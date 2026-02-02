#!/bin/bash
# 监控数据对比任务进度

echo "==================================="
echo "MyDataCheck 任务进度监控"
echo "==================================="
echo ""

# 1. 检查Web服务是否运行
echo "1. 检查Web服务状态:"
if ps aux | grep -v grep | grep "web_app.py" > /dev/null; then
    echo "   ✅ Web服务正在运行"
    ps aux | grep -v grep | grep "web_app.py" | awk '{print "   PID: " $2 ", CPU: " $3 "%, MEM: " $4 "%"}'
else
    echo "   ❌ Web服务未运行"
fi
echo ""

# 2. 检查输出目录
echo "2. 最近生成的文件:"
if [ -d "MyDataCheck/outputdata/api_comparison" ]; then
    ls -lht MyDataCheck/outputdata/api_comparison/*.csv 2>/dev/null | head -5 | while read line; do
        echo "   $line"
    done
else
    echo "   ⚠️  输出目录不存在"
fi
echo ""

# 3. 检查正在写入的文件
echo "3. 正在写入的文件（最近5分钟修改）:"
find MyDataCheck/outputdata/api_comparison -name "*.csv" -mmin -5 2>/dev/null | while read file; do
    size=$(du -h "$file" | cut -f1)
    lines=$(wc -l < "$file" 2>/dev/null || echo "0")
    echo "   📝 $file"
    echo "      大小: $size, 行数: $lines"
done
echo ""

# 4. 检查任务日志
echo "4. 最近的任务日志:"
if [ -d "MyDataCheck/logs/tasks" ]; then
    latest_log=$(ls -t MyDataCheck/logs/tasks/*.log 2>/dev/null | head -1)
    if [ -n "$latest_log" ]; then
        echo "   📄 $latest_log"
        echo "   最后10行:"
        tail -10 "$latest_log" | sed 's/^/      /'
    else
        echo "   ⚠️  没有找到任务日志"
    fi
else
    echo "   ⚠️  日志目录不存在"
fi
echo ""

echo "==================================="
echo "提示: 每5秒自动刷新，按 Ctrl+C 退出"
echo "==================================="
