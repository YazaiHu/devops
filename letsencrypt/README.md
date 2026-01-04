# Let's Encrypt SSL 证书生成脚本

这是一个用于自动化生成、配置和管理 Let's Encrypt SSL 证书的 Bash 脚本。旨在简化 HTTPS 证书的申请和维护流程。

## 功能特性

*   **自动依赖安装**：自动检测系统类型（Ubuntu/Debian 或 CentOS/RHEL）并安装 `certbot` 及相关依赖。
*   **多模式支持**：支持三种证书验证模式：
    *   **HTTP 验证**：配合 Nginx 使用。
    *   **DNS 验证**：适用于通配符证书或无法使用 80 端口的情况。
    *   **Standalone**：独立模式，无需 Web 服务器（自动临时启动服务）。
*   **环境检查**：自动检查域名 DNS 解析状态。
*   **安全配置**：自动配置防火墙（UFW 或 firewall-cmd），开放必要的 80/443 端口。
*   **自动续期**：自动添加 Cron 定时任务，确保证书不过期。

## 前置条件

*   Linux 操作系统（Ubuntu/Debian/CentOS/RHEL）。
*   **Root 权限**（脚本必须以 `sudo` 或 root 用户运行）。
*   域名已正确解析到运行脚本的服务器 IP。

## 使用方法

### 1. 下载脚本

```bash
git clone <repository_url>
cd letsencrypt
chmod +x ssl.sh
```

### 2. 运行脚本

**方式一：交互式运行（推荐）**

直接运行脚本，按照提示输入域名和选择验证方式：

```bash
sudo ./ssl.sh
```

**方式二：指定域名运行**

在命令行中直接指定一个或多个域名（空格分隔）：

```bash
sudo ./ssl.sh example.com www.example.com
```

### 3. 选择验证模式

运行过程中，脚本会询问选择哪种验证方式：

1.  **HTTP 验证**：需要服务器上已安装并运行 Nginx。Certbot 会自动修改 Nginx 配置完成验证。
2.  **DNS 验证**：脚本会暂停，要求你在域名提供商处添加指定的 TXT 记录。添加并生效后按回车继续。
3.  **Standalone 模式**：适用于没有 Web 服务器或想临时申请证书的情况。**注意**：此模式会临时占用 80 端口，如果已有 Nginx/Apache 运行，脚本会尝试暂停它们并在完成后重启。

## 证书位置

证书生成成功后，文件将保存在 `/etc/letsencrypt/live/<主域名>/` 目录下：

*   `fullchain.pem`：完整证书链（服务器配置使用此文件）。
*   `privkey.pem`：私钥文件（服务器配置使用此文件）。
*   `cert.pem`：服务器证书。
*   `chain.pem`：根证书和中级证书。

## 自动续期

脚本会自动设置每天运行的 Cron 任务进行证书检查和续期。
你可以通过以下命令手动测试续期：

```bash
sudo certbot renew --dry-run
```

## 注意事项

*   请确保在运行脚本前，域名的 A 记录已经解析到当前服务器。
*   如果使用 Standalone 模式，请确保 80 端口未被其他非标准服务占用。
*   脚本中默认配置了作者的邮箱，建议在脚本头部修改 `EMAIL` 变量为您自己的邮箱，以便接收证书过期提醒。

