#!/bin/sh
# common.sh - 代理脚本共享库
# forum: https://1024.day
# 这个文件包含所有代理安装脚本共用的函数和常量，以及统一的错误处理框架
# 可以被其他脚本通过 source 命令引入

#########################################
# 全局变量与常量定义
#########################################

# 脚本版本
SCRIPT_VERSION="1.0.1"

# 错误级别定义
INFO=0
WARNING=1
ERROR=2
FATAL=3

# 错误代码定义
ERR_SUCCESS=0           # 成功，无错误
ERR_PERMISSION=1        # 权限不足
ERR_NETWORK=2           # 网络错误
ERR_DEPENDENCY=3        # 依赖软件错误
ERR_PORT_OCCUPIED=4     # 端口被占用
ERR_CONFIGURATION=5     # 配置错误
ERR_INSTALLATION=6      # 安装失败
ERR_SERVICE=7           # 服务控制错误
ERR_UNEXPECTED=99       # 未预期的错误

# 日志文件路径
LOG_FILE="/var/log/proxy-install.log"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 恢复默认颜色

# 调试模式（0: 关闭，1: 开启）
DEBUG_MODE=0

# 出错时是否自动退出（0: 不退出，1: 退出）
AUTO_EXIT_ON_ERROR=1

#########################################
# 错误处理与日志函数
#########################################

# 初始化日志系统
init_log() {
    # 确保日志目录存在
    mkdir -p $(dirname $LOG_FILE)
    
    # 创建或清空日志文件
    if [ "$1" = "clear" ]; then
        echo "=== 代理安装日志 - $(date) ===" > $LOG_FILE
    else
        echo "=== 代理安装日志 - $(date) ===" >> $LOG_FILE
    fi
    
    # 记录系统信息
    echo "系统信息: $(uname -a)" >> $LOG_FILE
    echo "脚本版本: $SCRIPT_VERSION" >> $LOG_FILE
    echo "====================================" >> $LOG_FILE
}

# 设置调试模式
set_debug() {
    DEBUG_MODE=$1
    log_message $INFO "调试模式设置为: $DEBUG_MODE"
}

# 设置自动退出模式
set_auto_exit() {
    AUTO_EXIT_ON_ERROR=$1
    log_message $INFO "自动退出模式设置为: $AUTO_EXIT_ON_ERROR"
}

# 记录日志消息
# 参数: $1 - 日志级别，$2 - 消息内容
log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    local level_str=""
    
    # 确定日志级别字符串
    case $level in
        $INFO)    level_str="INFO";;
        $WARNING) level_str="WARNING";;
        $ERROR)   level_str="ERROR";;
        $FATAL)   level_str="FATAL";;
        *)        level_str="UNKNOWN";;
    esac
    
    # 写入日志文件
    echo "$timestamp [$level_str] $message" >> $LOG_FILE
    
    # 如果开启了调试模式，或者级别高于INFO，则输出到终端
    if [ $DEBUG_MODE -eq 1 ] || [ $level -gt $INFO ]; then
        case $level in
            $INFO)    echo -e "${BLUE}[$level_str]${NC} $message";;
            $WARNING) echo -e "${YELLOW}[$level_str]${NC} $message";;
            $ERROR)   echo -e "${RED}[$level_str]${NC} $message";;
            $FATAL)   echo -e "${RED}[$level_str]${NC} $message";;
            *)        echo "[$level_str] $message";;
        esac
    fi
}

# 处理错误
# 参数: $1 - 错误代码，$2 - 错误消息，$3 - 是否致命(可选)
handle_error() {
    local code=$1
    local message=$2
    local fatal=${3:-0}
    local level=$ERROR
    
    # 如果是致命错误，设置为FATAL级别
    if [ "$fatal" = "1" ]; then
        level=$FATAL
    fi
    
    # 记录错误
    log_message $level "错误代码[$code]: $message"
    
    # 如果是致命错误且AUTO_EXIT_ON_ERROR=1，则退出脚本
    if [ "$fatal" = "1" ] && [ $AUTO_EXIT_ON_ERROR -eq 1 ]; then
        log_message $FATAL "脚本因致命错误终止"
        exit $code
    fi
    
    return $code
}

