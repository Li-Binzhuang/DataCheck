#!/bin/bash
# 安装 BOSS 板块衍生所需的依赖

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "安装 BOSS 板块衍生依赖"
echo "=========================================="
echo ""

# 检查虚拟环境
if [ -f "../.venv/bin/activate" ]; then
    source ../.venv/bin/activate
    echo "✅ 使用 ../.venv 虚拟环境"
elif [ -f ".venv/bin/activate" ]; then
    source .venv/bin/activate
    echo "✅ 使用 .venv 虚拟环境"
else
    echo "⚠️  未找到虚拟环境，使用系统 Python"
fi

echo "Python 版本: $(python --version)"
echo ""

# 安装依赖
echo "安装 openpyxl（Excel 文件读写）..."
pip install openpyxl --quiet 2>/dev/null || \
pip install --trusted-host pypi.org --trusted-host pypi.python.org --trusted-host files.pythonhosted.org openpyxl --quiet

echo "安装 scipy（可选，用于相关性计算）..."
pip install scipy --quiet 2>/dev/null || \
pip install --trusted-host pypi.org --trusted-host pypi.python.org --trusted-host files.pythonhosted.org scipy --quiet || \
echo "⚠️  scipy 安装失败（可选，代码会自动降级）"

# 验证
echo ""
echo "验证安装..."
python -c "import openpyxl; print('✅ openpyxl', openpyxl.__version__)" 2>/dev/null || echo "❌ openpyxl 未安装"
python -c "import scipy; print('✅ scipy', scipy.__version__)" 2>/dev/null || echo "⚠️  scipy 未安装（可选）"

echo ""
echo "=========================================="
echo "✅ 安装完成！"
echo "=========================================="
