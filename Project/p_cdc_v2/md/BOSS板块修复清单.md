# BOSS板块衍生脚本修复清单

## 📋 需要修复的位置（8处）

### 位置1: 高使用率账户数（约第982行）

**搜索**: `high_util_cnt"] = 0.0`

**当前代码**:
```python
out[w_prefix + "high_util_cnt"] = 0.0
```

**修改为**:
```python
# zlf update: 无数据时填充-999
out[w_prefix + "high_util_cnt"] = -999
```

**上下文**:
```python
else:
    # 没有数据
    out[w_prefix + "high_util_cnt"] = 0.0  # ← 修改这里
```

---

### 位置2-3: 查询类型统计（约第1124-1126行）

**搜索**: `boss_auto_loan_query_cnt"] = 0.0`

**当前代码**:
```python
out["boss_auto_loan_query_cnt"] = 0.0
out["boss_credit_card_query_cnt"] = 0.0
```

**修改为**:
```python
# zlf update: 无数据时填充-999
out["boss_auto_loan_query_cnt"] = -999
# zlf update: 无数据时填充-999
out["boss_credit_card_query_cnt"] = -999
```

**上下文**:
```python
else:
    # 没有查询数据
    out["boss_auto_loan_query_cnt"] = 0.0  # ← 修改这里
    out["boss_credit_card_query_cnt"] = 0.0  # ← 修改这里
```

---

### 位置4: 查询金额汇总（约第1179行）

**搜索**: `boss_w{w}d_query_amount_sum"] = 0.0`

**当前代码**:
```python
out[f"boss_w{w}d_query_amount_sum"] = 0.0
```

**修改为**:
```python
# zlf update: 无数据时填充-999
out[f"boss_w{w}d_query_amount_sum"] = -999
```

**上下文**:
```python
else:
    # 没有查询数据
    out[f"boss_w{w}d_query_amount_sum"] = 0.0  # ← 修改这里
```

---

### 位置5-7: 就业和公司信息（约第1294-1298行）

**搜索**: `boss_has_verified_employment_flag"] = 0.0`

**当前代码**:
```python
out["boss_has_verified_employment_flag"] = 0.0
out["boss_salary_verified_flag"] = 0.0
out["boss_company_nunique"] = 0.0
```

**修改为**:
```python
# zlf update: 无数据时填充-999
out["boss_has_verified_employment_flag"] = -999
# zlf update: 无数据时填充-999
out["boss_salary_verified_flag"] = -999
# zlf update: 无数据时填充-999
out["boss_company_nunique"] = -999
```

**上下文**:
```python
else:
    # 没有就业数据
    out["boss_has_verified_employment_flag"] = 0.0  # ← 修改这里
    out["boss_salary_verified_flag"] = 0.0  # ← 修改这里
    out["boss_company_nunique"] = 0.0  # ← 修改这里
```

---

### 位置8: 搬家标志（约第1371行）

**搜索**: `boss_recent_move_flag_180d"] = 0.0`

**当前代码**:
```python
out["boss_recent_move_flag_180d"] = 0.0
```

**修改为**:
```python
# zlf update: 无数据时填充-999
out["boss_recent_move_flag_180d"] = -999
```

**上下文**:
```python
else:
    # 没有地址数据
    out["boss_recent_move_flag_180d"] = 0.0  # ← 修改这里
```

---

## 🔍 快速定位方法

### 方法1: 按特征名搜索

在 Jupyter Notebook 中搜索以下字符串：

1. `high_util_cnt"] = 0.0`
2. `boss_auto_loan_query_cnt"] = 0.0`
3. `boss_credit_card_query_cnt"] = 0.0`
4. `boss_w{w}d_query_amount_sum"] = 0.0`
5. `boss_has_verified_employment_flag"] = 0.0`
6. `boss_salary_verified_flag"] = 0.0`
7. `boss_company_nunique"] = 0.0`
8. `boss_recent_move_flag_180d"] = 0.0`

