# XLSX文件支持更新说明

## 更新概述

已为所有数据对比模块添加Excel文件（.xlsx/.xls）上传支持，现在可以直接上传Excel文件进行数据对比，无需手动转换为CSV格式。

## 支持的模块

✅ 接口数据对比
✅ 数据对比
✅ 线上灰度落数对比
✅ 批量跑数

## 支持的文件格式

- `.csv` - CSV文件（原有支持）
- `.xlsx` - Excel 2007及以上版本
- `.xls` - Excel 97-2003版本
- `.pkl` - Pickle文件（部分模块支持）

## 安装依赖

### 方法1：直接安装

```bash
pip install openpyxl
```

### 方法2：使用requirements.txt

```bash
pip install -r requirements.txt
```

## 使用方法

1. 启动Web服务器
   ```bash
   python web_app.py
   ```

2. 在浏览器中打开 `http://localhost:5001`

3. 选择任意模块（接口数据对比、数据对比等）

4. 点击"上传文件"按钮

5. 选择Excel文件（.xlsx或.xls）

6. 系统会自动读取Excel文件并进行处理

## 验证安装

运行测试脚本：

```bash
python test_xlsx_support.py
```

如果看到以下输出，说明功能正常：

```
✅ openpyxl已安装，版本: 3.x.x
🎉 所有测试通过！XLSX文件支持功能正常
```

## Excel文件要求

1. **表头位置**：第一行必须是表头（列名）
2. **数据位置**：数据从第二行开始
3. **工作表**：只读取第一个工作表（Sheet）
4. **单元格格式**：所有单元格会被转换为文本格式
5. **空单元格**：空单元格会被转换为空字符串

## 性能建议

- **小文件（<10MB）**：Excel和CSV性能相当
- **中等文件（10-50MB）**：Excel略慢，但可接受
- **大文件（>50MB）**：建议使用CSV格式以获得最佳性能

## 常见问题

### Q1: 上传Excel文件后提示"只支持CSV文件"

**原因**：可能是浏览器缓存问题

**解决方案**：
1. 清除浏览器缓存
2. 强制刷新页面（Ctrl+F5 或 Cmd+Shift+R）
3. 重启Web服务器

### Q2: Excel文件读取失败

**可能原因**：
- 文件损坏
- 文件包含复杂公式或宏
- 文件格式不正确

**解决方案**：
1. 用Excel打开文件，另存为新的.xlsx文件
2. 删除不必要的工作表
3. 删除复杂的公式和宏
4. 如果问题持续，转换为CSV格式

### Q3: 读取速度很慢

**优化方法**：
1. 删除Excel文件中的空行和空列
2. 只保留需要的工作表
3. 对于超大文件，使用CSV格式

## 技术细节

### 核心实现

更新了 `common/csv_tool.py` 中的 `read_csv_with_encoding()` 函数：

```python
# 自动检测文件类型
file_ext = os.path.splitext(file_path)[1].lower()

if file_ext in ['.xlsx', '.xls']:
    # 使用openpyxl读取Excel
    import openpyxl
    workbook = openpyxl.load_workbook(file_path, read_only=True, data_only=True)
    sheet = workbook.active
    # 读取数据...
else:
    # 使用csv模块读取CSV
    # 原有逻辑...
```

### 修改的文件列表

1. `common/csv_tool.py` - 核心读取函数
2. `web/routes/api_routes.py` - 接口数据对比路由
3. `web/routes/compare_routes.py` - 数据对比路由
4. `web/routes/online_routes.py` - 线上灰度落数对比路由
5. `web/routes/batch_run_routes.py` - 批量跑数路由
6. `requirements.txt` - 依赖配置

## 向后兼容性

✅ 完全向后兼容，所有现有CSV功能保持不变
✅ 不影响现有的数据对比流程
✅ 可以混合使用CSV和Excel文件

## 更新日期

2024-03-09

## 相关文档

- 详细技术文档：[XLSX_SUPPORT_UPDATE.md](XLSX_SUPPORT_UPDATE.md)
- 安装指南：[INSTALLATION_GUIDE.md](INSTALLATION_GUIDE.md)
- 测试脚本：[test_xlsx_support.py](test_xlsx_support.py)
