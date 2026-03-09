# XLSX文件支持更新说明

## 更新概述

已为所有模块添加 `.xlsx` 和 `.xls` 文件上传支持，现在可以直接上传Excel文件进行数据对比。

## 更新内容

### 1. 核心工具模块更新

**文件：`common/csv_tool.py`**

- 更新 `read_csv_with_encoding()` 函数，新增对 `.xlsx` 和 `.xls` 文件的支持
- 使用 `openpyxl` 库读取Excel文件
- 自动将Excel数据转换为与CSV相同的格式（表头 + 数据行）
- 保持向后兼容，原有CSV读取功能不受影响

**关键特性：**
- 自动检测文件扩展名（`.xlsx`, `.xls`, `.csv`）
- Excel文件使用只读模式，提高性能
- 自动将单元格值转换为字符串，确保数据一致性
- 如果缺少 `openpyxl` 库，会给出清晰的安装提示

### 2. 路由模块更新

#### 接口数据对比模块
**文件：`web/routes/api_routes.py`**

- 更新 `upload_file()` 函数
- 支持文件类型：`.csv`, `.xlsx`, `.xls`, `.pkl`
- 错误提示更新为："只支持CSV、XLSX和PKL文件"

#### 数据对比模块
**文件：`web/routes/compare_routes.py`**

- 更新 `upload_compare_file()` 函数
- 支持文件类型：`.csv`, `.xlsx`, `.xls`
- 错误提示更新为："只支持CSV和XLSX文件"

#### 线上灰度落数对比模块
**文件：`web/routes/online_routes.py`**

- 更新 `upload_online_file()` 函数
- 支持文件类型：`.csv`, `.xlsx`, `.xls`, `.pkl`
- 错误提示更新为："只支持CSV、XLSX和PKL文件"

#### 批量跑数模块
**文件：`web/routes/batch_run_routes.py`**

- 更新 `upload_batch_run_file()` 函数
- 支持文件类型：`.csv`, `.xlsx`, `.xls`
- 错误提示更新为："只支持CSV和XLSX文件"

### 3. 依赖更新

**文件：`requirements.txt`**

- 新增依赖：`openpyxl>=3.0.0`

## 使用方法

### 安装依赖

```bash
pip install openpyxl
```

或者使用requirements.txt安装所有依赖：

```bash
pip install -r requirements.txt
```

### 上传Excel文件

1. 在Web界面中，选择任意模块（接口数据对比、数据对比、线上灰度落数对比、批量跑数）
2. 点击"上传文件"按钮
3. 选择 `.xlsx` 或 `.xls` 文件
4. 系统会自动读取Excel文件并转换为内部格式
5. 后续操作与CSV文件完全相同

### 注意事项

1. **Excel文件格式要求：**
   - 第一行必须是表头
   - 数据从第二行开始
   - 只读取第一个工作表（Sheet）
   - 空单元格会被转换为空字符串

2. **性能考虑：**
   - Excel文件读取速度略慢于CSV文件
   - 建议大文件（>100MB）优先使用CSV格式
   - 系统会使用只读模式打开Excel，减少内存占用

3. **兼容性：**
   - 支持 `.xlsx`（Excel 2007及以上）
   - 支持 `.xls`（Excel 97-2003）
   - 所有现有CSV功能保持不变

## 技术细节

### Excel读取实现

```python
import openpyxl

workbook = openpyxl.load_workbook(file_path, read_only=True, data_only=True)
sheet = workbook.active

headers = []
rows = []

for i, row in enumerate(sheet.iter_rows(values_only=True)):
    if i == 0:
        headers = [str(cell) if cell is not None else '' for cell in row]
    else:
        rows.append([str(cell) if cell is not None else '' for cell in row])

workbook.close()
```

### 文件类型检测

```python
file_ext = os.path.splitext(file.filename)[1].lower()
allowed_extensions = ['.csv', '.xlsx', '.xls', '.pkl']

if file_ext in allowed_extensions:
    # 处理文件
```

## 测试建议

1. **基本功能测试：**
   - 上传小型Excel文件（<1MB）
   - 验证数据正确读取
   - 执行对比流程

2. **边界测试：**
   - 空Excel文件
   - 只有表头的Excel文件
   - 包含空单元格的Excel文件
   - 大型Excel文件（>50MB）

3. **兼容性测试：**
   - 测试 `.xlsx` 格式
   - 测试 `.xls` 格式
   - 验证CSV文件仍然正常工作

## 回滚方案

如果需要回滚此更新：

1. 恢复 `common/csv_tool.py` 中的 `read_csv_with_encoding()` 函数
2. 恢复各路由文件中的文件验证逻辑
3. 从 `requirements.txt` 中移除 `openpyxl`

## 后续优化建议

1. **性能优化：**
   - 对于超大Excel文件，考虑使用流式读取
   - 添加进度条显示Excel读取进度

2. **功能增强：**
   - 支持选择读取哪个工作表
   - 支持指定表头行号
   - 添加Excel文件预览功能

3. **用户体验：**
   - 在前端显示文件类型图标
   - 提供Excel转CSV的下载功能
   - 添加文件格式转换工具

## 更新日期

2024-03-09
