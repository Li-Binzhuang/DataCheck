# MyDataCheck 项目理解总结

## 📋 项目概述

**MyDataCheck** 是一个功能强大的数据对比工具平台，提供 Web 界面用于多种数据对比场景。

- **版本**: v2.4 (2026-01-27)
- **技术栈**: Python 3.12, Flask, Pandas, NumPy
- **主要特性**: 模块化架构、流式处理、内存优化

---

## 🎯 核心功能

### 1. **接口数据对比** (API Comparison)
- **模块**: `api_comparison/`
- **功能**: 对比 API 返回数据与预期数据
- **核心类**: `DataComparator`, `DataComparatorOptimized`
- **关键功能**:
  - 时间戳规范化处理
  - 特征值转换（字符串→数字）
  - 配置管理和场景支持

### 2. **线上灰度落数对比** (Online Comparison)
- **模块**: `online_comparison/`
- **功能**: 对比线上环境与灰度环境的数据差异
- **用途**: 灰度发布验证

### 3. **数据对比** (Data Comparison)
- **模块**: `data_comparison/`
- **功能**: 对比两个 CSV/XLSX 文件的数据差异
- **特性**:
  - 支持多键对比
  - 流式处理大文件
  - 内存优化（降低 80%）

### 4. **PKL 文件解析** (PKL Conversion)
- **模块**: `common/pkl_converter.py`
- **功能**: 解析 PKL 文件并转换为 CSV 格式
- **特性**:
  - 字典展平处理
  - 预览功能
  - 支持嵌套结构

### 5. **CSV 合并** (CSV Merge)
- **模块**: `web/routes/merge_csv_routes.py`
- **功能**: 纵向/横向合并 CSV 文件
- **特性**:
  - 支持多文件合并
  - 进度回调
  - 流式写入

---

## 🏗️ 项目架构

### 目录结构

```
MyDataCheck/
├── web/                          # Flask Web 应用
│   ├── app.py                    # 应用主入口
│   ├── config.py                 # 配置管理
│   ├── routes/                   # 路由蓝图
│   │   ├── main.py              # 主页路由
│   │   ├── api_routes.py        # API 对比路由
│   │   ├── compare_routes.py    # 数据对比路由
│   │   ├── batch_run_routes.py  # 批量运行路由
│   │   ├── merge_csv_routes.py  # CSV 合并路由
│   │   └── download_routes.py   # 文件下载路由
│   ├── templates/                # HTML 模板
│   └── static/                   # CSS/JS 静态资源
│
├── api_comparison/               # 接口对比功能
│   ├── execute_comparison_flow.py
│   └── job/
│       ├── compare_api_data.py
│       ├── config_manager.py
│       ├── convert_feature_to_number.py
│       └── fetch_api_data.py
│
├── data_comparison/              # 数据对比功能
│   ├── execute_data_comparison.py
│   └── job/
│       ├── data_comparator.py
│       ├── config_manager.py
│       └── report_generator.py
│
├── online_comparison/            # 线上对比功能
│
├── common/                       # 公共工具模块
│   ├── core_logger.py           # 日志系统
│   ├── task_manager.py          # 任务管理
│   ├── csv_tool.py              # CSV 工具
│   ├── pkl_converter.py         # PKL 转换
│   ├── memory_manager.py        # 内存管理
│   ├── auto_cleanup.py          # 自动清理
│   ├── stop_controller.py       # 停止控制
│   └── report_generator.py      # 报告生成
│
├── scripts/                      # 脚本工具
│   ├── setup/                   # 环境设置脚本
│   └── archive/                 # 归档脚本
│
├── MyDataCheck/logs/            # 执行日志
│   ├── {task_id}_info.json     # 任务信息
│   └── {task_id}_logs.jsonl    # 任务日志
│
├── inputdata/                   # 输入数据目录
├── outputdata/                  # 输出数据目录
│
├── web_app.py                   # 主入口
├── requirements.txt             # 依赖清单
├── Dockerfile                   # Docker 配置
└── docker-compose.yml           # Docker Compose 配置
```

---

## 🔄 工作流程

### 1. Web 应用启动流程

```
web_app.py (主入口)
    ↓
web/app.py::create_app()
    ├─ 初始化 Flask 应用
    ├─ 设置模板和静态文件目录
    ├─ 配置文件上传大小限制 (5GB)
    ├─ 初始化目录结构 (inputdata, outputdata, logs)
    ├─ 启动定时清理任务 (每日凌晨3点)
    └─ 注册所有路由蓝图
    ↓
web/app.py::main()
    └─ 启动 Flask 服务器 (默认 0.0.0.0:5001)
```

### 2. 数据对比执行流程

```
用户提交配置
    ↓
web/routes/compare_routes.py::execute_compare()
    ├─ 验证配置
    ├─ 创建任务 (TaskManager)
    ├─ 启动后台线程执行对比
    └─ 返回任务 ID
    ↓
data_comparison/job/data_comparator.py::compare_two_files()
    ├─ 读取两个文件
    ├─ 数据规范化
    ├─ 逐行对比
    ├─ 生成差异报告
    └─ 流式写入结果
    ↓
common/report_generator.py
    └─ 生成 CSV 报告
    ↓
输出文件保存到 outputdata/
```

