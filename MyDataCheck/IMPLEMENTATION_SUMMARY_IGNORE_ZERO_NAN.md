# 实现总结：忽略0和NaN的差异功能

## 功能概述

在 CSV 数据对比模块中新增了一个选项：**忽略0和NaN的差异**

该选项允许用户在数据对比时将 `0` 和 `NaN` 视为相同的值，用于处理不同系统对缺失值的不同表示方式。

## 修改清单

### 1. 前端 UI 修改

**文件**: `MyDataCheck/templates/index.html`

**修改内容**:
- 在"忽略默认填充值"选项下方新增复选框
- ID: `compare-ignore-zero-nan`
- 标签: "忽略0和NaN的差异"
- 说明文字: "勾选后，0 和 NaN 会被视为一致（默认不勾选）"

**代码位置**: 第 338-365 行

```html
<div class="form-group">
    <div class="checkbox-group">
        <input type="checkbox" id="compare-ignore-zero-nan">
        <label for="compare-ignore-zero-nan" style="margin: 0;">忽略0和NaN的差异</label>
    </div>
    <p style="color: #666; font-size: 10px; margin-top: 3px; margin-left: 22px; line-height: 1.4;">
        勾选后，0 和 NaN 会被视为一致（默认不勾选）
    </p>
</div>
```

### 2. JavaScript 前端逻辑修改

**文件**: `MyDataCheck/static/js/data-compare.js`

**修改内容**:

#### 2.1 executeCompare() 函数
- 新增参数收集: `ignore_zero_nan: document.getElementById('compare-ignore-zero-nan').checked`
- 将参数传递给后端 API

**代码位置**: 第 180-240 行

```javascript
const config = {
    // ... 其他参数 ...
    ignore_zero_nan: document.getElementById('compare-ignore-zero-nan').checked,
    // ... 其他参数 ...
};
```

#### 2.2 saveCompareConfig() 函数
- 在 scenarios 中保存 `ignore_zero_nan` 参数
- 在 global_config 中保存 `default_ignore_zero_nan` 参数

**代码位置**: 第 349-415 行

```javascript
scenarios: [{
    // ... 其他参数 ...
    ignore_zero_nan: document.getElementById('compare-ignore-zero-nan').checked,
    // ... 其他参数 ...
}],
global_config: {
    // ... 其他参数 ...
    default_ignore_zero_nan: document.getElementById('compare-ignore-zero-nan').checked,
    // ... 其他参数 ...
}
```

#### 2.3 loadCompareConfig() 函数
- 从配置文件加载 `ignore_zero_nan` 参数
- 恢复复选框状态

**代码位置**: 第 418-560 行

```javascript
if (scenario.ignore_zero_nan !== undefined) {
    document.getElementById('compare-ignore-zero-nan').checked = scenario.ignore_zero_nan;
    console.log('[DEBUG] 设置忽略0和NaN的差异:', scenario.ignore_zero_nan);
}
```

### 3. 后端路由修改

**文件**: `MyDataCheck/web/routes/compare_routes.py`

**修改内容**:
- 在 execute_compare_flow() 函数中，从配置读取 `ignore_zero_nan` 参数
- 传递给 compare_two_files_func() 函数

**代码位置**: 第 115-130 行

```python
comparison_results = compare_two_files_func(
    file1_path,
    file2_path,
    sql_key_col,
    api_key_col,
    config['feature_start_1'],
    config['feature_start_2'],
    config.get('convert_feature_to_number', True),
    config.get('ignore_default_fill', False),
    config.get('ignore_zero_nan', False),  # 新增参数
    config.get('ignore_decimal_diff', False),
    config.get('decimal_threshold', 0.0001),
    config.get('column_prefix', ''),
    config.get('column_suffix', '')
)
```

### 4. 核心比较逻辑修改

**文件**: `MyDataCheck/common/value_comparator.py`

**修改内容**:
- 更新 compare_values() 函数签名，新增 `ignore_zero_nan` 参数
- 实现 0 和 NaN 的等价性检查逻辑

**代码位置**: 第 46-100 行

```python
def compare_values(csv_value: Any, api_value: Any, header: str = "", 
                   ignore_default_fill: bool = False, 
                   ignore_zero_nan: bool = False,  # 新增参数
                   ignore_decimal_diff: bool = False, 
                   decimal_threshold: float = 0.0001) -> bool:
    
    # ... 其他逻辑 ...
    
    # 如果启用了忽略0和NaN差异选项
    if ignore_zero_nan:
        # 检查CSV值是否为 0 或 NaN
        csv_is_zero_or_nan = False
        if not csv_null:
            try:
                csv_num = float(str(csv_value).strip())
                # 检查是否为 0 或 NaN
                if csv_num == 0 or (csv_num != csv_num):  # NaN != NaN 是 True
                    csv_is_zero_or_nan = True
            except (ValueError, TypeError):
                pass
        
        # 检查API值是否为 0 或 NaN
        api_is_zero_or_nan = False
        if not api_null:
            try:
                api_num = float(str(api_value).strip())
                # 检查是否为 0 或 NaN
                if api_num == 0 or (api_num != api_num):  # NaN != NaN 是 True
                    api_is_zero_or_nan = True
            except (ValueError, TypeError):
                pass
        
        # 如果两个值都是 0 或 NaN，则认为一致
        if csv_is_zero_or_nan and api_is_zero_or_nan:
            return True
```

