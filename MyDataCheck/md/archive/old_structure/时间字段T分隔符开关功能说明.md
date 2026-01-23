# 时间字段T分隔符开关功能说明

## 功能概述

为时间字段添加了可配置的T分隔符开关，允许用户选择时间格式中日期和时间之间是否使用T分隔符。

## 时间格式说明

- **使用T分隔符**（`add_t_separator=true`）：`2025-01-01T12:00:00.000`
- **不使用T分隔符**（`add_t_separator=false`）：`2025-01-01 12:00:00.000`

## 修改内容

### 1. 后端代码修改 (`fetch_api_data.py`)

#### 1.1 修改 `normalize_timestamp()` 方法
- 添加 `add_t_separator` 参数（默认 `True`，保持向后兼容）
- 根据参数决定使用 `T` 或空格作为分隔符
- 支持将现有格式转换为指定格式

```python
def normalize_timestamp(self, time_str: str, add_t_separator: bool = True) -> str:
    """
    标准化时间戳格式
    
    Args:
        time_str: 原始时间字符串
        add_t_separator: 是否在日期和时间之间加 T 分隔符（默认True）
        
    Returns:
        - 如果 add_t_separator=True: YYYY-MM-DDTHH:MM:SS.SSS
        - 如果 add_t_separator=False: YYYY-MM-DD HH:MM:SS.SSS
    """
```

#### 1.2 修改 `process_row()` 方法
- 从 `api_params` 配置中读取 `add_t_separator` 设置
- 传递给 `normalize_timestamp()` 方法

```python
# 获取是否加T分隔符的配置（默认True，保持向后兼容）
add_t_separator = param_config.get("add_t_separator", True)

# 标准化时间格式
param_value = self.normalize_timestamp(param_value, add_t_separator=add_t_separator)
```

### 2. 前端Web页面修改 (`templates/index.html`)

#### 2.1 UI界面更新
- 在每个接口参数配置项中添加"加T分隔符"复选框
- 复选框仅在"时间字段"被勾选时启用
- 默认勾选（保持向后兼容）

```html
<div class="form-group" style="flex: 1;">
    <label style="display: flex; align-items: center;">
        <input type="checkbox" class="param-add-t-separator" 
               ${param.add_t_separator !== false ? 'checked' : ''} 
               ${param.is_time_field ? '' : 'disabled'} 
               style="margin-right: 5px;">
        加T分隔符
    </label>
</div>
```

#### 2.2 JavaScript函数

**添加 `toggleTSeparator()` 函数**：
- 当"时间字段"复选框状态改变时调用
- 自动启用/禁用"加T分隔符"复选框
- 如果启用且未初始化，默认勾选

```javascript
function toggleTSeparator(scenarioId, paramIndex) {
    // 根据时间字段复选框状态，启用/禁用T分隔符复选框
    tSeparatorCheckbox.disabled = !isTimeField;
}
```

**修改 `saveConfig()` 函数**：
- 收集 `add_t_separator` 配置值
- 仅在时间字段被勾选时保存该配置

```javascript
const addTSeparator = item.querySelector('.param-add-t-separator')?.checked !== false;
if (isTimeField) {
    paramObj.add_t_separator = addTSeparator;
}
```

#### 2.3 更新提示信息
- 在参数配置区域添加了关于T分隔符的说明

## 配置格式

### JSON配置示例

```json
{
  "api_params": [
    {
      "param_name": "custNo",
      "column_index": 0,
      "is_time_field": false
    },
    {
      "param_name": "baseTime",
      "column_index": 2,
      "is_time_field": true,
      "add_t_separator": true  // 使用T分隔符: 2025-01-01T12:00:00.000
    },
    {
      "param_name": "createTime",
      "column_index": 3,
      "is_time_field": true,
      "add_t_separator": false  // 不使用T分隔符: 2025-01-01 12:00:00.000
    }
  ]
}
```

## 使用说明

### Web界面操作

1. **添加参数**：点击"➕ 添加参数"按钮
2. **配置参数**：
   - 输入参数名称（如：`baseTime`）
   - 输入列索引（如：`2`）
   - 勾选"时间字段"复选框
   - 勾选/取消"加T分隔符"复选框（仅在时间字段勾选时可用）

3. **保存配置**：点击"💾 保存配置"按钮

### 配置行为

- **默认行为**：如果未设置 `add_t_separator`，默认值为 `true`（使用T分隔符）
- **向后兼容**：旧配置文件中没有 `add_t_separator` 字段时，自动使用T分隔符
- **动态控制**：每个时间字段可以独立配置是否使用T分隔符

## 测试验证

### 测试用例

1. **输入**: `2025-01-01 12:00:00`, `add_t_separator=true`
   - **输出**: `2025-01-01T12:00:00.000` ✓

2. **输入**: `2025-01-01 12:00:00`, `add_t_separator=false`
   - **输出**: `2025-01-01 12:00:00.000` ✓

3. **输入**: `2025-01-01T12:00:00`, `add_t_separator=false`
   - **输出**: `2025-01-01 12:00:00.000` ✓

4. **输入**: `2025-01-01T12:00:00.123`, `add_t_separator=true`
   - **输出**: `2025-01-01T12:00:00.123` ✓

## 兼容性说明

- ✅ **向后兼容**：默认使用T分隔符，与原有行为一致
- ✅ **灵活配置**：每个时间字段可以独立配置
- ✅ **自动处理**：支持多种输入格式的自动转换

## 注意事项

1. **仅对时间字段生效**：`add_t_separator` 配置仅在 `is_time_field=true` 时生效
2. **默认值**：如果配置中未指定 `add_t_separator`，默认值为 `true`
3. **格式转换**：代码会自动处理输入格式（T或空格），转换为配置指定的格式

## 总结

通过添加T分隔符开关，现在可以灵活控制时间字段的输出格式，满足不同接口对时间格式的要求。该功能完全向后兼容，不影响现有配置的使用。
