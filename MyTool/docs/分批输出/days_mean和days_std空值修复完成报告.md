# CDC第一板块 - days_mean和days_std空值修复完成报告

## 修改概述

**任务**: 修复第一板块中 `days_mean` 和 `days_std` 特征的空值问题

**状态**: ✅ 已完成

**修改时间**: 2026-01-28

**修改标识**: zlf update

---

## 问题描述

### 现象
CSV输出文件中，以下特征仍然显示为空值（NaN）：
- `cdc_consultas_30d_shop_days_mean_v2`
- `cdc_consultas_30d_shop_days_std_v2`
- 以及其他 `_days_mean` 和 `_days_std` 特征

### 原因
在特征计算时，`mean` 和 `std` 变量计算后**没有填充 NaN 值**：

```python
# ❌ 问题代码
mean = (
    g["days_before_request"].mean().unstack().reindex(index=df_base.index, columns=groups_to_use)
)  # 没有 fillna

std = (
    g["days_before_request"].std(ddof=0).unstack().reindex(index=df_base.index, columns=groups_to_use)
)  # 没有 fillna

# 直接使用，导致 NaN 传递到输出
out[f"consultas_{window_days}d_{gid}_days_mean"] = mean[group_name]  # ❌ 包含 NaN
out[f"consultas_{window_days}d_{gid}_days_std"] = std[group_name]  # ❌ 包含 NaN
```

---

## 修改方案

### 修改位置1: otorgante_group 的 mean 和 std

**位置**: 约第784-793行

**修改前**:
```python
mean = (
    g["days_before_request"].mean().unstack().reindex(index=df_base.index, columns=groups_to_use)
)  # days_before_request 的均值

std = (
    g["days_before_request"].std(ddof=0).unstack().reindex(index=df_base.index, columns=groups_to_use)
)  # days_before_request 的标准差
```

**修改后**:
```python
mean = (
    g["days_before_request"].mean().unstack().reindex(index=df_base.index, columns=groups_to_use)
)  # days_before_request 的均值
# zlf update: 特征值为空时填充-999
mean = mean.fillna(-999.0)

std = (
    g["days_before_request"].std(ddof=0).unstack().reindex(index=df_base.index, columns=groups_to_use)
)  # days_before_request 的标准差
# zlf update: 特征值为空时填充-999
std = std.fillna(-999.0)
```

---

### 修改位置2: tipoCredito 的 mean_t 和 std_t

**位置**: 约第865-869行

**修改前**:
```python
mean_t = gt["days_before_request"].mean().unstack().reindex(index=df_base.index, columns=tipo_credito_to_use)
std_t = gt["days_before_request"].std(ddof=0).unstack().reindex(index=df_base.index, columns=tipo_credito_to_use)
```

**修改后**:
```python
mean_t = gt["days_before_request"].mean().unstack().reindex(index=df_base.index, columns=tipo_credito_to_use)
# zlf update: 特征值为空时填充-999
mean_t = mean_t.fillna(-999.0)

std_t = gt["days_before_request"].std(ddof=0).unstack().reindex(index=df_base.index, columns=tipo_credito_to_use)
# zlf update: 特征值为空时填充-999
std_t = std_t.fillna(-999.0)
```

---

## 影响的特征

### otorgante_group 相关特征（17个大类 × 7个窗口）
- `cdc_consultas_{window}d_{group}_days_mean_v2`
- `cdc_consultas_{window}d_{group}_days_std_v2`

**示例**:
- `cdc_consultas_30d_shop_days_mean_v2`
- `cdc_consultas_30d_shop_days_std_v2`
- `cdc_consultas_60d_mass_fin_assn_days_mean_v2`
- `cdc_consultas_60d_mass_fin_assn_days_std_v2`
- ...

### tipoCredito 相关特征（3个类型 × 7个窗口）
- `cdc_consultas_{window}d_tipo_{type}_days_mean_v2`
- `cdc_consultas_{window}d_tipo_{type}_days_std_v2`

