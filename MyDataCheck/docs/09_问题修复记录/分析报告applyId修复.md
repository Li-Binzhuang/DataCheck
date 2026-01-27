# 分析报告 applyId 修复

## 问题描述

在流式对比模式下，生成的 `_analysis_report.csv` 文件存在以下问题：
1. **applyId 列为空**：无法识别是哪个申请的数据
2. **baseTime 列冗余**：与 request_time 相同，没有必要

## 修复内容

### 1. 优化 applyId 获取逻辑

**修复前**：
- 只从 CSV 列中查找 `use_credit_apply_id` 等字段
- 如果 CSV 中没有这些列，applyId 就为空

**修复后**：
- **优先级1**：从接口入参中获取（`applyId` 或 `apply_id`）
- **优先级2**：从 CSV 列中查找（`apply_id`, `applyId`, `use_credit_id` 等）
- **优先级3**：使用 `custNo` 作为备选

**代码实现**：
```python
# 优先从接口入参中获取 applyId
apply_id = original_values.get("applyId", original_values.get("apply_id", ""))

# 如果接口入参中没有，尝试从 CSV 列中查找
if not apply_id:
    apply_id_fields = ['apply_id', 'applyId', 'use_credit_id', 'use_credit_apply_id', 'loan_no', 'ua_id', 'ua_no']
    for field_name in apply_id_fields:
        for i, header in enumerate(headers):
            if header.lower() == field_name.lower() and i < len(row):
                apply_id = row[i].strip()
                break
        if apply_id:
            break

# 如果还是没有，使用 custNo
if not apply_id:
    apply_id = cust_no
```

### 2. 去掉 baseTime 列

**修复前的格式**：
```csv
特征名,applyId,request_time,baseTime,CSV值,API值
feature1,1073458287442403329,2025-01-27T10:00:00.000,2025-01-27T10:00:00.000,0.5,0.6
```

**修复后的格式**：
```csv
特征名,applyId,request_time,CSV值,API值
feature1,1073458287442403329,2025-01-27T10:00:00.000,0.5,0.6
```

**原因**：
- baseTime 与 request_time 完全相同
- 冗余列增加文件大小
- 不利于数据分析

## 修复效果

### 修复前
```csv
特征名,applyId,request_time,baseTime,CSV值,API值
cdc1_m3_max_dpd_amt,,2025-01-27T10:00:00.000,2025-01-27T10:00:00.000,0.5,0.6
cdc1_m3_avg_dpd_amt,,2025-01-27T10:00:00.000,2025-01-27T10:00:00.000,1.2,1.3
```
❌ applyId 为空  
❌ baseTime 冗余

### 修复后
```csv
特征名,applyId,request_time,CSV值,API值
cdc1_m3_max_dpd_amt,1073458287442403329,2025-01-27T10:00:00.000,0.5,0.6
cdc1_m3_avg_dpd_amt,1073458287442403329,2025-01-27T10:00:00.000,1.2,1.3
```
✅ applyId 有值（从接口入参获取）  
✅ 去掉冗余的 baseTime 列  
✅ 文件更简洁，易于分析

## applyId 获取优先级

### 优先级说明

| 优先级 | 来源 | 字段名 | 说明 |
|--------|------|--------|------|
| 1 | 接口入参 | `applyId`, `apply_id` | 最可靠，来自实际请求参数 |
| 2 | CSV 列 | `apply_id`, `applyId`, `use_credit_id`, `use_credit_apply_id`, `loan_no`, `ua_id`, `ua_no` | 从原始数据中查找 |
| 3 | 备选 | `custNo` | 如果都没有，使用客户号 |

### 示例场景

**场景1：接口入参有 applyId**
```python
# 配置
"api_params": [
    {"param_name": "applyId", "column_index": 0}
]

# 结果：applyId = "1073458287442403329"（从接口入参获取）
```

**场景2：接口入参没有，CSV 有 apply_id 列**
```python
# 配置
"api_params": [
    {"param_name": "custNo", "column_index": 0}
]

# CSV 表头：custNo, apply_id, baseTime, ...
# 结果：applyId = "1073458287442403329"（从 CSV 的 apply_id 列获取）
```

**场景3：都没有，使用 custNo**
```python
# 配置
"api_params": [
    {"param_name": "custNo", "column_index": 0}
]

# CSV 表头：custNo, baseTime, feature1, ...（没有 apply_id 列）
# 结果：applyId = "123456"（使用 custNo）
```

## 使用建议

### 1. 推荐配置

在接口参数配置中明确指定 `applyId`：

```json
{
  "api_params": [
    {
      "param_name": "applyId",
      "column_index": 0,
      "is_time_field": false
    },
    {
      "param_name": "baseTime",
      "column_index": 1,
      "is_time_field": true
    }
  ]
}
```

### 2. CSV 文件准备

如果接口参数中没有 applyId，确保 CSV 文件包含以下列之一：
- `apply_id`
- `applyId`
- `use_credit_id`
- `use_credit_apply_id`

### 3. 验证方法

执行对比后，检查生成的 `_analysis_report.csv`：
```bash
# 查看前几行
head -n 5 bz_new3_01272118_compare_analysis_report.csv

# 检查 applyId 列是否有值
cut -d',' -f2 bz_new3_01272118_compare_analysis_report.csv | head -n 10
```

## 修改文件

- `MyDataCheck/api_comparison/job/streaming_comparator.py`
  - 修改 `_compare_single_row` 方法：优化 applyId 获取逻辑
  - 修改 `streaming_compare` 方法：去掉 baseTime 列

## 相关文档

- [分析报告格式优化](../04_数据对比功能/分析报告格式优化.md)
- [流式对比模式实现说明](../04_数据对比功能/流式对比模式实现说明.md)

---

**修复日期**：2025-01-27  
**修复人员**：Kiro AI Assistant
