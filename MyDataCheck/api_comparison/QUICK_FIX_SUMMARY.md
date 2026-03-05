# 接口数据对比 - 入参显示修复总结

## 修复内容

✅ **修复了输出报告中 `applyId` 和 `request_time` 列显示错误的问题**

## 问题

输出报告中显示的是CSV文件中的原始值，而不是实际发送给接口的参数值。

## 解决方案

修改 `streaming_comparator.py` 中的 `_compare_single_row()` 方法，优先从 `request_params` 中获取参数值。

## 修改文件

- `api_comparison/job/streaming_comparator.py`

## 修改点

### 获取 request_time（baseTime）
```python
# 修改前
use_create_time = request_params.get("baseTime", original_values.get("baseTime", ""))

# 修改后
use_create_time = request_params.get("baseTime", "")
```

### 获取 applyId
```python
# 修改前
apply_id = original_values.get("applyId", original_values.get("apply_id", ""))

# 修改后
apply_id = request_params.get("applyId", request_params.get("apply_id", ""))
if not apply_id:
    apply_id = original_values.get("applyId", original_values.get("apply_id", ""))
```

## 效果

### 修改前
```
特征名 | applyId | request_time | CSV值 | API值
------|---------|--------------|-------|------
feat1 | 123     | 2026-03-05   | 100   | 99
```

### 修改后
```
特征名 | applyId | request_time | CSV值 | API值
------|---------|--------------|-------|------
feat1 | 123     | 2026-03-05   | 100   | 99
      |         | 10:00:01     |       |
      |         | (实际发送值)  |       |
```

## 验证方法

1. 查看输出报告中的 `request_time` 列
2. 对比接口日志中的 `baseTime` 参数
3. 两者应该一致

## 相关文档

- [API参数显示修复详细说明](API_PARAMS_DISPLAY_FIX.md)
- [接口数据对比使用指南](README.md)

---

**修改日期**: 2026-03-05  
**状态**: ✅ 已完成
