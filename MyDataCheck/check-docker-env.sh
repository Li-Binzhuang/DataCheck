#!/bin/bash
# Docker环境检查脚本

set -e

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "=========================================="
echo "Docker 环境检查"
echo "=========================================="
echo ""

# 检查项计数
PASS=0
FAIL=0
WARN=0

# 检查Docker
echo -n "检查 Docker... "
if command -v docker &> /dev/null; then
    VERSION=$(docker --version)
    echo -e "${GREEN}✓${NC} $VERSION"
    ((PASS++))
else
    echo -e "${RED}✗ 未安装${NC}"
    ((FAIL++))
fi

# 检查Docker Buildx
echo -n "检查 Docker Buildx... "
if docker buildx version &> /dev/null; then
    VERSION=$(docker buildx version)
    echo -e "${GREEN}✓${NC} $VERSION"
    ((PASS++))
else
    echo -e "${RED}✗ 不可用${NC}"
    ((FAIL++))
fi

# 检查Docker Compose
echo -n "检查 Docker Compose... "
if docker compose version &> /dev/null; then
    VERSION=$(docker compose version)
    echo -e "${GREEN}✓${NC} $VERSION"
    ((PASS++))
elif docker-compose --version &> /dev/null; then
    VERSION=$(docker-compose --version)
    echo -e "${YELLOW}⚠${NC} $VERSION (建议使用 docker compose)"
    ((WARN++))
else
    echo -e "${RED}✗ 未安装${NC}"
    ((FAIL++))
fi

# 检查Docker是否运行
echo -n "检查 Docker 服务... "
if docker info &> /dev/null; then
    echo -e "${GREEN}✓ 运行中${NC}"
    ((PASS++))
else
    echo -e "${RED}✗ 未运行${NC}"
    echo "  请启动 Docker Desktop 或 Docker 服务"
    ((FAIL++))
fi

# 检查当前架构
echo -n "检查系统架构... "
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ] || [ "$ARCH" = "aarch64" ]; then
    echo -e "${GREEN}✓ ARM64${NC} (Apple Silicon)"
    ((PASS++))
elif [ "$ARCH" = "x86_64" ]; then
    echo -e "${GREEN}✓ x86_64${NC}"
    ((PASS++))
else
    echo -e "${YELLOW}⚠ $ARCH${NC}"
    ((WARN++))
fi

# 检查Buildx构建器
echo -n "检查 Buildx 构建器... "
if docker buildx ls &> /dev/null; then
    if docker buildx inspect mybuilder &> /dev/null 2>&1; then
        echo -e "${GREEN}✓ mybuilder 已存在${NC}"
    else
        echo -e "${YELLOW}⚠ mybuilder 不存在（首次构建时会自动创建）${NC}"
        ((WARN++))
    fi
    ((PASS++))
else
    echo -e "${RED}✗ 无法检查${NC}"
    ((FAIL++))
fi

# 检查端口占用
echo -n "检查端口 5001... "
if lsof -i :5001 &> /dev/null; then
    echo -e "${YELLOW}⚠ 已被占用${NC}"
    echo "  占用进程:"
    lsof -i :5001 | tail -n +2 | awk '{print "  - PID: "$2", 进程: "$1}'
    ((WARN++))
else
    echo -e "${GREEN}✓ 可用${NC}"
    ((PASS++))
fi

# 检查必要文件
echo ""
echo "检查项目文件:"
FILES=(
    "Dockerfile"
    "docker-compose.yml"
    "docker-compose.dev.yml"
    "build-docker.sh"
    "requirements.txt"
)

for file in "${FILES[@]}"; do
    echo -n "  $file... "
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓${NC}"
        ((PASS++))
    else
        echo -e "${RED}✗ 不存在${NC}"
        ((FAIL++))
    fi
done

# 检查构建脚本权限
echo -n "  build-docker.sh 可执行权限... "
if [ -x "build-docker.sh" ]; then
    echo -e "${GREEN}✓${NC}"
    ((PASS++))
else
    echo -e "${YELLOW}⚠ 无执行权限${NC}"
    echo "  运行: chmod +x build-docker.sh"
    ((WARN++))
fi

# 检查现有镜像
echo ""
echo "检查现有镜像:"
if docker images | grep -q mydatacheck; then
    docker images | grep mydatacheck | while read line; do
        IMAGE=$(echo $line | awk '{print $1":"$2}')
        ARCH=$(docker image inspect $IMAGE --format '{{.Architecture}}' 2>/dev/null || echo "未知")
        echo -e "  ${BLUE}$IMAGE${NC} (架构: $ARCH)"
    done
else
    echo "  无现有镜像（首次使用需要构建）"
fi

# 检查运行中的容器
echo ""
echo "检查运行中的容器:"
if docker ps | grep -q mydatacheck; then
    docker ps | grep mydatacheck | while read line; do
        NAME=$(echo $line | awk '{print $NF}')
        STATUS=$(echo $line | awk '{for(i=5;i<=NF-1;i++) printf $i" "; print ""}')
        echo -e "  ${GREEN}$NAME${NC} - $STATUS"
    done
else
    echo "  无运行中的容器"
fi

# 总结
echo ""
echo "=========================================="
echo "检查结果总结"
echo "=========================================="
echo -e "${GREEN}通过: $PASS${NC}"
if [ $WARN -gt 0 ]; then
    echo -e "${YELLOW}警告: $WARN${NC}"
fi
if [ $FAIL -gt 0 ]; then
    echo -e "${RED}失败: $FAIL${NC}"
fi
echo ""

# 给出建议
if [ $FAIL -gt 0 ]; then
    echo -e "${RED}环境检查未通过，请先解决上述问题${NC}"
    echo ""
    echo "常见解决方案:"
    echo "  1. 安装 Docker Desktop: https://www.docker.com/products/docker-desktop"
    echo "  2. 启动 Docker 服务"
    echo "  3. 确保 Docker 版本 >= 19.03"
    exit 1
elif [ $WARN -gt 0 ]; then
    echo -e "${YELLOW}环境基本正常，但有一些警告${NC}"
    echo ""
    echo "建议操作:"
    echo "  1. 如果端口被占用，请停止占用进程或修改配置"
    echo "  2. 如果构建脚本无执行权限，运行: chmod +x build-docker.sh"
    echo ""
    echo "可以继续使用，但建议处理警告项"
else
    echo -e "${GREEN}环境检查全部通过！${NC}"
    echo ""
    echo "下一步:"
    echo "  1. 构建开发镜像: ./build-docker.sh dev"
    echo "  2. 启动开发环境: docker-compose -f docker-compose.dev.yml up -d"
    echo "  3. 访问应用: http://localhost:5001"
    echo ""
    echo "查看文档:"
    echo "  - 快速开始: cat DOCKER_QUICK_START.md"
    echo "  - 命令速查: cat DOCKER_CHEATSHEET.md"
fi

echo ""
