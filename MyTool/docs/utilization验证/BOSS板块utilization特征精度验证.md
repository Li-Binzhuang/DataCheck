# BOSS板块 utilization 特征精度验证

## 用户问题
检查BOSS板块衍生脚本中的utilization特征是否会被截取为2位小数，例如：
- `cdc_boss_w30d_avg_utilization_607`
- `cdc_boss_w30d_total_utilization_607`
- `cdc_boss_w30d_tc_avg_utilization_607`

## 验证结果

### ✅ 不会被截取为2位小数

**原因**：BOSS板块在CSV输出时已经添加了 `round(6)` 处理，会统一保留6位小数。

## 代码分析

### 特征计算阶段
在特征计算时，utilization特征没有round()处理：

```python
# 平均使用率
util = (bal[mask] / lim[mask]).replace([np.inf, -np.inf], np.nan).dropna()
out[w_prefix + "avg_utilization"] = float(util.mean()) if len(util) else SENTINEL

# 总使用率
out[w_prefix + "total_utilization"] = safe_div(bal_sum, lim_sum)

# 信用卡平均使用率
util = (bal[mask] / lim[mask]).replace([np.inf, -np.inf], np.nan).dropna()
out[w_prefix + "tc_avg_utilization"] = float(util.mean()) if len(util) else SENTINEL
```

### CSV输出阶段
在CSV输出时，有 `round(6)` 处理：

```python
# zlf update: 对数值特征列保留6位小数
_features_to_write = features_df.copy()
_round_cols = [c for c in _features_to_write.columns if c not in {"apply_id", "request_time"}]
_features_to_write[_round_cols] = _features_to_write[_round_cols].apply(pd.to_numeric, errors="coerce").round(6)
_features_to_write.to_csv(csv_path, index=False, encoding="utf-8-sig")
```

### 处理流程

```
特征计算 → features_df → CSV输出时round(6) → 输出文件
   ↓                           ↓
原始精度                    保留6位小数
(可能很多位)                  (统一格式)
```

## 受影响的特征

### utilization相关特征（示例）

**窗口特征（3个窗口：30d, 90d, 180d）：**
- `boss_w30d_avg_utilization` - 平均使用率
- `boss_w30d_total_utilization` - 总使用率
- `boss_w30d_tc_avg_utilization` - 信用卡平均使用率
- `boss_w90d_avg_utilization`
- `boss_w90d_total_utilization`
- `boss_w90d_tc_avg_utilization`
- `boss_w180d_avg_utilization`
- `boss_w180d_total_utilization`
- `boss_w180d_tc_avg_utilization`

**加前缀后的特征名：**
- `cdc_boss_w30d_avg_utilization_607`
- `cdc_boss_w30d_total_utilization_607`
- `cdc_boss_w30d_tc_avg_utilization_607`
- ... (其他窗口)

## 输出示例

### 修复前（如果没有round(6)）
```csv
apply_id,cdc_boss_w30d_avg_utilization_607,cdc_boss_w30d_total_utilization_607
123,0.7534892156,0.8123456789  # 可能很多位小数
456,0.45,0.67                   # 或者被截断
```

### 修复后（有round(6)）
```csv
apply_id,cdc_boss_w30d_avg_utilization_607,cdc_boss_w30d_total_utilization_607
123,0.753489,0.812346  # 统一保留6位小数
456,0.45,0.67          # 不足6位的保持原样
```

## 验证方法

### 1. 代码验证
```bash
# 检查CSV输出部分是否有round(6)
grep -A 5 "zlf update.*小数" CDC/BOSS板块衍生.ipynb
```

### 2. 输出文件验证
```python
import pandas as pd

# 读取输出文件
df = pd.read_csv('CDC/outputs/cdcboss_features_full_data.csv')

# 检查utilization特征的小数位数
util_cols = [c for c in df.columns if 'utilization' in c]

for col in util_cols[:3]:  # 检查前3个
    print(f"\n{col}:")
    print(df[col].head())
    
    # 检查小数位数
    sample_val = df[col].dropna().iloc[0]
    if pd.notna(sample_val) and sample_val != -999:
        decimal_str = str(sample_val).split('.')[-1] if '.' in str(sample_val) else ''
        print(f"小数位数: {len(decimal_str)}")
```

## 总结

### 当前状态
✅ **BOSS板块的utilization特征不会被截取为2位小数**

### 原因
- ✅ CSV输出时有 `round(6)` 处理
- ✅ 处理应用到所有数值列
- ✅ 包括所有utilization特征

### 精度保证
- ✅ 统一保留6位小数
- ✅ 与其他特征格式一致
- ✅ 满足精度要求

## 相关修改

### 之前的修改
在2026-01-28，为BOSS板块添加了CSV输出时的 `round(6)` 处理：

```python
# zlf update: 对数值特征列保留6位小数
_features_to_write[_round_cols] = _features_to_write[_round_cols].apply(pd.to_numeric, errors="coerce").round(6)
```

这个修改确保了：
1. 所有数值特征统一保留6位小数
2. 包括utilization、ratio、mean、std等所有类型的特征
3. 不会出现截取为2位小数的情况

## 相关文档
- `浮点数处理功能说明.md` - 浮点数精度控制详细说明
- `浮点数处理功能完成报告.md` - 修复完成报告
- `zlf_update_最终总结.md` - 所有修改总结

---

**验证完成时间**：2026-01-28  
**验证结论**：✅ utilization特征会保留6位小数，不会被截取为2位
