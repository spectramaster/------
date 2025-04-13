#!/bin/sh
# 论坛链接: https://1024.day
# 脚本名称: reality.sh
# 脚本功能: 安装 XTLS Reality 代理服务
# 创建日期: 2025年4月13日
# 支持系统: Debian, Ubuntu, CentOS 7及以上
# 特点: 无需域名和证书即可使用，利用Reality协议进行伪装和认证

# 引入共享库，并设置错误处理
. ./common.sh || { echo "Error: common.sh not found or failed to source."; exit 1; }

# 执行初始化检查
check_root
# 设置系统时区
set_timezone

# 生成随机 UUID
echo "Generating UUID..."
v2uuid=$(gen_uuid)
echo "UUID generated."

# 交互式设置端口
getPort=443 # Default port
read -t 15 -p "Enter port number (1-65535) [Default: 443, wait 15s]: " inputPort
# 检查输入是否为空，以及是否为纯数字
if [ -n "$inputPort" ]; then
    if ! echo "$inputPort" | grep -qE '^[0-9]+$'; then
        error_exit "Invalid port number entered. Please enter numbers only."
    fi
    if [ "$inputPort" -lt 1 ] || [ "$inputPort" -gt 65535 ]; then
        error_exit "Port number out of range (1-65535)."
    fi
    getPort=$inputPort
    echo "Using custom port: $getPort"
else
    echo "Using default port: 443"
fi

# 安装 Xray-core 的函数
install_xray(){ 
    # 安装基本依赖包
    install_base
    
    # 使用安全函数执行官方脚本安装 Xray
    # 注意：官方脚本可能使用 @ install 传递参数，安全函数不支持直接传递，需要看脚本本身如何处理
    # 检查 install-release.sh 脚本发现它接受命令行参数，所以这样调用应该可以
    echo "Installing Xray-core..."
    safe_run_remote_script "https://github.com/XTLS/Xray-install/raw/main/install-release.sh" "Xray-core"
    
    # 检查 Xray 是否安装成功
    command -v /usr/local/bin/xray > /dev/null || error_exit "Xray installation failed or '/usr/local/bin/xray' not found."
    echo "Xray-core installed successfully."
}

# 配置 Reality 服务的函数
reconfig(){
    echo "Generating Reality key pair..."
    # 生成 X25519 密钥对
    # 检查 xray 命令是否存在
    command -v /usr/local/bin/xray > /dev/null || error_exit "Cannot find xray command at /usr/local/bin/xray to generate keys."
    reX25519Key=$(/usr/local/bin/xray x25519) || error_exit "Failed to generate Reality key pair using 'xray x25519'."
    
    rePrivateKey=$(echo "${reX25519Key}" | head -n 1 | awk '{print $3}')
    rePublicKey=$(echo "${reX25519Key}" | tail -n 1 | awk '{print $3}')
    
    # 简单验证密钥是否看起来有效
    if [ -z "$rePrivateKey" ] || [ -z "$rePublicKey" ]; then
        error_exit "Failed to extract private or public key from 'xray x25519' output."
    fi
    echo "Reality key pair generated."

    echo "Creating Xray configuration file for Reality..."
    # 创建配置目录（如果安装脚本没创建的话）
    mkdir -p /usr/local/etc/xray/ || error_exit "Failed to create directory /usr/local/etc/xray/."

# 创建 Xray 配置文件
cat >/usr/local/etc/xray/config.json<<EOF || error_exit "Failed to write Xray config file."
{
    "log": {
        "loglevel": "warning"
    },
    "inbounds": [
        {
            "listen": "0.0.0.0",
            "port": $getPort,
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "$v2uuid",
                        "flow": "xtls-rprx-vision"
                    }
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "tcp",
                "security": "reality",
                "realitySettings": {
                    "show": false,
                    "dest": "www.amazon.com:443",
                    "xver": 0,
                    "serverNames": [
                        "www.amazon.com",
                        "addons.mozilla.org",
                        "www.un.org",
                        "www.tesla.com"
                    ],
                    "privateKey": "$rePrivateKey",
                    "minClientVer": "",
                    "maxClientVer": "",
                    "maxTimeDiff": 60000,
                    "shortIds": [
                        "", 
                        "0123456789abcdef"
                    ]
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
            "tag": "direct"
        },
        {
            "protocol": "blackhole",
            "tag": "blocked"
        }
    ]    
}
EOF
    echo "Xray configuration file created."

    # 启用并重启 Xray 服务
    enable_service xray
    
    # 清理安装文件 (仅清理此脚本自身)
    # install-release.sh 已经在 safe_run_remote_script 中被清理
    clean_files reality.sh

    echo "Getting server IP address..."
    serverIP=$(getIP)
     if [[ -z "$serverIP" ]]; then
        error_exit "Failed to get server IP address. Cannot generate client config."
    fi

    echo "Creating Reality client configuration file..."
# 创建客户端配置文件
cat >/usr/local/etc/xray/reclient.json<<EOF || error_exit "Failed to write Reality client config file."
{
===========配置参数=============
代理模式：vless
地址：${serverIP}
端口：${getPort}
UUID：${v2uuid}
流控：xtls-rprx-vision
传输协议：tcp
Public key：${rePublicKey}
底层传输：reality
SNI: www.amazon.com
shortIds: (空字符串或0123456789abcdef，取决于你的客户端)
指纹：chrome (或其他，如firefox, safari, edge, random)
====================================
vless://${v2uuid}@${serverIP}:${getPort}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.amazon.com&fp=chrome&pbk=${rePublicKey}&sid=0123456789abcdef&type=tcp&headerType=none#1024-reality

(请根据需要修改fp指纹和sid)
}
EOF
    echo "Client configuration file created at /usr/local/etc/xray/reclient.json"

    # 清屏，准备显示客户端配置信息
    clear
}

# 输出客户端配置信息的函数
client_re(){
    serverIP=$(getIP)
    if [[ -z "$serverIP" ]]; then
        echo "Error: Failed to get server IP address for final output." >&2
        echo "Please check your network or find the IP manually." >&2
        echo "Client configuration might be incomplete in /usr/local/etc/xray/reclient.json" >&2
    fi
    
    show_completion
    echo "===========Reality Configuration============"
    echo "Proxy Mode：vless"
    echo "Address：${serverIP:-'IP NOT FOUND'}"
    echo "Port：${getPort}"
    echo "UUID：${v2uuid}"
    echo "Flow Control：xtls-rprx-vision"
    echo "Transport Protocol：tcp"
    echo "Public key：${rePublicKey}"
    echo "Security：reality"
    echo "SNI: www.amazon.com"
    echo "shortIds: (空字符串或0123456789abcdef)"
    echo "Fingerprint (fp): chrome (建议根据客户端修改)"
    echo "===================================="
    if [[ -n "$serverIP" ]]; then
        echo "Client URI (Import this link, maybe adjust fp/sid):"
        echo "vless://${v2uuid}@${serverIP}:${getPort}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.amazon.com&fp=chrome&pbk=${rePublicKey}&sid=0123456789abcdef&type=tcp&headerType=none#1024-reality"
    else
        echo "Client URI could not be generated due to missing IP."
    fi
    echo "Client configuration saved to: /usr/local/etc/xray/reclient.json"
    echo
}

# 执行安装和配置函数
install_xray
reconfig
client_re

echo "Reality installation script finished."