# 解析 response_body 平铺展示 Notebook 使用说明

## 📄 文件位置

`CDC/解析response_body平铺展示.ipynb`

---

## ✨ 新增功能

### 1. CSV 输出功能

现在支持将解析后的数据输出到 CSV 文件：

```python
WRITE_CSV = True  # 开启 CSV 输出
```

**输出文件**：
- `consultas_<timestamp>.csv` - 查询记录明细
- `creditos_<timestamp>.csv` - 信贷账户明细
- `empleos_<timestamp>.csv` - 工作记录明细
- `domicilios_<timestamp>.csv` - 住址记录明细
- `summary_<timestamp>.csv` - 汇总统计

**输出位置**：`CDC/outputs/response_body_flat/`

### 2. 每个板块的查询代码块

在每个板块（consultas、creditos、empleos、domicilios）下都新增了一个查询代码块，可以快速查询某个 apply_id 的明细数据。

---

## 🚀 使用方法

### 步骤1：配置参数

在第2个代码块中配置：

```python
# 是否输出到 Excel
WRITE_EXCEL = False

# 是否输出到 CSV
WRITE_CSV = True  # 改为 True 启用 CSV 输出

# 最大处理样本数
MAX_SAMPLES = None  # None=全部，10=只处理前10个
```

### 步骤2：运行所有单元格

点击 "Run All" 或按 `Shift+Enter` 逐个运行。

### 步骤3：查询某个 apply_id 的明细

在每个板块下都有查询代码块，修改 `query_apply_id` 即可：

```python
query_apply_id = '1065991091661283329'  # 修改这里
```

---

## 📊 查询示例

### 示例1：查询 consultas 明细

在 **7.1 consultas** 章节下的查询代码块中：

```python
# 查询某个 apply_id 的 consultas 明细
query_apply_id = '1065991091661283329'  # 修改这里

consultas_detail = parsed_data['consultas'][parsed_data['consultas']['apply_id'] == query_apply_id]

print(f"apply_id = {query_apply_id} 的 consultas 明细")
print("="*60)
print(f"共 {len(consultas_detail)} 条查询记录")

if len(consultas_detail) > 0:
    consultas_detail
else:
    print("未找到该 apply_id 的查询记录")
```

**输出示例**：
```
apply_id = 1065991091661283329 的 consultas 明细
============================================================
共 55 条查询记录

[显示该 apply_id 的所有查询记录表格]
```

### 示例2：查询 creditos 明细

在 **7.2 creditos** 章节下的查询代码块中：

```python
query_apply_id = '1065991091661283329'  # 修改这里
creditos_detail = parsed_data['creditos'][parsed_data['creditos']['apply_id'] == query_apply_id]
```

**输出示例**：
```
apply_id = 1065991091661283329 的 creditos 明细
============================================================
共 142 个信贷账户

[显示该 apply_id 的所有信贷账户表格]
```

### 示例3：查询 empleos 明细

在 **7.3 empleos** 章节下的查询代码块中：

```python
query_apply_id = '1067575625355862017'  # 这个 ID 有工作记录
empleos_detail = parsed_data['empleos'][parsed_data['empleos']['apply_id'] == query_apply_id]
```

### 示例4：查询 domicilios 明细

在 **7.4 domicilios** 章节下的查询代码块中：

```python
query_apply_id = '1065991091661283329'
domicilios_detail = parsed_data['domicilios'][parsed_data['domicilios']['apply_id'] == query_apply_id]
```

---

## 📁 输出文件说明

### CSV 文件格式

所有 CSV 文件使用 `UTF-8 with BOM` 编码，可以直接在 Excel 中打开。

| 文件名 | 内容 | 行数（示例） | 用途 |
|--------|------|-------------|------|
| `consultas_<timestamp>.csv` | 查询记录明细 | 412,045 | 查看所有查询记录 |
| `creditos_<timestamp>.csv` | 信贷账户明细 | 697,815 | 查看所有信贷账户 |
| `empleos_<timestamp>.csv` | 工作记录明细 | 5,188 | 查看所有工作记录 |
| `domicilios_<timestamp>.csv` | 住址记录明细 | 37,272 | 查看所有住址记录 |
| `summary_<timestamp>.csv` | 汇总统计 | 12,546 | 查看每个申请的记录数统计 |

