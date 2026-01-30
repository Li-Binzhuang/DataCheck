# _cnt_std 特征填充验证报告

## 验证时间
2026-01-30

## 验证目的
检查所有 `*_cnt_std` 相关特征的填充值是否正确处理 -999 的情况

## 验证范围
- 第一板块衍生.ipynb：包含 `daily_cnt_std` 特征
- 第二板块衍生.ipynb：不包含 std 特征
- 第三板块衍生.ipynb：不包含 std 特征  
- BOSS板块衍生.ipynb：不包含 std 特征

## 验证结果

### ✅ 第一板块衍生.ipynb - 已正确处理

#### 1. daily_std 计算逻辑（行 839-862）

**特征数量**：17个机构类型 × 7个时间窗口 = 119个特征

**计算公式**：
```python
# 方差计算：var = (sumsq / N) - (mean^2)
var = (sumsq.replace(-999, np.nan) / float(window_days)) - (daily_mean.replace(-999, np.nan)**2)
# 标准差计算：std = sqrt(var)
daily_std = np.sqrt(var.clip(lower=0.0))
# 填充 NaN 为 -999
daily_std = daily_std.fillna(-999.0)
```

**关键处理**：
1. ✅ `sumsq` 在计算前先 `.replace(-999, np.nan)`，避免 -999 参与除法
2. ✅ `daily_mean` 在计算前先 `.replace(-999, np.nan)`，避免 -999 参与平方运算
3. ✅ 计算完成后使用 `.fillna(-999.0)` 将 NaN 填充回 -999
4. ✅ 使用 `.clip(lower=0.0)` 确保方差非负

**影响分析**：
- 当 `sumsq = -999` 或 `daily_mean = -999` 时，会被替换为 NaN
- NaN 参与运算后结果仍为 NaN
- 最终 NaN 被填充为 -999，符合预期

#### 2. daily_std_t 计算逻辑（行 909-932）

**特征数量**：3个信贷类型 × 7个时间窗口 = 21个特征

**计算公式**：
```python
# 方差计算：var_t = (sumsq_t / N) - (mean_t^2)
var_t = (sumsq_t.replace(-999, np.nan) / float(window_days)) - (daily_mean_t.replace(-999, np.nan)**2)
# 标准差计算：std_t = sqrt(var_t)
daily_std_t = np.sqrt(var_t.clip(lower=0.0))
# 填充 NaN 为 -999
daily_std_t = daily_std_t.fillna(-999.0)
```

**关键处理**：
1. ✅ `sumsq_t` 在计算前先 `.replace(-999, np.nan)`
2. ✅ `daily_mean_t` 在计算前先 `.replace(-999, np.nan)`
3. ✅ 计算完成后使用 `.fillna(-999.0)` 填充
4. ✅ 使用 `.clip(lower=0.0)` 确保方差非负

**影响分析**：同 daily_std，处理逻辑一致

### ✅ 其他板块 - 无需处理

- **第二板块衍生.ipynb**：不包含 `*_cnt_std` 特征
- **第三板块衍生.ipynb**：不包含 `*_cnt_std` 特征
- **BOSS板块衍生.ipynb**：不包含 `*_cnt_std` 特征

## 总结

### 涉及的特征总数
- daily_std 特征：119个（17个机构类型 × 7个时间窗口）
- daily_std_t 特征：21个（3个信贷类型 × 7个时间窗口）
- **合计：140个特征**

### 处理状态
✅ **所有 `*_cnt_std` 特征均已正确处理**

### 关键修复点
1. 在计算方差前，将 `sumsq` 和 `daily_mean` 中的 -999 替换为 NaN
2. 计算完成后，将结果中的 NaN 填充回 -999
3. 使用 `.clip(lower=0.0)` 确保方差非负（避免浮点误差导致负数）

### 验证结论
- ✅ 不会出现 -999 参与除法或平方运算的情况
- ✅ 不会出现类似 -33.3、-333 等错误填充值
- ✅ 所有缺失值最终都正确填充为 -999
- ✅ 不影响正常数据的计算（正常值不会被替换为 NaN）

## 相关文档
- [ratio特征填充修复说明](./ratio特征填充修复说明.md)
- [daily_mean特征填充修复说明](./daily_mean特征填充修复说明.md)
- [ratio特征修复完成检查报告](./ratio特征修复完成检查报告.md)
