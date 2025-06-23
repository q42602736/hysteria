#!/bin/bash

# Hysteria2 SSPanel版本一键在线安装脚本
# 自动从GitHub releases下载最新版本
# 支持 Linux x64, ARM64, ARM32

set -e

# 配置信息
GITHUB_REPO="q42602736/hysteria"
GITHUB_API="https://api.github.com/repos/${GITHUB_REPO}"
GITHUB_RELEASES="https://github.com/${GITHUB_REPO}/releases"
INSTALL_DIR="/opt/hysteria"
SERVICE_NAME="hysteria"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印彩色信息
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查命令是否存在
check_command() {
    if ! command -v "$1" &> /dev/null; then
        print_error "命令 $1 未找到，请先安装"
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
        armv7l|armv6l)
            echo "arm32"
            ;;
        *)
            print_error "不支持的架构: $arch"
            exit 1
            ;;
    esac
}

# 检测操作系统
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    else
        print_error "不支持的操作系统: $OSTYPE"
        exit 1
    fi
}

# 获取最新版本号
get_latest_version() {
    print_info "获取最新版本信息..."
    local latest_version
    
    # 尝试使用curl获取最新版本
    if command -v curl &> /dev/null; then
        latest_version=$(curl -s "${GITHUB_API}/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    elif command -v wget &> /dev/null; then
        latest_version=$(wget -qO- "${GITHUB_API}/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    else
        print_error "需要 curl 或 wget 来下载文件"
        exit 1
    fi
    
    if [[ -z "$latest_version" ]]; then
        print_error "无法获取最新版本信息"
        exit 1
    fi
    
    echo "$latest_version"
}

# 下载文件
download_file() {
    local url="$1"
    local output="$2"
    
    print_info "下载: $url"
    
    if command -v curl &> /dev/null; then
        curl -L -o "$output" "$url"
    elif command -v wget &> /dev/null; then
        wget -O "$output" "$url"
    else
        print_error "需要 curl 或 wget 来下载文件"
        exit 1
    fi
}

# 主安装函数
install_hysteria() {
    print_info "开始安装 Hysteria2 SSPanel版本..."
    
    # 检查必要命令
    check_command "uname"
    
    # 检测系统
    local os=$(detect_os)
    local arch=$(detect_arch)
    local binary_name="hysteria-sspanel-${os}-${arch}"
    
    print_info "检测到系统: ${os}-${arch}"
    
    # 获取最新版本
    local version=$(get_latest_version)
    print_info "最新版本: $version"
    
    # 构建下载URL
    local download_url="${GITHUB_RELEASES}/download/${version}/${binary_name}"
    local config_sspanel_url="${GITHUB_RELEASES}/download/${version}/config-sspanel-example.yaml"
    local config_v2board_url="${GITHUB_RELEASES}/download/${version}/config-v2board-example.yaml"
    local readme_url="${GITHUB_RELEASES}/download/${version}/README-SSPANEL.md"

    print_info "下载地址: $download_url"
    
    # 创建临时目录
    local temp_dir=$(mktemp -d)
    cd "$temp_dir"
    
    # 下载文件
    print_info "下载二进制文件..."
    download_file "$download_url" "$binary_name"
    
    print_info "下载配置文件..."
    download_file "$config_sspanel_url" "config-sspanel-example.yaml"
    download_file "$config_v2board_url" "config-v2board-example.yaml" || print_warning "V2board配置下载失败，跳过"
    download_file "$readme_url" "README-SSPANEL.md" || print_warning "说明文档下载失败，跳过"
    
    # 验证下载的文件
    if [[ ! -f "$binary_name" ]]; then
        print_error "二进制文件下载失败"
        exit 1
    fi
    
    # 创建安装目录
    print_info "创建安装目录: $INSTALL_DIR"
    sudo mkdir -p "$INSTALL_DIR"
    
    # 安装二进制文件
    print_info "安装二进制文件..."
    sudo cp "$binary_name" "$INSTALL_DIR/hysteria"
    sudo chmod +x "$INSTALL_DIR/hysteria"
    
    # 安装配置文件
    print_info "安装配置文件..."
    if [[ ! -f "$INSTALL_DIR/config.yaml" ]]; then
        sudo cp "config-sspanel-example.yaml" "$INSTALL_DIR/config.yaml"
        print_warning "请编辑 $INSTALL_DIR/config.yaml 配置文件"
    else
        print_info "配置文件已存在，跳过复制"
    fi
    
    # 复制示例配置和文档
    [[ -f "config-sspanel-example.yaml" ]] && sudo cp "config-sspanel-example.yaml" "$INSTALL_DIR/"
    [[ -f "config-v2board-example.yaml" ]] && sudo cp "config-v2board-example.yaml" "$INSTALL_DIR/"
    [[ -f "README-SSPANEL.md" ]] && sudo cp "README-SSPANEL.md" "$INSTALL_DIR/"
    
    # 创建systemd服务
    print_info "创建systemd服务..."
    sudo tee /etc/systemd/system/${SERVICE_NAME}.service > /dev/null <<EOF
[Unit]
Description=Hysteria2 SSPanel Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/hysteria server -c $INSTALL_DIR/config.yaml
Restart=always
RestartSec=5
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
    
    # 重载systemd
    sudo systemctl daemon-reload
    sudo systemctl enable ${SERVICE_NAME}
    
    # 清理临时文件
    cd /
    rm -rf "$temp_dir"
    
    print_success "安装完成！"
    print_info "安装目录: $INSTALL_DIR"
    print_info "配置文件: $INSTALL_DIR/config.yaml"
    print_info "服务名称: $SERVICE_NAME"
    print_info "版本: $version"
    
    echo
    print_warning "下一步操作:"
    echo "1. 编辑配置文件: sudo nano $INSTALL_DIR/config.yaml"
    echo "2. 启动服务: sudo systemctl start $SERVICE_NAME"
    echo "3. 查看状态: sudo systemctl status $SERVICE_NAME"
    echo "4. 查看日志: sudo journalctl -u $SERVICE_NAME -f"
    echo "5. 开机自启: sudo systemctl enable $SERVICE_NAME"
}

# 卸载函数
uninstall_hysteria() {
    print_info "开始卸载 Hysteria2..."
    
    # 停止服务
    sudo systemctl stop ${SERVICE_NAME} 2>/dev/null || true
    sudo systemctl disable ${SERVICE_NAME} 2>/dev/null || true
    
    # 删除服务文件
    sudo rm -f /etc/systemd/system/${SERVICE_NAME}.service
    sudo systemctl daemon-reload
    
    # 删除安装目录
    sudo rm -rf "$INSTALL_DIR"
    
    print_success "卸载完成！"
}

# 更新函数
update_hysteria() {
    print_info "更新 Hysteria2 到最新版本..."
    
    # 备份配置文件
    if [[ -f "$INSTALL_DIR/config.yaml" ]]; then
        sudo cp "$INSTALL_DIR/config.yaml" "/tmp/hysteria-config-backup.yaml"
        print_info "配置文件已备份到 /tmp/hysteria-config-backup.yaml"
    fi
    
    # 停止服务
    sudo systemctl stop ${SERVICE_NAME} 2>/dev/null || true
    
    # 重新安装
    install_hysteria
    
    # 恢复配置文件
    if [[ -f "/tmp/hysteria-config-backup.yaml" ]]; then
        sudo cp "/tmp/hysteria-config-backup.yaml" "$INSTALL_DIR/config.yaml"
        sudo rm -f "/tmp/hysteria-config-backup.yaml"
        print_info "配置文件已恢复"
    fi
    
    print_success "更新完成！"
}

# 显示帮助
show_help() {
    echo "Hysteria2 SSPanel版本在线安装脚本"
    echo
    echo "用法: $0 [选项]"
    echo
    echo "选项:"
    echo "  install     安装 Hysteria2"
    echo "  uninstall   卸载 Hysteria2"
    echo "  update      更新 Hysteria2"
    echo "  help        显示此帮助信息"
    echo
    echo "支持的架构:"
    echo "  - Linux x64 (amd64)"
    echo "  - Linux ARM64 (aarch64)"
    echo "  - Linux ARM32 (armv7l/armv6l)"
    echo
    echo "GitHub仓库: https://github.com/${GITHUB_REPO}"
}

# 主程序
main() {
    case "${1:-install}" in
        install)
            install_hysteria
            ;;
        uninstall)
            uninstall_hysteria
            ;;
        update)
            update_hysteria
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
}

# 检查是否为root用户
if [[ $EUID -eq 0 ]]; then
    print_warning "检测到root用户，继续安装..."
else
    print_info "需要sudo权限进行安装"
fi

# 运行主程序
main "$@"
