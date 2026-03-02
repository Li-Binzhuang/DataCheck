#!/bin/bash
# MyDataCheck 服务器部署脚本（不依赖docker-compose）
# 用于在x86服务器上导入镜像并启动容器

set -e

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置参数
CONTAINER_NAME="mydatacheck"
IMAGE_NAME="mydatacheck:prod-amd64"
IMAGE_FILE="mydatacheck-amd64.tar.gz"
HOST_PORT=5001
CONTAINER_PORT=5001

# 数据目录
DATA_DIR="$(pwd)"
INPUT_DIR="${DATA_DIR}/inputdata"
OUTPUT_DIR="${DATA_DIR}/outputdata"
LOGS_DIR="${DATA_DIR}/logs"

echo "=========================================="
echo "MyDataCheck 服务器部署脚本"
echo "=========================================="
echo ""

# 显示使用说明
show_usage() {
    echo "用法: $0 [命令] [选项]"
    echo ""
    echo "命令:"
    echo "  start       - 导入镜像并启动容器（默认）"
    echo "  stop        - 停止容器"
    echo "  restart     - 重启容器"
    echo "  status      - 查看容器状态"
    echo "  logs        - 查看容器日志"
    echo "  clean       - 停止并删除容器"
    echo "  help        - 显示帮助信息"
    echo ""
    echo "选项:"
    echo "  --image-file <文件>   指定镜像文件路径（默认: mydatacheck-amd64.tar.gz）"
    echo "  --port <端口>         指定主机端口（默认: 5001）"
    echo ""
    echo "示例:"
    echo "  $0 start                              # 使用默认配置启动"
    echo "  $0 start --image-file /path/to/image.tar.gz"
    echo "  $0 start --port 8080                  # 使用8080端口"
    echo "  $0 logs                               # 查看日志"
    echo "  $0 stop                               # 停止服务"
    echo ""
}

# 检查Docker
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}错误: Docker未安装${NC}"
        echo "请先安装Docker: https://docs.docker.com/engine/install/"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        echo -e "${RED}错误: Docker服务未运行${NC}"
        echo "请启动Docker服务: sudo systemctl start docker"
        exit 1
    fi
}

# 创建数据目录
create_directories() {
    echo -e "${YELLOW}创建数据目录...${NC}"
    
    mkdir -p "${INPUT_DIR}/api_comparison"
    mkdir -p "${INPUT_DIR}/data_comparison"
    mkdir -p "${INPUT_DIR}/online_comparison"
    mkdir -p "${OUTPUT_DIR}/api_comparison"
    mkdir -p "${OUTPUT_DIR}/data_comparison"
    mkdir -p "${OUTPUT_DIR}/online_comparison"
    mkdir -p "${OUTPUT_DIR}/performance_test"
    mkdir -p "${OUTPUT_DIR}/progress_test"
    mkdir -p "${LOGS_DIR}"
    
    echo -e "${GREEN}✓ 数据目录创建完成${NC}"
}

# 导入镜像
import_image() {
    if [ ! -f "${IMAGE_FILE}" ]; then
        echo -e "${RED}错误: 镜像文件不存在: ${IMAGE_FILE}${NC}"
        echo "请确保镜像文件在当前目录，或使用 --image-file 指定路径"
        exit 1
    fi
    
    echo -e "${YELLOW}导入Docker镜像...${NC}"
    echo "镜像文件: ${IMAGE_FILE}"
    
    if [[ "${IMAGE_FILE}" == *.gz ]]; then
        gunzip -c "${IMAGE_FILE}" | docker load
    else
        docker load < "${IMAGE_FILE}"
    fi
    
    echo -e "${GREEN}✓ 镜像导入完成${NC}"
    
    # 验证镜像
    if docker images | grep -q "mydatacheck"; then
        echo -e "${GREEN}✓ 镜像验证成功${NC}"
        docker images | grep mydatacheck
    else
        echo -e "${RED}错误: 镜像导入失败${NC}"
        exit 1
    fi
}

# 停止并删除旧容器
remove_old_container() {
    if docker ps -a | grep -q "${CONTAINER_NAME}"; then
        echo -e "${YELLOW}停止并删除旧容器...${NC}"
        docker stop "${CONTAINER_NAME}" 2>/dev/null || true
        docker rm "${CONTAINER_NAME}" 2>/dev/null || true
        echo -e "${GREEN}✓ 旧容器已清理${NC}"
    fi
}