**示例**:
- `cdc_consultas_30d_tipo_cc_days_mean_v2`
- `cdc_consultas_30d_tipo_cc_days_std_v2`
- `cdc_consultas_60d_tipo_pp_days_mean_v2`
- `cdc_consultas_60d_tipo_pp_days_std_v2`
- ...

---

## 修改效果

### 修改前
```csv
apply_id,cdc_consultas_30d_shop_days_mean_v2,cdc_consultas_30d_shop_days_std_v2
1065462364007251969,NaN,NaN
```

### 修改后
```csv
apply_id,cdc_consultas_30d_shop_days_mean_v2,cdc_consultas_30d_shop_days_std_v2
1065462364007251969,-999.0,-999.0
```

---

## 其他板块

### 第二板块
✅ 无此问题（没有 days_mean 和 days_std 特征）

### 第三板块
✅ 无此问题（没有 days_mean 和 days_std 特征）

### BOSS板块
✅ 无此问题（没有 days_mean 和 days_std 特征）

---

## 验证方法

### 1. 运行脚本后检查
```python
import pandas as pd

# 读取输出文件
df = pd.read_csv("CDC/outputs/cdc1_features_batch001_1-500.csv")

# 检查 days_mean 和 days_std 特征
days_cols = [c for c in df.columns if '_days_mean_' in c or '_days_std_' in c]

# 检查是否还有 NaN
for col in days_cols:
    nan_count = df[col].isna().sum()
    if nan_count > 0:
        print(f"❌ {col}: {nan_count} 个 NaN")
    else:
        print(f"✅ {col}: 无 NaN")

# 检查 -999.0 的数量
for col in days_cols[:5]:  # 只看前5个
    count_999 = (df[col] == -999.0).sum()
    print(f"{col}: {count_999} 个 -999.0")
```

### 2. 查询特定 apply_id
```python
# 查询某个 apply_id 的 days 特征
apply_id = 1065462364007251969

result = df[df['apply_id'] == apply_id][[
    'apply_id',
    'cdc_consultas_30d_shop_days_mean_v2',
    'cdc_consultas_30d_shop_days_std_v2'
]]

print(result)
# 应该显示 -999.0 而不是 NaN
```

---

## 修改总结

### 修改统计
- **修改文件**: 1个（第一板块衍生.ipynb）
- **修改位置**: 2处
- **添加代码**: 4行（2处 fillna）
- **影响特征**: 约140个（17个大类 + 3个类型）× 7个窗口 × 2个指标

### 填充规则
- **days_mean**: 缺失值填充为 **-999.0**
- **days_std**: 缺失值填充为 **-999.0**

### 业务含义
- `-999.0` 表示该 apply_id 在该窗口内没有对应类型的查询记录
- 无法计算均值和标准差，用 -999.0 标识

---

## 相关文档

- NaN和count特征填充修复: `CDC/docs/分批输出/NaN和count特征填充修复完成报告.md`
- 分批输出功能说明: `CDC/docs/分批输出/分批输出功能说明.md`
- zlf update总结: `CDC/docs/zlf_update/zlf_update_最终总结.md`

---

## 完整修改历史

### 第一轮修改（之前）
1. ✅ 空值填充改为 -999
2. ✅ 浮点数精度保留6位小数
3. ✅ np.nan 补充修复
4. ✅ 禁用明细文件输出
5. ✅ 分批输出功能
6. ✅ round(6) 后添加 fillna(-999.0)
7. ✅ count特征填充改为 0

### 第二轮修改（本次）
8. ✅ **days_mean 和 days_std 添加 fillna(-999.0)**

---

**创建时间**: 2026-01-28  
**修改标识**: zlf update  
**状态**: ✅ 已完成  
**修改类型**: 数据质量优化 - days特征空值修复

