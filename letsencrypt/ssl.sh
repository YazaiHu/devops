#!/bin/bash

# Let's Encrypt SSL 证书生成和配置脚本
# 适用于 example.com www.example.com

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 域名配置
DEFAULT_DOMAINS="www.example.com"
EMAIL="example@gmail.com"  # 请替换为您的邮箱

# 获取域名参数
if [ -n "$1" ]; then
    DOMAINS="$@"
else
    read -p "请输入域名（多个域名用空格分隔，回车使用默认值 $DEFAULT_DOMAINS）: " input_domains
    if [ -z "$input_domains" ]; then
        DOMAINS="$DEFAULT_DOMAINS"
    else
        DOMAINS="$input_domains"
    fi
fi

# 获取主域名（用于文件路径）
MAIN_DOMAIN=$(echo $DOMAINS | awk '{print $1}')

# 检查是否以 root 权限运行
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}错误：此脚本需要 root 权限运行${NC}"
   echo "请使用 sudo 运行此脚本"
   exit 1
fi

echo -e "${GREEN}=== Let's Encrypt SSL 证书生成脚本 ===${NC}"
echo -e "${YELLOW}目标域名：${DOMAINS}${NC}"
echo

# 函数：检查命令是否存在
check_command() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}错误：$1 未安装${NC}"
        return 1
    fi
    return 0
}

# 函数：安装 Certbot
install_certbot() {
    echo -e "${GREEN}正在安装 Certbot...${NC}"

    if [[ -f /etc/debian_version ]]; then
        # Ubuntu/Debian
        apt update
        apt install -y inetutils-ping dnsutils cron ufw
        apt install -y certbot python3-certbot-nginx snapd
    elif [[ -f /etc/redhat-release ]]; then
        # CentOS/RHEL
        yum install -y epel-release
        yum install -y certbot python3-certbot-nginx snapd
    else
        echo -e "${RED}不支持的操作系统${NC}"
        exit 1
    fi

    echo -e "${GREEN}Certbot 安装完成${NC}"
}

# 函数：检查域名解析
check_dns() {
    echo -e "${GREEN}检查域名解析...${NC}"

    for domain in $DOMAINS; do
        echo -n "检查 $domain... "
        if dig +short $domain | grep -q "[0-9]"; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${RED}✗${NC}"
            echo -e "${RED}错误：域名 $domain 无法解析${NC}"
            echo "请确保域名正确解析到当前服务器"
            exit 1
        fi
    done
}

# 函数：配置防火墙
configure_firewall() {
    echo -e "${GREEN}配置防火墙...${NC}"

    if command -v ufw &> /dev/null; then
        ufw allow 80/tcp
        ufw allow 443/tcp
        ufw allow 8443/tcp
        echo -e "${GREEN}UFW 防火墙配置完成${NC}"
    elif command -v firewall-cmd &> /dev/null; then
        firewall-cmd --permanent --add-port=80/tcp
        firewall-cmd --permanent --add-port=443/tcp
        firewall-cmd --permanent --add-port=8443/tcp
        firewall-cmd --reload
        echo -e "${GREEN}firewalld 防火墙配置完成${NC}"
    else
        echo -e "${YELLOW}未检测到防火墙，请手动开放 80 和 443 端口${NC}"
    fi
}

# 函数：生成证书
generate_certificate() {
    echo -e "${GREEN}生成 SSL 证书...${NC}"

    # 构建域名参数
    DOMAIN_ARGS=""
    for domain in $DOMAINS; do
        DOMAIN_ARGS="$DOMAIN_ARGS -d $domain"
    done

    # 检查是否已有证书
    if [[ -f "/etc/letsencrypt/live/${MAIN_DOMAIN}/fullchain.pem" ]]; then
        echo -e "${YELLOW}检测到已有证书，是否重新生成？(y/n)${NC}"
        read -r response
        if [[ "$response" != "y" ]]; then
            echo "跳过证书生成"
            return 0
        fi
    fi

    # 选择验证方式
    echo -e "${YELLOW}选择验证方式：${NC}"
    echo "1) HTTP 验证（需要 Web 服务器运行）"
    echo "2) DNS 验证（手动添加 TXT 记录）"
    echo "3) Standalone 模式（自动临时服务器）"
    read -p "请选择 (1-3): " choice

    case $choice in
        1)
            if check_command nginx; then
                certbot --nginx $DOMAIN_ARGS --email $EMAIL --agree-tos --non-interactive
            else
                echo -e "${RED}错误：未找到 Nginx${NC}"
                exit 1
            fi
            ;;
        2)
            certbot certonly --manual --preferred-challenges dns $DOMAIN_ARGS --email $EMAIL --agree-tos
            ;;
        3)
            # 停止可能占用端口的服务
            systemctl stop nginx 2>/dev/null || true

            certbot certonly --standalone $DOMAIN_ARGS --email $EMAIL --agree-tos --non-interactive

            # 重新启动服务
            systemctl start nginx 2>/dev/null || true
            ;;
        *)
            echo -e "${RED}无效选择${NC}"
            exit 1
            ;;
    esac

    echo -e "${GREEN}证书生成完成！${NC}"
}

# 函数：配置自动续期
setup_auto_renewal() {
    echo -e "${GREEN}配置自动续期...${NC}"

    # 添加 cron 任务
    (crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet") | crontab -

    # 测试续期
    certbot renew --dry-run

    echo -e "${GREEN}自动续期配置完成${NC}"
}

# 函数：显示证书信息
show_certificate_info() {
    echo -e "${GREEN}=== 证书信息 ===${NC}"
    echo "证书文件位置：/etc/letsencrypt/live/${MAIN_DOMAIN}/"
    echo "  - 证书文件：cert.pem"
    echo "  - 私钥文件：privkey.pem"
    echo "  - 证书链：chain.pem"
    echo "  - 完整证书链：fullchain.pem（推荐使用）"
    echo
    echo -e "${GREEN}证书有效期：${NC}"
    certbot certificates | grep -A 10 "${MAIN_DOMAIN}"
    echo
    echo -e "${GREEN}Nginx 配置示例已保存至 nginx-ssl-config.conf${NC}"
}

# 主执行流程
main() {
    # 检查并安装 Certbot
    if ! check_command certbot; then
        install_certbot
    fi

    # 检查域名解析
    check_dns

    # 配置防火墙
    configure_firewall

    # 生成证书
    generate_certificate

    # 配置自动续期
    setup_auto_renewal

    # 显示证书信息
    show_certificate_info

    echo -e "${GREEN}=== 完成 ===${NC}"
    echo -e "${GREEN}SSL 证书已成功生成并配置！${NC}"
    echo -e "${YELLOW}请根据 nginx-ssl-config.conf 配置您的 Web 服务器${NC}"
}

# 运行主函数
main "$@"