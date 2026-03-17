#!/bin/bash
# 将项目推送到对应的 Git 仓库（增量提交，保留历史）
# MyDataCheck -> zlfjob.git
# MyTool -> MyTool.git
# Project -> Project.git
# 根目录脚本文件会同步到每个仓库
#
# 用法:
#   ./git_push.sh              # 推送全部三个仓库
#   ./git_push.sh MyDataCheck  # 只推送 MyDataCheck
#   ./git_push.sh MyTool       # 只推送 MyTool
#   ./git_push.sh Project      # 只推送 Project
#
# 日志:
#   cat git_push.log           # 查看推送历史

set -e

# 访问凭据
GIT_USERNAME="zhanglifeng703"
GIT_TOKEN="zhang0324"
BASE="codeup.aliyun.com/674eeae32855ba207e1c86c8/daizhonhuankuan_part1"

# 目录名 -> 远程仓库名（兼容 bash 3.x）
get_repo_name() {
    case "$1" in
        MyDataCheck) echo "zlfjob" ;;
        MyTool)      echo "MyTool" ;;
        Project)     echo "Project" ;;
        *)           echo "" ;;
    esac
}

# 解析参数
if [ $# -eq 0 ]; then
    TARGETS="MyDataCheck MyTool Project"
else
    TARGETS=""
    for arg in "$@"; do
        repo=$(get_repo_name "$arg")
        if [ -z "$repo" ]; then
            echo "❌ 无效的项目名: $arg"
            echo "   可选: MyDataCheck, MyTool, Project"
            exit 1
        fi
        TARGETS="$TARGETS $arg"
    done
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK_DIR="$SCRIPT_DIR/.git_push_tmp"
LOG_FILE="$SCRIPT_DIR/git_push.log"

# 同时输出到终端和日志文件
log() {
    echo "$@" | tee -a "$LOG_FILE"
}

# 写入本次推送的分隔线
echo "" >> "$LOG_FILE"
log "================================================================"
log "推送时间: $(date '+%Y-%m-%d %H:%M:%S')"
log "推送目标: $TARGETS"
log "================================================================"

# 修复 macOS SSL
if [ "$(uname)" = "Darwin" ]; then
    git config --global http.sslVerify false 2>/dev/null || true
fi

# 收集根目录需要同步的文件
collect_root_files() {
    local dest="$1"
    for f in "$SCRIPT_DIR"/.gitignore "$SCRIPT_DIR"/*.sh "$SCRIPT_DIR"/*.md "$SCRIPT_DIR"/*.txt; do
        [ -f "$f" ] || continue
        fname="$(basename "$f")"
        case "$fname" in
            *.tmp|*.bak|*~|"git_push copy.sh") continue ;;
        esac
        cp "$f" "$dest/$fname"
    done
}

SUCCESS_COUNT=0
FAIL_COUNT=0
FAIL_LIST=""
SKIP_CLEANUP=0

for DIR_NAME in $TARGETS; do
    REPO_NAME=$(get_repo_name "$DIR_NAME")
    REPO_URL="https://${GIT_USERNAME}:${GIT_TOKEN}@${BASE}/${REPO_NAME}.git"
    DISPLAY_URL="https://${BASE}/${REPO_NAME}.git"
    TMP_DIR="$WORK_DIR/$DIR_NAME"

    log "------------------------------------------"
    log "[$DIR_NAME] -> $DISPLAY_URL"
    log "------------------------------------------"

    if [ ! -d "$SCRIPT_DIR/$DIR_NAME" ]; then
        log "  ⚠ [$DIR_NAME] 目录不存在，跳过"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        FAIL_LIST="$FAIL_LIST $DIR_NAME(目录不存在)"
        continue
    fi

    rm -rf "$TMP_DIR"

    # clone 远程仓库
    log "  拉取远程仓库..."
    if ! git clone "$REPO_URL" "$TMP_DIR" 2>/dev/null; then
        log "  远程仓库为空，初始化新仓库..."
        mkdir -p "$TMP_DIR"
        (cd "$TMP_DIR" && git init -q && git checkout -b master 2>/dev/null || true)
    fi

    # 清空工作区（保留 .git）
    (cd "$TMP_DIR" && find . -maxdepth 1 ! -name '.' ! -name '.git' -exec rm -rf {} +)

    # 复制项目目录
    cp -R "$SCRIPT_DIR/$DIR_NAME" "$TMP_DIR/$DIR_NAME"
    rm -rf "$TMP_DIR/$DIR_NAME/.git"

    # 复制根目录脚本
    collect_root_files "$TMP_DIR"

    # 清理不需要的文件
    find "$TMP_DIR" -name ".DS_Store" -delete 2>/dev/null || true
    find "$TMP_DIR" -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
    find "$TMP_DIR" -name "*.pyc" -delete 2>/dev/null || true
    find "$TMP_DIR" -name ".venv" -type d -exec rm -rf {} + 2>/dev/null || true
    find "$TMP_DIR" -name ".idea" -type d -exec rm -rf {} + 2>/dev/null || true
    find "$TMP_DIR" -name ".vscode" -type d -exec rm -rf {} + 2>/dev/null || true
    find "$TMP_DIR" -name ".kiro" -type d -exec rm -rf {} + 2>/dev/null || true

    # 进入临时目录提交并推送
    pushd "$TMP_DIR" > /dev/null
    git add -A

    if git diff --staged --quiet 2>/dev/null; then
        log "  ✓ [$DIR_NAME] 无变更，跳过"
        popd > /dev/null
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        continue
    fi

    CHANGED_FILES=$(git diff --staged --stat | tail -1)
    log "  [$DIR_NAME] 变更: $CHANGED_FILES"
    git commit -q -m "feat: 更新 $DIR_NAME 项目

- 包含 $DIR_NAME 项目文件
- 包含根目录脚本文件
- 提交时间: $(date '+%Y-%m-%d %H:%M:%S')"
    log "  ✓ [$DIR_NAME] 已提交"

    git remote set-url origin "$REPO_URL" 2>/dev/null || git remote add origin "$REPO_URL"
    CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "master")

    # 合并远程代码
    if git ls-remote --heads origin "$CURRENT_BRANCH" 2>/dev/null | grep -q "$CURRENT_BRANCH"; then
        PULL_OUTPUT=$(git pull --rebase origin "$CURRENT_BRANCH" 2>&1)
        PULL_EXIT=$?
        if [ $PULL_EXIT -ne 0 ]; then
            git rebase --abort 2>/dev/null || true
            log "  ✗ [$DIR_NAME] 合并冲突，请手动处理"
            log "    $PULL_OUTPUT"
            log "    临时目录: $TMP_DIR"
            popd > /dev/null
            FAIL_COUNT=$((FAIL_COUNT + 1))
            FAIL_LIST="$FAIL_LIST $DIR_NAME(冲突)"
            SKIP_CLEANUP=1
            continue
        fi
        log "  ✓ [$DIR_NAME] 已合并远程代码"
    fi

    # 推送
    PUSH_OUTPUT=$(git push -u origin "$CURRENT_BRANCH" 2>&1)
    PUSH_EXIT=$?
    popd > /dev/null

    if [ $PUSH_EXIT -eq 0 ]; then
        log "  ✓ [$DIR_NAME] 推送成功"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        log "  ✗ [$DIR_NAME] 推送失败: $PUSH_OUTPUT"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        FAIL_LIST="$FAIL_LIST $DIR_NAME(推送失败)"
        SKIP_CLEANUP=1
    fi
done

# 清理临时目录
if [ $SKIP_CLEANUP -eq 0 ]; then
    rm -rf "$WORK_DIR"
else
    log "⚠ 临时目录已保留: $WORK_DIR"
fi

log "=========================================="
log "推送完成: 成功 $SUCCESS_COUNT, 失败 $FAIL_COUNT"
if [ $FAIL_COUNT -gt 0 ]; then
    log "失败项目:$FAIL_LIST"
fi
log "=========================================="
echo ""
echo "📋 查看推送日志: cat git_push.log"
