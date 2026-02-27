# Ratio 特征填充修复说明

## 问题描述

在 CDC 项目的衍生脚本中，发现部分特征值被错误填充为 `-333`、`-166.5` 等值，而不是预期的 `-999`。

### 问题示例

```
cdc_consultas_90d_shop_ratio_v2: -333.0  (错误)
应该是: -999.0  (正确)
```

## 问题根源

在计算 ratio（比例）特征时，已经填充为 `-999` 的 `cnt` 值参与了除法运算：

```python
# 错误的逻辑：
cnt = cnt.fillna(-999)  # cnt 被填充为 -999
ratio = cnt.div(total, axis=0).fillna(-999.0)  # -999 / 3 = -333
```

当 `cnt = -999`（表示该类别没有记录）且 `total = 3` 时：
- `ratio = -999 / 3 = -333.0` ❌

## 修复方案

在计算 ratio 之前，先将 `-999` 替换为 `NaN`，计算完成后再填充回 `-999`：

```python
# 正确的逻辑：
cnt = cnt.fillna(-999)  # cnt 被填充为 -999
ratio = cnt.replace(-999, np.nan).div(total.replace(0, np.nan), axis=0).fillna(-999.0)  # ✓
```

这样：
- 如果 `cnt = -999` → 替换为 `NaN` → 除法结果 `NaN` → 填充为 `-999` ✓
- 如果 `cnt = 0` → `0 / total = 0` ✓
- 如果 `total = 0` → 结果 `NaN` → 填充为 `-999` ✓

## 修复范围

### ✅ 已修复的脚本

1. **第一板块衍生.ipynb** (consultas 特征)
   - 修复位置 1: 机构大类的 `notnull_ratio` 和 `ratio` 计算
   - 修复位置 2: tipoCredito 的 `notnull_ratio_t` 和 `ratio_t` 计算

2. **第二板块衍生.ipynb** (creditos 特征)
   - 修复位置 1: 机构大类的 `ratio` 计算
   - 修复位置 2: 类别字段（tipoCuenta/tipoCredito）的 `ratio_local` 计算

3. **第三板块衍生.ipynb** (clavePrevencion 特征)
   - 修复位置 1: 预防类型的 `prev_ratio` 计算
   - 修复位置 2: 责任类型的 `resp_ratio` 计算

4. **BOSS板块衍生.ipynb**
   - ✓ 无需修复（该脚本不涉及类似的 ratio 计算）

## 影响的特征类型

所有包含以下后缀的特征都受到影响：
- `*_ratio` - 类别占比特征
- `*_notnull_ratio` - 非空值占比特征

### 具体特征示例

**第一板块（consultas）：**
- `cdc_consultas_30d_shop_ratio_v2`
- `cdc_consultas_60d_shop_ratio_v2`
- `cdc_consultas_90d_shop_ratio_v2`
- `cdc_consultas_*d_*_notnull_ratio_v2`
- `cdc_consultas_*d_tipo_cc_ratio_v2`
- 等等...

**第二板块（creditos）：**
- `cdc2_creditos_30d_shop_ratio`
- `cdc2_creditos_*d_*_ratio`
- 等等...

**第三板块（clavePrevencion）：**
- `cdc3_creditos_30d_prev_cl_ratio`
- `cdc3_creditos_*d_resp_i_ratio`
- 等等...

## 验证方法

### 1. 检查现有输出文件

```bash
# 查找包含 -333 的记录
grep -h "\-333" CDC/outputs/*.csv | head -5

# 查找包含 -166 的记录
grep -h "\-166" CDC/outputs/*.csv | head -5
```

### 2. 重新运行脚本

修复后需要重新运行所有衍生脚本以生成正确的输出：

```bash
# 在 Jupyter 中依次运行：
1. CDC/第一板块衍生.ipynb
2. CDC/第二板块衍生.ipynb
3. CDC/第三板块衍生.ipynb
4. CDC/BOSS板块衍生.ipynb
```

### 3. 验证修复结果

重新运行后，所有 ratio 特征应该只包含以下值：
- 正常比例值：`0.0` 到 `1.0` 之间
- 缺失标记：`-999.0`
- **不应该出现**：`-333.0`、`-166.5`、`-111.0` 等值

## 修复时间

- 修复日期：2026-01-30
- 修复人：zlf

## 注意事项

1. **必须重新运行脚本**：修复代码后，旧的输出文件仍然包含错误值，需要重新生成
2. **检查下游影响**：如果已经使用了旧的特征文件进行建模，需要重新训练模型
3. **数据一致性**：确保所有板块都使用修复后的脚本生成特征

## 相关文档

- [空值填充优化说明](./空值填充优化完成报告.md)
- [特征值检查报告](./特征值检查报告_1065479921833549825.md)
