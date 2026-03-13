# CDC 项目 CSV 输出配置总结

## 当前配置状态

### ✅ 已完成的修改

| 板块 | 输出开关 | 状态 | 输出文件 |
|------|---------|------|---------|
| **第一板块** | `WRITE_OUTPUTS = True` | ✅ 已开启 | `outputs/consultas_features.csv` |
| **第二板块** | `WRITE_OUTPUTS = True` | ✅ 已开启 | `outputs/features_creditos.csv` |
| **第三板块** | `WRITE_OUTPUTS = True` | ✅ 已开启 | `outputs/flat_features.csv` |
| **BOSS板块** | `WRITE_FEATURES_CSV = True` | ✅ 已开启 | `outputs/boss_features_full_<timestamp>.csv` |

---

## 输出文件说明

### 第一板块（consultas 查询板块）

**输出文件**：`CDC/outputs/consultas_features.csv`

**内容**：
- 行数：根据数据源而定（示例：3 行）
- 列数：约 988 列
  - 1 列 `apply_id`
  - 1 列 `request_time`
  - 986 列特征（cdc_consultas_*_v2）

**特征类型**：
- 近 30/60/90/120/180/360/720 天的查询统计
- 按查询类型分组（shop、bank、finance等）
- 查询次数、占比、间隔等

**文件特点**：
- ✅ 固定文件名
- ⚠️ 每次运行会覆盖
- ✅ UTF-8 with BOM 编码
- ✅ 数值保留2位小数

---

### 第二板块（creditos 信贷板块）

**输出文件**：`CDC/outputs/features_creditos.csv`

**内容**：
- 行数：12546 行
- 列数：约 16647 列
  - 1 列 `apply_id`
  - 1 列 `request_time`
  - 16645 列特征（cdc_creditos_*_v2）

**特征类型**：
- 近 30/60/90/120/180/360/720 天的信贷统计
- 账户数量（按类型、状态、责任类型）
- 余额统计（当前、逾期、额度）
- 逾期统计（账户数、金额、等级）
- 还款统计（期数、频率）
- 时间统计（账户年龄、距事件天数）

**文件特点**：
- ✅ 固定文件名
- ⚠️ 每次运行会覆盖
- ✅ UTF-8 with BOM 编码
- ✅ 数值保留2位小数
- ⚠️ 文件较大（约 200-500 MB）

---

### 第三板块

**输出文件**：`CDC/outputs/flat_features.csv`

**内容**：
- 根据第三板块的特征定义
- 包含 apply_id、request_time 和衍生特征

**文件特点**：
- ✅ 固定文件名
- ⚠️ 每次运行会覆盖
- ✅ UTF-8 with BOM 编码
- ✅ 数值保留2位小数

---

### BOSS板块

**输出文件**：`CDC/outputs/boss_features_full_<timestamp>.csv`

**内容**：
- 行数：12546 行
- 列数：约 149 列
  - 1 列 `apply_id`
  - 148 列特征（cdc_boss_*_607）

**特征类型**：
- consultas（查询）相关特征
- creditos（信贷）相关特征
- empleos（工作）相关特征
- domicilios（住址）相关特征
- 综合统计特征

**文件特点**：
- ✅ 带时间戳文件名（不会覆盖）
- ✅ UTF-8 with BOM 编码
- ✅ 数值保留2位小数

---

## 使用方法

### 运行 Notebook 输出 CSV

只需要正常运行各个板块的 notebook，CSV 文件会自动生成：

```bash
# 在 Jupyter 或 VS Code 中运行
1. 打开 第一板块衍生.ipynb，运行所有 cell
   → 生成 outputs/consultas_features.csv

2. 打开 第二板块衍生.ipynb，运行所有 cell
   → 生成 outputs/features_creditos.csv

3. 打开 第三板块衍生.ipynb，运行所有 cell
   → 生成 outputs/flat_features.csv

4. 打开 BOSS板块衍生.ipynb，运行所有 cell
   → 生成 outputs/boss_features_full_20260123_163045.csv
```

### 查看输出文件

```bash
# 查看所有输出文件
ls -lh CDC/outputs/*.csv

# 查看文件行数
wc -l CDC/outputs/*.csv

# 查看文件大小
du -h CDC/outputs/*.csv
```

