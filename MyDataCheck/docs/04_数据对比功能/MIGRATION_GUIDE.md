# 多列主键迁移指南

## 概述

本指南帮助你从单列主键配置迁移到多列主键配置。

## 是否需要迁移？

### 无需迁移的情况
- ✅ 当前使用单列作为主键，且满足业务需求
- ✅ 主键值在文件中唯一

### 需要迁移的情况
- ❌ 单列主键值不唯一，需要多列组合才能唯一标识
- ❌ 业务需求变更，需要使用多列作为主键

## 迁移步骤

### 步骤1：备份当前配置

```bash
cp data_comparison/config.json data_comparison/config.json.backup
```

### 步骤2：确定主键列

分析你的数据文件，确定需要哪些列组合作为主键。

**示例数据**：
```
user_id | date       | product_id | feature1 | feature2
--------|------------|------------|----------|----------
U001    | 2026-03-01 | P001       | 100      | 200
U001    | 2026-03-02 | P001       | 110      | 210
U001    | 2026-03-01 | P002       | 120      | 220
```

在这个例子中：
- 单独使用 `user_id` 不唯一
- 需要使用 `user_id + date + product_id` 组合才能唯一标识

### 步骤3：修改配置文件

**原配置（单列主键）**：
```json
{
  "scenarios": [
    {
      "name": "用户特征对比",
      "enabled": true,
      "sql_file": "user_features.csv",
      "api_file": "user_features_api.csv",
      "sql_key_column": 0,
      "api_key_column": 0,
      "sql_feature_start": 1,
      "api_feature_start": 1,
      "convert_feature_to_number": true,
      "output_prefix": "user_compare"
    }
  ]
}
```

**新配置（多列主键）**：
```json
{
  "scenarios": [
    {
      "name": "用户特征对比",
      "enabled": true,
      "sql_file": "user_features.csv",
      "api_file": "user_features_api.csv",
      "sql_key_column": [0, 1, 2],
      "api_key_column": [0, 1, 2],
      "sql_feature_start": 3,
      "api_feature_start": 3,
      "convert_feature_to_number": true,
      "output_prefix": "user_compare"
    }
  ]
}
```

**关键变更**：
1. `sql_key_column`: `0` → `[0, 1, 2]`
2. `api_key_column`: `0` → `[0, 1, 2]`
3. `sql_feature_start`: `1` → `3`
4. `api_feature_start`: `1` → `3`

### 步骤4：验证配置

运行测试确保配置正确：

```bash
cd data_comparison
python execute_data_comparison.py
```

### 步骤5：检查输出

查看输出文件，确认主键值格式正确：
- 单列主键：`U001`
- 多列主键：`U001||2026-03-01||P001`

## 常见迁移场景

### 场景1：从单列迁移到双列

**数据结构**：
```
user_id | date | feature1 | feature2
```

**配置变更**：
```json
// 原配置
"sql_key_column": 0,
"sql_feature_start": 1

// 新配置
"sql_key_column": [0, 1],
"sql_feature_start": 2
```

### 场景2：从单列迁移到三列

**数据结构**：
```
user_id | date | product_id | feature1 | feature2
```

**配置变更**：
```json
// 原配置
"sql_key_column": 0,
"sql_feature_start": 1

// 新配置
"sql_key_column": [0, 1, 2],
"sql_feature_start": 3
```

### 场景3：不连续的列作为主键

**数据结构**：
```
user_id | name | date | product_id | feature1
```

如果需要使用 `user_id` (列0) 和 `date` (列2) 作为主键：

```json
"sql_key_column": [0, 2],
"sql_feature_start": 1  // 特征从name列开始
```

## 迁移检查清单

- [ ] 备份原配置文件
- [ ] 确定主键列组合
- [ ] 更新 `sql_key_column` 为数组格式
- [ ] 更新 `api_key_column` 为数组格式
- [ ] 调整 `sql_feature_start` 位置
- [ ] 调整 `api_feature_start` 位置
- [ ] 运行测试验证
- [ ] 检查输出文件格式
- [ ] 验证对比结果正确性

## 回滚方案

如果迁移后出现问题，可以快速回滚：

```bash
# 恢复备份配置
cp data_comparison/config.json.backup data_comparison/config.json

# 重新运行对比
cd data_comparison
python execute_data_comparison.py
```

## 常见问题

### Q1: 迁移后主键值显示为 `A||B||C`，这正常吗？
A: 是的，多列主键使用 `||` 分隔符组合显示，这是正常的。

### Q2: 可以只修改一个文件的主键列吗？
A: 不可以，`sql_key_column` 和 `api_key_column` 必须保持相同的列数。

### Q3: 迁移后性能会下降吗？
A: 不会，多列主键不影响对比性能。

### Q4: 原有的输出文件还能用吗？
A: 可以，输出文件格式保持兼容，只是主键值的显示格式不同。

### Q5: 如何验证主键配置是否正确？
A: 运行 `python test_multi_key.py` 进行基础验证，然后用小数据集测试完整流程。

## 获取帮助

- 查看 [多列主键快速参考](MULTI_KEY_QUICK_REFERENCE.md)
- 查看 [多列主键详细说明](MULTI_KEY_UPDATE.md)
- 查看 [配置指南](CONFIG_GUIDE.md)

---
**更新日期**: 2026-03-05
