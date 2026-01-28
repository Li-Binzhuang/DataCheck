# CDC板块衍生脚本 - 前200条记录输出功能说明

## 功能概述
所有四个板块衍生脚本都支持输出前200条记录的样本文件，用于快速查看和测试。

## 控制开关
在每个脚本的开头配置区域：

```python
WRITE_SAMPLE_200 = True  # 是否输出前200条记录的样本文件
```

## 输出文件

### 第一板块（consultas）
- 文件名：`cdc1_features_consultas_sample200.csv`
- 位置：`CDC/outputs/`

### 第二板块（creditos）
- 文件名：`cdc2_features_creditos_sample200.csv`
- 位置：`CDC/outputs/`

### 第三板块（clavePrevencion）
- 文件名：`cdc3_features_clave_prevencion_sample200.csv`
- 位置：`CDC/outputs/`

### BOSS板块
- 文件名：`cdcboss_features_sample200.csv`
- 位置：`CDC/outputs/`

## 数据处理

### 统一处理流程
所有样本文件都经过与全量数据相同的处理：

1. **空值填充**：空值填充为 -999
2. **浮点数精度**：保留6位小数
3. **列顺序**：apply_id 和 request_time 在最前面
4. **编码格式**：UTF-8-BOM（utf-8-sig）

### 代码示例
```python
if WRITE_SAMPLE_200:
    _features_sample200 = _features_to_write.head(200)  # 取前200条记录
    _features_sample200.to_csv(
        features_sample200_path,
        index=False,
        encoding="utf-8-sig",
    )
```

## 使用场景

### 1. 快速验证
运行脚本后，先查看sample200文件，快速验证：
- 特征计算是否正确
- 空值填充是否为-999
- 浮点数精度是否为6位
- 列名是否正确

### 2. 测试调试
在开发和调试时：
- 减少数据加载时间
- 快速定位问题
- 方便人工检查

### 3. 文档示例
在文档和报告中：
- 提供数据样例
- 展示特征格式
- 说明数据结构

## 与全量数据的关系

### 数据一致性
- ✅ 样本数据是全量数据的前200条
- ✅ 处理逻辑完全相同
- ✅ 数据格式完全一致

### 文件大小对比
| 板块 | 全量文件 | 样本文件 | 比例 |
|------|----------|----------|------|
| 第一板块 | ~数MB | ~数百KB | ~1% |
| 第二板块 | ~数MB | ~数百KB | ~1% |
| 第三板块 | ~数MB | ~数百KB | ~1% |
| BOSS板块 | ~数MB | ~数百KB | ~1% |

## 配置建议

### 开发阶段
```python
WRITE_SAMPLE_200 = True   # 启用样本输出
WRITE_FEATURES_CSV = True  # 同时输出全量数据
```

### 生产环境
```python
WRITE_SAMPLE_200 = False  # 可选择关闭以节省时间
WRITE_FEATURES_CSV = True  # 保持全量数据输出
```

### 快速测试
```python
WRITE_SAMPLE_200 = True   # 只看样本
WRITE_FEATURES_CSV = False # 暂时不输出全量
```

## 验证方法

### 1. 检查文件是否生成
```bash
ls -lh CDC/outputs/*sample200.csv
```

### 2. 查看记录数
```bash
wc -l CDC/outputs/*sample200.csv
# 应该显示 201 行（包含表头）
```

### 3. 检查数据格式
```python
import pandas as pd

# 读取样本文件
df = pd.read_csv('CDC/outputs/cdcboss_features_sample200.csv')

# 检查形状
print(f"形状: {df.shape}")  # 应该是 (200, N列)

# 检查列名
print(f"前几列: {df.columns[:5].tolist()}")  # 应该包含 apply_id

# 检查浮点数精度
print(df.iloc[0, 2:5])  # 查看几个数值列
```

## 注意事项

1. **数据顺序**：样本是按原始数据顺序的前200条，不是随机抽样
2. **代表性**：如果数据有时间顺序或其他排序，前200条可能不具代表性
3. **文件覆盖**：每次运行会覆盖之前的样本文件
4. **编码格式**：使用UTF-8-BOM，Excel可以直接打开

## 相关文档
- 空值填充：`CDC/zlf_update_summary.md`
- 浮点数精度：`CDC/浮点数处理功能说明.md`
- 完整使用指南：`CDC/README_zlf_update.md`
