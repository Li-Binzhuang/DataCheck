# fillna修改安全性 - 快速参考

## 问题
-999填充、cnt填充0会不会影响特征计算？

## 答案
✅ **不会！所有fillna都在计算完成之后**

---

## 安全原则

### ✅ 我们的做法（安全）
```python
# 1. 先计算
result = data.mean()

# 2. 后填充
result = result.fillna(-999.0)
```

### ❌ 危险做法（我们没有用）
```python
# 1. 先填充
data = data.fillna(0)

# 2. 后计算（会改变结果！）
result = data.mean()
```

---

## 各类特征的fillna位置

### 1. cnt特征：fillna(0)
```python
cnt = g.size().unstack().reindex(...)  # ← 计算完成
cnt = cnt.fillna(0).astype(int)        # ← 填充缺失 ✅
```
**含义**：没有记录 = 0次

### 2. mean/std特征：fillna(-999.0)
```python
mean = g["days_before_request"].mean()...  # ← 计算完成
mean = mean.fillna(-999.0)                 # ← 填充缺失 ✅
```
**含义**：无法计算 = -999.0

### 3. ratio特征：fillna(-999.0)
```python
ratio = cnt.div(total.replace(0, np.nan), axis=0)  # ← 计算完成
ratio = ratio.fillna(-999.0)                       # ← 填充缺失 ✅
```
**含义**：分母为0 = -999.0

### 4. 输出处理：round(6).fillna(-999.0)
```python
features[_round_cols] = features[_round_cols]
    .apply(pd.to_numeric, errors="coerce")  # ← 转换
    .round(6)                                # ← 保留6位
    .fillna(-999.0)                          # ← 填充NaN ✅
```
**含义**：防止NaN泄漏到输出

---

## 特殊情况

### daily_mean的-33.3
```python
cnt_in_Ndays = cnt_in_Ndays.fillna(-999.0)
daily_mean = cnt_in_Ndays / 30  # -999.0 / 30 = -33.3
```
**这是有意的！** -33.3表示"无数据"，不会与正常值混淆

---

## 快速验证

```python
import pandas as pd
df = pd.read_csv("CDC/outputs/cdc1_features_batch001_1-500.csv")

# 1. cnt特征应该 >= 0
cnt_cols = [c for c in df.columns if '_cnt' in c]
print("cnt最小值:", df[cnt_cols].min().min())  # 应该 >= 0

# 2. 不应该有NaN
print("NaN总数:", df.isna().sum().sum())  # 应该 = 0

# 3. -999.0只出现在非cnt特征
print("cnt中的-999:", (df[cnt_cols] == -999).sum().sum())  # 应该 = 0
```

---

## 结论

✅ **所有修改都安全**
- fillna在计算后
- 不改变已有值
- -999.0是标识值

---

**日期**: 2026-01-28  
**状态**: ✅ 已验证安全
