# _cnt_std 特征填充快速参考

## 验证结论
✅ **所有 `*_cnt_std` 特征均已正确处理，不会出现错误填充值**

## 涉及特征
- **第一板块衍生.ipynb**：140个特征
  - daily_std：119个（17个机构类型 × 7个时间窗口）
  - daily_std_t：21个（3个信贷类型 × 7个时间窗口）
- **其他板块**：无 std 特征

## 处理逻辑
```python
# 1. 计算方差时，先将 -999 替换为 NaN
var = (sumsq.replace(-999, np.nan) / float(window_days)) - (daily_mean.replace(-999, np.nan)**2)

# 2. 计算标准差，确保非负
daily_std = np.sqrt(var.clip(lower=0.0))

# 3. 将 NaN 填充回 -999
daily_std = daily_std.fillna(-999.0)
```

## 关键点
1. ✅ -999 不参与除法运算（避免出现 -33.3 等值）
2. ✅ -999 不参与平方运算（避免出现 998001 等值）
3. ✅ 计算结果中的 NaN 正确填充为 -999
4. ✅ 不影响正常数据的计算

## 相关文档
- [详细验证报告](./_cnt_std特征填充验证报告.md)
- [ratio特征修复](./ratio特征填充修复说明.md)
- [daily_mean特征修复](./daily_mean特征填充修复说明.md)
