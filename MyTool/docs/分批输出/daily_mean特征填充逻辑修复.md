# daily_mean和daily_std特征填充逻辑修复

## 问题发现

用户发现了一个重要的逻辑问题：

### 原来的代码
```python
cnt_in_Ndays = cnt_in_Ndays.fillna(-999.0)  # 无数据填充为-999
daily_mean = cnt_in_Ndays / float(window_days)  # -999.0 / 30 = -33.3 ❌
```

### 问题
- 当 `cnt_in_Ndays = -999.0` 时（表示无数据）
- `daily_mean = -999.0 / 30 = -33.3`
- **-33.3 不是一个清晰的标识值**，容易与正常的负值混淆

---

## 修复方案

### 正确的逻辑
```python
cnt_in_Ndays = cnt_in_Ndays.fillna(0.0)  # 无数据填充为0 ✅
daily_mean = cnt_in_Ndays / float(window_days)  # 0.0 / 30 = 0.0 ✅
```

### 为什么填充0而不是-999？

#### 业务含义
- `cnt_in_Ndays = 0`：近N天内该类别的查询次数为0
- `daily_mean = 0 / 30 = 0.0`：每天平均查询0次
- **这符合业务逻辑**：没有记录 = 每天0次

#### 与其他特征的区别
| 特征类型 | 填充值 | 原因 |
|---------|--------|------|
| cnt | 0 | 没有记录 = 0次 |
| mean/std | -999.0 | 无法计算均值/标准差 |
| ratio | -999.0 | 分母为0无法计算 |
| **daily_mean** | **0.0** | **没有记录 = 每天0次** |
| **daily_std** | **0.0** | **没有记录 = 标准差为0** |

---

## 修改内容

### 第一板块 - otorgante_group部分

#### 修改1: sumsq填充
```python
# 修改前
sumsq = sumsq.reindex(...).fillna(-999.0)  # ❌

# 修改后
sumsq = sumsq.reindex(...).fillna(0.0)  # ✅
```

#### 修改2: cnt_in_Ndays填充
```python
# 修改前
cnt_in_Ndays = cnt_in_Ndays.reindex(...).fillna(-999.0)  # ❌

# 修改后
cnt_in_Ndays = cnt_in_Ndays.reindex(...).fillna(0.0)  # ✅
```

#### 修改3: var计算
```python
# 修改前
var = (sumsq.replace(-999.0, 0.0) / float(window_days)) - (daily_mean**2)  # ❌ 需要replace

# 修改后
var = (sumsq / float(window_days)) - (daily_mean**2)  # ✅ 不需要replace
```

---

### 第一板块 - tipoCredito部分

#### 修改4: sumsq_t填充
```python
# 修改前
sumsq_t = sumsq_t.reindex(...).fillna(-999.0)  # ❌

# 修改后
sumsq_t = sumsq_t.reindex(...).fillna(0.0)  # ✅
```

#### 修改5: cnt_in_Ndays_t填充
```python
# 修改前
cnt_in_Ndays_t = cnt_in_Ndays_t.reindex(...).fillna(-999.0)  # ❌

# 修改后
cnt_in_Ndays_t = cnt_in_Ndays_t.reindex(...).fillna(0.0)  # ✅
```

---

## 修改位置

### 第一板块衍生.ipynb

| 行号 | 变量 | 修改前 | 修改后 |
|------|------|--------|--------|
| 825 | sumsq | fillna(-999.0) | fillna(0.0) |
| 830 | cnt_in_Ndays | fillna(-999.0) | fillna(0.0) |
| 834 | var计算 | sumsq.replace(-999.0, 0.0) | sumsq |
| 893 | sumsq_t | fillna(-999.0) | fillna(0.0) |
| 897 | cnt_in_Ndays_t | fillna(-999.0) | fillna(0.0) |

---

## 修改效果

### 修改前
```python
# apply_id 1001: 没有记录
cnt_in_Ndays = -999.0
daily_mean = -999.0 / 30 = -33.3  # ❌ 不清晰
daily_std = sqrt((-999.0/30) - (-33.3)^2) = 异常值
```

### 修改后
```python
# apply_id 1001: 没有记录
cnt_in_Ndays = 0.0
daily_mean = 0.0 / 30 = 0.0  # ✅ 清晰：每天0次
daily_std = sqrt((0.0/30) - (0.0)^2) = 0.0  # ✅ 清晰：标准差为0
```

---

## 其他板块

需要检查第二、三、BOSS板块是否有类似的daily_mean/daily_std特征，如果有，也需要同样修改。

### 检查方法
```bash
grep -n "cnt_in_Ndays.*fillna" CDC/*板块衍生.ipynb
grep -n "sumsq.*fillna" CDC/*板块衍生.ipynb
```

---

## 验证方法

### 1. 检查daily_mean的值
```python
import pandas as pd
df = pd.read_csv("CDC/outputs/cdc1_features_batch001_1-500.csv")

# 检查daily_mean特征
daily_mean_cols = [c for c in df.columns if 'daily_cnt_mean' in c]

for col in daily_mean_cols[:3]:
    print(f"{col}:")
    print(f"  最小值: {df[col].min()}")  # 应该 >= 0
    print(f"  最大值: {df[col].max()}")
    print(f"  =0的数量: {(df[col] == 0.0).sum()}")
    print(f"  <0的数量: {(df[col] < 0).sum()}")  # 应该 = 0
    print()
```

### 2. 检查daily_std的值
```python
daily_std_cols = [c for c in df.columns if 'daily_cnt_std' in c]

for col in daily_std_cols[:3]:
    print(f"{col}:")
    print(f"  最小值: {df[col].min()}")  # 应该 >= 0
    print(f"  最大值: {df[col].max()}")
    print(f"  =0的数量: {(df[col] == 0.0).sum()}")
    print(f"  <0的数量: {(df[col] < 0).sum()}")  # 应该 = 0
    print()
```

---

## 总结

### 修改原因
- 原来的 `-999.0 / 30 = -33.3` 不是清晰的标识值
- 容易与正常的负值混淆

### 修改后的逻辑
- `cnt_in_Ndays = 0`：没有记录
- `daily_mean = 0 / 30 = 0.0`：每天平均0次
- `daily_std = 0.0`：标准差为0

### 业务含义
- **更清晰**：0.0 明确表示"没有查询"
- **更合理**：符合"没有记录 = 每天0次"的业务逻辑
- **更一致**：与cnt特征的填充逻辑一致

---

**创建时间**: 2026-01-28  
**修改标识**: zlf update  
**状态**: ✅ 已完成  
**修改类型**: 逻辑优化 - daily_mean/daily_std填充修复
