# MyDataCheck Shell 脚本使用指南

## 脚本分类总览

### 📊 脚本统计

| 类别 | 数量 | 状态 | 位置 |
|------|------|------|------|
| 启动脚本 | 4个 | ✅ 活跃 | scripts/startup/ |
| 清理脚本 | 2个 | ✅ 活跃 | scripts/cleanup/ |
| 安装脚本 | 2个 | ✅ 活跃 | scripts/setup/ |
| 测试脚本 | 1个 | ⚠️ 测试用 | tests/ |
| 归档脚本 | 4个 | 📦 已归档 | scripts/archive/ |
| 软链接 | 2个 | ✅ 活跃 | 根目录 |

---

## 一、启动脚本（scripts/startup/）

### 1.1 start_web.sh ⭐ 最常用

**功能**: 启动 Web 服务（开发模式）

**特点**:
- ✅ 自动检查虚拟环境
- ✅ 自动安装缺失依赖
- ✅ 验证 pandas、psutil 等依赖
- ✅ 隐藏 Flask 开发服务器警告
- ✅ 友好的错误提示

**使用方法**:
```bash
# 方式一：使用根目录软链接（推荐）
cd MyDataCheck
./start_web.sh

# 方式二：使用完整路径
./scripts/startup/start_web.sh
```

**适用场景**:
- 本地开发
- 个人使用
- 快速测试

**端口**: 5001

**可重复使用**: ✅ 是
- 可在任何 MyDataCheck 项目中使用
- 需要确保项目结构一致

---

### 1.2 start_web_production.sh

**功能**: 启动 Web 服务（生产模式，使用 Gunicorn）

**特点**:
- ✅ 使用 Gunicorn WSGI 服务器
- ✅ 自动计算工作进程数（CPU核心数 × 2 + 1）
- ✅ 记录访问日志和错误日志
- ✅ 支持高并发
- ✅ 自动重启失败的工作进程

**使用方法**:
```bash
./scripts/startup/start_web_production.sh
```

**适用场景**:
- 团队共享
- 正式部署
- 高并发场景
- 生产环境

**配置**:
- 工作进程数: 自动计算
- 超时时间: 300秒
- 最大请求数: 1000（防止内存泄漏）
- 日志: logs/access.log, logs/error.log

**可重复使用**: ✅ 是
- 可在任何 Flask 项目中使用
- 需要修改应用入口（web_app:app）

---

### 1.3 stop_web.sh

**功能**: 停止 Web 服务

**特点**:
- ✅ 自动查找占用 5001 端口的进程
- ✅ 强制停止所有相关进程
- ✅ 二次确认确保完全停止
- ✅ 友好的状态提示

**使用方法**:
```bash
# 方式一：使用根目录软链接
./stop_web.sh

# 方式二：使用完整路径
./scripts/startup/stop_web.sh

# 方式三：使用 Ctrl+C（如果在前台运行）
```

**可重复使用**: ✅ 是
- 可用于停止任何占用 5001 端口的服务
- 可修改端口号适配其他服务

---

### 1.4 install_psutil.sh

**功能**: 快速安装 psutil 依赖

**特点**:
- ✅ 检查虚拟环境
- ✅ 自动激活虚拟环境
- ✅ 安装 psutil
- ✅ 验证安装成功

**使用方法**:
```bash
./scripts/startup/install_psutil.sh
```

**适用场景**:
- 首次安装
- 依赖缺失时快速修复

**可重复使用**: ✅ 是
- 可用于任何需要 psutil 的 Python 项目
- 需要修改虚拟环境路径

---

## 二、清理脚本（scripts/cleanup/）

### 2.1 cleanup_now.sh ⭐ 推荐使用

**功能**: 立即执行清理（交互式）

**特点**:
- ✅ 支持试运行模式（--dry-run）
- ✅ 可自定义保留天数（--days）
- ✅ 交互式确认（安全）
- ✅ 详细的帮助信息
- ✅ 友好的进度提示

**使用方法**:
```bash
# 试运行（查看将要删除的文件）
./scripts/cleanup/cleanup_now.sh --dry-run

# 删除 5 天前的文件（默认）
./scripts/cleanup/cleanup_now.sh

# 删除 7 天前的文件
./scripts/cleanup/cleanup_now.sh --days 7

# 试运行 + 自定义天数
./scripts/cleanup/cleanup_now.sh --days 3 --dry-run

# 查看帮助
./scripts/cleanup/cleanup_now.sh --help
```

