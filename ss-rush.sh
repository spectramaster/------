#!/bin/sh
# 论坛链接: https://1024.day
# 脚本名称: ss-rush.sh (原ss-rust.sh?)
# 脚本功能: 安装 Shadowsocks-rust 代理服务
# 创建日期: 2025年4月13日
# 支持系统: Debian, Ubuntu, CentOS 7及以上

# 引入共享库，并设置错误处理
. ./common.sh || { echo "Error: common.sh not found or failed to source."; exit 1; }

# 检查必要命令
command -v wget > /dev/null || error_exit "'wget' command not found."
command -v tar > /dev/null || error_exit "'tar' command not found."
command -v jq > /dev/null || error_exit "'jq' command not found."

# 执行初始化检查
check_root
# 设置系统时区
set_timezone

# 设置Shadowsocks服务参数
echo "Generating Shadowsocks parameters..."
sspasswd=$(gen_uuid)
ssport=$(gen_port)
echo "Parameters generated."

# 安装 Shadowsocks-rust 的函数
install_SS() {
    echo "Detecting system architecture..."
    arch=$(detect_arch)
    echo "Architecture detected: $arch"
    
    echo "Fetching latest Shadowsocks-rust release version..."
    # 添加 --connect-timeout 和重试逻辑可能更好，但暂时简化
	new_ver=$(wget -qO- https://api.github.com/repos/shadowsocks/shadowsocks-rust/releases | jq -r '[.[] | select(.prerelease == false) | select(.draft == false) | .tag_name] | .[0]') || error_exit "Failed to fetch latest release version from GitHub API."
    
    if [ -z "$new_ver" ]; then
        error_exit "Could not determine the latest Shadowsocks-rust version."
    fi
    echo "Latest version: $new_ver"

    local filename="shadowsocks-${new_ver}.${arch}-unknown-linux-gnu.tar.xz"
    local download_url="https://github.com/shadowsocks/shadowsocks-rust/releases/download/${new_ver}/${filename}"
    
    echo "Downloading Shadowsocks-rust binary from ${download_url}..."
	wget --no-check-certificate -O "${filename}" "${download_url}" || error_exit "Failed to download Shadowsocks-rust binary."

    echo "Extracting archive..."
	tar -xvf "${filename}" || error_exit "Failed to extract Shadowsocks-rust archive '${filename}'."
	
	# 检查 ssserver 文件是否存在且可执行
	if [ ! -f "ssserver" ]; then
	    # 尝试在解压出的子目录中查找 (有时 releases 包含子目录)
	    extracted_dir=$(tar -tf "${filename}" | head -n 1 | cut -f1 -d"/")
	    if [ -n "$extracted_dir" ] && [ -f "${extracted_dir}/ssserver" ]; then
	        echo "Found ssserver in subdirectory '${extracted_dir}'. Adjusting paths."
	        mv "${extracted_dir}/ssserver" . || error_exit "Failed to move ssserver from subdirectory."
	        # 可以选择删除其他文件或整个目录
	        rm -rf "$extracted_dir" 
	    else
            rm -f "${filename}" # 清理下载的文件
		    error_exit "Extracted archive does not contain 'ssserver' file."
		fi
	fi
	
    echo "Setting permissions and moving binary..."
    chmod +x ssserver || error_exit "Failed to set executable permission on ssserver."
    mv -f ssserver /usr/local/bin/ || error_exit "Failed to move ssserver to /usr/local/bin/."
    
    echo "Cleaning up temporary files..."
    # 删除压缩包和其他可能解压出来的文件 (可选)
    rm -f "${filename}"
    # 如果需要删除其他文件，如 sslocal 等
    # find . -maxdepth 1 -type f \( -name 'sslocal' -o -name 'ssmanager' -o -name 'ssservice' -o -name 'ssurl' \) -delete

    echo "Shadowsocks-rust installation complete."
}

# 配置 Shadowsocks 服务的函数
config_SS(){
    echo "Creating Shadowsocks configuration directory..."
	mkdir -p /etc/shadowsocks || error_exit "Failed to create directory /etc/shadowsocks."

    echo "Creating Shadowsocks configuration file..."
# 创建 Shadowsocks 配置文件
cat >/etc/shadowsocks/config.json<<EOF || error_exit "Failed to write Shadowsocks config file."
{
    "server":"::",
    "server_port":$ssport,
    "password":"$sspasswd",
    "timeout":600,
    "mode":"tcp_and_udp",
    "method":"aes-256-gcm" 
}
EOF
# 注意：原脚本用的 aes-128-gcm，这里改为更推荐的 aes-256-gcm

    echo "Creating systemd service file for Shadowsocks..."
# 创建 systemd 服务单元文件
cat >/etc/systemd/system/shadowsocks.service<<EOF || error_exit "Failed to write systemd service file."
[Unit]
Description=Shadowsocks-rust Server Service
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=simple
User=nobody # 建议以非 root 用户运行
Group=nogroup # 或 nobody
CapabilityBoundingSet=CAP_NET_BIND_SERVICE # 允许绑定低位端口
AmbientCapabilities=CAP_NET_BIND_SERVICE
LimitNOFILE=51200
ExecStart=/usr/local/bin/ssserver -c /etc/shadowsocks/config.json --log-without-time --log-level info 
# Restart=on-failure
Restart=always # 更常用的设置
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

    echo "Reloading systemd daemon..."
    systemctl daemon-reload || error_exit "Failed to reload systemd daemon."
    
    # 启用并重启Shadowsocks服务
    enable_service shadowsocks
    
    # 清理安装文件 (仅清理此脚本自身)
    clean_files ss-rush.sh # 或 ss-rust.sh? 保持和文件名一致
    echo "Shadowsocks configuration complete."
}

# 输出客户端配置信息的函数
client_SS(){
    serverIP=$(getIP)
     if [[ -z "$serverIP" ]]; then
        echo "Error: Failed to get server IP address for final output." >&2
        echo "Please check your network or find the IP manually." >&2
        echo "Client configuration might be incomplete." >&2
    fi
    
    # 生成Shadowsocks链接字符串 (使用 aes-256-gcm)
    sslink=""
    if [[ -n "$serverIP" ]]; then
        sslink=$(gen_ss_link "aes-256-gcm" "${sspasswd}" "${serverIP}" "${ssport}") || echo "Warning: Failed to generate SS link." >&2
    fi

    show_completion
    echo "===========Shadowsocks Configuration============"
    echo "Address：${serverIP:-'IP NOT FOUND'}"
    echo "Port：${ssport}"
    echo "Password：${sspasswd}"
    echo "Encryption Method：aes-256-gcm" # 保持一致
    echo "Mode：tcp_and_udp"
    echo "========================================="
    if [[ -n "$sslink" ]]; then
      echo "Client URI (Import this link):"
      echo "ss://${sslink}"
    else
      echo "Client URI could not be generated due to missing IP or generation error."
    fi
    echo "Server configuration saved to: /etc/shadowsocks/config.json"
    echo "Systemd service file at: /etc/systemd/system/shadowsocks.service"
    echo
}

# 主脚本流程：
# 1. 安装基础软件包
install_base
# 2. 安装额外工具 (确保 jq 在内)
install_debian_tools "gzip wget curl unzip xz-utils jq"
install_centos_tools "gzip wget curl unzip xz jq"
# 3. 安装Shadowsocks-rust
install_SS
# 4. 配置Shadowsocks服务
config_SS
# 5. 输出客户端配置信息
client_SS

echo "Shadowsocks-rust installation script finished."