#!/bin/bash
# MyDataCheck Docker部署脚本

set -e

echo "=========================================="
echo "MyDataCheck Docker 部署"
echo "=========================================="

# 进入项目根目录
cd "$(dirname "$0")/.."

# 检查Docker是否安装
if ! command -v docker &> /dev/null; then
    echo "❌ 错误: Docker未安装"
    echo "请先安装Docker: https://docs.docker.com/get-docker/"
    exit 1
fi

# 显示帮助
show_help() {
    echo "用法: $0 [命令]"
    echo ""
    echo "命令:"
    echo "  build    构建Docker镜像"
    echo "  start    启动容器"
    echo "  stop     停止容器"
    echo "  restart  重启容器"
    echo "  logs     查看日志"
    echo "  shell    进入容器Shell"
    echo "  clean    清理镜像和容器"
    echo ""
}

# 构建镜像
build() {
    echo "📦 构建Docker镜像（AMD64架构）..."
    
    # 检查buildx是否可用
    if ! docker buildx version &> /dev/null; then
        echo "❌ 错误: Docker Buildx不可用"
        echo "请升级Docker到最新版本"
        exit 1
    fi
    
    # 创建并使用buildx构建器
    echo "🔧 设置Docker Buildx构建器..."
    if ! docker buildx inspect mybuilder &> /dev/null; then
        docker buildx create --name mybuilder --use
        echo "✅ 构建器创建成功"
    else
        docker buildx use mybuilder
        echo "✅ 使用现有构建器"
    fi
    
    # 启动构建器
    docker buildx inspect --bootstrap
    
    echo "⚠️  注意: 跨架构构建较慢，预计需要5-10分钟"
    echo ""
    
    # 使用buildx构建AMD64镜像
    docker buildx build \
        --platform linux/amd64 \
        --tag mydatacheck:latest \
        --tag mydatacheck:prod-amd64 \
        --load \
        .
    
    echo "✅ 构建完成"
    
    # 验证架构
    ARCH=$(docker image inspect mydatacheck:latest --format '{{.Architecture}}' 2>/dev/null || echo "未知")
    echo "镜像架构: $ARCH"
    
    if [ "$ARCH" != "amd64" ]; then
        echo "⚠️  警告: 镜像架构不是amd64，可能无法在x86服务器上运行"
    fi
    
    # 导出镜像
    echo "📤 导出Docker镜像..."
    EXPORT_DIR="docker_exports"
    mkdir -p "$EXPORT_DIR"
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    EXPORT_FILE="$EXPORT_DIR/mydatacheck-amd64.tar.gz"
    
    docker save mydatacheck:latest | gzip > "$EXPORT_FILE"
    
    FILE_SIZE=$(du -h "$EXPORT_FILE" | cut -f1)
    echo "✅ 镜像已导出: $EXPORT_FILE (大小: $FILE_SIZE)"
}

# 启动容器
start() {
    echo "🚀 启动容器..."
    if command -v docker-compose &> /dev/null; then
        docker-compose up -d
    else
        docker compose up -d
    fi
    echo "✅ 启动完成"
    echo "访问地址: http://localhost:5001"
}

# 停止容器
stop() {
    echo "⏹️  停止容器..."
    if command -v docker-compose &> /dev/null; then
        docker-compose down
    else
        docker compose down
    fi
    echo "✅ 已停止"
}

# 重启容器
restart() {
    stop
    start
}

# 查看日志
logs() {
    if command -v docker-compose &> /dev/null; then
        docker-compose logs -f
    else
        docker compose logs -f
    fi
}

# 进入容器Shell
shell() {
    docker exec -it mydatacheck /bin/bash
}

# 清理
clean() {
    echo "🧹 清理Docker资源..."
    stop 2>/dev/null || true
    docker rmi mydatacheck:latest 2>/dev/null || true
    echo "✅ 清理完成"
}

# 主逻辑
case "${1:-}" in
    build)
        build
        ;;
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        restart
        ;;
    logs)
        logs
        ;;
    shell)
        shell
        ;;
    clean)
        clean
        ;;
    ""|help)
        show_help
        ;;
    *)
        echo "❌ 未知命令: $1"
        show_help
        exit 1
        ;;
esac