**清理范围**:
- outputdata/ 目录下的 .csv 文件
- inputdata/ 目录下的 .csv 文件
- 递归扫描所有子目录

**可重复使用**: ✅ 是
- 可用于任何需要定期清理 CSV 文件的项目
- 需要修改清理目录路径

---

### 2.2 setup_auto_cleanup.sh

**功能**: 设置自动清理定时任务

**特点**:
- ✅ 配置 cron 定时任务
- ✅ 每天凌晨 2:00 自动执行
- ✅ 检测并替换已存在的任务
- ✅ 自动创建日志目录
- ✅ 详细的配置说明

**使用方法**:
```bash
# 设置自动清理
./scripts/cleanup/setup_auto_cleanup.sh

# 查看当前 cron 任务
crontab -l

# 查看清理日志
tail -f logs/cleanup.log

# 删除自动清理任务
crontab -l | grep -v 'cleanup_old_files.py' | crontab -
```

**定时配置**:
- 执行时间: 每天凌晨 2:00
- 保留天数: 5 天
- 日志文件: logs/cleanup.log

**可重复使用**: ✅ 是
- 可用于任何需要定期清理的项目
- 需要修改脚本路径和清理参数

---

## 三、安装脚本（scripts/setup/）

### 3.1 setup_python312.sh ⭐ 环境配置

**功能**: 一键设置 Python 3.12 环境

**特点**:
- ✅ 自动检查并安装 Python 3.12
- ✅ 删除旧虚拟环境
- ✅ 创建新虚拟环境
- ✅ 安装所有依赖
- ✅ 验证安装成功
- ✅ 完整的步骤提示

**使用方法**:
```bash
./scripts/setup/setup_python312.sh
```

**执行步骤**:
1. 检查并安装 Python 3.12（使用 Homebrew）
2. 删除旧的虚拟环境
3. 创建新的虚拟环境
4. 激活虚拟环境
5. 升级 pip
6. 安装项目依赖
7. 验证安装

**适用场景**:
- 首次安装
- Python 版本不兼容（如 3.15）
- 虚拟环境损坏
- 依赖问题

**可重复使用**: ✅ 是
- 可用于任何 Python 项目
- 需要修改 Python 版本号和依赖文件

---

### 3.2 install_pandas.sh

**功能**: 安装 pandas 及相关依赖

**特点**:
- ✅ 检查 Python 版本
- ✅ 警告 Python 3.15 兼容性问题
- ✅ 升级 pip
- ✅ 安装 pandas、numpy、Flask、requests
- ✅ 验证安装

**使用方法**:
```bash
./scripts/setup/install_pandas.sh
```

**安装的包**:
- pandas >= 2.0.0
- numpy >= 1.24.0
- Flask >= 2.0.0
- requests >= 2.25.0

**可重复使用**: ✅ 是
- 可用于任何需要 pandas 的项目
- 需要修改依赖版本

---

## 四、测试脚本（tests/）

### 4.1 test_api_execute.sh

**功能**: 测试接口对比执行

**特点**:
- ⚠️ 仅用于测试
- 创建临时测试配置
- 使用 curl 发送 POST 请求
- 设置超时时间

**使用方法**:
```bash
# 确保 Web 服务已启动
./start_web.sh

# 在另一个终端运行测试
./tests/test_api_execute.sh
```

**可重复使用**: ⚠️ 有限
- 需要修改测试配置
- 需要修改 API 地址
- 主要用于开发测试

---

## 五、归档脚本（scripts/archive/）

这些脚本已归档，不再推荐使用：

| 脚本 | 原功能 | 状态 |
|------|--------|------|
| cleanup_redundant_files.sh | 清理冗余文件 | 📦 已被 Python 版本替代 |
| organize_all_files.sh | 整理所有文件 | 📦 已完成，不再需要 |
| organize_files.sh | 整理文件 | 📦 已完成，不再需要 |
| switch_to_port_5001.sh | 切换端口 | 📦 已固定端口，不再需要 |

---

## 六、软链接（根目录）

### 6.1 start_web.sh → scripts/startup/start_web.sh

**目的**: 便于快速启动

**使用**:
```bash
./start_web.sh
```

