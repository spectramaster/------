#!/bin/sh
# 论坛链接: https://1024.day
# 脚本名称: ws.sh
# 脚本功能: 安装纯WebSocket模式的V2Ray代理服务（不带TLS加密）
# 创建日期: 2025年4月13日
# 支持系统: Debian, Ubuntu, CentOS 7及以上
# 特点: 简单轻量配置，不需要域名和SSL证书

# 引入共享库，并设置错误处理
. ./common.sh || { echo "Error: common.sh not found or failed to source."; exit 1; }

# 执行初始化检查
check_root
# 设置系统时区
set_timezone

# 设置V2Ray服务参数
echo "Generating V2Ray (WebSocket only) parameters..."
v2uuid=$(gen_uuid)
v2path=$(gen_path)
v2port=$(gen_port)
echo "UUID: $v2uuid"
echo "Path: /$v2path"
echo "Port: $v2port"
echo "Parameters generated."

# 安装和配置V2Ray的函数
install_v2ray(){
    # 安装基本工具
    install_base

    echo "Installing V2Ray..."
    # 使用安全函数执行官方脚本安装 V2Ray
    safe_run_remote_script "https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh" "V2Ray"
    
    # 检查 V2Ray 是否安装成功
    command -v /usr/local/bin/v2ray > /dev/null || error_exit "V2Ray installation failed or '/usr/local/bin/v2ray' not found."

    echo "Creating V2Ray configuration file (WebSocket only)..."
# 创建V2Ray配置文件
cat >/usr/local/etc/v2ray/config.json<<EOF || error_exit "Failed to write V2Ray config file."
{
  "log": {
    "loglevel": "warning" 
  },
  "inbounds": [
    {
      "listen": "0.0.0.0", # 监听所有接口
      "port": $v2port,
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "$v2uuid",
            "alterId": 0 # Recommended value
          }
        ],
        "disableInsecureEncryption": false # Allow insecure methods if needed, consider security
      },
      "streamSettings": {
        "network": "ws",
        "security": "none", # No TLS
        "wsSettings": {
          "path": "/$v2path"
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    },
    {
      "protocol": "blackhole",
      "settings": {},
      "tag": "blocked"
    }
  ]
}
EOF
    echo "V2Ray configuration file created."

    # 启用并启动V2Ray服务
    enable_service v2ray

    # 清理安装文件 (仅清理此脚本自身)
    clean_files ws.sh

    echo "Getting server IP address..."
    serverIP=$(getIP)
    if [[ -z "$serverIP" ]]; then
        error_exit "Failed to get server IP address. Cannot generate client config."
    fi
    # 导出供 client_v2ray 使用
    export WS_SERVER_IP=$serverIP 
    export WS_PORT=$v2port
    export WS_UUID=$v2uuid
    export WS_PATH=$v2path

    echo "Creating V2Ray client configuration file template..."
# 创建客户端配置文件
cat >/usr/local/etc/v2ray/client.json<<EOF || error_exit "Failed to write V2Ray client config file."
{
===========配置参数 (V2RayN/V2RayNG 格式)=============
协议(Protocol)：VMess
地址(Address)：${serverIP}
端口(Port)：${v2port}
用户ID(UUID)：${v2uuid}
额外ID(AlterID)：0
加密方式(Security)：auto (建议客户端选 aes-128-gcm 或 none)
传输协议(Network)：ws
伪装类型(Type)：none
伪装域名/主机(Host)：(可留空或填服务器IP)
路径(Path)：/${v2path}
底层传输安全(TLS)：none

====================================
(以下是 VMess 链接)
请将下方链接复制到 V2Ray 客户端导入：
vmess://$(echo -n "{\"v\":\"2\",\"ps\":\"1024-ws-${serverIP}\",\"add\":\"${serverIP}\",\"port\":\"${v2port}\",\"id\":\"${v2uuid}\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"\",\"path\":\"/${v2path}\",\"tls\":\"\"}" | base64 -w 0)
}
EOF
    echo "Client configuration template saved to /usr/local/etc/v2ray/client.json"

    # 清屏
    clear
}

# 输出客户端配置信息的函数
client_v2ray(){
    # 从环境变量获取参数
    local serverIP=${WS_SERVER_IP:?}
    local v2port=${WS_PORT:?}
    local v2uuid=${WS_UUID:?}
    local v2path=${WS_PATH:?}

    # 生成V2Ray连接链接
    local vmess_config="{\"v\":\"2\",\"ps\":\"1024-ws-${serverIP}\",\"add\":\"${serverIP}\",\"port\":\"${v2port}\",\"id\":\"${v2uuid}\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"\",\"path\":\"/${v2path}\",\"tls\":\"\"}"
    local wslink=$(echo -n "${vmess_config}" | base64 -w 0) || echo "Warning: Failed to generate base64 VMess link." >&2

    show_completion
    echo "===========V2Ray (VMess+WS only) Configuration============"
    echo "Protocol：VMess"
    echo "Address：${serverIP}"
    echo "Port：${v2port}"
    echo "UUID：${v2uuid}"
    echo "AlterID：0"
    echo "Security：auto (建议客户端选 aes-128-gcm 或 none)"
    echo "Network：ws"
    echo "Host：(Leave blank or use server IP)"
    echo "Path：/${v2path}"
    echo "TLS：none"
    echo "====================================================="
    if [[ -n "$wslink" ]]; then
        echo "Client URI (Import this link into V2RayN/V2RayNG etc.):"
        echo "vmess://${wslink}"
    else
        echo "VMess link generation failed. Please configure manually using the parameters above."
    fi
    echo "Client configuration template saved to: /usr/local/etc/v2ray/client.json"
    echo
}

# 执行安装和配置函数
install_v2ray
client_v2ray

echo "V2Ray (WebSocket only) installation script finished."