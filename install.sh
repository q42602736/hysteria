#!/bin/bash

# Hysteria2 SSPanel 一键安装脚本
# 支持交互式配置和自动安装

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 全局变量
HYSTERIA_DIR="/opt/hysteria"
CONFIG_FILE="$HYSTERIA_DIR/config.yaml"
SERVICE_FILE="/etc/systemd/system/hysteria.service"
BINARY_NAME="hysteria"

# 打印带颜色的消息
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# 打印标题
print_title() {
    echo
    print_message $CYAN "=================================================="
    print_message $CYAN "  $1"
    print_message $CYAN "=================================================="
    echo
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_message $RED "错误：此脚本需要root权限运行"
        print_message $YELLOW "请使用: sudo $0"
        exit 1
    fi
}

# 检测系统架构
detect_arch() {
    local arch=$(uname -m)
    case $arch in
        x86_64)
            echo "amd64"
            ;;
        aarch64|arm64)
            echo "arm64"
            ;;
        armv7l)
            echo "armv7"
            ;;
        *)
            print_message $RED "不支持的架构: $arch"
            exit 1
            ;;
    esac
}

# 安装依赖
install_dependencies() {
    print_title "安装系统依赖"
    
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update
        apt-get install -y curl wget unzip systemd
    elif command -v yum >/dev/null 2>&1; then
        yum update -y
        yum install -y curl wget unzip systemd
    elif command -v dnf >/dev/null 2>&1; then
        dnf update -y
        dnf install -y curl wget unzip systemd
    else
        print_message $RED "不支持的包管理器"
        exit 1
    fi
    
    print_message $GREEN "依赖安装完成"
}

# 下载Hysteria2 SSPanel版本
download_hysteria() {
    print_title "下载Hysteria2 SSPanel版本"

    local arch=$(detect_arch)
    # 使用您自己编译的支持SSPanel的版本
    # 根据架构选择正确的文件名
    case $arch in
        "amd64")
            local download_url="https://github.com/q42602736/hysteria/releases/download/1.0/hysteria-sspanel-linux-amd64"
            ;;
        "arm64")
            local download_url="https://github.com/q42602736/hysteria/releases/download/1.0/hysteria-sspanel-linux-arm64"
            ;;
        "armv7")
            local download_url="https://github.com/q42602736/hysteria/releases/download/1.0/hysteria-sspanel-linux-arm32"
            ;;
        *)
            print_message $RED "不支持的架构: $arch"
            exit 1
            ;;
    esac

    print_message $BLUE "检测到架构: $arch"
    print_message $BLUE "下载SSPanel支持版本: $download_url"

    # 创建目录
    mkdir -p $HYSTERIA_DIR

    # 下载文件
    print_message $YELLOW "正在下载Hysteria2 SSPanel版本..."
    if curl -L -o "$HYSTERIA_DIR/$BINARY_NAME" "$download_url"; then
        chmod +x "$HYSTERIA_DIR/$BINARY_NAME"
        print_message $GREEN "Hysteria2 SSPanel版本下载完成"
    else
        print_message $RED "下载失败，请检查下载地址是否正确"
        print_message $YELLOW "请确保您的GitHub仓库中有编译好的二进制文件"
        exit 1
    fi

    # 验证下载
    if "$HYSTERIA_DIR/$BINARY_NAME" version >/dev/null 2>&1; then
        print_message $GREEN "Hysteria2验证成功"
    else
        print_message $RED "Hysteria2验证失败"
        exit 1
    fi
}

