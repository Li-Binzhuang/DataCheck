# Docker 部署方案说明

## 📁 文件清单

| 文件 | 用途 | 说明 |
|------|------|------|
| `Dockerfile` | 镜像定义 | 支持多架构构建 |
| `docker-compose.dev.yml` | 开发环境 | ARM原生，高性能 |
| `docker-compose.yml` | 生产环境 | x86架构，用于部署 |
| `build-docker.sh` | 构建脚本 | 一键构建不同架构镜像 |
| `DOCKER_QUICK_START.md` | 快速开始 | 常用命令和工作流程 |
| `DOCKER_DEPLOYMENT.md` | 详细文档 | 完整的部署指南 |

## 🚀 快速开始

### 第一次使用

```bash
# 1. 构建开发镜像（ARM原生，用于日常开发）
./build-docker.sh dev

# 2. 启动开发环境
docker-compose -f docker-compose.dev.yml up -d

# 3. 访问应用
open http://localhost:5001
```

### 准备部署

```bash
# 1. 构建生产镜像（x86，用于服务器部署）
./build-docker.sh prod

# 2. 导出镜像
docker save mydatacheck:prod-amd64 | gzip > mydatacheck-amd64.tar.gz

# 3. 上传到服务器并部署
scp mydatacheck-amd64.tar.gz user@server:/path/to/
```

## 📖 文档导航

### 新手入门
👉 先看 `DOCKER_QUICK_START.md`
- 快速上手命令
- 常见使用场景
- 故障排查

### 深入了解
👉 再看 `DOCKER_DEPLOYMENT.md`
- 架构原理
- 性能分析
- 高级配置
- 最佳实践

## 💡 核心概念

### 两种模式

**开发模式** (`docker-compose.dev.yml`)
- ✅ ARM原生运行
- ✅ 性能100%
- ✅ 代码热更新
- ✅ 快速迭代
- 📍 用于：日常开发和测试

**生产模式** (`docker-compose.yml`)
- ✅ x86架构
- ✅ 可直接部署
- ⚠️ 构建较慢（5-10分钟）
- ⚠️ ARM上运行慢（仅用于验证）
- 📍 用于：构建部署镜像

### 为什么需要两种模式？

你的情况：
- 开发机器是ARM（Apple Silicon）
- 生产服务器是x86

如果只用一种模式：
- ❌ 只用ARM镜像：无法部署到x86服务器
- ❌ 只用x86镜像：在ARM机器上开发性能差

使用两种模式：
- ✅ 开发时用ARM镜像：性能好，开发快
- ✅ 部署时用x86镜像：服务器原生运行

## 🎯 使用建议

### 日常开发
```bash
# 使用开发模式（ARM原生）
docker-compose -f docker-compose.dev.yml up -d
```

### 准备发布
```bash
# 构建生产镜像（x86）
./build-docker.sh prod
```

### 查看帮助
```bash
# 查看构建脚本帮助
./build-docker.sh
```

## ❓ 常见问题

**Q: 我应该用哪个模式？**  
A: 日常开发用 `docker-compose.dev.yml`，准备部署时构建 `prod-amd64` 镜像

**Q: 为什么生产镜像构建这么慢？**  
A: 跨架构构建需要QEMU模拟器，这是正常现象

**Q: 可以在ARM机器上测试x86镜像吗？**  
A: 可以，但性能会降低50%左右，仅用于功能验证

**Q: 代码修改后需要重新构建吗？**  
A: 开发模式已挂载代码目录，Python代码修改自动生效

**Q: 如何查看容器日志？**  
A: `docker-compose -f docker-compose.dev.yml logs -f`

## 📞 获取帮助

遇到问题？按顺序查看：
1. `DOCKER_QUICK_START.md` - 故障排查章节
2. `DOCKER_DEPLOYMENT.md` - 常见问题章节
3. 查看容器日志：`docker-compose logs`

## 🔗 相关资源

- [Docker官方文档](https://docs.docker.com/)
- [Docker Buildx文档](https://docs.docker.com/buildx/working-with-buildx/)
- [多架构镜像构建](https://docs.docker.com/build/building/multi-platform/)
