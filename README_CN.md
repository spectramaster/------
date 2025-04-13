# VPN 部署套件 🚀

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**流行 VPN 及代理服务的一键安装脚本。**

本项目提供一系列 Shell 脚本，旨在简化在 Linux 服务器上部署各种代理服务的流程。该套件包含了增强的错误处理、基于服务器资源的自适应系统调优以及一个专用的卸载脚本。同时，也提供了更现代化的 Docker 部署方式。

---

## ✨ 功能特性

*   **两种部署方式：**
    *   **Shell 脚本安装：** 传统的一键式脚本，自动化程度高。
    *   **Docker 部署 (推荐)：** 使用 Docker 和 Docker Compose，提供更好的环境隔离、一致性和可移植性。
*   **菜单驱动安装 (Shell 方式)：** `tcp-wss.sh` 脚本提供清晰的安装选项。
*   **多种协议支持 (两种方式均可部署)：**
    *   Shadowsocks-rust
    *   V2Ray + WebSocket + TLS (Docker 方式需要手动配置 Nginx 和 ACME)
    *   Reality (Xray-core)
    *   Hysteria2
    *   V2Ray + WebSocket (无 TLS)
*   **广泛的操作系统兼容性 (Shell 方式)：** 已在 Debian (9+)、Ubuntu (16.04+) 和 CentOS 7+ 上测试。支持 ARM 架构。 (Docker 方式依赖宿主机支持 Docker)。
*   **自适应系统调优 (针对宿主机)：** 包含 `tcp-window.sh` 脚本，可根据检测到的内存和 CPU 核心数自动调整宿主机网络参数和资源限制。 **(需要重启生效)**
*   **健壮的错误处理 (Shell 方式)：** Shell 脚本包含 `set -e` 和关键操作检查。
*   **共享代码库 (Shell 方式)：** 使用 `common.sh` 提取可复用函数。
*   **专用卸载脚本 (Shell 方式)：** 提供 `uninstall.sh` 用于移除 Shell 脚本安装的服务。
*   **清晰的部署选项：** README 提供 Shell 和 Docker 两种部署方式的详细指南。

---

## 📜 相对于原版的改进历程

此脚本集在原始版本（源自 yeahwu/v2ray-wss）的基础上进行了多项重要改进：

1.  **创建共享库 (`common.sh`)：** 提取了常用功能函数，减少代码重复。
2.  **重构原始脚本：** 调用共享库函数，优化结构。
3.  **增加详细注释与优化结构：** 提高代码可读性。
4.  **增强错误处理机制：** 引入 `set -e` 和错误检查，提高脚本可靠性。
5.  **引入自适应系统调优 (`tcp-window.sh`)：** 根据服务器资源动态调整网络参数和资源限制。
6.  **修复脚本依赖问题：** 主菜单脚本调用本地辅助脚本，保证一致性。
7.  **添加专用卸载脚本 (`uninstall.sh`)：** 方便移除 Shell 方式安装的服务。
8.  **新增 Docker 部署支持：** 提供 `docker-compose.yml` 及示例配置，支持容器化部署。

*(注：上述列表记录了主要的迭代改进点，可能未包含所有细微调整。)*

---

## 📋 系统要求

**通用要求:**

*   Linux 服务器。
*   Root (`sudo`) 权限。
*   互联网连接。
*   基本的命令行知识。

**Shell 脚本安装方式特定要求:**

*   运行受支持的操作系统的 Linux 服务器（Debian 9+, Ubuntu 16.04+, CentOS 7+）。
*   **对于 V2Ray+WSS+TLS：** 一个已注册的域名，并且其 DNS 解析已指向您服务器的 IP 地址。

**Docker 部署方式特定要求:**

