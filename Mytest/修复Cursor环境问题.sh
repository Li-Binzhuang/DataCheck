#!/bin/bash
# 修复 Cursor 使用的虚拟环境问题

set -e

echo "=========================================="
echo "修复 Cursor 环境问题"
echo "=========================================="
echo ""

# 方案1: 在 OverseasPython/.venv 安装依赖
OVERSEAS_VENV="/Users/zhanglifeng12703/Documents/OverseasPython/.venv"
MYTEST_VENV="/Users/zhanglifeng12703/Documents/OverseasPython/Mytest/.venv"

echo "检查虚拟环境..."
echo ""

if [ -d "$OVERSEAS_VENV" ]; then
    echo "✅ 找到 OverseasPython/.venv"
    echo "   这是 Cursor 正在使用的环境"
    echo ""
    echo "正在安装 pandas 和 numpy..."
    
    "$OVERSEAS_VENV/bin/python" -m pip install --upgrade pip --quiet 2>/dev/null || \
    "$OVERSEAS_VENV/bin/python" -m pip install --trusted-host pypi.org --trusted-host pypi.python.org --trusted-host files.pythonhosted.org --upgrade pip --quiet
    
    if "$OVERSEAS_VENV/bin/python" -m pip install pandas numpy --quiet 2>/dev/null; then
        echo "✅ 安装成功（标准方式）"
    elif "$OVERSEAS_VENV/bin/python" -m pip install --trusted-host pypi.org --trusted-host pypi.python.org --trusted-host files.pythonhosted.org pandas numpy --quiet 2>/dev/null; then
        echo "✅ 安装成功（使用 trusted-host）"
    else
        echo "❌ 自动安装失败，请手动运行："
        echo "   $OVERSEAS_VENV/bin/python -m pip install pandas numpy"
        exit 1
    fi
    
    # 验证
    echo ""
    echo "验证安装..."
    if "$OVERSEAS_VENV/bin/python" -c "import pandas; print('✅ pandas', pandas.__version__)" 2>/dev/null && \
       "$OVERSEAS_VENV/bin/python" -c "import numpy; print('✅ numpy', numpy.__version__)" 2>/dev/null; then
        echo ""
        echo "=========================================="
        echo "✅ 修复完成！"
        echo "=========================================="
        echo ""
        echo "现在可以重启 Cursor 并运行 notebook 了"
        echo "Cursor 使用的 Python: $OVERSEAS_VENV/bin/python"
    else
        echo "❌ 验证失败"
        exit 1
    fi
else
    echo "❌ OverseasPython/.venv 不存在"
    echo ""
    echo "创建虚拟环境..."
    cd /Users/zhanglifeng12703/Documents/OverseasPython
    /opt/homebrew/bin/python3.12 -m venv .venv
    
    echo "安装依赖..."
    .venv/bin/python -m pip install --upgrade pip --quiet
    .venv/bin/python -m pip install pandas numpy --quiet || \
    .venv/bin/python -m pip install --trusted-host pypi.org --trusted-host pypi.python.org --trusted-host files.pythonhosted.org pandas numpy --quiet
    
    echo "✅ 创建并安装完成"
fi
