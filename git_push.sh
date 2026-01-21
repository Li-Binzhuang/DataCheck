#!/bin/bash
# 将 MyDataCheck 项目提交并推送到 Git 仓库
# 已配置访问令牌，一键提交

set -e

# 仓库地址
REPO_URL="https://codeup.aliyun.com/674eeae32855ba207e1c86c8/daizhonhuankuan_part1/zlfjob.git"

# 访问凭据（已配置）
GIT_USERNAME="zhanglifeng703"
GIT_TOKEN="zhang0324"

# 获取脚本所在目录
SCRIPT_DIR="$(dirname "$0")"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "准备提交 MyDataCheck 项目到 Git 仓库"
echo "=========================================="
echo "仓库结构: daizhonghuankuan_part1/"
echo "  └── MyDataCheck/"
echo ""

# 检查 MyDataCheck 目录是否存在
if [ ! -d "MyDataCheck" ]; then
    echo "错误: MyDataCheck 目录不存在！"
    exit 1
fi

echo "注意: 只提交 MyDataCheck 目录内容到远程仓库"
echo ""

# 修复 macOS SSL 证书问题
if [[ "$OSTYPE" == "darwin"* ]]; then
    git config --global http.sslVerify false 2>/dev/null || true
fi

# 初始化 Git 仓库（如果还没有）
if [ ! -d ".git" ]; then
    echo "初始化 Git 仓库..."
    git init
fi

# 构建带凭据的 URL
BASE_URL=$(echo "$REPO_URL" | sed -E 's|https://||')
AUTH_URL="https://${GIT_USERNAME}:${GIT_TOKEN}@${BASE_URL}"

# 添加远程仓库（如果还没有）
if ! git remote | grep -q "origin"; then
    echo "添加远程仓库（已配置访问令牌）..."
    git remote add origin "$AUTH_URL"
else
    echo "更新远程仓库地址（已配置访问令牌）..."
    git remote set-url origin "$AUTH_URL"
fi

# 创建 .gitignore 文件（忽略临时文件和系统文件）
if [ ! -f ".gitignore" ]; then
    cat > .gitignore << EOF
# 临时文件
*.tmp
*.bak
*~
.DS_Store
.~*

# Python 缓存
__pycache__/
*.pyc
*.pyo
*.pyd
.Python

# 虚拟环境
.venv/
venv/
env/

# Jupyter Notebook
.ipynb_checkpoints

# IDE
.vscode/
.idea/
*.swp
*.swo

# 日志文件
*.log
logs/

# 大型数据文件（可选，根据需要调整）
# *.csv
# *.xlsx
EOF
    echo "已创建 .gitignore 文件"
fi

# 检查 MyDataCheck 是否是子模块
if [ -f "MyDataCheck/.git" ] || [ -d "MyDataCheck/.git" ]; then
    echo "检测到 MyDataCheck 是 Git 子模块"
    echo "先提交子模块内的变更..."
    
    # 进入子模块并提交变更
    cd MyDataCheck
    if [ -n "$(git status --porcelain)" ]; then
        echo "子模块内有未提交的变更，正在提交..."
        git add -A
        git commit -m "chore: 更新 MyDataCheck 子模块内容

- 提交时间: $(date '+%Y-%m-%d %H:%M:%S')" || echo "子模块提交完成或无需提交"
    else
        echo "子模块内无变更"
    fi
    cd ..
    
    # 更新父仓库中的子模块引用
    echo "更新父仓库中的子模块引用..."
    git add MyDataCheck
else
    # 如果不是子模块，按普通目录处理
    echo "添加 MyDataCheck 目录到 Git..."
    git add MyDataCheck/
fi

# 添加其他文件（未跟踪的或已修改的）
if [ -f ".gitignore" ]; then
    # 检查文件是否未跟踪或已修改
    if ! git ls-files --error-unmatch .gitignore >/dev/null 2>&1 || ! git diff --quiet .gitignore 2>/dev/null; then
        echo "添加 .gitignore 文件..."
        git add .gitignore
    fi
