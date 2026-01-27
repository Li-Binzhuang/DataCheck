# 诊断Web页面卡住问题

## 问题描述

执行接口数据对比时，Web页面卡住不动。

---

## 可能的原因

### 1. 线程阻塞
- 执行线程在某个地方卡住
- 可能是网络请求超时
- 可能是文件读取阻塞

### 2. 输出队列问题
- 队列没有正确发送数据
- 前端没有正确接收流式输出

### 3. 配置问题
- CSV文件不存在
- API地址无法访问
- 线程数设置过大

### 4. 浏览器问题
- 浏览器缓存
- 网络连接超时
- EventStream连接断开

---

## 诊断步骤

### 步骤1：检查服务状态
```bash
# 检查服务是否运行
ps aux | grep web_app.py

# 检查端口
lsof -i:5001
```

### 步骤2：查看Python进程
```bash
# 查看所有Python进程
ps aux | grep python

# 查看进程详情
top -pid <PID>
```

### 步骤3：检查配置
```bash
# 查看配置文件
cat api_comparison/config.json

# 检查CSV文件是否存在
ls -la inputdata/api_comparison/
```

### 步骤4：查看浏览器控制台
1. 打开浏览器开发者工具（F12）
2. 查看Console标签页
3. 查看Network标签页
4. 检查是否有错误信息

### 步骤5：测试API接口
```bash
# 简单测试
curl -X POST http://localhost:5001/api/execute \
  -H "Content-Type: application/json" \
  -d '{"config": "{\"scenarios\":[]}"}'
```

---

## 常见问题和解决方案

### 问题1：CSV文件不存在
**症状**：执行后立即卡住，没有任何输出

**解决**：
```bash
# 检查文件
ls -la inputdata/api_comparison/

# 上传正确的CSV文件
```

### 问题2：API地址无法访问
**症状**：执行一段时间后卡住，显示"正在请求API..."

**解决**：
- 检查API地址是否正确
- 检查网络连接
- 减少超时时间（默认60秒）

### 问题3：线程数过大
**症状**：执行时CPU占用很高，页面卡住

**解决**：
- 减少线程数（建议50-100）
- 检查系统资源

### 问题4：浏览器缓存
**症状**：页面显示异常，功能不正常

**解决**：
```
1. 清除浏览器缓存
2. 硬刷新（Cmd+Shift+R 或 Ctrl+Shift+R）
3. 使用无痕模式测试
```

### 问题5：EventStream连接断开
**症状**：执行开始后没有输出，页面一直显示"执行中"

**解决**：
```bash
# 重启服务
cd MyDataCheck
./stop_web.sh
./start_web.sh

# 刷新浏览器页面
```

---

## 快速修复方法

### 方法1：重启服务
```bash
cd MyDataCheck
./stop_web.sh
./start_web.sh
```

### 方法2：清除浏览器缓存
```
1. 打开浏览器设置
2. 清除缓存和Cookie
3. 重新访问 http://localhost:5001
```

### 方法3：检查配置
```bash
# 查看配置
cat api_comparison/config.json

# 确保：
# 1. CSV文件存在
# 2. API地址正确
# 3. 线程数合理（50-150）
# 4. 超时时间合理（30-60秒）
```

### 方法4：使用更小的测试数据
```
1. 准备一个小的CSV文件（10-20行）
2. 设置线程数为10
3. 设置超时为30秒
4. 测试执行
```

---

## 调试技巧

### 1. 查看实时日志
```bash
# 如果使用nohup启动
tail -f nohup.out

# 或者直接运行（不使用后台）
python web_app.py
```

### 2. 添加调试输出
在 `web/routes/api_routes.py` 中添加：
```python
print(f"DEBUG: 开始执行场景: {scenario.get('name')}")
print(f"DEBUG: CSV文件: {scenario.get('csv_file')}")
print(f"DEBUG: API地址: {scenario.get('api_url')}")
```

### 3. 使用浏览器开发者工具
```
1. F12 打开开发者工具
2. Network标签 - 查看请求状态
3. Console标签 - 查看JavaScript错误
4. 检查 /api/execute 请求的响应
```

---

## 预防措施

### 1. 合理配置参数
```json
{
  "scenarios": [{
    "thread_count": 100,     // 不要超过200
    "timeout": 60,           // 30-60秒合适
    "csv_file": "test.csv"   // 确保文件存在
  }],
  "global_config": {
    "default_thread_count": 100,
    "default_timeout": 60
  }
}
```

### 2. 分批执行
- 不要一次执行太多场景
- 建议每次执行1-3个场景
- 大数据量分批处理

### 3. 监控资源
```bash
# 监控CPU和内存
top

# 监控网络
netstat -an | grep 5001
```

---

## 紧急处理

### 如果页面完全卡死
```bash
# 1. 强制停止服务
pkill -9 -f web_app.py

# 2. 清理进程
ps aux | grep python | grep -v grep | awk '{print $2}' | xargs kill -9

# 3. 重启服务
cd MyDataCheck
./start_web.sh

# 4. 刷新浏览器
```

---

## 联系支持

如果以上方法都无法解决，请提供：
1. 浏览器控制台截图
2. 配置文件内容
3. CSV文件大小和行数
4. 执行时的具体表现

---

**更新时间**：2026-01-27  
**状态**：诊断指南
