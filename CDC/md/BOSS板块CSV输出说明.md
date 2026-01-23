# BOSS板块衍生特征 CSV 输出说明

## 更新内容

已在 `BOSS板块衍生.ipynb` 中添加了将 `features_df` 全量输出到 CSV 文件的功能。

## 使用方法

### 1. 运行 Notebook

直接运行 `BOSS板块衍生.ipynb`，执行到第 4 个代码单元格（显示 features_df 的那个格子）。

### 2. 输出控制

在代码中有一个开关变量：

```python
WRITE_FEATURES_CSV = True  # 设置为 True 输出 CSV，False 则跳过
```

- **True**（默认）：自动输出 CSV 文件
- **False**：跳过 CSV 输出

### 3. 输出位置

CSV 文件会输出到：

```
CDC/outputs/boss_features_full_<timestamp>.csv
```

其中 `<timestamp>` 是生成文件时的时间戳，格式为 `YYYYMMDD_HHMMSS`。

例如：
- `boss_features_full_20260123_143025.csv`

### 4. 输出内容

CSV 文件包含：
- **所有行**：features_df 的全部数据（不是只有 head(5)）
- **所有列**：包括 `apply_id` 和所有 BOSS 板块的衍生特征（cdc_boss_*_607）
- **编码格式**：UTF-8 with BOM（utf-8-sig），可直接用 Excel 打开，中文不乱码

### 5. 输出信息

运行后会在控制台显示：

```
[WRITE] BOSS 特征全量数据已输出到: /path/to/CDC/outputs/boss_features_full_20260123_143025.csv
[INFO] 输出数据形状: (12546, 149)
[INFO] 包含 12546 行数据，149 列特征（含 apply_id）
```

## 数据说明

根据你提供的截图，输出的 CSV 包含：

- **行数**：12546 行（对应 12546 个 apply_id）
- **列数**：149 列（1 列 apply_id + 148 列特征）
- **特征命名**：所有特征列名格式为 `cdc_boss_*_607`

示例列名：
- `cdc_boss_total_accounts_607`：总账户数
- `cdc_boss_closed_accounts_cnt_607`：已关闭账户数
- `cdc_boss_open_accounts_cnt_607`：开放账户数
- 等等...

## 与其他输出的区别

| 输出类型 | 文件名 | 内容 | 用途 |
|---------|--------|------|------|
| **全量特征数据** | `boss_features_full_<timestamp>.csv` | 完整的 features_df（所有行和列） | 用于模型训练、特征分析 |
| 特征字典 | `feature_dict_boss_3col.csv` | 特征名、中文描述、逻辑描述 | 特征文档 |
| 评估报告 | `boss_eval_report.xlsx` | IV、PSI、分箱、分周统计等 | 特征质量评估 |
| 质量检测 | `boss_feature_quality.xlsx` | 每个特征的质量指标 | 特征筛选 |

## 注意事项

1. **文件大小**：12546 行 × 149 列的数据，CSV 文件大小约 5-10 MB
2. **时间戳**：每次运行都会生成新文件，不会覆盖旧文件
3. **路径**：确保有 `CDC/outputs/` 目录的写入权限（脚本会自动创建）
4. **编码**：使用 UTF-8 with BOM，Excel 可直接打开

## 快速验证

运行后可以用以下命令验证：

```bash
# 查看文件是否生成
ls -lh CDC/outputs/boss_features_full_*.csv

# 查看文件行数（应该是 12547，包含表头）
wc -l CDC/outputs/boss_features_full_*.csv

# 查看前几行
head -5 CDC/outputs/boss_features_full_*.csv
```

## 如果需要修改

如果需要修改输出行为，可以编辑 `BOSS板块衍生.ipynb` 第 4 个代码单元格中的相关代码：

- 修改文件名格式
- 修改输出路径
- 添加数据过滤
- 调整列的顺序
- 等等...
