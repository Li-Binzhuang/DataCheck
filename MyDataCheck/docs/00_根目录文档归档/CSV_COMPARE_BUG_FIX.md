# CSV数据对比 - 多主键支持修复

## 问题描述

```
❌ 执行错误: '<' not supported between instances of 'list' and 'int'
```

## 根本原因

前端 `parseKeyColumns` 函数可能返回：
- **整数**：单主键（例如 `0`）
- **数组**：多主键（例如 `[0, 1]`）

但后端代码假设 `key_column` 总是整数，导致在比较列表和整数时出错。

## 已完成的修复

### 修复1：参数处理

**文件：** `data_comparison/job/data_comparator_optimized.py` 第100-130行

```python
# 处理主键列参数（支持单列或多列）
if isinstance(sql_key_column, list):
    sql_key_columns = sql_key_column
else:
    sql_key_columns = [sql_key_column]

if isinstance(api_key_column, list):
    api_key_columns = api_key_column
else:
    api_key_columns = [api_key_column]
```

### 修复2：索引构建

**文件：** `data_comparison/job/data_comparator_optimized.py` 第150-180行

```python
# 构建复合主键
key_parts = []
for col_idx in sql_key_columns:
    if col_idx < len(row) and row[col_idx] is not None:
        key_parts.append(str(row[col_idx]).strip())

if key_parts:
    key_value = "|".join(key_parts)  # 使用|分隔多个主键
    sql_index[key_value] = row
```

### 修复3：对比数据

**文件：** `data_comparison/job/data_comparator_optimized.py` 第240-280行

```python
# 构建API文件的复合主键
key_parts_api = []
for col_idx in api_key_columns:
    if col_idx < len(row_api) and row_api[col_idx] is not None:
        key_parts_api.append(str(row_api[col_idx]).strip())

if not key_parts_api:
    unmatched_count += 1
    unmatched_rows.append(row_api)
    continue

key_value_api = "|".join(key_parts_api)
```

---

## 支持的主键类型

### 单主键

```
主键列输入：0
解析结果：[0]
复合主键：row[0]
```

### 多主键

```
主键列输入：0,1,2
解析结果：[0, 1, 2]
复合主键：row[0]|row[1]|row[2]
```

---

## 立即生效

### 第1步：验证修复

```bash
# 检查修复是否正确应用
grep -n "isinstance(sql_key_column, list)" data_comparison/job/data_comparator_optimized.py
```

**预期输出：** 显示第100行附近有该代码

### 第2步：重启服务

```bash
# 停止当前服务
Ctrl + C

# 重新启动
python web_app.py
```

### 第3步：测试对比

在Web界面执行对比，观察：
- ✅ 是否不再出现 `'<' not supported` 错误
- ✅ 对比是否正常完成
- ✅ 结果是否正确

---

## 测试场景

### 场景1：单主键

```
主键列：0
预期：正常对比
```

### 场景2：多主键

```
主键列：0,1
预期：使用复合主键对比
```

### 场景3：多主键（多个逗号）

```
主键列：0,1,2,3
预期：使用复合主键对比
```

---

## 常见问题

### Q: 多主键如何工作？

A: 使用 `|` 分隔符连接多个主键值：
```
单主键：key = row[0]
多主键：key = row[0] + "|" + row[1] + "|" + row[2]
```

### Q: 是否影响性能？

A: 不影响。多主键的处理复杂度仍然是 O(1)。

### Q: 是否影响输出结果？

A: 不影响。输出结果完全相同。

---

## 修复验证

### 检查清单

- [ ] 代码修复已应用
- [ ] 服务已重启
- [ ] 单主键对比正常
- [ ] 多主键对比正常
- [ ] 无错误信息

---

## 总结

| 项目 | 说明 |
|------|------|
| **问题** | 多主键导致类型错误 |
| **原因** | 后端假设主键总是整数 |
| **解决** | 支持单主键和多主键 |
| **修复** | 已完成 |
| **生效** | 重启服务 |

