#!/bin/bash
# 从远程仓库拉取代码到本地
# MyDataCheck <- zlfjob.git
# MyTool <- MyTool.git
# Project <- Project.git
#
# 用法:
#   ./git_restore.sh                    # 交互式选择
#   ./git_restore.sh MyDataCheck        # 拉取 MyDataCheck（交互选模式）
#   ./git_restore.sh MyTool --force     # 直接覆盖本地 MyTool
#   ./git_restore.sh Project --backup   # 先备份再拉取 Project
#   ./git_restore.sh --force            # 覆盖全部
#   ./git_restore.sh --backup           # 备份后拉取全部

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

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK_DIR="$SCRIPT_DIR/.git_restore_tmp"

# 修复 macOS SSL
if [ "$(uname)" = "Darwin" ]; then
    git config --global http.sslVerify false 2>/dev/null || true
fi

# 解析参数
TARGETS=""
MODE=""

for arg in "$@"; do
    case "$arg" in
        --force)  MODE="force" ;;
        --backup) MODE="backup" ;;
        *)
            repo=$(get_repo_name "$arg")
            if [ -z "$repo" ]; then
                echo "❌ 无效参数: $arg"
                echo "   项目名: MyDataCheck, MyTool, Project"
                echo "   模式:   --force (覆盖), --backup (备份后拉取)"
                exit 1
            fi
            TARGETS="$TARGETS $arg"
            ;;
    esac
done

# 没指定项目则交互选择
if [ -z "$TARGETS" ]; then
    echo "请选择要恢复的项目："
    echo "1) MyDataCheck"
    echo "2) MyTool"
    echo "3) Project"
    echo "4) 全部"
    echo "5) 取消"
    read -p "选项 (1-5): " choice
    case $choice in
        1) TARGETS="MyDataCheck" ;;
        2) TARGETS="MyTool" ;;
        3) TARGETS="Project" ;;
        4) TARGETS="MyDataCheck MyTool Project" ;;
        *) echo "操作已取消"; exit 0 ;;
    esac
fi

# 没指定模式则交互选择
if [ -z "$MODE" ]; then
    echo ""
    echo "请选择恢复方式："
    echo "1) 覆盖本地（放弃本地修改）"
    echo "2) 先备份再拉取"
    echo "3) 取消"
    read -p "选项 (1-3): " mode_choice
    case $mode_choice in
        1) MODE="force" ;;
        2) MODE="backup" ;;
        *) echo "操作已取消"; exit 0 ;;
    esac
fi

echo ""
echo "=========================================="
echo "拉取远程代码"
echo "=========================================="
echo "目标: $TARGETS"
echo "模式: $MODE"
echo ""

# 覆盖模式需要确认
if [ "$MODE" = "force" ]; then
    echo "⚠️  将覆盖以下目录:"
    for t in $TARGETS; do echo "    $SCRIPT_DIR/$t/"; done
    echo "  以及根目录脚本文件"
    read -p "确认？(y/n): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "操作已取消"
        exit 0
    fi
fi

# 恢复根目录文件
restore_root_files() {
    local src="$1"
    echo "  同步根目录脚本文件..."
    for f in "$src"/*; do
        fname="$(basename "$f")"
        [ -d "$f" ] && continue
        case "$fname" in .DS_Store|*.tmp|*.bak) continue ;; esac
        cp "$f" "$SCRIPT_DIR/$fname"
        echo "    ✓ $fname"
    done
    if [ -f "$src/.gitignore" ]; then
        cp "$src/.gitignore" "$SCRIPT_DIR/.gitignore"
        echo "    ✓ .gitignore"
    fi
}

for DIR_NAME in $TARGETS; do
    REPO_NAME=$(get_repo_name "$DIR_NAME")
    REPO_URL="https://${GIT_USERNAME}:${GIT_TOKEN}@${BASE}/${REPO_NAME}.git"
    DISPLAY_URL="https://${BASE}/${REPO_NAME}.git"
    TMP_DIR="$WORK_DIR/$DIR_NAME"

    echo "=========================================="
    echo "[$DIR_NAME] <- $DISPLAY_URL"
    echo "=========================================="

    rm -rf "$TMP_DIR"
    echo "  拉取远程仓库..."
    if ! git clone "$REPO_URL" "$TMP_DIR" 2>/dev/null; then
        echo "  ✗ 拉取失败"
        continue
    fi

    if [ ! -d "$TMP_DIR/$DIR_NAME" ]; then
        echo "  ⚠ 远程仓库中没有 $DIR_NAME/ 目录"
        continue
    fi

    # 备份模式：先备份本地
    if [ "$MODE" = "backup" ] && [ -d "$SCRIPT_DIR/$DIR_NAME" ]; then
        BACKUP_DIR="$SCRIPT_DIR/.git_backup_$(date '+%Y%m%d_%H%M%S')"
        echo "  备份本地 $DIR_NAME/ ..."
        mkdir -p "$BACKUP_DIR"
        cp -R "$SCRIPT_DIR/$DIR_NAME" "$BACKUP_DIR/"
        echo "  ✓ 已备份到 $BACKUP_DIR/$DIR_NAME"
    fi

    # 用远程版本替换本地
    echo "  更新本地 $DIR_NAME/ ..."
    rm -rf "$SCRIPT_DIR/$DIR_NAME"
    cp -R "$TMP_DIR/$DIR_NAME" "$SCRIPT_DIR/$DIR_NAME"
    echo "  ✓ $DIR_NAME/ 已更新"

    restore_root_files "$TMP_DIR"
    echo ""
done

rm -rf "$WORK_DIR"

echo "=========================================="
echo "✅ 拉取完成"
echo "=========================================="
if [ "$MODE" = "backup" ]; then
    echo "💾 备份目录: $SCRIPT_DIR/.git_backup_*/"
    echo "   确认无误后可手动删除"
fi
