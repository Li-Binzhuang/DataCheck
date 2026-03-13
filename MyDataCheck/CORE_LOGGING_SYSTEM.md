# 核心日志系统 - 使用指南

## 概述

为所有功能模块添加了统一的核心日志系统，支持：
- 性能分析
- 错误追踪
- 执行流程记录
- 日志对比分析

---

## 核心特性

### 1. 统一日志记录

```python
from common.core_logger import get_logger

# 获取日志记录器
logger = get_logger('data_comparison')

# 开始执行
logger.start_execution('任务名称', config)

# 记录事件
logger.log_event('CHECKPOINT', '关键步骤完成')

# 记录进度
logger.log_progress(current=100, total=1000, stage='处理数据')

# 记录性能指标
logger.log_performance('read_time', 2.5, 'seconds')

# 记录错误
logger.log_error('ERROR_TYPE', '错误信息', traceback_str)

# 结束执行
logger.end_execution('completed', summary)
```

### 2. 自动日志保留

- **保留策略：** 保留当前和上一次的执行日志
- **自动轮转：** 超过2个日志时自动删除最旧的
- **日志位置：** `logs/{module_name}/current_{timestamp}.json`

### 3. 日志对比分析

```python
# 获取对比报告
report = logger.get_comparison_report()

# 报告内容
{
    'current': {
        'task_name': '...',
        'duration': 10.5,
        'status': 'completed',
        'errors_count': 0
    },
    'previous': {
        'task_name': '...',
        'duration': 15.2,
        'status': 'completed',
        'errors_count': 1
    },
    'comparison': {
        'duration_improvement': 30.9,  # 性能提升百分比
        'status_same': True,
        'errors_reduced': True
    }
}
```

---

## 日志文件结构

### 日志文件位置

```
logs/
├── data_comparison/
│   ├── current_20260311_150000.json  # 当前执行
│   └── current_20260311_140000.json  # 上一次执行
├── merge_csv/
│   ├── current_20260311_150000.json
│   └── current_20260311_140000.json
└── ...
```

### 日志文件内容

```json
{
  "module": "data_comparison",
  "task_name": "数据对比",
  "start_time": "2026-03-11T15:00:00.000000",
  "end_time": "2026-03-11T15:10:00.000000",
  "duration": 600.0,
  "status": "completed",
  "config": {
    "sql_file": "file1.csv",
    "api_file": "file2.csv"
  },
  "events": [
    {
      "timestamp": "2026-03-11T15:00:00.000000",
      "type": "START",
      "message": "开始执行任务: 数据对比",
      "elapsed_time": 0.0
    },
    {
      "timestamp": "2026-03-11T15:00:02.000000",
      "type": "CHECKPOINT",
      "message": "文件读取完成",
      "elapsed_time": 2.0,
      "data": {
        "sql_rows": 15986,
        "sql_cols": 20900,
        "api_rows": 15986,
        "api_cols": 20906,
        "read_time": 2.0
      }
    }
  ],
  "performance": {
    "file_read_time": {
      "value": 2.0,
      "unit": "seconds",
      "timestamp": "2026-03-11T15:00:02.000000"
    },
    "total_duration": {
      "value": 600.0,
      "unit": "seconds",
      "timestamp": "2026-03-11T15:10:00.000000"
    }
  },
  "errors": [],
  "progress": [
    {
      "timestamp": "2026-03-11T15:00:10.000000",
      "current": 1599,
      "total": 15986,
      "percentage": 10.0,
      "stage": "对比数据",
      "elapsed_time": 10.0
    }
  ],
  "summary": {
    "matched_count": 15986,
    "unmatched_count": 0,
    "differences_count": 1234,
    "match_ratio": 98.5,
    "total_duration": 600.0
  }
}
```

---

## 事件类型

| 事件类型 | 说明 | 示例 |
|---------|------|------|
| START | 任务开始 | 开始执行任务 |
| CHECKPOINT | 关键步骤 | 文件读取完成、索引构建完成 |
| PROGRESS | 进度更新 | 处理进度 10% |
| PERFORMANCE | 性能指标 | 读取时间、对比时间 |
| ERROR | 错误信息 | 文件不存在、数据格式错误 |
| END | 任务结束 | 任务执行完成 |

---

## 集成指南

### 步骤1：导入日志模块

```python
from common.core_logger import get_logger

logger = get_logger('module_name')
```

### 步骤2：开始执行

```python
logger.start_execution('任务名称', {
    'param1': 'value1',
    'param2': 'value2'
})
```

### 步骤3：记录关键步骤

