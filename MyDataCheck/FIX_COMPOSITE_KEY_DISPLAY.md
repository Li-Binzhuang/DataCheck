# 修复：组合主键在差异明细中的显示

## 问题描述

当使用组合主键（如 `cust_no + create_time`）进行数据对比时，输出的差异数据明细文件存在以下问题：

1. **主键显示问题**：只显示一列合并后的主键值（如 `"value1||value2"`），而不是分别显示两列
2. **可读性差**：用户无法直观看到每个主键的值

## 期望行为

差异数据明细文件应该：
- 分别显示每个主键列（如 `cust_no` 和 `create_time`）
- 每个主键值单独一列，便于查看和筛选

## 解决方案

### 修改的文件

1. **MyDataCheck/data_comparison/job/data_comparator.py**
   - 在差异数据中分别保存每个主键的值
   - 在返回结果中添加 `key_column_names` 字段

2. **MyDataCheck/data_comparison/job/report_generator.py**
   - 更新差异明细表头，分别显示每个主键列
   - 更新数据行，分别输出每个主键值

### 修改详情

#### 1. data_comparator.py

**存储主键值**:
```python
# 获取主键值（分别保存每个主键的值）
key_values = []
for idx in api_key_columns:
    if idx < len(row_api) and row_api[idx] is not None:
        key_values.append(str(row_api[idx]).strip())
    else:
        key_values.append("")
```

**存储差异数据**:
```python
differences_dict[(key_value, feature_name)] = (
    api_value, sql_value, cust_no, time_value, key_values
)
```

**返回结果**:
```python
"key_column_names": [headers_api[idx] for idx in api_key_columns]
```

#### 2. report_generator.py

**表头**:
```python
header = list(key_column_names) + [
    time_column_name, 'cust_no', '特征名', 
    '接口/灰度/从库值', '模型特征样本值'
]
```

**数据行**:
```python
row_data = list(key_values[:len(key_column_names)]) + [
    time_value, cust_no, feature, api_value, sql_value
]
```

## 效果对比

### 修复前

| 主键值 | 时间 | cust_no | 特征名 | 接口值 | 模型值 |
|--------|------|---------|--------|--------|--------|
| value1\|\|value2 | ... | ... | ... | ... | ... |

### 修复后

| cust_no | create_time | 时间 | cust_no | 特征名 | 接口值 | 模型值 |
|---------|-------------|------|---------|--------|--------|--------|
| value1 | value2 | ... | ... | ... | ... | ... |

## 向后兼容性

✅ **完全向后兼容**

- 支持单主键和组合主键
- 兼容旧格式的差异数据
- 现有配置不需要修改

## 测试建议

1. 使用单主键测试
2. 使用组合主键（2个）测试
3. 使用组合主键（3个或更多）测试
4. 验证差异明细文件的列数和数据正确性

## 版本信息

- **修复版本**: 1.2
- **修复日期**: 2026-03-12
- **影响范围**: CSV 数据对比模块
- **向后兼容**: 是
