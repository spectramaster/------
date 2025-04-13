# VPN Deployment Suite 🚀

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**One-click installation scripts and Docker configurations for popular VPN and proxy services.**

This project provides a collection of shell scripts and Docker Compose setups designed to simplify the deployment of various proxy services on Linux servers. The suite includes enhanced error handling, adaptive system tuning based on server resources, a dedicated uninstaller for script-based installs, and a modern Docker deployment option.

---

## ✨ Features

*   **Two Deployment Methods:**
    *   **Shell Scripts:** Traditional one-click scripts with high automation.
    *   **Docker Deployment (Recommended):** Utilizes Docker and Docker Compose for better environment isolation, consistency, and portability.
*   **Menu-Driven Installation (Shell Method):** The `tcp-wss.sh` script offers a clear menu for selecting services.
*   **Multiple Protocol Support (Deployable via both methods):**
    *   Shadowsocks-rust
    *   V2Ray + WebSocket + TLS (Requires manual Nginx & ACME config for Docker)
    *   Reality (Xray-core)
    *   Hysteria2
    *   V2Ray + WebSocket (No TLS)
*   **Broad OS Compatibility (Shell Method):** Tested on Debian (9+), Ubuntu (16.04+), and CentOS 7+. ARM architecture is supported. (Docker method depends on the host supporting Docker).
*   **Adaptive System Tuning (For Host Machine):** Includes `tcp-window.sh` script to automatically adjust host network parameters (`sysctl.conf`) and resource limits (`limits.conf`) based on detected RAM and CPU cores. **(Requires Reboot)**
*   **Robust Error Handling (Shell Method):** Shell scripts include `set -e` and checks for critical operations.
*   **Shared Code Library (Shell Method):** Uses `common.sh` for reusable functions.
*   **Dedicated Uninstaller (Shell Method):** Provides `uninstall.sh` to remove services installed via shell scripts.
*   **Clear Deployment Options:** README provides detailed guides for both Shell and Docker deployment methods.

---

## 📜 Evolution from Original Version

This script suite has undergone significant improvements compared to its original base (derived from yeahwu/v2ray-wss):

1.  **Created Shared Library (`common.sh`):** Extracted common utility functions to reduce code duplication.
2.  **Refactored Original Scripts:** Utilized the shared library, optimizing structure.
3.  **Added Detailed Comments & Optimized Structure:** Improved code readability.
4.  **Enhanced Error Handling Mechanism:** Introduced `set -e` and error checks for increased reliability.
5.  **Introduced Adaptive System Tuning (`tcp-window.sh`):** Dynamically adjusts host network parameters and limits based on server resources.
6.  **Fixed Script Dependency Issues:** Ensured the main script calls local helper scripts for consistency.
7.  **Added Dedicated Uninstaller (`uninstall.sh`):** Facilitates clean removal of services installed via shell scripts.
8.  **Added Docker Deployment Support:** Provided `docker-compose.yml` and example configurations for containerized deployment.

*(Note: This list highlights major iterative improvements and may not include every minor adjustment.)*

---

## 📋 System Requirements

**General Requirements:**

*   A Linux server.
*   Root (`sudo`) privileges.
*   Internet connection.
*   Basic command-line knowledge.

**Shell Script Installation Specific Requirements:**

*   A supported Linux OS (Debian 9+, Ubuntu 16.04+, CentOS 7+).
*   **For V2Ray+WSS+TLS:** A registered domain name with DNS pointed to your server's IP address.

**Docker Deployment Specific Requirements:**

