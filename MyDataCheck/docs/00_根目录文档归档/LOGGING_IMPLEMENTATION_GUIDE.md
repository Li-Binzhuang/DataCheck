# 核心日志系统实施指南

## 🎯 目标

为每个功能模块添加核心日志，执行完成后保留本次和上一次执行的日志，方便Kiro分析问题。

---

## ✅ 已完成

### 1. 核心日志模块

**文件：** `common/core_logger.py`

```python
from common.core_logger import get_logger

logger = get_logger('module_name')
logger.start_execution('任务名称', config)
logger.log_event('CHECKPOINT', '步骤完成')
logger.end_execution('completed', summary)
```

**特性：**
- ✅ 统一的日志API
- ✅ 自动日志保留（当前 + 上一次）
- ✅ 性能指标记录
- ✅ 错误追踪
- ✅ 日志对比分析

### 2. 完整文档

**文件：** `CORE_LOGGING_SYSTEM.md`

包含：
- 核心特性说明
- 日志文件结构
- 集成指南
- 最佳实践
- 故障排查

---

## 🚀 快速开始

### 步骤1：导入日志模块

```python
from common.core_logger import get_logger

logger = get_logger('data_comparison')
```

### 步骤2：开始执行

```python
logger.start_execution('数据对比', {
    'file1': 'file1.csv',
    'file2': 'file2.csv'
})
```

### 步骤3：记录关键步骤

```python
# 记录事件
logger.log_event('CHECKPOINT', '文件读取完成', {
    'rows': 15986,
    'cols': 20900
})

# 记录进度
logger.log_progress(current=100, total=1000, stage='处理数据')

# 记录性能
logger.log_performance('read_time', 2.5, 'seconds')
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
    'matched_count': 15986,
    'differences_count': 1234,
    'match_ratio': 98.5
})
```

---

## 📊 日志文件位置

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

---

## 🔍 查看日志

### 方式1：命令行

```bash
# 查看最新的日志
ls -ltr logs/data_comparison/

# 查看日志内容
cat logs/data_comparison/current_*.json | jq .

# 查看特定字段
cat logs/data_comparison/current_*.json | jq '.summary'
```

### 方式2：Python API

```python
from common.core_logger import get_logger

logger = get_logger('data_comparison')

# 获取最新的2个日志
logs = logger.get_latest_logs(2)

# 获取对比报告
report = logger.get_comparison_report()
print(f"性能提升: {report['comparison']['duration_improvement']}%")
```

---

## 📈 性能对比示例

### 查看性能改进

```python
from common.core_logger import get_logger

logger = get_logger('data_comparison')
report = logger.get_comparison_report()

print("=== 性能对比 ===")
print(f"当前执行耗时: {report['current']['duration']}秒")
print(f"上一次执行耗时: {report['previous']['duration']}秒")
print(f"性能提升: {report['comparison']['duration_improvement']}%")
print(f"错误减少: {report['comparison']['errors_reduced']}")
```

### 输出示例

```
=== 性能对比 ===
当前执行耗时: 600.0秒
上一次执行耗时: 800.0秒
性能提升: 25.0%
错误减少: True
```

---

## 🔧 集成到现有模块

### 数据对比模块

```python
# 在 data_comparison/job/data_comparator_optimized.py 中

from common.core_logger import get_logger

def compare_two_files(...):
    logger = get_logger('data_comparison')
    logger.start_execution('数据对比', config)
    
    try:
        # 记录关键步骤
        logger.log_event('CHECKPOINT', '文件读取完成')
        
        # 记录进度
        logger.log_progress(current, total, '对比数据')
        
        # 记录性能
        logger.log_performance('total_duration', duration, 'seconds')
        
        # 结束执行
        logger.end_execution('completed', summary)
        
    except Exception as e:
        import traceback
        logger.log_error('ERROR', str(e), traceback.format_exc())
        logger.end_execution('failed')
        raise
```

### 其他模块

按照相同的方式集成到：
- 合并CSV模块
- 接口对比模块
- 在线对比模块
- 批量运行模块

---

## 📋 日志内容示例

### 完整日志

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
      "unit": "seconds"
    },
    "total_duration": {
      "value": 600.0,
      "unit": "seconds"
    }
  },
  "errors": [],
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

## 🎯 使用场景

### 场景1：性能分析

```python
# 对比两次执行的性能
report = logger.get_comparison_report()

if report['comparison']['duration_improvement'] > 0:
    print(f"✅ 性能提升 {report['comparison']['duration_improvement']}%")
else:
    print(f"⚠️ 性能下降 {abs(report['comparison']['duration_improvement'])}%")
```

### 场景2：错误追踪

```python
# 查看最新的错误
logs = logger.get_latest_logs(1)
if logs[0]['errors']:
    for error in logs[0]['errors']:
        print(f"错误: {error['type']}")
        print(f"信息: {error['message']}")
        print(f"堆栈: {error['traceback']}")
```

### 场景3：执行流程分析

```python
# 查看执行流程
logs = logger.get_latest_logs(1)
for event in logs[0]['events']:
    print(f"[{event['type']}] {event['message']} ({event['elapsed_time']}s)")
```

---

## 🔄 日志轮转策略

### 自动保留

- **当前执行：** `current_20260311_150000.json`
- **上一次执行：** `current_20260311_140000.json`
- **更旧的日志：** 自动删除

### 手动查看

```bash
# 查看所有日志
ls -la logs/data_comparison/

# 查看最新的2个日志
ls -ltr logs/data_comparison/ | tail -2

# 删除所有日志（谨慎操作）
rm logs/data_comparison/current_*.json
```

---

## 📚 最佳实践

### ✅ 好的做法

```python
# 记录详细的信息
logger.log_event('CHECKPOINT', '文件读取完成', {
    'rows': 15986,
    'cols': 20900,
    'time': 2.0
})

# 记录性能指标
logger.log_performance('read_time', 2.0, 'seconds')

# 记录进度
logger.log_progress(100, 1000, '处理数据')

# 处理错误
try:
    # 操作
except Exception as e:
    import traceback
    logger.log_error('ERROR_TYPE', str(e), traceback.format_exc())
```

### ❌ 不好的做法

```python
# 记录信息不详细
logger.log_event('CHECKPOINT', '完成')

# 不记录性能指标
logger.log_event('INFO', '读取时间: 2.0秒')

# 不记录进度
logger.log_event('PROGRESS', '100/1000')

# 不处理错误
try:
    # 操作
except Exception as e:
    print(f"错误: {e}")
```

---

## 🚨 故障排查

### 问题1：日志文件不存在

```bash
# 检查日志目录
ls -la logs/

# 创建日志目录
mkdir -p logs/data_comparison
```

### 问题2：日志内容为空

```python
# 检查是否调用了 start_execution 和 end_execution
logger.start_execution('任务', config)
# ... 执行操作 ...
logger.end_execution('completed', summary)
```

### 问题3：日志文件过多

```bash
# 检查日志文件数量
ls logs/data_comparison/ | wc -l

# 手动清理旧日志
rm logs/data_comparison/current_*.json
```

---

## 📞 支持

如有问题，请查看：
- `CORE_LOGGING_SYSTEM.md` - 完整文档
- `common/core_logger.py` - 源代码
- `logs/` - 日志文件

---

**系统版本：** 1.0
**创建日期：** 2026-03-11
**状态：** ✅ 已实现

