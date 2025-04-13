#!/bin/sh
# 论坛链接: https://1024.day
# 脚本名称: ss-rust.sh
# 脚本功能: 安装 Shadowsocks-rust 代理服务
# 创建日期: 2025年4月13日
# 支持系统: Debian, Ubuntu, CentOS 7及以上

# 引入共享库，使用点号引入脚本，这样可以在当前shell环境中执行
. ./common.sh

# 执行初始化检查，确保脚本以root权限运行
check_root
# 设置系统时区为亚洲/上海
set_timezone

# 设置Shadowsocks服务参数
# 使用UUID作为密码，提供较高的安全性
sspasswd=$(gen_uuid)
# 随机生成一个2000-65000范围内的端口号
ssport=$(gen_port)

# 安装 Shadowsocks-rust 的函数
install_SS() {
    # 获取系统架构信息
    arch=$(detect_arch)
    # 从GitHub API获取最新的Shadowsocks-rust版本号
	new_ver=$(wget -qO- https://api.github.com/repos/shadowsocks/shadowsocks-rust/releases| jq -r '[.[] | select(.prerelease == false) | select(.draft == false) | .tag_name] | .[0]')

    # 下载匹配当前系统架构的Shadowsocks-rust二进制文件
	wget --no-check-certificate -N "https://github.com/shadowsocks/shadowsocks-rust/releases/download/${new_ver}/shadowsocks-${new_ver}.${arch}-unknown-linux-gnu.tar.xz"
	# 检查下载是否成功
	if [[ ! -e "shadowsocks-${new_ver}.${arch}-unknown-linux-gnu.tar.xz" ]]; then
		echo -e "${Error} Shadowsocks Rust 官方源下载失败！"
		return 1 && exit 1
	else
	    # 解压下载的压缩包
		tar -xvf "shadowsocks-${new_ver}.${arch}-unknown-linux-gnu.tar.xz"
	fi
	
	# 检查解压后是否存在ssserver程序
	if [[ ! -e "ssserver" ]]; then
		echo -e "${Error} Shadowsocks Rust 解压失败！"
		echo -e "${Error} Shadowsocks Rust 安装失败 !"
		return 1 && exit 1
	else
	    # 删除下载的压缩包
		rm -rf "shadowsocks-${new_ver}.${arch}-unknown-linux-gnu.tar.xz"
        # 设置ssserver可执行权限
        chmod +x ssserver
        # 将ssserver移动到/usr/local/bin目录下
	    mv -f ssserver /usr/local/bin/
	    # 删除其他无用的可执行文件
	    rm sslocal ssmanager ssservice ssurl

        echo -e "${Info} Shadowsocks Rust 主程序下载安装完毕！"
		return 0
	fi
}

# 配置 Shadowsocks 服务的函数
config_SS(){
    # 创建配置目录
	mkdir -p /etc/shadowsocks

# 创建 Shadowsocks 配置文件，设置监听、密码和加密方式
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

# 创建 Shadowsocks 服务单元文件，用于systemd管理
cat >/etc/systemd/system/shadowsocks.service<<EOF
[Unit]
Description=Shadowsocks Server
After=network.target

[Service]
ExecStart=/usr/local/bin/ssserver -c /etc/shadowsocks/config.json

Restart=on-abort

[Install]
WantedBy=multi-user.target
EOF

    # 重新加载systemd配置
    systemctl daemon-reload 
    # 启用并重启Shadowsocks服务
    enable_service shadowsocks
    # 清理安装文件
    clean_files ss-rust.sh
}

# 输出客户端配置信息的函数
client_SS(){
    # 获取服务器IP地址
    serverIP=$(getIP)
    # 生成Shadowsocks链接字符串
    sslink=$(gen_ss_link "aes-128-gcm" "${sspasswd}" "${serverIP}" "${ssport}")

    # 显示安装完成信息
    show_completion
    # 输出Shadowsocks配置参数
    echo "===========Shadowsocks配置参数============"
    echo "地址：${serverIP}"
    echo "端口：${ssport}"
    echo "密码：${sspasswd}"
    echo "加密方式：aes-128-gcm"
    echo "传输协议：tcp+udp"
    echo "========================================="
    # 输出客户端可直接导入的URI链接
    echo "ss://${sslink}"
    echo
}

# 主脚本流程：
# 1. 安装基础软件包
install_base
# 2. 安装Debian/Ubuntu系统所需的额外工具
install_debian_tools "gzip wget curl unzip xz-utils jq"
# 3. 安装CentOS系统所需的额外工具
install_centos_tools "gzip wget curl unzip xz jq"
# 4. 安装Shadowsocks-rust
install_SS
# 5. 配置Shadowsocks服务
config_SS
# 6. 输出客户端配置信息
client_SS