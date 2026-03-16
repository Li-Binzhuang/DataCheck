# 根目录脚本使用指南

本文档说明根目录中各个脚本的用途和使用方法。

## 🐳 Docker 相关脚本

### build-docker.sh
**用途**: 构建 Docker 镜像

```bash
./build-docker.sh
```

**功能**:
- 构建项目的 Docker 镜像
- 用于本地开发和测试

### check-docker-env.sh
**用途**: 检查 Docker 环境

```bash
./check-docker-env.sh
```

**功能**:
- 验证 Docker 是否正确安装
- 检查 Docker 环境配置
- 诊断 Docker 相关问题

### docker_deploy.sh
**用途**: Docker 部署脚本

```bash
./docker_deploy.sh
```

**功能**:
- 部署 Docker 容器
- 配置容器环境
- 启动应用服务

## 🚀 启动和停止脚本

### start_web.sh
**用途**: 启动 Web 服务

```bash
./start_web.sh
```

**功能**:
- 启动 Flask Web 应用
- 初始化服务环境
- 监听指定端口

### stop_web.sh
**用途**: 停止 Web 服务

```bash
./stop_web.sh
```

**功能**:
- 优雅地停止 Web 服务
- 清理资源
- 关闭监听端口

## 🌐 部署脚本

### deploy-to-server.sh
**用途**: 部署到服务器

```bash
./deploy-to-server.sh
```

**功能**:
- 部署应用到远程服务器
- 配置服务器环境
- 启动远程服务

### sync_with_remote.sh
**用途**: 与远程同步

```bash
./sync_with_remote.sh
```

**功能**:
- 同步本地代码到远程
- 更新远程配置
- 保持版本一致

## 📋 快速参考

| 脚本 | 用途 | 场景 |
|------|------|------|
| build-docker.sh | 构建镜像 | 本地开发、CI/CD |
| check-docker-env.sh | 检查环境 | 环境诊断 |
| docker_deploy.sh | 部署容器 | 容器部署 |
| start_web.sh | 启动服务 | 本地开发 |
| stop_web.sh | 停止服务 | 本地开发 |
| deploy-to-server.sh | 服务器部署 | 生产部署 |
| sync_with_remote.sh | 远程同步 | 代码同步 |

## ⚙️ 常见操作

### 本地开发流程
```bash
# 1. 检查 Docker 环境
./check-docker-env.sh

# 2. 构建镜像
./build-docker.sh

# 3. 启动服务
./start_web.sh

# 4. 开发...

# 5. 停止服务
./stop_web.sh
```

### 生产部署流程
```bash
# 1. 同步代码
./sync_with_remote.sh

# 2. 部署到服务器
./deploy-to-server.sh
```

## 📝 注意事项

- 所有脚本都需要执行权限
- 某些脚本可能需要 sudo 权限
- 建议在部署前备份重要数据
- 查看脚本内容了解具体操作

## 🔗 相关文档

- Docker 配置: `Dockerfile`, `docker-compose.yml`
- 更多脚本: `scripts/` 目录
- 详细说明: `docs/` 目录
