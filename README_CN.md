# VPN 部署套件 🚀

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**流行 VPN 及代理服务的一键安装脚本。**

本项目提供一系列 Shell 脚本，旨在简化在 Linux 服务器上部署各种代理服务的流程。该套件包含了增强的错误处理、基于服务器资源的自适应系统调优以及一个专用的卸载脚本。

---

## ✨ 功能特性

*   **菜单驱动安装：** 易于使用的主脚本 (`tcp-wss.sh`) 提供清晰的安装选项菜单。
*   **多种协议支持：**
    *   **Shadowsocks-rust：** 高性能、安全的 Socks5 代理。
    *   **V2Ray + WebSocket + TLS：** 需要域名，提供 TLS 加密和流量伪装的稳健方案。
    *   **Reality (Xray-core)：** 基于 Xray 的 VLESS 协议，无需域名，增强隐私。
    *   **Hysteria2：** 高性能、基于 UDP (QUIC) 的代理，同样无需域名。
    *   *(可选)* **V2Ray + WebSocket (无 TLS)：** 简单的纯 WebSocket 模式。
*   **广泛的操作系统兼容性：** 已在 Debian (9+)、Ubuntu (16.04+) 和 CentOS 7+ 上测试。支持 ARM 架构（例如 Oracle Cloud Ampere 服务器）。
*   **自适应系统调优：** 包含 `tcp-window.sh` 脚本，可根据检测到的系统内存（RAM）和 CPU 核心数，自动调整关键网络参数 (`sysctl.conf`) 和资源限制 (`limits.conf`) 以优化性能。 **(需要重启生效)**
*   **健壮的错误处理：** 脚本包含 `set -e` 和关键操作检查，能在发生错误时提供更清晰的反馈。
*   **共享代码库：** 使用 `common.sh` 提取可复用函数，提高可维护性。
*   **专用卸载脚本：** 提供 `uninstall.sh`，方便干净地移除已安装的组件。
*   **一致的本地执行：** 主脚本可靠地执行本地代码库克隆中的辅助脚本。

---

## 📋 系统要求

*   运行受支持的操作系统的 Linux 服务器（Debian 9+, Ubuntu 16.04+, CentOS 7+）。
*   Root (`sudo`) 权限。
*   互联网连接（用于下载依赖项和安装脚本）。
*   **对于 V2Ray+WSS+TLS：** 一个已注册的域名，并且其 DNS 解析已指向您服务器的 IP 地址。
*   基本的命令行知识。

---

## 🚀 快速开始：安装

1.  通过 SSH **连接**到您的服务器。
2.  使用以下命令**下载并运行**主安装脚本：

    ```bash
    wget https://raw.githubusercontent.com/spectramaster/vpn/main/tcp-wss.sh && sudo bash tcp-wss.sh
    ```
    *(如果您使用的是 fork 仓库，请将 `spectramaster/vpn` 替换为正确的仓库 URL)。*

3.  **根据屏幕菜单提示**选择您想要安装的服务。脚本将引导您完成必要的输入（例如域名或端口号）。

![安装菜单截图](https://github.com/user-attachments/assets/76396d58-3fef-4028-8a5f-f8c9260c76e5)

---

## ⚙️ 配置与客户端信息

安装成功后，脚本会直接在屏幕上显示客户端应用所需的配置参数和导入链接/URI。

作为参考，包含客户端配置细节的模板文件也会保存在服务器的以下位置：

*   **Shadowsocks-rust：** `/etc/shadowsocks/config.json` (服务端配置) + **屏幕输出 (链接)**
*   **V2Ray+WSS+TLS：** `/usr/local/etc/v2ray/client.json` (客户端模板) + **屏幕输出 (链接)**
*   **Reality：** `/usr/local/etc/xray/reclient.json` (客户端模板) + **屏幕输出 (链接)**
*   **Hysteria2：** `/etc/hysteria/hyclient.json` (客户端模板) + **屏幕输出 (链接)**
*   **V2Ray+WS (无TLS)：** `/usr/local/etc/v2ray/client.json` (客户端模板，内容不同) + **屏幕输出 (链接)**

*请始终优先使用安装后屏幕上显示的信息。*

---

## 🧹 卸载服务

本套件包含一个专用的卸载脚本，以帮助您干净地移除服务。

1.  **切换**到您克隆或下载脚本的目录（例如 `cd vpn`）。
2.  **确保**脚本具有执行权限：
    ```bash
    chmod +x uninstall.sh
    ```
3.  以 root 用户身份**运行**脚本：
    ```bash
    sudo bash uninstall.sh
    ```
4.  **根据菜单提示**选择您希望卸载的组件。
    *   **警告：** 在确认移除可能共享的组件（如 Nginx 或 Let's Encrypt 证书）时请务必小心，这可能会影响您服务器上的其他应用程序。

---

## ⚠️ 重要提示

1.  **防火墙规则：** 安装或连接失败通常与防火墙有关。请确保您的服务器防火墙（如 `ufw`, `firewalld`）或云服务商的安全组规则允许您所安装服务使用的端口上的入站流量。
2.  **系统调优需要重启：** `tcp-window.sh` 脚本优化了系统网络参数。**必须重新启动服务器**才能使这些更改（特别是文件描述符限制）完全生效。安装脚本可能会提示您，或者您需要在之后手动重启。
3.  **脚本执行：** 在执行来自互联网的脚本之前，请务必进行审查，尤其是在使用 root 权限时。尽管我们已努力确保这些脚本的安全性，但请自行承担使用风险。
4.  **AI 辅助开发：** 这些脚本的部分内容是在 AI 辅助下开发的，并经过了审查，但在多样化环境中的全面测试仍在进行中。

---

## 🤝 致谢与许可证

*   本项目基于 [yeahwu/v2ray-wss](https://github.com/yeahwu/v2ray-wss) 的工作并进行了大量修改。
*   使用了来自 Shadowsocks-rust, V2Ray (v2fly), Xray (XTLS), Hysteria2, 和 acme.sh 的官方安装方法或二进制文件。

本项目采用 [MIT 许可证](https://opensource.org/licenses/MIT)授权。