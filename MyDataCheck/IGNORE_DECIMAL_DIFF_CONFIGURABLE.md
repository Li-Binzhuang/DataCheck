# 忽略小数差异功能实现说明（可配置阈值版）

## 功能概述

在 MyDataCheck 项目的 CSV 数据对比功能中，新增"忽略小数差异"配置项。当启用此选项时，差异绝对值小于设定阈值的数值差异将不被视为差异。阈值可通过前端配置进行修改，默认为 0.0001。

## 配置位置

在 Web 界面的数据对比配置面板中，"忽略小数差异"选项位于"忽略默认填充值"下方：

```
☐ 忽略默认填充值
  勾选后，-999 和 null 会被视为一致（默认不勾选）

☐ 忽略小数差异
  勾选后，差异绝对值小于设定阈值的不算作差异（默认不勾选）
  
  小数差异阈值: [0.0001] ← 可配置的输入框
```

## 实现细节

### 1. 前端修改

**文件**: `templates/index.html`
- 在"忽略默认填充值"配置项下方添加新的复选框和输入框
- 复选框 ID: `compare-ignore-decimal-diff`
- 输入框 ID: `compare-decimal-threshold`
- 默认值: 0.0001
- 步长: 0.00001
- 最小值: 0

**文件**: `static/js/data-compare.js`
- `executeCompare()`: 在配置对象中添加 `ignore_decimal_diff` 和 `decimal_threshold` 字段
- `saveCompareConfig()`: 在保存配置时包含 `ignore_decimal_diff`、`decimal_threshold` 和对应的全局默认值
- `loadCompareConfig()`: 在加载配置时恢复 `ignore_decimal_diff` 复选框和 `decimal_threshold` 输入框的值

### 2. 后端修改

**文件**: `common/value_comparator.py`
- 函数签名: `compare_values(csv_value, api_value, header="", ignore_default_fill=False, ignore_decimal_diff=False, decimal_threshold=0.0001)`
- 新增参数: 
  - `ignore_decimal_diff` (bool, 默认 False)
  - `decimal_threshold` (float, 默认 0.0001)
- 实现逻辑:
  - 当 `ignore_decimal_diff=True` 时，在数值比较前计算差异绝对值
  - 如果差异绝对值 < `decimal_threshold`，返回 True（认为一致）
  - 否则继续按原有逻辑进行比较

**文件**: `data_comparison/job/data_comparator.py`
- 函数签名: `compare_two_files(..., ignore_decimal_diff=False, decimal_threshold=0.0001)`
- 新增参数: 
  - `ignore_decimal_diff` (bool, 默认 False)
  - `decimal_threshold` (float, 默认 0.0001)
- 在调用 `compare_values()` 时传递 `ignore_decimal_diff` 和 `decimal_threshold` 参数
- 在日志输出中显示这两个参数的值

**文件**: `data_comparison/job/data_comparator_optimized.py`
- 同 `data_comparator.py` 的修改

**文件**: `web/routes/compare_routes.py`
- 在 `execute_compare_flow()` 中从配置获取 `ignore_decimal_diff` 和 `decimal_threshold` 值
- 在日志输出中显示这两个参数的值
- 在调用 `compare_two_files_func()` 时传递这两个参数

**文件**: `data_comparison/job/config_manager.py`
- 在默认配置中添加:
  - `default_ignore_decimal_diff: False`
  - `default_decimal_threshold: 0.0001`
- 在 `save_config()` 和 `load_config()` 中支持新配置项

### 3. 配置文件

**文件**: `data_comparison/config.json`
- 场景配置中新增字段: 
  - `ignore_decimal_diff` (bool)
  - `decimal_threshold` (float)
- 全局配置中新增字段: 
  - `default_ignore_decimal_diff` (bool, 默认 False)
  - `default_decimal_threshold` (float, 默认 0.0001)

## 工作流程

1. **用户在 UI 中配置**
   - 勾选"忽略小数差异"复选框
   - 在"小数差异阈值"输入框中输入自定义阈值（如 0.001）
   - 点击"执行对比"按钮

2. **前端处理**
   - 收集 `ignore_decimal_diff` 的值（true/false）
   - 收集 `decimal_threshold` 的值（数值）
   - 将其包含在请求配置对象中

3. **后端处理**
   - 接收配置参数
   - 将 `ignore_decimal_diff` 和 `decimal_threshold` 传递给 `compare_two_files()` 函数
   - 在对比过程中，每次调用 `compare_values()` 时传递这两个参数

