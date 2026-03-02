# Docker 命令速查表

## 🎯 一句话总结
- **开发**: `docker-compose -f docker-compose.dev.yml up -d` (ARM原生，快)
- **部署**: `./build-docker.sh prod` → 导出镜像 → 上传服务器

---

## 📦 构建镜像

```bash
# 开发镜像（ARM原生，2-3分钟）
./build-docker.sh dev

# 生产镜像（x86，5-10分钟）
./build-docker.sh prod

# 同时构建两种
./build-docker.sh both
```

---

## 🚀 启动服务

### 开发环境（日常使用）
```bash
# 启动
docker-compose -f docker-compose.dev.yml up -d

# 查看日志
docker-compose -f docker-compose.dev.yml logs -f

# 重启
docker-compose -f docker-compose.dev.yml restart

# 停止
docker-compose -f docker-compose.dev.yml down
```

### 生产环境（测试x86镜像）
```bash
# 启动
docker-compose up -d

# 查看日志
docker-compose logs -f

# 停止
docker-compose down
```

---

## 📤 导出/导入镜像

### 导出（在ARM机器上）
```bash
# 导出生产镜像
docker save mydatacheck:prod-amd64 | gzip > mydatacheck-amd64.tar.gz

# 查看文件大小
ls -lh mydatacheck-amd64.tar.gz

# 上传到服务器
scp mydatacheck-amd64.tar.gz user@server:/path/to/
```

### 导入（在x86服务器上）
```bash
# 导入镜像
docker load < mydatacheck-amd64.tar.gz

# 验证镜像
docker images | grep mydatacheck

# 启动服务
docker-compose up -d
```

---

## 🔍 查看信息

```bash
# 查看所有镜像
docker images | grep mydatacheck

# 查看镜像架构
docker image inspect mydatacheck:dev-arm64 --format '{{.Architecture}}'
docker image inspect mydatacheck:prod-amd64 --format '{{.Architecture}}'

# 查看运行中的容器
docker ps

# 查看所有容器
docker ps -a

# 查看容器详情
docker inspect mydatacheck-dev
```

---

## 🐛 调试

```bash
# 查看日志（开发环境）
docker-compose -f docker-compose.dev.yml logs -f

# 查看日志（生产环境）
docker-compose logs -f

# 进入容器
docker exec -it mydatacheck-dev bash

# 查看容器资源使用
docker stats mydatacheck-dev

# 查看容器进程
docker top mydatacheck-dev
```

---

## 🧹 清理

```bash
# 停止并删除容器
docker-compose -f docker-compose.dev.yml down
docker-compose down

# 删除镜像
docker rmi mydatacheck:dev-arm64
docker rmi mydatacheck:prod-amd64

# 清理未使用的镜像
docker image prune -a

# 清理所有未使用的资源
docker system prune -a

# 清理构建缓存
docker builder prune -a
```

---

## 🔧 故障排查

### 端口被占用
```bash
# 查看端口占用
lsof -i :5001

# 杀死占用进程
kill -9 <PID>
```

### 容器无法启动
```bash
# 查看详细日志
docker-compose -f docker-compose.dev.yml logs

# 重新构建
docker-compose -f docker-compose.dev.yml up -d --build

# 清理后重试
docker-compose -f docker-compose.dev.yml down
docker system prune -a
./build-docker.sh dev
docker-compose -f docker-compose.dev.yml up -d
```

### 代码修改不生效
```bash
# 重启容器（开发模式已挂载代码）
docker-compose -f docker-compose.dev.yml restart

# 如果修改了依赖，需要重新构建
docker-compose -f docker-compose.dev.yml up -d --build
```

---

## 📊 性能对比

| 操作 | 开发模式 | 生产模式 |
|------|---------|---------|
| 构建时间 | 2-3分钟 | 5-10分钟 |
| 启动时间 | 5-10秒 | 10-20秒 |
| 运行性能 | 100% | 50-70% (ARM上) |
| 推荐用途 | 日常开发 | 构建部署 |

---

## 🎓 最佳实践

1. ✅ 日常开发用 `docker-compose.dev.yml`
2. ✅ 发布前构建 `prod-amd64` 镜像
3. ✅ 在x86服务器上运行生产镜像
4. ❌ 不要在ARM机器上长期运行x86容器

---

## 📚 文档链接

- 快速开始: `DOCKER_QUICK_START.md`
- 详细文档: `DOCKER_DEPLOYMENT.md`
- 文件说明: `DOCKER_README.md`

---

## 🆘 快速帮助

```bash
# 查看构建脚本帮助
./build-docker.sh

# 查看Docker版本
docker --version

# 查看Buildx版本
docker buildx version

# 查看支持的平台
docker buildx ls
```
