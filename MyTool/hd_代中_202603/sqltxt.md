## PART 1：中间表解析
### 1. target_user（目标用户表）
### 2. target_user_credit_loan_repay_info（用户授信借款还款信息表）
| 字段                        | 含义          | 计算逻辑                                 |
|---------------------------|-------------|--------------------------------------|
| `order_asc_rank`          | 在贷订单按时间升序排名 | 首单&未结清                               |
| `order_desc_rank`         | 在贷订单按时间降序排名 | 最近一笔&未结清                             |
| `total_order_asc_rank`    | 所有订单按时间升序排名 | 首单                                   |
| `total_order_desc_rank`   | 所有订单按时间降序排名 | 最近一笔订单                               |
| `is_tqjq`                 | 是否提前结清      | 结清时间 < 用信窗口时间 且 结清日期 < 贷款结束日期        |
| `is_tqjq_15d`             | 是否提前15天结清   | 提前结清且提前天数 > 15天                      |
| `is_tqjq_7d`              | 是否提前7天结清    | 提前结清且提前天数 > 7天                       |
| `is_tqjq_3d`              | 是否提前3天结清    | 提前结清且提前天数 > 3天                       |
| `is_overdue`              | 是否逾期        | 贷款结束日期 < 用信日期 且 未结清或结清时间晚于到期日        |
| `is_unclear_tag`          | 是否在贷订单标记    | 未结清或结清时间 > 用信窗口时间（值为1表示在贷）           |
| `creditlimit_use_ratio`   | 额度使用率       | 用信窗口时的预使用额度 / (可用额度+预使用额度)值越高表示用信越充分 |
| `available_limit`         | 剩余可用额度      | 总授信额度 - 已使用额度                        |
| `credit_create_time`      | 授信申请时间      | 记录用户最初获得授信的时间点，用于计算从授信到用信的时间间隔       |
| `creadit_use_create_time` | 用信申请时间      | 记录用户每次用信的时间点，用于特征计算的时间锚点             |
| `use_credit_apply_id`     | 用信申请ID      | 用于关联其他表，作为用信记录的唯一键                   |

## PART 2：特征详细解析
### 一、multi_loan_in_loan_order_ 系列（在贷订单行为特征）
#### 1.1 最近1/2笔在贷订单特征
    recentfirst_ 系列
    recentsecond_ 系列
| 特征名                                      | 中文含义                  | 详细计算逻辑                                          |
|------------------------------------------|-----------------------|-------------------------------------------------|
| `creditusageratio`                       | 最近第一笔在贷订单的额度使用率       | 取最近一笔在贷订单（未结清）的creditlimit_use_ratio            |
| `completedsamedayinstalcntavg`           | 最近第1/2笔订单同一天结清期数平均值   | 对rank=1/rank=2订单按结清日期分组统计每天结清期数，再取平均值           |
| `completedsamedayinstalcntmax`           | 最近第1/2笔订单同一天结清期数最大值   | 对rank=1/rank=2订单按结清日期分组统计每天结清期数，取最大值            |
| `maxcontinuecompletedadvanceinstalcnt`   | 最近第1/2笔订单最大连续提前结清期数   | 对rank=1/rank=2订单,通过periods-rn方法识别连续提前结清的期数，取最大值 |
| `maxcontinuecompletedadvanceinstalratio` | 最近第1/2笔订单最大连续提前结清账单比例 | 对rank=1/rank=2订单,最大连续提前结清期数 / 该订单到期账单数          |
| `maxcontinueoverdueinstalcnt`            | 最近第1/2笔订单最大连续逾期期数     | 对rank=1/rank=2订单,通过periods-rn方法识别连续逾期的期数，取最大值   |
| `maxcontinueoverdueinstalratio`          | 最近第1/2笔订单最大连续逾期账单比例   | 对rank=1/rank=2订单,最大连续逾期期数 / 该订单到期账单数            |
| `minusinloanavgcreditusage`              | 最近2笔订单额度使用率与在贷平均的差值   | 最近第二笔订单的额度使用率 - 所有在贷订单平均额度使用率                   |
#### 1.2 续贷全部在贷订单特征（order_asc_rank>1，非首笔在贷订单）
all_ 系列
**提前3/7/15天数相关特征：**
| 特征名 | 中文含义 | 详细计算逻辑 |
|--------|----------|--------------|
| `advanceget3days_maxcontinuecompletedadvanceinstalcnt` | 续贷订单提前3/7/15天最大连续提前结清期数 | 筛选is_tqjq_3d=1/is_tqjq_7d=1/is_tqjq_15d=1/所有 订单，计算最大连续提前结清期数 |
| `advanceget7days_maxcontinuecompletedadvanceinstaloverallcompletedadvanceratio` | 提前3/7/15天最大连续期数占**所有**提前结清订单比例 | 最大连续提前结清期数 / 所有提前结清订单数 |
| `advanceget15days_maxcontinuecompletedadvanceinstalovercompletedorexpiredratio` | 提前3/7/15天最大连续期数占**到期或已结清**订单比例 | 最大连续提前结清期数 / (到期或已结清订单数) |
**通用续贷特征：**
| 特征名                                       | 中文含义              | 详细计算逻辑                     |
|-------------------------------------------|-------------------|----------------------------|
| `maxcontinuecompletedadvanceinstalcnt`    | 续贷订单最大连续提前结清期数    | 所有续贷订单中最大连续提前结清期数          |
| `maxcontinuecompletedadvanceinstalratio`  | 续贷订单最大连续提前结清账单比例  | 最大连续提前结清期数 / 到期或已结清订单数     |
| `maxcontinueoverdueinstalcnt`             | 续贷订单最大连续逾期期数      | 所有续贷订单中最大连续逾期期数            |
| `maxcontinueoverdueinstalratio`           | 续贷订单最大连续逾期账单比例    | 最大连续逾期期数 / 到期订单数           |
| `maxoverdueinstalcntforwithinthreemonths` | 续贷订单3个月内每月最大逾期账单数 | 取近30天、30-60天、60-90天逾期数的最大值 |
### 二、multi_loan_order_info_ 系列（订单综合信息特征）
#### 2.1 额度相关特征
| 特征名                                                          | 中文含义                 | 详细计算逻辑                    |
|--------------------------------------------------------------|----------------------|---------------------------|
| `inloanorders_completeprincipalvslatestremaincreditratio`    | 在贷订单已结清本金占最新剩余额度比例   | sum(在贷且已结清订单的本金) / 最新可用额度 |
| `multiloanorders_completeprincipalvslatestremaincreditratio` | 续借在贷订单已结清本金占最新剩余额度比例 | sum(续借且已结清订单的本金) / 最新可用额度 |

