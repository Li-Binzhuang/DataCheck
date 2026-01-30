# Ratio 和 Daily_mean 特征修复完成检查报告

## 检查时间
2026-01-30

## 检查范围
CDC 项目所有衍生脚本中的 ratio 和 daily_mean 计算逻辑

---

## ✅ 第一板块衍生.ipynb - 已完成（4处修复）

### 修复位置 1：机构大类 ratio 计算
**行号**: 825, 827

**修复前**:
```python
notnull_ratio = valid.div(cnt.replace(0, np.nan)).fillna(-999.0)
ratio = cnt.div(total.replace(0, np.nan), axis=0).fillna(-999.0)
```

**修复后**:
```python
notnull_ratio = valid.replace(-999, np.nan).div(cnt.replace([0, -999], np.nan)).fillna(-999.0)
ratio = cnt.replace(-999, np.nan).div(total.replace(0, np.nan), axis=0).fillna(-999.0)
```

✅ **状态**: 已修复

---

### 修复位置 2：tipoCredito ratio 计算
**行号**: 898, 900

**修复前**:
```python
notnull_ratio_t = valid_t.div(cnt_t.replace(0, np.nan)).fillna(-999.0)
ratio_t = cnt_t.div(total.replace(0, np.nan), axis=0).fillna(-999.0)
```

**修复后**:
```python
notnull_ratio_t = valid_t.replace(-999, np.nan).div(cnt_t.replace([0, -999], np.nan)).fillna(-999.0)
ratio_t = cnt_t.replace(-999, np.nan).div(total.replace(0, np.nan), axis=0).fillna(-999.0)
```

✅ **状态**: 已修复

---

### 修复位置 3：机构大类 daily_mean 和 daily_std 计算 ⭐ 新增
**行号**: 856-861

**问题**: `cnt_in_Ndays = -999` 参与除法 → `-999 / 30 = -33.3` ❌

**修复前**:
```python
cnt_in_Ndays = cnt_in_Ndays.fillna(-999)
daily_mean = cnt_in_Ndays / float(window_days)
var = (sumsq / float(window_days)) - (daily_mean**2)
daily_std = np.sqrt(var.clip(lower=0.0))
```

**修复后**:
```python
cnt_in_Ndays = cnt_in_Ndays.fillna(-999)
daily_mean = cnt_in_Ndays.replace(-999, np.nan) / float(window_days)
daily_mean = daily_mean.fillna(-999.0)
var = (sumsq.replace(-999, np.nan) / float(window_days)) - (daily_mean.replace(-999, np.nan)**2)
daily_std = np.sqrt(var.clip(lower=0.0))
daily_std = daily_std.fillna(-999.0)
```

✅ **状态**: 已修复

---

### 修复位置 4：tipoCredito daily_mean_t 和 daily_std_t 计算 ⭐ 新增
**行号**: 926-931

**问题**: `cnt_in_Ndays_t = -999` 参与除法 → `-999 / 30 = -33.3` ❌

**修复前**:
```python
cnt_in_Ndays_t = cnt_in_Ndays_t.fillna(-999)
daily_mean_t = cnt_in_Ndays_t / float(window_days)
var_t = (sumsq_t / float(window_days)) - (daily_mean_t**2)
daily_std_t = np.sqrt(var_t.clip(lower=0.0))
```

**修复后**:
```python
cnt_in_Ndays_t = cnt_in_Ndays_t.fillna(-999)
daily_mean_t = cnt_in_Ndays_t.replace(-999, np.nan) / float(window_days)
daily_mean_t = daily_mean_t.fillna(-999.0)
var_t = (sumsq_t.replace(-999, np.nan) / float(window_days)) - (daily_mean_t.replace(-999, np.nan)**2)
daily_std_t = np.sqrt(var_t.clip(lower=0.0))
daily_std_t = daily_std_t.fillna(-999.0)
```

✅ **状态**: 已修复

---

## ✅ 第二板块衍生.ipynb - 已完成

