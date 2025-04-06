#!/bin/sh
# forum: https://1024.day
# 这是一个用于安装 Shadowsocks-rust 代理服务的脚本
# Shadowsocks-rust 是 Shadowsocks 的 Rust 语言实现，性能更好

# 获取脚本所在目录
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

# 下载共享库
if [ ! -f "${SCRIPT_DIR}/common.sh" ]; then
    wget -q -O "${SCRIPT_DIR}/common.sh" https://raw.githubusercontent.com/yeahwu/v2ray-wss/main/common.sh
    chmod +x "${SCRIPT_DIR}/common.sh"
fi

# 导入共享库
. "${SCRIPT_DIR}/common.sh"

# 检查root权限
check_root

# 设置时区
set_timezone

# 生成随机密码和端口
sspasswd=$(random_uuid)
ssport=$(random_port)

# 安装必要的系统更新和工具
install_ss_deps() {
    # 使用共享库函数安装基本软件包
    system_type=$(install_base_packages)
}

# 安装Shadowsocks-rust
install_ss() {
    # 获取系统架构
    arch=$(detect_arch)
    
    # 获取Shadowsocks-rust的最新版本号
    new_ver=$(wget -qO- https://api.github.com/repos/shadowsocks/shadowsocks-rust/releases| jq -r '[.[] | select(.prerelease == false) | select(.draft == false) | .tag_name] | .[0]')

    # 下载对应系统架构的安装包
    wget --no-check-certificate -N "https://github.com/shadowsocks/shadowsocks-rust/releases/download/${new_ver}/shadowsocks-${new_ver}.${arch}-unknown-linux-gnu.tar.xz"
    
    # 检查下载是否成功
    if [[ ! -e "shadowsocks-${new_ver}.${arch}-unknown-linux-gnu.tar.xz" ]]; then
        echo "错误: Shadowsocks Rust 官方源下载失败！"
        return 1 && exit 1
    else
        # 解压安装包
        tar -xvf "shadowsocks-${new_ver}.${arch}-unknown-linux-gnu.tar.xz"
    fi
    
    # 检查解压是否成功
    if [[ ! -e "ssserver" ]]; then
        echo "错误: Shadowsocks Rust 解压失败！"
        echo "错误: Shadowsocks Rust 安装失败！"
        return 1 && exit 1
    else
        # 删除安装包
        rm -rf "shadowsocks-${new_ver}.${arch}-unknown-linux-gnu.tar.xz"
        # 给服务端可执行文件添加执行权限
        chmod +x ssserver
        # 移动服务端可执行文件到/usr/local/bin目录
        mv -f ssserver /usr/local/bin/
        # 删除其他不需要的可执行文件
        rm -f sslocal ssmanager ssservice ssurl

        echo "Shadowsocks Rust 主程序下载安装完毕！"
        return 0
    fi
}

# 配置Shadowsocks-rust
config_ss(){
    # 创建配置文件目录
    mkdir -p /etc/shadowsocks

    # 创建Shadowsocks配置文件
cat >/etc/shadowsocks/config.json<<EOF
{
    "server":"::",
    "server_port":$ssport,
    "password":"$sspasswd",
    "timeout":600,
    "mode":"tcp_and_udp",
    "method":"aes-128-gcm"
}
EOF

    # 使用共享库函数创建systemd服务
    create_systemd_service "shadowsocks" "/usr/local/bin/ssserver -c /etc/shadowsocks/config.json" "Shadowsocks Server"
    
    # 删除安装脚本
    cleanup_files "${SCRIPT_DIR}/tcp-wss.sh" "${SCRIPT_DIR}/ss-rust.sh"
}

# 生成并显示客户端配置信息
client_ss(){
    # 获取服务器IP
    server_ip=$(get_ip)
    
    # 生成Shadowsocks URI链接
    sslink=$(echo -n "aes-128-gcm:${sspasswd}@${server_ip}:${ssport}" | base64 -w 0)

    # 构建配置信息字符串
    config=$(cat <<EOF
地址：${server_ip}
端口：${ssport}
密码：${sspasswd}
加密方式：aes-128-gcm
传输协议：tcp+udp
EOF
)

    # 使用共享库函数显示配置信息
    print_config "Shadowsocks" "$config" "ss://${sslink}"
}

# 执行安装流程
install_ss_deps
install_ss
config_ss
client_ss