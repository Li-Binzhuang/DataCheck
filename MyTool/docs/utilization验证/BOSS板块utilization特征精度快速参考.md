# BOSS板块 utilization 特征精度 - 快速参考

## ❓ 问题
utilization特征是否会被截取为2位小数？

## ✅ 答案
**不会**。BOSS板块在CSV输出时有 `round(6)` 处理，统一保留6位小数。

## 📝 相关特征
- `cdc_boss_w30d_avg_utilization_607`
- `cdc_boss_w30d_total_utilization_607`
- `cdc_boss_w30d_tc_avg_utilization_607`
- ... (其他窗口的utilization特征)

## 💻 处理代码
```python
# CSV输出时的处理（约2194-2198行）
# zlf update: 对数值特征列保留6位小数
_features_to_write = features_df.copy()
_round_cols = [c for c in _features_to_write.columns if c not in {"apply_id", "request_time"}]
_features_to_write[_round_cols] = _features_to_write[_round_cols].apply(pd.to_numeric, errors="coerce").round(6)
_features_to_write.to_csv(csv_path, index=False, encoding="utf-8-sig")
```

## 🔍 验证方法
```python
import pandas as pd

# 读取输出文件
df = pd.read_csv('CDC/outputs/cdcboss_features_full_data.csv')

# 检查utilization特征
print(df['cdc_boss_w30d_avg_utilization_607'].head())
# 应该显示6位小数，例如：0.753489
```

## 📊 输出格式
```csv
apply_id,cdc_boss_w30d_avg_utilization_607
123,0.753489  ✅ 6位小数
456,0.812346  ✅ 6位小数
789,0.45      ✅ 不足6位保持原样
```

## ✨ 总结
- ✅ 不会截取为2位小数
- ✅ 统一保留6位小数
- ✅ 与其他特征格式一致

---

**验证时间**：2026-01-28  
**验证结论**：✅ 精度正常，保留6位小数