# 显示管理菜单
show_management_menu() {
    clear
    print_title "Hysteria2 后端管理脚本"

    # 显示当前状态
    if systemctl is-active --quiet hysteria; then
        print_message $GREEN "当前状态: 运行中"
    else
        print_message $RED "当前状态: 已停止"
    fi

    # 显示配置信息
    if [[ -f "$CONFIG_FILE" ]]; then
        echo
        echo "当前配置:"
        if grep -q "apiHost:" "$CONFIG_FILE"; then
            EXISTING_PANEL=$(grep "apiHost:" "$CONFIG_FILE" | awk '{print $2}')
            echo "  面板地址: $EXISTING_PANEL"
        fi
        if grep -q "nodeID:" "$CONFIG_FILE"; then
            EXISTING_NODE_ID=$(grep "nodeID:" "$CONFIG_FILE" | awk '{print $2}')
            echo "  节点ID: $EXISTING_NODE_ID"
        fi
        if grep -q "listen:" "$CONFIG_FILE"; then
            EXISTING_PORT=$(grep "listen:" "$CONFIG_FILE" | awk '{print $2}' | sed 's/://')
            echo "  监听端口: $EXISTING_PORT"
        fi
    fi

    echo
    echo "--- https://github.com/your-repo/hysteria2-sspanel ---"
    echo "0. 修改配置"
    echo
    echo "1. 安装 Hysteria2"
    echo "2. 更新 Hysteria2"
    echo "3. 卸载 Hysteria2"
    echo
    echo "4. 启动 Hysteria2"
    echo "5. 停止 Hysteria2"
    echo "6. 重启 Hysteria2"
    echo "7. 查看 Hysteria2 状态"
    echo "8. 查看 Hysteria2 日志"
    echo
    echo "9. 设置 Hysteria2 开机自启"
    echo "10. 取消 Hysteria2 开机自启"
    echo
    read -p "请输入选择 [0-10]: " menu_choice

    case $menu_choice in
        0)
            # 备份现有配置
            cp "$CONFIG_FILE" "$CONFIG_FILE.backup.$(date +%Y%m%d_%H%M%S)"
            print_message $BLUE "已备份现有配置"
            return 1  # 继续配置收集
            ;;
        1)
            if [[ -f "$HYSTERIA_DIR/$BINARY_NAME" ]]; then
                print_message $YELLOW "Hysteria2 已安装，将重新安装"
            fi
            return 2  # 重新安装
            ;;
        2)
            print_message $YELLOW "更新 Hysteria2..."
            download_hysteria
            systemctl restart hysteria
            print_message $GREEN "更新完成"
            exit 0
            ;;
        3)
            uninstall
            exit 0
            ;;
        4)
            systemctl start hysteria
            if systemctl is-active --quiet hysteria; then
                print_message $GREEN "Hysteria2 启动成功"
            else
                print_message $RED "Hysteria2 启动失败"
                diagnose_service
            fi
            echo
            read -p "按任意键继续..." -n 1
            show_management_menu
            ;;
        5)
            systemctl stop hysteria
            print_message $GREEN "Hysteria2 已停止"
            echo
            read -p "按任意键继续..." -n 1
            show_management_menu
            ;;
        6)
            systemctl restart hysteria
            if systemctl is-active --quiet hysteria; then
                print_message $GREEN "Hysteria2 重启成功"
            else
                print_message $RED "Hysteria2 重启失败"
                diagnose_service
            fi
            echo
            read -p "按任意键继续..." -n 1
            show_management_menu
            ;;
        7)
            diagnose_service
            echo
            read -p "按任意键继续..." -n 1
            show_management_menu
            ;;
        8)
            print_message $BLUE "查看 Hysteria2 日志 (按 Ctrl+C 退出)"
            journalctl -u hysteria -f
            echo
            read -p "按任意键继续..." -n 1
            show_management_menu
            ;;
        9)
            systemctl enable hysteria
            print_message $GREEN "已设置开机自启"
            echo
            read -p "按任意键继续..." -n 1
            show_management_menu
            ;;
        10)
            systemctl disable hysteria
            print_message $GREEN "已取消开机自启"
            echo
            read -p "按任意键继续..." -n 1
            show_management_menu
            ;;
        *)
            print_message $RED "无效选择"
            exit 1
            ;;
    esac
}

