#!/bin/bash
# CDC分批输出 - 快速检查脚本

echo "=================================="
echo "CDC分批输出 - 快速检查"
echo "=================================="
echo ""

cd "$(dirname "$0")/../.." || exit

# 检查输出目录
if [ ! -d "outputs" ]; then
    echo "❌ outputs 目录不存在"
    echo "   请先运行板块衍生脚本"
    exit 1
fi

echo "📁 输出目录: outputs/"
echo ""

# 检查第一板块
echo "第一板块 (cdc1_features):"
cdc1_count=$(ls outputs/cdc1_features_batch*.csv 2>/dev/null | wc -l)
if [ "$cdc1_count" -gt 0 ]; then
    echo "  ✅ 找到 $cdc1_count 个批次文件"
    ls -lh outputs/cdc1_features_batch*.csv | head -3
    if [ "$cdc1_count" -gt 3 ]; then
        echo "  ... (共 $cdc1_count 个文件)"
    fi
else
    echo "  ⏳ 未找到批次文件"
fi
echo ""

# 检查第二板块
echo "第二板块 (cdc2_features):"
cdc2_count=$(ls outputs/cdc2_features_batch*.csv 2>/dev/null | wc -l)
if [ "$cdc2_count" -gt 0 ]; then
    echo "  ✅ 找到 $cdc2_count 个批次文件"
    ls -lh outputs/cdc2_features_batch*.csv | head -3
    if [ "$cdc2_count" -gt 3 ]; then
        echo "  ... (共 $cdc2_count 个文件)"
    fi
else
    echo "  ⏳ 未找到批次文件"
fi
echo ""

# 检查第三板块
echo "第三板块 (cdc3_features):"
cdc3_count=$(ls outputs/cdc3_features_batch*.csv 2>/dev/null | wc -l)
if [ "$cdc3_count" -gt 0 ]; then
    echo "  ✅ 找到 $cdc3_count 个批次文件"
    ls -lh outputs/cdc3_features_batch*.csv | head -3
    if [ "$cdc3_count" -gt 3 ]; then
        echo "  ... (共 $cdc3_count 个文件)"
    fi
else
    echo "  ⏳ 未找到批次文件"
fi
echo ""

# 检查BOSS板块
echo "BOSS板块 (cdcboss_features):"
boss_count=$(ls outputs/cdcboss_features_batch*.csv 2>/dev/null | wc -l)
if [ "$boss_count" -gt 0 ]; then
    echo "  ✅ 找到 $boss_count 个批次文件"
    ls -lh outputs/cdcboss_features_batch*.csv | head -3
    if [ "$boss_count" -gt 3 ]; then
        echo "  ... (共 $boss_count 个文件)"
    fi
else
    echo "  ⏳ 未找到批次文件"
fi
echo ""

# 总结
echo "=================================="
echo "总结"
echo "=================================="
total_count=$((cdc1_count + cdc2_count + cdc3_count + boss_count))
echo "总批次文件数: $total_count"
echo ""

if [ "$total_count" -gt 0 ]; then
    echo "✅ 分批输出功能正常工作"
    echo ""
    echo "详细验证请运行:"
    echo "  python scripts/verify_scripts/verify_batch_output.py --all"
else
    echo "⏳ 尚未生成批次文件"
    echo ""
    echo "请在 Jupyter 中运行板块衍生脚本"
fi
echo ""
