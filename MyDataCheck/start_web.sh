#!/bin/bash
# Web界面启动脚本

echo "=========================================="
echo "场景1：接口数据对比 - Web界面"
echo "=========================================="
echo ""

# 进入脚本所在目录
cd "$(dirname "$0")"

# 检查虚拟环境是否存在
if [ ! -d ".venv" ]; then
    echo "❌ 错误: 未找到虚拟环境 .venv"
    echo "请先创建虚拟环境: python3.12 -m venv .venv"
    echo "然后安装依赖: source .venv/bin/activate && pip install -r requirements.txt"
    exit 1
fi

# 激活虚拟环境
echo "激活虚拟环境..."
source .venv/bin/activate

# 检查Python版本
PYTHON_VERSION=$(python --version 2>&1)
echo "当前Python版本: $PYTHON_VERSION"
echo ""

# 检查是否安装了Flask和pandas
if ! python -c "import flask" 2>/dev/null; then
    echo "⚠️  警告: Flask未安装，正在安装..."
    pip install -r requirements.txt
    if [ $? -ne 0 ]; then
        echo "❌ 错误: 依赖安装失败"
        exit 1
    fi
fi

# 检查pandas
if ! python -c "import pandas" 2>/dev/null; then
    echo "⚠️  警告: pandas未安装，正在安装..."
    pip install pandas numpy
    if [ $? -ne 0 ]; then
        echo "❌ 错误: pandas安装失败"
        echo "提示: 如果使用的是Python 3.15，请切换到Python 3.12"
        exit 1
    fi
fi

# 检查psutil（内存管理依赖）
if ! python -c "import psutil" 2>/dev/null; then
    echo "⚠️  警告: psutil未安装，正在安装..."
    pip install psutil
    if [ $? -ne 0 ]; then
        echo "❌ 错误: psutil安装失败"
        exit 1
    fi
fi

# 验证pandas安装
echo "验证依赖..."
python -c "import pandas; print('✅ pandas版本:', pandas.__version__)" || {
    echo "❌ pandas验证失败"
    exit 1
}

# 验证psutil安装
python -c "import psutil; print('✅ psutil版本:', psutil.__version__)" || {
    echo "❌ psutil验证失败"
    exit 1
}

# 启动Web服务
echo ""
echo "=========================================="
echo "服务器启动中..."
echo "访问地址: http://127.0.0.1:5001"
echo "按 Ctrl+C 停止服务器"
echo "=========================================="
echo ""
python web_app.py