fi

if [ -f "git_push.sh" ]; then
    # 检查文件是否未跟踪或已修改
    if ! git ls-files --error-unmatch git_push.sh >/dev/null 2>&1 || ! git diff --quiet git_push.sh 2>/dev/null; then
        echo "添加 git_push.sh 脚本..."
        git add git_push.sh
    fi
fi

# 检查是否有变更需要提交（检查暂存区）
if ! git diff --staged --quiet 2>/dev/null; then
    # 有暂存的文件，执行提交
    echo "提交变更..."
    COMMIT_MSG="feat: 提交 MyDataCheck 项目

- 包含 MyDataCheck 项目的所有文件
- MyDataCheck 位于 daizhonghuankuan_part1/MyDataCheck/
- 提交时间: $(date '+%Y-%m-%d %H:%M:%S')"
    
    git commit -m "$COMMIT_MSG"
    echo "✓ 已提交更改"
else
    # 检查是否有未提交的变更
    if [ -n "$(git status --porcelain)" ]; then
        echo "⚠ 检测到未跟踪的文件（如 Mytest/），但这些文件未被添加到暂存区"
        echo "   如需提交这些文件，请手动运行: git add <文件>"
    else
        echo "✓ 工作区干净，没有需要提交的变更"
    fi
    echo "跳过提交步骤"
fi

# 获取当前分支
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "main")

echo ""
echo "=========================================="
echo "推送到远程仓库..."
echo "=========================================="
echo "分支: $CURRENT_BRANCH"
echo ""

# 先拉取远程更改（如果远程分支存在）
echo "检查远程分支状态..."
if git ls-remote --heads origin "$CURRENT_BRANCH" | grep -q "$CURRENT_BRANCH"; then
    echo "远程分支存在，先拉取远程更改..."
    # 使用 rebase 方式拉取，保持提交历史线性
    if git pull --rebase origin "$CURRENT_BRANCH" 2>&1; then
        echo "✓ 已拉取并合并远程更改"
    else
        echo "⚠ 拉取远程更改时出现冲突或错误"
        echo "   如果出现冲突，请手动解决后重试"
        echo "   或者使用: git pull --rebase origin $CURRENT_BRANCH"
    fi
else
    echo "远程分支不存在，将创建新分支"
fi

echo ""
# 推送（已配置访问令牌）
echo "推送到远程仓库（已配置访问令牌）..."
PUSH_OUTPUT=$(git push -u origin "$CURRENT_BRANCH" 2>&1)
PUSH_EXIT_CODE=$?

if [ $PUSH_EXIT_CODE -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "✓ 推送成功！"
    echo "=========================================="
    echo ""
    echo "仓库地址: $REPO_URL"
    echo "提交目录: MyDataCheck/"
    echo "当前分支: $CURRENT_BRANCH"
    echo ""
    echo "查看远程仓库状态:"
    git remote -v | sed 's|://[^@]*@|://***:***@|g'
elif echo "$PUSH_OUTPUT" | grep -q "non-fast-forward"; then
    echo ""
    echo "=========================================="
    echo "⚠ 推送被拒绝：本地分支落后于远程分支"
    echo "=========================================="
    echo ""
    echo "建议操作："
    echo "1. 手动拉取并合并: git pull --rebase origin $CURRENT_BRANCH"
    echo "2. 解决可能的冲突后，再次运行此脚本"
    echo "3. 或者强制推送（谨慎使用）: git push -f origin $CURRENT_BRANCH"
    echo ""
    echo "详细错误信息:"
    echo "$PUSH_OUTPUT"
    exit 1
else
    echo ""
    echo "=========================================="
    echo "✗ 推送失败"
    echo "=========================================="
    echo ""
    echo "请检查："
    echo "1. 网络连接是否正常"
    echo "2. 访问令牌是否正确"
    echo "3. 仓库地址是否正确"
    echo "4. 是否有仓库访问权限"
    echo ""
    echo "详细错误信息:"
    echo "$PUSH_OUTPUT"
    exit 1
fi
