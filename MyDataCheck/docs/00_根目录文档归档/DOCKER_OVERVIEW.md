# Docker 跨架构部署方案总览

## 🎯 方案目标

解决在 ARM 机器（Apple Silicon）上开发，部署到 x86 服务器的问题。

## ✨ 核心特性

### 双模式设计
1. **开发模式**: ARM 原生镜像，高性能开发测试
2. **生产模式**: x86 镜像，直接部署到服务器

### 主要优势
- ✅ 开发时性能100%（ARM原生）
- ✅ 代码热更新（开发模式挂载代码目录）
- ✅ 一键构建切换
- ✅ 生产镜像可直接部署

## 📁 文件结构

```
项目根目录/
├── Dockerfile                    # 镜像定义（支持多架构）
├── docker-compose.yml            # 生产环境配置（x86）
├── docker-compose.dev.yml        # 开发环境配置（ARM）
├── build-docker.sh               # 构建脚本（可执行）
├── .dockerignore                 # Docker忽略文件
│
├── DOCKER_OVERVIEW.md            # 本文档 - 方案总览
├── DOCKER_README.md              # 文件说明和导航
├── DOCKER_QUICK_START.md         # 快速开始指南
├── DOCKER_DEPLOYMENT.md          # 详细部署文档
└── DOCKER_CHEATSHEET.md          # 命令速查表
```

## 🚀 快速开始（3步）

### 1️⃣ 构建开发镜像
```bash
./build-docker.sh dev
```

### 2️⃣ 启动开发环境
```bash
docker-compose -f docker-compose.dev.yml up -d
```

### 3️⃣ 访问应用
```bash
open http://localhost:5001
```

## 📖 文档导航

### 🆕 新手入门
**从这里开始** → `DOCKER_README.md`
- 了解文件用途
- 核心概念
- 快速开始

### 🏃 快速上手
**日常使用** → `DOCKER_QUICK_START.md`
- 常用命令
- 工作流程
- 故障排查

### 📚 深入学习
**详细了解** → `DOCKER_DEPLOYMENT.md`
- 架构原理
- 性能分析
- 最佳实践

### ⚡ 速查表
**快速查询** → `DOCKER_CHEATSHEET.md`
- 常用命令
- 一键复制
- 快速参考

## 🔄 典型工作流程

### 场景1: 日常开发
```bash
# 1. 首次启动
./build-docker.sh dev
docker-compose -f docker-compose.dev.yml up -d

# 2. 修改代码（自动生效）
# 编辑 Python 文件...

# 3. 查看效果
open http://localhost:5001

# 4. 查看日志
docker-compose -f docker-compose.dev.yml logs -f
```

### 场景2: 准备发布
```bash
# 1. 在开发环境测试通过
docker-compose -f docker-compose.dev.yml up -d

# 2. 构建生产镜像
./build-docker.sh prod

# 3. 导出镜像
docker save mydatacheck:prod-amd64 | gzip > mydatacheck-amd64.tar.gz

# 4. 上传到服务器
scp mydatacheck-amd64.tar.gz user@server:/path/to/

# 5. 在服务器上部署
ssh user@server
docker load < mydatacheck-amd64.tar.gz
docker-compose up -d
```

## 📊 两种模式对比

| 特性 | 开发模式 | 生产模式 |
|------|---------|---------|
| **架构** | ARM64 | AMD64 (x86_64) |
| **镜像名** | mydatacheck:dev-arm64 | mydatacheck:prod-amd64 |
| **配置文件** | docker-compose.dev.yml | docker-compose.yml |
| **构建时间** | 2-3分钟 | 5-10分钟 |
| **运行性能** | 100% (ARM上) | 50-70% (ARM上) |
| **代码挂载** | ✅ 支持热更新 | ❌ 不挂载 |
| **推荐用途** | 日常开发测试 | 构建部署镜像 |
| **启动命令** | `docker-compose -f docker-compose.dev.yml up -d` | `docker-compose up -d` |

## 🎓 使用建议

### ✅ 推荐做法
1. 日常开发使用开发模式（ARM原生）
2. 在开发环境完成所有功能测试
3. 发布前构建生产镜像（x86）
4. 在x86服务器上运行生产镜像

### ❌ 不推荐做法
1. 在ARM机器上长期运行x86容器（性能差）
2. 每次代码修改都重新构建镜像（开发模式已挂载代码）
3. 在生产环境使用开发镜像（架构不匹配）

## 🔧 核心技术

### Docker Buildx
- 支持多架构构建
- 使用QEMU模拟器
- 自动处理平台差异

### 代码挂载（开发模式）
```yaml
volumes:
  - ./web:/app/web
  - ./common:/app/common
  - ./api_comparison:/app/api_comparison
  - ./data_comparison:/app/data_comparison
```

### 平台指定（生产模式）
```yaml
build:
  platforms:
    - linux/amd64
platform: linux/amd64
```

## 💡 常见问题

**Q: 为什么需要两种模式？**  
A: 开发时用ARM原生获得最佳性能，部署时用x86匹配服务器架构。

**Q: 生产镜像构建为什么慢？**  
A: 跨架构构建需要QEMU模拟器，这是正常现象。

**Q: 可以只用一种模式吗？**  
A: 可以，但会牺牲开发性能或部署兼容性。

**Q: 代码修改后需要重启吗？**  
A: 开发模式下Python代码修改自动生效，无需重启。

**Q: 如何验证镜像架构？**  
A: `docker image inspect <镜像名> --format '{{.Architecture}}'`

## 🆘 获取帮助

### 按问题类型查找

| 问题类型 | 查看文档 |
|---------|---------|
| 不知道从哪开始 | `DOCKER_README.md` |
| 需要快速上手 | `DOCKER_QUICK_START.md` |
| 遇到具体问题 | `DOCKER_QUICK_START.md` → 故障排查 |
| 想深入了解 | `DOCKER_DEPLOYMENT.md` |
| 忘记命令 | `DOCKER_CHEATSHEET.md` |

### 查看日志
```bash
# 开发环境
docker-compose -f docker-compose.dev.yml logs -f

# 生产环境
docker-compose logs -f
```

### 验证环境
```bash
# 检查Docker
docker --version

# 检查Buildx
docker buildx version

# 查看镜像
docker images | grep mydatacheck
```

## 🔗 相关资源

- [Docker官方文档](https://docs.docker.com/)
- [Docker Buildx](https://docs.docker.com/buildx/working-with-buildx/)
- [多架构构建](https://docs.docker.com/build/building/multi-platform/)
- [Docker Compose](https://docs.docker.com/compose/)

## 📝 版本信息

- Docker版本要求: >= 19.03
- Docker Compose版本: >= 3.8
- Python版本: 3.12
- 基础镜像: python:3.12-slim

## 🎉 开始使用

现在你已经了解了整个方案，可以：

1. 阅读 `DOCKER_README.md` 了解文件结构
2. 按照 `DOCKER_QUICK_START.md` 快速开始
3. 遇到问题查看 `DOCKER_CHEATSHEET.md`
4. 需要深入了解查看 `DOCKER_DEPLOYMENT.md`

祝你使用愉快！🚀
