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
    echo "📦 构建Docker镜像..."
    docker build -t mydatacheck:latest .
    echo "✅ 构建完成"
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
