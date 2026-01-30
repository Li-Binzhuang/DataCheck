#!/bin/bash
# 自动切换到 Python 3.12（非交互式）

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "自动切换到 Python 3.12"
echo "=========================================="
echo ""

# 检查 Python 3.12
if ! command -v python3.12 &> /dev/null; then
    echo "❌ 未找到 Python 3.12"
    echo "请先安装: brew install python@3.12"
    exit 1
fi

PYTHON312=$(which python3.12)
echo "✅ 找到 Python 3.12: $PYTHON312"

# 备份旧环境
if [ -d ".venv" ]; then
    BACKUP_NAME=".venv.backup.$(date +%Y%m%d_%H%M%S)"
    echo "备份旧环境到: $BACKUP_NAME"
    mv .venv "$BACKUP_NAME"
fi

# 创建新环境
echo "创建 Python 3.12 虚拟环境..."
$PYTHON312 -m venv .venv

# 激活并安装依赖
source .venv/bin/activate
echo "安装依赖..."
pip install --upgrade pip --quiet
pip install pandas numpy --quiet

# 验证
python -c "import pandas; print('✅ pandas', pandas.__version__)" || exit 1
python -c "import numpy; print('✅ numpy', numpy.__version__)" || exit 1

echo ""
echo "=========================================="
echo "✅ 切换完成！"
echo "=========================================="
echo "Python 版本: $(python --version)"
echo ""
echo "现在可以在 Cursor 中重新运行 notebook 了"
