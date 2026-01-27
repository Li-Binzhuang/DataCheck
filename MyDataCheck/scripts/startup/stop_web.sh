#!/bin/bash
# Web界面停止脚本（非交互式，直接停止）

echo "=========================================="
echo "停止Web服务"
echo "=========================================="
echo ""

# 查找并停止web_app.py进程
PIDS=$(lsof -ti:5001 2>/dev/null)

if [ -z "$PIDS" ]; then
    echo "未找到运行在端口5001的进程"
    # 尝试通过进程名查找
    PIDS=$(pgrep -f "web_app.py" 2>/dev/null)
    if [ -z "$PIDS" ]; then
        echo "未找到web_app.py进程"
        exit 0
    fi
fi

echo "找到以下进程:"
echo "$PIDS" | while read PID; do
    if [ ! -z "$PID" ]; then
        echo "  PID: $PID"
        ps -p $PID -o command= 2>/dev/null | head -1
    fi
done

echo ""
echo "正在强制停止..."

# 停止所有占用5001端口的进程
lsof -ti:5001 2>/dev/null | xargs kill -9 2>/dev/null

# 停止所有web_app.py进程
pkill -9 -f "web_app.py" 2>/dev/null

# 等待一下，然后检查是否成功
sleep 1

REMAINING=$(lsof -ti:5001 2>/dev/null)
if [ -z "$REMAINING" ]; then
    echo "✅ Web服务已成功停止"
else
    echo "⚠️  警告: 仍有进程占用端口5001"
    echo "剩余进程PID: $REMAINING"
    echo "正在强制停止剩余进程..."
    echo "$REMAINING" | xargs kill -9 2>/dev/null
    sleep 1
    FINAL_CHECK=$(lsof -ti:5001 2>/dev/null)
    if [ -z "$FINAL_CHECK" ]; then
        echo "✅ 所有进程已成功停止"
    else
        echo "❌ 无法停止以下进程，请手动执行:"
        echo "   kill -9 $FINAL_CHECK"
    fi
fi
