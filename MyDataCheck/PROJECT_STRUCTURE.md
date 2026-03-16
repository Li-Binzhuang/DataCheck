# MyDataCheck 项目结构速查表

## 🎯 快速导航

### 📚 文档
- **项目说明**: `README.md`
- **脚本指南**: `SCRIPTS_GUIDE.md`
- **快速开始**: `docs/01_快速开始/`
- **所有文档**: `docs/00_根目录文档归档/INDEX.md`

### 🚀 启动脚本
```bash
./start_web.sh          # 启动 Web 服务
./stop_web.sh           # 停止 Web 服务
./build-docker.sh       # 构建 Docker 镜像
./docker_deploy.sh      # 部署 Docker 容器
```

### 🧪 测试和调试
- **测试文件**: `scripts/test_files/`
- **调试脚本**: `scripts/debug_scripts/`

### 📦 主要模块
- **Web 应用**: `web/` - Flask 应用
- **数据对比**: `data_comparison/` - 数据对比功能
- **API 对比**: `api_comparison/` - API 对比功能
- **通用工具**: `common/` - 共享工具函数

### 📂 数据目录
- **输入数据**: `inputdata/`
- **输出数据**: `outputdata/`
- **日志文件**: `logs/`
- **测试数据**: `test_data/`

## 📋 常见任务

### 启动开发环境
```bash
# 1. 检查 Docker
./check-docker-env.sh

# 2. 启动服务
./start_web.sh

# 3. 访问 http://localhost:5000
```

### 部署到生产
```bash
# 1. 同步代码
./sync_with_remote.sh

# 2. 部署
./deploy-to-server.sh
```

### 运行测试
```bash
cd scripts/test_files/
python test_merge_csv.py
```

### 调试问题
```bash
cd scripts/debug_scripts/
python diagnose_csv.py
```

## 🔍 文件查找

| 我要找... | 位置 |
|---------|------|
| 项目说明 | `README.md` |
| 快速开始 | `docs/01_快速开始/QUICK_START.md` |
| Web 界面说明 | `docs/02_Web界面/` |
| 数据对比功能 | `docs/04_数据对比功能/` |
| 问题修复 | `docs/09_问题修复记录/` |
| 历史文档 | `docs/00_根目录文档归档/` |
| 启动脚本 | 根目录 `*.sh` |
| Docker 配置 | `Dockerfile`, `docker-compose.yml` |
| 测试脚本 | `scripts/test_files/` |
| 调试脚本 | `scripts/debug_scripts/` |

## 🛠️ 常用命令

```bash
# 启动服务
./start_web.sh

# 停止服务
./stop_web.sh

# 构建 Docker 镜像
./build-docker.sh

# 检查 Docker 环境
./check-docker-env.sh

# 部署到服务器
./deploy-to-server.sh

# 运行测试
cd scripts/test_files && python test_merge_csv.py

# 查看日志
tail -f logs/gunicorn_error.log
```

## 📞 获取帮助

1. **查看项目文档**: `README.md`
2. **查看脚本说明**: `SCRIPTS_GUIDE.md`
3. **查看功能文档**: `docs/` 目录
4. **查看问题修复**: `docs/09_问题修复记录/`
5. **查看历史文档**: `docs/00_根目录文档归档/INDEX.md`

---

**最后更新**: 2026-03-16
