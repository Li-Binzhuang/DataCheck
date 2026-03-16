# 合并表格文件 - 进度显示功能更新

## 更新内容

为合并表格文件模块添加了详细的进度显示功能，让用户清楚了解合并过程。

## 功能特性

### 1. 文件上传信息显示

合并开始时显示：
- 📁 文件数量
- 📄 每个文件的名称和大小
- 🔄 合并方式（纵向/横向）
- 🔧 重复列处理配置

### 2. 文件详情显示

合并成功后显示每个文件的详细信息：
- 文件名
- 行数
- 列数

### 3. 合并结果统计

根据合并方式显示不同的统计信息：

**纵向合并：**
- 📈 合并后总行数（重点显示）
- 📊 列数

**横向合并：**
- 📊 合并后总列数（重点显示）
- 📈 行数

### 4. 重复列移除信息

如果横向合并时移除了重复列，显示：
- 🗑️ 移除的列数量
- 具体的列名列表

### 5. 输出格式优化

- 使用 emoji 图标增强可读性
- 添加空行分隔不同信息块
- 清晰的层级结构

## 示例输出

### 横向合并示例

```
📁 准备合并 3 个文件...
  1. users.csv (12.34 KB)
  2. features1.csv (8.56 KB)
  3. features2.csv (9.12 KB)
🔄 合并方式: 横向合并（追加列）
🔧 将自动检测并移除所有重复列
⏳ 正在读取和合并文件...

✅ 合并成功！

📊 文件详情:
  1. users.csv: 100 行 × 4 列
  2. features1.csv: 100 行 × 4 列
  3. features2.csv: 100 行 × 4 列

📄 输出文件: merged_20260309_143022.csv
📊 合并后总列数: 10
📈 行数: 100

🗑️ 已移除重复列 (1个): user_id

⬇️ 正在下载文件...
```

### 纵向合并示例

```
📁 准备合并 2 个文件...
  1. data1.csv (5.67 KB)
  2. data2.csv (5.89 KB)
🔄 合并方式: 纵向合并（追加行）
⏳ 正在读取和合并文件...

✅ 合并成功！

📊 文件详情:
  1. data1.csv: 50 行 × 3 列
  2. data2.csv: 50 行 × 3 列

📄 输出文件: merged_20260309_143022.csv
📈 合并后总行数: 100
📊 列数: 3

⬇️ 正在下载文件...
```

## 技术实现

### 后端修改 (web/routes/merge_csv_routes.py)

1. 在读取文件时收集文件信息：
```python
file_info = []
for idx, file in enumerate(files, 1):
    df = pd.read_csv(file)
    dataframes.append(df)
    file_info.append({
        'name': file.filename,
        'rows': len(df),
        'columns': len(df.columns)
    })
```

2. 在响应中返回文件信息：
```python
response_data = {
    'success': True,
    'merge_mode': merge_mode,
    'output_file': output_file,
    'total_rows': len(merged_df),
    'total_columns': len(merged_df.columns),
    'download_url': f'/download/merge_csv/{output_file}',
    'file_info': file_info  # 新增
}
```

### 前端修改 (static/js/merge-csv.js)

1. 合并开始时显示文件列表和配置：
```javascript
appendOutput(`📁 准备合并 ${selectedMergeCsvFiles.length} 个文件...`, 'info', 'merge-csv');

selectedMergeCsvFiles.forEach((file, idx) => {
    appendOutput(`  ${idx + 1}. ${file.name} (${(file.size / 1024).toFixed(2)} KB)`, 'info', 'merge-csv');
});

appendOutput(`🔄 合并方式: ${mergeMode === 'vertical' ? '纵向合并（追加行）' : '横向合并（追加列）'}`, 'info', 'merge-csv');
```

2. 合并成功后显示详细信息：
```javascript
if (result.file_info && result.file_info.length > 0) {
    appendOutput('📊 文件详情:', 'info', 'merge-csv');
    result.file_info.forEach((info, idx) => {
        appendOutput(`  ${idx + 1}. ${info.name}: ${info.rows} 行 × ${info.columns} 列`, 'info', 'merge-csv');
    });
}
```

3. 根据合并方式显示不同的统计重点：
```javascript
if (result.merge_mode === 'vertical') {
    appendOutput(`📈 合并后总行数: ${result.total_rows}`, 'info', 'merge-csv');
    appendOutput(`📊 列数: ${result.total_columns}`, 'info', 'merge-csv');
} else {
    appendOutput(`📊 合并后总列数: ${result.total_columns}`, 'info', 'merge-csv');
    appendOutput(`📈 行数: ${result.total_rows}`, 'info', 'merge-csv');
}
```

## 使用说明

1. 选择多个CSV文件
2. 选择合并方式
3. 点击"执行合并"
4. 在右侧"执行输出"面板查看详细的合并进度和结果

## 注意事项

1. **重启服务**：修改后需要重启 Flask 应用才能生效
2. **浏览器缓存**：建议清除浏览器缓存或强制刷新（Ctrl+F5 / Cmd+Shift+R）
3. **文件大小**：大文件合并时，进度信息可以帮助用户了解处理状态

## 更新时间

2024-03-09

## 相关文件

- `web/routes/merge_csv_routes.py` - 后端路由（已更新）
- `static/js/merge-csv.js` - 前端逻辑（已更新）
- `MERGE_CSV_FIX.md` - 之前的修复说明
- `MERGE_CSV_FEATURE.md` - 功能文档