### 6.2 stop_web.sh → scripts/startup/stop_web.sh

**目的**: 便于快速停止

**使用**:
```bash
./stop_web.sh
```

---

## 七、脚本可重复使用性分析

### ✅ 高度可重复使用（可直接用于其他项目）

| 脚本 | 可重复使用性 | 需要修改的内容 |
|------|-------------|---------------|
| cleanup_now.sh | ⭐⭐⭐⭐⭐ | 清理目录路径 |
| setup_auto_cleanup.sh | ⭐⭐⭐⭐⭐ | 脚本路径、清理参数 |
| stop_web.sh | ⭐⭐⭐⭐⭐ | 端口号 |
| install_psutil.sh | ⭐⭐⭐⭐ | 虚拟环境路径、包名 |
| setup_python312.sh | ⭐⭐⭐⭐ | Python 版本、依赖文件 |

### ⚠️ 中度可重复使用（需要适配）

| 脚本 | 可重复使用性 | 需要修改的内容 |
|------|-------------|---------------|
| start_web.sh | ⭐⭐⭐ | 虚拟环境路径、应用入口、依赖检查 |
| start_web_production.sh | ⭐⭐⭐ | 应用入口、日志路径、端口 |
| install_pandas.sh | ⭐⭐⭐ | 依赖列表、版本要求 |

### ❌ 低度可重复使用（项目特定）

| 脚本 | 可重复使用性 | 原因 |
|------|-------------|------|
| test_api_execute.sh | ⭐⭐ | 测试配置特定于项目 |

---

## 八、脚本使用最佳实践

### 8.1 日常使用流程

```bash
# 1. 首次安装（如果需要）
./scripts/setup/setup_python312.sh

# 2. 启动服务
./start_web.sh

# 3. 使用完毕后停止
./stop_web.sh

# 4. 定期清理（每周或每月）
./scripts/cleanup/cleanup_now.sh --dry-run  # 先预览
./scripts/cleanup/cleanup_now.sh            # 确认后执行
```

### 8.2 自动化设置

```bash
# 设置自动清理（一次性）
./scripts/cleanup/setup_auto_cleanup.sh

# 查看定时任务
crontab -l

# 查看清理日志
tail -f logs/cleanup.log
```

### 8.3 问题排查

```bash
# 检查环境
python scripts/maintenance/check_startup.py

# 检查端口占用
lsof -i:5001

# 强制停止服务
./stop_web.sh

# 重新安装依赖
./scripts/setup/install_pandas.sh
```

---

## 九、脚本改进建议

### 9.1 已实现的优化

- ✅ 统一的错误处理
- ✅ 友好的用户提示
- ✅ 详细的帮助信息
- ✅ 参数验证
- ✅ 日志记录
- ✅ 交互式确认

### 9.2 可选的进一步优化

1. **配置文件化**
   - 将硬编码的参数提取到配置文件
   - 便于不同环境的配置管理

2. **日志增强**
   - 所有脚本统一日志格式
   - 集中日志管理

3. **错误恢复**
   - 添加失败重试机制
   - 自动回滚功能

4. **健康检查**
   - 启动后自动验证服务状态
   - 定期健康检查

---

## 十、快速参考

### 最常用的命令

```bash
# 启动服务
./start_web.sh

# 停止服务
./stop_web.sh

# 清理文件（试运行）
./scripts/cleanup/cleanup_now.sh --dry-run

# 清理文件（正式执行）
./scripts/cleanup/cleanup_now.sh

# 设置自动清理
./scripts/cleanup/setup_auto_cleanup.sh

# 环境配置
./scripts/setup/setup_python312.sh
```

### 脚本位置速查

```
scripts/
├── startup/
│   ├── start_web.sh              # 启动服务
│   ├── start_web_production.sh   # 生产模式启动
│   ├── stop_web.sh               # 停止服务
│   └── install_psutil.sh         # 安装 psutil
├── cleanup/
│   ├── cleanup_now.sh            # 立即清理
│   └── setup_auto_cleanup.sh     # 设置自动清理
└── setup/
    ├── setup_python312.sh        # 配置 Python 3.12
    └── install_pandas.sh         # 安装 pandas
```

---

**文档版本**: 1.0  
**更新时间**: 2026-01-27  
**维护者**: MyDataCheck Team
