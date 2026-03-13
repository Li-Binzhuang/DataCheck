#!/bin/bash
# 安装 pyarrow 以加速 CSV 读写

echo "安装 pyarrow..."
echo "================================"

# 检测 Python 命令
if command -v python3 &> /dev/null; then
    PYTHON_CMD="python3"
elif command -v python &> /dev/null; then
    PYTHON_CMD="python"
else
    echo "❌ 错误: 未找到 Python"
    exit 1
fi

echo "使用 Python: $PYTHON_CMD"
echo ""

# 安装 pyarrow
$PYTHON_CMD -m pip install pyarrow

echo ""
echo "================================"
echo "✅ 安装完成！"
echo ""
echo "pyarrow 可以将 CSV 读写速度提升 3-10 倍"
echo "现在可以运行: python merge_csv_fast_fixed.py"
