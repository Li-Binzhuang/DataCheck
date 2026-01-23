# 第二板块衍生特征 CSV 输出说明

## 更新内容

已在 `第二板块衍生.ipynb` 中添加了将 `features` 全量输出到 CSV 文件的功能。

## 使用方法

### 1. 运行 Notebook

直接运行 `第二板块衍生.ipynb`，执行到第 5 个代码单元格（显示 features 的那个格子）。

### 2. 输出控制

在代码中有一个开关变量：

```python
WRITE_FEATURES_FULL_CSV = True  # 设置为 True 输出完整特征 CSV，False 则跳过
```

- **True**（默认）：自动输出 CSV 文件
- **False**：跳过 CSV 输出

### 3. 输出位置

CSV 文件会输出到：

```
CDC/outputs/block2_features_full_<timestamp>.csv
```

其中 `<timestamp>` 是生成文件时的时间戳，格式为 `YYYYMMDD_HHMMSS`。

例如：
- `block2_features_full_20260123_163045.csv`

### 4. 输出内容

CSV 文件包含：
- **所有行**：features 的全部数据（12546 行）
- **所有列**：包括 `apply_id`、`request_time` 和所有第二板块的衍生特征（cdc_creditos_*_v2）
- **编码格式**：UTF-8 with BOM（utf-8-sig），可直接用 Excel 打开，中文不乱码

### 5. 输出信息

运行后会在控制台显示：

```
[WRITE] 第二板块特征全量数据已输出到: /path/to/CDC/outputs/block2_features_full_20260123_163045.csv
[INFO] 输出数据形状: (12546, 16647)
[INFO] 包含 12546 行数据，16647 列（含 apply_id 和 request_time）
[INFO] 特征列数（不含 apply_id 和 request_time）: 16645
```

## 数据说明

根据你提供的截图，输出的 CSV 包含：

- **行数**：12546 行（对应 12546 个 apply_id）
- **列数**：16647 列
  - 1 列 `apply_id`
  - 1 列 `request_time`（截止日期）
  - 16645 列特征（第二板块 creditos 信贷特征）
- **特征命名**：所有特征列名格式为 `cdc_creditos_*_v2`

示例列名：
- `cdc_creditos_30d_shop_cnt_v2`：近30天商店类信贷账户数
- `cdc_creditos_30d_shop_ratio_v2`：近30天商店类信贷账户占比
- `cdc_creditos_60d_total_balance_v2`：近60天总余额
- 等等...

## 特征窗口说明

第二板块特征按时间窗口计算，默认窗口为：
- 30天
- 60天
- 90天
- 120天
- 180天
- 360天
- 720天

每个窗口会计算多个维度的特征：
- 账户数量统计（按类型、状态等）
- 余额统计（当前余额、逾期余额等）
- 额度统计（信用额度、使用率等）
- 逾期统计（逾期账户数、逾期金额等）
- 还款统计（还款期数、还款频率等）
- 时间统计（账户年龄、距最后事件天数等）
- 等等

## 特征维度说明

第二板块（creditos 信贷板块）是特征最多的板块，包含：

### 1. 账户类型维度
- shop（商店）
- bank（银行）
- finance（金融）
- card（信用卡）
- loan（贷款）
- 等等

### 2. 账户状态维度
- open（开放）
- closed（关闭）
- active（活跃）
- overdue（逾期）
- 等等

### 3. 责任类型维度
- individual（个人）
- joint（联名）
- guarantee（担保）
- 等等

### 4. 统计指标维度
- cnt（计数）
- ratio（占比）
- sum（总和）
- mean（均值）
- max（最大值）
- min（最小值）
- std（标准差）
- 等等

## 与其他输出的区别

| 输出类型 | 文件名 | 内容 | 用途 |
|---------|--------|------|------|
| **全量特征数据** | `block2_features_full_<timestamp>.csv` | 完整的 features（所有行和列） | 用于模型训练、特征分析 |
| 明细数据 | `creditos_flat.csv` | creditos 原始明细数据 | 数据核查 |
| 特征数据（旧） | `creditos_features.csv` | 带前后缀的特征（WRITE_OUTPUTS控制） | 兼容旧流程 |
| 特征字典 | `feature_dict_block2.csv` | 特征名、窗口、描述等 | 特征文档 |
| 评估报告 | `block2_eval_report.xlsx` | IV、PSI、分箱、分周统计等 | 特征质量评估 |

## 注意事项

