#!/bin/bash
# 一键设置 Python 3.12 环境并安装依赖

set -e

echo "=========================================="
echo "Python 3.12 环境设置脚本"
echo "=========================================="
echo ""

# 进入项目目录
cd "$(dirname "$0")"
PROJECT_DIR=$(pwd)

echo "项目目录: $PROJECT_DIR"
echo ""

# 步骤1: 检查并安装 Python 3.12
echo "步骤1: 检查 Python 3.12..."
if command -v python3.12 &> /dev/null; then
    echo "✅ Python 3.12 已安装"
    python3.12 --version
else
    echo "❌ Python 3.12 未找到"
    echo ""
    echo "正在安装 Python 3.12..."
    echo "请等待 Homebrew 完成安装（可能需要几分钟）..."
    brew install python@3.12
    
    if command -v python3.12 &> /dev/null; then
        echo "✅ Python 3.12 安装成功"
        python3.12 --version
    else
        echo "❌ Python 3.12 安装失败"
        echo ""
        echo "请手动执行: brew install python@3.12"
        exit 1
    fi
fi

echo ""
echo "步骤2: 删除旧的虚拟环境..."
if [ -d ".venv" ]; then
    rm -rf .venv
    echo "✅ 已删除旧虚拟环境"
else
    echo "ℹ️  未找到旧虚拟环境"
fi

echo ""
echo "步骤3: 创建新的虚拟环境（使用 Python 3.12）..."
python3.12 -m venv .venv
if [ -d ".venv" ]; then
    echo "✅ 虚拟环境创建成功"
else
    echo "❌ 虚拟环境创建失败"
    exit 1
fi

echo ""
echo "步骤4: 激活虚拟环境..."
source .venv/bin/activate

echo ""
echo "步骤5: 验证 Python 版本..."
PYTHON_VERSION=$(python --version 2>&1)
echo "当前 Python 版本: $PYTHON_VERSION"

if [[ "$PYTHON_VERSION" != *"3.12"* ]]; then
    echo "⚠️  警告: 虚拟环境可能未正确使用 Python 3.12"
    echo "请检查虚拟环境配置"
fi

echo ""
echo "步骤6: 升级 pip..."
pip install --upgrade pip

echo ""
echo "步骤7: 安装项目依赖..."
pip install -r requirements.txt

echo ""
echo "步骤8: 验证安装..."
echo "检查 pandas..."
python -c "import pandas; print('✅ pandas 版本:', pandas.__version__)" || {
    echo "❌ pandas 安装失败"
    exit 1
}

echo "检查 numpy..."
python -c "import numpy; print('✅ numpy 版本:', numpy.__version__)" || {
    echo "❌ numpy 安装失败"
    exit 1
}

echo "检查 Flask..."
python -c "import flask; print('✅ Flask 版本:', flask.__version__)" || {
    echo "❌ Flask 安装失败"
    exit 1
}

echo ""
echo "=========================================="
echo "✅ 安装完成！"
echo "=========================================="
echo ""
echo "现在可以启动 Web 服务:"
echo "  cd $PROJECT_DIR"
echo "  source .venv/bin/activate"
echo "  python web_app.py"
echo ""
echo "或者使用启动脚本:"
echo "  ./start_web.sh"
echo ""
