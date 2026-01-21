#!/bin/bash
# Web界面启动脚本

echo "=========================================="
echo "场景1：接口数据对比 - Web界面"
echo "=========================================="
echo ""

# 检查Python是否安装
if ! command -v python3 &> /dev/null; then
    echo "❌ 错误: 未找到Python3，请先安装Python3"
    exit 1
fi

# 检查是否安装了Flask
if ! python3 -c "import flask" 2>/dev/null; then
    echo "⚠️  警告: Flask未安装，正在安装..."
    pip3 install -r requirements.txt
    if [ $? -ne 0 ]; then
        echo "❌ 错误: Flask安装失败，请手动执行: pip3 install Flask"
        exit 1
    fi
fi

# 启动Web服务
echo "正在启动Web服务..."
echo "提示: 如果端口5001被占用，可以使用 --port 参数指定其他端口"
echo "例如: python3 web_app.py --port 8080"
echo ""
python3 web_app.py
