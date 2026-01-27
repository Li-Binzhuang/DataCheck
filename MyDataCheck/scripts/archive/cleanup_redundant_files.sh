#!/bin/bash
# MyDataCheck 项目冗余文件清理脚本

echo "========================================="
echo "MyDataCheck 项目冗余文件清理"
echo "========================================="
echo ""

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 统计变量
total_files=0
total_size=0
deleted_files=0
deleted_size=0

# 函数：删除文件
delete_file() {
    local file="$1"
    if [ -f "$file" ]; then
        local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
        rm "$file"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ 删除: $file${NC}"
            ((deleted_files++))
            ((deleted_size+=size))
        else
            echo -e "${RED}❌ 删除失败: $file${NC}"
        fi
        ((total_files++))
        ((total_size+=size))
    fi
}

# 1. 删除备份文件
echo -e "${BLUE}📁 清理备份文件...${NC}"
delete_file "web_app_backup_20260127_101601.py"
delete_file "web_app_backup_20260127_115817.py"
delete_file "web_app_new.py"
delete_file "web_app_migrated.py"
echo ""

# 2. 删除临时测试文件
echo -e "${BLUE}🧪 清理临时测试文件...${NC}"
delete_file "test_menu_fix.sh"
delete_file "test_migration.sh"
delete_file "test_new_web_app.py"
delete_file "test_path_conversion.py"
delete_file "test_pkl_converter.py"
delete_file "test_quote_removal.py"
echo ""

# 3. 删除工具脚本（已完成任务）
echo -e "${BLUE}🔧 清理工具脚本...${NC}"
delete_file "auto_split_routes.py"
delete_file "generate_route_files.py"
delete_file "reorganize_md_files.py"
delete_file "split_web_app.py"
echo ""

# 4. 删除临时文档
echo -e "${BLUE}📚 清理临时文档...${NC}"
delete_file "WEB_APP_MIGRATION_GUIDE.md"
delete_file "快速迁移指南.md"
delete_file "代码拆分分析报告.md"
delete_file "代码拆分快速总结.md"
delete_file "路由迁移完成报告.md"
delete_file "迁移工作完成总结.md"
delete_file "侧边栏优化验证指南.md"
delete_file "文件整理方案.md"
delete_file "文件整理快速指南.md"
echo ""

# 5. 删除模板备份文件
echo -e "${BLUE}🎨 清理模板备份文件...${NC}"
delete_file "templates/index_backup_20260126_193547.html"
delete_file "templates/index_new.html"
delete_file "templates/index_old_tabs.html"
delete_file "templates/merge_ui.py"
delete_file "templates/MENU_FIX_GUIDE.md"
delete_file "templates/README_UI_UPDATE.md"
echo ""

# 6. 删除异常文件
echo -e "${BLUE}🗑️  清理异常文件...${NC}"
delete_file "=1.24.0"
delete_file "=2.0.0"
delete_file "=2.25.0"
echo ""

# 格式化大小
format_size() {
    local size=$1
    if [ $size -lt 1024 ]; then
        echo "${size}B"
    elif [ $size -lt $((1024 * 1024)) ]; then
        echo "$(awk "BEGIN {printf \"%.1f\", $size/1024}")KB"
    else
        echo "$(awk "BEGIN {printf \"%.2f\", $size/(1024*1024)}")MB"
    fi
}

# 显示统计结果
echo "========================================="
echo -e "${GREEN}✅ 清理完成！${NC}"
echo "========================================="
echo ""
echo "清理统计："
echo "- 检查文件数: $total_files"
echo "- 删除文件数: $deleted_files"
echo "- 释放空间: $(format_size $deleted_size)"
echo ""

# 显示剩余的根目录文件
echo "根目录剩余文件："
ls -1 *.py *.sh *.md 2>/dev/null | head -20
echo ""

echo "💡 提示："
echo "1. 备份文件已删除"
echo "2. 临时测试文件已删除"
echo "3. 已完成任务的工具脚本已删除"
echo "4. 临时文档已删除（重要文档已保存在 md/ 目录）"
echo "5. 模板备份文件已删除"
echo ""
echo "✅ 项目目录更加清爽！"
echo ""
