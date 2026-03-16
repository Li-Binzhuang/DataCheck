# 🚨 紧急修复指南

## 问题现象

点击"执行合并"后：
- 显示"正在合并文件..."
- 输出面板显示"输出已清空..."
- 没有任何进度更新
- 没有错误提示

## 根本原因

**99%的可能性：服务器没有重启！**

修改Python代码后，必须重启服务器才能生效。

## 立即执行（5分钟解决）

### 第1步：停止服务器
```bash
# 在运行服务器的终端按 Ctrl+C
# 或者找到进程并kill
ps aux | grep "python.*web_app" | grep -v grep
kill -9 <进程ID>
```

### 第2步：重新启动服务器
```bash
cd /Users/zhanglifeng12703/Documents/OverseasPython/MyDataCheck
python web_app.py
```

**等待看到类似输出**:
```
* Running on http://172.20.32.92:5001/
* Running on http://127.0.0.1:5001/
```

### 第3步：清除浏览器缓存
1. 按 F12 打开开发者工具
2. 右键点击刷新按钮（地址栏旁边）
3. 选择"清空缓存并硬性重新加载"

### 第4步：测试服务端点
在浏览器中访问：
```
http://172.20.32.92:5001/merge-csv/test
```

**应该看到**:
```json
{
  "status": "ok",
  "message": "CSV合并服务正常运行",
  "output_dir": "outputdata/merge_csv",
  "chunk_size": 50000
}
```

如果看不到，说明服务器没启动或路由没注册。

### 第5步：使用测试页面
在浏览器中打开：
```
http://172.20.32.92:5001/test_merge_simple.html
```

或者直接打开项目目录下的 `test_merge_simple.html` 文件。

这个页面会：
- 自动测试服务端点
- 显示详细的调试日志
- 实时显示SSE消息

### 第6步：重新测试
1. 选择测试文件（vertical_test1.csv + vertical_test2.csv）
2. 选择"纵向合并"
3. 点击"执行合并"
4. 观察输出

## 如果还是不行

### 检查1：服务器日志
查看服务器终端，是否有Python错误？

常见错误：
```python
ImportError: No module named 'pandas'
# 解决：pip install pandas

NameError: name 'Response' is not defined
# 解决：检查导入语句

SyntaxError: invalid syntax
# 解决：检查Python代码语法
```

### 检查2：浏览器控制台
按 F12 → Console 标签，是否有JavaScript错误？

常见错误：
```javascript
Uncaught ReferenceError: executeMergeCsv is not defined
// 解决：清除缓存，确保JS文件已加载

Failed to fetch
// 解决：检查服务器是否运行，URL是否正确
```

### 检查3：网络请求
按 F12 → Network 标签：
1. 点击"执行合并"
2. 找到 `/merge-csv/execute` 请求
3. 检查状态码（应该是200）
4. 检查响应类型（应该是text/event-stream）
5. 查看响应内容（应该有data:开头的消息）

## 验证后端功能

运行调试脚本：
```bash
python debug_merge.py vertical
```

**应该看到**:
```
✅ 合并成功！
   总行数: 200
   总列数: 4
   输出文件: debug_vertical_output.csv
```

如果这个失败了，说明后端代码有问题。

## 常见问题

### Q1: 服务器启动失败
```bash
# 检查端口是否被占用
lsof -i :5001

# 如果被占用，kill掉
kill -9 <PID>

# 或者换个端口
python web_app.py --port 5002
```

### Q2: 找不到模块
```bash
# 确保在虚拟环境中
source .venv/bin/activate  # macOS/Linux
.venv\Scripts\activate     # Windows

# 安装依赖
pip install -r requirements.txt
```

### Q3: 路由没注册
检查 `web_app.py` 或 `web/app.py`：
```python
from web.routes.merge_csv_routes import merge_csv_bp
app.register_blueprint(merge_csv_bp)
```

### Q4: 文件权限问题
```bash
# 确保输出目录可写
mkdir -p outputdata/merge_csv
chmod 755 outputdata/merge_csv
```

## 最简单的测试方法

使用curl命令测试：
```bash
# 测试端点
curl http://172.20.32.92:5001/merge-csv/test

# 测试合并（需要先准备文件）
curl -X POST http://172.20.32.92:5001/merge-csv/execute \
  -F "files=@vertical_test1.csv" \
  -F "files=@vertical_test2.csv" \
  -F "merge_mode=vertical" \
  -F "output_filename=test"
```

## 终极解决方案

如果以上都不行，重新克隆代码或重新部署：

```bash
# 1. 备份当前代码
cp -r MyDataCheck MyDataCheck_backup

# 2. 重新拉取代码（如果有git）
git pull

# 3. 重新安装依赖
pip install -r requirements.txt

# 4. 重启服务器
python web_app.py
```

## 联系支持

如果问题仍未解决，请提供：
1. 服务器终端完整输出（从启动到错误）
2. 浏览器控制台完整输出（Console + Network）
3. `/merge-csv/test` 端点的响应
4. `python debug_merge.py vertical` 的输出

## 总结

**90%的情况下，只需要：**
1. 重启服务器（Ctrl+C → python web_app.py）
2. 清除浏览器缓存（F12 → 右键刷新 → 清空缓存）
3. 刷新页面
4. 重新测试

**如果还不行，使用测试页面**:
```
http://172.20.32.92:5001/test_merge_simple.html
```

这个页面会显示详细的调试信息，帮助定位问题。
