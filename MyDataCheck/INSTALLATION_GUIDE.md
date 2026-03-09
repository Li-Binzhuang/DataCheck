# XLSX文件支持 - 安装指南

## 快速安装

为了支持XLSX文件上传和读取，需要安装 `openpyxl` 库。

### 方法1: 使用pip直接安装

```bash
pip install openpyxl
```

### 方法2: 使用requirements.txt安装所有依赖

```bash
pip install -r requirements.txt
```

## 验证安装

运行测试脚本验证XLSX支持功能：

```bash
python test_xlsx_support.py
```

如果看到以下输出，说明安装成功：

```
✅ openpyxl已安装，版本: 3.x.x
```

## 功能测试

### 1. 准备测试文件

在 `inputdata` 目录下放置一个测试用的XLSX文件。

### 2. 运行完整测试

```bash
python test_xlsx_support.py
```

### 3. 通过Web界面测试

1. 启动Web服务器：
   ```bash
   python web_app.py
   ```

2. 打开浏览器访问：`http://localhost:5001`

3. 选择任意模块（接口数据对比、数据对比等）

4. 点击"上传文件"按钮

5. 选择一个 `.xlsx` 或 `.xls` 文件

6. 验证文件上传成功并能正常读取

## 常见问题

### Q1: 安装openpyxl时出错

**解决方案：**
```bash
# 升级pip
pip install --upgrade pip

# 重新安装
pip install openpyxl
```

### Q2: 导入openpyxl时报错

**解决方案：**
```bash
# 检查是否在正确的Python环境中
which python
python --version

# 确认openpyxl已安装
pip list | grep openpyxl

# 如果没有，重新安装
pip install openpyxl
```

### Q3: XLSX文件读取失败

**可能原因：**
1. 文件损坏或格式不正确
2. Excel文件包含复杂的公式或宏
3. 文件过大导致内存不足

**解决方案：**
1. 尝试用Excel重新保存文件
2. 将文件另存为 `.xlsx` 格式（不要使用 `.xlsm` 等带宏的格式）
3. 对于超大文件，建议先转换为CSV格式

### Q4: 读取XLSX文件速度慢

**优化建议：**
1. 对于大文件（>50MB），优先使用CSV格式
2. 确保Excel文件不包含不必要的工作表
3. 删除Excel文件中的空行和空列

## 依赖版本

- Python: >= 3.7
- openpyxl: >= 3.0.0
- Flask: >= 2.0.0
- pandas: >= 2.0.0

## 卸载

如果需要移除XLSX支持功能：

```bash
pip uninstall openpyxl
```

注意：卸载后将无法上传和读取XLSX文件，但CSV文件功能不受影响。

## 技术支持

如有问题，请查看：
- [openpyxl官方文档](https://openpyxl.readthedocs.io/)
- [项目更新说明](XLSX_SUPPORT_UPDATE.md)
