#!/bin/sh
# forum: https://1024.day
# 这是一个用于安装 Shadowsocks-rust 代理服务的脚本
# Shadowsocks-rust 是 Shadowsocks 的 Rust 语言实现，性能更好

# 获取脚本所在目录
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

# 下载共享库
if [ ! -f "${SCRIPT_DIR}/common.sh" ]; then
    echo "下载共享库..."
    wget -q -O "${SCRIPT_DIR}/common.sh" https://raw.githubusercontent.com/yeahwu/v2ray-wss/main/common.sh
    chmod +x "${SCRIPT_DIR}/common.sh"
fi

# 导入共享库
. "${SCRIPT_DIR}/common.sh"

# 设置脚本名称（用于日志）
SCRIPT_NAME="Shadowsocks-rust 安装脚本"
log_message $INFO "$SCRIPT_NAME 开始执行"

# 检查root权限
check_root

# 设置时区
set_timezone

# 生成随机密码和端口
log_message $INFO "生成随机密码和端口"
sspasswd=$(random_uuid)
ssport=$(random_port)

# 定义安装步骤总数（用于显示进度）
TOTAL_STEPS=5
CURRENT_STEP=0

# 安装必要的系统更新和工具
install_ss_deps() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    show_progress $CURRENT_STEP $TOTAL_STEPS "安装系统依赖"
    
    # 使用共享库函数安装基本软件包
    system_type=$(install_base_packages)
    
    # 检查是否成功安装依赖
    if [ $? -ne 0 ]; then
        handle_error $ERR_DEPENDENCY "依赖安装失败，请检查网络连接或系统状态" 0
        return 1
    fi
    
    return 0
}

# 安装Shadowsocks-rust
install_ss() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    show_progress $CURRENT_STEP $TOTAL_STEPS "下载安装 Shadowsocks-rust"
    
    # 获取系统架构
    arch=$(detect_arch)
    
    # 获取Shadowsocks-rust的最新版本号
    log_message $INFO "正在获取 Shadowsocks-rust 最新版本..."
    local new_ver
    new_ver=$(wget -qO- https://api.github.com/repos/shadowsocks/shadowsocks-rust/releases| jq -r '[.[] | select(.prerelease == false) | select(.draft == false) | .tag_name] | .[0]')
    
    if [ -z "$new_ver" ]; then
        handle_error $ERR_NETWORK "获取 Shadowsocks-rust 版本信息失败" 0
        return 1
    fi
    
    log_message $INFO "检测到 Shadowsocks-rust 最新版本: $new_ver"
    
    # 下载对应系统架构的安装包
    local download_url="https://github.com/shadowsocks/shadowsocks-rust/releases/download/${new_ver}/shadowsocks-${new_ver}.${arch}-unknown-linux-gnu.tar.xz"
    local target_file="${SCRIPT_DIR}/shadowsocks-${new_ver}.${arch}-unknown-linux-gnu.tar.xz"
    
    log_message $INFO "开始下载: $download_url"
    download_file "$download_url" "$target_file" 1
    
    # 检查下载是否成功
    if [ ! -e "$target_file" ]; then
        handle_error $ERR_NETWORK "Shadowsocks Rust 官方源下载失败" 0
        return 1
    fi
    
    # 解压安装包
    log_message $INFO "解压 Shadowsocks-rust 安装包"
    tar -xvf "$target_file"
    
    # 检查解压是否成功
    if [ ! -e "ssserver" ]; then
        handle_error $ERR_INSTALLATION "Shadowsocks Rust 解压失败" 0
        return 1
    fi
    
    # 删除安装包
    log_message $INFO "清理安装包"
    rm -rf "$target_file"
    
    # 给服务端可执行文件添加执行权限
    chmod +x ssserver
    
    # 移动服务端可执行文件到/usr/local/bin目录
    log_message $INFO "安装 Shadowsocks-rust 到系统"
    mv -f ssserver /usr/local/bin/
    
    # 检查移动是否成功
    if [ ! -e "/usr/local/bin/ssserver" ]; then
        handle_error $ERR_INSTALLATION "Shadowsocks Rust 安装失败" 0
        return 1
    fi
    
    # 删除其他不需要的可执行文件
    rm -f sslocal ssmanager ssservice ssurl 2>/dev/null

    log_message $INFO "Shadowsocks Rust 主程序下载安装完毕"
    return 0
}

