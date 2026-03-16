# 测试文件目录

本目录包含项目的各种测试文件，包括测试脚本、测试数据和测试页面。

## 📋 文件说明

### 测试脚本
- `test_column_mapping.py` - 列映射测试
- `test_integration_mapping.py` - 集成映射测试
- `test_merge_csv.py` - CSV 合并测试
- `test_merge_new.py` - 新 CSV 合并测试
- `test_tolerance_feature.py` - 容差特性测试
- `test_xlsx_conversion.py` - XLSX 转换测试
- `test_xlsx_support.py` - XLSX 支持测试

### 测试数据
- `horizontal_test1.csv` - 水平测试数据 1
- `horizontal_test2.csv` - 水平测试数据 2
- `horizontal_test3.csv` - 水平测试数据 3
- `vertical_test1.csv` - 垂直测试数据 1
- `vertical_test2.csv` - 垂直测试数据 2
- `cdc灰度验证.csv` - CDC 灰度验证数据

### 测试页面
- `test_download_logic.html` - 下载逻辑测试页面
- `test_merge_simple.html` - 简单合并测试页面

## 🚀 使用方法

运行测试脚本：
```bash
python test_column_mapping.py
python test_merge_csv.py
# 等等...
```

## 📝 注意事项

- 这些是开发和测试用的文件
- 不应在生产环境中使用
- 测试数据仅用于验证功能
