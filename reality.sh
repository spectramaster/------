#!/bin/sh
# 论坛链接: https://1024.day
# 脚本名称: reality.sh
# 脚本功能: 安装 XTLS Reality 代理服务
# 创建日期: 2025年4月13日
# 支持系统: Debian, Ubuntu, CentOS 7及以上
# 特点: 无需域名和证书即可使用，利用Reality协议进行伪装和认证

# 引入共享库，使用点号引入脚本，这样可以在当前shell环境中执行
. ./common.sh

# 执行初始化检查，确保脚本以root权限运行
check_root
# 设置系统时区为亚洲/上海
set_timezone

# 生成随机 UUID (用于客户端认证)
v2uuid=$(gen_uuid)

# 交互式设置端口，等待15秒，默认为443
# -t 15 设置等待用户输入的超时时间为15秒
# -p 后跟提示信息
read -t 15 -p "回车或等待15秒为默认端口443，或者自定义端口请输入(1-65535)："  getPort
# 检查用户是否提供了端口号，如果没有则使用默认值443
if [ -z $getPort ];then
    getPort=443
fi

# 安装 Xray-core 的函数
install_xray(){ 
    # 安装基本依赖包
    install_base
    
    # 使用官方脚本安装 Xray
    # @ 符号用于传递参数给bash -c执行的脚本
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
}

# 配置 Reality 服务的函数
reconfig(){
    # 生成 X25519 密钥对 (Reality 协议所需)
    # 使用 Xray 内置工具生成 X25519 密钥对
    reX25519Key=$(/usr/local/bin/xray x25519)
    # 提取私钥 (第一行，第三列)
    rePrivateKey=$(echo "${reX25519Key}" | head -1 | awk '{print $3}')
    # 提取公钥 (最后一行，第三列)
    rePublicKey=$(echo "${reX25519Key}" | tail -n 1 | awk '{print $3}')

# 创建 Xray 配置文件，使用 Reality 协议
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

    # 启用并重启 Xray 服务
    enable_service xray
    
    # 清理安装文件
    clean_files install-release.sh reality.sh

    # 获取服务器IP地址
    serverIP=$(getIP)

# 创建客户端配置文件 (保存客户端连接信息)
cat >/usr/local/etc/xray/reclient.json<<EOF
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
shortIds: 88
====================================
vless://${v2uuid}@${serverIP}:${getPort}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.amazon.com&fp=chrome&pbk=${rePublicKey}&sid=88&type=tcp&headerType=none#1024-reality

}
EOF

    # 清屏，准备显示客户端配置信息
    clear
}

# 输出客户端配置信息的函数
client_re(){
    # 获取服务器IP地址
    serverIP=$(getIP)
    
    # 显示安装完成信息
    show_completion
    # 输出Reality配置参数
    echo "===========reality配置参数============"
    echo "代理模式：vless"
    echo "地址：${serverIP}"
    echo "端口：${getPort}"
    echo "UUID：${v2uuid}"
    echo "流控：xtls-rprx-vision"
    echo "传输协议：tcp"
    echo "Public key：${rePublicKey}"
    echo "底层传输：reality"
    echo "SNI: www.amazon.com"
    echo "shortIds: 88"
    echo "===================================="
    # 输出客户端可直接导入的URI链接
    echo "vless://${v2uuid}@${serverIP}:${getPort}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.amazon.com&fp=chrome&pbk=${rePublicKey}&sid=88&type=tcp&headerType=none#1024-reality"
    echo
}

# 执行安装和配置函数
install_xray
reconfig
client_re