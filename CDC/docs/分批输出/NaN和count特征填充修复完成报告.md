# CDC板块衍生脚本 - NaN和count特征填充修复完成报告

## 修改概述

**任务**: 修复CSV输出中的NaN值问题，并优化count特征的填充逻辑

**状态**: ✅ 已完成

**修改时间**: 2026-01-28

**修改标识**: zlf update

---

## 问题描述

### 问题1: CSV文件中出现大量NaN值

**现象**: 
- 打开CSV文件后，看到很多单元格显示为空白或NaN
- 特征值应该是 -999，但显示为 NaN

**原因**:
```python
# 这行代码会将无法转换的值变为NaN
_features_to_write[_round_cols] = _features_to_write[_round_cols].apply(pd.to_numeric, errors="coerce").round(6)
```

`pd.to_numeric(errors="coerce")` 会将无法转换为数字的值转换为 NaN，导致之前填充的 -999 又变回了 NaN。

---

### 问题2: count特征填充值不合理

**现象**:
- count类特征（如 `_cnt`）的缺失值被填充为 -999
- 但计数的最小值应该是 0，-999 不符合业务逻辑

**原因**:
- 统一使用了 -999 作为填充值
- 没有区分计数特征和其他特征

---

## 修改方案

### 修复1: 在 round(6) 后再次填充NaN

**修改位置**: 所有板块的输出部分

**修改前**:
```python
_features_to_write[_round_cols] = _features_to_write[_round_cols].apply(pd.to_numeric, errors="coerce").round(6)
```

**修改后**:
```python
_features_to_write[_round_cols] = _features_to_write[_round_cols].apply(pd.to_numeric, errors="coerce").round(6).fillna(-999.0)  # zlf update: round后再次填充NaN为-999
```

---

### 修复2: count特征填充为0

**修改位置**: 所有板块的特征计算部分

**修改前**:
```python
cnt = cnt.fillna(-999).astype(int)
```

**修改后**:
```python
cnt = cnt.fillna(0).astype(int)  # zlf update: count特征填充为0而不是-999
```

---

## 修改统计

### 第一板块

#### round(6).fillna(-999.0) 修改
- ✅ 第1479行：输出前的 round(6)

#### count特征 fillna(0) 修改
- ✅ 第781行：`cnt = cnt.fillna(0).astype(int)`
- ✅ 第859行：`cnt_t = gt.size().unstack()...fillna(0).astype(int)`
- ✅ 第2095行：`out["unique_cnt"] = out["unique_cnt"].fillna(0).astype(int)`

**小计**: 1处 round 修改 + 3处 count 修改

---

### 第二板块

#### round(6).fillna(-999.0) 修改
- ✅ 第1697行：输出前的 round(6)
- ✅ 第2076行：features 的 round(6)
- ✅ 第2071行：另一处 _features_to_write 的 round(6)

#### count特征 fillna(0) 修改
- ✅ 第1224行：`total_cnt = sub.groupby(...)...fillna(0).astype("int32")`
- ✅ 第1236行：`cnt = cnt.fillna(0).astype("int32")`
- ✅ 第1274行：`cnt_local = cnt_local.fillna(0).astype("int32")`
- ✅ 第3791行：`out["unique_cnt"] = out["unique_cnt"].fillna(0).astype(int)`

**小计**: 3处 round 修改 + 4处 count 修改

---

### 第三板块

#### round(6).fillna(-999.0) 修改
- ✅ 第1016行：输出前的 round(6)
- ✅ 第1232行：features 的 round(6)

#### count特征 fillna(0) 修改
- ✅ 第621行：`prev_cnt = prev_cnt.fillna(0).astype(int)`
- ✅ 第641行：`resp_cnt = resp_cnt.fillna(0).astype(int)`
- ✅ 第2156行：`out["unique_cnt"] = out["unique_cnt"].fillna(0).astype(int)`

**小计**: 2处 round 修改 + 3处 count 修改

---

### BOSS板块

#### round(6).fillna(-999.0) 修改
- ✅ 第2327行：输出前的 round(6)

