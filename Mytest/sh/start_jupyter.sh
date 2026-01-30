#!/bin/bash
# 启动 Jupyter Notebook（使用正确的 Python 3.12 环境）

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "启动 Jupyter Notebook"
echo "=========================================="
echo ""

# 检查虚拟环境
if [ ! -d ".venv" ]; then
    echo "❌ 虚拟环境不存在"
    echo "请先运行: ./switch_python.sh"
    exit 1
fi

# 激活虚拟环境
source .venv/bin/activate

# 检查 Python 版本
PYTHON_VERSION=$(python --version 2>&1)
echo "Python 版本: $PYTHON_VERSION"

if [[ ! "$PYTHON_VERSION" == *"3.12"* ]] && [[ ! "$PYTHON_VERSION" == *"3.11"* ]]; then
    echo "⚠️  警告: Python 版本不是 3.12 或 3.11"
    echo "建议运行: ./switch_python.sh 切换到 Python 3.12"
fi

# 检查并安装 jupyter
if ! python -c "import jupyter" 2>/dev/null; then
    echo ""
    echo "安装 Jupyter Notebook..."
    pip install jupyter notebook --quiet
fi

# 检查并安装 ipykernel
if ! python -c "import ipykernel" 2>/dev/null; then
    echo "安装 ipykernel..."
    pip install ipykernel --quiet
fi

echo ""
echo "=========================================="
echo "启动 Jupyter Notebook..."
echo "=========================================="
echo ""
echo "浏览器将自动打开，如果没有，请访问: http://localhost:8888"
echo ""
echo "按 Ctrl+C 停止服务器"
echo ""

# 启动 Jupyter Notebook
cd ipynb
jupyter notebook