4. **值对比逻辑**
   - 当两个值都是数值类型时，计算差异绝对值
   - 如果 `ignore_decimal_diff=True` 且差异 < `decimal_threshold`，返回 True
   - 否则按原有逻辑进行比较

5. **配置保存/加载**
   - 用户可以点击"保存配置"按钮保存当前配置（包括自定义阈值）
   - 下次加载配置时，`ignore_decimal_diff` 和 `decimal_threshold` 的值会被恢复

## 示例

### 场景 1: 启用忽略小数差异，阈值为 0.0001

```
CSV 值: 10.00001
API 值: 10.00002
差异: 0.00001 < 0.0001

结果: 认为一致 ✓
```

### 场景 2: 启用忽略小数差异，阈值为 0.001

```
CSV 值: 10.0001
API 值: 10.0011
差异: 0.001 < 0.001

结果: 认为一致 ✓
```

### 场景 3: 禁用忽略小数差异

```
CSV 值: 10.00001
API 值: 10.00002
差异: 0.00001 < 0.0001

结果: 认为不一致 ✗
```

### 场景 4: 差异超过阈值

```
CSV 值: 10.0001
API 值: 10.0002
差异: 0.0001 >= 0.0001

结果: 认为不一致 ✗（即使启用了忽略小数差异）
```

## 配置示例

保存后的 `data_comparison/config.json` 示例：

```json
{
  "scenarios": [
    {
      "name": "当前配置",
      "enabled": true,
      "description": "通过Web界面保存的配置",
      "sql_file": "file1.csv",
      "api_file": "file2.csv",
      "sql_key_column": [0, 2],
      "api_key_column": [0, 1],
      "sql_feature_start": 7,
      "api_feature_start": 2,
      "convert_feature_to_number": true,
      "ignore_default_fill": false,
      "ignore_decimal_diff": true,
      "decimal_threshold": 0.001,
      "output_prefix": "compare"
    }
  ],
  "global_config": {
    "default_convert_feature_to_number": true,
    "default_ignore_default_fill": false,
    "default_ignore_decimal_diff": true,
    "default_decimal_threshold": 0.001,
    "default_sql_key_column": [0, 2],
    "default_api_key_column": [0, 1],
    "default_sql_feature_start": 7,
    "default_api_feature_start": 2
  },
  "last_updated": "2026-03-11 17:45:00"
}
```

## 修改的文件列表

1. ✅ `templates/index.html` - 添加 UI 配置项（复选框和输入框）
2. ✅ `static/js/data-compare.js` - 前端逻辑处理
3. ✅ `common/value_comparator.py` - 核心对比逻辑
4. ✅ `data_comparison/job/data_comparator.py` - 主对比引擎
5. ✅ `data_comparison/job/data_comparator_optimized.py` - 优化版对比引擎
6. ✅ `web/routes/compare_routes.py` - 后端路由处理
7. ✅ `data_comparison/job/config_manager.py` - 配置管理

## 测试建议

1. **基本功能测试**
   - 勾选"忽略小数差异"，设置阈值为 0.0001，执行对比，验证小数差异是否被忽略
   - 取消勾选，执行对比，验证小数差异是否被记录

2. **阈值配置测试**
   - 设置阈值为 0.001，差异为 0.0005，验证是否被忽略
   - 设置阈值为 0.0001，差异为 0.0005，验证是否被记录

3. **边界值测试**
   - 差异 = 阈值 - 0.00001（应被忽略）
   - 差异 = 阈值（应被忽略）
   - 差异 = 阈值 + 0.00001（应被记录）

4. **配置保存/加载测试**
   - 勾选"忽略小数差异"，设置阈值为 0.001，点击"保存配置"
   - 刷新页面，点击"加载配置"，验证复选框和输入框的值是否恢复

5. **与其他选项的组合测试**
   - 同时启用"忽略默认填充值"和"忽略小数差异"
   - 验证两个选项是否能正确协作

## 注意事项

- 阈值可以是任何非负数，建议范围在 0 到 1 之间
- 此选项仅对数值类型的数据有效
- 字符串类型的数据不受此选项影响
- 当启用此选项时，可能会导致某些微小的数值差异被忽略，请根据实际业务需求决定是否启用
- 阈值过大可能导致实际差异被忽略，请谨慎设置
