# 启动脚本

本目录包含项目启动和停止相关的脚本。

## 脚本说明

| 脚本 | 说明 | 使用方法 |
|------|------|----------|
| start_web.sh | 启动 Web 服务（开发模式） | `./start_web.sh` |
| start_web_production.sh | 启动 Web 服务（生产模式） | `./start_web_production.sh` |
| stop_web.sh | 停止 Web 服务 | `./stop_web.sh` |
| install_psutil.sh | 安装 psutil 依赖 | `./install_psutil.sh` |

## 快速启动

```bash
# 方式一：使用根目录的软链接（推荐）
cd MyDataCheck
./start_web.sh

# 方式二：使用完整路径
cd MyDataCheck
./scripts/startup/start_web.sh

# 停止服务
./stop_web.sh
# 或按 Ctrl+C
```

## 访问地址

启动成功后访问：
- **开发模式**: http://127.0.0.1:5001
- **局域网**: http://172.20.32.66:5001

## 首次使用

首次启动前需要安装依赖：

```bash
cd MyDataCheck
source .venv/bin/activate
pip install -r requirements.txt

# 或使用安装脚本
./scripts/startup/install_psutil.sh
```

## 注意事项

- 确保虚拟环境已激活
- 确保端口 5001 未被占用
- 生产模式需要配置环境变量
- 停止服务使用 Ctrl+C 或 stop_web.sh
