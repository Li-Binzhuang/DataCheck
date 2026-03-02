# Docker 快速开始指南

## 🎯 使用场景

你的情况：
- **开发机器**: ARM架构（Apple Silicon Mac）
- **生产服务器**: x86架构
- **需求**: 在ARM机器上开发测试，构建x86镜像用于部署

## 📋 两种模式

### 1️⃣ 开发模式（推荐日常使用）
- **架构**: ARM原生
- **性能**: 高性能，无模拟损耗
- **用途**: 本地开发和功能测试
- **镜像**: `mydatacheck:dev-arm64`

### 2️⃣ 生产模式（用于部署）
- **架构**: x86 (amd64)
- **性能**: 构建慢（跨架构），运行慢（ARM上测试时）
- **用途**: 构建用于x86服务器的镜像
- **镜像**: `mydatacheck:prod-amd64`

## 🚀 快速开始

### 日常开发（ARM原生，推荐）

```bash
# 1. 构建开发镜像
./build-docker.sh dev

# 2. 启动开发环境
docker-compose -f docker-compose.dev.yml up -d

# 3. 查看日志
docker-compose -f docker-compose.dev.yml logs -f

# 4. 访问应用
open http://localhost:5001

# 5. 停止服务
docker-compose -f docker-compose.dev.yml down
```

### 准备生产部署（x86跨架构）

```bash
# 1. 构建生产镜像（需要5-10分钟）
./build-docker.sh prod

# 2. 导出镜像
docker save mydatacheck:prod-amd64 | gzip > mydatacheck-amd64.tar.gz

# 3. 上传到x86服务器
scp mydatacheck-amd64.tar.gz user@server:/path/to/

# 4. 在服务器上导入并运行
# ssh user@server
# docker load < mydatacheck-amd64.tar.gz
# docker-compose up -d
```

## 📝 常用命令

### 构建命令

```bash
# 只构建开发镜像（ARM原生，快速）
./build-docker.sh dev

# 只构建生产镜像（x86，慢）
./build-docker.sh prod

# 同时构建两种镜像
./build-docker.sh both
```

### 开发环境操作

```bash
# 启动（后台运行）
docker-compose -f docker-compose.dev.yml up -d

# 启动（查看日志）
docker-compose -f docker-compose.dev.yml up

# 重启服务
docker-compose -f docker-compose.dev.yml restart

# 停止服务
docker-compose -f docker-compose.dev.yml down

# 查看日志
docker-compose -f docker-compose.dev.yml logs -f

# 进入容器
docker exec -it mydatacheck-dev bash
```

### 生产环境操作

```bash
# 启动（用于在ARM机器上测试x86镜像）
docker-compose up -d

# 查看日志
docker-compose logs -f

# 停止服务
docker-compose down
```

### 镜像管理

```bash
# 查看所有镜像
docker images | grep mydatacheck

# 删除开发镜像
docker rmi mydatacheck:dev-arm64

# 删除生产镜像
docker rmi mydatacheck:prod-amd64

# 清理未使用的镜像
docker image prune -a
```

## 🔄 典型工作流程

### 场景1: 日常开发
```bash
# 第一次使用
./build-docker.sh dev
docker-compose -f docker-compose.dev.yml up -d

# 修改代码后（代码已挂载，自动生效）
# 如果修改了依赖，需要重新构建
./build-docker.sh dev
docker-compose -f docker-compose.dev.yml up -d --build
```

### 场景2: 准备发布
```bash
# 1. 在开发环境测试通过
docker-compose -f docker-compose.dev.yml up -d

# 2. 构建生产镜像
./build-docker.sh prod

# 3. （可选）在ARM机器上测试x86镜像
docker-compose up -d
# 访问 http://localhost:5001 测试功能

# 4. 导出镜像
docker save mydatacheck:prod-amd64 | gzip > mydatacheck-amd64.tar.gz

# 5. 部署到服务器
scp mydatacheck-amd64.tar.gz user@server:/path/to/
```

## ⚡ 性能对比

| 操作 | 开发模式(ARM) | 生产模式(x86) |
|------|--------------|--------------|
| 构建时间 | 2-3分钟 | 5-10分钟 |
| 启动时间 | 5-10秒 | 10-20秒 |
| 运行性能 | 100% | 50-70% (ARM上) |
| 推荐用途 | 日常开发测试 | 构建部署镜像 |

## 🎓 最佳实践

1. **日常开发**: 始终使用开发模式（ARM原生）
   ```bash
   docker-compose -f docker-compose.dev.yml up -d
   ```

2. **功能测试**: 在开发模式下完成所有测试

3. **准备发布**: 构建生产镜像并导出
   ```bash
   ./build-docker.sh prod
   docker save mydatacheck:prod-amd64 | gzip > mydatacheck-amd64.tar.gz
   ```

4. **生产部署**: 在x86服务器上导入镜像运行

5. **代码修改**: 开发模式已挂载代码目录，修改后自动生效（Python代码）

## 🐛 故障排查

### 问题1: 构建失败
```bash
# 检查Docker版本
docker --version

# 检查Buildx
docker buildx version

# 清理并重试
docker system prune -a
./build-docker.sh dev
```

### 问题2: 容器无法启动
```bash
# 查看日志
docker-compose -f docker-compose.dev.yml logs

# 检查端口占用
lsof -i :5001

# 重新构建
docker-compose -f docker-compose.dev.yml up -d --build
```

### 问题3: x86镜像构建太慢
这是正常现象，跨架构构建需要QEMU模拟器。建议：
- 使用缓存（第二次构建会快很多）
- 或在x86服务器上直接构建

### 问题4: 代码修改不生效
```bash
# 开发模式已挂载代码，Python代码修改会自动生效
# 如果修改了依赖或配置，需要重启
docker-compose -f docker-compose.dev.yml restart

# 如果还不行，重新构建
docker-compose -f docker-compose.dev.yml up -d --build
```

## 📚 文件说明

- `Dockerfile` - Docker镜像定义
- `docker-compose.dev.yml` - 开发环境配置（ARM原生）
- `docker-compose.yml` - 生产环境配置（x86）
- `build-docker.sh` - 构建脚本
- `DOCKER_DEPLOYMENT.md` - 详细部署文档

## 💡 提示

- 开发时使用 `docker-compose.dev.yml`，性能最好
- 发布前构建 `prod-amd64` 镜像
- 不要在ARM机器上长期运行x86容器（性能差）
- 生产环境在x86服务器上运行x86镜像（性能最佳）
