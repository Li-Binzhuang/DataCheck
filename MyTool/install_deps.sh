#!/bin/bash
# 安装依赖包

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "安装依赖包"
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
pip install --upgrade pip --quiet

# 安装依赖
echo "安装 pandas 和 numpy..."
pip install pandas numpy --quiet

# 验证
echo ""
echo "验证安装..."
python -c "import pandas; print('✅ pandas', pandas.__version__)" || exit 1
python -c "import numpy; print('✅ numpy', numpy.__version__)" || exit 1

echo ""
echo "=========================================="
echo "✅ 安装完成！"
echo "=========================================="
echo ""
echo "现在可以重启 Cursor 并运行 notebook 了"
