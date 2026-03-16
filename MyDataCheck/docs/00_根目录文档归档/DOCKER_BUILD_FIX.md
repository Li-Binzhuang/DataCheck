# Docker 跨架构构建修复说明

## 问题原因

在 ARM Mac 上使用普通 `docker build` 命令会构建 ARM64 架构的镜像，导致在 AMD64 服务器上运行时出现 `exec format error` 错误。

## 解决方案

使用 Docker Buildx 进行跨架构构建，明确指定目标平台为 `linux/amd64`。

## 正确的构建流程

### 方法 1: 使用修复后的脚本（推荐）

```bash
# 构建 AMD64 镜像并导出
./scripts/docker_deploy.sh build

# 镜像会自动导出到 docker_exports/mydatacheck-amd64.tar.gz
```

### 方法 2: 使用原有的 build-docker.sh

```bash
# 构建生产环境镜像（AMD64）
./build-docker.sh prod

# 导出镜像
docker save mydatacheck:prod-amd64 | gzip > mydatacheck-amd64.tar.gz
```

### 方法 3: 手动构建

```bash
# 1. 创建 buildx 构建器
docker buildx create --name mybuilder --use
docker buildx inspect --bootstrap

# 2. 构建 AMD64 镜像
docker buildx build \
    --platform linux/amd64 \
    --tag mydatacheck:prod-amd64 \
    --load \
    .

# 3. 验证架构
docker image inspect mydatacheck:prod-amd64 --format '{{.Architecture}}'
# 应该输出: amd64

# 4. 导出镜像
docker save mydatacheck:prod-amd64 | gzip > mydatacheck-amd64.tar.gz
```

## 部署到服务器

```bash
# 1. 上传镜像到服务器
scp mydatacheck-amd64.tar.gz user@server:/path/to/

# 2. 在服务器上导入
ssh user@server
docker load < mydatacheck-amd64.tar.gz

# 3. 启动容器
docker run -d \
    --name mydatacheck \
    -p 5001:5001 \
    -v ./inputdata:/app/inputdata \
    -v ./outputdata:/app/outputdata \
    -v ./logs:/app/logs \
    mydatacheck:prod-amd64
```

## 验证镜像架构

在构建后，务必验证镜像架构：

```bash
# 本地验证
docker image inspect mydatacheck:prod-amd64 --format '{{.Architecture}}'

# 服务器验证（导入后）
docker image inspect mydatacheck:prod-amd64 --format '{{.Architecture}}'
```

两者都应该输出 `amd64`。

## 注意事项

1. 跨架构构建比原生构建慢 5-10 倍，需要耐心等待
2. 确保 Docker 版本支持 Buildx（Docker 19.03+）
3. 首次构建会下载 QEMU 模拟器，需要网络连接
4. 构建完成后，镜像大小约 500-800MB

## 已修复的文件

- `scripts/docker_deploy.sh` - 添加了 buildx 跨架构构建支持
- `docker-compose.yml` - 修复了 platforms 配置错误
