# 🔄 重启Web服务说明

## 问题原因

虚拟环境已经更新到 Python 3.12 并安装了 pandas，但 Web 服务可能还在使用旧的 Python 3.15 环境。

## 解决方案：重启Web服务

### 步骤1: 停止当前Web服务

如果Web服务正在运行，需要先停止它：

**方法1: 如果在前台运行**
- 按 `Ctrl + C` 停止服务

**方法2: 如果在后台运行**
```bash
# 查找进程
ps aux | grep web_app

# 停止进程（替换PID为实际进程ID）
kill <PID>
```

**方法3: 使用端口查找并停止**
```bash
# 查找占用5000端口的进程
lsof -ti:5000 | xargs kill -9
```

### 步骤2: 使用更新后的启动脚本

启动脚本已经更新，现在会自动：
- ✅ 激活虚拟环境
- ✅ 使用 Python 3.12
- ✅ 验证 pandas 是否安装
- ✅ 启动 Web 服务

```bash
cd MyDataCheck
./start_web.sh
```

### 步骤3: 验证修复

启动后，在浏览器中访问 `http://localhost:5000`，尝试上传和解析PKL文件。

如果仍然报错，检查：
1. 虚拟环境是否正确激活
2. pandas 是否已安装：`source .venv/bin/activate && python -c "import pandas; print(pandas.__version__)"`
3. Web服务使用的Python版本：查看启动日志中的 "当前Python版本"

## 快速重启命令

```bash
cd MyDataCheck
# 停止旧服务（如果存在）
lsof -ti:5000 | xargs kill -9 2>/dev/null || true
# 启动新服务
./start_web.sh
```

## 验证清单

- [ ] 虚拟环境使用 Python 3.12
- [ ] pandas 已安装（版本 3.0.0）
- [ ] Web服务已重启
- [ ] 启动日志显示正确的Python版本
- [ ] PKL功能可以正常使用
