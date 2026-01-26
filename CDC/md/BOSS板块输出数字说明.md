# BOSS 板块输出数字说明

## 输出示例

```
[WRITE_EXCEL] boss feature quality saved: /Users/zhanglifeng12703/Documents/OverseasPython/CDC/outputs/blockboss_feature_quality.xlsx
[INFO] loaded pickle: cdc_pickle_pass_fpd7.pkl
[INFO] mapped apply_time -> request_time
raw_df shape: (12546, 12)
excel_feature_cnt (if readable): None
consultas_df: (412045, 5)
creditos_df: (697815, 23)
empleos_df: (5188, 7)
domicilios_df: (37272, 5)
```

---

## 数字含义详解

### 1. `raw_df shape: (12546, 12)`

**含义**：原始数据表的形状

- **12546**：总共有 12546 个申请（apply_id）
- **12**：每个申请有 12 个字段

**说明**：
- 这是从 `cdc_pickle_pass_fpd7.pkl` 读取的数据
- 每一行代表一个申请记录
- 包含的字段：apply_id、response_body、request_time、approve_state、credit_limit_amount、use_amount、principal_amount_borrowed、fpd7、spd7、credit_apply_cnt、blind_lend 等

---

### 2. `excel_feature_cnt (if readable): None`

**含义**：Excel 特征定义文件的特征数量

- **None**：表示没有读取到 Excel 文件，或者 Excel 文件不存在

**说明**：
- BOSS 板块原本设计从 `BOSS衍生.xlsx` 读取特征定义
- 如果这个值是数字（比如 148），表示 Excel 中定义了 148 个特征
- 用于核对代码生成的特征数量是否与 Excel 定义一致

---

### 3. `consultas_df: (412045, 5)`

**含义**：查询记录明细表的形状

- **412045**：从所有申请的 response_body 中解析出的**查询记录总数**
- **5**：每条查询记录有 5 个字段

**说明**：
- 这是从 `response_body.consultas` 解析出来的平铺明细
- 平均每个申请有：412045 ÷ 12546 ≈ **32.8 条查询记录**
- 5 个字段包括：
  1. `apply_id`（申请ID）
  2. `request_time`（截止时间）
  3. `fechaConsulta`（查询日期）
  4. `importeCredito`（合同金额）
  5. `tipoCredito`（查询的信贷类型）

**用途**：
- 用于计算查询相关特征
- 例如：近 30/60/90 天查询次数、查询金额统计、车贷查询次数、信用卡查询次数等

---

### 4. `creditos_df: (697815, 23)`

**含义**：信贷账户明细表的形状

- **697815**：从所有申请的 response_body 中解析出的**信贷账户总数**
- **23**：每条信贷账户记录有 23 个字段

**说明**：
- 这是从 `response_body.creditos` 解析出来的平铺明细
- 平均每个申请有：697815 ÷ 12546 ≈ **55.6 个信贷账户**
- 23 个字段包括：
  - 基础信息：apply_id、request_time
  - 日期字段：fechaReporte、fechaAperturaCuenta、fechaCierreCuenta、fechaUltimoPago、fechaUltimaCompra、fechaActualizacion、fechaPeorAtraso、ultimaFechaSaldoCero
  - 金额字段：saldoActual、limiteCredito、saldoVencido、valorActivoValuacion、creditoMaximo、montoPagar
  - 类型字段：tipoCuenta、tipoCredito、tipoResponsabilidad、frecuenciaPagos
  - 其他字段：numeroPagos、peorAtraso、clavePrevencion

**用途**：
- 用于计算信贷相关特征
- 例如：总账户数、开放账户数、账户使用率、授信收入比、负债收入比、最差逾期状态等

---

### 5. `empleos_df: (5188, 7)`

**含义**：工作记录明细表的形状

- **5188**：从所有申请的 response_body 中解析出的**工作记录总数**
- **7**：每条工作记录有 7 个字段

**说明**：
- 这是从 `response_body.empleos` 解析出来的平铺明细
- 平均每个申请有：5188 ÷ 12546 ≈ **0.41 条工作记录**（很多申请没有工作记录）
- 7 个字段包括：
  1. `apply_id`（申请ID）
  2. `request_time`（截止时间）
  3. `salarioMensual`（月薪）
  4. `fechaContratacion`（入职日期）
  5. `fechaUltimoDiaEmpleo`（离职日期）
  6. `fechaVerificacionEmpleo`（工作验证日期）
  7. `nombreEmpresa`（公司名称）

**用途**：
- 用于计算工作相关特征
- 例如：工作记录数、平均工作月数、当前工作月数、平均月薪、工作变更次数、工作稳定性得分等

---

### 6. `domicilios_df: (37272, 5)`

