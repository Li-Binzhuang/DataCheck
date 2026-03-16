# Docker 跨架构部署指南

## 概述

本项目提供双模式Docker方案：
1. **开发模式**: ARM原生镜像，用于本地高性能开发测试
2. **生产模式**: x86镜像，用于服务器部署

## 架构说明

- **开发机器**: ARM64 (Apple Silicon / M1/M2/M3)
- **目标服务器**: AMD64 (x86_64)
- **解决方案**: 
  - 开发环境使用ARM原生镜像（高性能）
  - 生产环境使用Docker Buildx跨架构构建x86镜像

## 核心优势

✅ **开发模式**: ARM原生运行，性能100%，快速迭代  
✅ **生产模式**: 构建x86镜像，直接部署到服务器  
✅ **代码挂载**: 开发模式支持代码热更新  
✅ **一键切换**: 简单命令在两种模式间切换

## 前置要求

1. Docker Desktop 或 Docker Engine (版本 >= 19.03)
2. Docker Buildx 插件（Docker Desktop 自带）
3. 启用 QEMU 模拟器（Docker Desktop 自动配置）

### 验证环境

```bash
# 检查Docker版本
docker --version

# 检查Buildx是否可用
docker buildx version

# 查看支持的平台
docker buildx ls
```

## 快速开始

### 推荐工作流程

```bash
# 1. 日常开发（ARM原生，高性能）
./build-docker.sh dev
docker-compose -f docker-compose.dev.yml up -d

# 2. 准备发布（构建x86镜像）
./build-docker.sh prod

# 3. 导出镜像用于部署
docker save mydatacheck:prod-amd64 | gzip > mydatacheck-amd64.tar.gz
```

### 方法一：使用构建脚本（推荐）

```bash
# 查看帮助
./build-docker.sh

# 构建开发镜像（ARM原生，2-3分钟）
./build-docker.sh dev

# 构建生产镜像（x86，5-10分钟）
./build-docker.sh prod

# 同时构建两种镜像
./build-docker.sh both
```

### 方法二：使用 docker-compose

#### 开发环境（ARM原生）

```bash
# 构建并启动
docker-compose -f docker-compose.dev.yml up -d --build

# 查看日志
docker-compose -f docker-compose.dev.yml logs -f

# 停止服务
docker-compose -f docker-compose.dev.yml down
```

#### 生产环境（x86）

```bash
# 构建并启动（会自动构建x86镜像）
docker-compose up -d --build

# 查看日志
docker-compose logs -f

# 停止服务
docker-compose down
```

### 方法三：手动构建

```bash
# 1. 创建buildx构建器
docker buildx create --name mybuilder --use

# 2. 启动构建器
docker buildx inspect --bootstrap

# 3. 构建x86镜像
docker buildx build \
    --platform linux/amd64 \
    --tag mydatacheck:latest \
    --load \
    .

# 4. 验证架构
docker image inspect mydatacheck:latest --format '{{.Architecture}}'
# 应该输出: amd64

# 5. 启动容器
docker-compose up -d
```

## 镜像导出与部署

### 在 ARM 机器上导出镜像

```bash
# 导出为压缩文件
docker save mydatacheck:latest | gzip > mydatacheck-amd64.tar.gz

# 查看文件大小
ls -lh mydatacheck-amd64.tar.gz
```

### 在 x86 服务器上导入镜像

```bash
# 1. 上传镜像文件到服务器
scp mydatacheck-amd64.tar.gz user@server:/path/to/

# 2. 在服务器上导入镜像
docker load < mydatacheck-amd64.tar.gz

# 3. 验证镜像
docker images | grep mydatacheck

# 4. 启动容器（需要docker-compose.yml文件）
docker-compose up -d
```

## 性能说明

### 构建性能对比

| 模式 | 架构 | 构建时间 | 说明 |
|------|------|---------|------|
| 开发模式 | ARM → ARM | 2-3分钟 | 原生构建，快速 |
| 生产模式 | ARM → x86 | 5-10分钟 | 跨架构构建，使用QEMU |

### 运行性能对比

| 环境 | 架构匹配 | 性能 | 推荐用途 |
|------|---------|------|---------|
| ARM机器 + ARM镜像 | ✅ 原生 | 100% | 日常开发测试 |
| ARM机器 + x86镜像 | ❌ 模拟 | 50-70% | 功能验证（不推荐） |
| x86服务器 + x86镜像 | ✅ 原生 | 100% | 生产环境 |

### 最佳实践

1. **开发阶段**: 使用开发模式（ARM原生），获得最佳性能
2. **测试阶段**: 在开发模式下完成所有功能测试
3. **发布阶段**: 构建生产镜像（x86），导出用于部署
4. **生产环境**: 在x86服务器上运行x86镜像，获得最佳性能

