#!/bin/bash
# MyDataCheck 项目文件完整整理脚本（包括所有md文件）

echo "========================================="
echo "MyDataCheck 项目完整文件整理"
echo "========================================="
echo ""

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 创建目录结构
echo -e "${BLUE}📁 创建目录结构...${NC}"
mkdir -p docs/migration
mkdir -p docs/ui
mkdir -p docs/cleanup
mkdir -p backups
mkdir -p tests
mkdir -p scripts

echo -e "${GREEN}✅ 目录创建完成${NC}"
echo ""

# 统计变量
moved_files=0

# 移动文档文件
echo -e "${BLUE}📚 整理文档文件...${NC}"

# 迁移相关文档
echo "  处理迁移相关文档..."
for file in 代码拆分*.md 快速迁移指南.md 路由迁移*.md 迁移工作*.md WEB_APP_MIGRATION_GUIDE.md; do
    if [ -f "$file" ]; then
        mv "$file" docs/migration/
        echo -e "${GREEN}  ✅ $file -> docs/migration/${NC}"
        ((moved_files++))
    fi
done

# 清理相关文档
echo "  处理清理相关文档..."
for file in 冗余文件清理报告.md 清理完成总结.md 文件整理*.md; do
    if [ -f "$file" ]; then
        mv "$file" docs/cleanup/
        echo -e "${GREEN}  ✅ $file -> docs/cleanup/${NC}"
        ((moved_files++))
    fi
done

# UI相关文档
echo "  处理UI相关文档..."
for file in 侧边栏*.md 界面*.md; do
    if [ -f "$file" ]; then
        mv "$file" docs/ui/
        echo -e "${GREEN}  ✅ $file -> docs/ui/${NC}"
        ((moved_files++))
    fi
done

# 检查是否还有其他md文件
echo "  检查其他md文件..."
other_md_files=$(ls *.md 2>/dev/null | grep -v "README.md" | grep -v "KIRO_AUTO_ACCEPT_CONFIG.md")
if [ ! -z "$other_md_files" ]; then
    echo -e "${YELLOW}  ⚠️  发现其他md文件:${NC}"
    for file in $other_md_files; do
        echo -e "${YELLOW}     - $file${NC}"
        echo "     请手动决定是否移动此文件"
    done
fi

echo ""

# 移动测试文件
echo -e "${BLUE}🧪 整理测试文件...${NC}"
test_count=0
for file in test_*.py test_*.sh; do
    if [ -f "$file" ]; then
        mv "$file" tests/
        echo -e "${GREEN}  ✅ $file -> tests/${NC}"
        ((test_count++))
        ((moved_files++))
    fi
done
if [ $test_count -eq 0 ]; then
    echo "  （无测试文件需要移动）"
fi

echo ""

# 移动工具脚本
echo -e "${BLUE}🔧 整理工具脚本...${NC}"
script_count=0
for file in auto_split_routes.py generate_route_files.py reorganize_md_files.py split_web_app.py; do
    if [ -f "$file" ]; then
        mv "$file" scripts/
        echo -e "${GREEN}  ✅ $file -> scripts/${NC}"
        ((script_count++))
        ((moved_files++))
    fi
done
if [ $script_count -eq 0 ]; then
    echo "  （无工具脚本需要移动）"
fi

echo ""

# 移动备份文件
echo -e "${BLUE}💾 整理备份文件...${NC}"
backup_count=0
for file in web_app_backup_*.py web_app_new.py web_app_migrated.py; do
    if [ -f "$file" ]; then
        mv "$file" backups/
        echo -e "${GREEN}  ✅ $file -> backups/${NC}"
        ((backup_count++))
        ((moved_files++))
    fi
done
if [ $backup_count -eq 0 ]; then
    echo "  （无备份文件需要移动）"
fi

echo ""

# 检查异常文件
echo -e "${BLUE}🔍 检查异常文件...${NC}"
found_abnormal=false
for file in =1.24.0 =2.0.0 =2.25.0; do
    if [ -f "$file" ]; then
        echo -e "${YELLOW}  ⚠️  发现异常文件: $file${NC}"
        echo "     建议删除此文件（可能是pip安装错误产生的）"
        found_abnormal=true
    fi
done
if [ "$found_abnormal" = false ]; then
    echo "  （无异常文件）"
fi

echo ""

# 统计结果
echo "========================================="
echo -e "${GREEN}✅ 文件整理完成！${NC}"
echo "========================================="
echo ""
echo "整理统计："
echo "- 移动文件总数: $moved_files"
echo ""
echo "目录文件数："
echo "- docs/migration/: $(ls docs/migration/ 2>/dev/null | wc -l | tr -d ' ') 个文件"
echo "- docs/ui/: $(ls docs/ui/ 2>/dev/null | wc -l | tr -d ' ') 个文件"
echo "- docs/cleanup/: $(ls docs/cleanup/ 2>/dev/null | wc -l | tr -d ' ') 个文件"
echo "- tests/: $(ls tests/ 2>/dev/null | wc -l | tr -d ' ') 个文件"
echo "- scripts/: $(ls scripts/ 2>/dev/null | wc -l | tr -d ' ') 个文件"
echo "- backups/: $(ls backups/ 2>/dev/null | wc -l | tr -d ' ') 个文件"
echo ""

# 显示新的目录结构
echo "新的目录结构："
echo "MyDataCheck/"
echo "├── docs/"
echo "│   ├── migration/    # 迁移相关文档"
echo "│   ├── ui/           # UI相关文档"
echo "│   └── cleanup/      # 清理相关文档"
echo "├── tests/            # 测试文件"
echo "├── scripts/          # 工具脚本"
echo "├── backups/          # 备份文件"
echo "└── （核心文件保持原位）"
echo ""

# 显示根目录剩余文件
echo "根目录剩余文件："
ls -1 *.py *.sh *.md 2>/dev/null | head -15
echo ""

echo "💡 提示："
echo "1. 文档已分类整理到 docs/ 目录"
echo "2. 测试文件已移到 tests/ 目录"
echo "3. 备份文件已移到 backups/ 目录"
echo "4. 工具脚本已移到 scripts/ 目录"
echo ""
