#!/bin/bash
# PKL功能依赖安装脚本

set -e

echo "=========================================="
echo "PKL功能依赖安装脚本"
echo "=========================================="
echo ""

# 检查当前Python版本
CURRENT_PYTHON=$(python3 --version 2>&1 | awk '{print $2}')
echo "当前Python版本: $CURRENT_PYTHON"

# 检查是否是Python 3.15
if [[ "$CURRENT_PYTHON" == 3.15* ]]; then
    echo ""
    echo "⚠️  警告: 检测到 Python 3.15 (alpha版本)"
    echo "pandas 可能无法在此版本上安装"
    echo ""
    echo "建议解决方案:"
    echo "1. 安装 Python 3.12 (推荐)"
    echo "   brew install python@3.12"
    echo ""
    echo "2. 或安装 Python 3.11"
    echo "   brew install python@3.11"
    echo ""
    echo "3. 然后重新创建虚拟环境:"
    echo "   cd MyDataCheck"
    echo "   rm -rf .venv"
    echo "   python3.12 -m venv .venv"
    echo "   source .venv/bin/activate"
    echo "   pip install -r requirements.txt"
    echo ""
    read -p "是否仍要尝试在当前环境安装? (y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "已取消安装"
        exit 1
    fi
fi

# 进入项目目录
cd "$(dirname "$0")"

# 检查虚拟环境
if [ ! -d ".venv" ]; then
    echo "❌ 未找到虚拟环境 .venv"
    echo "请先创建虚拟环境: python3 -m venv .venv"
    exit 1
fi

# 激活虚拟环境
echo "激活虚拟环境..."
source .venv/bin/activate

# 检查pip
echo "检查pip..."
pip --version

# 升级pip
echo ""
echo "升级pip..."
pip install --upgrade pip

# 安装依赖
echo ""
echo "安装依赖包..."
echo "正在安装: pandas, numpy, Flask, requests"
pip install pandas>=2.0.0 numpy>=1.24.0 Flask>=2.0.0 requests>=2.25.0

# 验证安装
echo ""
echo "验证安装..."
python3 -c "import pandas; print('✅ pandas版本:', pandas.__version__)" || {
    echo "❌ pandas安装失败"
    exit 1
}

python3 -c "import numpy; print('✅ numpy版本:', numpy.__version__)" || {
    echo "❌ numpy安装失败"
    exit 1
}

echo ""
echo "=========================================="
echo "✅ 安装完成!"
echo "=========================================="
echo ""
echo "现在可以启动Web服务:"
echo "  source .venv/bin/activate"
echo "  python web_app.py"
echo ""