## 常见问题

### 1. 构建速度慢

这是正常现象，跨架构构建需要使用 QEMU 模拟器。优化建议：

- 使用构建缓存
- 在 x86 服务器上直接构建（如果可能）
- 使用 CI/CD 在 x86 环境构建

### 2. 容器启动失败

```bash
# 检查容器日志
docker-compose logs

# 检查容器架构
docker inspect mydatacheck | grep Architecture

# 确保是 amd64
```

### 3. 在 ARM 机器上测试 x86 镜像

```bash
# 可以运行，但性能较差（仅用于功能测试）
docker-compose up -d

# 访问 Web 界面
open http://localhost:5001
```

### 4. 清理构建器

```bash
# 删除构建器
docker buildx rm mybuilder

# 清理构建缓存
docker buildx prune -a
```

## 多架构镜像（可选）

如果需要同时支持 ARM 和 x86，可以构建多架构镜像：

```bash
# 构建并推送到 Docker Hub
docker buildx build \
    --platform linux/amd64,linux/arm64 \
    --tag yourusername/mydatacheck:latest \
    --push \
    .

# 拉取时会自动选择匹配的架构
docker pull yourusername/mydatacheck:latest
```

## 配置文件说明

### 文件结构

```
.
├── Dockerfile                    # 镜像定义（支持多架构）
├── docker-compose.yml            # 生产环境配置（x86）
├── docker-compose.dev.yml        # 开发环境配置（ARM）
├── build-docker.sh               # 构建脚本
├── DOCKER_QUICK_START.md         # 快速开始指南
└── DOCKER_DEPLOYMENT.md          # 本文档
```

### Dockerfile 关键配置

```dockerfile
# 支持多架构构建
FROM --platform=$TARGETPLATFORM python:3.12-slim

# 构建参数（Docker Buildx自动传入）
ARG TARGETPLATFORM
ARG BUILDPLATFORM

# 显示构建信息
RUN echo "Building for platform: $TARGETPLATFORM on $BUILDPLATFORM"
```

### docker-compose.dev.yml（开发环境）

```yaml
services:
  mydatacheck:
    build:
      context: .
      # 不指定平台，使用本机架构（ARM）
    image: mydatacheck:dev-arm64
    volumes:
      # 挂载代码目录，支持热更新
      - ./web:/app/web
      - ./common:/app/common
```

### docker-compose.yml（生产环境）

```yaml
services:
  mydatacheck:
    build:
      platforms:
        - linux/amd64  # 指定目标平台
    platform: linux/amd64  # 运行平台
    image: mydatacheck:prod-amd64
```

## 最佳实践

### 开发流程

```bash
# 1. 首次启动开发环境
./build-docker.sh dev
docker-compose -f docker-compose.dev.yml up -d

# 2. 修改代码（自动生效，无需重启）
# 编辑 web/、common/ 等目录下的Python文件

# 3. 如果修改了依赖或配置
docker-compose -f docker-compose.dev.yml restart

# 4. 查看日志
docker-compose -f docker-compose.dev.yml logs -f
```

### 发布流程

```bash
# 1. 在开发环境测试通过
docker-compose -f docker-compose.dev.yml up -d
# 访问 http://localhost:5001 进行测试

# 2. 构建生产镜像
./build-docker.sh prod

# 3. （可选）在ARM机器上测试x86镜像功能
docker-compose up -d
# 注意：性能会降低，仅用于功能验证

# 4. 导出镜像
docker save mydatacheck:prod-amd64 | gzip > mydatacheck-amd64.tar.gz

# 5. 上传到服务器
scp mydatacheck-amd64.tar.gz user@server:/path/to/

# 6. 在服务器上部署
ssh user@server
docker load < mydatacheck-amd64.tar.gz
docker-compose up -d
```

### 日常使用建议

1. **开发时**: 始终使用 `docker-compose.dev.yml`
2. **测试时**: 在开发环境完成所有测试
3. **发布前**: 构建生产镜像并验证
4. **部署时**: 在x86服务器上运行生产镜像

## 技术支持

如遇问题，请检查：

1. Docker 版本是否 >= 19.03
2. Buildx 是否正确安装
3. 构建日志中的错误信息
4. 容器运行日志

## 参考资料

- [Docker Buildx 文档](https://docs.docker.com/buildx/working-with-buildx/)
- [多架构镜像构建](https://docs.docker.com/build/building/multi-platform/)
- [QEMU 用户模式](https://www.qemu.org/docs/master/user/main.html)