#### count特征 fillna(0) 修改
- ✅ 第2666行：`out["unique_cnt"] = out["unique_cnt"].fillna(0).astype(int)`

**小计**: 1处 round 修改 + 1处 count 修改

---

## 总计统计

| 板块 | round修改 | count修改 | 总计 |
|------|----------|----------|------|
| 第一板块 | 1 | 3 | 4 |
| 第二板块 | 3 | 4 | 7 |
| 第三板块 | 2 | 3 | 5 |
| BOSS板块 | 1 | 1 | 2 |
| **总计** | **7** | **11** | **18** |

---

## 修改效果

### 修改前
```csv
apply_id,request_time,cdc_consultas_30d_shop_cnt_v2,cdc_consultas_30d_shop_days_mean_v2
1065462384007251969,2025-11-24 21:37:18.301,NaN,NaN
```

### 修改后
```csv
apply_id,request_time,cdc_consultas_30d_shop_cnt_v2,cdc_consultas_30d_shop_days_mean_v2
1065462384007251969,2025-11-24 21:37:18.301,0,-999.0
```

**说明**:
- `_cnt` 特征（计数）: 缺失值填充为 **0**
- 其他特征（mean、std、ratio等）: 缺失值填充为 **-999.0**

---

## 特征填充规则总结

### 1. count类特征 → 填充为 0
**特征名包含**: `_cnt`, `_count`, `total_cnt`, `unique_cnt`

**原因**: 
- 计数的最小值是0（没有记录就是0次）
- 0 符合业务逻辑
- 便于理解和使用

**示例**:
- `cdc_consultas_30d_shop_cnt_v2`: 0（没有查询记录）
- `cdc_creditos_30d_total_cnt`: 0（没有信贷记录）

---

### 2. 其他特征 → 填充为 -999.0
**特征类型**: mean、std、ratio、days等

**原因**:
- -999 作为明显的缺失值标识
- 与正常值区分明显
- 便于后续处理和建模

**示例**:
- `cdc_consultas_30d_shop_days_mean_v2`: -999.0（没有数据无法计算均值）
- `cdc_consultas_30d_shop_ratio_v2`: -999.0（没有数据无法计算占比）

---

## 验证方法

### 1. 检查CSV文件
```bash
# 查看输出文件
head -5 CDC/outputs/cdc1_features_batch001_1-500.csv

# 检查是否还有NaN
grep -i "nan" CDC/outputs/cdc1_features_batch001_1-500.csv
```

### 2. 使用Python验证
```python
import pandas as pd

# 读取批次文件
df = pd.read_csv("CDC/outputs/cdc1_features_batch001_1-500.csv")

# 检查NaN值
print("NaN值数量:", df.isna().sum().sum())

# 检查count特征的最小值
cnt_cols = [c for c in df.columns if '_cnt' in c]
print("\ncount特征的最小值:")
for col in cnt_cols:
    print(f"{col}: {df[col].min()}")

# 检查其他特征的填充值
other_cols = [c for c in df.columns if c not in cnt_cols and c not in ['apply_id', 'request_time']]
print("\n其他特征中-999.0的数量:")
for col in other_cols[:5]:  # 只看前5个
    print(f"{col}: {(df[col] == -999.0).sum()}")
```

---

## 相关文档

- 分批输出功能说明: `CDC/docs/分批输出/分批输出功能说明.md`
- 分批输出验证指南: `CDC/docs/分批输出/分批输出验证指南.md`
- zlf update总结: `CDC/docs/zlf_update/zlf_update_最终总结.md`

---

## 下一步

1. ✅ 在Jupyter中运行板块脚本
2. ✅ 检查输出的CSV文件
3. ✅ 验证没有NaN值
4. ✅ 验证count特征填充为0
5. ✅ 验证其他特征填充为-999.0

---

**创建时间**: 2026-01-28  
**修改标识**: zlf update  
**状态**: ✅ 已完成  
**修改类型**: 数据质量优化 - NaN修复 + count特征优化

