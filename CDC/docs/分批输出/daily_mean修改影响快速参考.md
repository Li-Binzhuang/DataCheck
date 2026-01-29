# daily_mean修改影响 - 快速参考

## 问题
将 `cnt_in_Ndays` 和 `sumsq` 的填充从 `-999.0` 改为 `0.0`，会影响原逻辑吗？

## 答案
✅ **不会影响原特征计算逻辑**

---

## 变量使用范围

### sumsq
```python
sumsq = sumsq.fillna(0.0)  # ← 修改点
↓
var = (sumsq / N) - (daily_mean^2)
↓
daily_std = sqrt(var)
↓
只影响 daily_cnt_std 特征 ✅
```

### cnt_in_Ndays
```python
cnt_in_Ndays = cnt_in_Ndays.fillna(0.0)  # ← 修改点
↓
daily_mean = cnt_in_Ndays / N
↓
只影响 daily_cnt_mean 特征 ✅
```

---

## 不受影响的特征

| 特征 | 原因 |
|------|------|
| cnt | 独立计算：`g.size()` |
| days_mean | 独立计算：`g["days_before_request"].mean()` |
| days_std | 独立计算：`g["days_before_request"].std()` |
| ratio | 使用独立的cnt |
| notnull_ratio | 使用独立的cnt |

**所有其他特征都不受影响** ✅

---

## 受影响的特征（预期改变）

### daily_cnt_mean
```python
# 无数据时
修改前: -999.0 / 30 = -33.3  ❌
修改后: 0.0 / 30 = 0.0  ✅ 更合理
```

### daily_cnt_std
```python
# 无数据时
修改前: sqrt(异常值) = NaN  ❌
修改后: sqrt(0.0) = 0.0  ✅ 更合理
```

---

## 有数据的情况

✅ **完全不受影响**

当有数据时，fillna不会触发，计算结果与修改前完全相同。

---

## 验证
```python
# 检查有数据的记录（应该与修改前相同）
mask = df['cdc_consultas_30d_shop_cnt_v2'] > 0
print(df.loc[mask, 'cdc_consultas_30d_shop_daily_cnt_mean_v2'].describe())

# 检查无数据的记录（应该都是0.0）
mask_zero = df['cdc_consultas_30d_shop_cnt_v2'] == 0
print(df.loc[mask_zero, 'cdc_consultas_30d_shop_daily_cnt_mean_v2'].unique())
# 应该输出: [0.0]
```

---

**结论**: ✅ 安全，只改变了预期的特征值

**日期**: 2026-01-28