### 5. 数据对比模块修改

#### 5.1 data_comparator.py

**文件**: `MyDataCheck/data_comparison/job/data_comparator.py`

**修改内容**:
- 更新 compare_two_files() 函数签名，新增 `ignore_zero_nan` 参数
- 在调用 compare_values() 时传递该参数
- 在日志输出中显示该参数状态

**代码位置**: 第 54-70 行（函数签名）、第 109-112 行（日志）、第 345-347 行（调用）

```python
def compare_two_files(
    sql_file_path: str,
    api_file_path: str,
    sql_key_column,
    api_key_column,
    sql_feature_start: int = 1,
    api_feature_start: int = 1,
    convert_feature_to_number: bool = True,
    ignore_default_fill: bool = False,
    ignore_zero_nan: bool = False,  # 新增参数
    ignore_decimal_diff: bool = False,
    decimal_threshold: float = 0.0001,
    column_prefix: str = '',
    column_suffix: str = ''
):
    # ...
    print(f"忽略0和NaN的差异: {ignore_zero_nan}")
    # ...
    if not compare_values(api_value, sql_value, feature_name, 
                         ignore_default_fill, ignore_zero_nan,  # 新增参数
                         ignore_decimal_diff, decimal_threshold):
        differences_dict[(key_value, feature_name)] = (api_value, sql_value, cust_no, time_value)
```

#### 5.2 data_comparator_optimized.py

**文件**: `MyDataCheck/data_comparison/job/data_comparator_optimized.py`

**修改内容**:
- 同 data_comparator.py 的修改
- 更新函数签名、日志输出和函数调用

**代码位置**: 第 87-103 行（函数签名）、第 130-133 行（日志）、第 346-348 行（调用）

## 功能验证

### 测试用例

```python
from common.value_comparator import compare_values

# 测试1: 0 和 NaN 被视为一致（启用选项）
assert compare_values(0, float('nan'), ignore_zero_nan=True) == True
print("✅ 测试1通过: 0 和 NaN 一致")

# 测试2: 0 和 0 一致
assert compare_values(0, 0, ignore_zero_nan=True) == True
print("✅ 测试2通过: 0 和 0 一致")

# 测试3: NaN 和 NaN 一致
assert compare_values(float('nan'), float('nan'), ignore_zero_nan=True) == True
print("✅ 测试3通过: NaN 和 NaN 一致")

# 测试4: 0 和 1 不一致
assert compare_values(0, 1, ignore_zero_nan=True) == False
print("✅ 测试4通过: 0 和 1 不一致")

# 测试5: 禁用选项时，0 和 NaN 不一致
assert compare_values(0, float('nan'), ignore_zero_nan=False) == False
print("✅ 测试5通过: 禁用选项时 0 和 NaN 不一致")

# 测试6: 字符串 "0" 和 "NaN" 一致
assert compare_values("0", "NaN", ignore_zero_nan=True) == True
print("✅ 测试6通过: 字符串 '0' 和 'NaN' 一致")

# 测试7: null 不被视为 0 或 NaN
assert compare_values(None, 0, ignore_zero_nan=True) == False
print("✅ 测试7通过: null 不被视为 0")

# 测试8: 与其他选项组合使用
assert compare_values(-999, None, ignore_default_fill=True, ignore_zero_nan=True) == True
print("✅ 测试8通过: 与其他选项组合使用")
```

## 向后兼容性

✅ **完全向后兼容**

- 新参数默认值为 `False`（禁用）
- 现有代码无需修改
- 现有配置文件仍然有效
- 旧版本的配置文件加载时，新参数会使用默认值

## 配置文件格式

### 保存的配置示例

```json
{
  "scenarios": [
    {
      "name": "当前配置",
      "enabled": true,
      "description": "通过Web界面保存的配置",
      "sql_file": "file1.csv",
      "api_file": "file2.csv",
      "sql_key_column": 0,
      "api_key_column": 0,
      "sql_feature_start": 1,
      "api_feature_start": 1,
      "column_prefix": "",
      "column_suffix": "",
      "convert_feature_to_number": true,
      "ignore_default_fill": false,
      "ignore_zero_nan": false,
      "ignore_decimal_diff": false,
      "decimal_threshold": 0.0001,
      "output_prefix": "compare"
    }
  ],
  "global_config": {
    "default_convert_feature_to_number": true,
    "default_ignore_default_fill": false,
    "default_ignore_zero_nan": false,
    "default_ignore_decimal_diff": false,
    "default_decimal_threshold": 0.0001,
    "default_sql_key_column": 0,
    "default_api_key_column": 0,
    "default_sql_feature_start": 1,
    "default_api_feature_start": 1,
    "default_column_prefix": "",
    "default_column_suffix": ""
  }
}
```

## 文档

新增文档文件：
- `IGNORE_ZERO_NAN_FEATURE.md` - 详细功能说明
- `IGNORE_ZERO_NAN_QUICK_START.md` - 快速开始指南
- `IMPLEMENTATION_SUMMARY_IGNORE_ZERO_NAN.md` - 本文件

## 总结

✅ 功能完整实现
✅ 前后端集成完成
✅ 配置保存/加载支持
✅ 向后兼容
✅ 代码无错误
✅ 文档完整

该功能已准备好投入使用。