# 交互式配置收集
collect_config() {
    print_title "配置信息收集"
    
    # 面板信息
    print_message $CYAN "=== 面板配置 ==="
    read -p "请输入面板地址 (如: https://panel.example.com): " PANEL_HOST
    read -p "请输入面板API密钥: " API_KEY
    read -p "请输入节点ID: " NODE_ID
    
    # 服务器配置
    print_message $CYAN "=== 服务器配置 ==="
    read -p "请输入监听端口 [默认: 1253]: " LISTEN_PORT
    LISTEN_PORT=${LISTEN_PORT:-1253}
    
    read -p "请输入服务器域名 (如: node.example.com): " SERVER_DOMAIN
    
    # 混淆配置
    print_message $CYAN "=== 混淆配置 ==="
    read -p "是否启用混淆? (y/n) [默认: y]: " ENABLE_OBFS
    ENABLE_OBFS=${ENABLE_OBFS:-y}
    
    if [[ $ENABLE_OBFS == "y" || $ENABLE_OBFS == "Y" ]]; then
        read -p "请输入混淆密码: " OBFS_PASSWORD
    fi
    
    # 证书配置
    print_message $CYAN "=== 证书配置 ==="
    echo "请选择证书类型:"
    echo "1) ACME自动证书 (推荐)"
    echo "2) 自签名证书"
    echo "3) 手动指定证书文件"
    read -p "请选择 [1-3]: " CERT_TYPE
    
    case $CERT_TYPE in
        1)
            read -p "请输入邮箱地址: " ACME_EMAIL
            ;;
        2)
            CERT_PATH="/etc/hysteria/server.crt"
            KEY_PATH="/etc/hysteria/server.key"
            ;;
        3)
            read -p "请输入证书文件路径: " CERT_PATH
            read -p "请输入私钥文件路径: " KEY_PATH
            ;;
        *)
            print_message $RED "无效选择"
            exit 1
            ;;
    esac
    
    # 带宽配置
    print_message $CYAN "=== 带宽配置 ==="
    read -p "请输入上行带宽 (如: 100 mbps) [默认: 1 gbps]: " BANDWIDTH_UP
    BANDWIDTH_UP=${BANDWIDTH_UP:-"1 gbps"}

    read -p "请输入下行带宽 (如: 200 mbps) [默认: 1 gbps]: " BANDWIDTH_DOWN
    BANDWIDTH_DOWN=${BANDWIDTH_DOWN:-"1 gbps"}

    # 伪装网站配置
    print_message $CYAN "=== 伪装网站配置 ==="
    echo "请选择伪装网站 (用于增强抗审查能力):"
    echo "1) Microsoft官网 (https://www.microsoft.com)"
    echo "2) Google官网 (https://www.google.com)"
    echo "3) GitHub官网 (https://github.com)"
    echo "4) Cloudflare官网 (https://www.cloudflare.com)"
    echo "5) Amazon官网 (https://www.amazon.com)"
    echo "6) Apple官网 (https://www.apple.com)"
    echo "7) Netflix官网 (https://www.netflix.com)"
    echo "8) YouTube官网 (https://www.youtube.com)"
    echo "9) Wikipedia (https://www.wikipedia.org)"
    echo "10) BBC新闻 (https://www.bbc.com)"
    echo "11) CNN新闻 (https://www.cnn.com)"
    echo "12) 自定义网站"
    echo "0) 随机选择 (推荐)"
    read -p "请选择 [0-12] [默认: 0]: " MASQ_CHOICE
    MASQ_CHOICE=${MASQ_CHOICE:-0}

    # 预定义伪装网站列表
    MASQ_SITES=(
        "https://www.microsoft.com"
        "https://www.google.com"
        "https://github.com"
        "https://www.cloudflare.com"
        "https://www.amazon.com"
        "https://www.apple.com"
        "https://www.netflix.com"
        "https://www.youtube.com"
        "https://www.wikipedia.org"
        "https://www.bbc.com"
        "https://www.cnn.com"
    )

    case $MASQ_CHOICE in
        0)
            # 随机选择
            RANDOM_INDEX=$((RANDOM % ${#MASQ_SITES[@]}))
            MASQ_URL="${MASQ_SITES[$RANDOM_INDEX]}"
            print_message $GREEN "随机选择: $MASQ_URL"
            ;;
        1|2|3|4|5|6|7|8|9|10|11)
            MASQ_URL="${MASQ_SITES[$((MASQ_CHOICE-1))]}"
            ;;
        12)
            read -p "请输入自定义伪装网站URL: " MASQ_URL
            ;;
        *)
            print_message $YELLOW "无效选择，使用默认: Microsoft官网"
            MASQ_URL="https://www.microsoft.com"
            ;;
    esac
    
    # 确认配置
    print_title "配置确认"
    echo "面板地址: $PANEL_HOST"
    echo "API密钥: $API_KEY"
    echo "节点ID: $NODE_ID"
    echo "监听端口: $LISTEN_PORT"
    echo "服务器域名: $SERVER_DOMAIN"
    echo "启用混淆: $ENABLE_OBFS"
    [[ $ENABLE_OBFS == "y" || $ENABLE_OBFS == "Y" ]] && echo "混淆密码: $OBFS_PASSWORD"
    echo "证书类型: $CERT_TYPE"
    echo "上行带宽: $BANDWIDTH_UP"
    echo "下行带宽: $BANDWIDTH_DOWN"
    echo "伪装网站: $MASQ_URL"
    echo
    
    read -p "确认配置无误? (y/n) [默认: y]: " CONFIRM
    CONFIRM=${CONFIRM:-y}
    if [[ $CONFIRM != "y" && $CONFIRM != "Y" ]]; then
        print_message $YELLOW "配置已取消"
        exit 0
    fi
}

