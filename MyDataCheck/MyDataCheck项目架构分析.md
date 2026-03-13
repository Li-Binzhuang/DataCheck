# MyDataCheck 项目架构分析

## 📋 项目概述

MyDataCheck是一个功能强大的数据对比工具平台，提供Web界面用于多种数据对比场景。

### 核心功能
- 📡 **接口数据对比** - 对比API返回数据与预期数据
- 🌐 **线上灰度落数对比** - 对比线上环境与灰度环境的数据差异
- 📊 **数据对比** - 对比两个CSV/XLSX文件的数据差异
- 📦 **PKL文件解析** - 解析PKL文件并转换为CSV格式
- 🔄 **批量跑数** - 批量调用接口获取特征值
- 📋 **CSV合并** - 合并多个CSV文件

---

## 🏗️ 项目架构

### 整体架构图
```
┌─────────────────────────────────────────────────────────┐
│                    Web层 (Flask)                         │
│                   web_app.py (入口)                      │
└────────────────────┬────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────┐
│                  路由层 (Blueprints)                     │
│  api_routes │ online_routes │ compare_routes │ ...      │
└────────────────────┬────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────┐
│                   执行层 (Execute)                       │
│  execute_comparison_flow.py │ execute_data_comparison.py│
└────────────────────┬────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────┐
│                   任务层 (Job)                           │
│  各模块的job目录：处理具体业务逻辑                        │
└────────────────────┬────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────┐
│                 公共工具层 (Common)                       │
│  task_manager │ core_logger │ csv_tool │ ...            │
└─────────────────────────────────────────────────────────┘
```

---

## 📁 目录结构与职责

### 1. 核心入口

- **web_app.py**: 主应用入口，导入web/app.py并启动Flask服务
- **web/app.py**: Flask应用创建和配置，注册蓝图，初始化目录
- **web/config.py**: 项目配置管理，定义目录结构和文件限制

### 2. Web路由层 (web/routes/)

| 路由模块 | 功能 | 核心端点 |
|---------|------|---------|
| **main.py** | 主页路由 | `/` - 渲染主界面 |
| **api_routes.py** | 接口数据对比 | `/api/execute` - 执行对比流程 |
| **online_routes.py** | 线上灰度对比 | `/online/execute` - 执行线上对比 |
| **compare_routes.py** | 数据对比 | `/compare/execute` - 执行数据对比 |
| **batch_run_routes.py** | 批量跑数 | `/batch_run/execute` - 执行批量跑数 |
| **pkl_routes.py** | PKL解析 | `/pkl/convert` - 转换PKL文件 |
| **merge_csv_routes.py** | CSV合并 | `/merge_csv/execute` - 合并CSV |
| **download_routes.py** | 文件下载 | `/download/<filename>` - 下载结果 |
| **stop_routes.py** | 任务控制 | `/stop/<task_id>` - 停止任务 |

### 3. 功能模块层

#### 3.1 接口数据对比 (api_comparison/)
```
api_comparison/
├── execute_comparison_flow.py    # 主执行脚本
├── config.json                   # 配置文件
└── job/                          # 任务处理模块
    ├── config_manager.py         # 配置管理
    ├── fetch_api_data.py         # API数据获取
    ├── compare_api_data.py       # 数据对比
    ├── streaming_comparator.py   # 流式对比（内存优化）
    └── process_executor.py       # 流程执行器
```

**核心逻辑**:
1. 读取CSV文件中的请求参数
2. 批量调用API获取返回数据
3. 对比API返回值与预期值
4. 生成对比报告（差异记录、特征统计、合并数据）


#### 3.2 线上灰度对比 (online_comparison/)
```
online_comparison/
├── execute_online_comparison_flow.py  # 主执行脚本
├── config.json                        # 配置文件
└── job/                               # 任务处理模块
    ├── JSON解析器.py                   # 解析JSON字段
    ├── 数据对比器.py                   # 对比数据
    └── 报告生成器.py                   # 生成报告
```

**核心逻辑**:
1. 解析CSV中的JSON字段，提取特征值
2. 对比线上和灰度环境的数据差异
3. 生成对比报告

