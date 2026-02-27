# zlf update: 板块衍生脚本优化

## 📋 更新概述

本次更新优化了四个板块衍生脚本的特征空值处理逻辑,将所有特征计算中的空值填充从 `0` 统一改为 `-999`,以便更好地区分真实零值和缺失值。

## 🎯 更新目标

1. **统一缺失值标识**: 使用 `-999` 作为所有特征空值的统一标识
2. **提高数据质量**: 避免将真实的0值与缺失值混淆
3. **便于下游处理**: 明确的缺失值标识有助于模型更好地处理缺失数据
4. **代码可追溯**: 在每处修改前添加 "zlf update" 注释标识

## 📁 更新文件

| 文件名 | 板块 | 修改行数 | 状态 |
|--------|------|----------|------|
| 第一板块衍生.ipynb | 查询板块(consultas) | 9行 | ✅ 已完成 |
| 第二板块衍生.ipynb | 信贷板块(creditos) | 3行 | ✅ 已完成 |
| 第三板块衍生.ipynb | 预防类型板块(clavePrevencion) | 2行 | ✅ 已完成 |
| BOSS板块衍生.ipynb | BOSS综合板块 | 30行 | ✅ 已完成 |

**总计**: 44处修改

## 🔧 修改详情

### 修改规则

#### ✅ 修改的情况
```python
# 整数特征
.fillna(0) → .fillna(-999)

# 浮点数特征
.fillna(0.0) → .fillna(-999.0)
```

#### ⛔ 不修改的情况
```python
# 字符串填充保持不变
.fillna("")  # 不修改
.fillna('')  # 不修改
```

### 修改示例

#### 第一板块 - 查询次数统计
```python
# 修改前
total = (
    consultas_df.groupby("apply_id")
    .size()
    .reindex(df_base.index)
    .fillna(0)  # ❌ 旧代码
    .astype(int)
)

# 修改后
# zlf update: 特征值为空时填充-999
total = (
    consultas_df.groupby("apply_id")
    .size()
    .reindex(df_base.index)
    .fillna(-999)  # ✅ 新代码
    .astype(int)
)
```

#### 第二板块 - 占比计算
```python
# 修改前
ratio = cnt.div(denom, axis=0).fillna(0.0).astype("float32")  # ❌ 旧代码

# 修改后
# zlf update: 特征值为空时填充-999
ratio = cnt.div(denom, axis=0).fillna(-999.0).astype("float32")  # ✅ 新代码
```

#### BOSS板块 - 余额汇总
```python
# 修改前
saldo = cre["saldoActual"].fillna(0.0)  # ❌ 旧代码

# 修改后
# zlf update: 特征值为空时填充-999
saldo = cre["saldoActual"].fillna(-999.0)  # ✅ 新代码
```

## 📊 影响范围

### 受影响的特征类型
- ✅ 计数特征 (cnt)
- ✅ 占比特征 (ratio)
- ✅ 均值特征 (mean)
- ✅ 标准差特征 (std)
- ✅ 最大值特征 (max)
- ✅ 最小值特征 (min)
- ✅ 总和特征 (sum)
- ✅ 有效值占比 (notnull_ratio)

### 不受影响的字段
- ⛔ 字符串类型字段
- ⛔ 日期时间字段
- ⛔ 枚举类型字段

## 🚀 使用指南

### 1. 重新生成特征

```bash
# 方法1: 在Jupyter中运行
jupyter notebook CDC/第一板块衍生.ipynb

# 方法2: 使用nbconvert批量执行
jupyter nbconvert --to notebook --execute CDC/第一板块衍生.ipynb
jupyter nbconvert --to notebook --execute CDC/第二板块衍生.ipynb
jupyter nbconvert --to notebook --execute CDC/第三板块衍生.ipynb
jupyter nbconvert --to notebook --execute CDC/BOSS板块衍生.ipynb
```

### 2. 验证修改结果

```bash
# 查看所有zlf update标记
grep -r "zlf update" CDC/*板块衍生.ipynb

# 查看fillna(-999)使用情况
grep -r "fillna(-999" CDC/*板块衍生.ipynb | wc -l

# 确认没有遗漏的fillna(0)
grep "fillna(0)" CDC/*板块衍生.ipynb | grep -v 'fillna("")'
```

### 3. 下游处理建议

```python
import pandas as pd
import numpy as np

# 读取特征文件
features = pd.read_csv('outputs/cdc1_features_consultas.csv')

# 方法1: 替换为NaN (适用于大多数模型)
features = features.replace(-999, np.nan)

# 方法2: 保留-999作为特殊类别 (适用于树模型)
# 无需额外处理,树模型可以直接学习-999的含义

# 方法3: 使用缺失值填充
from sklearn.impute import SimpleImputer
imputer = SimpleImputer(missing_values=-999, strategy='mean')
features_imputed = imputer.fit_transform(features)

# 方法4: 创建缺失值指示器
features['is_missing'] = (features == -999).any(axis=1).astype(int)
```

## 📝 相关文档

- `zlf_update_summary.md` - 详细修改说明
- `zlf_update_quick_reference.md` - 快速参考指南
- `update_fillna_comprehensive.py` - 修改脚本源码

## ⚠️ 注意事项

1. **重新生成特征**: 修改后必须重新运行脚本生成新的特征文件
2. **下游兼容性**: 确保下游模型代码能正确处理-999缺失值
3. **统计计算**: 某些统计计算(如sum)可能需要先过滤-999值
4. **文档更新**: 建议在特征字典中添加-999缺失值的说明

## 🔍 验证清单

- [x] 所有fillna(0)已改为fillna(-999)
- [x] 所有fillna(0.0)已改为fillna(-999.0)
- [x] 字符串fillna("")保持不变
- [x] 每处修改前添加了"zlf update"注释
- [x] 创建了修改脚本和文档
- [x] 验证没有遗漏的修改

## 📞 支持

如有问题或建议,请联系开发团队。

---

**更新日期**: 2026-01-28  
**更新人**: zlf  
**版本**: v1.0