*   A host machine with [Docker](https://docs.docker.com/engine/install/) and [Docker Compose](https://docs.docker.com/compose/install/) installed.
*   **For V2Ray+WSS+TLS:** Also requires a domain name.
*   Requires manual editing of configuration files and generation/pasting of keys, UUIDs, etc.

---

## 🚀 Quick Start: Choose Your Deployment Method

You can choose one of the following methods to deploy the VPN services:

### Method 1: Shell Script One-Click Install (Highly Automated)

1.  **Connect** to your server via SSH.
2.  **(Optional but Highly Recommended)** Run the system tuning script and reboot the host:
    ```bash
    # Download the script (if you haven't already)
    # wget https://raw.githubusercontent.com/spectramaster/vpn/main/tcp-window.sh
    # chmod +x tcp-window.sh
    sudo bash tcp-window.sh
    sudo reboot
    ```
3.  **Download and run** the main installation script:
    ```bash
    wget https://raw.githubusercontent.com/spectramaster/vpn/main/tcp-wss.sh && sudo bash tcp-wss.sh
    ```
    *(Replace `spectramaster/vpn` with the correct repository URL if using a fork).*
4.  **Follow the on-screen menu** to select the desired service. The script will handle most configurations automatically.

![Installation Menu Screenshot](https://github.com/user-attachments/assets/76396d58-3fef-4028-8a5f-f8c9260c76e5)

**Client Configuration (Shell Method):** After successful installation, the script will display client configuration parameters and import links directly on the screen. Template files are also saved on the server:
*   Shadowsocks-rust: `/etc/shadowsocks/config.json` (Server config) + **Screen Output (Link)**
*   V2Ray+WSS+TLS: `/usr/local/etc/v2ray/client.json` + **Screen Output (Link)**
*   Reality: `/usr/local/etc/xray/reclient.json` + **Screen Output (Link)**
*   Hysteria2: `/etc/hysteria/hyclient.json` + **Screen Output (Link)**
*   V2Ray+WS (No TLS): `/usr/local/etc/v2ray/client.json` + **Screen Output (Link)**

**Uninstallation (Shell Method):**
1.  Navigate to the script directory (e.g., `cd vpn`).
2.  Run `chmod +x uninstall.sh && sudo bash uninstall.sh`.
3.  Follow the menu prompts.

---

### Method 2: 🐳 Docker Deployment (Recommended, More Flexible & Controlled)

This method uses Docker and Docker Compose, offering better isolation, consistency, and portability.

**Differences from Shell Script Installation:**
*   Services run in containers, not directly modifying the host system (except for network tuning).
*   Configuration files must be **manually prepared** and mounted into containers.
*   UUIDs, passwords, keys, etc., must be **manually generated** and inserted into configuration files.
*   System-level network tuning (`tcp-window.sh`) still needs to be run on the **host machine**.

**Deployment Steps:**

1.  **Prepare Host Machine:**
    *   Ensure [Docker](https://docs.docker.com/engine/install/) and [Docker Compose](https://docs.docker.com/compose/install/) are installed.
    *   **(Highly Recommended)** Execute the `tcp-window.sh` script from this repository on the **host** for system network optimization, then **reboot the host**:
        ```bash
        # Assuming the script is in the vpn/ directory
        sudo bash tcp-window.sh
        sudo reboot
        ```
2.  **Clone Repository:**
    ```bash
    git clone https://github.com/spectramaster/vpn.git # Replace with your repo URL
    cd vpn/docker_deployment # Navigate to the Docker config directory
    ```
3.  **Configure Environment Variables:**
    *   Copy the example environment file: `cp .env.example .env`
    *   Edit the `.env` file to change default ports (if needed to avoid conflicts) and set your ACME email address (if using WSS).
4.  **Prepare Service Configuration Files:**
    *   For **each** service you intend to deploy (V2Ray WSS, Reality, Hysteria2, Shadowsocks-rust), navigate into its respective subdirectory (e.g., `cd v2ray_wss`).
    *   Copy the example configuration file: `cp config.json.example config.json` (filename might vary, e.g., `config.yaml`).
    *   **Edit** the newly copied configuration file (`config.json` or `config.yaml`).
    *   **Important:** Replace all `<PLACEHOLDER>` or `<...>` values with your actual, **manually generated or specified** values. Examples:
        *   `<YOUR_DOMAIN_HERE>`: Replace with your domain name (for Nginx and V2Ray WSS).
        *   `<GENERATE_UUID_HERE>`: Use `uuidgen` command to generate and replace.
        *   `<GENERATE_PASSWORD_HERE>`: Use `openssl rand -base64 32` or similar to generate a strong password and replace.
        *   `<PASTE_YOUR_PRIVATE_KEY_HERE>`: Run `xray x25519` (requires xray installation) or use a tool to generate a Reality keypair and paste the private key.
        *   `<YOUR_V2RAY_WSPATH>`: Specify a WebSocket path (e.g., `myv2path`) and ensure consistency between V2Ray and Nginx configs.
5.  **Edit `docker-compose.yml`:**
    *   Open the `docker-compose.yml` file.
    *   Locate the service(s) you want to deploy (e.g., `xray_reality:` or `v2ray_wss:`, `nginx_wss:`, `acme_wss:`).
    *   **Uncomment** the definition lines for these services (remove the leading `# `). Ensure related `volumes`, `ports`, `networks`, `environment`, etc., are also uncommented.
6.  **Start Services:**
    *   From within the `docker_deployment` directory, run:
        ```bash
        docker-compose up -d
        ```
    *   The first time you start the ACME service, you might need to manually execute the certificate issuance command, or adjust the `command`/`entrypoint` according to the [acme.sh Docker documentation](https://github.com/acmesh-official/acme.sh/wiki/Run-acme.sh-in-docker) for automation.
7.  **View Logs:**
    ```bash
    docker-compose logs -f # View logs for all services
    docker-compose logs -f v2ray_wss # View logs for a specific service (replace v2ray_wss with the service name)
    ```
8.  **Get Client Configuration:** The Docker deployment method **does not** automatically generate client configurations on screen or in files. You need to manually assemble your client settings or import links based on the parameters you **manually configured** (domain, port, UUID, password, path, keys, etc.).

**Uninstallation (Docker Method):**
Uninstalling a Docker deployment is straightforward:
1.  Navigate to the `docker_deployment` directory.
2.  Run `docker-compose down -v` (the `-v` flag removes associated volumes like certificates).
3.  (Optional) Delete the `docker_deployment` directory.

This is **different** from running `uninstall.sh` (which is for services installed via the Shell scripts).

---

## ⚠️ Important Notes (General)

1.  **Firewall Rules:** Installation or connection issues are often firewall-related. Ensure your server's firewall (e.g., `ufw`, `firewalld`) or your cloud provider's security group allows incoming traffic on the port(s) used by the installed service.
2.  **System Tuning Requires Reboot:** The `tcp-window.sh` script optimizes host system network parameters. **A server reboot is required** for these changes to take full effect.
3.  **Script Execution:** Always review scripts from the internet before executing them, especially with root privileges. Use these scripts at your own risk.
4.  **AI Assistance:** Parts of these scripts were developed with AI assistance. They have been reviewed, but thorough testing in diverse environments is ongoing.

---

## 🤝 Credits & License

*   This project is based on and heavily modified from the work by [yeahwu/v2ray-wss](https://github.com/yeahwu/v2ray-wss).
*   Uses official installation methods, binaries, or Docker images from projects like Shadowsocks-rust, V2Ray (v2fly), Xray (XTLS), Hysteria2, Nginx, and acme.sh.

Licensed under the [MIT License](https://opensource.org/licenses/MIT).