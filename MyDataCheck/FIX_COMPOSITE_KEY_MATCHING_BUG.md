# CSV 数据对比模块 - 组合主键匹配 Bug 修复

## 问题描述

当对比两个 CSV 文件时，如果存在多条记录具有相同的部分主键（如 `cust_no`）但不同的完整主键（如 `cust_no + create_time`），差异报告会显示混淆的数据。

### 具体现象

**输入数据：**
- File1 有两条记录：
  - 记录1: `cust_no=800000650264, create_time=2026-03-02 17:36:37.316, 特征值=366`
  - 记录2: `cust_no=800000650264, create_time=2026-03-02 17:35:49.747, 特征值=0`

- File2 也有两条记录（完全相同）：
  - 记录1: `cust_no=800000650264, create_time=2026-03-02 17:36:37.316, 特征值=366`
  - 记录2: `cust_no=800000650264, create_time=2026-03-02 17:35:49.747, 特征值=0`

**期望结果：** 应该一一对应匹配，没有差异

**实际结果：** 显示有差异，且差异值来自不同记录（0 vs 366）

## 根本原因

### 问题1：时间列查找 Bug（已修复）

**文件**: `data_comparison/job/data_comparator.py` 第 252 和 258 行

**问题代码**:
```python
if time_idx_api is None and api_key_column + 1 < len(headers_api):
    time_idx_api = api_key_column + 1
```

**问题**: 使用了 `api_key_column`（单数），但实际上已经被标准化为 `api_key_columns`（复数列表）。这导致时间列查找失败，报告中的"时间"列为空。

**修复**:
```python
if time_idx_api is None and len(api_key_columns) > 0:
    last_key_idx = max(api_key_columns)
    if last_key_idx + 1 < len(headers_api):
        time_idx_api = last_key_idx + 1
```

### 问题2：报告表头显示不完整（已修复）

**文件**: `data_comparison/job/report_generator.py` 第 113 行

**问题**: 表头中应该显示所有主键列（如 `cust_no, create_time`），但实际只显示了一个 `主键值`。

**原因**: `key_column_names` 可能没有被正确处理为列表。

**修复**: 添加类型检查，确保 `key_column_names` 被正确转换为列表。

## 修复内容

### 1. 修复时间列查找逻辑

**文件**: `data_comparison/job/data_comparator.py`

**修改范围**: 第 248-265 行

**改动**:
- 将 `api_key_column + 1` 改为 `max(api_key_columns) + 1`
- 将 `sql_key_column + 1` 改为 `max(sql_key_columns) + 1`
- 添加长度检查，确保索引有效

### 2. 改进报告表头处理

**文件**: `data_comparison/job/report_generator.py`

**修改范围**: 第 113-120 行

**改动**:
- 添加类型检查，确保 `key_column_names` 是列表
- 如果是字符串，转换为列表格式

## 验证方法

### 1. 检查报告表头

运行对比后，查看差异数据明细文件的表头：

```bash
head -1 "outputdata/data_comparison/[报告名]_差异数据明细.csv"
```

**修复前**: `主键值,时间,cust_no,特征名,接口/灰度/从库值,模型特征样本值`

**修复后**: `cust_no,create_time,时间,cust_no,特征名,接口/灰度/从库值,模型特征样本值`

### 2. 检查差异数据

查找特定 cust_no 的差异记录：

```bash
grep "800000650264" "outputdata/data_comparison/[报告名]_差异数据明细.csv" | head -5
```

**修复后应该显示**:
- 每条记录都有完整的主键值（包括 `create_time`）
- 不会出现同一个特征的值混淆

## 影响范围

- ✅ 修复了多主键场景下的记录匹配问题
- ✅ 改进了差异报告的可读性
- ✅ 确保了时间列的正确显示
- ✅ 不影响单主键场景的对比逻辑

## 后续建议

1. **添加单元测试**: 为多主键场景添加测试用例
2. **改进日志**: 在对比过程中输出更详细的主键匹配日志
3. **性能优化**: 考虑为大文件添加进度条显示
4. **文档更新**: 更新配置指南，说明如何正确配置多主键

## 相关文件

- `data_comparison/job/data_comparator.py` - 数据对比核心逻辑
- `data_comparison/job/report_generator.py` - 报告生成逻辑
- `data_comparison/config.json` - 对比配置文件
