# CSV 文件压缩指南

## 问题分析

- **原始文件大小**: 1.32 GB
- **数据规模**: 15,986 行 × 20,912 列
- **主要原因**: CSV 文本格式存储浮点数和重复数据效率低

## 压缩方案对比

| 方案 | 格式 | 压缩率 | 读写速度 | 优点 | 缺点 |
|------|------|--------|---------|------|------|
| **推荐** | Parquet | 70-90% | 快 | 最佳压缩 + 快速读写 + 列式查询 | 需要 pyarrow |
| 备选1 | CSV.GZ | 60-80% | 慢 | 通用格式 + 可文本查看 | 读写慢 |
| 备选2 | Feather | 50-70% | 最快 | 快速读写 + 列式存储 | 压缩率一般 |

## 快速使用

### 方案1：Parquet（推荐）

```bash
python compress_merged_file.py
```

这会自动生成三个压缩版本，对比效果。

### 方案2：仅生成 Parquet

```python
import pandas as pd

df = pd.read_csv('sms_v3_all_merged_0302_v1.csv')
df.to_parquet('sms_v3_all_merged_0302_v1.parquet', compression='snappy')
```

### 方案3：仅生成 CSV.GZ

```python
import pandas as pd

df = pd.read_csv('sms_v3_all_merged_0302_v1.csv')
df.to_csv('sms_v3_all_merged_0302_v1.csv.gz', compression='gzip')
```

## 读取压缩文件

### 读取 Parquet
```python
df = pd.read_parquet('sms_v3_all_merged_0302_v1.parquet')
```

### 读取 CSV.GZ
```python
df = pd.read_csv('sms_v3_all_merged_0302_v1.csv.gz')
```

### 读取 Feather
```python
df = pd.read_feather('sms_v3_all_merged_0302_v1.feather')
```

## 数据完整性保证

✓ **所有方案都保留 100% 的数据**
- 无数据丢失
- 无精度损失
- 无列/行删除

## 性能预期

假设原始文件 1.32 GB：

| 操作 | Parquet | CSV.GZ | Feather |
|------|---------|--------|---------|
| 压缩后大小 | ~150-400 MB | ~250-500 MB | ~400-650 MB |
| 读取时间 | 2-5 秒 | 10-20 秒 | 1-2 秒 |
| 写入时间 | 5-10 秒 | 20-40 秒 | 2-3 秒 |

## 建议

1. **首选 Parquet**：最佳的压缩率和读写性能平衡
2. **需要通用格式**：选择 CSV.GZ
3. **需要最快速度**：选择 Feather

## 注意事项

- 压缩过程会占用内存（需要 2-3 倍的原始文件大小）
- 建议在内存充足的机器上执行
- 压缩后可以删除原始 CSV 文件以节省空间
