# days特征空值修复 - 快速参考

## 问题
CSV输出中 `_days_mean` 和 `_days_std` 特征显示为 NaN

## 根本原因
两个地方缺少 fillna：
1. 特征计算时：mean/std 变量计算后未填充
2. 输出处理时：features表的round(6)后未填充

## 解决方案

### 第一板块修改（3处）

#### 1. otorgante_group的mean和std（约第784-793行）
```python
mean = g["days_before_request"].mean().unstack().reindex(...)
# zlf update: 特征值为空时填充-999
mean = mean.fillna(-999.0)

std = g["days_before_request"].std(ddof=0).unstack().reindex(...)
# zlf update: 特征值为空时填充-999
std = std.fillna(-999.0)
```

#### 2. tipoCredito的mean_t和std_t（约第865-869行）
```python
mean_t = gt["days_before_request"].mean().unstack().reindex(...)
# zlf update: 特征值为空时填充-999
mean_t = mean_t.fillna(-999.0)

std_t = gt["days_before_request"].std(ddof=0).unstack().reindex(...)
# zlf update: 特征值为空时填充-999
std_t = std_t.fillna(-999.0)
```

#### 3. features表的round(6)处理（约第2414行）⭐ 关键修复
```python
features[_round_cols] = features[_round_cols].apply(pd.to_numeric, errors="coerce").round(6).fillna(-999.0)  # zlf update
```

## 验证
```python
import pandas as pd
df = pd.read_csv("CDC/outputs/cdc1_features_batch001_1-500.csv")

# 检查NaN
days_cols = [c for c in df.columns if '_days_mean_' in c or '_days_std_' in c]
print("NaN总数:", df[days_cols].isna().sum().sum())  # 应该是0

# 检查-999.0
print("-999.0总数:", (df[days_cols] == -999.0).sum().sum())
```

## 其他板块
✅ 第二板块：已验证，所有round(6)都有fillna
✅ 第三板块：已验证，所有round(6)都有fillna  
✅ BOSS板块：已验证，所有round(6)都有fillna

## 关键教训
**任何使用 `pd.to_numeric(errors="coerce")` 的地方，都必须在后面加上 `.fillna(-999.0)`**

---
**状态**: ✅ 已完成  
**日期**: 2026-01-28
