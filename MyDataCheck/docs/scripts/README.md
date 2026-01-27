# Shell 脚本文档

本目录包含 MyDataCheck 项目中所有 Shell 脚本的详细文档。

## 📚 文档列表

| 文档 | 说明 | 适用对象 |
|------|------|----------|
| [Shell脚本使用指南.md](Shell脚本使用指南.md) | 完整的脚本使用说明 | 所有用户 |
| [可重用脚本模板.md](可重用脚本模板.md) | 可在其他项目中重用的脚本模板 | 开发者 |

## 🚀 快速开始

### 查看所有脚本

```bash
# 启动脚本
ls scripts/startup/

# 清理脚本
ls scripts/cleanup/

# 安装脚本
ls scripts/setup/
```

### 最常用的脚本

```bash
# 启动服务
./start_web.sh

# 停止服务
./stop_web.sh

# 清理文件
./scripts/cleanup/cleanup_now.sh --dry-run
```

## 📊 脚本分类

### 启动脚本（scripts/startup/）

| 脚本 | 功能 | 可重用性 |
|------|------|----------|
| start_web.sh | 启动 Web 服务（开发模式） | ⭐⭐⭐ |
| start_web_production.sh | 启动 Web 服务（生产模式） | ⭐⭐⭐ |
| stop_web.sh | 停止 Web 服务 | ⭐⭐⭐⭐⭐ |
| install_psutil.sh | 安装 psutil 依赖 | ⭐⭐⭐⭐ |

### 清理脚本（scripts/cleanup/）

| 脚本 | 功能 | 可重用性 |
|------|------|----------|
| cleanup_now.sh | 立即执行清理 | ⭐⭐⭐⭐⭐ |
| setup_auto_cleanup.sh | 设置自动清理定时任务 | ⭐⭐⭐⭐⭐ |

### 安装脚本（scripts/setup/）

| 脚本 | 功能 | 可重用性 |
|------|------|----------|
| setup_python312.sh | 配置 Python 3.12 环境 | ⭐⭐⭐⭐ |
| install_pandas.sh | 安装 pandas 及依赖 | ⭐⭐⭐ |

## 🎯 使用场景

### 场景 1: 首次安装

```bash
# 1. 配置 Python 环境
./scripts/setup/setup_python312.sh

# 2. 启动服务
./start_web.sh
```

### 场景 2: 日常使用

```bash
# 启动
./start_web.sh

# 停止
./stop_web.sh
```

### 场景 3: 定期清理

```bash
# 手动清理
./scripts/cleanup/cleanup_now.sh --dry-run  # 预览
./scripts/cleanup/cleanup_now.sh            # 执行

# 自动清理
./scripts/cleanup/setup_auto_cleanup.sh     # 设置一次即可
```

### 场景 4: 问题排查

```bash
# 停止服务
./stop_web.sh

# 检查环境
python scripts/maintenance/check_startup.py

# 重新安装依赖
./scripts/setup/install_pandas.sh

# 重新启动
./start_web.sh
```

## 🔧 在其他项目中使用

### 高度可重用的脚本

这些脚本可以直接复制到其他项目使用：

1. **cleanup_now.sh** - 通用清理脚本
   - 只需修改清理目录路径
   - 支持任何文件类型

2. **setup_auto_cleanup.sh** - 自动清理配置
   - 只需修改脚本路径和参数
   - 适用于任何需要定期清理的项目

3. **stop_web.sh** - 服务停止脚本
   - 只需修改端口号
   - 适用于任何 Web 服务

详细的重用指南请查看：[可重用脚本模板.md](可重用脚本模板.md)

## 📖 详细文档

### Shell脚本使用指南

包含以下内容：
- 所有脚本的详细说明
- 使用方法和示例
- 参数说明
- 适用场景
- 最佳实践
- 问题排查

[查看完整指南 →](Shell脚本使用指南.md)

### 可重用脚本模板

包含以下内容：
- 6 个通用脚本模板
- 修改指南
- 使用建议
- 注意事项
- 快速参考

[查看模板文档 →](可重用脚本模板.md)

## 💡 提示

### 脚本权限

如果脚本无法执行，添加执行权限：

```bash
chmod +x scripts/startup/*.sh
chmod +x scripts/cleanup/*.sh
chmod +x scripts/setup/*.sh
```

### 查看帮助

大多数脚本支持 `--help` 参数：

```bash
./scripts/cleanup/cleanup_now.sh --help
```

### 日志查看

```bash
# 清理日志
tail -f logs/cleanup.log

# Web 服务日志（生产模式）
tail -f logs/access.log
tail -f logs/error.log
```

## 🔗 相关文档

- [项目目录结构](../01_快速开始/项目目录结构.md)
- [快速开始](../01_快速开始/QUICK_START.md)
- [清理指南](../01_快速开始/CLEANUP_GUIDE.md)

---

**文档版本**: 1.0  
**更新时间**: 2026-01-27  
**维护者**: MyDataCheck Team
