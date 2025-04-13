# VPN Deployment Suite 🚀

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**One-click installation scripts for popular VPN and proxy services.**

This project provides a collection of shell scripts designed to simplify the deployment of various proxy services on Linux servers. The suite includes enhanced error handling, adaptive system tuning based on server resources, and a dedicated uninstaller.

---

## ✨ Features

*   **Menu-Driven Installation:** Easy-to-use main script (`tcp-wss.sh`) guides you through the installation choices.
*   **Multiple Protocol Support:**
    *   **Shadowsocks-rust:** High-performance, secure socks5 proxy.
    *   **V2Ray + WebSocket + TLS:** Robust setup requiring a domain name, offering encryption and traffic obfuscation.
    *   **Reality (Xray-core):** Domainless VLESS proxy solution for enhanced privacy.
    *   **Hysteria2:** High-performance, UDP-based (QUIC) proxy, also domainless.
    *   *(Optional)* **V2Ray + WebSocket (No TLS):** Simple WebSocket-only setup.
*   **Broad OS Compatibility:** Tested on Debian (9+), Ubuntu (16.04+), and CentOS 7+. ARM architecture (like Oracle Cloud Ampere) is supported.
*   **Adaptive System Tuning:** Includes `tcp-window.sh` which automatically adjusts key network parameters (`sysctl.conf`) and resource limits (`limits.conf`) based on detected system RAM and CPU cores for optimized performance. **(Requires Reboot)**
*   **Robust Error Handling:** Scripts include `set -e` and checks for critical operations, providing clearer feedback on failures.
*   **Shared Code Library:** Uses `common.sh` for reusable functions, improving maintainability.
*   **Dedicated Uninstaller:** Provides `uninstall.sh` for clean removal of installed components.
*   **Consistent Local Execution:** The main script reliably executes helper scripts from the local repository clone.

---

## 📋 Requirements

*   A Linux server running a supported OS (Debian 9+, Ubuntu 16.04+, CentOS 7+).
*   Root (`sudo`) privileges.
*   Internet connection (for downloading dependencies and installation scripts).
*   **For V2Ray+WSS+TLS:** A registered domain name with DNS pointed to your server's IP address.
*   Basic command-line knowledge.

---

## 🚀 Quick Start: Installation

1.  **Connect** to your server via SSH.
2.  **Download and run** the main installation script using the following command:

    ```bash
    wget https://raw.githubusercontent.com/spectramaster/vpn/main/tcp-wss.sh && sudo bash tcp-wss.sh
    ```
    *(Please replace `spectramaster/vpn` with the correct repository URL if you are using a fork).*

3.  **Follow the on-screen menu** to choose the service you want to install. The script will guide you through any necessary inputs (like domain name or port).

![Installation Menu Screenshot](https://github.com/user-attachments/assets/76396d58-3fef-4028-8a5f-f8c9260c76e5)

---

## ⚙️ Configuration & Client Info

After a successful installation, the script will display the necessary configuration parameters and import links/URIs for your client application directly on the screen.

For reference, template files containing client configuration details are also saved on the server at these locations:

*   **Shadowsocks-rust:** `/etc/shadowsocks/config.json` (Server config) + **Screen Output (Link)**
*   **V2Ray+WSS+TLS:** `/usr/local/etc/v2ray/client.json` (Client template) + **Screen Output (Link)**
*   **Reality:** `/usr/local/etc/xray/reclient.json` (Client template) + **Screen Output (Link)**
*   **Hysteria2:** `/etc/hysteria/hyclient.json` (Client template) + **Screen Output (Link)**
*   **V2Ray+WS (No TLS):** `/usr/local/etc/v2ray/client.json` (Client template, different content) + **Screen Output (Link)**

*Always prioritize the information shown on the screen after installation.*

---

## 🧹 Uninstallation

This suite includes a dedicated uninstaller script to help remove the services cleanly.

1.  **Navigate** to the directory where you cloned or downloaded the scripts (e.g., `cd vpn`).
2.  **Ensure** the script has execute permissions:
    ```bash
    chmod +x uninstall.sh
    ```
3.  **Run** the script as root:
    ```bash
    sudo bash uninstall.sh
    ```
4.  **Follow the menu** to select the component(s) you wish to uninstall.
    *   **Warning:** Be cautious when confirming the removal of potentially shared components like Nginx or Let's Encrypt certificates, as this might affect other applications on your server.

---

## ⚠️ Important Notes

1.  **Firewall Rules:** Installation and connection problems are often caused by firewalls. Ensure your server's firewall (e.g., `ufw`, `firewalld`) or cloud provider's security group allows incoming traffic on the port(s) used by the installed service.
2.  **System Tuning Requires Reboot:** The `tcp-window.sh` script optimizes system network parameters. **A server reboot is required** for these changes (especially file descriptor limits) to take full effect. The installation script may prompt you or you might need to reboot manually afterward.
3.  **Script Execution:** Always review scripts from the internet before executing them, especially with root privileges. While efforts have been made to ensure these scripts are safe, use them at your own risk.
4.  **AI Assistance:** Some parts of these scripts were developed with AI assistance. They have been reviewed, but thorough testing in diverse environments is ongoing.

---

## 🤝 Credits & License

*   This project is based on and heavily modified from the work by [yeahwu/v2ray-wss](https://github.com/yeahwu/v2ray-wss).
*   Uses official installation methods or binaries from Shadowsocks-rust, V2Ray (v2fly), Xray (XTLS), Hysteria2, and acme.sh.

Licensed under the [MIT License](https://opensource.org/licenses/MIT).