1. **数据结构**：
   - features 是一个 DataFrame，index 是 apply_id
   - 输出时会将 index 重置为列（reset_index()）
   - 因此 CSV 中第一列是 apply_id

2. **文件大小**：
   - 12546 行 × 16647 列的数据量很大
   - CSV 文件大小约 **200-500 MB**
   - 建议使用专业工具（如 Python pandas）读取，Excel 可能无法完全打开

3. **时间戳**：每次运行都会生成新文件，不会覆盖旧文件

4. **路径**：确保有 `CDC/outputs/` 目录的写入权限（脚本会自动创建）

5. **编码**：使用 UTF-8 with BOM，Excel 可直接打开（但可能因列数过多而截断）

6. **数值精度**：所有特征值已保留2位小数

## 与 WRITE_OUTPUTS 的区别

notebook 中有两个输出开关：

| 开关 | 文件名 | 说明 |
|------|--------|------|
| `WRITE_OUTPUTS` | `creditos_features.csv` | 旧的输出方式，需要手动确认 |
| `WRITE_FEATURES_FULL_CSV` | `block2_features_full_<timestamp>.csv` | 新增的全量输出，默认开启 |

两者可以同时使用，互不影响。

## 快速验证

运行后可以用以下命令验证：

```bash
# 查看文件是否生成
ls -lh CDC/outputs/block2_features_full_*.csv

# 查看文件大小
du -h CDC/outputs/block2_features_full_*.csv

# 查看文件行数（应该是 12547，包含表头）
wc -l CDC/outputs/block2_features_full_*.csv

# 查看前几行（只显示前几列）
head -5 CDC/outputs/block2_features_full_*.csv | cut -d',' -f1-10

# 查看列数
head -1 CDC/outputs/block2_features_full_*.csv | awk -F',' '{print NF}'
```

## 使用 Python 读取大文件

由于文件较大，建议使用 Python 读取：

```python
import pandas as pd

# 读取 CSV
df = pd.read_csv('CDC/outputs/block2_features_full_20260123_163045.csv')

print(f"数据形状: {df.shape}")
print(f"列名: {df.columns.tolist()[:10]}...")  # 显示前10列
print(df.head())

# 如果内存不足，可以分块读取
chunks = []
for chunk in pd.read_csv('CDC/outputs/block2_features_full_20260123_163045.csv', chunksize=1000):
    # 处理每个 chunk
    chunks.append(chunk)
df = pd.concat(chunks, ignore_index=True)
```

## 如果需要修改

如果需要修改输出行为，可以编辑 `第二板块衍生.ipynb` 第 5 个代码单元格中的相关代码：

### 示例1：只输出特定窗口的特征

```python
# 只输出 30天 和 60天 窗口的特征
selected_cols = ['apply_id', 'request_time']
selected_cols += [c for c in output_df.columns if '30d' in c or '60d' in c]
output_df_filtered = output_df[selected_cols]
output_df_filtered.to_csv(csv_path, index=False, encoding="utf-8-sig")
```

### 示例2：只输出高IV特征

```python
# 假设你已经计算了 IV，只输出 IV > 0.1 的特征
high_iv_features = ['apply_id', 'request_time']  # 基础列
high_iv_features += [f for f in iv_dict.keys() if iv_dict[f] > 0.1]
output_df_filtered = output_df[high_iv_features]
output_df_filtered.to_csv(csv_path, index=False, encoding="utf-8-sig")
```

### 示例3：分批输出（避免单文件过大）

```python
# 按窗口分别输出
for window in [30, 60, 90, 120, 180, 360, 720]:
    window_cols = ['apply_id', 'request_time']
    window_cols += [c for c in output_df.columns if f'{window}d' in c]
    
    csv_filename = f\"block2_features_{window}d_{timestamp}.csv\"
    csv_path = Path(\"outputs\") / csv_filename
    
    output_df[window_cols].to_csv(csv_path, index=False, encoding="utf-8-sig")
    print(f\"[WRITE] {window}天窗口特征已输出: {csv_path.resolve()}\")
```

## 性能优化建议

1. **内存优化**：如果内存不足，可以在输出前删除不需要的列
2. **压缩输出**：可以输出为 `.csv.gz` 格式节省空间
3. **Parquet 格式**：对于大数据，建议使用 Parquet 格式（更快、更小）

```python
# 输出为 Parquet 格式（推荐）
parquet_path = csv_path.with_suffix('.parquet')
output_df.to_parquet(parquet_path, index=False, compression='snappy')
```
