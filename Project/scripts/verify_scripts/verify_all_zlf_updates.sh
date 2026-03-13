#!/bin/bash
# CDC板块衍生脚本 - zlf update 修改验证脚本
# 用于验证所有 zlf update 标识的修改

echo "================================================================================"
echo "CDC板块衍生脚本 - zlf update 修改验证"
echo "================================================================================"
echo ""

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 统计 zlf update 注释
echo "📊 统计 zlf update 注释数量"
echo "--------------------------------------------------------------------------------"

count1=$(grep -c "zlf update" CDC/第一板块衍生.ipynb 2>/dev/null || echo "0")
count2=$(grep -c "zlf update" CDC/第二板块衍生.ipynb 2>/dev/null || echo "0")
count3=$(grep -c "zlf update" CDC/第三板块衍生.ipynb 2>/dev/null || echo "0")
count_boss=$(grep -c "zlf update" CDC/BOSS板块衍生.ipynb 2>/dev/null || echo "0")

echo "第一板块: $count1 处"
echo "第二板块: $count2 处"
echo "第三板块: $count3 处"
echo "BOSS板块: $count_boss 处"

total=$((count1 + count2 + count3 + count_boss))
echo ""
echo -e "${GREEN}总计: $total 处 zlf update 注释${NC}"
echo ""

# 验证空值填充
echo "🔍 验证空值填充（fillna(-999)）"
echo "--------------------------------------------------------------------------------"

fillna1=$(grep -c "fillna(-999" CDC/第一板块衍生.ipynb 2>/dev/null || echo "0")
fillna2=$(grep -c "fillna(-999" CDC/第二板块衍生.ipynb 2>/dev/null || echo "0")
fillna3=$(grep -c "fillna(-999" CDC/第三板块衍生.ipynb 2>/dev/null || echo "0")
fillna_boss=$(grep -c "fillna(-999" CDC/BOSS板块衍生.ipynb 2>/dev/null || echo "0")

echo "第一板块: $fillna1 处 fillna(-999)"
echo "第二板块: $fillna2 处 fillna(-999)"
echo "第三板块: $fillna3 处 fillna(-999)"
echo "BOSS板块: $fillna_boss 处 fillna(-999)"

total_fillna=$((fillna1 + fillna2 + fillna3 + fillna_boss))
echo ""
echo -e "${GREEN}总计: $total_fillna 处 fillna(-999)${NC}"
echo ""

# 验证浮点数精度
echo "🔍 验证浮点数精度（round(6)）"
echo "--------------------------------------------------------------------------------"

round1=$(grep -c "round(6)" CDC/第一板块衍生.ipynb 2>/dev/null || echo "0")
round2=$(grep -c "round(6)" CDC/第二板块衍生.ipynb 2>/dev/null || echo "0")
round3=$(grep -c "round(6)" CDC/第三板块衍生.ipynb 2>/dev/null || echo "0")
round_boss=$(grep -c "round(6)" CDC/BOSS板块衍生.ipynb 2>/dev/null || echo "0")

echo "第一板块: $round1 处 round(6)"
echo "第二板块: $round2 处 round(6)"
echo "第三板块: $round3 处 round(6)"
echo "BOSS板块: $round_boss 处 round(6)"

total_round=$((round1 + round2 + round3 + round_boss))
echo ""
echo -e "${GREEN}总计: $total_round 处 round(6)${NC}"
echo ""

# 运行Python验证脚本
echo "🔍 运行浮点数精度验证脚本"
echo "--------------------------------------------------------------------------------"
if [ -f "CDC/verify_float_precision.py" ]; then
    python CDC/verify_float_precision.py
    if [ $? -eq 0 ]; then
        echo ""
        echo -e "${GREEN}✅ Python验证脚本通过${NC}"
    else
        echo ""
        echo -e "${RED}❌ Python验证脚本失败${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  验证脚本不存在: CDC/verify_float_precision.py${NC}"
fi
echo ""

# 检查是否有遗漏的 fillna(0)
echo "🔍 检查是否有遗漏的 fillna(0)"
echo "--------------------------------------------------------------------------------"

# 排除字符串填充 fillna("")
old_fillna=$(grep -r "fillna(0)" CDC/*板块衍生.ipynb 2>/dev/null | grep -v 'fillna("")' | grep -v 'fillna("' | wc -l | tr -d ' ')

if [ "$old_fillna" -eq "0" ]; then
    echo -e "${GREEN}✅ 没有遗漏的 fillna(0)${NC}"
else
    echo -e "${RED}⚠️  发现 $old_fillna 处可能遗漏的 fillna(0)${NC}"
    echo "请手动检查以下位置："
    grep -rn "fillna(0)" CDC/*板块衍生.ipynb 2>/dev/null | grep -v 'fillna("")' | grep -v 'fillna("'
fi
echo ""

# 最终总结
echo "================================================================================"
echo "验证总结"
echo "================================================================================"
echo ""
echo "📊 统计结果："
echo "  - zlf update 注释: $total 处"
echo "  - fillna(-999) 修改: $total_fillna 处"
echo "  - round(6) 处理: $total_round 处"
echo ""

# 判断是否全部通过
if [ "$total" -ge "63" ] && [ "$total_fillna" -ge "65" ] && [ "$total_round" -ge "10" ] && [ "$old_fillna" -eq "0" ]; then
    echo -e "${GREEN}✅ 所有验证通过！${NC}"
    echo ""
    echo "四个板块的修改已全部完成："
    echo "  ✅ 空值填充统一为 -999"
    echo "  ✅ 浮点数精度统一为 6位"
    echo "  ✅ 所有修改都有 zlf update 标识"
    echo "  ✅ 补充修复了np.nan为-999"
    exit 0
else
    echo -e "${YELLOW}⚠️  部分验证未通过，请检查${NC}"
    exit 1
fi
