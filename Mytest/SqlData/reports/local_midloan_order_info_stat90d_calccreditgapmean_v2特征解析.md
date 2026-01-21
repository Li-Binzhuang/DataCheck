# local_midloan_order_info_stat90d_calccreditgapmean_v2 特征解析

## 一、特征基本信息

- **特征名**: `local_midloan_order_info_stat90d_calccreditgapmean_v2`
- **特征含义**: 近90天内，历次下单时间距离一次风控时间的平均天数间隔
- **时间窗口**: 90天（从观察日期往前推90天）
- **数据来源**: `test/99.sql` 中的 `stat90D` CTE

---

## 二、计算逻辑详解

### 2.1 整体计算流程

```
1. base_loan_data_light (基础表)
   ↓
2. order_level_stats (订单级别聚合)
   ↓
3. order_new_credit_time (新客授信时间)
   ↓
4. order_prev_settled_time_precise (往前最近的结清时间)
   ↓
5. order_level_stats_with_credit_gap (计算每个订单的calc_credit_gap_new)
   ↓
6. stat90D_base (筛选90天窗口内的订单)
   ↓
7. stat90D (聚合计算平均值)
   ↓
8. 最终输出: calcCreditGapMean
```

### 2.2 核心计算逻辑

#### 步骤1: 计算每个订单的额度测算间隔 (`calc_credit_gap_new`)

**业务含义**: 计算"当前订单创建时间"距离"上一次风控时间"的天数间隔

**计算规则** (在 `order_level_stats_with_credit_gap` CTE中):

```sql
CASE 
    -- 情况1: 第一笔订单
    -- 条件: 不存在往前最近的settled_time (prev_settled_time_precise IS NULL)
    --       且存在新客授信时间 (new_credit_time IS NOT NULL)
    -- 计算: 订单创建时间 - 新客授信时间
    WHEN opstp.prev_settled_time_precise IS NULL 
        AND onct.new_credit_time IS NOT NULL 
    THEN GREATEST(DATEDIFF(DATE(ols.order_create_time), DATE(onct.new_credit_time)), 0)
    
    -- 情况2: 后续订单（续借订单）
    -- 条件: 存在往前最近的settled_time (prev_settled_time_precise IS NOT NULL)
    -- 计算: 订单创建时间 - 往前最近的settled_time（上一笔订单的结清时间）
    WHEN opstp.prev_settled_time_precise IS NOT NULL 
    THEN GREATEST(DATEDIFF(DATE(ols.order_create_time), DATE(opstp.prev_settled_time_precise)), 0)
    
    -- 情况3: 兜底情况
    -- 如果都没有，返回0
    ELSE 0
END AS calc_credit_gap_new
```

#### 步骤2: 筛选90天窗口内的订单 (`stat90D_base`)

```sql
WHERE ols.order_create_time >= date_sub(ols.observation_date, 90)
    AND ols.order_create_time < ols.observation_date  -- 排除观察日期当天的订单
```

**说明**:
- 只统计观察日期往前90天内的订单
- 排除观察日期当天的订单（即最新申请的订单）

#### 步骤3: 计算平均值 (`stat90D`)

```sql
ROUND(AVG(base.calc_credit_gap), 6) AS calcCreditGapMean
```

**说明**:
- 对所有90天窗口内的订单的 `calc_credit_gap` 值取平均值
- 保留6位小数

---

## 三、详细业务逻辑

### 3.1 第一笔订单的计算逻辑

**识别方式**: 
- 通过 `order_prev_settled_time_precise` CTE判断
- 如果 `prev_settled_time_precise IS NULL`，说明该订单创建时间之前没有已结清的账单，即这是第一笔订单

**新客授信时间获取** (`order_new_credit_time` CTE):
```sql
-- 通过 use_credit.credit_apply_id = credit_apply.id 匹配
-- 获取 credit_apply.create_time 作为新客授信时间
```

**计算公式**:
```
calc_credit_gap_new = 订单创建时间(use_credit.create_time) - 新客授信时间(credit_apply.create_time)
```

**业务含义**: 
- 第一笔订单：从首次授信到首次下单的时间间隔
- 反映客户从获得授信到实际使用额度的间隔时间

### 3.2 后续订单（续借订单）的计算逻辑

**识别方式**: 
- 如果 `prev_settled_time_precise IS NOT NULL`，说明该订单创建时间之前存在已结清的账单，即这是续借订单

**往前最近的结清时间获取** (`order_prev_settled_time_precise` CTE):
```sql
-- 在该客户所有账单的settled_time中
-- 找到小于order_create_time的最大值（精确到秒比较）
MAX(CASE 
    WHEN bld.settled_time IS NOT NULL 
        AND bld.settled_time < ols.order_create_time  -- 精确到秒比较
    THEN bld.settled_time 
    ELSE NULL 
END) AS prev_settled_time_precise
```

**计算公式**:
```
calc_credit_gap_new = 当前订单创建时间(use_credit.create_time) - 上一笔订单的结清时间(prev_settled_time_precise)
```

**业务含义**: 
- 续借订单：从上一笔订单结清到当前订单创建的时间间隔
- 反映客户的续借频率和用信习惯

### 3.3 时间窗口筛选

**90天窗口**:
- 起始时间: `observation_date - 90天`
- 结束时间: `observation_date`（不包含当天）
- 只统计这个时间窗口内的订单

**观察日期** (`customer_observation_date` CTE):
```sql
-- 各客户的最新use_credit.create_time作为观察日期
MAX(create_time) AS observation_date
```

---

## 四、SQL代码位置

### 4.1 关键代码段

1. **基础表**: `base_loan_data_light` (第19-149行)
   - 包含订单、账单、额度等基础信息