# 配置Shadowsocks-rust
config_ss() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    show_progress $CURRENT_STEP $TOTAL_STEPS "配置 Shadowsocks-rust"
    
    # 创建配置文件目录
    log_message $INFO "创建配置目录"
    mkdir -p /etc/shadowsocks
    
    # 检查端口是否可用
    if ! check_ports $ssport; then
        # 如果端口被占用，重新生成端口
        log_message $WARNING "端口 $ssport 被占用，重新生成随机端口"
        ssport=$(random_port)
        # 再次检查
        if ! check_ports $ssport; then
            handle_error $ERR_PORT_OCCUPIED "无法找到可用的端口" 1
            return 1
        fi
    fi

    # 创建Shadowsocks配置文件
    log_message $INFO "创建配置文件: /etc/shadowsocks/config.json"
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

    # 检查配置文件是否创建成功
    if [ ! -e "/etc/shadowsocks/config.json" ]; then
        handle_error $ERR_CONFIGURATION "Shadowsocks 配置文件创建失败" 0
        return 1
    fi
    
    log_message $INFO "配置文件创建成功"
    return 0
}

# 启动Shadowsocks服务
start_ss_service() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    show_progress $CURRENT_STEP $TOTAL_STEPS "设置并启动服务"
    
    # 使用共享库函数创建systemd服务
    create_systemd_service "shadowsocks" "/usr/local/bin/ssserver -c /etc/shadowsocks/config.json" "Shadowsocks Server"
    
    # 检查服务是否启动成功
    if ! systemctl is-active --quiet shadowsocks.service; then
        handle_error $ERR_SERVICE "Shadowsocks服务启动失败" 0
        
        # 尝试查看失败原因
        log_message $ERROR "Shadowsocks服务状态:"
        systemctl status shadowsocks.service
        
        return 1
    fi
    
    log_message $INFO "Shadowsocks服务启动成功"
    return 0
}

# 清理安装环境
cleanup_installation() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    show_progress $CURRENT_STEP $TOTAL_STEPS "清理安装环境"
    
    # 删除安装脚本
    cleanup_files "${SCRIPT_DIR}/tcp-wss.sh" "${SCRIPT_DIR}/ss-rust.sh"
    
    # 清理临时资源
    cleanup_resources 1
    
    log_message $INFO "安装环境清理完成"
    return 0
}

# 生成并显示客户端配置信息
client_ss() {
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
    
    # 将配置信息保存到文件
    log_message $INFO "保存客户端配置到文件: /etc/shadowsocks/client.json"
    cat >/etc/shadowsocks/client.json<<EOF
{
===========配置参数=============
地址：${server_ip}
端口：${ssport}
密码：${sspasswd}
加密方式：aes-128-gcm
传输协议：tcp+udp
====================================
ss://${sslink}
}
EOF
}

# 执行安装流程，带有错误处理
main() {
    # 设置错误处理为严格模式
    set_auto_exit 1
    
    # 初始化日志
    init_log clear
    
    # 打印脚本信息
    print_header "Shadowsocks-rust 代理安装脚本"
    
    log_message $INFO "开始安装 Shadowsocks-rust"
    
    # 执行安装步骤
    install_ss_deps && \
    install_ss && \
    config_ss && \
    start_ss_service && \
    cleanup_installation
    
    # 检查安装结果
    if [ $? -eq 0 ]; then
        log_message $INFO "Shadowsocks-rust 安装成功"
        client_ss
    else
        log_message $ERROR "Shadowsocks-rust 安装失败，请查看日志: $LOG_FILE"
        echo
        echo "安装失败，请查看日志文件: $LOG_FILE"
        echo
        return 1
    fi
    
    return 0
}

# 执行主函数
main