#!/bin/bash
# 快速安装 psutil 依赖

echo "=========================================="
echo "安装 psutil 依赖"
echo "=========================================="
echo ""

# 进入脚本所在目录
cd "$(dirname "$0")"

# 检查虚拟环境
if [ ! -d ".venv" ]; then
    echo "❌ 错误: 未找到虚拟环境 .venv"
    echo "请先创建虚拟环境: python3.12 -m venv .venv"
    exit 1
fi

# 激活虚拟环境
echo "激活虚拟环境..."
source .venv/bin/activate

# 安装 psutil
echo ""
echo "安装 psutil..."
pip install psutil>=5.9.0

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ psutil 安装成功"
    
    # 验证安装
    python -c "import psutil; print(f'psutil 版本: {psutil.__version__}')"
    
    echo ""
    echo "=========================================="
    echo "现在可以启动服务了:"
    echo "  ./start_web.sh"
    echo "=========================================="
else
    echo ""
    echo "❌ psutil 安装失败"
    echo "请手动安装: pip install psutil"
    exit 1
fi