# 生成证书
generate_certificate() {
    if [[ $CERT_TYPE == "2" ]]; then
        print_title "生成自签名证书"
        
        mkdir -p /etc/hysteria
        
        print_message $YELLOW "正在生成自签名证书..."
        openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) \
            -keyout "$KEY_PATH" \
            -out "$CERT_PATH" \
            -subj "/CN=$SERVER_DOMAIN" \
            -days 36500
        
        # 设置权限
        chown root:root "$CERT_PATH" "$KEY_PATH"
        chmod 644 "$CERT_PATH"
        chmod 600 "$KEY_PATH"
        
        print_message $GREEN "自签名证书生成完成"
    fi
}

# 生成配置文件
generate_config() {
    print_title "生成配置文件"

    cat > "$CONFIG_FILE" << EOF
# Hysteria2 SSPanel配置文件
# 由安装脚本自动生成

log:
  level: info
  output: /var/log/hysteria.log

panelType: sspanel

sspanel:
  apiHost: $PANEL_HOST
  apiKey: $API_KEY
  nodeID: $NODE_ID
  nodeType: hysteria2
  pullInterval: 10
  pushInterval: 10

listen: :$LISTEN_PORT

EOF

    # 添加混淆配置
    if [[ $ENABLE_OBFS == "y" || $ENABLE_OBFS == "Y" ]]; then
        cat >> "$CONFIG_FILE" << EOF
obfs:
  type: salamander
  salamander:
    password: $OBFS_PASSWORD

EOF
    fi

    # 添加证书配置
    case $CERT_TYPE in
        1)
            cat >> "$CONFIG_FILE" << EOF
acme:
  domains:
    - $SERVER_DOMAIN
  email: $ACME_EMAIL
  ca: letsencrypt
  type: http

EOF
            ;;
        2|3)
            cat >> "$CONFIG_FILE" << EOF
tls:
  cert: $CERT_PATH
  key: $KEY_PATH

EOF
            ;;
    esac

    # 添加其余配置
    cat >> "$CONFIG_FILE" << EOF
auth:
  type: sspanel

bandwidth:
  up: $BANDWIDTH_UP
  down: $BANDWIDTH_DOWN

trafficStats:
  listen: 127.0.0.1:8080
  secret: $(openssl rand -hex 16)

masquerade:
  type: proxy
  proxy:
    url: $MASQ_URL
    rewriteHost: true

