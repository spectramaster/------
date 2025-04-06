#!/bin/sh
# forum: https://1024.day
# 这是一个用于安装 Hysteria2 代理服务的脚本
# Hysteria2 是基于 QUIC 协议的高性能代理，抗干扰能力强

# 获取脚本所在目录
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

# 下载共享库
if [ ! -f "${SCRIPT_DIR}/common.sh" ]; then
    echo "下载共享库..."
    wget -q -O "${SCRIPT_DIR}/common.sh" https://raw.githubusercontent.com/spectramaster/vpn/main/common.sh
    chmod +x "${SCRIPT_DIR}/common.sh"
fi

# 导入共享库
. "${SCRIPT_DIR}/common.sh"

# 设置脚本名称（用于日志）
SCRIPT_NAME="Hysteria2 安装脚本"
log_message $INFO "$SCRIPT_NAME 开始执行"

# 检查root权限
check_root

# 设置时区
set_timezone

# 生成随机密码和端口
hyPasswd=$(random_uuid)
getPort=$(random_port)

# 定义安装步骤总数（用于显示进度）
TOTAL_STEPS=5
CURRENT_STEP=0

# 检查和准备环境
prepare_environment() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    show_progress $CURRENT_STEP $TOTAL_STEPS "准备环境"
    
    # 使用共享库函数安装基本软件包
    log_message $INFO "安装基本软件包"
    install_base_packages >/dev/null
    
    if [ $? -ne 0 ]; then
        handle_error $ERR_DEPENDENCY "基本软件包安装失败" 0
        return 1
    }
    
    # 检查端口是否被占用
    log_message $INFO "检查端口: $getPort"
    if ! check_ports $getPort; then
        log_message $WARNING "端口 $getPort 已被占用，重新生成端口"
        getPort=$(random_port)
        
        # 再次检查新端口
        if ! check_ports $getPort; then
            handle_error $ERR_PORT_OCCUPIED "无法找到可用的端口" 1
            return 1
        }
    }
    
    log_message $INFO "使用端口: $getPort"
    log_message $INFO "环境准备完成"
    return 0
}

# 安装Hysteria2
install_hy2(){
    CURRENT_STEP=$((CURRENT_STEP + 1))
    show_progress $CURRENT_STEP $TOTAL_STEPS "安装 Hysteria2"
    
    # 从Hysteria2官方仓库下载并运行安装脚本
    log_message $INFO "下载并安装Hysteria2"
    exec_with_check "bash <(curl -fsSL https://get.hy2.sh/)" \
                   "Hysteria2安装成功" "Hysteria2安装失败" 0
    
    if [ $? -ne 0 ]; then
        handle_error $ERR_INSTALLATION "Hysteria2安装失败" 1
        return 1
    }
    
    log_message $INFO "Hysteria2安装完成"
    return 0
}

# 生成证书
generate_certificate() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    show_progress $CURRENT_STEP $TOTAL_STEPS "生成自签名证书"
    
    # 创建Hysteria2配置文件目录
    log_message $INFO "创建配置目录"
    mkdir -p /etc/hysteria/
    
    # 检查OpenSSL是否可用
    if ! command -v openssl &> /dev/null; then
        log_message $WARNING "OpenSSL未安装，尝试安装"
        if [ -f "/usr/bin/apt-get" ]; then
            apt-get install -y openssl
        else
            yum install -y openssl
        fi
        
        if ! command -v openssl &> /dev/null; then
            handle_error $ERR_DEPENDENCY "OpenSSL安装失败" 1
            return 1
        }
    }
    
    # 生成自签名TLS证书
    log_message $INFO "生成自签名证书"
    exec_with_check "openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) -keyout /etc/hysteria/server.key -out /etc/hysteria/server.crt -subj \"/CN=bing.com\" -days 36500" \
                   "证书生成成功" "证书生成失败" 0
    
    if [ $? -ne 0 ]; then
        handle_error $ERR_CONFIGURATION "证书生成失败" 1
        return 1
    }
    
    # 设置适当的权限
    log_message $INFO "设置证书权限"
    exec_with_check "chown hysteria /etc/hysteria/server.key && chown hysteria /etc/hysteria/server.crt" \
                   "证书权限设置成功" "证书权限设置失败" 0
    
    if [ $? -ne 0 ]; then
        log_message $WARNING "证书权限设置失败，可能会影响服务运行"
    }
    
    log_message $INFO "证书生成完成"
    return 0
}