#### 3.3 数据对比 (data_comparison/)
```
data_comparison/
├── execute_data_comparison.py    # 主执行脚本
├── config.json                   # 配置文件
└── job/                          # 任务处理模块
    ├── data_comparator.py        # 数据对比核心
    ├── report_generator.py       # 报告生成
    └── config_manager.py         # 配置管理
```

**核心逻辑**:
1. 读取两个CSV/XLSX文件
2. 根据主键列匹配数据行
3. 对比特征列的差异
4. 支持多主键、忽略零值/NaN、小数精度控制等高级功能

#### 3.4 批量跑数 (batch_run/)
```
batch_run/
├── config.json                   # 配置文件
└── job/
    └── batch_runner.py           # 批量跑数核心
```

**核心逻辑**:
1. 读取CSV文件中的参数
2. 多线程并发调用API
3. 提取API返回的特征值
4. 合并原始数据和特征值输出


### 4. 公共工具层 (common/)

| 工具模块 | 功能说明 |
|---------|---------|
| **task_manager.py** | 任务状态管理，支持任务创建、更新、日志记录 |
| **core_logger.py** | 核心日志系统，记录执行流程、性能分析、错误追踪 |
| **stop_controller.py** | 停止控制器，支持任务中断和停止信号 |
| **csv_tool.py** | CSV读写工具，支持编码检测、流式写入 |
| **value_comparator.py** | 值对比工具，支持数值、字符串、时间戳对比 |
| **report_generator.py** | 报告生成器，生成差异记录、特征统计、合并数据 |
| **pkl_converter.py** | PKL文件转换工具 |
| **data_formatter.py** | 数据格式化工具 |
| **memory_manager.py** | 内存管理工具，监控和优化内存使用 |
| **auto_cleanup.py** | 自动清理工具，定时清理旧文件 |

---

## 🔄 核心流程详解

### 1. 接口数据对比流程

```
用户上传CSV → 配置API参数 → 执行对比
                                 ↓
                    ┌────────────┴────────────┐
                    │                         │
            读取CSV文件                  注册任务
                    │                         │
                    ▼                         ▼
            批量调用API              记录任务状态
                    │                         │
                    ▼                         │
            流式对比数据 ←──────────────────────┘
                    │
                    ▼
            生成对比报告
                    │
                    ▼
            返回下载链接
```

**关键技术点**:
- **流式处理**: 使用`StreamingComparator`逐批处理数据，降低内存占用80%
- **并发请求**: 使用线程池并发调用API，提高效率
- **停止控制**: 支持任务中断，通过`StopController`实现


### 2. 数据对比流程

```
上传两个文件 → 配置对比参数 → 执行对比
                                  ↓
                    ┌─────────────┴─────────────┐
                    │                           │
            读取文件1和文件2              建立主键索引
                    │                           │
                    ▼                           ▼
            匹配数据行                    对比特征列
                    │                           │
                    ▼                           │
            计算差异值 ←────────────────────────┘
                    │
                    ▼
            生成三份报告
            ├─ 差异记录
            ├─ 特征统计
            └─ 合并数据
```

**关键技术点**:
- **多主键支持**: 支持单主键或复合主键匹配
- **智能对比**: 自动识别数值、字符串、时间戳类型
- **高级功能**: 
  - 忽略零值/NaN/空格
  - 小数精度控制
  - 列前缀/后缀配置

### 3. 任务管理流程

```
创建任务 → 注册到TaskManager
              ↓
        生成唯一task_id
              ↓
        记录任务信息
        ├─ 任务名称
        ├─ 任务类型
        ├─ 开始时间
        └─ 状态(pending)
              ↓
        执行任务逻辑
              ↓
        实时更新状态
        ├─ 进度百分比
        ├─ 当前阶段
        └─ 日志输出
              ↓
        任务完成/失败
              ↓
        更新最终状态
        └─ 保存日志文件
```

---

## 🔧 核心技术特性

### 1. 内存优化
- **流式写入**: 使用`CSVStreamWriter`逐行写入，避免内存堆积
- **批量处理**: 分批处理数据，每批1000行
- **及时释放**: 处理完立即释放内存

