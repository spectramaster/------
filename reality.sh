#!/bin/sh
# forum: https://1024.day
# 这是一个用于安装 Xray Reality 代理服务的脚本
# Reality是一种新型的代理协议，无需域名和证书，安全性高

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

# 生成随机UUID作为用户标识
v2uuid=$(random_uuid)

# 提示用户输入端口号，15秒内无输入则默认使用443端口
read -t 15 -p "回车或等待15秒为默认端口443，或者自定义端口请输入(1-65535)："  getPort
if [ -z $getPort ];then
    getPort=443
fi

# 安装Xray
install_xray(){ 
    # 使用共享库函数安装基本软件包
    install_base_packages >/dev/null
    
    # 从Xray官方仓库下载并运行安装脚本
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
}

# 配置Reality
reconfig(){
    # 生成X25519密钥对（Reality所需的身份认证密钥）
    reX25519Key=$(/usr/local/bin/xray x25519)
    rePrivateKey=$(echo "${reX25519Key}" | head -1 | awk '{print $3}')
    rePublicKey=$(echo "${reX25519Key}" | tail -n 1 | awk '{print $3}')

    # 创建Xray配置文件
cat >/usr/local/etc/xray/config.json<<EOF
{
    "inbounds": [
        {
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
                    "maxTimeDiff": 0,
                    "shortIds": [
                        "88",
                        "123abc"
                    ]
                }
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

    # 启用并重启Xray服务
    systemctl enable xray.service && systemctl restart xray.service
    # 删除安装脚本
    cleanup_files "${SCRIPT_DIR}/tcp-wss.sh" "${SCRIPT_DIR}/install-release.sh" "${SCRIPT_DIR}/reality.sh"

    # 获取服务器IP
    server_ip=$(get_ip)
    
    # 保存客户端配置信息到文件
cat >/usr/local/etc/xray/reclient.json<<EOF
{
===========配置参数=============
代理模式：vless
地址：${server_ip}
端口：${getPort}
UUID：${v2uuid}
流控：xtls-rprx-vision
传输协议：tcp
Public key：${rePublicKey}
底层传输：reality
SNI: www.amazon.com
shortIds: 88
====================================
vless://${v2uuid}@${server_ip}:${getPort}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.amazon.com&fp=chrome&pbk=${rePublicKey}&sid=88&type=tcp&headerType=none#1024-reality

}
EOF

    clear
}

# 显示客户端配置信息
client_re(){
    # 获取服务器IP
    server_ip=$(get_ip)
    
    # 构建配置信息字符串
    config=$(cat <<EOF
代理模式：vless
地址：${server_ip}
端口：${getPort}
UUID：${v2uuid}
流控：xtls-rprx-vision
传输协议：tcp
Public key：${rePublicKey}
底层传输：reality
SNI: www.amazon.com
shortIds: 88
EOF
)

    # 生成链接
    link="vless://${v2uuid}@${server_ip}:${getPort}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.amazon.com&fp=chrome&pbk=${rePublicKey}&sid=88&type=tcp&headerType=none#1024-reality"
    
    # 使用共享库函数显示配置信息
    print_config "reality" "$config" "$link"
}

# 执行安装流程
install_xray
reconfig
client_re