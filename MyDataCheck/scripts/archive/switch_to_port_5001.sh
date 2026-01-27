#!/bin/bash
# 快速切换到5001端口

echo "=========================================="
echo "切换Web服务端口：5000 → 5001"
echo "=========================================="
echo ""

# 停止现有服务
echo "1. 停止现有服务..."
pkill -9 -f web_app.py 2>/dev/null
sleep 1

# 修改 web/app.py
echo "2. 修改 web/app.py 端口配置..."
if [ -f "web/app.py" ]; then
    sed -i '' 's/port=5000/port=5001/g' web/app.py
    echo "   ✅ web/app.py 已更新"
else
    echo "   ❌ 未找到 web/app.py"
fi

# 修改 start_web.sh
echo "3. 修改 start_web.sh 端口配置..."
if [ -f "start_web.sh" ]; then
    sed -i '' 's/5000/5001/g' start_web.sh
    echo "   ✅ start_web.sh 已更新"
else
    echo "   ❌ 未找到 start_web.sh"
fi

# 修改 stop_web.sh（已经是5001，无需修改）
echo "4. 检查 stop_web.sh..."
if grep -q "5001" stop_web.sh 2>/dev/null; then
    echo "   ✅ stop_web.sh 已配置为5001"
else
    echo "   ⚠️  stop_web.sh 可能需要手动检查"
fi

echo ""
echo "=========================================="
echo "✅ 端口切换完成！"
echo "=========================================="
echo ""
echo "现在可以启动服务："
echo "  ./start_web.sh"
echo ""
echo "访问地址："
echo "  http://localhost:5001"
echo ""
