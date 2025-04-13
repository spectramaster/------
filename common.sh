#!/bin/sh
# common.sh - 网络代理工具共享库文件
# 包含所有脚本共用的函数和设置
# 论坛: https://1024.day
# 创建日期: 2025年4月13日
# 用途: 提供代理服务脚本所需的共享函数，避免代码重复

# 增加错误处理：任何命令失败则立即退出
set -e

# 定义错误处理函数
error_exit() {
    echo "Error: $1" 1>&2
    exit 1
}

# 检查root权限函数
check_root() {
    if [[ $EUID -ne 0 ]]; then
        clear
        # 使用错误处理函数退出
        error_exit "This script must be run as root!"
    fi
}

# 设置系统时区函数
set_timezone() {
    timedatectl set-timezone Asia/Shanghai || error_exit "Failed to set timezone."
}

# 获取服务器IP地址函数
getIP() {
    local serverIP=""
    # 尝试获取IPv4 (允许失败，后续会尝试IPv6)
    serverIP=$(curl -s -4 --connect-timeout 5 http://www.cloudflare.com/cdn-cgi/trace | grep "ip" | awk -F "[=]" '{print $2}') || true 
    if [[ -z "${serverIP}" ]]; then
        # 尝试获取IPv6 (允许失败)
        serverIP=$(curl -s -6 --connect-timeout 5 http://www.cloudflare.com/cdn-cgi/trace | grep "ip" | awk -F "[=]" '{print $2}') || true
    fi
    if [[ -z "${serverIP}" ]]; then
        echo "Warning: Could not automatically determine server IP." >&2
        # 可以考虑让用户手动输入，或者返回空让调用者处理
    fi
    echo "${serverIP}"
}

# 随机生成UUID函数
gen_uuid() {
    # 检查 /proc/sys/kernel/random/uuid 是否可读
    if [ -r "/proc/sys/kernel/random/uuid" ]; then
        cat /proc/sys/kernel/random/uuid
    else
        # 后备方法（如果系统不支持 /proc/sys/kernel/random/uuid）
        # 需要 uuidgen 命令 (通常在 uuid-runtime 或 util-linux 包中)
        if command -v uuidgen > /dev/null; then
            uuidgen
        else
            error_exit "Cannot generate UUID. 'uuidgen' command not found and /proc/sys/kernel/random/uuid not available."
        fi
    fi
}

# 随机生成端口号函数
gen_port() {
    shuf -i 2000-65000 -n 1
}

# 随机生成短路径函数
gen_path() {
    # 检查 /dev/urandom 是否可读
    if [ -r "/dev/urandom" ]; then
        # 使用 head -c 16 限制读取量，避免潜在的阻塞
        head -c 16 /dev/urandom | md5sum | head -c 6
    else
        error_exit "Cannot generate random path. /dev/urandom is not readable."
    fi
}

# 安装系统更新和基本工具函数
install_base() {
    echo "Updating system packages and installing base tools..."
    if command -v apt-get > /dev/null; then
        # Debian/Ubuntu
        apt-get update -y || error_exit "apt-get update failed."
        # 允许 upgrade 失败，有时会有交互或冲突
        apt-get upgrade -y || echo "Warning: apt-get upgrade had issues, continuing..."
        apt-get install -y gawk curl wget || error_exit "Failed to install base packages (gawk, curl, wget) using apt-get."
    elif command -v yum > /dev/null; then
        # CentOS
        yum update -y || error_exit "yum update failed."
        # 允许 upgrade 失败
        yum upgrade -y || echo "Warning: yum upgrade had issues, continuing..."
        # EPEL 安装可能已存在，忽略错误
        yum install -y epel-release || true 
        yum install -y gawk curl wget || error_exit "Failed to install base packages (gawk, curl, wget) using yum."
    else
        error_exit "Unsupported package manager. Cannot install base packages."
    fi
    echo "Base tools installation complete."
}

# 安装Debian/Ubuntu额外工具函数
install_debian_tools() {
    if command -v apt-get > /dev/null; then
        echo "Installing Debian/Ubuntu tools: $@"
        apt-get install -y "$@" || error_exit "Failed to install Debian/Ubuntu packages: $@."
        echo "Debian/Ubuntu tools installation complete."
    fi
}

# 安装CentOS额外工具函数
install_centos_tools() {
    if command -v yum > /dev/null; then
        echo "Installing CentOS tools: $@"
        yum install -y "$@" || error_exit "Failed to install CentOS packages: $@."
        echo "CentOS tools installation complete."
    fi
}

# 清理安装文件函数
# rm -f 不会因文件不存在而报错，set -e 对其无效，无需额外检查
clean_files() {
    echo "Cleaning up files: $@"
    rm -f "$@"
    echo "Cleanup complete."
}

# 显示安装完成的通用信息函数
show_completion() {
    echo
    echo "Installation process completed."
    echo
}

# 生成Shadowsocks链接函数
gen_ss_link() {
    local method=$1
    local password=$2
    local ip=$3
    local port=$4

    # 检查 base64 命令是否存在
    command -v base64 > /dev/null || error_exit "'base64' command not found."
    
    echo -n "${method}:${password}@${ip}:${port}" | base64 -w 0
}

# 启用并重启服务函数
enable_service() {
    local service_name=$1
    echo "Enabling and restarting service: ${service_name}..."
    systemctl enable "${service_name}.service" || error_exit "Failed to enable service: ${service_name}."
    systemctl restart "${service_name}.service" || error_exit "Failed to restart service: ${service_name}."
    echo "Service ${service_name} enabled and restarted successfully."
}

# 检测系统架构函数
detect_arch() {
    local uname_m
    uname_m=$(uname -m)
    case "$uname_m" in
        "i686" | "i386")
            echo "i686"
            ;;
        *"armv7"* | "armv6l")
            echo "arm"
            ;;
        *"armv8"* | "aarch64")
            echo "aarch64"
            ;;
        "x86_64")
            echo "x86_64"
            ;;
        *)
            # 如果无法识别，默认返回 x86_64 并打印警告
            echo "Warning: Unknown architecture '$uname_m'. Assuming x86_64." >&2
            echo "x86_64"
            ;;
    esac
}

# 添加一个函数用于安全执行远程脚本
# 用法: safe_run_remote_script "URL" "Description for error message"
safe_run_remote_script() {
    local url="$1"
    local description="$2"
    local temp_script="/tmp/temp_install_script_$(date +%s).sh"

    echo "Downloading script from ${url}..."
    curl -L "${url}" -o "${temp_script}" || error_exit "Failed to download ${description} installer script from ${url}."
    
    echo "Executing ${description} installer script..."
    bash "${temp_script}" || { 
        local exit_code=$?
        rm -f "${temp_script}"
        error_exit "${description} installer script failed with exit code ${exit_code}." 
    }
    
    rm -f "${temp_script}"
    echo "${description} installation script executed successfully."
}