# 出站规则配置
outbounds:
  - name: direct
    type: direct
    direct:
      mode: auto  # 默认双栈模式
  - name: ipv4_only
    type: direct
    direct:
      mode: 4     # 强制使用IPv4
  - name: ipv6_only
    type: direct
    direct:
      mode: 6     # 强制使用IPv6

# ACL分流规则
acl:
  inline:
    # 1. 拒绝中国IP访问
    - reject(geoip:cn)
    
    # 2. 拒绝中国网站访问
    - reject(geosite:cn)

ignoreClientBandwidth: false
disableUDP: false
udpIdleTimeout: 60s
EOF

    print_message $GREEN "配置文件生成完成: $CONFIG_FILE"
}

# 创建systemd服务
create_service() {
    print_title "创建系统服务"

    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Hysteria2 SSPanel Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$HYSTERIA_DIR
ExecStart=$HYSTERIA_DIR/$BINARY_NAME server -c $CONFIG_FILE
Restart=always
RestartSec=3
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

    # 重载systemd并启用服务
    systemctl daemon-reload
    systemctl enable hysteria

    print_message $GREEN "系统服务创建完成"
}

# 配置防火墙
configure_firewall() {
    print_title "配置防火墙"

    # 检查并配置防火墙
    if command -v ufw >/dev/null 2>&1; then
        print_message $YELLOW "配置UFW防火墙..."
        ufw allow $LISTEN_PORT/udp
        if [[ $CERT_TYPE == "1" ]]; then
            ufw allow 80/tcp  # ACME HTTP挑战
        fi
    elif command -v firewall-cmd >/dev/null 2>&1; then
        print_message $YELLOW "配置firewalld防火墙..."
        firewall-cmd --permanent --add-port=$LISTEN_PORT/udp
        if [[ $CERT_TYPE == "1" ]]; then
            firewall-cmd --permanent --add-port=80/tcp
        fi
        firewall-cmd --reload
    else
        print_message $YELLOW "未检测到防火墙，请手动开放端口 $LISTEN_PORT/udp"
        if [[ $CERT_TYPE == "1" ]]; then
            print_message $YELLOW "ACME证书需要开放端口 80/tcp"
        fi
    fi

    print_message $GREEN "防火墙配置完成"
}

# 诊断服务问题
diagnose_service() {
    print_title "服务诊断"

    print_message $YELLOW "正在诊断Hysteria2服务问题..."

    # 检查配置文件
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_message $RED "❌ 配置文件不存在: $CONFIG_FILE"
        return 1
    else
        print_message $GREEN "✅ 配置文件存在"
    fi

    # 检查程序文件
    if [[ ! -f "$HYSTERIA_DIR/$BINARY_NAME" ]]; then
        print_message $RED "❌ 程序文件不存在: $HYSTERIA_DIR/$BINARY_NAME"
        return 1
    else
        print_message $GREEN "✅ 程序文件存在"
    fi

    # 检查配置文件语法 (使用YAML语法检查)
    if command -v python3 >/dev/null 2>&1; then
        if python3 -c "import yaml; yaml.safe_load(open('$CONFIG_FILE'))" >/dev/null 2>&1; then
            print_message $GREEN "✅ 配置文件YAML语法正确"
        else
            print_message $RED "❌ 配置文件YAML语法错误"
            return 1
        fi
    else
        # 简单检查配置文件关键字段
        if grep -q "panelType:" "$CONFIG_FILE" && \
           grep -q "sspanel:" "$CONFIG_FILE" && \
           grep -q "listen:" "$CONFIG_FILE" && \
           grep -q "auth:" "$CONFIG_FILE"; then
            print_message $GREEN "✅ 配置文件基本结构正确"
        else
            print_message $RED "❌ 配置文件缺少必要字段"
            return 1
        fi
    fi

    # 检查端口占用
    local port=$(grep "listen:" "$CONFIG_FILE" | awk '{print $2}' | sed 's/://')
    if netstat -tlnp | grep ":$port " >/dev/null 2>&1; then
        local process=$(netstat -tlnp | grep ":$port " | awk '{print $7}')
        if [[ "$process" == *"hysteria"* ]]; then
            print_message $GREEN "✅ 端口 $port 被Hysteria2正常占用"
        else
            print_message $RED "❌ 端口 $port 被其他进程占用: $process"
            return 1
        fi
    else
        print_message $YELLOW "⚠️  端口 $port 未被占用"
    fi

    # 检查服务状态
    if systemctl is-active --quiet hysteria; then
        print_message $GREEN "✅ 服务正在运行"
    else
        print_message $RED "❌ 服务未运行"
        print_message $YELLOW "服务状态:"
        systemctl status hysteria --no-pager -l || true
        print_message $YELLOW "最近的错误日志:"
        journalctl -u hysteria --since "10 minutes ago" --no-pager -l | tail -20 || true
        return 1
    fi

    print_message $GREEN "✅ 服务诊断完成"
    return 0
}