### 2. 性能优化
- **并发处理**: 使用线程池并发调用API
- **索引优化**: 使用字典索引加速数据匹配
- **缓存机制**: 缓存常用配置和数据


### 3. 任务控制
- **停止机制**: 通过`StopController`实现任务中断
- **状态管理**: 通过`TaskManager`管理任务生命周期
- **日志记录**: 通过`CoreLogger`记录详细执行日志

### 4. 文件处理
- **编码检测**: 自动检测CSV文件编码（UTF-8/GBK）
- **格式支持**: 支持CSV、XLSX、PKL格式
- **大文件处理**: 支持10GB以内的文件上传

---

## 📊 数据流转

### 输入数据流
```
用户上传文件 → inputdata/{module}/
                      ↓
                读取并解析
                      ↓
                执行业务逻辑
```

### 输出数据流
```
生成结果 → outputdata/{module}/
                ↓
          提供下载链接
                ↓
          用户下载文件
```

### 日志数据流
```
任务执行 → TaskManager记录
              ↓
        logs/{task_id}_logs.jsonl
              ↓
        Web界面实时展示
```

---

## 🔐 配置管理

### 配置文件结构
每个模块都有独立的`config.json`配置文件：

```json
{
  "scenarios": [
    {
      "name": "场景名称",
      "enabled": true,
      "sql_file": "文件1.csv",
      "api_file": "文件2.csv",
      "sql_key_column": 0,
      "api_key_column": 0,
      ...
    }
  ],
  "global_config": {
    "default_sql_key_column": 0,
    ...
  }
}
```

### 配置管理功能
- **加载配置**: 从JSON文件读取配置
- **保存配置**: 将配置写入JSON文件
- **场景管理**: 添加、更新、删除场景
- **参数验证**: 验证配置参数的有效性


---

## 🚀 启动流程

### 1. 应用启动
```python
web_app.py
  └─> web/app.py::create_app()
       ├─> init_directories()        # 初始化目录
       ├─> startup_cleanup()         # 启动清理任务
       └─> register_blueprints()     # 注册路由
            └─> 启动Flask服务 (0.0.0.0:5001)
```

### 2. 请求处理
```
用户请求 → Flask路由 → 路由处理函数
                           ↓
                    创建任务(TaskManager)
                           ↓
                    启动后台线程执行
                           ↓
                    返回task_id给前端
                           ↓
                    前端轮询任务状态
```

---

## 📦 依赖关系

### 模块依赖图
```
web_app.py
  └─> web/app.py
       └─> web/routes/*
            ├─> api_comparison/execute_*.py
            ├─> online_comparison/execute_*.py
            ├─> data_comparison/execute_*.py
            └─> batch_run/job/*.py
                 └─> common/*
                      ├─> task_manager.py
                      ├─> core_logger.py
                      ├─> csv_tool.py
                      └─> ...
```

### 核心依赖
- **Flask**: Web框架
- **pandas**: 数据处理（部分模块）
- **openpyxl**: Excel文件处理
- **requests**: HTTP请求
- **chardet**: 编码检测

---

## 🎯 设计模式

### 1. 单例模式
- `TaskManager`: 全局任务管理器
- `StopController`: 全局停止控制器

### 2. 工厂模式
- `create_app()`: 创建Flask应用实例

### 3. 策略模式
- 不同的对比策略（数值对比、字符串对比、时间戳对比）

### 4. 观察者模式
- 任务状态变化通知前端

---

## 📝 总结

MyDataCheck是一个设计良好的数据对比工具平台，具有以下特点：

1. **模块化设计**: 各功能模块独立，易于维护和扩展
2. **统一的公共层**: 通过common目录提供统一的工具类
3. **完善的任务管理**: 支持任务状态跟踪、日志记录、停止控制
4. **性能优化**: 流式处理、并发执行、内存优化
5. **用户友好**: Web界面操作简单，实时反馈任务进度
6. **灵活配置**: 支持JSON配置文件，参数可调

### 核心优势
- ✅ 支持多种数据对比场景
- ✅ 处理大文件能力强（10GB）
- ✅ 内存占用低（流式处理）
- ✅ 执行效率高（并发处理）
- ✅ 可扩展性强（模块化设计）