# 显示执行进度
# 参数: $1 - 当前步骤，$2 - 总步骤数，$3 - 描述
show_progress() {
    local current=$1
    local total=$2
    local desc=$3
    local percent=$((current * 100 / total))
    local completed=$((percent / 2))
    local remaining=$((50 - completed))
    
    # 构建进度条
    printf "\r[${GREEN}"
    printf "%0.s=" $(seq 1 $completed)
    printf "${NC}${BLUE}"
    printf "%0.s-" $(seq 1 $remaining)
    printf "${NC}] %3d%% %s" $percent "$desc"
    
    # 如果完成，换行
    if [ $current -eq $total ]; then
        printf "\n"
    fi
}

# 清理临时资源
# 参数: $1 - 清理级别 (1=轻度清理，2=中度清理，3=完全清理)
cleanup_resources() {
    local level=${1:-1}
    
    log_message $INFO "开始清理资源，级别: $level"
    
    # 清理临时文件
    rm -f /tmp/proxy-install-*
    
    # 如果级别大于1，清理下载的安装包
    if [ $level -gt 1 ]; then
        rm -f $SCRIPT_DIR/*.tar.gz $SCRIPT_DIR/*.xz $SCRIPT_DIR/*.zip 2>/dev/null
    fi
    
    # 如果级别等于3，执行完全清理（谨慎使用）
    if [ $level -eq 3 ]; then
        log_message $WARNING "执行完全清理，这将移除所有已下载的脚本和临时文件"
        rm -f $SCRIPT_DIR/*.sh 2>/dev/null
    fi
    
    log_message $INFO "资源清理完成"
}

# 检查命令执行结果
# 参数: $1 - 返回码, $2 - 成功消息, $3 - 失败消息, $4 - 是否致命(可选)
check_result() {
    local code=$1
    local success_msg=$2
    local error_msg=$3
    local fatal=${4:-0}
    
    if [ $code -eq 0 ]; then
        log_message $INFO "$success_msg"
        return 0
    else
        handle_error $code "$error_msg" $fatal
        return $code
    fi
}

# 执行命令并检查结果
# 参数: $1 - 命令, $2 - 成功消息, $3 - 失败消息, $4 - 是否致命(可选)
exec_with_check() {
    local command="$1"
    local success_msg="$2"
    local error_msg="$3"
    local fatal=${4:-0}
    
    log_message $INFO "执行命令: $command"
    
    # 执行命令并捕获输出和返回码
    local output
    output=$($command 2>&1)
    local ret=$?
    
    # 如果启用调试模式，记录命令输出
    if [ $DEBUG_MODE -eq 1 ]; then
        log_message $INFO "命令输出: $output"
    fi
    
    # 检查执行结果
    check_result $ret "$success_msg" "$error_msg ($output)" $fatal
    return $ret
}

# 确认用户输入
# 参数: $1 - 提示信息, $2 - 默认值(y/n)
confirm() {
    local prompt=$1
    local default=${2:-n}
    local options="y/N"
    
    if [ "$default" = "y" ]; then
        options="Y/n"
    fi
    
    echo -n "$prompt [$options] "
    read answer
    
    if [ -z "$answer" ]; then
        answer=$default
    fi
    
    case "$answer" in
        [yY]|[yY][eE][sS])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

#########################################
# 基础工具函数
#########################################

# 检查是否以 root 权限运行脚本
check_root() {
    if [[ $EUID -ne 0 ]]; then
        handle_error $ERR_PERMISSION "此脚本必须以 root 权限运行!" 1
        exit 1
    fi
    log_message $INFO "已确认脚本以root权限运行"
}

# 设置系统时区为上海时区(UTC+8)
set_timezone() {
    log_message $INFO "设置系统时区为 Asia/Shanghai"
    timedatectl set-timezone Asia/Shanghai
    check_result $? "时区设置成功" "时区设置失败" 0
}

# 获取服务器IP地址的函数
# 优先获取IPv4地址，如果没有则获取IPv6地址
get_ip() {
    log_message $INFO "获取服务器IP地址"
    local serverIP=
    
    # 尝试获取IPv4地址
    serverIP=$(curl -s -4 --connect-timeout 10 http://www.cloudflare.com/cdn-cgi/trace 2>/dev/null | grep "ip" | awk -F "[=]" '{print $2}')
    
    # 如果IPv4地址获取失败，尝试获取IPv6地址
    if [[ -z "${serverIP}" ]]; then
        log_message $WARNING "获取IPv4地址失败，尝试获取IPv6地址"
        serverIP=$(curl -s -6 --connect-timeout 10 http://www.cloudflare.com/cdn-cgi/trace 2>/dev/null | grep "ip" | awk -F "[=]" '{print $2}')
        
        # 如果仍然失败，尝试其他API
        if [[ -z "${serverIP}" ]]; then
            log_message $WARNING "通过Cloudflare获取IP失败，尝试使用其他API"
            serverIP=$(curl -s --connect-timeout 10 https://api.ipify.org 2>/dev/null)
            
            # 如果仍然失败，使用本地网络接口获取
            if [[ -z "${serverIP}" ]]; then
                log_message $WARNING "通过API获取IP失败，尝试从网络接口获取"
                serverIP=$(ip -4 addr | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v "127.0.0.1" | head -1)
                
                # 如果本地获取也失败，报错
                if [[ -z "${serverIP}" ]]; then
                    handle_error $ERR_NETWORK "无法获取服务器IP地址" 0
                    serverIP="未知IP"
                fi
            fi
        fi
    fi
    
    log_message $INFO "获取到服务器IP地址: $serverIP"
    echo "${serverIP}"
}

# 随机生成端口号
# 参数：$1 - 最小值(默认2000)，$2 - 最大值(默认65000)
random_port() {
    local min=${1:-2000}
    local max=${2:-65000}
    local port=$(shuf -i $min-$max -n 1)
    log_message $INFO "生成随机端口: $port"
    echo $port
}

# 随机生成UUID
random_uuid() {
    local uuid=$(cat /proc/sys/kernel/random/uuid)
    log_message $INFO "生成随机UUID: $uuid"
    echo $uuid
}

# 生成随机路径
# 参数：$1 - 长度(默认6)
random_path() {
    local length=${1:-6}
    local path=$(cat /dev/urandom | head -1 | md5sum | head -c $length)
    log_message $INFO "生成随机路径: $path (长度 $length)"
    echo $path
}

# 检测系统类型并安装基本软件包
# 返回系统类型：debian或centos
install_base_packages() {
    log_message $INFO "开始安装基本软件包"
    local system_type=""
    
    # 检测是否为Debian系统
    if [ -f "/usr/bin/apt-get" ]; then
        log_message $INFO "检测到Debian/Ubuntu系统"
        system_type="debian"
        
        # 更新软件源和系统
        exec_with_check "apt-get update -y" "apt-get update 成功" "apt-get update 失败" 0
        exec_with_check "apt-get upgrade -y" "apt-get upgrade 成功" "apt-get upgrade 失败" 0
        
        # 安装基本软件包
        exec_with_check "apt-get install -y net-tools gawk curl wget unzip xz-utils jq socat" \
                      "基本软件包安装成功" "基本软件包安装失败" 0
    # 否则假设是CentOS系统
    else
        log_message $INFO "检测到CentOS/RHEL系统"
        system_type="centos"
        
        # 更新软件源和系统
        exec_with_check "yum update -y" "yum update 成功" "yum update 失败" 0
        exec_with_check "yum upgrade -y" "yum upgrade 成功" "yum upgrade 失败" 0
        
        # 安装EPEL仓库
        exec_with_check "yum install -y epel-release" "EPEL仓库安装成功" "EPEL仓库安装失败" 0
        
        # 安装基本软件包
        exec_with_check "yum install -y net-tools gawk curl wget unzip xz jq socat" \
                      "基本软件包安装成功" "基本软件包安装失败" 0
    fi
    
    log_message $INFO "基本软件包安装完成，系统类型: $system_type"
    echo $system_type
}

# 检测系统架构
# 返回：i686, arm, aarch64, x86_64
detect_arch() {
    local uname=$(uname -m)
    local arch=""
    
    if [[ "$uname" == "i686" ]] || [[ "$uname" == "i386" ]]; then
        arch="i686"
    elif [[ "$uname" == *"armv7"* ]] || [[ "$uname" == "armv6l" ]]; then
        arch="arm"
    elif [[ "$uname" == *"armv8"* ]] || [[ "$uname" == "aarch64" ]]; then
        arch="aarch64"
    else
        arch="x86_64"
    fi
    
    log_message $INFO "检测到系统架构: $arch"
    echo $arch
}

# 创建并启用 systemd 服务
# 参数：$1 - 服务名称，$2 - 命令，$3 - 描述
create_systemd_service() {
    local name=$1
    local command=$2
    local description=${3:-"Proxy Service"}
    
    log_message $INFO "创建 systemd 服务: $name"
    
    cat >/etc/systemd/system/${name}.service<<EOF
[Unit]
Description=${description}
After=network.target

[Service]
ExecStart=${command}
Restart=on-abort

[Install]
WantedBy=multi-user.target
EOF

    # 重新加载systemd配置
    exec_with_check "systemctl daemon-reload" \
                  "systemd 配置重新加载成功" "systemd 配置重新加载失败" 0
    
    # 启用服务
    exec_with_check "systemctl enable ${name}.service" \
                  "服务 $name 启用成功" "服务 $name 启用失败" 0
    
    # 重启服务
    exec_with_check "systemctl restart ${name}.service" \
                  "服务 $name 启动成功" "服务 $name 启动失败" 0
    
    # 检查服务状态
    if systemctl is-active --quiet ${name}.service; then
        log_message $INFO "服务 $name 运行正常"
    else
        handle_error $ERR_SERVICE "服务 $name 启动失败或运行异常" 0
    fi
}

# 检查端口占用情况
# 参数：$@ - 要检查的端口列表
# 返回：0 - 无占用，1 - 有占用
check_ports() {
    local ports=("$@")
    local isOccupied=0
    local occupiedPorts=""
    
    log_message $INFO "检查端口占用情况: ${ports[*]}"
    
    for port in "${ports[@]}"; do
        if netstat -tuln | grep -q ":$port "; then
            isOccupied=1
            occupiedPorts="$occupiedPorts $port"
            log_message $WARNING "端口 $port 已被占用"
        else
            log_message $INFO "端口 $port 可用"
        fi
    done
    
    if [ $isOccupied -eq 1 ]; then
        handle_error $ERR_PORT_OCCUPIED "以下端口被占用:$occupiedPorts" 0
        return 1
    fi
    
    log_message $INFO "所有检查的端口均可用"
    return 0
}

# 清理安装文件
# 参数：$@ - 要删除的文件列表
cleanup_files() {
    log_message $INFO "清理安装文件: $@"
    rm -f "$@" 2>/dev/null
    
    # 检查是否有文件删除失败
    local failed=0
    for file in "$@"; do
        if [ -f "$file" ]; then
            log_message $WARNING "文件 $file 删除失败"
            failed=1
        fi
    done
    
    if [ $failed -eq 1 ]; then
        handle_error $ERR_UNEXPECTED "部分文件清理失败" 0
        return 1
    else
        log_message $INFO "文件清理完成"
        return 0
    fi
}

# 打印分隔线
print_line() {
    echo "=================================================="
}

# 打印脚本头部信息
print_header() {
    local title=$1
    clear
    print_line
    echo " 论坛：https://1024.day"
    echo " 介绍：$title"
    echo " 系统：Ubuntu、Debian、CentOS"
    print_line
    echo
    
    log_message $INFO "显示脚本头部信息: $title"
}

# 显示完成信息
# 参数：$1 - 配置标题，$2 - 配置内容，$3 - URI链接
print_config() {
    local title=$1
    local config=$2
    local uri=${3:-""}
    
    log_message $INFO "显示 $title 配置信息"
    
    echo
    echo "安装已经完成"
    echo
    echo "===========$title配置参数============"
    echo "$config"
    echo "====================================="
    if [ ! -z "$uri" ]; then
        echo "$uri"
    fi
    echo
}

# 下载文件
# 参数：$1 - URL，$2 - 保存路径，$3 - 是否显示进度(0/1)
download_file() {
    local url=$1
    local path=$2
    local show_progress=${3:-0}
    local download_tool=""
    
    log_message $INFO "下载文件: $url -> $path"
    
    # 检查下载工具
    if command -v wget >/dev/null 2>&1; then
        download_tool="wget"
        log_message $INFO "使用 wget 下载文件"
        
        # 根据是否显示进度使用不同参数
        if [ $show_progress -eq 1 ]; then
            wget -O $path $url
        else
            wget -q -O $path $url
        fi
    elif command -v curl >/dev/null 2>&1; then
        download_tool="curl"
        log_message $INFO "使用 curl 下载文件"
        
        # 根据是否显示进度使用不同参数
        if [ $show_progress -eq 1 ]; then
            curl -L -o $path $url
        else
            curl -s -L -o $path $url
        fi
    else
        handle_error $ERR_DEPENDENCY "未找到 wget 或 curl，无法下载文件" 1
        return 1
    fi
    
    # 检查下载结果
    if [ ! -s $path ]; then
        handle_error $ERR_NETWORK "文件下载失败: $url" 0
        return 1
    else
        log_message $INFO "文件下载成功: $url"
        return 0
    fi
}

# 初始化日志
init_log