#### 2.2 首笔/最近1笔/最近2笔 订单特征
    furthestsingleorder_ 系列
    latest1singleorder_ 系列
    latest2singleorder_ 系列
| 特征名                                      | 中文含义                           | 详细计算逻辑                        |
|------------------------------------------|--------------------------------|-------------------------------|
| `maxsuccessiveprepaytermvsbillingratio`  | 首笔/最近1笔/最近2笔 订单最大连续提前结清占到期账单比例 | 最大连续提前结清期数 / 到期账单数            |
| `maxsuccessiveprepaytermvsallratio`      | 首笔/最近1笔/最近2笔 订单最大连续提前结清占所有期数比例 | 最大连续提前结清期数 / 总期数              |
| `maxsuccessiveprepaytermcnt`             | 首笔/最近1笔/最近2笔 订单最大连续提前结清期数      | 取最大连续提前结清期数                   |
| `maxsuccessiveoverduetermvsbillingratio` | 首笔/最近1笔/最近2笔 订单最大连续逾期占到期账单比例   | 最大连续逾期期数 / 到期账单数              |
| `maxsuccessiveoverduetermvsallratio`     | 首笔/最近1笔/最近2笔 订单最大连续逾期占所有期数比例   | 最大连续逾期期数 / 总期数                |
| `maxsuccessiveoverduetermcnt`            | 首笔/最近1笔/最近2笔 订单最大连续逾期期数        | 取最大连续逾期期数                     |
| `completesamedaytermscntmax`             | 首笔/最近2笔 同一天结清期数最大值             | 按天统计结清期数取最大值                  |
| `completesamedaytermscntavg`             | 首笔/最近2笔 订单同一天结清期数平均值           | 按天统计结清期数取平均值                  |
| `createdcalccreditgap`                   | 最远一笔订单创建距额度测算间隔                | 用信创建时间 - 授信创建时间（天数差）          |
| `creditusageratio`                       | 最近第一笔订单额度使用率                   | 取最近一笔订单的creditlimit_use_ratio |

#### 2.3 未来账单时间分布特征
    multiloanrangefuture 系列
| 特征名                                         | 中文含义                                   | 详细计算逻辑                              |
|---------------------------------------------|----------------------------------------|-------------------------------------|
| `_futurebillingunclearvsunclearinstalratio` | 未来0-15/15-30/30-60/60-90天未结清账单占所有未结清比例 | 未来15/30/60/90天内到期的未结清账单数 / 所有未结清账单数 |
| `_futurebillingunclearvsclearinstalratio`   | 未来0-15/15-30/30-60/60-90天未结清账单占所有已结清比例 | 未来15/30/60/90天内到期的未结清账单数 / 所有已结清账单数 |


