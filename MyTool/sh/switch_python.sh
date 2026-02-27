#!/bin/bash
# Python 版本切换脚本

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "Python 版本切换工具"
echo "=========================================="
echo ""

# 查找系统中可用的 Python 版本
echo "正在查找可用的 Python 版本..."
echo ""

PYTHON_VERSIONS=()

# 检查常见的 Python 版本路径
if command -v python3.12 &> /dev/null; then
    PYTHON_VERSIONS+=("3.12:$(which python3.12)")
    echo "✅ 找到 Python 3.12: $(which python3.12)"
fi

if command -v python3.11 &> /dev/null; then
    PYTHON_VERSIONS+=("3.11:$(which python3.11)")
    echo "✅ 找到 Python 3.11: $(which python3.11)"
fi

if command -v python3.10 &> /dev/null; then
    PYTHON_VERSIONS+=("3.10:$(which python3.10)")
    echo "✅ 找到 Python 3.10: $(which python3.10)"
fi

if command -v python3.9 &> /dev/null; then
    PYTHON_VERSIONS+=("3.9:$(which python3.9)")
    echo "✅ 找到 Python 3.9: $(which python3.9)"
fi

# 检查 Homebrew 安装的 Python
if [ -d "/opt/homebrew/opt" ]; then
    for py_dir in /opt/homebrew/opt/python@*/bin/python*; do
        if [ -f "$py_dir" ] && [[ "$py_dir" =~ python@([0-9]+\.[0-9]+) ]]; then
            version="${BASH_REMATCH[1]}"
            if [[ ! " ${PYTHON_VERSIONS[@]} " =~ " ${version}:" ]]; then
                PYTHON_VERSIONS+=("${version}:${py_dir}")
                echo "✅ 找到 Python ${version}: ${py_dir}"
            fi
        fi
    done
fi

# 检查 /usr/local/bin 中的 Python
for py in /usr/local/bin/python3.*; do
    if [ -f "$py" ] && [[ "$py" =~ python3\.([0-9]+\.[0-9]+) ]]; then
        version="${BASH_REMATCH[1]}"
        if [[ ! " ${PYTHON_VERSIONS[@]} " =~ " ${version}:" ]]; then
            PYTHON_VERSIONS+=("${version}:${py}")
            echo "✅ 找到 Python ${version}: ${py}"
        fi
    fi
done

echo ""
echo "=========================================="

if [ ${#PYTHON_VERSIONS[@]} -eq 0 ]; then
    echo "❌ 未找到可用的 Python 版本"
    echo ""
    echo "请先安装 Python 3.12:"
    echo "  brew install python@3.12"
    exit 1
fi

# 显示当前 Python 版本
if [ -d ".venv" ] && [ -f ".venv/bin/python" ]; then
    CURRENT_VERSION=$(.venv/bin/python --version 2>&1 | awk '{print $2}')
    echo "当前虚拟环境 Python 版本: $CURRENT_VERSION"
    echo ""
fi

# 让用户选择 Python 版本
echo "请选择要使用的 Python 版本:"
echo ""

for i in "${!PYTHON_VERSIONS[@]}"; do
    version_path="${PYTHON_VERSIONS[$i]}"
    version="${version_path%%:*}"
    path="${version_path#*:}"
    echo "  $((i+1)). Python $version ($path)"
done

echo ""
read -p "请输入选项 (1-${#PYTHON_VERSIONS[@]}): " choice

if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#PYTHON_VERSIONS[@]} ]; then
    echo "❌ 无效的选项"
    exit 1
fi

SELECTED="${PYTHON_VERSIONS[$((choice-1))]}"
SELECTED_VERSION="${SELECTED%%:*}"
SELECTED_PATH="${SELECTED#*:}"

echo ""
echo "=========================================="
echo "切换到 Python $SELECTED_VERSION"
echo "=========================================="
echo "Python 路径: $SELECTED_PATH"
echo ""

# 验证 Python 版本
VERIFIED_VERSION=$($SELECTED_PATH --version 2>&1 | awk '{print $2}')
echo "验证版本: $VERIFIED_VERSION"
echo ""

# 备份旧的虚拟环境
if [ -d ".venv" ]; then
    BACKUP_NAME=".venv.backup.$(date +%Y%m%d_%H%M%S)"
    echo "备份旧虚拟环境到: $BACKUP_NAME"
    mv .venv "$BACKUP_NAME"
fi

# 创建新的虚拟环境
echo "使用 Python $SELECTED_VERSION 创建虚拟环境..."
$SELECTED_PATH -m venv .venv

if [ ! -d ".venv" ]; then
    echo "❌ 虚拟环境创建失败"
    exit 1
fi

echo "✅ 虚拟环境创建成功"
echo ""

# 激活虚拟环境
source .venv/bin/activate

# 验证 Python 版本
ACTUAL_VERSION=$(python --version 2>&1)
echo "当前 Python 版本: $ACTUAL_VERSION"

if [[ ! "$ACTUAL_VERSION" == *"$SELECTED_VERSION"* ]]; then
    echo "⚠️  警告: Python 版本可能不匹配"
fi

# 升级 pip
echo ""
echo "升级 pip..."
python -m pip install --upgrade pip --quiet

# 安装依赖
echo ""
echo "安装依赖: pandas, numpy..."
pip install pandas numpy --quiet

# 验证安装
echo ""
echo "验证安装..."
python -c "import pandas; print('✅ pandas', pandas.__version__)" || {
    echo "❌ pandas 安装失败"
    exit 1
}

python -c "import numpy; print('✅ numpy', numpy.__version__)" || {
    echo "❌ numpy 安装失败"
    exit 1
}

echo ""
echo "=========================================="
echo "✅ 切换完成！"
echo "=========================================="
echo ""
echo "当前 Python 版本: $ACTUAL_VERSION"
echo "虚拟环境路径: $SCRIPT_DIR/.venv"
echo ""
echo "使用方法:"
echo "  source .venv/bin/activate"
echo ""
echo "或者在 Cursor 中切换 Jupyter 内核到此 Python 环境"
