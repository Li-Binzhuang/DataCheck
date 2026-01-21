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
echo "准备提交项目到 Git 仓库"
echo "=========================================="
echo "仓库结构: daizhonghuankuan_part1/"
echo "  ├── MyDataCheck/"
echo "  └── Mytest/"
echo ""

# 检查 MyDataCheck 目录是否存在
if [ ! -d "MyDataCheck" ]; then
    echo "错误: MyDataCheck 目录不存在！"
    exit 1
fi

# 检查 Mytest 目录是否存在
if [ ! -d "Mytest" ]; then
    echo "警告: Mytest 目录不存在，将只提交 MyDataCheck"
else
    echo "将提交 MyDataCheck 和 Mytest 目录内容到远程仓库"
fi
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

# 添加 Mytest 目录（如果存在且不是子模块）
if [ -d "Mytest" ]; then
    if [ -f "Mytest/.git" ] || [ -d "Mytest/.git" ]; then
        echo "检测到 Mytest 是 Git 子模块"
        echo "先提交子模块内的变更..."
        
        # 进入子模块并提交变更
        cd Mytest
        if [ -n "$(git status --porcelain)" ]; then
            echo "Mytest 子模块内有未提交的变更，正在提交..."
            git add -A
            git commit -m "chore: 更新 Mytest 子模块内容

- 提交时间: $(date '+%Y-%m-%d %H:%M:%S')" || echo "Mytest 子模块提交完成或无需提交"
        else
            echo "Mytest 子模块内无变更"
        fi
        cd ..
        
        # 更新父仓库中的子模块引用
        echo "更新父仓库中的 Mytest 子模块引用..."
        git add Mytest
    else
        # 如果不是子模块，按普通目录处理
        echo "添加 Mytest 目录到 Git..."
        git add Mytest/
    fi
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
    if [ -d "Mytest" ]; then
        COMMIT_MSG="feat: 提交 MyDataCheck 和 Mytest 项目

- 包含 MyDataCheck 项目的所有文件
- 包含 Mytest 项目的所有文件
- MyDataCheck 位于 daizhonghuankuan_part1/MyDataCheck/
- Mytest 位于 daizhonghuankuan_part1/Mytest/
- 提交时间: $(date '+%Y-%m-%d %H:%M:%S')"
    else
        COMMIT_MSG="feat: 提交 MyDataCheck 项目

- 包含 MyDataCheck 项目的所有文件
- MyDataCheck 位于 daizhonghuankuan_part1/MyDataCheck/
- 提交时间: $(date '+%Y-%m-%d %H:%M:%S')"
    fi
    
    git commit -m "$COMMIT_MSG"
    echo "✓ 已提交更改"
else
    # 检查是否有未提交的变更
    if [ -n "$(git status --porcelain)" ]; then
        echo "⚠ 检测到未跟踪的文件，但这些文件未被添加到暂存区"
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
    echo "远程分支存在，检查本地和远程的差异..."
    
    # 检查本地是否有未推送的提交
    LOCAL_COMMITS=$(git log origin/$CURRENT_BRANCH..HEAD --oneline 2>/dev/null | wc -l | tr -d ' ')
    REMOTE_COMMITS=$(git log HEAD..origin/$CURRENT_BRANCH --oneline 2>/dev/null | wc -l | tr -d ' ')
    
    if [ "$REMOTE_COMMITS" -gt 0 ]; then
        echo "检测到远程有 $REMOTE_COMMITS 个新提交，本地有 $LOCAL_COMMITS 个未推送提交"
        
        # 如果 MyDataCheck 是子模块，检测到结构差异时直接跳过拉取
        if [ -f "MyDataCheck/.git" ] || [ -d "MyDataCheck/.git" ]; then
            echo "检测到 MyDataCheck 是子模块"
            # 检查远程 MyDataCheck 是否是普通目录（会导致冲突）
            REMOTE_MYDATACHECK_TYPE=$(git ls-tree origin/$CURRENT_BRANCH MyDataCheck 2>/dev/null | awk '{print $2}' || echo "")
            if [ "$REMOTE_MYDATACHECK_TYPE" = "tree" ]; then
                echo "⚠ 检测到结构差异：远程 MyDataCheck 是普通目录，本地是子模块"
                echo "   跳过拉取步骤以避免冲突，将直接推送本地版本"
            else
                echo "尝试拉取远程更改..."
                # 先暂存子模块引用
                git add MyDataCheck 2>/dev/null || true
                # 尝试拉取
                PULL_OUTPUT=$(git pull --rebase --recurse-submodules=no origin "$CURRENT_BRANCH" 2>&1)
                PULL_EXIT=$?
                
                if [ $PULL_EXIT -eq 0 ]; then
                    echo "✓ 已拉取并合并远程更改"
                elif echo "$PULL_OUTPUT" | grep -q "untracked working tree files would be overwritten"; then
                    echo "⚠ 拉取时检测到文件冲突，跳过拉取步骤，直接推送"
                else
                    echo "⚠ 拉取失败，将直接尝试推送"
                fi
            fi
        else
            echo "尝试拉取远程更改..."
            PULL_OUTPUT=$(git pull --rebase origin "$CURRENT_BRANCH" 2>&1)
            PULL_EXIT=$?
            
            if [ $PULL_EXIT -eq 0 ]; then
                echo "✓ 已拉取并合并远程更改"
            else
                echo "⚠ 拉取失败，将直接尝试推送"
            fi
        fi
    else
        echo "✓ 本地已是最新，无需拉取"
    fi
