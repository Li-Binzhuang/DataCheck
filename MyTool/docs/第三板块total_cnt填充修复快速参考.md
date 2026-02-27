# 第三板块 total_cnt 填充修复 - 快速参考

## 问题

第三板块`creditos_{w}d_total_cnt`特征错误地使用了`fillna(-999)`，应该使用`fillna(0)`。

---

## 修复

### 修改位置
**文件**: `CDC/第三板块衍生.ipynb`  
**行号**: 610

### 修改内容

**修改前**:
```python
# zlf update: 特征值为空时填充-999
total = sub.groupby("apply_id").size().reindex(base.index).fillna(-999).astype(int)
```

**修改后**:
```python
# zlf update: cnt特征空值填充0
total = sub.groupby("apply_id").size().reindex(base.index).fillna(0).astype(int)
```

---

## 影响特征

8个total_cnt特征：
- `creditos_7d_total_cnt`
- `creditos_15d_total_cnt`
- `creditos_30d_total_cnt`
- `creditos_60d_total_cnt`
- `creditos_90d_total_cnt`
- `creditos_180d_total_cnt`
- `creditos_360d_total_cnt`
- `creditos_720d_total_cnt`

---

## 填充规则

| 特征类型 | 填充值 | 原因 |
|---------|-------|------|
| `*_cnt` | **0** | 计数为0，不是缺失值 |
| `*_ratio` | -999 | 无法计算，标记为缺失 |
| `*_mean` | -999 | 无法计算，标记为缺失 |
| `*_std` | -999 | 无法计算，标记为缺失 |

---

## 验证

### 检查修复结果

```python
# 检查total_cnt特征的最小值
for w in [7, 15, 30, 60, 90, 180, 360, 720]:
    col = f"creditos_{w}d_total_cnt"
    min_val = features[col].min()
    print(f"{col}: min={min_val}")
    # 应该输出 min=0，而不是 min=-999
```

### 预期结果

✅ 所有`creditos_*d_total_cnt`特征的最小值应该是0  
❌ 不应该出现-999

---

## 其他板块

已检查其他三个板块，确认无此问题：
- ✅ 第一板块衍生.ipynb
- ✅ 第二板块衍生.ipynb
- ✅ BOSS板块衍生.ipynb

---

## 相关文档

- [第三板块total_cnt填充修复.md](./第三板块total_cnt填充修复.md) - 完整文档
- [四个衍生脚本最近修改总结.md](./四个衍生脚本最近修改总结.md) - 所有修改

---

**修复日期**: 2026-01-29  
**状态**: ✅ 已修复
