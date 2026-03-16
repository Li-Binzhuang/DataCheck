# 合并功能故障排查

## 当前状态

从截图看：
- ✅ 文件已选择（显示了5个文件）
- ✅ 按钮可点击
- ❌ 点击后显示"正在合并文件..."但没有进度输出
- ❌ 输出面板显示"输出已清空..."

## 问题诊断

这个现象说明：
1. 前端JavaScript执行了（按钮被点击）
2. 清空了输出面板（`clearOutput`被调用）
3. 但没有收到任何SSE数据流

## 可能的原因

### 1. 服务器没有重启 ⭐⭐⭐⭐⭐
**最可能的原因！**

修改了Python代码后，必须重启服务器才能生效。

**解决方案**:
```bash
# 1. 停止当前服务器
# 按 Ctrl+C 或在终端中找到进程并kill

# 2. 重新启动
python web_app.py
# 或
python web/app.py
```

### 2. 浏览器缓存没清除 ⭐⭐⭐⭐
JavaScript文件可能被缓存了。

**解决方案**:
1. 按 F12 打开开发者工具
2. 右键点击刷新按钮
3. 选择"清空缓存并硬性重新加载"

### 3. 后端报错但没有推送错误消息 ⭐⭐⭐
服务器可能在处理请求时崩溃了。

**检查方法**:
查看服务器终端输出，是否有Python错误信息。

### 4. SSE连接被阻止 ⭐⭐
某些代理或防火墙可能阻止SSE连接。

**检查方法**:
1. 打开浏览器开发者工具（F12）
2. 切换到 Network 标签
3. 点击"执行合并"
4. 查找 `/merge-csv/execute` 请求
5. 检查状态码和响应

## 立即执行的检查步骤

### 步骤1: 测试后端功能（已验证✅）
```bash
python debug_merge.py vertical
```

结果：✅ 后端代码正常工作

### 步骤2: 测试服务端点
在浏览器中访问：
```
http://172.20.32.92:5001/merge-csv/test
```

**预期结果**:
```json
{
  "status": "ok",
  "message": "CSV合并服务正常运行",
  "output_dir": "outputdata/merge_csv",
  "chunk_size": 50000
}
```

如果看不到这个结果，说明：
- 服务器没有运行
- 或者路由没有正确注册

### 步骤3: 检查浏览器控制台
1. 按 F12 打开开发者工具
2. 切换到 Console 标签
3. 点击"执行合并"
4. 查看是否有JavaScript错误

**预期输出**:
```
响应类型: text/event-stream
```

### 步骤4: 检查网络请求
1. 开发者工具 → Network 标签
2. 点击"执行合并"
3. 找到 `/merge-csv/execute` 请求
4. 检查：
   - Status: 应该是 200
   - Type: 应该是 text/event-stream
   - Response: 应该有数据流

## 最可能的解决方案

### 方案1: 完全重启（推荐）⭐⭐⭐⭐⭐

```bash
# 1. 停止服务器（Ctrl+C）

# 2. 确认进程已停止
ps aux | grep python | grep web_app

# 3. 如果还有进程，强制kill
kill -9 <进程ID>

# 4. 重新启动
python web_app.py

# 5. 等待服务器启动完成（看到类似 "Running on http://..." 的输出）

# 6. 清除浏览器缓存（F12 → 右键刷新 → 清空缓存）

# 7. 刷新页面

# 8. 重新测试
```

### 方案2: 检查路由注册

确认 `merge_csv_bp` 已在主应用中注册：

```python
# 在 web_app.py 或 web/app.py 中应该有：
from web.routes.merge_csv_routes import merge_csv_bp
app.register_blueprint(merge_csv_bp)
```

### 方案3: 添加调试日志

临时修改 `web/routes/merge_csv_routes.py`，在 `execute_merge` 函数开头添加：

```python
@merge_csv_bp.route('/execute', methods=['POST'])
def execute_merge():
    print("=" * 60)
    print("收到合并请求！")
    print("=" * 60)
    
    def generate():
        print("开始生成SSE流...")
        # ... 原有代码
```

重启服务器后，点击"执行合并"，查看终端是否有输出。

## 快速验证清单

- [ ] 服务器已重启
- [ ] 浏览器缓存已清除
- [ ] 访问 `/merge-csv/test` 端点正常
- [ ] 浏览器控制台无JavaScript错误
- [ ] Network标签显示请求已发送
- [ ] 服务器终端无Python错误

## 如果还是不行

请提供以下信息：

1. **服务器终端输出**（完整的启动日志和错误信息）
2. **浏览器控制台输出**（Console标签的所有信息）
3. **网络请求详情**（Network标签中 `/merge-csv/execute` 的详细信息）
4. **测试端点结果**（访问 `/merge-csv/test` 的响应）

## 临时解决方案

如果SSE不工作，可以暂时使用传统的同步方式。修改前端代码，直接等待完整响应：

```javascript
// 临时方案：不使用SSE
const response = await fetch('/merge-csv/execute', {
    method: 'POST',
    body: formData
});

const result = await response.json();
if (result.success) {
    // 处理成功
} else {
    // 处理失败
}
```

但这样就看不到实时进度了。

## 总结

**最可能的问题**: 服务器没有重启

**解决方案**: 
1. 停止服务器（Ctrl+C）
2. 重新启动（python web_app.py）
3. 清除浏览器缓存
4. 刷新页面
5. 重新测试

如果按照上述步骤操作后还是不行，请查看服务器终端和浏览器控制台的错误信息。
