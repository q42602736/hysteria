#!/bin/bash

# Hysteria2 SSPanel版本一键安装脚本
# 支持 Linux x64, ARM64, ARM32

set -e

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

# 主安装函数
install_hysteria() {
    print_info "开始安装 Hysteria2 SSPanel版本..."
    
    # 检测系统
    local os=$(detect_os)
    local arch=$(detect_arch)
    local binary_name="hysteria-sspanel-${os}-${arch}"
    
    print_info "检测到系统: ${os}-${arch}"
    
    # 检查二进制文件是否存在
    if [[ ! -f "$binary_name" ]]; then
        print_error "找不到对应的二进制文件: $binary_name"
        print_info "可用的文件:"
        ls -la hysteria-sspanel-*
        exit 1
    fi
    
    # 创建安装目录
    local install_dir="/opt/hysteria"
    print_info "创建安装目录: $install_dir"
    sudo mkdir -p "$install_dir"
    
    # 复制二进制文件
    print_info "安装二进制文件..."
    sudo cp "$binary_name" "$install_dir/hysteria"
    sudo chmod +x "$install_dir/hysteria"
    
    # 复制配置文件
    print_info "安装配置文件..."
    if [[ ! -f "$install_dir/config.yaml" ]]; then
        sudo cp config-sspanel-example.yaml "$install_dir/config.yaml"
        print_warning "请编辑 $install_dir/config.yaml 配置文件"
    else
        print_info "配置文件已存在，跳过复制"
    fi
    
    # 复制文档
    sudo cp README-SSPANEL.md "$install_dir/"
    sudo cp BUILD-GUIDE.md "$install_dir/"
    
    # 创建systemd服务
    print_info "创建systemd服务..."
    sudo tee /etc/systemd/system/hysteria.service > /dev/null <<EOF
[Unit]
Description=Hysteria2 SSPanel Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$install_dir
ExecStart=$install_dir/hysteria server -c $install_dir/config.yaml
Restart=always
RestartSec=5
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
    
    # 重载systemd
    sudo systemctl daemon-reload
    sudo systemctl enable hysteria
    
    print_success "安装完成！"
    print_info "安装目录: $install_dir"
    print_info "配置文件: $install_dir/config.yaml"
    print_info "服务名称: hysteria"
    
    echo
    print_warning "下一步操作:"
    echo "1. 编辑配置文件: sudo nano $install_dir/config.yaml"
    echo "2. 启动服务: sudo systemctl start hysteria"
    echo "3. 查看状态: sudo systemctl status hysteria"
    echo "4. 查看日志: sudo journalctl -u hysteria -f"
}

# 卸载函数
uninstall_hysteria() {
    print_info "开始卸载 Hysteria2..."
    
    # 停止服务
    sudo systemctl stop hysteria 2>/dev/null || true
    sudo systemctl disable hysteria 2>/dev/null || true
    
    # 删除服务文件
    sudo rm -f /etc/systemd/system/hysteria.service
    sudo systemctl daemon-reload
    
    # 删除安装目录
    sudo rm -rf /opt/hysteria
    
    print_success "卸载完成！"
}

# 显示帮助
show_help() {
    echo "Hysteria2 SSPanel版本安装脚本"
    echo
    echo "用法: $0 [选项]"
    echo
    echo "选项:"
    echo "  install     安装 Hysteria2"
    echo "  uninstall   卸载 Hysteria2"
    echo "  help        显示此帮助信息"
    echo
    echo "支持的架构:"
    echo "  - Linux x64 (amd64)"
    echo "  - Linux ARM64 (aarch64)"
    echo "  - Linux ARM32 (armv7l/armv6l)"
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
