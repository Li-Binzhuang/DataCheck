# MyDataCheck 快速参考

## 🚀 快速启动

```bash
cd MyDataCheck
./start_web.sh
```

访问: http://127.0.0.1:5001

## 📁 项目结构

```
MyDataCheck/
├── README.md              # 项目说明
├── web_app.py             # Web 入口
├── start_web.sh           # 启动（软链接）
├── stop_web.sh            # 停止（软链接）
├── scripts/               # 脚本目录
│   ├── cleanup/           # 清理脚本
│   ├── startup/           # 启动脚本
│   └── maintenance/       # 维护脚本
├── tests/archived/        # 测试归档
└── docs/                  # 文档
```

## 🔧 常用命令

### 启动和停止

```bash
# 启动服务
./start_web.sh

# 停止服务
./stop_web.sh
# 或按 Ctrl+C
```

### 清理文件

```bash
# 清理旧文件（试运行）
python scripts/cleanup/cleanup_old_files.py --dry-run

# 清理旧文件（正式执行）
./scripts/cleanup/cleanup_now.sh

# 清理冗余文件
python scripts/cleanup/cleanup_redundant_files.py
```

### 维护检查

```bash
# 检查启动环境
python scripts/maintenance/check_startup.py
```

## 📖 文档位置

| 文档 | 位置 |
|------|------|
| 快速开始 | docs/01_快速开始/QUICK_START.md |
| 安装指南 | docs/01_快速开始/INSTALL.md |
| 清理指南 | docs/01_快速开始/CLEANUP_GUIDE.md |
| 内存优化 | docs/01_快速开始/MEMORY_OPTIMIZATION.md |
| 目录结构 | docs/01_快速开始/项目目录结构.md |
| 清理脚本说明 | scripts/cleanup/README.md |
| 启动脚本说明 | scripts/startup/README.md |
| 维护脚本说明 | scripts/maintenance/README.md |

## 🎯 核心功能

1. **接口数据对比** - 对比 API 返回数据
2. **线上灰度落数对比** - 对比线上环境数据
3. **数据对比** - 对比 CSV/XLSX 文件
4. **PKL 文件解析** - 解析 PKL 文件

## ⚡ 性能优化

- ✅ 内存占用降低 80%
- ✅ 写入性能提升 5-20倍
- ✅ 支持 10-50万行数据
- ✅ 实时进度显示

## 🧹 自动清理

```bash
# 设置自动清理（每天凌晨2点）
./scripts/cleanup/setup_auto_cleanup.sh
```

## 🔍 问题排查

### 启动失败

```bash
# 检查环境
python scripts/maintenance/check_startup.py

# 检查端口
lsof -i:5001

# 查看日志
tail -f logs/app.log
```

### 依赖问题

```bash
# 安装依赖
source .venv/bin/activate
pip install -r requirements.txt

# 或使用脚本
./scripts/startup/install_psutil.sh
```

## 📞 获取帮助

- 查看 README: `cat README.md`
- 查看文档: `ls docs/`
- 查看脚本说明: `cat scripts/*/README.md`

---

**版本**: v2.3+  
**更新**: 2026-01-27  
**状态**: ✅ 生产就绪
