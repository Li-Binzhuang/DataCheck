# 接口参数列显示修复说明

## 问题描述
在 `_compare_analysis_report.csv` 文件中，B 列和 C 列应该显示接口入参的字段名和值，但之前显示的是固定的字段名（`cust_no`、`use_credit_apply_id`、`use_create_time`），而不是配置文件中定义的实际入参字段名和值。

## 修复内容

### 1. 修改 `common/report_generator.py`
- 在 `write_analysis_record_csv` 函数中添加 `api_params` 参数
- 从 `api_params` 配置中动态获取入参字段名，用于生成表头
- 从原始行数据中根据 `api_params` 的 `column_index` 获取实际的入参值
- 表头现在会根据配置动态生成，例如：`["特征名", "custNo", "dateTimeStr", "CSV值", "API值"]`

### 2. 修改 `api_comparison/job/compare_api_data.py`
- 在 `DataComparator.__init__` 中添加 `api_params` 参数
- 在调用 `write_analysis_record_csv` 时传递 `api_params` 参数

### 3. 修改 `api_comparison/job/process_executor.py`
- 在 `compare_data_step` 函数中添加 `api_params` 参数
- 在创建 `DataComparator` 实例时传递 `api_params` 参数
- 在调用 `compare_data_step` 时传递 `api_params` 参数

## 配置示例

在 `config.json` 中的 `api_params` 配置：

```json
"api_params": [
  {
    "param_name": "custNo",
    "column_index": 1,
    "is_time_field": false
  },
  {
    "param_name": "dateTimeStr",
    "column_index": 2,
    "is_time_field": true,
    "add_t_separator": true,
    "convert_date_to_time": true
  }
]
```

## 输出效果

修复后，`_compare_analysis_report.csv` 的表头和数据将正确显示：

### 之前（错误）：
```
特征名,cust_no,use_credit_apply_id,use_create_time,CSV值,API值
```

### 修复后（正确）：
```
特征名,custNo,dateTimeStr,CSV值,API值
```

数据行也会从原始 CSV 文件的对应列（column_index）中提取实际的入参值。

## 兼容性
- 如果配置文件中没有 `api_params`，代码会使用默认字段名保持向后兼容
- 所有现有功能（差值计算、time_now 字段等）都保持不变

## 测试建议
1. 运行接口对比任务
2. 检查生成的 `_compare_analysis_report.csv` 文件
3. 确认 B 列和 C 列（以及更多列，如果有更多入参）显示的是配置文件中定义的入参字段名
4. 确认数据行中的值是从原始 CSV 文件的正确列索引中提取的
