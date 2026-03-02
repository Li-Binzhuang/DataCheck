#!/bin/bash
# MyDataCheck Docker构建脚本
# 支持开发环境（ARM原生）和生产环境（x86跨架构）

set -e

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 显示使用说明
show_usage() {
    echo "=========================================="
    echo "MyDataCheck Docker 构建脚本"
    echo "=========================================="
    echo ""
    echo "用法: $0 [模式]"
    echo ""
    echo "模式:"
    echo "  dev     - 开发模式（ARM原生，高性能，用于本地测试）"
    echo "  prod    - 生产模式（x86架构，用于服务器部署）"
    echo "  both    - 同时构建两种架构"
    echo ""
    echo "示例:"
    echo "  $0 dev      # 构建ARM开发镜像"
    echo "  $0 prod     # 构建x86生产镜像"
    echo "  $0 both     # 构建两种镜像"
    echo ""
    exit 1
}

# 检查Docker环境
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}错误: Docker未安装${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Docker已安装${NC}"
}

# 检查Buildx（仅生产模式需要）
check_buildx() {
    if ! docker buildx version &> /dev/null; then
        echo -e "${RED}错误: Docker Buildx不可用${NC}"
        echo "请升级Docker到最新版本"
        exit 1
    fi
    echo -e "${GREEN}✓ Docker Buildx可用${NC}"
}

# 构建开发镜像（ARM原生）
build_dev() {
    echo ""
    echo "=========================================="
    echo -e "${BLUE}构建开发镜像（ARM原生）${NC}"
    echo "=========================================="
    echo ""
    
    check_docker
    
    echo -e "${YELLOW}目标架构: ARM64 (本机原生)${NC}"
    echo -e "${YELLOW}镜像标签: mydatacheck:dev-arm64${NC}"
    echo -e "${YELLOW}用途: 本地开发和测试（高性能）${NC}"
    echo ""
    
    echo -e "${YELLOW}开始构建...${NC}"
    docker-compose -f docker-compose.dev.yml build
    
    echo ""
    echo -e "${GREEN}✓ 开发镜像构建完成${NC}"
    
    # 显示镜像信息
    ARCH=$(docker image inspect mydatacheck:dev-arm64 --format '{{.Architecture}}' 2>/dev/null || echo "未知")
    echo -e "镜像架构: ${GREEN}${ARCH}${NC}"
    
    echo ""
    echo "启动开发环境:"
    echo -e "  ${BLUE}docker-compose -f docker-compose.dev.yml up -d${NC}"
    echo ""
}

# 构建生产镜像（x86跨架构）
build_prod() {
    echo ""
    echo "=========================================="
    echo -e "${BLUE}构建生产镜像（x86跨架构）${NC}"
    echo "=========================================="
    echo ""
    
    check_docker
    check_buildx
    
    echo -e "${YELLOW}目标架构: AMD64 (x86_64)${NC}"
    echo -e "${YELLOW}镜像标签: mydatacheck:prod-amd64${NC}"
    echo -e "${YELLOW}用途: 服务器生产部署${NC}"
    echo ""
    
    # 创建并使用buildx构建器
    echo -e "${YELLOW}设置Docker Buildx构建器...${NC}"
    if ! docker buildx inspect mybuilder &> /dev/null; then
        docker buildx create --name mybuilder --use
        echo -e "${GREEN}✓ 构建器创建成功${NC}"
    else
        docker buildx use mybuilder
        echo -e "${GREEN}✓ 使用现有构建器${NC}"
    fi
    
    # 启动构建器
    docker buildx inspect --bootstrap
    
    echo ""
    echo -e "${YELLOW}开始构建x86镜像...${NC}"
    echo -e "${RED}注意: 跨架构构建较慢，预计需要5-10分钟${NC}"
    echo ""
    
    # 使用buildx构建
    docker buildx build \
        --platform linux/amd64 \
        --tag mydatacheck:prod-amd64 \
        --load \
        .
    
    echo ""
    echo -e "${GREEN}✓ 生产镜像构建完成${NC}"
    
    # 显示镜像信息
    ARCH=$(docker image inspect mydatacheck:prod-amd64 --format '{{.Architecture}}' 2>/dev/null || echo "未知")
    echo -e "镜像架构: ${GREEN}${ARCH}${NC}"
    
    echo ""
    echo "后续操作:"
    echo -e "  1. 本地测试: ${BLUE}docker-compose up -d${NC}"
    echo -e "  2. 导出镜像: ${BLUE}docker save mydatacheck:prod-amd64 | gzip > mydatacheck-amd64.tar.gz${NC}"
    echo -e "  3. 上传到服务器并导入"
    echo ""
}

# 构建两种镜像
build_both() {
    build_dev
    echo ""
    echo "=========================================="
    echo ""
    build_prod
    
    echo ""
    echo "=========================================="
    echo -e "${GREEN}所有镜像构建完成！${NC}"
    echo "=========================================="
    echo ""
    echo "可用镜像:"
    echo -e "  • ${BLUE}mydatacheck:dev-arm64${NC}  - 开发环境（ARM原生）"
    echo -e "  • ${BLUE}mydatacheck:prod-amd64${NC} - 生产环境（x86）"
    echo ""
}

# 主逻辑
main() {
    if [ $# -eq 0 ]; then
        show_usage
    fi
    
    case "$1" in
        dev)
            build_dev
            ;;
        prod)
            build_prod
            ;;
        both)
            build_both
            ;;
        *)
            echo -e "${RED}错误: 未知模式 '$1'${NC}"
            echo ""
            show_usage
            ;;
    esac
}

main "$@"
