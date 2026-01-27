#!/bin/bash
# MyDataCheck 项目文件自动整理脚本

echo "========================================="
echo "MyDataCheck 项目文件整理"
echo "========================================="
echo ""

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 创建目录结构
echo -e "${BLUE}📁 创建目录结构...${NC}"
mkdir -p docs/migration
mkdir -p docs/ui
mkdir -p backups
mkdir -p tests
mkdir -p scripts

echo -e "${GREEN}✅ 目录创建完成${NC}"
echo ""

# 移动文档文件
echo -e "${BLUE}📚 整理文档文件...${NC}"

# 迁移相关文档
for file in 代码拆分*.md 快速迁移指南.md 路由迁移*.md 迁移工作*.md WEB_APP_MIGRATION_GUIDE.md; do
    if [ -f "$file" ]; then
        mv "$file" docs/migration/
        echo -e "${GREEN}✅ 移动: $file -> docs/migration/${NC}"
    fi
done

# 清理相关文档
for file in 冗余文件清理报告.md 清理完成总结.md 文件整理*.md; do
    if [ -f "$file" ]; then
        mv "$file" docs/migration/
        echo -e "${GREEN}✅ 移动: $file -> docs/migration/${NC}"
    fi
done

# UI相关文档
for file in 侧边栏优化*.md 界面*.md; do
    if [ -f "$file" ]; then
        mv "$file" docs/ui/
        echo -e "${GREEN}✅ 移动: $file -> docs/ui/${NC}"
    fi
done

echo ""

# 移动测试文件
echo -e "${BLUE}🧪 整理测试文件...${NC}"
for file in test_*.py test_*.sh; do
    if [ -f "$file" ]; then
        mv "$file" tests/
        echo -e "${GREEN}✅ 移动: $file -> tests/${NC}"
    fi
done

echo ""

# 移动工具脚本
echo -e "${BLUE}🔧 整理工具脚本...${NC}"
for file in auto_split_routes.py generate_route_files.py reorganize_md_files.py split_web_app.py; do
    if [ -f "$file" ]; then
        mv "$file" scripts/
        echo -e "${GREEN}✅ 移动: $file -> scripts/${NC}"
    fi
done

echo ""

# 移动备份文件
echo -e "${BLUE}💾 整理备份文件...${NC}"
for file in web_app_backup_*.py web_app_new.py web_app_migrated.py; do
    if [ -f "$file" ]; then
        mv "$file" backups/
        echo -e "${GREEN}✅ 移动: $file -> backups/${NC}"
    fi
done

echo ""

# 检查异常文件
echo -e "${BLUE}🔍 检查异常文件...${NC}"
for file in =1.24.0 =2.0.0 =2.25.0; do
    if [ -f "$file" ]; then
        echo -e "${YELLOW}⚠️  发现异常文件: $file${NC}"
        echo "   建议删除此文件（可能是pip安装错误产生的）"
    fi
done

echo ""

# 统计结果
echo "========================================="
echo -e "${GREEN}✅ 文件整理完成！${NC}"
echo "========================================="
echo ""
echo "整理结果："
echo "- docs/migration/: $(ls docs/migration/ 2>/dev/null | wc -l | tr -d ' ') 个文件"
echo "- docs/ui/: $(ls docs/ui/ 2>/dev/null | wc -l | tr -d ' ') 个文件"
echo "- tests/: $(ls tests/ 2>/dev/null | wc -l | tr -d ' ') 个文件"
echo "- scripts/: $(ls scripts/ 2>/dev/null | wc -l | tr -d ' ') 个文件"
echo "- backups/: $(ls backups/ 2>/dev/null | wc -l | tr -d ' ') 个文件"
echo ""

# 显示新的目录结构
echo "新的目录结构："
echo "MyDataCheck/"
echo "├── docs/"
echo "│   ├── migration/    # 迁移相关文档"
echo "│   └── ui/           # UI相关文档"
echo "├── tests/            # 测试文件"
echo "├── scripts/          # 工具脚本"
echo "├── backups/          # 备份文件"
echo "└── （核心文件保持原位）"
echo ""

echo "💡 提示："
echo "1. 如果需要访问文档，请到 docs/ 目录"
echo "2. 如果需要运行测试，请到 tests/ 目录"
echo "3. 备份文件已移到 backups/ 目录"
echo ""