# 启动服务
start_service() {
    print_title "启动Hysteria2服务"

    # 如果使用ACME，确保80端口可用
    if [[ $CERT_TYPE == "1" ]]; then
        print_message $YELLOW "检查80端口占用情况..."
        if netstat -tlnp | grep :80 >/dev/null 2>&1; then
            print_message $YELLOW "80端口被占用，尝试停止可能的服务..."
            systemctl stop nginx apache2 2>/dev/null || true
        fi
    fi

    # 启动服务
    print_message $YELLOW "启动Hysteria2服务..."
    if systemctl start hysteria; then
        print_message $GREEN "服务启动成功"
    else
        print_message $RED "服务启动失败"
        print_message $YELLOW "正在进行服务诊断..."

        if diagnose_service; then
            print_message $YELLOW "诊断完成，尝试重新启动..."
            systemctl restart hysteria
        else
            print_message $RED "服务诊断发现问题"
            print_message $YELLOW "建议操作:"
            echo "1. 检查配置文件: cat $CONFIG_FILE"
            echo "2. 查看详细日志: journalctl -u hysteria -f"
            echo "3. 重新运行安装: $0"
            echo "4. 手动启动测试: $HYSTERIA_DIR/$BINARY_NAME server -c $CONFIG_FILE"
            exit 1
        fi
    fi

    # 等待服务稳定
    sleep 3

    # 检查服务状态
    if systemctl is-active --quiet hysteria; then
        print_message $GREEN "Hysteria2服务运行正常"
    else
        print_message $RED "服务状态异常"
        systemctl status hysteria --no-pager
        exit 1
    fi
}

# 显示安装结果
show_result() {
    print_title "安装完成"

    print_message $GREEN "🎉 Hysteria2安装成功！"
    echo
    print_message $CYAN "=== 服务信息 ==="
    echo "服务状态: $(systemctl is-active hysteria)"
    echo "配置文件: $CONFIG_FILE"
    echo "日志文件: /var/log/hysteria.log"
    echo "服务管理: systemctl {start|stop|restart|status} hysteria"
    echo

    print_message $CYAN "=== 节点信息 ==="
    echo "监听端口: $LISTEN_PORT"
    echo "服务器域名: $SERVER_DOMAIN"
    echo "混淆启用: $ENABLE_OBFS"
    [[ $ENABLE_OBFS == "y" || $ENABLE_OBFS == "Y" ]] && echo "混淆密码: $OBFS_PASSWORD"
    echo

    print_message $CYAN "=== 面板配置 ==="
    echo "在面板中创建节点时，服务器地址应填写:"
    if [[ $ENABLE_OBFS == "y" || $ENABLE_OBFS == "Y" ]]; then
        echo "$SERVER_DOMAIN;port=$LISTEN_PORT;sni=$SERVER_DOMAIN;obfs=salamander;obfs_password=$OBFS_PASSWORD;up=${BANDWIDTH_UP// /};down=${BANDWIDTH_DOWN// /}"
    else
        echo "$SERVER_DOMAIN;port=$LISTEN_PORT;sni=$SERVER_DOMAIN;up=${BANDWIDTH_UP// /};down=${BANDWIDTH_DOWN// /}"
    fi
    echo

    print_message $CYAN "=== 常用命令 ==="
    echo "查看服务状态: systemctl status hysteria"
    echo "查看实时日志: journalctl -u hysteria -f"
    echo "重启服务: systemctl restart hysteria"
    echo "查看配置: cat $CONFIG_FILE"
    echo

    if [[ $CERT_TYPE == "1" ]]; then
        print_message $YELLOW "注意: 使用ACME证书时，首次启动可能需要几分钟申请证书"
        print_message $YELLOW "请确保域名 $SERVER_DOMAIN 正确解析到本服务器IP"
    fi

    print_message $GREEN "安装完成！请在面板中添加节点并测试连接。"
}

