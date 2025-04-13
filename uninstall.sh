#!/bin/sh
# uninstall.sh - 用于卸载由脚本集安装的 VPN 服务的卸载脚本
# 论坛: https://1024.day

# --- 基本设置 ---
set -e # 发生错误时退出

error_exit() {
    echo "错误: $1" 1>&2
    exit 1
}

# 检查 root 权限
if [ "$(id -u)" -ne 0 ]; then
   error_exit "此脚本必须以 root 权限运行。"
fi

# --- 辅助函数 ---

# 检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 如果 systemd 服务存在且是活动/启用的，则停止并禁用它
stop_disable_service() {
    local service_name="$1"
    echo "处理服务: ${service_name}..."
    # 使用 systemctl list-unit-files 检查服务是否存在
    if systemctl list-unit-files | grep -qw "${service_name}.service"; then
        echo "找到服务。正在停止和禁用..."
        systemctl stop "${service_name}" || echo " - 服务已停止或停止失败。" >&2
        systemctl disable "${service_name}" || echo " - 服务已禁用或禁用失败。" >&2
    else
        echo " - 未找到服务 ${service_name}.service。"
    fi
}

# 如果文件或目录存在，则删除它
remove_path() {
    local path_to_remove="$1"
    if [ -e "$path_to_remove" ]; then
        echo "正在删除 ${path_to_remove}..."
        rm -rf "$path_to_remove" || echo "警告: 删除 ${path_to_remove} 失败。" >&2
    else
        echo "路径 ${path_to_remove} 未找到。跳过删除。"
    fi
}

# 询问用户确认
confirm_action() {
    local message="$1"
    local response=""
    read -p "${message} [y/N]: " response
    case "$response" in
        [yY][eE][sS]|[yY])
            return 0 # 已确认
            ;;
        *)
            return 1 # 未确认
            ;;
    esac
}

# 获取包管理器类型
get_pkg_manager() {
    if command_exists apt-get; then
        echo "apt"
    elif command_exists yum; then
        echo "yum"
    else
        echo "unknown"
    fi
}

# 如果软件包已安装，则清除/删除它
remove_package() {
    local pkg_name="$1"
    local pkg_manager=$(get_pkg_manager)
    local installed=1 # 初始假设未安装

    echo "检查软件包: $pkg_name"
    if [ "$pkg_manager" = "apt" ]; then
        dpkg -s "$pkg_name" >/dev/null 2>&1 && installed=0
        if [ "$installed" -eq 0 ]; then
            if confirm_action "找到软件包 '$pkg_name'。是否要清除它(purge)?"; then
                echo "正在清除 $pkg_name..."
                apt-get purge -y "$pkg_name" || echo "警告: 清除 $pkg_name 失败。" >&2
            fi
        else
            echo "软件包 '$pkg_name' 未安装 (apt)。"
        fi
    elif [ "$pkg_manager" = "yum" ]; then
        rpm -q "$pkg_name" >/dev/null 2>&1 && installed=0
         if [ "$installed" -eq 0 ]; then
            if confirm_action "找到软件包 '$pkg_name'。是否要移除它(remove)?"; then
                echo "正在移除 $pkg_name..."
                yum remove -y "$pkg_name" || echo "警告: 移除 $pkg_name 失败。" >&2
            fi
        else
             echo "软件包 '$pkg_name' 未安装 (yum)。"
        fi
    else
        echo "不支持的包管理器。无法移除软件包 '$pkg_name'。"
    fi
}

# --- 卸载函数 ---

uninstall_ss_rust() {
    echo "--- 开始卸载 Shadowsocks-rust ---"
    stop_disable_service shadowsocks
    remove_path "/usr/local/bin/ssserver"
    remove_path "/etc/systemd/system/shadowsocks.service"
    remove_path "/etc/shadowsocks" # 删除配置目录
    echo "Shadowsocks-rust 卸载过程完成。"
}

uninstall_v2ray_wss() {
    echo "--- 开始卸载 V2Ray + WS + TLS ---"
    stop_disable_service v2ray
    stop_disable_service nginx

    echo "正在运行 V2Ray 官方卸载脚本..."
    if command_exists curl; then
        # 使用官方 remove 命令 - 需要网络连接
        bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh) --remove || echo "警告: V2Ray 官方卸载脚本失败或被中断。" >&2
    else
        echo "警告: 未找到 curl 命令。无法自动运行 V2Ray 官方卸载程序。"
        echo "尝试手动删除常见路径..."
         remove_path "/usr/local/bin/v2ray"
         remove_path "/usr/local/bin/v2ctl"
         remove_path "/usr/local/etc/v2ray"
         remove_path "/usr/local/share/v2ray"
         remove_path "/etc/systemd/system/v2ray.service"
         remove_path "/etc/systemd/system/v2ray@.service"
    fi

    # 移除 Nginx (先询问!)
    echo "Nginx 可能作为 V2Ray+WSS 的一部分被安装了。"
    remove_package nginx

    # 询问关于 ACME / 证书
    if [ -d "$HOME/.acme.sh" ] || [ -d "/root/.acme.sh" ]; then
        if confirm_action "找到 acme.sh 安装目录。是否移除? (这将影响由它管理的所有证书)"; then
            local acme_sh_path="$HOME/.acme.sh/acme.sh"
            [ ! -f "$acme_sh_path" ] && acme_sh_path="/root/.acme.sh/acme.sh"
            if [ -f "$acme_sh_path" ]; then
                echo "正在卸载 acme.sh..."
                "$acme_sh_path" --uninstall || echo "警告: acme.sh 卸载命令失败。" >&2
            fi
            remove_path "$HOME/.acme.sh" # 清理可能的残留
            remove_path "/root/.acme.sh"
        fi
    fi
    if [ -d "/etc/letsencrypt" ]; then
         if confirm_action "找到 Let's Encrypt 目录 (/etc/letsencrypt)。是否移除? (警告: 将移除所有证书)"; then
              remove_path "/etc/letsencrypt"
         fi
    fi

    # 清理可能创建的 webroot
    # remove_path "/var/www/html" # 风险太高 - 可能被其他服务使用

    echo "V2Ray+WSS 卸载过程完成。"
}

