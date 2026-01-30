# Daily_mean 特征填充修复说明

## 问题描述

在第一板块衍生脚本中，发现 `daily_cnt_mean` 和 `daily_cnt_std` 特征被错误填充为 `-33.3`、`-16.65` 等值，而不是预期的 `-999`。

### 问题示例

```
cdc_consultas_30d_shop_daily_cnt_mean_v2: -33.3  (错误)
cdc_consultas_60d_shop_daily_cnt_mean_v2: -16.65  (错误)
应该是: -999.0  (正确)
```

## 问题根源

在计算 `daily_mean` 特征时，已经填充为 `-999` 的 `cnt_in_Ndays` 值参与了除法运算：

```python
# 错误的逻辑：
cnt_in_Ndays = cnt_in_Ndays.fillna(-999)  # 填充为 -999
daily_mean = cnt_in_Ndays / float(window_days)  # -999 / 30 = -33.3 ❌
```

### 具体计算示例

当 `cnt_in_Ndays = -999`（表示该类别没有记录）时：
- 30天窗口：`daily_mean = -999 / 30 = -33.3` ❌
- 60天窗口：`daily_mean = -999 / 60 = -16.65` ❌
- 90天窗口：`daily_mean = -999 / 90 = -11.1` ❌
- 120天窗口：`daily_mean = -999 / 120 = -8.325` ❌
- 180天窗口：`daily_mean = -999 / 180 = -5.55` ❌
- 360天窗口：`daily_mean = -999 / 360 = -2.775` ❌
- 720天窗口：`daily_mean = -999 / 720 = -1.3875` ❌

## 修复方案

在计算 `daily_mean` 之前，先将 `-999` 替换为 `NaN`，计算完成后再填充回 `-999`：

```python
# 修复前（错误）
cnt_in_Ndays = cnt_in_Ndays.fillna(-999)
daily_mean = cnt_in_Ndays / float(window_days)

# 修复后（正确）
cnt_in_Ndays = cnt_in_Ndays.fillna(-999)
daily_mean = cnt_in_Ndays.replace(-999, np.nan) / float(window_days)
daily_mean = daily_mean.fillna(-999.0)  # 计算完成后再填充回-999
```

这样：
- 如果 `cnt_in_Ndays = -999` → 替换为 `NaN` → 除法结果 `NaN` → 填充为 `-999` ✓
- 如果 `cnt_in_Ndays = 0` → `0 / 30 = 0` ✓
- 如果 `cnt_in_Ndays = 3` → `3 / 30 = 0.1` ✓

## 修复范围

### ✅ 已修复的位置

**第一板块衍生.ipynb**

#### 修复位置 1：机构大类的 daily_mean 和 daily_std
**行号**: 856-861

**修复内容**:
- `daily_mean` 计算：先将 `cnt_in_Ndays` 中的 `-999` 替换为 `NaN`
- `daily_std` 计算：先将 `sumsq` 中的 `-999` 替换为 `NaN`
- 计算完成后再填充回 `-999`

#### 修复位置 2：tipoCredito 的 daily_mean_t 和 daily_std_t
**行号**: 926-931

**修复内容**:
- `daily_mean_t` 计算：先将 `cnt_in_Ndays_t` 中的 `-999` 替换为 `NaN`
- `daily_std_t` 计算：先将 `sumsq_t` 中的 `-999` 替换为 `NaN`
- 计算完成后再填充回 `-999`

## 影响的特征

所有包含以下后缀的特征都受到影响：
- `*_daily_cnt_mean` - 每天平均次数特征
- `*_daily_cnt_std` - 每天次数标准差特征

### 具体特征列表

**机构大类（17类 × 7窗口 × 2特征 = 238个特征）**:
- `cdc_consultas_30d_shop_daily_cnt_mean_v2`
- `cdc_consultas_30d_shop_daily_cnt_std_v2`
- `cdc_consultas_60d_shop_daily_cnt_mean_v2`
- `cdc_consultas_60d_shop_daily_cnt_std_v2`
- ... (所有机构大类 × 所有窗口)

**tipoCredito（3类 × 7窗口 × 2特征 = 42个特征）**:
- `cdc_consultas_30d_tipo_cc_daily_cnt_mean_v2`
- `cdc_consultas_30d_tipo_cc_daily_cnt_std_v2`
- `cdc_consultas_60d_tipo_pp_daily_cnt_mean_v2`
- `cdc_consultas_60d_tipo_pp_daily_cnt_std_v2`
- ... (所有 tipoCredito × 所有窗口)

**总计**: 280 个特征受影响

## 与 ratio 修复的关系

这个问题与之前修复的 ratio 特征问题本质相同：
- **ratio 问题**: `cnt = -999` 参与除法 → `-999 / 3 = -333`
- **daily_mean 问题**: `cnt_in_Ndays = -999` 参与除法 → `-999 / 30 = -33.3`

**根本原因**: 填充为 `-999` 的值在后续计算中没有被正确处理，直接参与了数学运算。

**统一解决方案**: 在进行除法运算前，先将 `-999` 替换为 `NaN`，计算完成后再填充回 `-999`。

## 验证方法

### 1. 检查现有输出文件

```bash
# 查找包含 -33.3 的记录（30天窗口）
grep -h "\-33\.3" CDC/outputs/*.csv | head -3

# 查找包含 -16.65 的记录（60天窗口）
grep -h "\-16\.65" CDC/outputs/*.csv | head -3

# 查找包含 -11.1 的记录（90天窗口）
grep -h "\-11\.1" CDC/outputs/*.csv | head -3
```

### 2. 重新运行脚本

修复后需要重新运行第一板块衍生脚本：

```bash
# 在 Jupyter 中运行：
CDC/第一板块衍生.ipynb
```

### 3. 验证修复结果

重新运行后，所有 `daily_cnt_mean` 和 `daily_cnt_std` 特征应该只包含：
- 正常值：`>= 0.0` 的数值
- 缺失标记：`-999.0`
- **不应该出现**：`-33.3`, `-16.65`, `-11.1`, `-8.325`, `-5.55`, `-2.775`, `-1.3875` 等值

## 修复时间

- 修复日期：2026-01-30
- 修复人：zlf

## 注意事项

1. **必须重新运行脚本**：修复代码后，旧的输出文件仍然包含错误值
2. **检查下游影响**：如果已经使用了旧的特征文件进行建模，需要重新训练模型
3. **与 ratio 修复一起验证**：建议同时验证 ratio 和 daily_mean 特征的修复效果

## 相关文档

- [ratio特征填充修复说明.md](./ratio特征填充修复说明.md) - ratio 特征修复
- [ratio特征修复完成检查报告.md](./ratio特征修复完成检查报告.md) - 完整检查报告