---

## 如果需要关闭输出

如果某次运行不想输出 CSV，可以修改开关：

### 第一、二、三板块

```python
WRITE_OUTPUTS = False  # 改为 False
```

### BOSS板块

```python
WRITE_FEATURES_CSV = False  # 改为 False
```

---

## 文件命名规则

| 板块 | 文件名规则 | 是否覆盖 |
|------|-----------|---------|
| 第一板块 | `consultas_features.csv`（固定） | ✅ 会覆盖 |
| 第二板块 | `features_creditos.csv`（固定） | ✅ 会覆盖 |
| 第三板块 | `flat_features.csv`（固定） | ✅ 会覆盖 |
| BOSS板块 | `boss_features_full_<timestamp>.csv`（带时间戳） | ❌ 不会覆盖 |

---

## 注意事项

### 1. 文件大小

- **第一板块**：约 5-10 MB
- **第二板块**：约 200-500 MB（最大）
- **第三板块**：根据特征数量而定
- **BOSS板块**：约 10-20 MB

### 2. Excel 兼容性

- ✅ 所有文件使用 UTF-8 with BOM 编码，Excel 可直接打开
- ⚠️ 第二板块列数超过 16000，Excel 可能无法完全显示（Excel 最多支持 16384 列）
- 💡 建议使用 Python pandas 或专业数据工具处理大文件

### 3. 内存使用

- 第二板块特征最多，运行时可能需要较大内存
- 如果内存不足，可以考虑分批处理或使用更大内存的机器

### 4. 运行时间

- 第一板块：较快（几分钟）
- 第二板块：较慢（可能需要 10-30 分钟）
- 第三板块：中等
- BOSS板块：中等

---

## 读取 CSV 文件示例

### 使用 Python pandas

```python
import pandas as pd

# 读取第一板块
df1 = pd.read_csv('CDC/outputs/consultas_features.csv')
print(f"第一板块: {df1.shape}")

# 读取第二板块（大文件）
df2 = pd.read_csv('CDC/outputs/features_creditos.csv')
print(f"第二板块: {df2.shape}")

# 读取第三板块
df3 = pd.read_csv('CDC/outputs/flat_features.csv')
print(f"第三板块: {df3.shape}")

# 读取 BOSS 板块（找最新的文件）
import glob
boss_files = glob.glob('CDC/outputs/boss_features_full_*.csv')
latest_boss = max(boss_files)  # 按文件名排序，最新的在最后
df_boss = pd.read_csv(latest_boss)
print(f"BOSS板块: {df_boss.shape}")
```

### 合并所有板块

```python
# 按 apply_id 合并所有板块
df_all = df1.merge(df2, on=['apply_id', 'request_time'], how='outer')
df_all = df_all.merge(df3, on=['apply_id', 'request_time'], how='outer')
df_all = df_all.merge(df_boss, on='apply_id', how='outer')

print(f"合并后: {df_all.shape}")
```

---

## 故障排查

### 问题1：文件未生成

**检查**：
- 确认 `WRITE_OUTPUTS` 或 `WRITE_FEATURES_CSV` 是否为 `True`
- 确认 notebook 是否运行到输出代码的 cell
- 检查 `CDC/outputs/` 目录是否有写入权限

### 问题2：文件为空或数据不完整

**检查**：
- 确认原始数据（pickle 或 CSV）是否正确加载
- 检查 console 输出是否有错误信息
- 确认 `features.shape` 是否正常

### 问题3：Excel 打开乱码

**检查**：
- 确认文件编码是 UTF-8 with BOM
- 尝试用 Excel 的"数据" → "从文本/CSV"导入
- 或使用 Python pandas 读取

### 问题4：内存不足

**解决方案**：
- 关闭其他程序释放内存
- 使用更大内存的机器
- 考虑分批处理数据
- 使用 Parquet 格式代替 CSV

---

## 更新日志

- **2026-01-23**：
  - ✅ 删除第一、二板块的新增输出代码
  - ✅ 打开第一、二、三板块的 `WRITE_OUTPUTS` 开关
  - ✅ 保持 BOSS 板块的带时间戳输出
  - ✅ 统一输出配置，简化使用流程
