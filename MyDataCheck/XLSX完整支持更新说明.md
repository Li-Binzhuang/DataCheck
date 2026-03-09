# XLSX完整支持更新说明

## 更新概述

本次更新为所有模块添加了完整的XLSX文件支持，包括前端界面和后端处理逻辑。现在用户可以直接上传XLSX文件，系统会自动转换为CSV格式进行处理。

## 更新内容

### 1. 后端更新

#### 新增功能
在 `common/csv_tool.py` 中添加了 `convert_xlsx_to_csv()` 函数：
- 支持将XLSX文件自动转换为CSV格式
- 支持自定义输出路径
- 支持输出到outputdata目录或同目录
- 完整的错误处理和友好的错误提示

#### 路由更新
更新了以下路由文件，添加XLSX转CSV的处理逻辑：

**1. web/routes/api_routes.py** (接口数据对比)
- `upload_file()` 函数：支持.xlsx和.xls文件上传
- 自动转换XLSX为CSV格式
- 返回转换后的CSV文件名

**2. web/routes/online_routes.py** (线上灰度落数对比)
- `upload_online_file()` 函数：支持.xlsx和.xls文件上传
- 自动转换XLSX为CSV格式
- 返回转换后的CSV文件名

**3. web/routes/compare_routes.py** (数据对比和小数处理工具)
- `upload_compare_file()` 函数：支持.xlsx和.xls文件上传
- `upload_decimal_file()` 函数：支持.xlsx和.xls文件上传
- 自动转换XLSX为CSV格式
- 返回转换后的CSV文件名

### 2. 前端更新

#### HTML模板更新 (templates/index.html)
- **小数位差异检测工具**
  - 标签改为 "CSV/XLSX文件"
  - accept 属性改为 `.csv,.xlsx`
  
- **批量运行工具**
  - accept 属性改为 `.csv,.xlsx`

#### JavaScript更新

**1. static/js/api-compare.js** (接口数据对比)
- 标签改为 "输入CSV/PKL/XLSX文件"
- accept 改为 `.csv,.pkl,.xlsx`
- 提示文本更新：支持CSV、PKL和XLSX文件，PKL和XLSX将自动转换为CSV

**2. static/js/online.js** (线上灰度落数对比)
- 离线文件标签改为 "离线文件 (CSV/PKL/XLSX)"
- 线上文件标签改为 "线上文件 (CSV/PKL/XLSX)"
- accept 都改为 `.csv,.pkl,.xlsx`
- 提示文本更新：支持CSV、PKL和XLSX文件

### 3. 支持的文件格式

现在所有模块都支持以下文件格式：
- `.csv` - CSV文件（直接使用）
- `.xlsx` - Excel 2007+格式（自动转换为CSV）
- `.xls` - Excel 97-2003格式（自动转换为CSV）
- `.pkl` - Pickle文件（自动转换为CSV，部分模块支持）

### 4. 转换逻辑

当用户上传XLSX文件时：
1. 文件首先保存到inputdata目录
2. 系统检测文件扩展名为.xlsx或.xls
3. 自动调用 `convert_xlsx_to_csv()` 函数
4. 使用openpyxl库读取XLSX文件
5. 转换后的CSV文件保存到相应目录
6. 返回转换后的CSV文件名给前端
7. 前端显示转换成功消息
8. 后续处理使用转换后的CSV文件

### 5. 错误处理

- 如果openpyxl库未安装，返回友好提示："需要安装openpyxl库，请运行: pip install openpyxl"
- 转换失败时，返回详细的错误信息
- 前端会显示转换状态和结果
- 文件大小限制：1GB

### 6. 测试

创建了测试文件 `test_xlsx_conversion.py` 用于验证XLSX转CSV功能。

## 使用说明

### 支持XLSX的模块

用户现在可以在以下所有模块中直接上传XLSX文件：

1. **接口数据对比**
   - 上传输入CSV/PKL/XLSX文件
   - 系统自动转换XLSX为CSV

2. **线上灰度落数对比**
   - 上传离线文件（CSV/PKL/XLSX）
   - 上传线上文件（CSV/PKL/XLSX）
   - 系统自动转换XLSX为CSV

3. **数据对比**
   - 上传模型特征文件（CSV/XLSX）
   - 上传接口/灰度/从库特征表（CSV/XLSX）
   - 系统自动转换XLSX为CSV

4. **小数位差异检测工具**
   - 上传CSV/XLSX文件
   - 系统自动转换XLSX为CSV

5. **批量运行工具**
   - 上传CSV/XLSX文件
   - 系统自动转换XLSX为CSV

### 用户体验

- 用户无需手动转换XLSX为CSV
- 上传XLSX文件后，系统会显示"XLSX文件已转换为CSV: xxx.csv"
- 转换过程自动完成，用户无感知
- 转换后的CSV文件可以在outputdata目录中找到

## 依赖要求

需要安装 `openpyxl` 库：

```bash
pip install openpyxl
```

或使用requirements.txt：

```bash
pip install -r requirements.txt
```

## Excel文件要求

1. **表头位置**：第一行必须是表头（列名）
2. **数据位置**：数据从第二行开始
3. **工作表**：只读取第一个工作表（Sheet）
4. **单元格格式**：所有单元格会被转换为文本格式
5. **空单元格**：空单元格会被转换为空字符串

## 性能建议

- **小文件（<10MB）**：XLSX转换速度快
- **中等文件（10-50MB）**：转换时间可接受
- **大文件（>50MB）**：建议使用CSV格式以获得最佳性能

## 修改的文件列表

### 后端文件
1. `common/csv_tool.py` - 添加convert_xlsx_to_csv()函数
2. `web/routes/api_routes.py` - 添加XLSX转换逻辑
3. `web/routes/online_routes.py` - 添加XLSX转换逻辑
4. `web/routes/compare_routes.py` - 添加XLSX转换逻辑（两个函数）

### 前端文件
1. `templates/index.html` - 更新文件上传accept属性（2处）
2. `static/js/api-compare.js` - 更新文件上传accept和提示文本
3. `static/js/online.js` - 更新文件上传accept和提示文本（2处）

### 测试文件
1. `test_xlsx_conversion.py` - XLSX转CSV功能测试

## 向后兼容性

✅ 完全向后兼容，所有现有CSV和PKL功能保持不变
✅ 不影响现有的数据对比流程
✅ 可以混合使用CSV、PKL和XLSX文件

## 更新日期

2024-03-09

## 相关文档

- 原有XLSX支持文档：[XLSX支持更新说明.md](XLSX支持更新说明.md)
- 详细技术文档：[XLSX_SUPPORT_UPDATE.md](XLSX_SUPPORT_UPDATE.md)
- 安装指南：[INSTALLATION_GUIDE.md](INSTALLATION_GUIDE.md)
