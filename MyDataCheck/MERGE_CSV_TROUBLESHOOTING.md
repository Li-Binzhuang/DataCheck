# CSV合并功能 - 故障排查指南

## 当前状态

已修复并优化代码，现在需要测试验证。

## 文件上传流程说明

### 1. 选择文件阶段
- 用户点击"选择CSV文件"按钮
- 浏览器打开文件选择对话框
- 用户选择多个CSV文件（Ctrl/Cmd + 多选）
- 文件对象存储在浏览器内存中（`selectedMergeCsvFiles` 变量）
- **此时文件还未上传到服务器**

### 2. 点击"执行合并"阶段
- 用户点击"执行合并"按钮
- JavaScript 创建 FormData 对象
- 将选中的文件添加到 FormData
- 通过 HTTP POST 请求上传文件到服务器 `/merge-csv/execute`
- **此时文件才真正上传到服务器**

### 3. 服务器处理阶段
- 服务器接收上传的文件
- 保存到临时目录
- 执行合并操作
- 通过 SSE 流实时推送进度
- 处理完成后清理临时文件
- 返回下载链接

## 测试步骤

### 步骤1: 重启服务器
```bash
# 停止当前服务器（Ctrl+C）
# 重新启动
python web_app.py
# 或
python web/app.py
```

### 步骤2: 清除浏览器缓存
1. 打开浏览器开发者工具（F12）
2. 右键点击刷新按钮
3. 选择"清空缓存并硬性重新加载"

### 步骤3: 测试服务端点
在浏览器中访问：
```
http://172.20.32.92:5001/merge-csv/test
```

应该看到：
```json
{
  "status": "ok",
  "message": "CSV合并服务正常运行",
  "output_dir": "outputdata/merge_csv",
  "chunk_size": 50000
}
```

### 步骤4: 测试合并功能
1. 准备2个测试CSV文件（每个至少100行）
2. 打开合并表格文件页面
3. 选择2个CSV文件
4. 确认显示"已选择 2 个文件"
5. 确认"执行合并"按钮已启用
6. 打开浏览器控制台（F12 → Console）
7. 点击"执行合并"按钮
8. 观察控制台输出和页面输出面板

## 预期输出

### 浏览器控制台
```
响应类型: text/event-stream
```

### 页面输出面板
```
开始合并 2 个文件...
合并方式: 纵向合并（追加行）
正在上传文件到服务器...
文件上传成功，开始处理...
使用流式处理模式...
[5%] 开始处理 2 个文件...
[7%] 已保存文件 1/2: file1.csv
[10%] 已保存文件 2/2: file2.csv
[20%] 开始纵向合并（追加行）...
[20%] 正在处理第 1/2 个文件...
[50%] 正在处理第 2/2 个文件...
[90%] 合并完成，正在生成结果...
✅ 合并成功！
输出文件: merged_20250313_143022.csv
总行数: 200
总列数: 10
正在下载文件...
```

## 常见问题排查

### 问题1: 点击按钮没有反应
**检查项**:
1. 打开浏览器控制台，查看是否有JavaScript错误
2. 确认是否选择了至少2个文件
3. 确认按钮是否已启用（不是灰色）

**解决方案**:
- 清除浏览器缓存并刷新
- 检查 `static/js/merge-csv.js` 是否正确加载

### 问题2: 显示"等待执行..."不变化
**检查项**:
1. 浏览器控制台是否有网络错误
2. 服务器是否正常运行
3. 访问 `/merge-csv/test` 端点是否正常

**解决方案**:
- 重启服务器
- 检查防火墙设置
- 检查服务器日志

### 问题3: 上传后长时间无响应
**检查项**:
1. 文件大小是否过大（>100MB）
2. 服务器CPU/内存使用情况
3. 服务器日志是否有错误

**解决方案**:
- 使用较小的测试文件
- 检查服务器资源
- 查看服务器错误日志

### 问题4: SSE流不工作
**检查项**:
1. 浏览器控制台显示的响应类型
2. 服务器是否支持SSE
3. 代理服务器配置（如Nginx）

**解决方案**:
- 代码已包含降级方案，会自动切换到标准JSON响应
- 如果使用Nginx，需要配置：
```nginx
proxy_buffering off;
proxy_cache off;
proxy_set_header Connection '';
proxy_http_version 1.1;
chunked_transfer_encoding off;
```

## 调试技巧

### 1. 查看网络请求
1. 打开开发者工具 → Network 标签
2. 点击"执行合并"
3. 查找 `/merge-csv/execute` 请求
4. 检查请求状态、响应头、响应内容

### 2. 查看服务器日志
```bash
# 如果使用 Flask 开发服务器
# 日志会直接输出到终端

# 查看错误信息
tail -f logs/error.log  # 如果有日志文件
```

### 3. 添加调试输出
在 `executeMergeCsv()` 函数开头添加：
```javascript
console.log('开始执行合并');
console.log('选中的文件:', selectedMergeCsvFiles);
console.log('合并模式:', mergeMode);
```

## 部署到测试服务器注意事项

### 1. 文件上传大小限制
确保服务器配置允许大文件上传：

**Flask配置** (`app.py` 或 `web_app.py`):
```python
app.config['MAX_CONTENT_LENGTH'] = 500 * 1024 * 1024  # 500MB
```

**Nginx配置**:
```nginx
client_max_body_size 500M;
```

### 2. 临时文件目录权限
确保应用有权限创建临时文件：
```bash
chmod 755 /tmp
# 或指定临时目录
export TMPDIR=/path/to/temp
```

### 3. 输出目录权限
确保输出目录存在且可写：
```bash
mkdir -p outputdata/merge_csv
chmod 755 outputdata/merge_csv
```

### 4. 超时设置
对于大文件，可能需要增加超时时间：

**Nginx**:
```nginx
proxy_read_timeout 300s;
proxy_connect_timeout 300s;
proxy_send_timeout 300s;
```

**Gunicorn**:
```bash
gunicorn --timeout 300 app:app
```

## 性能优化建议

### 1. 调整分块大小
根据服务器内存调整 `CHUNK_SIZE`：
```python
# web/routes/merge_csv_routes.py
CHUNK_SIZE = 50000  # 内存充足可增大到 100000
```

### 2. 使用更快的CSV库
考虑使用 `pyarrow` 或 `polars` 替代 pandas：
```python
# 安装
pip install pyarrow

# 使用
df = pd.read_csv(file, engine='pyarrow')
```

### 3. 启用压缩
对于大文件，可以启用压缩：
```python
merged_df.to_csv(output_path, index=False, encoding='utf-8-sig', compression='gzip')
```

## 联系支持

如果问题仍未解决，请提供：
1. 浏览器控制台完整错误信息
2. 服务器日志
3. 测试文件大小和行数
4. 服务器配置信息（内存、CPU）
