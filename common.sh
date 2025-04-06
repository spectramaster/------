#!/bin/sh
# common.sh - 代理脚本共享库
# forum: https://1024.day
# 这个文件包含所有代理安装脚本共用的函数和常量
# 可以被其他脚本通过 source 命令引入

# 设置全局变量
SCRIPT_VERSION="1.0.0"

# 检查是否以 root 权限运行脚本
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "错误: 此脚本必须以 root 权限运行!" 1>&2
        exit 1
    fi
}

# 设置系统时区为上海时区(UTC+8)
set_timezone() {
    timedatectl set-timezone Asia/Shanghai
}

# 获取服务器IP地址的函数
# 优先获取IPv4地址，如果没有则获取IPv6地址
get_ip() {
    local serverIP=
    serverIP=$(curl -s -4 http://www.cloudflare.com/cdn-cgi/trace | grep "ip" | awk -F "[=]" '{print $2}')
    if [[ -z "${serverIP}" ]]; then
        serverIP=$(curl -s -6 http://www.cloudflare.com/cdn-cgi/trace | grep "ip" | awk -F "[=]" '{print $2}')
    fi
    echo "${serverIP}"
}

# 随机生成端口号
# 参数：$1 - 最小值(默认2000)，$2 - 最大值(默认65000)
random_port() {
    local min=${1:-2000}
    local max=${2:-65000}
    echo $(shuf -i $min-$max -n 1)
}

# 随机生成UUID
random_uuid() {
    cat /proc/sys/kernel/random/uuid
}

# 生成随机路径
# 参数：$1 - 长度(默认6)
random_path() {
    local length=${1:-6}
    cat /dev/urandom | head -1 | md5sum | head -c $length
}

# 检测系统类型并安装基本软件包
# 返回系统类型：debian或centos
install_base_packages() {
    # 检测是否为Debian系统
    if [ -f "/usr/bin/apt-get" ]; then
        apt-get update -y && apt-get upgrade -y
        apt-get install -y net-tools gawk curl wget unzip xz-utils jq socat
        echo "debian"
    # 否则假设是CentOS系统
    else
        yum update -y && yum upgrade -y
        yum install -y epel-release
        yum install -y net-tools gawk curl wget unzip xz jq socat
        echo "centos"
    fi
}

# 检测系统架构
# 返回：i686, arm, aarch64, x86_64
detect_arch() {
    local uname=$(uname -m)
    if [[ "$uname" == "i686" ]] || [[ "$uname" == "i386" ]]; then
        echo "i686"
    elif [[ "$uname" == *"armv7"* ]] || [[ "$uname" == "armv6l" ]]; then
        echo "arm"
    elif [[ "$uname" == *"armv8"* ]] || [[ "$uname" == "aarch64" ]]; then
        echo "aarch64"
    else
        echo "x86_64"
    fi  
}

# 创建并启用 systemd 服务
# 参数：$1 - 服务名称，$2 - 命令，$3 - 描述
create_systemd_service() {
    local name=$1
    local command=$2
    local description=${3:-"Proxy Service"}
    
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

    systemctl daemon-reload && systemctl enable ${name}.service && systemctl restart ${name}.service
}

# 检查端口占用情况
# 参数：$@ - 要检查的端口列表
# 返回：0 - 无占用，1 - 有占用
check_ports() {
    local ports=("$@")
    local isOccupied=0
    local occupiedPorts=""
    
    for port in "${ports[@]}"; do
        if netstat -tuln | grep -q ":$port "; then
            isOccupied=1
            occupiedPorts="$occupiedPorts $port"
        fi
    done
    
    if [ $isOccupied -eq 1 ]; then
        echo "以下端口被占用:$occupiedPorts" >&2
        return 1
    fi
    
    return 0
}

# 清理安装文件
# 参数：$@ - 要删除的文件列表
cleanup_files() {
    rm -f "$@" 2>/dev/null
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
}

# 显示完成信息
# 参数：$1 - 配置标题，$2 - 配置内容，$3 - URI链接
print_config() {
    local title=$1
    local config=$2
    local uri=${3:-""}
    
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