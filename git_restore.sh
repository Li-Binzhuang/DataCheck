#!/bin/bash
# Git 代码恢复脚本
# 用于从远程仓库恢复代码，覆盖本地修改

echo "=========================================="
echo "Git 代码恢复脚本"
echo "=========================================="
echo ""

# 显示当前状态
echo "当前 Git 状态："
git status
echo ""

# 询问用户选择
echo "请选择恢复方式："
echo "1) 恢复所有文件（放弃所有本地修改）"
echo "2) 恢复特定文件"
echo "3) 先保存本地修改再拉取（使用 stash）"
echo "4) 取消操作"
echo ""
read -p "请输入选项 (1-4): " choice

case $choice in
    1)
        echo ""
        echo "⚠️  警告：这将放弃所有本地修改！"
        read -p "确认继续？(y/n): " confirm
        if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
            echo ""
            echo "正在从远程恢复代码..."
            git fetch origin
            git reset --hard origin/master
            echo ""
            echo "✅ 代码已恢复到远程最新版本"
        else
            echo "操作已取消"
        fi
        ;;
    2)
        echo ""
        read -p "请输入要恢复的文件路径（相对路径）: " filepath
        if [ -n "$filepath" ]; then
            echo ""
            echo "正在恢复文件: $filepath"
            git checkout origin/master -- "$filepath"
            echo ""
            echo "✅ 文件已恢复"
        else
            echo "❌ 文件路径不能为空"
        fi
        ;;
    3)
        echo ""
        echo "正在保存本地修改..."
        git stash save "自动保存 - $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
        echo "正在拉取远程代码..."
        git pull origin master
        echo ""
        echo "✅ 代码已更新"
        echo ""
        read -p "是否恢复刚才保存的本地修改？(y/n): " restore
        if [ "$restore" = "y" ] || [ "$restore" = "Y" ]; then
            git stash pop
            echo "✅ 本地修改已恢复"
        else
            echo "💾 本地修改已保存，可以使用 'git stash list' 查看"
            echo "   使用 'git stash pop' 恢复修改"
        fi
        ;;
    4)
        echo ""
        echo "操作已取消"
        ;;
    *)
        echo ""
        echo "❌ 无效选项"
        ;;
esac

echo ""
echo "=========================================="