# 启动容器
start_container() {
    echo -e "${YELLOW}启动容器...${NC}"
    echo "容器名称: ${CONTAINER_NAME}"
    echo "访问端口: http://localhost:${HOST_PORT}"
    echo ""
    
    docker run -d \
        --name "${CONTAINER_NAME}" \
        --restart unless-stopped \
        -p "${HOST_PORT}:${CONTAINER_PORT}" \
        -v "${INPUT_DIR}:/app/inputdata" \
        -v "${OUTPUT_DIR}:/app/outputdata" \
        -v "${LOGS_DIR}:/app/logs" \
        -e PYTHONUNBUFFERED=1 \
        -e SERVER_HOST=0.0.0.0 \
        -e SERVER_PORT=${CONTAINER_PORT} \
        -e CLEANUP_RETENTION_DAYS=3 \
        -e DISABLE_OPEN_FOLDER=1 \
        "${IMAGE_NAME}"
    
    echo -e "${GREEN}✓ 容器启动成功${NC}"
    
    # 等待容器启动
    echo ""
    echo -e "${YELLOW}等待服务启动...${NC}"
    sleep 3
    
    # 检查容器状态
    if docker ps | grep -q "${CONTAINER_NAME}"; then
        echo -e "${GREEN}✓ 服务运行正常${NC}"
        echo ""
        echo "=========================================="
        echo -e "${GREEN}部署完成！${NC}"
        echo "=========================================="
        echo ""
        echo "访问地址: http://localhost:${HOST_PORT}"
        echo "或: http://$(hostname -I | awk '{print $1}'):${HOST_PORT}"
        echo ""
        echo "常用命令:"
        echo "  查看日志: $0 logs"
        echo "  查看状态: $0 status"
        echo "  停止服务: $0 stop"
        echo "  重启服务: $0 restart"
        echo ""
    else
        echo -e "${RED}错误: 容器启动失败${NC}"
        echo "查看日志: docker logs ${CONTAINER_NAME}"
        exit 1
    fi
}

# 停止容器
stop_container() {
    echo -e "${YELLOW}停止容器...${NC}"
    
    if docker ps | grep -q "${CONTAINER_NAME}"; then
        docker stop "${CONTAINER_NAME}"
        echo -e "${GREEN}✓ 容器已停止${NC}"
    else
        echo -e "${YELLOW}容器未运行${NC}"
    fi
}

# 重启容器
restart_container() {
    echo -e "${YELLOW}重启容器...${NC}"
    
    if docker ps -a | grep -q "${CONTAINER_NAME}"; then
        docker restart "${CONTAINER_NAME}"
        echo -e "${GREEN}✓ 容器已重启${NC}"
        
        # 等待启动
        sleep 3
        show_status
    else
        echo -e "${RED}错误: 容器不存在${NC}"
        echo "请先运行: $0 start"
        exit 1
    fi
}

# 查看状态
show_status() {
    echo "=========================================="
    echo "容器状态"
    echo "=========================================="
    echo ""
    
    if docker ps -a | grep -q "${CONTAINER_NAME}"; then
        docker ps -a | grep "${CONTAINER_NAME}" || true
        echo ""
        
        if docker ps | grep -q "${CONTAINER_NAME}"; then
            echo -e "状态: ${GREEN}运行中${NC}"
            echo "访问地址: http://localhost:${HOST_PORT}"
            echo ""
            echo "资源使用:"
            docker stats --no-stream "${CONTAINER_NAME}"
        else
            echo -e "状态: ${RED}已停止${NC}"
            echo "启动容器: $0 start"
        fi
    else
        echo -e "状态: ${YELLOW}容器不存在${NC}"
        echo "请先运行: $0 start"
    fi
    echo ""
}

# 查看日志
show_logs() {
    if docker ps -a | grep -q "${CONTAINER_NAME}"; then
        echo "=========================================="
        echo "容器日志（按 Ctrl+C 退出）"
        echo "=========================================="
        echo ""
        docker logs -f --tail 100 "${CONTAINER_NAME}"
    else
        echo -e "${RED}错误: 容器不存在${NC}"
        exit 1
    fi
}

# 清理容器
clean_container() {
    echo -e "${YELLOW}清理容器...${NC}"
    
    if docker ps -a | grep -q "${CONTAINER_NAME}"; then
        docker stop "${CONTAINER_NAME}" 2>/dev/null || true
        docker rm "${CONTAINER_NAME}" 2>/dev/null || true
        echo -e "${GREEN}✓ 容器已删除${NC}"
    else
        echo -e "${YELLOW}容器不存在，无需清理${NC}"
    fi
    
    echo ""
    echo "注意: 数据目录未删除，如需删除请手动执行:"
    echo "  rm -rf inputdata outputdata logs"
}

# 完整部署流程
deploy() {
    echo -e "${BLUE}开始部署...${NC}"
    echo ""
    
    check_docker
    create_directories
    
    # 检查镜像是否已存在
    if docker images | grep -q "${IMAGE_NAME}"; then
        echo -e "${YELLOW}检测到已存在的镜像${NC}"
        read -p "是否重新导入镜像？(y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            import_image
        else
            echo -e "${GREEN}✓ 使用现有镜像${NC}"
        fi
    else
        import_image
    fi
    
    remove_old_container
    start_container
}

# 解析参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --image-file)
                IMAGE_FILE="$2"
                shift 2
                ;;
            --port)
                HOST_PORT="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done
}

# 主逻辑
main() {
    # 解析参数
    COMMAND="${1:-start}"
    shift || true
    parse_args "$@"
    
    case "$COMMAND" in
        start)
            deploy
            ;;
        stop)
            check_docker
            stop_container
            ;;
        restart)
            check_docker
            restart_container
            ;;
        status)
            check_docker
            show_status
            ;;
        logs)
            check_docker
            show_logs
            ;;
        clean)
            check_docker
            clean_container
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            echo -e "${RED}错误: 未知命令 '$COMMAND'${NC}"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

main "$@"
