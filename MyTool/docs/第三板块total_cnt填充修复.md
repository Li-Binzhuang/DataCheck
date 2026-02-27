# 第三板块 total_cnt 特征填充修复

## 问题描述

在第三板块衍生.ipynb中，发现`creditos_{w}d_total_cnt`特征使用了错误的空值填充值。

### 问题代码

**文件**: `CDC/第三板块衍生.ipynb`  
**行号**: 610

```python
# 错误：cnt特征使用-999填充
total = sub.groupby("apply_id").size().reindex(base.index).fillna(-999).astype(int)
out[f"creditos_{w}d_total_cnt"] = total
```

### 问题分析

1. **特征名称**: `creditos_{w}d_total_cnt` - 明确是一个计数（cnt）特征
2. **错误填充**: 使用了`fillna(-999)`
3. **正确填充**: cnt特征应该使用`fillna(0)`

### 影响范围

**影响的特征**:
- `creditos_7d_total_cnt`
- `creditos_15d_total_cnt`
- `creditos_30d_total_cnt`
- `creditos_60d_total_cnt`
- `creditos_90d_total_cnt`
- `creditos_180d_total_cnt`
- `creditos_360d_total_cnt`
- `creditos_720d_total_cnt`

**影响说明**:
- 当某个apply_id在指定窗口期内没有creditos记录时
- 原来会填充-999（错误）
- 现在会填充0（正确）

## 修复方案

### 修复代码

```python
# 修复后：cnt特征使用0填充
total = sub.groupby("apply_id").size().reindex(base.index).fillna(0).astype(int)
out[f"creditos_{w}d_total_cnt"] = total
```

### 修改内容

**文件**: `CDC/第三板块衍生.ipynb`  
**行号**: 610  
**修改前**:
```python
# zlf update: 特征值为空时填充-999
total = sub.groupby("apply_id").size().reindex(base.index).fillna(-999).astype(int)
```

**修改后**:
```python
# zlf update: cnt特征空值填充0
total = sub.groupby("apply_id").size().reindex(base.index).fillna(0).astype(int)
```

## 验证检查

### 检查其他板块

已检查其他三个板块，确认没有类似问题：

1. ✅ **第一板块衍生.ipynb** - 无此问题
2. ✅ **第二板块衍生.ipynb** - 无此问题
3. ✅ **BOSS板块衍生.ipynb** - 无此问题
4. ✅ **第三板块衍生.ipynb** - 已修复

### 检查第三板块其他cnt特征

已确认第三板块其他cnt特征填充正确：

```python
# ✅ 正确：prev_cnt 使用0填充
prev_cnt = prev_cnt.fillna(0).astype(int)

# ✅ 正确：resp_cnt 使用0填充
resp_cnt = resp_cnt.fillna(0).astype(int)

# ✅ 正确：unique_cnt 使用0填充
out["unique_cnt"] = out["unique_cnt"].fillna(0).astype(int)
```

## 填充规则总结

### 正确的填充规则

| 特征类型 | 填充值 | 示例 |
|---------|-------|------|
| cnt特征 | 0 | `_cnt`, `total_cnt`, `unique_cnt` |
| ratio特征 | -999 | `_ratio`, `_rate` |
| mean特征 | -999 | `_mean`, `_avg` |
| std特征 | -999 | `_std`, `_stddev` |
| max/min特征 | -999 | `_max`, `_min` |
| 其他数值特征 | -999 | 其他衍生特征 |

### 原因说明

1. **cnt特征填充0**:
   - 计数特征，0表示"没有记录"，语义明确
   - 0是合理的默认值，不会引起误解
   - 例如：7天内没有creditos记录，total_cnt=0是正确的

2. **其他特征填充-999**:
   - 统计特征（mean、std等），-999表示"无法计算"
   - -999是明显的异常值，便于识别
   - 例如：没有记录时，无法计算平均值，用-999标记

## 测试建议

### 测试步骤

1. **重新运行第三板块衍生脚本**
   ```bash
   # 在Jupyter中运行第三板块衍生.ipynb
   ```

2. **检查输出特征**
   ```python
   # 检查total_cnt特征的最小值
   for w in [7, 15, 30, 60, 90, 180, 360, 720]:
       col = f"creditos_{w}d_total_cnt"
       min_val = features[col].min()
       print(f"{col}: min={min_val}")
       # 应该输出 min=0，而不是 min=-999
   ```

3. **对比修复前后的差异**
   ```python
   # 统计有多少记录受影响
   for w in [7, 15, 30, 60, 90, 180, 360, 720]:
       col = f"creditos_{w}d_total_cnt"
       # 修复前：值为-999的记录数
       # 修复后：值为0的记录数
       zero_count = (features[col] == 0).sum()
       print(f"{col}: {zero_count} records with value 0")
   ```

### 预期结果

修复后，应该看到：
- ✅ `creditos_*d_total_cnt` 特征的最小值为0（不是-999）
- ✅ 没有creditos记录的apply_id，total_cnt为0
- ✅ 其他ratio特征仍然使用-999填充

## 相关文档

- [四个衍生脚本最近修改总结.md](./四个衍生脚本最近修改总结.md)
- [CDC项目README](../README_文档索引.md)

## 修复记录

| 日期 | 修改人 | 说明 |
|------|-------|------|
| 2026-01-29 | Kiro | 修复第三板块total_cnt特征填充值从-999改为0 |

---

**修复状态**: ✅ 已完成  
**影响范围**: 第三板块 8个total_cnt特征  
**验证状态**: ⏳ 待测试验证
