# MyDataCheck - 数据对比工具平台

[![Version](https://img.shields.io/badge/version-2.3-blue.svg)](https://github.com/yourusername/MyDataCheck)
[![Python](https://img.shields.io/badge/python-3.12-green.svg)](https://www.python.org/)
[![Flask](https://img.shields.io/badge/flask-latest-red.svg)](https://flask.palletsprojects.com/)

一个功能强大的数据对比工具平台，提供Web界面用于多种数据对比场景。

## ✨ 主要功能

- 📡 **接口数据对比** - 对比API返回数据与预期数据
- 🌐 **线上灰度落数对比** - 对比线上环境与灰度环境的数据差异
- 📊 **数据对比** - 对比两个CSV/XLSX文件的数据差异
- 📦 **PKL文件解析** - 解析PKL文件并转换为CSV格式

## 🚀 快速开始

### 首次安装

```bash
# 设置Python 3.12环境（首次使用）
./scripts/setup/setup_python312.sh

# 或手动安装依赖
pip install -r requirements.txt
```

### 启动服务

```bash
# 启动Web服务
./start_web.sh

# 访问界面
open http://localhost:5001
```

### 停止服务

```bash
./stop_web.sh
```

### 其他脚本

```bash
# 环境设置脚本
./scripts/setup/setup_python312.sh    # 设置Python 3.12环境
./scripts/setup/install_pandas.sh     # 安装pandas依赖

# 测试脚本
./tests/test_api_execute.sh           # 测试接口对比功能
```

## 📚 文档

完整文档请查看 [docs/INDEX.md](docs/INDEX.md)

### 快速导航

- [快速开始指南](docs/01_快速开始/QUICK_START.md)
- [Web界面使用说明](docs/02_Web界面/Web界面使用说明.md)
- [数据对比快速参考](docs/04_数据对比功能/数据对比快速参考.md)
- [PKL功能快速参考](docs/05_PKL功能/PKL功能快速参考.md)
- [问题修复记录](docs/09_问题修复记录/README.md)

## 🏗️ 项目结构

```
MyDataCheck/
├── start_web.sh            # 启动服务
├── stop_web.sh             # 停止服务
├── web_app.py              # 主入口
├── requirements.txt        # 依赖清单
│
├── web/                    # Flask应用
├── static/                 # 静态资源 (CSS/JS)
├── templates/              # HTML模板
│
├── api_comparison/         # 接口对比功能
├── online_comparison/      # 线上对比功能
├── data_comparison/        # 数据对比功能
├── common/                 # 公共模块
│
├── scripts/                # 脚本工具
│   ├── setup/              # 环境设置脚本
│   └── archive/            # 归档脚本
│
├── tests/                  # 测试脚本
├── docs/                   # 文档
├── inputdata/              # 输入数据
└── outputdata/             # 输出数据
```

## 🔧 技术栈

- **后端**: Python 3.12, Flask
- **前端**: HTML5, CSS3, JavaScript (原生)
- **数据处理**: Pandas, NumPy
- **文件格式**: CSV, XLSX, PKL

## 📝 版本历史

### v2.4 (2026-01-27)
- ✅ 脚本文件整理优化
- ✅ 根目录脚本: 9个 → 2个 (↓ 78%)
- ✅ 脚本分类归档 (setup/archive)
- ✅ 项目结构更清晰

### v2.3 (2026-01-27)
- ✅ 前端代码拆分优化 (4506行 → 296行)
- ✅ 文档结构整理
- ✅ 问题修复记录模块
- ✅ 元素ID统一规范

### v2.0 (2026-01-27)
- ✅ Web应用模块化重构
- ✅ 侧边栏UI优化
- ✅ 代码注释完善

查看完整版本历史: [docs/06_历史版本/](docs/06_历史版本/)

## 🤝 贡献

欢迎提交问题和改进建议！

## 📄 许可证

MIT License

---

**最后更新**: 2026-01-27  
**项目版本**: v2.4
