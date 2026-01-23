#!/bin/bash
# 在 Mytest/.venv 中安装依赖

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "在 Mytest/.venv 中安装依赖"
echo "=========================================="
echo ""

# 检查并创建虚拟环境
if [ ! -d ".venv" ]; then
    echo "创建 Python 3.12 虚拟环境..."
    /opt/homebrew/bin/python3.12 -m venv .venv
fi

# 激活虚拟环境
source .venv/bin/activate

echo "Python 版本: $(python --version)"
echo "Python 路径: $(which python)"
echo ""

# 升级 pip
echo "升级 pip..."
python -m pip install --upgrade pip --quiet 2>/dev/null || \
python -m pip install --trusted-host pypi.org --trusted-host pypi.python.org --trusted-host files.pythonhosted.org --upgrade pip --quiet

# 安装依赖
echo "安装 pandas 和 numpy..."
if python -m pip install pandas numpy --quiet 2>/dev/null; then
    echo "✅ 安装成功（标准方式）"
elif python -m pip install --trusted-host pypi.org --trusted-host pypi.python.org --trusted-host files.pythonhosted.org pandas numpy --quiet 2>/dev/null; then
    echo "✅ 安装成功（使用 trusted-host）"
else
    echo "❌ 自动安装失败，请手动运行："
    echo "   source .venv/bin/activate"
    echo "   pip install pandas numpy"
    exit 1
fi

# 验证
echo ""
echo "验证安装..."
if python -c "import pandas; print('✅ pandas', pandas.__version__)" 2>/dev/null && \
   python -c "import numpy; print('✅ numpy', numpy.__version__)" 2>/dev/null; then
    echo ""
    echo "=========================================="
    echo "✅ 安装完成！"
    echo "=========================================="
    echo ""
    echo "虚拟环境位置: $SCRIPT_DIR/.venv"
    echo "Python 路径: $SCRIPT_DIR/.venv/bin/python"
    echo ""
    echo "现在需要更新 notebook 配置以使用此环境"
else
    echo "❌ 验证失败"
    exit 1
fi
