#!/bin/sh
# forum: https://1024.day
# 这是一个用于安装 Hysteria2 代理服务的脚本
# Hysteria2 是基于 QUIC 协议的高性能代理，抗干扰能力强

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
hyPasswd=$(random_uuid)
getPort=$(random_port)

# 安装Hysteria2
install_hy2(){
    # 使用共享库函数安装基本软件包
    install_base_packages >/dev/null
    
    # 从Hysteria2官方仓库下载并运行安装脚本
    bash <(curl -fsSL https://get.hy2.sh/)
    
    # 创建Hysteria2配置文件目录
    mkdir -p /etc/hysteria/
    
    # 生成自签名TLS证书
    openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) -keyout /etc/hysteria/server.key -out /etc/hysteria/server.crt -subj "/CN=bing.com" -days 36500 && chown hysteria /etc/hysteria/server.key && chown hysteria /etc/hysteria/server.crt

    # 创建Hysteria2配置文件
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

    # 启用并重启Hysteria2服务，然后检查状态
    systemctl enable hysteria-server.service && systemctl restart hysteria-server.service && systemctl status --no-pager hysteria-server.service
    # 删除安装脚本
    cleanup_files "${SCRIPT_DIR}/tcp-wss.sh" "${SCRIPT_DIR}/hy2.sh"

    # 获取服务器IP
    server_ip=$(get_ip)
    
    # 保存客户端配置信息到文件
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

    clear
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

# 执行安装流程
install_hy2
client_hy2