### 方法2: 按行号范围搜索

- **第982行附近**: 高使用率账户数
- **第1124-1126行附近**: 查询类型统计
- **第1179行附近**: 查询金额汇总
- **第1294-1298行附近**: 就业和公司信息
- **第1371行附近**: 搬家标志

---

## 📝 完整的代码块示例

### 示例1: 高使用率账户数（第982行附近）

**修改前**:
```python
if len(dfw):
    # 有数据，计算高使用率账户数
    lim = dfw["limiteCredito"].fillna(-999.0)
    bal = dfw["saldoActual"].fillna(-999.0)
    mask = lim > 0
    util = bal[mask] / lim[mask]
    out[w_prefix + "high_util_cnt"] = float((util > 0.8).sum())
else:
    out[w_prefix + "high_util_cnt"] = 0.0  # ← 修改这里
```

**修改后**:
```python
if len(dfw):
    # 有数据，计算高使用率账户数
    lim = dfw["limiteCredito"].fillna(-999.0)
    bal = dfw["saldoActual"].fillna(-999.0)
    mask = lim > 0
    util = bal[mask] / lim[mask]
    out[w_prefix + "high_util_cnt"] = float((util > 0.8).sum())
else:
    # zlf update: 无数据时填充-999
    out[w_prefix + "high_util_cnt"] = -999
```

### 示例2: 查询类型统计（第1124-1126行附近）

**修改前**:
```python
if len(consultas_df):
    # 有查询数据
    tipo_cnt = consultas_df.groupby("tipoCredito").size()
    out["boss_auto_loan_query_cnt"] = float(tipo_cnt.get("AU", 0))
    out["boss_credit_card_query_cnt"] = float(tipo_cnt.get("TC", 0))
else:
    out["boss_auto_loan_query_cnt"] = 0.0  # ← 修改这里
    out["boss_credit_card_query_cnt"] = 0.0  # ← 修改这里
```

**修改后**:
```python
if len(consultas_df):
    # 有查询数据
    tipo_cnt = consultas_df.groupby("tipoCredito").size()
    out["boss_auto_loan_query_cnt"] = float(tipo_cnt.get("AU", 0))
    out["boss_credit_card_query_cnt"] = float(tipo_cnt.get("TC", 0))
else:
    # zlf update: 无数据时填充-999
    out["boss_auto_loan_query_cnt"] = -999
    # zlf update: 无数据时填充-999
    out["boss_credit_card_query_cnt"] = -999
```

### 示例3: 查询金额汇总（第1179行附近）

**修改前**:
```python
for w in [7, 30, 90]:
    qw = consultas_df[consultas_df["days_since_query"] <= w]
    if len(qw):
        out[f"boss_w{w}d_query_amount_sum"] = float(qw["importeSolicitado"].fillna(-999.0).sum())
    else:
        out[f"boss_w{w}d_query_amount_sum"] = 0.0  # ← 修改这里
```

**修改后**:
```python
for w in [7, 30, 90]:
    qw = consultas_df[consultas_df["days_since_query"] <= w]
    if len(qw):
        out[f"boss_w{w}d_query_amount_sum"] = float(qw["importeSolicitado"].fillna(-999.0).sum())
    else:
        # zlf update: 无数据时填充-999
        out[f"boss_w{w}d_query_amount_sum"] = -999
```

### 示例4: 就业和公司信息（第1294-1298行附近）

**修改前**:
```python
if len(emp):
    # 有就业数据
    out["boss_has_verified_employment_flag"] = 1.0 if len(emp) > 0 else 0.0
    out["boss_salary_verified_flag"] = 1.0 if (emp["salario"] > 0).any() else 0.0
    out["boss_company_nunique"] = float(emp["nombreEmpresa"].nunique())
else:
    out["boss_has_verified_employment_flag"] = 0.0  # ← 修改这里
    out["boss_salary_verified_flag"] = 0.0  # ← 修改这里
    out["boss_company_nunique"] = 0.0  # ← 修改这里
```