### 修复位置 1：机构大类 ratio 计算
**行号**: 1238

**修复前**:
```python
ratio = cnt.div(denom, axis=0).fillna(-999.0).astype("float32")
```

**修复后**:
```python
ratio = cnt.replace(-999, np.nan).div(denom, axis=0).fillna(-999.0).astype("float32")
```

✅ **状态**: 已修复

---

### 修复位置 2：类别字段 ratio_local 计算
**行号**: 1276

**修复前**:
```python
ratio_local = cnt_local.div(denom, axis=0).fillna(-999.0).astype("float32")
```

**修复后**:
```python
ratio_local = cnt_local.replace(-999, np.nan).div(denom, axis=0).fillna(-999.0).astype("float32")
```

✅ **状态**: 已修复

---

## ✅ 第三板块衍生.ipynb - 已完成

### 修复位置 1：预防类型 prev_ratio 计算
**行号**: 625

**修复前**:
```python
prev_ratio = prev_cnt.div(total.replace(0, np.nan), axis=0).fillna(-999.0)
```

**修复后**:
```python
prev_ratio = prev_cnt.replace(-999, np.nan).div(total.replace(0, np.nan), axis=0).fillna(-999.0)
```

✅ **状态**: 已修复

---

### 修复位置 2：责任类型 resp_ratio 计算
**行号**: 645

**修复前**:
```python
resp_ratio = resp_cnt.div(total.replace(0, np.nan), axis=0).fillna(-999.0)
```

**修复后**:
```python
resp_ratio = resp_cnt.replace(-999, np.nan).div(total.replace(0, np.nan), axis=0).fillna(-999.0)
```

✅ **状态**: 已修复

---

## ✅ BOSS板块衍生.ipynb - 无需修复

该脚本不涉及类似的 ratio 计算逻辑，无需修复。

✅ **状态**: 无需修复

---

## 修复统计

| 脚本 | 修复位置数 | 状态 |
|------|-----------|------|
| 第一板块衍生.ipynb | 4 (ratio×2 + daily_mean×2) | ✅ 已完成 |
| 第二板块衍生.ipynb | 2 (ratio×2) | ✅ 已完成 |
| 第三板块衍生.ipynb | 2 (ratio×2) | ✅ 已完成 |
| BOSS板块衍生.ipynb | 0 | ✅ 无需修复 |
| **总计** | **8** | **✅ 全部完成** |

---

## 影响的特征类型

### 1. Ratio 特征（所有板块）
- `*_ratio` - 类别占比特征
- `*_notnull_ratio` - 非空值占比特征

**错误值示例**: `-333.0`, `-166.5`, `-111.0` 等

### 2. Daily_mean 特征（仅第一板块）⭐ 新发现
- `*_daily_cnt_mean` - 每天平均次数特征
- `*_daily_cnt_std` - 每天次数标准差特征

**错误值示例**: 
- 30天窗口: `-33.3`
- 60天窗口: `-16.65`
- 90天窗口: `-11.1`
- 120天窗口: `-8.325`
- 180天窗口: `-5.55`
- 360天窗口: `-2.775`
- 720天窗口: `-1.3875`

**影响特征数**: 280个（17类机构×7窗口×2 + 3类tipoCredito×7窗口×2）

---

## 验证方法

### 1. 代码层面验证
所有涉及 ratio 计算的代码都已添加 `.replace(-999, np.nan)` 处理：

```bash
# 检查是否还有未修复的 ratio 计算
grep -n "\.div(" CDC/第一板块衍生.ipynb | grep "fillna(-999" | grep -v "replace(-999"
grep -n "\.div(" CDC/第二板块衍生.ipynb | grep "fillna(-999" | grep -v "replace(-999"
grep -n "\.div(" CDC/第三板块衍生.ipynb | grep "fillna(-999" | grep -v "replace(-999"
```

✅ **结果**: 所有命令返回空，说明没有遗漏

### 2. 输出文件验证
重新运行脚本后，检查输出文件：