### 3. API 对比执行流程

```
用户提交配置
    ↓
web/routes/api_routes.py::execute_comparison_flow()
    ├─ 加载配置
    ├─ 创建任务
    └─ 启动后台线程
    ↓
api_comparison/job/fetch_api_data.py
    ├─ 调用 API 获取数据
    └─ 保存响应
    ↓
api_comparison/job/compare_api_data.py::DataComparator
    ├─ 规范化时间戳
    ├─ 转换特征值
    ├─ 对比数据
    └─ 生成报告
    ↓
输出文件保存到 outputdata/
```

---

## 🛠️ 关键模块详解

### 1. **TaskManager** (任务管理)
- **位置**: `common/task_manager.py`
- **功能**:
  - 创建和管理任务
  - 记录任务状态和进度
  - 生成任务 ID
  - 保存任务日志

### 2. **CoreLogger** (日志系统)
- **位置**: `common/core_logger.py`
- **功能**:
  - 记录执行事件
  - 跟踪进度
  - 生成 JSONL 格式日志
  - 支持自定义日志目录

### 3. **CSVStreamWriter** (流式 CSV 写入)
- **位置**: `common/csv_tool.py`
- **功能**:
  - 流式写入 CSV 文件
  - 内存优化（不加载整个文件）
  - 支持大文件处理

### 4. **MemoryManager** (内存管理)
- **位置**: `common/memory_manager.py`
- **功能**:
  - 监控内存使用
  - 强制垃圾回收
  - 清理变量

### 5. **AutoCleanup** (自动清理)
- **位置**: `common/auto_cleanup.py`
- **功能**:
  - 定时清理旧文件
  - 支持自定义保留天数
  - 后台调度执行

### 6. **StopController** (停止控制)
- **位置**: `common/stop_controller.py`
- **功能**:
  - 单例模式
  - 控制任务停止
  - 支持多任务管理

---

## 📊 数据流

### 输入数据
- **位置**: `inputdata/`
- **格式**: CSV, XLSX, JSON, PKL
- **用途**: 用户上传的对比源数据

### 输出数据
- **位置**: `outputdata/`
- **格式**: CSV (对比结果)
- **内容**:
  - 差异分析报告
  - 特征统计信息
  - 合并数据结果

### 日志数据
- **位置**: `MyDataCheck/logs/`
- **格式**: JSON (info) + JSONL (logs)
- **内容**:
  - 任务元信息
  - 执行日志
  - 错误信息

---

## 🚀 启动和运行

### 启动服务
```bash
./start_web.sh
# 或
python web_app.py
```

### 访问界面
```
http://localhost:5001
```

### 停止服务
```bash
./stop_web.sh
```

### 环境变量配置
```bash
SERVER_PORT=5001              # 服务端口
SERVER_HOST=0.0.0.0          # 服务地址
CLEANUP_RETENTION_DAYS=3      # 清理保留天数
```

---

## 📦 依赖清单

```
Flask>=2.0.0          # Web 框架
requests>=2.25.0      # HTTP 请求
pandas>=2.0.0         # 数据处理
numpy>=1.24.0         # 数值计算
psutil>=5.9.0         # 系统监控
schedule>=1.2.0       # 任务调度
openpyxl>=3.0.0       # Excel 处理
```

---

## 🔐 安全特性

1. **文件上传限制**: 5GB 最大限制
2. **文件类型验证**: 白名单检查
3. **路径安全**: 防止目录遍历
4. **自动清理**: 定期清理旧数据

---

## 📈 性能优化

1. **流式处理**: 使用 CSVStreamWriter 处理大文件
2. **内存优化**: 内存占用降低 80%
3. **异步执行**: 后台线程处理对比任务
4. **定时清理**: 自动清理过期数据

---

## 🐳 Docker 支持

- **Dockerfile**: 容器镜像配置
- **docker-compose.yml**: 多容器编排
- **docker-compose.dev.yml**: 开发环境配置

---

## 📝 配置文件

### 数据对比配置
- **位置**: `data_comparison/config.json`
- **格式**: JSON
- **内容**: 对比场景、键列、对比列等

### API 对比配置
- **位置**: `api_comparison/config.json`
- **格式**: JSON
- **内容**: API 端点、参数、预期数据等

---

## 🎓 项目特点

1. **模块化设计**: 功能独立，易于扩展
2. **Web 界面**: 用户友好的操作界面
3. **多功能支持**: 4 种主要对比功能
4. **内存优化**: 支持大文件处理
5. **日志完善**: 详细的执行记录
6. **自动清理**: 定期清理过期数据
7. **Docker 支持**: 容器化部署

---

## 🔗 相关文档

- **快速开始**: `docs/01_快速开始/QUICK_START.md`
- **Web 界面说明**: `docs/02_Web界面/Web界面使用说明.md`
- **数据对比功能**: `docs/04_数据对比功能/`
- **PKL 功能**: `docs/05_PKL功能/`
- **问题修复记录**: `docs/09_问题修复记录/`

---

**最后更新**: 2026-03-16  
**项目版本**: v2.4