else
    echo "远程分支不存在，将创建新分支"
fi

echo ""
# 推送（已配置访问令牌）
echo "推送到远程仓库（已配置访问令牌）..."
echo "正在推送，请稍候..."
PUSH_OUTPUT=$(git push -u origin "$CURRENT_BRANCH" 2>&1)
PUSH_EXIT_CODE=$?
echo "$PUSH_OUTPUT"

if [ $PUSH_EXIT_CODE -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "✓ 推送成功！"
    echo "=========================================="
    echo ""
    echo "仓库地址: $REPO_URL"
    if [ -d "Mytest" ]; then
        echo "提交目录: MyDataCheck/, Mytest/"
    else
        echo "提交目录: MyDataCheck/"
    fi
    echo "当前分支: $CURRENT_BRANCH"
    echo ""
    echo "查看远程仓库状态:"
    git remote -v | sed 's|://[^@]*@|://***:***@|g'
elif echo "$PUSH_OUTPUT" | grep -q "non-fast-forward"; then
    echo ""
    echo "=========================================="
    echo "⚠ 推送被拒绝：本地分支与远程分支有分歧"
    echo "=========================================="
    echo ""
    echo "检测到本地有未推送的提交，远程也有新提交"
    echo "由于 MyDataCheck 子模块结构差异，尝试强制推送..."
    echo ""
    
    # 尝试强制推送（覆盖远程）
    echo "执行强制推送（--force-with-lease，安全模式）..."
    FORCE_PUSH_OUTPUT=$(git push --force-with-lease origin "$CURRENT_BRANCH" 2>&1)
    FORCE_PUSH_EXIT=$?
    
    if [ $FORCE_PUSH_EXIT -eq 0 ]; then
        echo ""
        echo "=========================================="
        echo "✓ 强制推送成功！"
        echo "=========================================="
        echo ""
        echo "仓库地址: $REPO_URL"
        if [ -d "Mytest" ]; then
            echo "提交目录: MyDataCheck/, Mytest/"
        else
            echo "提交目录: MyDataCheck/"
        fi
        echo "当前分支: $CURRENT_BRANCH"
        echo ""
        echo "⚠ 注意：已覆盖远程分支的历史记录"
    else
        echo ""
        echo "=========================================="
        echo "⚠ 强制推送也失败"
        echo "=========================================="
        echo ""
        echo "输出: $FORCE_PUSH_OUTPUT"
        echo ""
        echo "建议手动处理："
        echo "1. 检查远程更改: git fetch origin"
        echo "2. 查看差异: git log HEAD..origin/$CURRENT_BRANCH"
        echo "3. 手动合并或强制推送: git push -f origin $CURRENT_BRANCH"
        exit 1
    fi
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
