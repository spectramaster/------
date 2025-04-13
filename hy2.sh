#!/bin/sh
# 论坛链接: https://1024.day
# 脚本名称: hy2.sh
# 脚本功能: 安装 Hysteria2 代理服务
# 创建日期: 2025年4月13日
# 支持系统: Debian, Ubuntu, CentOS 7及以上

# 引入共享库，并设置错误处理
# common.sh 内部已经包含了 set -e
. ./common.sh || { echo "Error: common.sh not found or failed to source."; exit 1; }

# 检查 command -v openssl 是否可用
command -v openssl > /dev/null || error_exit "'openssl' command is required but not found. Please install it."

# 执行初始化检查
check_root
# 设置系统时区
set_timezone

# 设置Hysteria2服务参数
echo "Generating Hysteria2 parameters..."
hyPasswd=$(gen_uuid)
getPort=$(gen_port)
echo "Parameters generated."

# 安装 Hysteria2 的主函数
install_hy2(){
    # 安装基本依赖包
    install_base
    
    # 使用安全函数执行官方脚本安装 Hysteria2
    safe_run_remote_script "https://get.hy2.sh/" "Hysteria2"
    
    echo "Creating Hysteria2 configuration directory..."
    mkdir -p /etc/hysteria/ || error_exit "Failed to create directory /etc/hysteria/."
    
    echo "Generating self-signed TLS certificate..."
    # 生成自签名TLS证书
    openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) -keyout /etc/hysteria/server.key -out /etc/hysteria/server.crt -subj "/CN=bing.com" -days 36500 || error_exit "Failed to generate TLS certificate."
    
    # 尝试设置文件所有权，如果 hysteria 用户不存在则忽略错误
    chown hysteria /etc/hysteria/server.key || echo "Warning: User 'hysteria' not found, skipping chown for server.key." >&2
    chown hysteria /etc/hysteria/server.crt || echo "Warning: User 'hysteria' not found, skipping chown for server.crt." >&2
    echo "Certificate generated."

    echo "Creating Hysteria2 server configuration file..."
# 创建 Hysteria2 服务器配置文件
cat >/etc/hysteria/config.yaml <<EOF || error_exit "Failed to write Hysteria2 config file."
# 监听端口，格式为 :端口号
listen: :$getPort
# TLS证书配置
tls:
  cert: /etc/hysteria/server.crt
  key: /etc/hysteria/server.key

# 认证配置
auth:
  type: password
  password: $hyPasswd
  
# 伪装配置，用于绕过DPI检测
masquerade:
  type: proxy
  proxy:
    url: https://bing.com
    rewriteHost: true
# QUIC协议参数配置，用于优化性能
quic:
  initStreamReceiveWindow: 26843545 
  maxStreamReceiveWindow: 26843545 
  initConnReceiveWindow: 67108864 
  maxConnReceiveWindow: 67108864 
EOF
    echo "Server configuration file created."

    # 启用并重启Hysteria2服务
    enable_service hysteria-server 
    echo "Checking Hysteria2 service status..."
    # 显示状态，但不因状态命令失败而退出
    systemctl status --no-pager hysteria-server.service || echo "Warning: Could not get hysteria-server status." >&2
    
    # 清理安装文件 (仅清理此脚本自身)
    clean_files hy2.sh

    echo "Getting server IP address..."
    serverIP=$(getIP)
    if [[ -z "$serverIP" ]]; then
        error_exit "Failed to get server IP address. Cannot generate client config."
    fi

    echo "Creating Hysteria2 client configuration file..."
# 创建客户端配置文件
cat >/etc/hysteria/hyclient.json<<EOF || error_exit "Failed to write Hysteria2 client config file."
{
===========配置参数=============
代理模式：Hysteria2
地址：${serverIP}
端口：${getPort}
密码：${hyPasswd}
SNI：bing.com
传输协议：tls
跳过证书验证：ture
====================================
hysteria2://$(echo -n "${hyPasswd}@${serverIP}:${getPort}/?insecure=1&sni=bing.com#1024-Hysteria2")
}
EOF
    echo "Client configuration file created at /etc/hysteria/hyclient.json"

    # 清屏，准备显示客户端配置信息
    clear
}

# 输出客户端配置信息的函数
client_hy2(){
    # 获取IP可能失败，进行检查
    serverIP=$(getIP)
    if [[ -z "$serverIP" ]]; then
        echo "Error: Failed to get server IP address for final output." >&2
        echo "Please check your network or find the IP manually." >&2
        echo "Client configuration might be incomplete in /etc/hysteria/hyclient.json" >&2
        # 不退出，但显示警告
    fi
    
    # 生成 Hysteria2 连接链接 (如果IP获取失败，链接会不完整)
    hylink=""
    if [[ -n "$serverIP" ]]; then
      hylink=$(echo -n "${hyPasswd}@${serverIP}:${getPort}/?insecure=1&sni=bing.com#1024-Hysteria2")
    fi

    show_completion
    echo "===========Hysteria2 Configuration============"
    echo
    echo "Address：${serverIP:-'IP NOT FOUND'}"
    echo "Port：${getPort}"
    echo "Password：${hyPasswd}"
    echo "SNI：bing.com"
    echo "Transport Protocol：tls"
    echo "Skip Certificate Verification：true"
    echo
    echo "========================================="
    if [[ -n "$hylink" ]]; then
      echo "Client URI (Import this link):"
      echo "hysteria2://${hylink}"
    else
      echo "Client URI could not be generated due to missing IP."
    fi
    echo "Client configuration saved to: /etc/hysteria/hyclient.json"
    echo
}

# 执行安装和配置函数
install_hy2
client_hy2

echo "Hysteria2 installation script finished."