**含义**：住址记录明细表的形状

- **37272**：从所有申请的 response_body 中解析出的**住址记录总数**
- **5**：每条住址记录有 5 个字段

**说明**：
- 这是从 `response_body.domicilios` 解析出来的平铺明细
- 平均每个申请有：37272 ÷ 12546 ≈ **2.97 条住址记录**
- 5 个字段包括：
  1. `apply_id`（申请ID）
  2. `request_time`（截止时间）
  3. `fechaResidencia`（居住开始日期）
  4. `estado`（州/省）
  5. `direccion`（详细地址）

**用途**：
- 用于计算住址相关特征
- 例如：平均居住月数、最长居住月数、当前居住月数、州数量、近期搬迁标记、居住稳定性得分等

---

## 数据规模总结

| 数据类型 | 总记录数 | 平均每申请记录数 | 字段数 | 用途 |
|---------|---------|----------------|-------|------|
| **原始申请** | 12,546 | 1 | 12 | 基础数据 |
| **查询记录** | 412,045 | 32.8 | 5 | 查询特征 |
| **信贷账户** | 697,815 | 55.6 | 23 | 信贷特征 |
| **工作记录** | 5,188 | 0.41 | 7 | 工作特征 |
| **住址记录** | 37,272 | 2.97 | 5 | 住址特征 |

---

## 数据质量观察

### 1. 查询记录（consultas）

- ✅ **数据充足**：平均每个申请有 32.8 条查询记录
- ✅ **覆盖率高**：大部分申请都有查询记录
- 💡 **特征价值**：可以计算丰富的查询行为特征

### 2. 信贷账户（creditos）

- ✅ **数据充足**：平均每个申请有 55.6 个信贷账户
- ✅ **覆盖率高**：大部分申请都有信贷历史
- 💡 **特征价值**：可以计算丰富的信贷行为特征

### 3. 工作记录（empleos）

- ⚠️ **数据稀疏**：平均每个申请只有 0.41 条工作记录
- ⚠️ **覆盖率低**：约 59% 的申请没有工作记录（5188 ÷ 12546 ≈ 41%）
- 💡 **特征价值**：工作特征可能有缺失，需要做好缺失值处理

### 4. 住址记录（domicilios）

- ✅ **数据适中**：平均每个申请有 2.97 条住址记录
- ✅ **覆盖率较高**：大部分申请都有住址记录
- 💡 **特征价值**：可以计算居住稳定性相关特征

---

## 特征衍生流程

```
原始数据 (12546 个申请)
    │
    ├─ 解析 response_body.consultas
    │  └─> consultas_df (412045 条记录)
    │      └─> 计算查询特征（约 30-40 个）
    │
    ├─ 解析 response_body.creditos
    │  └─> creditos_df (697815 条记录)
    │      └─> 计算信贷特征（约 80-100 个）
    │
    ├─ 解析 response_body.empleos
    │  └─> empleos_df (5188 条记录)
    │      └─> 计算工作特征（约 10-15 个）
    │
    └─ 解析 response_body.domicilios
       └─> domicilios_df (37272 条记录)
           └─> 计算住址特征（约 8-12 个）
                │
                ▼
        features_df (12546 行 × 148 列)
        每个 apply_id 一行，包含所有衍生特征
```

---

## 常见问题

### Q1：为什么 empleos_df 的记录数这么少？

**A**：
- 工作信息不是征信报告的必填项
- 很多用户可能没有提供工作信息，或者征信机构没有收集到
- 这是正常现象，需要在特征计算时做好缺失值处理

### Q2：平均每个申请有 55.6 个信贷账户，是不是太多了？

**A**：
- 这是正常的，因为 creditos 包含了用户的**所有历史信贷账户**
- 包括：已关闭的账户、零余额账户、历史账户等
- 不是说用户同时有 55 个活跃账户

### Q3：这些明细表会输出到文件吗？

**A**：
- 默认**不输出**明细表
- BOSS 板块只输出特征表：`boss_features_full_<timestamp>.csv`
- 如果需要查看明细，可以在 notebook 中直接查看变量：
  ```python
  consultas_df.head()
  creditos_df.head()
  empleos_df.head()
  domicilios_df.head()
  ```

### Q4：如何验证特征计算是否正确？

**A**：
1. 查看明细表的记录数是否合理
2. 查看特征表的形状：`features_df.shape`（应该是 12546 行 × 148 列）
3. 查看特征值的分布：`features_df.describe()`
4. 对比 Excel 定义的特征数量

---

## 相关文档

- [BOSS板块CSV输出说明](./BOSS板块CSV输出说明.md)
- [CSV输出配置总结](./CSV输出配置总结.md)
- [输出控制统一说明](./输出控制统一说明.md)