### 文件大小参考

| 文件 | 大小（约） |
|------|-----------|
| consultas CSV | 50-100 MB |
| creditos CSV | 150-300 MB |
| empleos CSV | 1-5 MB |
| domicilios CSV | 5-10 MB |
| summary CSV | 1-2 MB |

---

## 💡 使用技巧

### 技巧1：快速测试

如果只想快速测试，设置：

```python
MAX_SAMPLES = 10  # 只处理前10个申请
WRITE_CSV = False  # 不输出文件
```

### 技巧2：查询多个 apply_id

如果要查询多个 apply_id，可以修改查询代码：

```python
# 查询多个 apply_id
query_apply_ids = ['1065991091661283329', '1066560157648134145', '1066719243236777985']

consultas_detail = parsed_data['consultas'][parsed_data['consultas']['apply_id'].isin(query_apply_ids)]

print(f"查询 {len(query_apply_ids)} 个 apply_id 的 consultas 明细")
print(f"共 {len(consultas_detail)} 条查询记录")
consultas_detail
```

### 技巧3：导出查询结果

如果要导出某个 apply_id 的查询结果：

```python
# 导出到 CSV
consultas_detail.to_csv('outputs/consultas_1065991091661283329.csv', index=False, encoding='utf-8-sig')

# 导出到 Excel
consultas_detail.to_excel('outputs/consultas_1065991091661283329.xlsx', index=False)
```

### 技巧4：在 Excel 中打开 CSV

1. 直接双击 CSV 文件（使用 UTF-8 with BOM 编码，不会乱码）
2. 或者在 Excel 中：数据 → 从文本/CSV → 选择文件

### 技巧5：查看某个字段的分布

```python
# 查看某个 apply_id 的查询机构分布
consultas_detail['nombreOtorgante'].value_counts()

# 查看某个 apply_id 的账户类型分布
creditos_detail['tipoCuenta'].value_counts()
```

---

## 🔍 常见问题

### Q1：为什么查询返回空结果？

**A**：可能的原因：
1. apply_id 不存在 - 检查 ID 是否正确
2. 该 apply_id 没有该类型的记录（例如没有工作记录）
3. 数据类型不匹配 - apply_id 是字符串，要用字符串查询

**解决方法**：
```python
# 检查 apply_id 是否存在
print(query_apply_id in parsed_data['consultas']['apply_id'].values)

# 查看所有 apply_id
print(parsed_data['consultas']['apply_id'].unique()[:10])
```

### Q2：CSV 文件太大，Excel 打不开怎么办？

**A**：
1. 使用 Python 读取：`pd.read_csv('file.csv')`
2. 使用专业工具：Tableau、Power BI
3. 分批导出：只导出某些 apply_id 的数据

### Q3：如何查看某个字段的详细信息？

**A**：
```python
# 查看某个字段的统计信息
consultas_detail['importeCredito'].describe()

# 查看某个字段的唯一值
consultas_detail['tipoCredito'].unique()

# 查看某个字段的缺失情况
consultas_detail['importeCredito'].isna().sum()
```

### Q4：如何按条件筛选数据？

**A**：
```python
# 筛选某个机构的查询记录
bank_consultas = consultas_detail[consultas_detail['nombreOtorgante'] == 'BANCOS']

# 筛选金额大于1000的查询
high_amount = consultas_detail[consultas_detail['importeCredito'] > 1000]

# 筛选某个日期范围的查询
consultas_detail['fechaConsulta'] = pd.to_datetime(consultas_detail['fechaConsulta'])
recent = consultas_detail[consultas_detail['fechaConsulta'] >= '2025-11-01']
```

---

## 📚 相关文档

- [解析response_body平铺展示说明](./解析response_body平铺展示说明.md)
- [四个板块衍生逻辑分析](./四个板块衍生逻辑分析.md)
- [BOSS板块输出数字说明](./BOSS板块输出数字说明.md)

---

**文档版本**：v2.0  
**更新时间**：2026-01-26  
**更新内容**：
- ✅ 添加 CSV 输出功能
- ✅ 每个板块增加查询代码块
- ✅ 完善使用说明和示例