```bash
# 检查 ratio 错误值（-333, -166.5, -111 等）
grep -h "\-333\|\-166\|\-111" CDC/outputs/*.csv

# 检查 daily_mean 错误值（-33.3, -16.65, -11.1 等）
grep -h "\-33\.3\|\-16\.65\|\-11\.1\|\-8\.325\|\-5\.55\|\-2\.775\|\-1\.3875" CDC/outputs/*.csv
```

⚠️ **注意**: 需要重新运行脚本后才能验证

---

## 下一步操作

### 必须执行的步骤：

1. **重新运行所有衍生脚本**
   - 在 Jupyter 中依次运行：
     - `CDC/第一板块衍生.ipynb`
     - `CDC/第二板块衍生.ipynb`
     - `CDC/第三板块衍生.ipynb`
     - `CDC/BOSS板块衍生.ipynb`

2. **验证输出结果**
   ```bash
   # 检查 ratio 错误值（应该没有输出）
   grep -h "\-333\|\-166\|\-111" CDC/outputs/*.csv
   
   # 检查 daily_mean 错误值（应该没有输出）
   grep -h "\-33\.3\|\-16\.65\|\-11\.1" CDC/outputs/*.csv
   ```

3. **检查特征值范围**
   - ratio 特征应该只包含：
     - 正常值：`0.0` 到 `1.0`
     - 缺失标记：`-999.0`
     - ❌ 不应该有：`-333.0`, `-166.5`, `-111.0` 等
   
   - daily_mean 特征应该只包含：
     - 正常值：`>= 0.0` 的数值
     - 缺失标记：`-999.0`
     - ❌ 不应该有：`-33.3`, `-16.65`, `-11.1` 等

### 可选步骤：

4. **如果已用于建模**
   - 使用新的特征文件重新训练模型
   - 对比新旧模型的性能差异

5. **更新文档**
   - 在项目文档中记录此次修复
   - 通知相关人员使用新的特征文件

---

## 修复原理说明

### 问题 1: Ratio 特征
```python
cnt = -999  # 表示该类别没有记录
total = 3   # 窗口内总记录数
ratio = -999 / 3 = -333  # ❌ 错误：-999 参与了除法
```

### 问题 2: Daily_mean 特征 ⭐ 新发现
```python
cnt_in_Ndays = -999  # 表示该类别没有记录
window_days = 30     # 窗口天数
daily_mean = -999 / 30 = -33.3  # ❌ 错误：-999 参与了除法
```

### 统一修复方案
```python
# 步骤1: 填充为 -999
value = -999

# 步骤2: 计算前替换为 NaN
value_clean = np.nan

# 步骤3: 进行除法运算
result = np.nan / divisor = np.nan

# 步骤4: 填充回 -999
result_final = -999  # ✓ 正确
```

### 核心逻辑
**在进行除法运算之前，先将 -999 替换为 NaN，避免 -999 参与除法运算，计算完成后再填充回 -999**

---

## 相关文档

- [ratio特征填充修复说明.md](./ratio特征填充修复说明.md) - ratio 特征详细说明
- [ratio特征填充修复快速参考.md](./ratio特征填充修复快速参考.md) - 快速参考
- [daily_mean特征填充修复说明.md](./daily_mean特征填充修复说明.md) - daily_mean 特征详细说明 ⭐ 新增
- [_cnt_std特征填充验证报告.md](./_cnt_std特征填充验证报告.md) - std 特征验证报告 ⭐ 新增
- [_cnt_std特征填充快速参考.md](./_cnt_std特征填充快速参考.md) - std 特征快速参考 ⭐ 新增

---

## 检查人员
zlf

## 检查结论
✅ **所有修复已完成（包括新发现的 daily_mean 问题），代码层面检查通过**

✅ **所有 `*_cnt_std` 特征已验证，处理逻辑正确** ⭐ 新增验证

⚠️ **需要重新运行脚本以生成正确的输出文件**
