# 组合主键匹配问题 - 快速参考

## 问题
同一个特征在两条记录中的值混淆了（0 vs 366），报告无法区分不同的记录。

## 原因
1. 时间列查找 Bug：使用了错误的变量名
2. 报告表头不完整：没有显示完整的主键信息

## 修复
已在以下文件中修复：
- ✅ `data_comparison/job/data_comparator.py` (第 248-265 行)
- ✅ `data_comparison/job/report_generator.py` (第 113-155 行)

## 验证
```bash
# 检查修复是否应用
grep "max(api_key_columns)" data_comparison/job/data_comparator.py

# 运行对比
python data_comparison/execute_data_comparison.py

# 查看新报告的表头
head -1 "outputdata/data_comparison/[最新报告]_差异数据明细.csv"
```

## 预期结果
- 报告表头包含完整的主键列（如 `cust_no,create_time`）
- 每条记录都能正确区分
- 特征值正确对应到各自的记录

## 详细说明
见 `COMPOSITE_KEY_FIX_SUMMARY.md`
