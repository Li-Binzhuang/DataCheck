#!/bin/bash
# Mytest 项目 Python 3.12 环境设置脚本

set -e

echo "=========================================="
echo "Mytest 项目 Python 3.12 环境设置"
echo "=========================================="
echo ""

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 检查是否已安装 Python 3.12
echo "检查 Python 3.12 是否已安装..."
if command -v python3.12 &> /dev/null; then
    PYTHON312_VERSION=$(python3.12 --version 2>&1)
    echo "✅ 找到 Python 3.12: $PYTHON312_VERSION"
else
    echo "❌ 未找到 Python 3.12"
    echo ""
    echo "正在安装 Python 3.12..."
    
    # 检查是否有 Homebrew
    if command -v brew &> /dev/null; then
        echo "使用 Homebrew 安装 Python 3.12..."
        brew install python@3.12
        
        # 检查安装是否成功
        if command -v python3.12 &> /dev/null; then
            echo "✅ Python 3.12 安装成功"
        else
            echo "❌ Python 3.12 安装失败，请手动安装"
            echo ""
            echo "手动安装方法:"
            echo "1. 访问 https://www.python.org/downloads/"
            echo "2. 下载 Python 3.12.x 安装包"
            echo "3. 运行安装包进行安装"
            exit 1
        fi
    else
        echo "❌ 未找到 Homebrew"
        echo ""
        echo "请选择以下方式之一安装 Python 3.12:"
        echo ""
        echo "方法1: 安装 Homebrew 后使用"
        echo "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        echo "  brew install python@3.12"
        echo ""
        echo "方法2: 从官网下载安装"
        echo "  访问 https://www.python.org/downloads/"
        echo "  下载并安装 Python 3.12.x"
        echo ""
        exit 1
    fi
fi

echo ""
echo "=========================================="
echo "设置虚拟环境"
echo "=========================================="
echo ""

# 备份旧的虚拟环境（如果存在）
if [ -d ".venv" ]; then
    echo "发现旧的虚拟环境，正在备份..."
    BACKUP_NAME=".venv.backup.$(date +%Y%m%d_%H%M%S)"
    mv .venv "$BACKUP_NAME"
    echo "✅ 已备份到: $BACKUP_NAME"
fi

# 创建新的虚拟环境
echo "使用 Python 3.12 创建新的虚拟环境..."
python3.12 -m venv .venv

# 验证虚拟环境
if [ -d ".venv" ]; then
    echo "✅ 虚拟环境创建成功"
else
    echo "❌ 虚拟环境创建失败"
    exit 1
fi

# 激活虚拟环境
echo ""
echo "激活虚拟环境..."
source .venv/bin/activate

# 验证 Python 版本
PYTHON_VERSION=$(python --version 2>&1)
echo "当前 Python 版本: $PYTHON_VERSION"

if [[ "$PYTHON_VERSION" == *"3.12"* ]]; then
    echo "✅ Python 版本正确"
else
    echo "⚠️  警告: Python 版本不是 3.12"
fi

# 升级 pip
echo ""
echo "升级 pip..."
python -m pip install --upgrade pip

# 安装依赖
echo ""
echo "安装依赖包..."
echo "正在安装: pandas, numpy"

pip install pandas numpy

# 验证安装
echo ""
echo "=========================================="
echo "验证安装"
echo "=========================================="
echo ""

python -c "import pandas; print('✅ pandas 版本:', pandas.__version__)" || {
    echo "❌ pandas 安装失败"
    exit 1
}

python -c "import numpy; print('✅ numpy 版本:', numpy.__version__)" || {
    echo "❌ numpy 安装失败"
    exit 1
}

echo ""
echo "=========================================="
echo "✅ 设置完成！"
echo "=========================================="
echo ""
echo "虚拟环境已创建并配置完成"
echo ""
echo "使用方法:"
echo "  1. 激活虚拟环境:"
echo "     cd $SCRIPT_DIR"
echo "     source .venv/bin/activate"
echo ""
echo "  2. 运行 Jupyter Notebook:"
echo "     jupyter notebook"
echo ""
echo "  3. 退出虚拟环境:"
echo "     deactivate"
echo ""
