#!/bin/bash
# 设置自动清理任务
# 功能：配置 cron 定时任务，每天凌晨2点自动清理旧文件

echo "=========================================="
echo "设置自动清理任务"
echo "=========================================="

# 获取脚本所在目录的绝对路径
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CLEANUP_SCRIPT="$SCRIPT_DIR/cleanup_old_files.py"
LOG_DIR="$SCRIPT_DIR/logs"
LOG_FILE="$LOG_DIR/cleanup.log"

# 创建日志目录
mkdir -p "$LOG_DIR"

# 检查清理脚本是否存在
if [ ! -f "$CLEANUP_SCRIPT" ]; then
    echo "❌ 错误: 清理脚本不存在: $CLEANUP_SCRIPT"
    exit 1
fi

# 设置脚本可执行权限
chmod +x "$CLEANUP_SCRIPT"

# 检查 Python 环境
if command -v python3 &> /dev/null; then
    PYTHON_CMD="python3"
elif command -v python &> /dev/null; then
    PYTHON_CMD="python"
else
    echo "❌ 错误: 未找到 Python 环境"
    exit 1
fi

echo "✅ Python 命令: $PYTHON_CMD"
echo "✅ 清理脚本: $CLEANUP_SCRIPT"
echo "✅ 日志文件: $LOG_FILE"

# 生成 cron 任务命令
CRON_CMD="0 2 * * * cd $SCRIPT_DIR && $PYTHON_CMD $CLEANUP_SCRIPT --days 5 >> $LOG_FILE 2>&1"

echo ""
echo "=========================================="
echo "Cron 任务配置"
echo "=========================================="
echo "执行时间: 每天凌晨 2:00"
echo "保留天数: 5 天"
echo "日志文件: $LOG_FILE"
echo ""
echo "Cron 命令:"
echo "$CRON_CMD"
echo ""

# 检查是否已存在相同的 cron 任务
if crontab -l 2>/dev/null | grep -q "cleanup_old_files.py"; then
    echo "⚠️  检测到已存在的清理任务"
    echo ""
    read -p "是否要替换现有任务？(y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ 取消设置"
        exit 0
    fi
    
    # 删除旧任务
    crontab -l 2>/dev/null | grep -v "cleanup_old_files.py" | crontab -
    echo "✅ 已删除旧任务"
fi

# 添加新的 cron 任务
(crontab -l 2>/dev/null; echo "$CRON_CMD") | crontab -

if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "✅ 自动清理任务设置成功！"
    echo "=========================================="
    echo ""
    echo "任务详情:"
    echo "  • 执行时间: 每天凌晨 2:00"
    echo "  • 保留天数: 5 天"
    echo "  • 清理目录: outputdata, inputdata"
    echo "  • 日志文件: $LOG_FILE"
    echo ""
    echo "查看当前 cron 任务:"
    echo "  crontab -l"
    echo ""
    echo "查看清理日志:"
    echo "  tail -f $LOG_FILE"
    echo ""
    echo "手动执行清理（试运行）:"
    echo "  $PYTHON_CMD $CLEANUP_SCRIPT --dry-run"
    echo ""
    echo "手动执行清理（正式运行）:"
    echo "  $PYTHON_CMD $CLEANUP_SCRIPT"
    echo ""
    echo "删除自动清理任务:"
    echo "  crontab -l | grep -v 'cleanup_old_files.py' | crontab -"
    echo ""
else
    echo ""
    echo "=========================================="
    echo "❌ 设置失败"
    echo "=========================================="
    echo ""
    echo "可能的原因:"
    echo "  1. cron 服务未运行"
    echo "  2. 没有权限修改 crontab"
    echo ""
    echo "手动设置方法:"
    echo "  1. 编辑 crontab: crontab -e"
    echo "  2. 添加以下行:"
    echo "     $CRON_CMD"
    echo ""
    exit 1
fi
