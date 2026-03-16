# CSV 数据对比 - 忽略0和NaN的差异功能

## 功能说明

在 CSV 数据对比模块中新增了一个选项：**忽略0和NaN的差异**

该选项位于"忽略默认填充值"下方，用于处理数据中 0、NaN、空格 和其他空值表示被视为等价的场景。

## 功能详情

### 选项位置
- **页面**: CSV数据对比
- **位置**: 配置面板 → "忽略默认填充值"下方
- **默认状态**: 不勾选（关闭）

### 功能行为

#### 勾选时（启用）
当勾选"忽略0和NaN的差异"选项时，以下值被视为等价：

**数值表示**:
- `0` (数字)
- `"0"` (字符串)
- `0.0` (浮点数)

**空值表示**:
- `None` (Python None)
- `""` (空字符串)
- `" "` (空格)
- `"  "` (多个空格)
- `"null"` (字符串)
- `"none"` (字符串)

**NaN 表示**:
- `float('nan')` (NaN)
- `"NaN"` (字符串)
- `"nan"` (字符串)
- `"NA"` (字符串)
- `"N/A"` (字符串)

#### 不勾选时（禁用）
按照现有逻辑进行比较，这些值被视为不同的值。

### 使用场景

1. **数据缺失处理**
   - 某些系统用 `0` 表示缺失值
   - 某些系统用空格 `" "` 表示缺失值
   - 某些系统用 `NaN` 表示缺失值
   - 需要将这些都视为等价

2. **浮点数计算结果**
   - 某些计算结果为 `0`
   - 某些计算结果为 `NaN`
   - 需要忽略这种差异

3. **数据源差异**
   - 不同数据源对缺失值的表示方式不同
   - 需要统一处理

## 技术实现

### 后端逻辑

在 `MyDataCheck/common/value_comparator.py` 中的 `compare_values()` 函数中实现：

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

### 前端集成

1. **HTML 界面** (`MyDataCheck/templates/index.html`)
   - 新增复选框：`compare-ignore-zero-nan`
   - 显示说明文字

2. **JavaScript 处理** (`MyDataCheck/static/js/data-compare.js`)
   - 在 `executeCompare()` 中收集该选项
   - 在 `saveCompareConfig()` 中保存该选项
   - 在 `loadCompareConfig()` 中加载该选项

3. **后端路由** (`MyDataCheck/web/routes/compare_routes.py`)
   - 从配置中读取 `ignore_zero_nan` 参数
   - 传递给 `compare_two_files()` 函数

### 数据对比模块更新

更新了以下文件中的 `compare_two_files()` 函数：
- `MyDataCheck/data_comparison/job/data_comparator.py`
- `MyDataCheck/data_comparison/job/data_comparator_optimized.py`

新增参数：
```python
ignore_zero_nan: bool = False  # 是否忽略0和NaN的差异
```

## 配置保存和加载

### 配置文件格式

配置会保存到 `data_comparison/config.json`，包含新参数：

```json
{
  "scenarios": [{
    "ignore_zero_nan": false,
    ...
  }],
  "global_config": {
    "default_ignore_zero_nan": false,
    ...
  }
}
```

### 配置优先级

1. 用户在 Web 界面勾选的选项（最高优先级）
2. 加载的配置文件中的设置
3. 默认值：`false`（不勾选）

## 与其他选项的关系

### 与"忽略默认填充值"的区别

| 选项 | 处理的值 | 说明 |
|------|---------|------|
| 忽略默认填充值 | `-999` 和 `null` | 处理默认的缺失值标记 |
| 忽略0和NaN的差异 | `0` 和 `NaN` | 处理计算结果或特殊缺失值 |

### 与"忽略小数差异"的关系

- **忽略小数差异**: 处理浮点数精度问题（如 `8.0001` 和 `8.0002`）
- **忽略0和NaN的差异**: 处理特定值的等价性（`0` 和 `NaN`）

这两个选项可以同时启用，互不影响。

## 使用示例

### 场景1：处理缺失值差异

**原始数据对比结果**（未启用选项）：
```
特征: amount
CSV值: 0
API值: NaN
结果: ❌ 差异
```

**启用"忽略0和NaN的差异"后**：
```
特征: amount
CSV值: 0
API值: NaN
结果: ✅ 一致
```

### 场景2：多个选项组合使用

```
启用选项:
- ✅ 忽略默认填充值 (处理 -999 和 null)
- ✅ 忽略0和NaN的差异 (处理 0 和 NaN)
- ✅ 忽略小数差异 (阈值: 0.0001)

效果: 对比更加宽松，只关注实质性差异
```

## 注意事项

1. **null 不等于 0 或 NaN**
   - 当启用此选项时，`null` 不会被视为 `0` 或 `NaN`
   - 如果需要处理 `null`，请使用"忽略默认填充值"选项

2. **字符串 "NaN" 的处理**
   - 字符串 `"NaN"` 会被转换为浮点数 `NaN`
   - 字符串 `"0"` 会被转换为浮点数 `0`

3. **性能影响**
   - 启用此选项会增加少量计算开销（浮点数转换和检查）
   - 对大文件的影响可以忽略不计

## 测试

可以使用以下测试用例验证功能：

```python
from common.value_comparator import compare_values

# 测试1: 0 和 NaN 被视为一致
assert compare_values(0, float('nan'), ignore_zero_nan=True) == True

# 测试2: 0 和 0 一致
assert compare_values(0, 0, ignore_zero_nan=True) == True

# 测试3: NaN 和 NaN 一致
assert compare_values(float('nan'), float('nan'), ignore_zero_nan=True) == True

# 测试4: 0 和 1 不一致
assert compare_values(0, 1, ignore_zero_nan=True) == False

# 测试5: 禁用选项时，0 和 NaN 不一致
assert compare_values(0, float('nan'), ignore_zero_nan=False) == False
```

## 相关文件修改清单

### 前端文件
- ✅ `MyDataCheck/templates/index.html` - 新增 UI 元素
- ✅ `MyDataCheck/static/js/data-compare.js` - 处理参数收集和配置

### 后端文件
- ✅ `MyDataCheck/common/value_comparator.py` - 核心比较逻辑
- ✅ `MyDataCheck/data_comparison/job/data_comparator.py` - 函数签名和调用
- ✅ `MyDataCheck/data_comparison/job/data_comparator_optimized.py` - 函数签名和调用
- ✅ `MyDataCheck/web/routes/compare_routes.py` - 路由处理

## 版本信息

- **功能版本**: 1.0
- **发布日期**: 2026-03-12
- **兼容性**: 向后兼容（默认禁用）