uninstall_reality() {
    echo "--- 开始卸载 Reality (Xray) ---"
    stop_disable_service xray

    echo "正在运行 Xray 官方卸载脚本..."
    if command_exists curl; then
        # 使用官方 remove 命令 - 需要网络连接
        bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ remove || echo "警告: Xray 官方卸载脚本失败或被中断。" >&2
    else
        echo "警告: 未找到 curl 命令。无法自动运行 Xray 官方卸载程序。"
        echo "尝试手动删除常见路径..."
        remove_path "/usr/local/bin/xray"
        remove_path "/usr/local/etc/xray"
        remove_path "/usr/local/share/xray"
        remove_path "/etc/systemd/system/xray.service"
        remove_path "/etc/systemd/system/xray@.service"
    fi
    echo "Reality (Xray) 卸载过程完成。"
}

uninstall_hysteria2() {
    echo "--- 开始卸载 Hysteria2 ---"
    stop_disable_service hysteria-server # 如果服务名不同请调整

    echo "正在运行 Hysteria2 官方卸载脚本..."
    if command_exists curl; then
        # 使用官方 remove 命令 - 需要网络连接
         bash <(curl -fsSL https://get.hy2.sh/) --remove || echo "警告: Hysteria2 官方卸载脚本失败或被中断。" >&2
    else
        echo "警告: 未找到 curl 命令。无法自动运行 Hysteria2 官方卸载程序。"
         echo "尝试手动删除常见路径..."
         # 注意: Hysteria 安装路径可能变化，这里是猜测
         remove_path "/usr/local/bin/hysteria-server" # 检查实际二进制文件名/路径
         remove_path "/etc/hysteria"
         remove_path "/etc/systemd/system/hysteria-server.service" # 检查实际服务名
    fi
    echo "Hysteria2 卸载过程完成。"
}

# --- 主菜单 ---
main_menu() {
    clear
    echo "============================================="
    echo " VPN 服务卸载程序"
    echo "============================================="
    echo "警告: 此脚本将尝试移除已安装的服务和配置。"
    echo "请谨慎使用。建议先备份数据。"
    echo "---------------------------------------------"
    echo "检测到的组件 (基于常见路径):"
    # 基于常见安装位置/文件的简单检测
    [ -f "/usr/local/bin/ssserver" ] && echo " - 检测到 Shadowsocks-rust"
    [ -f "/usr/local/bin/v2ray" ] && echo " - 检测到 V2Ray"
    [ -f "/usr/local/bin/xray" ] && echo " - 检测到 Xray (Reality)"
    [ -f "/usr/local/bin/hysteria-server" ] && echo " - 检测到 Hysteria2" # 检查二进制文件名
    [ -f "/etc/nginx/nginx.conf" ] && command_exists nginx && echo " - 检测到 Nginx"
    echo "---------------------------------------------"
    echo "请选择要卸载的组件:"
    echo " 1. 卸载 Shadowsocks-rust"
    echo " 2. 卸载 V2Ray + WS + TLS (包括 V2Ray, 可能包括 Nginx, 证书)"
    echo " 3. 卸载 Reality (包括 Xray)"
    echo " 4. 卸载 Hysteria2"
    echo " 5. 卸载所有检测到的组件 (每个都需要确认)"
    echo " 0. 退出"
    echo "---------------------------------------------"
    read -p "请输入选项 [0-5]: " choice

    case "$choice" in
        1) uninstall_ss_rust ;;
        2) uninstall_v2ray_wss ;;
        3) uninstall_reality ;;
        4) uninstall_hysteria2 ;;
        5)
            echo "尝试卸载所有检测到的组件..."
            # 仅当组件似乎存在时才调用卸载函数
            [ -f "/usr/local/bin/ssserver" ] || [ -d "/etc/shadowsocks" ] && uninstall_ss_rust
            # V2Ray+WSS 意味着 V2Ray 和 Nginx 可能存在
            [ -f "/usr/local/bin/v2ray" ] || [ -d "/usr/local/etc/v2ray" ] && uninstall_v2ray_wss
            # Reality 意味着 Xray
            [ -f "/usr/local/bin/xray" ] || [ -d "/usr/local/etc/xray" ] && uninstall_reality
             # Hysteria2 检查
            [ -f "/usr/local/bin/hysteria-server" ] || [ -d "/etc/hysteria" ] && uninstall_hysteria2
            echo "尝试移除所有检测到的组件已完成。"
            ;;
        0) echo "正在退出。"; exit 0 ;;
        *) echo "无效选项。"; sleep 2; main_menu ;;
    esac

    # 卸载操作后的最后步骤
    echo "正在重新加载 systemd 守护进程..."
    systemctl daemon-reload || echo "警告: systemctl daemon-reload 失败。" >&2
    echo "卸载完成。建议重新启动系统。"
}

# --- 脚本执行 ---
main_menu