# 解析 response_body 平铺展示说明

## 📄 脚本概述

`解析response_body平铺展示.ipynb` 是一个用于解析 `cdc_pickle_pass_fpd7.pkl` 文件的工具脚本，可以将 `response_body` 中的 JSON 数据平铺成表格形式，方便查看和分析。

---

## 🎯 主要功能

### 1. 数据解析

将 `response_body` 中的四个子板块数据解析并平铺：

| 板块 | 说明 | 平均记录数/申请 |
|------|------|----------------|
| **consultas** | 查询记录 | 32.8 条 |
| **creditos** | 信贷账户 | 55.6 个 |
| **empleos** | 工作记录 | 0.41 条 |
| **domicilios** | 住址记录 | 2.97 条 |

### 2. 数据质量分析

对每个板块的数据进行质量分析：
- 字段列表
- 数据类型
- 缺失值统计
- 唯一值数量

### 3. 数据输出

支持输出到 Excel 或 CSV 文件：
- 各板块明细表
- 数据质量报告
- 汇总统计表

### 4. 快速查询

提供常用的数据查询示例：
- 查看某个申请的所有记录
- 统计各机构查询次数
- 统计账户类型分布
- 查看薪资分布

---

## 🚀 使用方法

### 步骤1：打开 Notebook

在 Jupyter 或 VS Code 中打开 `CDC/解析response_body平铺展示.ipynb`

### 步骤2：配置参数

```python
# 配置参数
PICKLE_PATH = Path("cdc_pickle_pass_fpd7.pkl")
OUTPUT_DIR = Path("outputs/response_body_flat")

# 是否输出到 Excel（True=输出；False=只在内存中查看）
WRITE_EXCEL = True

# 是否输出到 CSV（True=输出；False=不输出）
WRITE_CSV = False
```

### 步骤3：运行所有单元格

点击 "Run All" 或逐个运行单元格。

### 步骤4：查看结果

- 在 Notebook 中查看各板块的数据
- 在 `outputs/response_body_flat/` 目录下查看输出的文件

---

## 📊 输出文件说明

### Excel 文件

| 文件名 | 内容 | 说明 |
|--------|------|------|
| `consultas_<timestamp>.xlsx` | 查询记录明细表 | 所有查询记录，apply_id 会重复 |
| `creditos_<timestamp>.xlsx` | 信贷账户明细表 | 所有信贷账户，apply_id 会重复 |
| `empleos_<timestamp>.xlsx` | 工作记录明细表 | 所有工作记录，apply_id 会重复 |
| `domicilios_<timestamp>.xlsx` | 住址记录明细表 | 所有住址记录，apply_id 会重复 |
| `summary_<timestamp>.xlsx` | 汇总统计表 | 每个 apply_id 的记录数统计 |
| `data_quality_<timestamp>.xlsx` | 数据质量报告 | 各板块的数据质量分析 |

**注意**：`<timestamp>` 是文件生成时间，格式为 `YYYYMMDD_HHMMSS`

---

## 📈 数据结构说明

### consultas（查询记录）

**主要字段**：

| 字段名 | 说明 | 示例 |
|--------|------|------|
| apply_id | 申请ID | 1065991091661283329 |
| request_time | 截止时间 | 2025-11-25 01:53:44.943 |
| fechaConsulta | 查询日期 | 2025-11-20 |
| nombreOtorgante | 查询机构 | BANCOS |
| tipoCredito | 查询类型 | TC（信用卡） |
| importeCredito | 合同金额 | 5000 |
| claveOtorgante | 机构代码 | 004676 |

### creditos（信贷账户）

**主要字段**：

| 字段名 | 说明 | 示例 |
|--------|------|------|
| apply_id | 申请ID | 1065991091661283329 |
| request_time | 截止时间 | 2025-11-25 01:53:44.943 |
| fechaAperturaCuenta | 开户日期 | 2023-01-26 |
| fechaCierreCuenta | 关户日期 | 2024-01-26 |
| nombreOtorgante | 机构名称 | BANCOS |
| tipoCuenta | 账户类型 | R（循环信用） |
| tipoCredito | 信贷类型 | TC（信用卡） |
| saldoActual | 当前余额 | 5000 |
| limiteCredito | 信用额度 | 10000 |
| saldoVencido | 逾期余额 | 0 |
| tipoResponsabilidad | 责任类型 | I（个人） |
| clavePrevencion | 预防类型 | CL（正常关闭） |

### empleos（工作记录）

**主要字段**：

| 字段名 | 说明 | 示例 |
|--------|------|------|
| apply_id | 申请ID | 1065991091661283329 |
| request_time | 截止时间 | 2025-11-25 01:53:44.943 |
| nombreEmpresa | 公司名称 | ABC Company |
| salarioMensual | 月薪 | 10000 |
| fechaContratacion | 入职日期 | 2023-01-01 |
| fechaUltimoDiaEmpleo | 离职日期 | 2024-12-31 |
| fechaVerificacionEmpleo | 验证日期 | 2025-01-01 |

### domicilios（住址记录）

**主要字段**：