```python
# 记录事件
logger.log_event('CHECKPOINT', '步骤完成', {
    'detail': 'value'
})

# 记录进度
logger.log_progress(current=100, total=1000, stage='处理')

# 记录性能
logger.log_performance('metric_name', 10.5, 'unit')
```

### 步骤4：处理错误

```python
try:
    # 执行操作
    pass
except Exception as e:
    import traceback
    logger.log_error('ERROR_TYPE', str(e), traceback.format_exc())
    logger.end_execution('failed')
    raise
```

### 步骤5：结束执行

```python
logger.end_execution('completed', {
    'result_count': 1000,
    'success_rate': 99.5
})
```

---

## 查看日志

### 方式1：直接查看文件

```bash
# 查看最新的日志
cat logs/data_comparison/current_*.json | jq .

# 查看特定模块的日志
ls -ltr logs/data_comparison/
```

### 方式2：使用Python API

```python
from common.core_logger import get_logger

logger = get_logger('data_comparison')

# 获取最新的2个日志
logs = logger.get_latest_logs(2)

# 获取对比报告
report = logger.get_comparison_report()
print(report)
```

### 方式3：Web界面（待实现）

在Web界面添加日志查看功能，显示：
- 最新执行的日志
- 上一次执行的日志
- 性能对比
- 错误信息

---

## 性能分析示例

### 查看性能改进

```python
from common.core_logger import get_logger

logger = get_logger('data_comparison')
report = logger.get_comparison_report()

print(f"当前执行耗时: {report['current']['duration']}秒")
print(f"上一次执行耗时: {report['previous']['duration']}秒")
print(f"性能提升: {report['comparison']['duration_improvement']}%")
```

### 输出示例

```
当前执行耗时: 600.0秒
上一次执行耗时: 800.0秒
性能提升: 25.0%
```

---

## 已集成的模块

### ✅ 数据对比模块

- 文件：`data_comparison/job/data_comparator_optimized.py`
- 记录内容：
  - 文件读取时间
  - 索引构建时间
  - 对比进度
  - 性能指标
  - 执行摘要

### 🔄 待集成的模块

- 合并CSV模块
- 接口对比模块
- 在线对比模块
- 批量运行模块

---

## 最佳实践

### 1. 记录关键步骤

```python
# ✅ 好
logger.log_event('CHECKPOINT', '文件读取完成', {
    'rows': 15986,
    'cols': 20900,
    'time': 2.0
})

# ❌ 不好
logger.log_event('CHECKPOINT', '完成')
```

### 2. 记录性能指标

```python
# ✅ 好
logger.log_performance('read_time', 2.0, 'seconds')
logger.log_performance('matched_records', 15986, 'rows')

# ❌ 不好
logger.log_event('INFO', '读取时间: 2.0秒')
```

### 3. 记录进度

```python
# ✅ 好
for i in range(total):
    logger.log_progress(i, total, '处理数据')

# ❌ 不好
for i in range(total):
    logger.log_event('PROGRESS', f'{i}/{total}')
```

### 4. 处理错误

```python
# ✅ 好
try:
    # 执行操作
    pass
except Exception as e:
    import traceback
    logger.log_error('FILE_ERROR', str(e), traceback.format_exc())
    logger.end_execution('failed')
    raise

# ❌ 不好
try:
    # 执行操作
    pass
except Exception as e:
    print(f"错误: {e}")
```

---

## 故障排查

### 问题1：日志文件不存在

**症状：** 执行完成后没有生成日志文件

**排查：**
```bash
# 检查日志目录是否存在
ls -la logs/data_comparison/

# 检查权限
ls -la logs/
```

**解决：** 确保 `logs` 目录存在且有写权限

### 问题2：日志内容为空

**症状：** 日志文件存在但内容为空

**排查：**
```python
# 检查日志记录器是否正确初始化
logger = get_logger('data_comparison')
print(logger.current_log_data)
```

**解决：** 确保调用了 `start_execution()` 和 `end_execution()`

### 问题3：日志文件过多

**症状：** 日志文件不断增加

**排查：**
```bash
# 查看日志文件数量
ls logs/data_comparison/ | wc -l
```

**解决：** 日志轮转应该自动删除旧文件，检查是否有权限问题

---

## 总结

| 特性 | 说明 |
|------|------|
| **统一记录** | 所有模块使用相同的日志API |
| **自动保留** | 保留当前和上一次的执行日志 |
| **性能分析** | 自动对比性能指标 |
| **错误追踪** | 完整的错误堆栈记录 |
| **易于集成** | 简单的API，易于添加到现有代码 |

---

**日志系统版本：** 1.0
**创建日期：** 2026-03-11
**状态：** ✅ 已实现

