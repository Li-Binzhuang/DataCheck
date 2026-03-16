# 修复：忽略0和NaN的差异 - 包括空格和其他空值表示

## 问题描述

在使用"忽略0和NaN的差异"选项时，某些特征的值为 `0` 和空格 `" "` 没有被正确忽略。

例如：
- `local_all_sms_balance_bank_type_latest_15d_v3`
- `local_all_sms_balance_cashvia_latest_15d_v3`

这些特征中，一个数据源返回 `0`，另一个返回空格 `" "`，但仍然被标记为差异。

## 根本原因

原始实现只处理了以下情况：
- 数值 `0`
- 数值 `NaN`
- `null` 值

但没有处理以下情况：
- 空格 `" "`
- 多个空格 `"  "`
- 字符串 `"NaN"`, `"nan"`, `"NA"`, `"N/A"`
- 空字符串 `""`

## 解决方案

### 修改的文件

**文件**: `MyDataCheck/common/value_comparator.py`

### 修改内容

更新 `compare_values()` 函数中的 `ignore_zero_nan` 逻辑，现在会检查以下所有情况：

```python
# 如果启用了忽略0和NaN差异选项
if ignore_zero_nan:
    # 检查CSV值是否为 0、NaN、空格 或 null
    csv_is_zero_or_nan_or_empty = False
    
    # 首先检查是否为空值（包括空格）
    if csv_null:
        csv_is_zero_or_nan_or_empty = True
    else:
        try:
            csv_num = float(str(csv_value).strip())
            # 检查是否为 0 或 NaN
            if csv_num == 0 or (csv_num != csv_num):  # NaN != NaN 是 True
                csv_is_zero_or_nan_or_empty = True
        except (ValueError, TypeError):
            # 无法转换为数字，检查是否为空格或其他空值表示
            csv_str_stripped = str(csv_value).strip()
            if csv_str_stripped == "" or csv_str_stripped.lower() in ["nan", "na", "n/a"]:
                csv_is_zero_or_nan_or_empty = True
    
    # 同样检查 API 值...
    
    # 如果两个值都是 0、NaN、空格 或 null，则认为一致
    if csv_is_zero_or_nan_or_empty and api_is_zero_or_nan_or_empty:
        return True
```

## 现在支持的等价值

启用"忽略0和NaN的差异"选项后，以下值被视为等价：

### 数值表示
- `0` (数字)
- `"0"` (字符串)
- `0.0` (浮点数)
- `float('nan')` (NaN)

### 空值表示
- `None` (Python None)
- `""` (空字符串)
- `" "` (空格)
- `"  "` (多个空格)
- `"null"` (字符串)
- `"none"` (字符串)

### NaN 表示
- `"NaN"` (字符串)
- `"nan"` (字符串)
- `"NA"` (字符串)
- `"N/A"` (字符串)
- `"n/a"` (字符串)

## 测试结果

✅ **所有 31 个测试用例通过**

### 测试覆盖范围

1. **基础测试** (4 个)
   - 0 和 NaN 一致
   - 0 和 0 一致
   - NaN 和 NaN 一致
   - 0 和 1 不一致

2. **字符串测试** (4 个)
   - 字符串 '0' 和 'NaN' 一致
   - 字符串 '0' 和 'nan' 一致
   - 字符串 '0' 和 'NA' 一致
   - 字符串 '0' 和 'N/A' 一致

3. **空格测试** (3 个) ⭐ 关键修复
   - 字符串 '0' 和空格 ' ' 一致
   - 字符串 '0' 和多个空格 '  ' 一致
   - 数字 0 和空格 ' ' 一致

4. **null 测试** (3 个)
   - 字符串 '0' 和 None 一致
   - 字符串 '0' 和 'null' 一致
   - 字符串 '0' 和 'none' 一致

5. **空字符串测试** (2 个)
   - 字符串 '0' 和空字符串 '' 一致
   - 空字符串 '' 和空字符串 '' 一致

6. **NaN 各种表示** (3 个)
   - 字符串 'NaN' 和空格 ' ' 一致
   - 字符串 'nan' 和多个空格 '  ' 一致
   - 字符串 'NA' 和 None 一致

7. **不应该一致的情况** (3 个)
   - 字符串 '1' 和空格 ' ' 不一致
   - 字符串 '1' 和 'NaN' 不一致
   - 字符串 '0' 和 '1' 不一致

8. **禁用选项测试** (5 个)
   - 验证禁用时的默认行为

9. **与其他选项组合** (4 个)
   - 与 ignore_default_fill 组合
   - 与 ignore_decimal_diff 组合

## 使用示例

### 场景：处理不同系统的缺失值表示

**数据对比前**（未启用选项）：
```
特征: local_all_sms_balance_bank_type_latest_15d_v3
CSV值: 0
API值: (空格)
结果: ❌ 差异
```

**启用"忽略0和NaN的差异"后**：
```
特征: local_all_sms_balance_bank_type_latest_15d_v3
CSV值: 0
API值: (空格)
结果: ✅ 一致
```

## 向后兼容性

✅ **完全向后兼容**

- 现有配置不需要修改
- 默认行为不变（选项默认禁用）
- 现有的对比结果不受影响

## 文件修改清单

- ✅ `MyDataCheck/common/value_comparator.py` - 更新 compare_values() 函数
- ✅ `MyDataCheck/test_ignore_zero_nan_fix.py` - 新增完整测试套件

## 验证方法

运行测试套件验证修复：

```bash
python MyDataCheck/test_ignore_zero_nan_fix.py
```

预期输出：
```
✅ 所有测试通过！
```

## 版本信息

- **修复版本**: 1.1
- **修复日期**: 2026-03-12
- **影响范围**: CSV 数据对比模块
- **向后兼容**: 是
