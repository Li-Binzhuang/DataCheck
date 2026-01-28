# np.nan补充修复 - 快速参考

## 📋 问题
第一板块中 `days_mean` 和 `days_std` 特征在无数据时使用了 `np.nan` 而不是 `-999`

## ✅ 解决方案
将 `np.nan` 改为 `-999`，并添加 `zlf update` 注释

## 📝 修改位置
**文件**：`CDC/第一板块衍生.ipynb`

**位置1**：机构17大类特征（2处）
```python
# zlf update: 特征值为空时填充-999
out[f"consultas_{window_days}d_{gid}_days_mean"] = -999
# zlf update: 特征值为空时填充-999
out[f"consultas_{window_days}d_{gid}_days_std"] = -999
```

**位置2**：tipoCredito特征（2处）
```python
# zlf update: 特征值为空时填充-999
out[f"consultas_{window_days}d_tipo_{tid}_days_mean"] = -999
# zlf update: 特征值为空时填充-999
out[f"consultas_{window_days}d_tipo_{tid}_days_std"] = -999
```

## 📊 修改统计
| 板块 | 修改前 | 修改后 | 新增 |
|------|--------|--------|------|
| 第一板块 | 14 | 18 | +4 |
| 总计 | 59 | 63 | +4 |

## 🔍 验证命令
```bash
# 检查zlf update注释数量
grep -c "zlf update" CDC/第一板块衍生.ipynb
# 输出: 18

# 检查是否还有np.nan
grep -c "= np\.nan" CDC/第一板块衍生.ipynb
# 输出: 0

# 检查新增的-999赋值
grep -n "= -999" CDC/第一板块衍生.ipynb | grep "days_mean\|days_std"
# 应该显示4行
```

## 🎯 影响的特征
- `consultas_30d_shop_days_mean` / `consultas_30d_shop_days_std`
- `consultas_30d_bank_days_mean` / `consultas_30d_bank_days_std`
- ... (其他15个机构大类)
- `consultas_30d_tipo_cc_days_mean` / `consultas_30d_tipo_cc_days_std`
- `consultas_30d_tipo_pp_days_mean` / `consultas_30d_tipo_pp_days_std`
- `consultas_30d_tipo_tc_days_mean` / `consultas_30d_tipo_tc_days_std`

**总计**：约120个特征

## ⚠️ 注意
第二板块中的2处 `np.nan` 用于数据清洗，**不需要修改**

## 📚 相关文档
- 详细说明：`np.nan补充修复说明.md`
- 总结报告：`zlf_update_最终总结.md`

---

**修复完成时间**：2026-01-28  
**修改人员标识**：zlf update  
**新增注释**：4处
