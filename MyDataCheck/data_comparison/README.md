# 数据对比模块

## 功能概述
数据对比模块用于对比两个CSV或XLSX文件的数据差异，支持灵活的列配置和特征值转换。

## 目录结构
```
data_comparison/
├── __init__.py              # 模块初始化文件
├── README.md                # 本文档
├── config.json              # 配置文件
├── execute_data_comparison.py  # 执行脚本
└── job/                     # 核心功能模块
    ├── __init__.py
    ├── data_comparator.py   # 数据对比器
    └── report_generator.py  # 报告生成器
```

## 主要功能

### 1. 文件对比
- 支持CSV和XLSX格式
- 自动编码检测（UTF-8、GBK、GB2312）
- 支持大文件处理

### 2. 配置选项
- **主键列配置**：分别配置Sql文件和接口文件的主键列索引，支持单列或多列组合主键
- **特征列配置**：分别配置两个文件的特征起始列索引
- **转换功能**：可选择是否将特征值转换为数值类型
- **输出前缀**：自定义输出文件名前缀

### 3. 数据处理
- 自动去除引号（单引号和双引号）
- 字符串转数值（可选）
- 智能识别cust_no和时间字段
- 主键值和cust_no的智能获取

### 4. 结果输出
生成以下报告文件：
- 差异特征汇总
- 差异数据明细
- 特征统计
- 全量数据合并
- 仅在Sql文件中的数据
- 仅在接口文件中的数据

## 使用方法

### 通过Web界面
1. 访问Web界面的"数据对比"Tab
2. 上传Sql文件和接口文件
3. 配置主键列和特征起始列索引
4. 选择是否转换特征值为数值
5. 点击"执行对比"按钮

### 通过命令行
```bash
python execute_data_comparison.py
```

### 通过Python代码
```python
from data_comparison.job.data_comparator import compare_csv_files
from data_comparison.job.report_generator import generate_reports

# 执行对比
results = compare_csv_files(
    sql_file_path="path/to/sql_file.csv",
    api_file_path="path/to/api_file.csv",
    sql_key_column=0,
    api_key_column=0,
    sql_feature_start=1,
    api_feature_start=1,
    convert_feature_to_number=True
)

# 生成报告
generate_reports(
    output_base_path="output/result",
    **results
)
```

## 配置文件说明

### config.json 结构
```json
{
  "scenarios": [
    {
      "name": "场景1",
      "enabled": true,
      "sql_file": "file1.csv",
      "api_file": "file2.csv",
      "sql_key_column": 0,
      "api_key_column": 0,
      "sql_feature_start": 1,
      "api_feature_start": 1,
      "convert_feature_to_number": true,
      "output_prefix": "compare"
    }
  ]
}
```

### 配置项说明
- `name`: 场景名称
- `enabled`: 是否启用该场景
- `sql_file`: Sql文件名（位于inputdata/data_comparison/）
- `api_file`: 接口文件名（位于inputdata/data_comparison/）
- `sql_key_column`: Sql文件主键列索引（从0开始），支持单列(数字)或多列(数组)
- `api_key_column`: 接口文件主键列索引（从0开始），支持单列(数字)或多列(数组)
- `sql_feature_start`: Sql文件特征起始列索引
- `api_feature_start`: 接口文件特征起始列索引
- `convert_feature_to_number`: 是否转换特征值为数值
- `output_prefix`: 输出文件前缀

### 多列主键配置示例
```json
{
  "name": "多列主键示例",
  "enabled": true,
  "sql_file": "file1.csv",
  "api_file": "file2.csv",
  "sql_key_column": [0, 1],
  "api_key_column": [0, 1],
  "sql_feature_start": 2,
  "api_feature_start": 2,
  "convert_feature_to_number": true,
  "output_prefix": "multi_key_compare"
}
```
详细说明请参考：[多列主键快速参考](MULTI_KEY_QUICK_REFERENCE.md)

## 输入输出

### 输入目录
```
inputdata/data_comparison/
```
将待对比的CSV或XLSX文件放在此目录下。

### 输出目录
```
outputdata/data_comparison/
```
对比结果将保存在此目录下，文件名格式：
- `{prefix}_{timestamp}_差异特征汇总.csv`
- `{prefix}_{timestamp}_差异数据明细.csv`
- `{prefix}_{timestamp}_特征统计.csv`
- `{prefix}_{timestamp}_全量数据合并.csv`
- `{prefix}_{timestamp}_仅在Sql文件中的数据.csv`
- `{prefix}_{timestamp}_仅在接口文件中的数据.csv`

## 转换功能说明

### 启用转换后的行为
- `"8"` → `8`（整数）
- `"8.5"` → `8.5`（浮点数）
- `"abc"` → `abc`（去除引号）
- `"  8  "` → `8`（去除引号和空格）

### 不启用转换
保持原始字符串格式，不做任何转换。

## 注意事项

1. **文件编码**：支持UTF-8、GBK、GB2312编码
2. **列索引**：从0开始，A列=0，B列=1，以此类推
3. **主键唯一性**：确保主键列的值在各自文件中唯一
4. **内存使用**：大文件对比需要足够的内存
5. **文件格式**：确保CSV文件格式正确，XLSX文件不包含多个sheet

## 相关文档
- [多列主键快速参考](MULTI_KEY_QUICK_REFERENCE.md) - 多列主键配置快速指南
- [多列主键更新说明](MULTI_KEY_UPDATE.md) - 详细的多列主键功能说明
- [配置指南](CONFIG_GUIDE.md) - 完整的配置文件说明
- [数据对比功能说明](../md/数据对比功能说明.md)
- [数据对比功能完整更新记录](../md/数据对比功能完整更新记录.md)
- [数据对比转换功能快速参考](../数据对比转换功能快速参考.md)

## 版本历史
- v2.0.0 (2026-03-05): 支持单列或多列组合主键
- v1.4.0 (2026-01-26): 修复引号处理问题，优化转换逻辑
- v1.3.0: 优化主键值获取逻辑
- v1.2.0: 界面优化和cust_no字段修复
- v1.1.0: 添加特征值转换功能
- v1.0.0: 初始版本
