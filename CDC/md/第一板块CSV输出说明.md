# 第一板块衍生特征 CSV 输出说明

## 更新内容

已在 `第一板块衍生.ipynb` 中添加了将 `features` 全量输出到 CSV 文件的功能。

## 使用方法

### 1. 运行 Notebook

直接运行 `第一板块衍生.ipynb`，执行到第 5 个代码单元格（显示 features.head(3) 的那个格子）。

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
CDC/outputs/block1_features_full_<timestamp>.csv
```

其中 `<timestamp>` 是生成文件时的时间戳，格式为 `YYYYMMDD_HHMMSS`。

例如：
- `block1_features_full_20260123_153045.csv`

### 4. 输出内容

CSV 文件包含：
- **所有行**：features 的全部数据（不是只有 head(3)）
- **所有列**：包括 `apply_id`、`request_time` 和所有第一板块的衍生特征（cdc_consultas_*_v2）
- **编码格式**：UTF-8 with BOM（utf-8-sig），可直接用 Excel 打开，中文不乱码

### 5. 输出信息

运行后会在控制台显示：

```
[WRITE] 第一板块特征全量数据已输出到: /path/to/CDC/outputs/block1_features_full_20260123_153045.csv
[INFO] 输出数据形状: (3, 988)
[INFO] 包含 3 行数据，988 列（含 apply_id 和 request_time）
[INFO] 特征列数（不含 apply_id 和 request_time）: 986
```

## 数据说明

根据你提供的截图，输出的 CSV 包含：

- **行数**：3 行（对应 3 个 apply_id）
  - 注意：这是示例数据，实际运行时会根据你的数据源有更多行
- **列数**：988 列
  - 1 列 `apply_id`
  - 1 列 `request_time`（截止日期）
  - 986 列特征（第一板块 consultas 查询特征）
- **特征命名**：所有特征列名格式为 `cdc_consultas_*_v2`

示例列名：
- `cdc_consultas_30d_total_cnt_v2`：近30天总查询次数
- `cdc_consultas_30d_shop_cnt_v2`：近30天商店类查询次数
- `cdc_consultas_60d_total_cnt_v2`：近60天总查询次数
- 等等...

## 特征窗口说明

第一板块特征按时间窗口计算，默认窗口为：
- 30天
- 60天
- 90天
- 120天
- 180天
- 360天
- 720天

每个窗口会计算多个维度的特征：
- 总查询次数
- 各类型查询次数（shop、bank、finance等）
- 查询占比
- 查询间隔统计
- 等等

## 与其他输出的区别

| 输出类型 | 文件名 | 内容 | 用途 |
|---------|--------|------|------|
| **全量特征数据** | `block1_features_full_<timestamp>.csv` | 完整的 features（所有行和列） | 用于模型训练、特征分析 |
| 明细数据 | `consultas_flat.csv` | consultas 原始明细数据 | 数据核查 |
| 特征数据（旧） | `consultas_features.csv` | 带前后缀的特征（WRITE_OUTPUTS控制） | 兼容旧流程 |
| 特征字典 | `feature_dict_block1.csv` | 特征名、窗口、描述等 | 特征文档 |
| 评估报告 | `block1_eval_report.xlsx` | IV、PSI、分箱、分周统计等 | 特征质量评估 |

## 注意事项

1. **数据结构**：
   - features 是一个 DataFrame，index 是 apply_id
   - 输出时会将 index 重置为列（reset_index()）
   - 因此 CSV 中第一列是 apply_id

2. **时间戳**：每次运行都会生成新文件，不会覆盖旧文件

3. **路径**：确保有 `CDC/outputs/` 目录的写入权限（脚本会自动创建）

4. **编码**：使用 UTF-8 with BOM，Excel 可直接打开

5. **数值精度**：所有特征值已保留2位小数

## 与 WRITE_OUTPUTS 的区别

notebook 中有两个输出开关：

| 开关 | 文件名 | 说明 |
|------|--------|------|
| `WRITE_OUTPUTS` | `consultas_features.csv` | 旧的输出方式，需要手动确认 |
| `WRITE_FEATURES_FULL_CSV` | `block1_features_full_<timestamp>.csv` | 新增的全量输出，默认开启 |

两者可以同时使用，互不影响。

## 快速验证

运行后可以用以下命令验证：

```bash
# 查看文件是否生成
ls -lh CDC/outputs/block1_features_full_*.csv

# 查看文件行数（应该是数据行数+1表头）
wc -l CDC/outputs/block1_features_full_*.csv

# 查看前几行
head -5 CDC/outputs/block1_features_full_*.csv

# 查看列数
head -1 CDC/outputs/block1_features_full_*.csv | awk -F',' '{print NF}'
```

## 如果需要修改

如果需要修改输出行为，可以编辑 `第一板块衍生.ipynb` 第 5 个代码单元格中的相关代码：

- 修改文件名格式
- 修改输出路径
- 添加数据过滤
- 调整列的顺序
- 选择性输出某些列
- 等等...

## 示例：只输出特定窗口的特征

如果你只想输出某些窗口的特征，可以这样修改：

```python
# 只输出 30天 和 60天 窗口的特征
selected_cols = ['apply_id', 'request_time']
selected_cols += [c for c in output_df.columns if '30d' in c or '60d' in c]
output_df_filtered = output_df[selected_cols]
output_df_filtered.to_csv(csv_path, index=False, encoding="utf-8-sig")
```