2. **订单级别聚合**: `order_level_stats` (第162-350行)
   - 将账单级别数据聚合到订单级别

3. **新客授信时间**: `order_new_credit_time` (第320-350行)
   - 获取第一笔订单对应的授信时间

4. **往前最近的结清时间**: `order_prev_settled_time_precise` (第352-376行)
   - 获取续借订单对应的上一笔订单结清时间

5. **计算额度测算间隔**: `order_level_stats_with_credit_gap` (第392-417行)
   - 计算每个订单的 `calc_credit_gap_new`

6. **90天窗口筛选**: `stat90D_base` (第866-911行)
   - 筛选90天窗口内的订单

7. **聚合计算平均值**: `stat90D` (第913-923行)
   - 计算 `calcCreditGapMean`

8. **最终输出**: 第1530行
   ```sql
   COALESCE(s90.calcCreditGapMean, 0) AS local_midloan_order_info_stat90d_calccreditgapmean_v2
   ```

---

## 五、业务含义

### 5.1 特征含义

**`local_midloan_order_info_stat90d_calccreditgapmean_v2`** 表示：
- **近90天内**，客户所有订单的"下单时间距离上一次风控时间"的平均天数间隔

### 5.2 业务价值

1. **客户用信习惯**: 
   - 值越小，说明客户用信频率越高，从授信/结清到下单的间隔越短
   - 值越大，说明客户用信频率越低，间隔越长

2. **风险识别**:
   - 间隔过短可能表示客户资金需求紧急，风险可能较高
   - 间隔过长可能表示客户用信不活跃，或者有其他资金渠道

3. **续借行为**:
   - 对于续借客户，反映从上一笔订单结清到再次下单的间隔
   - 可以识别客户的续借模式和资金周转情况

### 5.3 示例说明

**示例1: 第一笔订单**
- 客户A在2025-01-01获得授信（`credit_apply.create_time`）
- 客户A在2025-01-10创建第一笔订单（`use_credit.create_time`）
- `calc_credit_gap_new = 2025-01-10 - 2025-01-01 = 9天`

**示例2: 续借订单**
- 客户A的第一笔订单在2025-02-01结清（`settled_time`）
- 客户A在2025-02-15创建第二笔订单（`use_credit.create_time`）
- `calc_credit_gap_new = 2025-02-15 - 2025-02-01 = 14天`

**示例3: 90天窗口内的平均值**
- 假设客户A在90天窗口内有3笔订单：
  - 订单1: `calc_credit_gap_new = 9天`（第一笔）
  - 订单2: `calc_credit_gap_new = 14天`（续借）
  - 订单3: `calc_credit_gap_new = 10天`（续借）
- `calcCreditGapMean = (9 + 14 + 10) / 3 = 11天`

---

## 六、注意事项

### 6.1 时间逻辑

1. **精确到秒的比较**: 
   - `prev_settled_time_precise` 使用精确到秒的时间比较
   - 确保找到的是"往前最近"的结清时间

2. **时间窗口**:
   - 只统计观察日期往前90天内的订单
   - 排除观察日期当天的订单

3. **时间穿越防护**:
   - 所有时间比较都确保在观察日期之前
   - 避免使用未来的数据

### 6.2 数据完整性

1. **第一笔订单判断**:
   - 如果 `prev_settled_time_precise IS NULL`，且 `new_credit_time IS NOT NULL`，才按第一笔订单计算
   - 如果两个条件都不满足，返回0

2. **续借订单判断**:
   - 如果 `prev_settled_time_precise IS NOT NULL`，按续借订单计算
   - 使用 `GREATEST(..., 0)` 确保结果不为负数

### 6.3 特殊情况处理

1. **没有订单**: 
   - 如果90天窗口内没有订单，`AVG()` 返回 `NULL`
   - 最终使用 `COALESCE(..., 0)` 处理，返回0

2. **没有匹配的授信时间**:
   - 第一笔订单如果没有匹配到 `credit_apply`，`new_credit_time` 为 `NULL`
   - 此时返回0

3. **没有往前最近的结清时间**:
   - 续借订单如果找不到往前最近的 `settled_time`，返回0

---

## 七、与其他特征的关系

### 7.1 类似特征

- `local_midloan_order_info_stat180d_calccreditgapmean_v2`: 180天窗口内的平均值
- `local_midloan_order_info_stat10000d_calccreditgapmean_v2`: 10000天窗口内的平均值

### 7.2 计算逻辑一致性

三个时间窗口（90天、180天、10000天）使用相同的计算逻辑：
- 都是计算 `calc_credit_gap_new` 的平均值
- 区别仅在于时间窗口范围不同

---

## 八、SQL代码片段

### 8.1 核心计算代码

```sql
-- 在 order_level_stats_with_credit_gap 中计算每个订单的间隔
CASE 
    WHEN opstp.prev_settled_time_precise IS NULL 
        AND onct.new_credit_time IS NOT NULL 
    THEN GREATEST(DATEDIFF(DATE(ols.order_create_time), DATE(onct.new_credit_time)), 0)
    WHEN opstp.prev_settled_time_precise IS NOT NULL 
    THEN GREATEST(DATEDIFF(DATE(ols.order_create_time), DATE(opstp.prev_settled_time_precise)), 0)
    ELSE 0
END AS calc_credit_gap_new
```

### 8.2 聚合计算代码

```sql
-- 在 stat90D 中计算平均值
ROUND(AVG(base.calc_credit_gap), 6) AS calcCreditGapMean
```

### 8.3 最终输出代码

```sql
-- 在最终SELECT中输出
COALESCE(s90.calcCreditGapMean, 0) AS local_midloan_order_info_stat90d_calccreditgapmean_v2
```

---

**文档生成时间**: 2026-01-19
