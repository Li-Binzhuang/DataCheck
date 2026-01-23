#!/bin/bash
# 一键安装依赖包

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "一键安装依赖包"
echo "=========================================="
echo ""

# 检查虚拟环境
if [ ! -d ".venv" ]; then
    echo "❌ 虚拟环境不存在，正在创建..."
    /opt/homebrew/bin/python3.12 -m venv .venv
fi

# 激活虚拟环境
source .venv/bin/activate

echo "Python 版本: $(python --version)"
echo ""

# 升级 pip
echo "升级 pip..."
pip install --upgrade pip --quiet 2>/dev/null || pip install --trusted-host pypi.org --trusted-host pypi.python.org --trusted-host files.pythonhosted.org --upgrade pip --quiet

# 安装依赖（尝试多种方法）
echo "安装 pandas 和 numpy..."

if pip install pandas numpy --quiet 2>/dev/null; then
    echo "✅ 安装成功（标准方式）"
elif pip install --trusted-host pypi.org --trusted-host pypi.python.org --trusted-host files.pythonhosted.org pandas numpy --quiet 2>/dev/null; then
    echo "✅ 安装成功（使用 trusted-host）"
elif pip install --user pandas numpy --quiet 2>/dev/null; then
    echo "✅ 安装成功（使用 --user）"
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
    echo "现在可以重启 Cursor 并运行 notebook 了"
else
    echo "❌ 验证失败，请检查安装"
    exit 1
fi
