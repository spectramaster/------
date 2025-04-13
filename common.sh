#!/bin/sh
# common.sh - 网络代理工具共享库文件
# 包含所有脚本共用的函数和设置
# 论坛: https://1024.day
# 创建日期: 2025年4月13日
# 用途: 提供代理服务脚本所需的共享函数，避免代码重复

# 检查root权限函数
# 用途: 确保脚本以root权限运行，否则退出
check_root() {
    # $EUID是当前用户的有效UID，root用户的UID为0
    if [[ $EUID -ne 0 ]]; then
        # 清屏
        clear
        # 显示错误信息并定向到stderr
        echo "Error: This script must be run as root!" 1>&2
        # 以状态码1退出脚本，表示出错
        exit 1
    fi
}

# 设置系统时区函数
# 用途: 将系统时区设置为亚洲/上海
set_timezone() {
    # 使用timedatectl命令修改系统时区
    timedatectl set-timezone Asia/Shanghai
}

# 获取服务器IP地址函数
# 用途: 尝试获取服务器的公网IP地址(优先IPv4)
getIP() {
    # 定义局部变量，避免污染全局命名空间
    local serverIP=
    # 使用cloudflare的IP检测服务获取IPv4地址
    serverIP=$(curl -s -4 http://www.cloudflare.com/cdn-cgi/trace | grep "ip" | awk -F "[=]" '{print $2}')
    # 如果无法获取IPv4地址，尝试获取IPv6地址
    if [[ -z "${serverIP}" ]]; then
        serverIP=$(curl -s -6 http://www.cloudflare.com/cdn-cgi/trace | grep "ip" | awk -F "[=]" '{print $2}')
    fi
    # 输出获取到的IP地址
    echo "${serverIP}"
}

# 随机生成UUID函数
# 用途: 生成随机UUID，用于代理服务的身份验证
gen_uuid() {
    # 读取Linux内核提供的随机UUID
    cat /proc/sys/kernel/random/uuid
}

# 随机生成端口号函数
# 用途: 在2000-65000范围内随机生成一个端口号
gen_port() {
    # shuf命令用于随机选择，-i指定范围，-n指定选择数量
    shuf -i 2000-65000 -n 1
}

# 随机生成短路径函数
# 用途: 生成6位随机字符，用于WebSocket的路径
gen_path() {
    # 从/dev/urandom获取随机数据，通过md5sum生成哈希，截取前6位
    cat /dev/urandom | head -1 | md5sum | head -c 6
}

# 安装系统更新和基本工具函数
# 用途: 根据系统类型安装必要的更新和基础工具
install_base() {
    # 检测是否为Debian/Ubuntu系统
    if [ -f "/usr/bin/apt-get" ]; then
        # Debian/Ubuntu系统的更新和安装命令
        apt-get update -y && apt-get upgrade -y
        apt-get install -y gawk curl wget
    else
        # CentOS系统的更新和安装命令
        yum update -y && yum upgrade -y
        yum install -y epel-release
        yum install -y gawk curl wget
    fi
}

# 安装Debian/Ubuntu额外工具函数
# 用途: 在Debian/Ubuntu系统安装指定的额外工具
# 参数: $@ 要安装的软件包列表
install_debian_tools() {
    # 检测是否为Debian/Ubuntu系统
    if [ -f "/usr/bin/apt-get" ]; then
        # 使用apt-get安装传入的软件包
        apt-get install -y $@
    fi
}

# 安装CentOS额外工具函数
# 用途: 在CentOS系统安装指定的额外工具
# 参数: $@ 要安装的软件包列表
install_centos_tools() {
    # 检测是否为CentOS系统
    if [ -f "/usr/bin/yum" ]; then
        # 使用yum安装传入的软件包
        yum install -y $@
    fi
}

# 清理安装文件函数
# 用途: 删除指定的安装脚本文件
# 参数: $@ 要删除的文件列表
clean_files() {
    # 删除主脚本和传入的其他文件
    rm -f tcp-wss.sh $@
}

# 显示安装完成的通用信息函数
# 用途: 显示安装完成的提示信息
show_completion() {
    # 输出空行
    echo
    # 输出完成提示
    echo "安装已经完成"
    # 输出空行
    echo
}

# 生成Shadowsocks链接函数
# 用途: 根据参数生成Shadowsocks客户端连接链接
# 参数: $1 加密方法, $2 密码, $3 IP地址, $4 端口
gen_ss_link() {
    # 获取传入的四个参数
    local method=$1
    local password=$2
    local ip=$3
    local port=$4
    
    # 使用base64编码生成Shadowsocks链接
    echo -n "${method}:${password}@${ip}:${port}" | base64 -w 0
}

# 启用并重启服务函数
# 用途: 启用并重启指定的系统服务
# 参数: $1 服务名称
enable_service() {
    # 启用服务并设置开机自启，然后重启服务
    systemctl enable $1.service && systemctl restart $1.service
}

# 检测系统架构函数
# 用途: 检测当前系统的CPU架构类型
detect_arch() {
    # 获取系统架构信息
    uname=$(uname -m)
    # 根据架构信息返回对应的架构标识
    if [[ "$uname" == "i686" ]] || [[ "$uname" == "i386" ]]; then
        echo "i686"  # 32位x86架构
    elif [[ "$uname" == *"armv7"* ]] || [[ "$uname" == "armv6l" ]]; then
        echo "arm"   # ARM 32位架构
    elif [[ "$uname" == *"armv8"* ]] || [[ "$uname" == "aarch64" ]]; then
        echo "aarch64"  # ARM 64位架构
    else
        echo "x86_64"  # 64位x86架构(默认)
    fi
}