*   已安装 [Docker](https://docs.docker.com/engine/install/) 和 [Docker Compose](https://docs.docker.com/compose/install/) 的宿主机。
*   **对于 V2Ray+WSS+TLS：** 同样需要域名。
*   需要手动编辑配置文件并生成/粘贴密钥、UUID 等。

---

## 🚀 快速开始：选择部署方式

您可以选择以下两种方式之一来部署 VPN 服务：

### 方式一：Shell 脚本一键安装 (自动化程度高)

1.  通过 SSH **连接**到您的服务器。
2.  **(可选但强烈推荐)** 运行系统优化脚本并重启：
    ```bash
    # 下载脚本 (如果还没有)
    # wget https://raw.githubusercontent.com/spectramaster/vpn/main/tcp-window.sh
    # chmod +x tcp-window.sh
    sudo bash tcp-window.sh
    sudo reboot
    ```
3.  使用以下命令**下载并运行**主安装脚本：
    ```bash
    wget https://raw.githubusercontent.com/spectramaster/vpn/main/tcp-wss.sh && sudo bash tcp-wss.sh
    ```
    *(如果您使用的是 fork 仓库，请将 `spectramaster/vpn` 替换为正确的仓库 URL)。*
4.  **根据屏幕菜单提示**选择您想要安装的服务。脚本将自动处理大部分配置。

![安装菜单截图](https://github.com/user-attachments/assets/76396d58-3fef-4028-8a5f-f8c9260c76e5)

**客户端配置 (Shell 方式):** 安装成功后，脚本会直接在屏幕上显示客户端配置参数和导入链接。模板文件也会保存在服务器的以下位置：
*   Shadowsocks-rust: `/etc/shadowsocks/config.json` (服务端配置) + **屏幕输出 (链接)**
*   V2Ray+WSS+TLS: `/usr/local/etc/v2ray/client.json` + **屏幕输出 (链接)**
*   Reality: `/usr/local/etc/xray/reclient.json` + **屏幕输出 (链接)**
*   Hysteria2: `/etc/hysteria/hyclient.json` + **屏幕输出 (链接)**
*   V2Ray+WS (无TLS): `/usr/local/etc/v2ray/client.json` + **屏幕输出 (链接)**

**卸载 (Shell 方式):**
1.  切换到脚本所在目录 (e.g., `cd vpn`)。
2.  运行 `chmod +x uninstall.sh && sudo bash uninstall.sh`。
3.  根据菜单提示操作。

---

### 方式二：🐳 Docker 部署 (推荐，更灵活可控)

此方式使用 Docker 和 Docker Compose，具有更好的环境隔离、一致性和可移植性。

**与 Shell 脚本安装的区别:**
*   服务运行在容器中，不直接修改宿主机系统（除了网络调优）。
*   配置文件需要**手动准备**并挂载到容器中。
*   UUID、密码、密钥等需要**手动生成**并填入配置文件。
*   系统级网络调优 (`tcp-window.sh`) 仍需在**宿主机**上执行。

**部署步骤:**

1.  **宿主机准备:**
    *   确保已安装 [Docker](https://docs.docker.com/engine/install/) 和 [Docker Compose](https://docs.docker.com/compose/install/)。
    *   **(强烈推荐)** 在**宿主机**上执行仓库中的 `tcp-window.sh` 脚本进行系统网络优化，并**重新启动宿主机**：
        ```bash
        # 假设脚本已在 vpn/ 目录下
        sudo bash tcp-window.sh
        sudo reboot
        ```
2.  **克隆仓库:**
    ```bash
    git clone https://github.com/spectramaster/vpn.git # 替换为你的仓库地址
    cd vpn/docker_deployment # 进入 Docker 配置目录
    ```
3.  **配置环境变量:**
    *   复制环境变量示例文件：`cp .env.example .env`
    *   编辑 `.env` 文件，修改其中的端口号（如果需要避免冲突）和你的 ACME 邮箱地址 (如果使用 WSS)。
4.  **准备服务配置文件:**
    *   对于你想要部署的**每一种**服务 (V2Ray WSS, Reality, Hysteria2, Shadowsocks-rust)，进入其对应的子目录 (e.g., `cd v2ray_wss`)。
    *   复制示例配置文件：`cp config.json.example config.json` (文件名可能不同，如 `config.yaml`)。
    *   **编辑** 新复制的配置文件 (`config.json` 或 `config.yaml`)。
    *   **重要:** 将文件中所有 `<PLACEHOLDER>` 或 `<...>` 的值替换为你自己**生成或指定**的实际值。例如：
        *   `<YOUR_DOMAIN_HERE>`: 替换为你的域名 (用于 Nginx 和 V2Ray WSS)。
        *   `<GENERATE_UUID_HERE>`: 使用 `uuidgen` 命令生成并替换。
        *   `<GENERATE_PASSWORD_HERE>`: 使用 `openssl rand -base64 32` 或类似命令生成强密码并替换。
        *   `<PASTE_YOUR_PRIVATE_KEY_HERE>`: 运行 `xray x25519` (需要安装 xray) 或使用工具生成 Reality 密钥对，粘贴私钥。
        *   `<YOUR_V2RAY_WSPATH>`: 指定一个 WebSocket 路径 (例如 `myv2path`)，并确保 V2Ray 和 Nginx 配置一致。
5.  **编辑 `docker-compose.yml`:**
    *   打开 `docker-compose.yml` 文件。
    *   找到你想要部署的服务部分 (例如 `xray_reality:` 或 `v2ray_wss:`, `nginx_wss:`, `acme_wss:`)。
    *   **取消注释** 这些服务的定义行 (删除行首的 `# `)。确保相关的 `volumes`, `ports`, `networks`, `environment` 等都已取消注释。
6.  **启动服务:**
    *   在 `docker_deployment` 目录下，运行：
        ```bash
        docker-compose up -d
        ```
    *   首次启动 ACME 服务可能需要手动执行证书申请命令，或者您需要根据 [acme.sh Docker 文档](https://github.com/acmesh-official/acme.sh/wiki/Run-acme.sh-in-docker) 调整 `command` 或 `entrypoint` 来自动化申请。
7.  **查看日志:**
    ```bash
    docker-compose logs -f # 查看所有服务日志
    docker-compose logs -f v2ray_wss # 查看特定服务日志 (将 v2ray_wss 替换为服务名)
    ```
8.  **获取客户端配置:** Docker 部署方式**不会**自动在屏幕或文件中生成客户端配置。你需要根据你**手动配置**的服务参数（域名、端口、UUID、密码、路径、密钥等）自行组合客户端配置或导入链接。

**卸载 (Docker 方式):**
Docker 部署的卸载非常简单：
1.  进入 `docker_deployment` 目录。
2.  运行 `docker-compose down -v` ( `-v` 会删除相关的数据卷，如证书)。
3.  (可选) 删除 `docker_deployment` 目录。

---

## ⚠️ 重要提示 (通用)

1.  **防火墙规则：** 安装或连接失败通常与防火墙有关。请确保您的服务器防火墙（如 `ufw`, `firewalld`）或云服务商的安全组规则允许您所安装服务使用的端口上的入站流量。
2.  **系统调优需要重启：** `tcp-window.sh` 脚本优化了宿主机系统网络参数。**必须重新启动服务器**才能使这些更改完全生效。
3.  **脚本执行：** 在执行来自互联网的脚本之前，请务必进行审查，尤其是在使用 root 权限时。请自行承担使用风险。
4.  **AI 辅助开发：** 这些脚本的部分内容是在 AI 辅助下开发的，并经过了审查，但在多样化环境中的全面测试仍在进行中。

---

## 🤝 致谢与许可证

*   本项目基于 [yeahwu/v2ray-wss](https://github.com/yeahwu/v2ray-wss) 的工作并进行了大量修改。
*   使用了来自 Shadowsocks-rust, V2Ray (v2fly), Xray (XTLS), Hysteria2, Nginx, acme.sh 等项目的官方安装方法、二进制文件或 Docker 镜像。

本项目采用 [MIT 许可证](https://opensource.org/licenses/MIT)授权。