**修改后**:
```python
if len(emp):
    # 有就业数据
    out["boss_has_verified_employment_flag"] = 1.0 if len(emp) > 0 else 0.0
    out["boss_salary_verified_flag"] = 1.0 if (emp["salario"] > 0).any() else 0.0
    out["boss_company_nunique"] = float(emp["nombreEmpresa"].nunique())
else:
    # zlf update: 无数据时填充-999
    out["boss_has_verified_employment_flag"] = -999
    # zlf update: 无数据时填充-999
    out["boss_salary_verified_flag"] = -999
    # zlf update: 无数据时填充-999
    out["boss_company_nunique"] = -999
```

### 示例5: 搬家标志（第1371行附近）

**修改前**:
```python
if len(domicilios_df):
    # 有地址数据
    recent_move = (domicilios_df["days_since_address"] <= 180).any()
    out["boss_recent_move_flag_180d"] = 1.0 if recent_move else 0.0
else:
    out["boss_recent_move_flag_180d"] = 0.0  # ← 修改这里
```

**修改后**:
```python
if len(domicilios_df):
    # 有地址数据
    recent_move = (domicilios_df["days_since_address"] <= 180).any()
    out["boss_recent_move_flag_180d"] = 1.0 if recent_move else 0.0
else:
    # zlf update: 无数据时填充-999
    out["boss_recent_move_flag_180d"] = -999
```

---

## ✅ 修复检查清单

修改完成后，检查以下内容：

- [ ] 第 982 行: `high_util_cnt` 改为 -999
- [ ] 第 1124 行: `boss_auto_loan_query_cnt` 改为 -999
- [ ] 第 1126 行: `boss_credit_card_query_cnt` 改为 -999
- [ ] 第 1179 行: `boss_w{w}d_query_amount_sum` 改为 -999
- [ ] 第 1294 行: `boss_has_verified_employment_flag` 改为 -999
- [ ] 第 1296 行: `boss_salary_verified_flag` 改为 -999
- [ ] 第 1298 行: `boss_company_nunique` 改为 -999
- [ ] 第 1371 行: `boss_recent_move_flag_180d` 改为 -999
- [ ] 每处修改都添加了 `# zlf update: 无数据时填充-999` 注释

---

## 🔄 验证方法

修改完成后，运行检查脚本：

```bash
python CDC/scripts/check_and_fix_fillna.py
```

期望结果：
```
BOSS板块:
  = 0: 0 处 ✅
```

---

## 📊 影响的特征

修改后，以下特征在无数据时将输出 -999 而不是 0：

### 使用率相关（3个窗口）
- `boss_w7d_high_util_cnt`
- `boss_w30d_high_util_cnt`
- `boss_w90d_high_util_cnt`

### 查询类型统计
- `boss_auto_loan_query_cnt`
- `boss_credit_card_query_cnt`

### 查询金额汇总（3个窗口）
- `boss_w7d_query_amount_sum`
- `boss_w30d_query_amount_sum`
- `boss_w90d_query_amount_sum`

### 就业和公司信息
- `boss_has_verified_employment_flag`
- `boss_salary_verified_flag`
- `boss_company_nunique`

### 地址信息
- `boss_recent_move_flag_180d`

**总计**: 约 12 个特征

---

## 💡 修改提示

### 批量查找替换

可以使用以下正则表达式进行批量替换：

**查找**: `= 0\.0  # (?:.*无数据|.*没有)`
**替换**: `= -999  # zlf update: 无数据时填充-999`

或者手动逐个修改，确保每处都正确。

---

## 🎯 修改优先级

这8处修改都是**可选的**，不影响核心功能。但为了保持一致性，建议全部修改。

**修改理由**:
- 统一空值处理逻辑（全部使用 -999）
- 区分"没有数据"和"数值为0"
- 提高数据质量和可追溯性

---

**创建时间**: 2025-01-29  
**需要修复**: 8 处  
**预计时间**: 10-15 分钟
