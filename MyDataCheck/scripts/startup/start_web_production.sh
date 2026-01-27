#!/bin/bash
# 生产环境启动脚本（使用Gunicorn）
# 适用于：团队共享、正式部署、高并发场景

echo "=========================================="
echo "生产环境 - Web服务启动"
echo "=========================================="
echo ""

# 进入脚本所在目录
cd "$(dirname "$0")"

# 检查虚拟环境
if [ ! -d ".venv" ]; then
    echo "❌ 错误: 未找到虚拟环境 .venv"
    exit 1
fi

# 激活虚拟环境
echo "激活虚拟环境..."
source .venv/bin/activate

# 检查Gunicorn是否安装
if ! python -c "import gunicorn" 2>/dev/null; then
    echo "⚠️  Gunicorn未安装，正在安装..."
    pip install gunicorn
    if [ $? -ne 0 ]; then
        echo "❌ 错误: Gunicorn安装失败"
        exit 1
    fi
fi

# 创建日志目录
mkdir -p logs

# 获取CPU核心数
if command -v nproc &> /dev/null; then
    CPU_CORES=$(nproc)
elif command -v sysctl &> /dev/null; then
    CPU_CORES=$(sysctl -n hw.ncpu)
else
    CPU_CORES=2
fi

# 计算工作进程数: (CPU核心数 × 2) + 1
WORKERS=$((CPU_CORES * 2 + 1))

echo "系统信息:"
echo "  CPU核心数: $CPU_CORES"
echo "  工作进程数: $WORKERS"
echo ""

# 启动Gunicorn
echo "=========================================="
echo "Gunicorn服务器启动中..."
echo "=========================================="
echo "访问地址: http://127.0.0.1:5001"
echo "工作进程: $WORKERS"
echo "访问日志: logs/access.log"
echo "错误日志: logs/error.log"
echo "按 Ctrl+C 停止服务器"
echo "=========================================="
echo ""

gunicorn -w $WORKERS \
         -b 127.0.0.1:5001 \
         --access-logfile logs/access.log \
         --error-logfile logs/error.log \
         --log-level info \
         --timeout 300 \
         --keep-alive 5 \
         --max-requests 1000 \
         --max-requests-jitter 50 \
         web_app:app