| 字段名 | 说明 | 示例 |
|--------|------|------|
| apply_id | 申请ID | 1065991091661283329 |
| request_time | 截止时间 | 2025-11-25 01:53:44.943 |
| fechaResidencia | 居住开始日期 | 2023-01-01 |
| estado | 州/省 | CDMX |
| direccion | 详细地址 | Calle 123 |

---

## 💡 使用场景

### 场景1：数据探索

**目的**：了解 response_body 的数据结构和内容

**步骤**：
1. 运行脚本
2. 查看各板块的字段列表
3. 查看前几行数据
4. 查看数据质量报告

### 场景2：数据核对

**目的**：核对特征计算是否正确

**步骤**：
1. 输出到 Excel
2. 在 Excel 中查看某个 apply_id 的明细记录
3. 手工计算特征值
4. 与衍生脚本的输出对比

### 场景3：数据分析

**目的**：分析数据分布和特征

**步骤**：
1. 使用快速查询示例
2. 统计各维度的分布
3. 发现数据规律
4. 为特征工程提供依据

### 场景4：问题排查

**目的**：排查数据异常或特征计算错误

**步骤**：
1. 找到异常的 apply_id
2. 查看该 apply_id 的所有明细记录
3. 检查数据是否异常
4. 定位问题原因

---

## 🔍 快速查询示例

### 示例1：查看某个申请的所有查询记录

```python
apply_id = 1065991091661283329
consultas = parsed_data["consultas"][parsed_data["consultas"]["apply_id"] == apply_id]
print(f"共 {len(consultas)} 条查询记录")
consultas
```

### 示例2：统计各机构的查询次数

```python
otorgante_stats = parsed_data["consultas"]["nombreOtorgante"].value_counts()
print("各机构查询次数（Top 20）：")
otorgante_stats.head(20)
```

### 示例3：查看高额度账户

```python
high_limit = parsed_data["creditos"][parsed_data["creditos"]["limiteCredito"] > 50000]
print(f"共 {len(high_limit)} 个高额度账户（>50000）")
high_limit[["apply_id", "nombreOtorgante", "limiteCredito", "saldoActual"]]
```

### 示例4：查看逾期账户

```python
overdue = parsed_data["creditos"][parsed_data["creditos"]["saldoVencido"] > 0]
print(f"共 {len(overdue)} 个逾期账户")
overdue[["apply_id", "nombreOtorgante", "saldoVencido", "peorAtraso"]]
```

### 示例5：查看高薪工作

```python
high_salary = parsed_data["empleos"][parsed_data["empleos"]["salarioMensual"] > 20000]
print(f"共 {len(high_salary)} 条高薪工作记录（>20000）")
high_salary[["apply_id", "nombreEmpresa", "salarioMensual"]]
```

---

## ⚠️ 注意事项

### 1. 内存占用

- 解析后的数据会占用较多内存（约 500MB-1GB）
- 如果内存不足，可以分批处理或只解析部分板块

### 2. 文件大小

- Excel 文件可能很大（creditos 约 100-200MB）
- 建议使用 Excel 2016 或更高版本打开
- 如果文件太大，可以考虑输出到 CSV

### 3. 数据类型

- 日期字段可能是字符串格式，需要手动转换
- 金额字段可能包含空值或非数值
- 建议在使用前先检查数据类型

### 4. 性能优化

- 如果只需要查看部分数据，可以在解析时添加过滤条件
- 如果只需要某个板块，可以注释掉其他板块的解析代码

---

## 🛠️ 自定义修改

### 修改1：只解析某个板块

```python
# 在 parse_response_body 函数中，注释掉不需要的板块
# 例如，只解析 consultas：

# 解析 consultas
consultas = obj.get("consultas", [])
# ... consultas 解析代码 ...

# 注释掉其他板块
# creditos = obj.get("creditos", [])
# empleos = obj.get("empleos", [])
# domicilios = obj.get("domicilios", [])
```

### 修改2：添加过滤条件

```python
# 只解析某些 apply_id
target_apply_ids = [1065991091661283329, 1066560157648134145]
df_raw_filtered = df_raw[df_raw["apply_id"].isin(target_apply_ids)]
parsed_data = parse_response_body(df_raw_filtered)
```

### 修改3：添加自定义字段

```python
# 在解析时添加计算字段
consultas_rows.append({
    "apply_id": apply_id,
    "request_time": request_time,
    **item,
    # 添加自定义字段
    "days_since_query": (request_time - pd.to_datetime(item.get("fechaConsulta"))).days
})
```

---

## 📚 相关文档

- [四个板块衍生逻辑分析](./四个板块衍生逻辑分析.md)
- [BOSS板块输出数字说明](./BOSS板块输出数字说明.md)
- [输出控制统一说明](./输出控制统一说明.md)

---

## 🔄 更新历史

- **2026-01-26**：初始版本
  - ✅ 支持解析四个子板块
  - ✅ 支持数据质量分析
  - ✅ 支持输出到 Excel/CSV
  - ✅ 提供快速查询示例

---

**文档版本**：v1.0  
**创建时间**：2026-01-26  
**作者**：Kiro AI Assistant
