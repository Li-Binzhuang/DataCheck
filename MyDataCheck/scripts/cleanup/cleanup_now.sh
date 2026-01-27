#!/bin/bash
# 立即执行清理（交互式）
# 功能：手动清理旧的CSV文件

echo "=========================================="
echo "CSV文件清理工具"
echo "=========================================="

# 获取脚本所在目录
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CLEANUP_SCRIPT="$SCRIPT_DIR/cleanup_old_files.py"

# 检查清理脚本是否存在
if [ ! -f "$CLEANUP_SCRIPT" ]; then
    echo "❌ 错误: 清理脚本不存在: $CLEANUP_SCRIPT"
    exit 1
fi

# 检查 Python 环境
if command -v python3 &> /dev/null; then
    PYTHON_CMD="python3"
elif command -v python &> /dev/null; then
    PYTHON_CMD="python"
else
    echo "❌ 错误: 未找到 Python 环境"
    exit 1
fi

# 默认保留天数
DAYS_TO_KEEP=5

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --days)
            DAYS_TO_KEEP="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN="--dry-run"
            shift
            ;;
        --help|-h)
            echo ""
            echo "用法: $0 [选项]"
            echo ""
            echo "选项:"
            echo "  --days N       保留最近N天的文件（默认5天）"
            echo "  --dry-run      试运行模式（只显示不删除）"
            echo "  --help, -h     显示帮助信息"
            echo ""
            echo "示例:"
            echo "  $0                    # 删除5天前的文件"
            echo "  $0 --days 7           # 删除7天前的文件"
            echo "  $0 --dry-run          # 试运行，查看将要删除的文件"
            echo "  $0 --days 3 --dry-run # 试运行，查看3天前的文件"
            echo ""
            exit 0
            ;;
        *)
            echo "❌ 未知选项: $1"
            echo "使用 --help 查看帮助"
            exit 1
            ;;
    esac
done

echo ""
echo "配置:"
echo "  保留天数: $DAYS_TO_KEEP 天"
echo "  运行模式: ${DRY_RUN:+试运行（不会真正删除）}"
echo "  运行模式: ${DRY_RUN:-正式运行（会删除文件）}"
echo ""

# 如果不是试运行模式，需要确认
if [ -z "$DRY_RUN" ]; then
    read -p "⚠️  确认要删除 $DAYS_TO_KEEP 天前的CSV文件吗？(y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ 取消清理"
        exit 0
    fi
fi

echo ""
echo "=========================================="
echo "开始清理..."
echo "=========================================="
echo ""

# 执行清理
$PYTHON_CMD "$CLEANUP_SCRIPT" --days "$DAYS_TO_KEEP" $DRY_RUN

echo ""
echo "=========================================="
echo "清理完成"
echo "=========================================="