# 配置Hysteria2
configure_hy2() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    show_progress $CURRENT_STEP $TOTAL_STEPS "配置 Hysteria2"
    
    # 创建Hysteria2配置文件
    log_message $INFO "创建配置文件"
cat >/etc/hysteria/config.yaml <<EOF
listen: :$getPort
tls:
  cert: /etc/hysteria/server.crt
  key: /etc/hysteria/server.key

auth:
  type: password
  password: $hyPasswd
  
masquerade:
  type: proxy
  proxy:
    url: https://bing.com
    rewriteHost: true
quic:
  initStreamReceiveWindow: 26843545 
  maxStreamReceiveWindow: 26843545 
  initConnReceiveWindow: 67108864 
  maxConnReceiveWindow: 67108864 
EOF

    # 检查配置文件是否创建成功
    if [ ! -e "/etc/hysteria/config.yaml" ]; then
        handle_error $ERR_CONFIGURATION "Hysteria2配置文件创建失败" 0
        return 1
    }
    
    log_message $INFO "配置文件创建成功"
    return 0
}

# 启动Hysteria2服务
start_hy2_service() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    show_progress $CURRENT_STEP $TOTAL_STEPS "启动服务并保存配置"
    
    # 启用并重启Hysteria2服务，然后检查状态
    log_message $INFO "启动Hysteria2服务"
    exec_with_check "systemctl enable hysteria-server.service && systemctl restart hysteria-server.service" \
                   "Hysteria2服务启动成功" "Hysteria2服务启动失败" 0
    
    if [ $? -ne 0 ]; then
        handle_error $ERR_SERVICE "Hysteria2服务启动失败" 0
        
        # 检查服务状态以获取更多信息
        log_message $ERROR "Hysteria2服务状态:"
        systemctl status --no-pager hysteria-server.service
        
        return 1
    }
    
    # 检查服务是否正常运行
    if ! systemctl is-active --quiet hysteria-server.service; then
        handle_error $ERR_SERVICE "Hysteria2服务未正常运行" 0
        return 1
    }
    
    # 删除安装脚本
    cleanup_files "${SCRIPT_DIR}/tcp-wss.sh" "${SCRIPT_DIR}/hy2.sh"
    
    # 获取服务器IP
    server_ip=$(get_ip)
    
    # 保存客户端配置信息到文件
    log_message $INFO "保存客户端配置信息"
cat >/etc/hysteria/hyclient.json<<EOF
{
===========配置参数=============
代理模式：Hysteria2
地址：${server_ip}
端口：${getPort}
密码：${hyPasswd}
SNI：bing.com
传输协议：tls
跳过证书验证：ture
====================================
hysteria2://$(echo -n "${hyPasswd}@${server_ip}:${getPort}/?insecure=1&sni=bing.com#1024-Hysteria2")
}
EOF

    log_message $INFO "服务启动和配置保存完成"
    clear
    return 0
}

# 显示客户端配置信息
client_hy2(){
    # 获取服务器IP
    server_ip=$(get_ip)
    
    # 生成Hysteria2客户端配置链接
    hylink=$(echo -n "${hyPasswd}@${server_ip}:${getPort}/?insecure=1&sni=bing.com#1024-Hysteria2")

    # 构建配置信息字符串
    config=$(cat <<EOF
地址：${server_ip}
端口：${getPort}
密码：${hyPasswd}
SNI：bing.com
传输协议：tls
打开跳过证书验证，true
EOF
)

    # 使用共享库函数显示配置信息
    print_config "Hysteria2" "$config" "hysteria2://${hylink}"
}

# 主函数
main() {
    # 设置错误处理为严格模式
    set_auto_exit 1
    
    # 初始化日志
    init_log clear
    
    log_message $INFO "开始安装 Hysteria2"
    
    # 执行安装步骤
    prepare_environment && \
    install_hy2 && \
    generate_certificate && \
    configure_hy2 && \
    start_hy2_service
    
    # 检查安装结果
    if [ $? -eq 0 ]; then
        log_message $INFO "Hysteria2 安装成功"
        client_hy2
    else
        log_message $ERROR "Hysteria2 安装失败，请查看日志: $LOG_FILE"
        echo
        echo "安装失败，请查看日志文件: $LOG_FILE"
        echo
        return 1
    fi
    
    return 0
}

# 执行主函数
main