# 卸载函数
uninstall() {
    print_title "卸载Hysteria2"

    read -p "确定要卸载Hysteria2吗? (y/n): " CONFIRM_UNINSTALL
    if [[ $CONFIRM_UNINSTALL != "y" && $CONFIRM_UNINSTALL != "Y" ]]; then
        print_message $YELLOW "取消卸载"
        exit 0
    fi

    # 停止并禁用服务
    print_message $YELLOW "停止服务..."
    systemctl stop hysteria 2>/dev/null || true
    systemctl disable hysteria 2>/dev/null || true

    # 删除文件
    print_message $YELLOW "删除文件..."
    rm -rf "$HYSTERIA_DIR"
    rm -f "$SERVICE_FILE"
    rm -f /var/log/hysteria.log

    # 重载systemd
    systemctl daemon-reload

    print_message $GREEN "卸载完成"
}

# 主函数
main() {
    # 检查参数
    case "${1:-}" in
        "uninstall")
            check_root
            uninstall
            exit 0
            ;;
        "fix"|"repair")
            check_root
            print_title "Hysteria2 修复模式"
            if diagnose_service; then
                print_message $GREEN "服务运行正常，无需修复"
            else
                print_message $YELLOW "尝试修复服务..."
                create_service
                systemctl daemon-reload
                systemctl restart hysteria
                if systemctl is-active --quiet hysteria; then
                    print_message $GREEN "✅ 服务修复成功"
                else
                    print_message $RED "❌ 服务修复失败"
                    diagnose_service
                fi
            fi
            exit 0
            ;;
        "restart")
            check_root
            print_title "重启Hysteria2服务"
            systemctl restart hysteria
            if systemctl is-active --quiet hysteria; then
                print_message $GREEN "✅ 服务重启成功"
            else
                print_message $RED "❌ 服务重启失败"
                diagnose_service
            fi
            exit 0
            ;;
        "status")
            print_title "Hysteria2 状态检查"
            diagnose_service
            exit 0
            ;;
        "help"|"-h"|"--help")
            echo "用法: $0 [选项]"
            echo "选项:"
            echo "  无参数    - 安装Hysteria2"
            echo "  fix       - 修复服务问题"
            echo "  restart   - 重启服务"
            echo "  status    - 检查服务状态"
            echo "  uninstall - 卸载Hysteria2"
            echo "  help      - 显示帮助"
            exit 0
            ;;
    esac

    # 显示欢迎信息
    clear
    print_title "Hysteria2 SSPanel 一键安装脚本"
    print_message $BLUE "作者: AI Assistant"
    print_message $BLUE "版本: 1.0.0"
    print_message $BLUE "支持: Ubuntu/Debian/CentOS/RHEL"
    echo

    # 执行安装流程
    check_root

    # 首先检查是否已有配置，如果有则显示管理菜单
    if [[ -f "$CONFIG_FILE" ]]; then
        show_management_menu
        # 管理菜单中的大部分操作都会直接exit
        # 只有选择重新配置才会继续到这里
    fi

    # 只有首次安装或重新配置时才执行以下步骤
    install_dependencies
    download_hysteria
    collect_config
    generate_certificate
    generate_config
    create_service
    configure_firewall
    start_service
    show_result
}

# 脚本入口
main "$@"
