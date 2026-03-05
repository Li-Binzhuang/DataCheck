# 多列主键快速参考

## 快速配置

### 单列主键（原有方式）
```json
{
  "sql_key_column": 0,
  "api_key_column": 0,
  "sql_feature_start": 1,
  "api_feature_start": 1
}
```

### 双列主键（A列+B列）
```json
{
  "sql_key_column": [0, 1],
  "api_key_column": [0, 1],
  "sql_feature_start": 2,
  "api_feature_start": 2
}
```

### 三列主键（A列+B列+C列）
```json
{
  "sql_key_column": [0, 1, 2],
  "api_key_column": [0, 1, 2],
  "sql_feature_start": 3,
  "api_feature_start": 3
}
```

## 列索引对照表

| 列名 | 索引 |
|------|------|
| A列  | 0    |
| B列  | 1    |
| C列  | 2    |
| D列  | 3    |
| E列  | 4    |
| ...  | ...  |

## 配置规则

1. **单列主键**：使用数字 `0`
2. **多列主键**：使用数组 `[0, 1]`
3. **特征起始**：必须在主键列之后
4. **列数一致**：sql和api的主键列数必须相同

## 示例场景

### 场景1：用户ID作为主键
```
文件结构：user_id | name | feature1 | feature2 | ...
配置：
  "sql_key_column": 0,
  "sql_feature_start": 2
```

### 场景2：用户ID+日期作为主键
```
文件结构：user_id | date | feature1 | feature2 | ...
配置：
  "sql_key_column": [0, 1],
  "sql_feature_start": 2
```

### 场景3：用户ID+产品ID+日期作为主键
```
文件结构：user_id | product_id | date | feature1 | feature2 | ...
配置：
  "sql_key_column": [0, 1, 2],
  "sql_feature_start": 3
```

## 输出示例

### 单列主键输出
```
主键值: ABC123
```

### 多列主键输出
```
主键值: ABC123||20260305
```
（使用 `||` 分隔多个主键值）

## 测试验证

运行测试脚本验证功能：
```bash
cd data_comparison
python test_multi_key.py
```

## 常见错误

### ❌ 错误1：主键列数不一致
```json
"sql_key_column": [0, 1],
"api_key_column": [0]  // 错误：列数不同
```

### ❌ 错误2：特征起始位置错误
```json
"sql_key_column": [0, 1],
"sql_feature_start": 1  // 错误：应该是2
```

### ✅ 正确配置
```json
"sql_key_column": [0, 1],
"api_key_column": [0, 1],
"sql_feature_start": 2,
"api_feature_start": 2
```

## 完整配置示例

参考文件：
- `config_example_multi_key.json` - 多种主键配置示例
- `MULTI_KEY_UPDATE.md` - 详细更新说明
- `CONFIG_GUIDE.md` - 完整配置指南

---
**更新时间**：2026-03-05
