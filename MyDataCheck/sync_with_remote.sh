#!/bin/bash

# 阿里云代码同步脚本
# 功能：拉取远程更新，合并本地修改，推送到远程

set -e

echo "=========================================="
echo "  阿里云代码同步脚本"
echo "=========================================="

# 1. 检查是否有未提交的更改
echo ""
echo "[步骤1] 检查本地更改状态..."
if [[ -n $(git status --porcelain) ]]; then
    echo "✓ 检测到本地有未提交的更改"
    git status --short
else
    echo "✓ 本地没有未提交的更改"
fi

# 2. 暂存本地更改
echo ""
echo "[步骤2] 暂存本地更改..."
git stash push -m "auto-stash-$(date +%Y%m%d%H%M%S)"
echo "✓ 本地更改已暂存"

# 3. 拉取远程最新代码（使用rebase策略）
echo ""
echo "[步骤3] 拉取阿里云最新代码..."
git fetch origin
git pull --rebase origin $(git branch --show-current)
echo "✓ 远程代码已拉取"

# 4. 恢复本地更改
echo ""
echo "[步骤4] 恢复本地更改..."
if git stash list | grep -q "auto-stash"; then
    git stash pop
    echo "✓ 本地更改已恢复"
else
    echo "✓ 没有需要恢复的暂存"
fi

# 5. 检查是否有冲突
echo ""
echo "[步骤5] 检查合并状态..."
if [[ -n $(git diff --name-only --diff-filter=U) ]]; then
    echo "⚠️  检测到合并冲突，请手动解决以下文件："
    git diff --name-only --diff-filter=U
    echo ""
    echo "解决冲突后，运行以下命令完成提交："
    echo "  git add ."
    echo "  git commit -m '合并远程更新'"
    echo "  git push origin $(git branch --show-current)"
    exit 1
fi

# 6. 提交合并后的代码
echo ""
echo "[步骤6] 提交代码..."
git add .
if [[ -n $(git status --porcelain) ]]; then
    git commit -m "合并本地更新与远程更新 $(date +%Y-%m-%d_%H:%M:%S)"
    echo "✓ 代码已提交"
else
    echo "✓ 没有需要提交的更改"
fi

# 7. 推送到远程
echo ""
echo "[步骤7] 推送到阿里云..."
git push origin $(git branch --show-current)
echo "✓ 代码已推送"

echo ""
echo "=========================================="
echo "  ✅ 同步完成！"
echo "=========================================="
