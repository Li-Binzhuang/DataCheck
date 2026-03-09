# XLSX文件支持 - 快速更新总结

## 更新内容

已为所有模块添加 `.xlsx` 和 `.xls` 文件上传支持。

## 修改的文件

1. **common/csv_tool.py** - 核心读取函数支持XLSX
2. **web/routes/api_routes.py** - 接口数据对比模块
3. **web/routes/compare_routes.py** - 数据对比模块
4. **web/routes/online_routes.py** - 线上灰度落数对比模块
5. **web/routes/batch_run_routes.py** - 批量跑数模块
6. **requirements.txt** - 添加openpyxl依赖

## 安装步骤

```bash
# 安装新依赖
pip install openpyxl

# 或使用requirements.txt
pip install -r requirements.txt
```

## 验证安装

```bash
# 运行测试脚本
python test_xlsx_support.py
```

## 使用方法

在Web界面上传文件时，现在可以选择：
- `.csv` 文件
- `.xlsx` 文件（Excel 2007+）
- `.xls` 文件（Excel 97-2003）
- `.pkl` 文件（部分模块支持）

系统会自动识别文件类型并正确读取。

## 注意事项

1. Excel文件第一行必须是表头
2. 只读取第一个工作表
3. 大文件（>100MB）建议使用CSV格式以获得更好性能

## 文档

- 详细更新说明：[XLSX_SUPPORT_UPDATE.md](XLSX_SUPPORT_UPDATE.md)
- 安装指南：[INSTALLATION_GUIDE.md](INSTALLATION_GUIDE.md)
- 测试脚本：[test_xlsx_support.py](test_xlsx_support.py)
