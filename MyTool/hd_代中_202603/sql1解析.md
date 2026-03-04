# 一、中间表解析
1. target_user（目标用户表）
作用：获取当天发起用信申请的用户样本
use_create_time：用户发起用信申请的时间
cust_no：用户编号
业务意义：这是特征计算的目标人群，所有特征都是基于这些用户和他们的申请时间点来计算的

2. target_user_credit_loan_repay_info（用户完整金融行为表）
作用：整合用户的授信、借款、还款全流程数据
关键字段：
order_asc_rank：订单按创建时间升序排序（1表示最早的一笔）
order_desc_rank：订单按创建时间降序排序（1表示最近的一笔）
credit_create_time：授信申请创建时间
creadit_use_create_time：用信申请创建时间
数据范围限制：
t2.create_time < t1.create_time：只取用信申请时间之前的历史数据
t4.settled_time is null or t4.settled_time > t3.use_create_time：只取未结清的订单
# 二、PART 1 特征解析（MEXICO_MULTI_LOAN_ORDER_INFO）
## 2.1 最远一笔订单特征（Furthest Single Order）
-- 最远一笔订单是否结清（计数）
multi_loan_order_info_furthestsingleorder_completetermcnt
逻辑：order_asc_rank=1 and settled_time is not null and settled_time < use_create_time
含义：最早的那笔订单是否已经结清
业务意义：反映用户最早借款的还款完成情况

-- 最远一笔订单结清比例
multi_loan_order_info_furthestsingleorder_completetermratio
逻辑：结清计数 / 总订单数
含义：如果值为1，说明最早订单已结清；如果为0，说明还未结清

-- 最远一笔订单提前结清计数
multi_loan_order_info_furthestsingleorder_completefutureduetermcnt
逻辑：settled_time < use_create_time and substr(settled_time,1,10) < loan_end_date
含义：最早订单是否在到期日之前就结清了
业务意义：提前还款行为，通常被认为是信用良好的表现

-- 最远一笔订单提前结清天数（最小/平均/最大）
multi_loan_order_info_furthestsingleorder_completeprepaydaysmin
multi_loan_order_info_furthestsingleorder_completeprepaydaysmean
multi_loan_order_info_furthestsingleorder_completeprepaydaysmax
逻辑：datediff(loan_end_date, settled_time)
含义：提前了多少天还款
业务意义：提前天数越多，说明用户资金越充裕

-- 最远一笔订单逾期计数
multi_loan_order_info_furthestsingleorder_overduetermcnt
逻辑：loan_end_date < use_create_time and (settled_time is null or settled_time > loan_end_date)
含义：到期日已过但还未结清的订单
业务意义：这是风险最高的逾期订单

-- 最远一笔订单逾期vs到期订单比例
multi_loan_order_info_furthestsingleorder_overduevsbillingtermratio
逻辑：逾期订单数 / 已到期订单数
含义：到期的订单中有多少是逾期的
业务意义：反映用户的还款意愿和能力

-- 最远一笔订单创建到现在的时间间隔
multi_loan_order_info_furthestsingleorder_creatednowgap
逻辑：datediff(use_create_time, t6.create_time)
含义：从订单创建到本次用信申请过去了多少天
业务意义：反映用户历史借款的久远程度

-- 最远一笔订单创建时间时段特征
multi_loan_order_info_furthestsingleorder_creatednoon
multi_loan_order_info_furthestsingleorder_creatednight
multi_loan_order_info_furthestsingleorder_createdmorning
multi_loan_order_info_furthestsingleorder_createdevening
multi_loan_order_info_furthestsingleorder_createdafternoon
逻辑：根据创建时间的小时数分类
中午：11-13点
夜晚：23-04点
早晨：05-10点
傍晚：18-22点
下午：14-17点
业务意义：用户借款的时间偏好，可能与用户类型相关

## 2.2 最近订单特征（Latest 1/2 Single Order）
-- 最近订单的授信-借款时间间隔
multi_loan_order_info_latest1singleorder_createdcalccreditgap
逻辑：datediff(t6.create_time, t7.create_time)
含义：从授信申请通过到实际用信借款的时间差
业务意义：时间差短说明用户用款需求急迫，时间长可能说明用户谨慎或资金不急需

-- 最近订单结清比例
multi_loan_order_info_latest1singleorder_completetermratio
逻辑：结清订单数 / 分期期数
含义：已还款期数占总期数的比例
业务意义：反映最近一笔订单的还款进度

最近第二笔订单特征 与第一笔类似，但针对倒数第二笔订单：
multi_loan_order_info_latest2singleorder_completetermcnt：结清期数
multi_loan_order_info_latest2singleorder_overduetermcnt：逾期期数
业务意义：通过对比最近两笔订单的行为，可以观察用户还款行为的稳定性或变化趋势

## 2.3 时间窗口特征
未来订单预测
-- 未来0-90天到期订单
multi_loan_order_info_multiloanrangefuture0dto90d_futurebillingunclearinstalcnt
逻辑：loan_end_date between use_create_time and use_create_time+90
含义：未来90天内将要到期的订单数
业务意义：预测用户近期的还款压力

-- 未来90-180天到期订单
multi_loan_order_info_multiloanrangefuture90dto180d_futurebillingunclearinstalcnt
逻辑：loan_end_date between use_create_time+90 and use_create_time+180
含义：未来90-180天内将要到期的订单数
业务意义：预测用户中期的还款压力

历史行为统计
-- 过去30天放款订单数
multi_loan_order_info_multiloan30dstat_payoutordercnt
逻辑：create_time(还款计划表) between use_create_time-30 and use_create_time
含义：最近30天内新发放的借款订单数
业务意义：反映用户近期的借款活跃度

-- 过去30天续借订单数
multi_loan_order_info_multiloan30dstat_payoutmultiloanordercnt
逻辑：同上，但加上order_asc_rank>1（非首次借款）
含义：最近30天内的续借行为次数
业务意义：续借可能意味着用户对额度依赖度高

-- 过去90天结清订单数
multi_loan_order_info_multiloannoloanclear90dstat_clearordercnt
逻辑：settled_time between use_create_time-90 and use_create_time
含义：最近90天内结清的订单数
业务意义：反映用户近期的还款能力

## 2.4 在贷/续借订单特征
在贷订单统计
-- 在贷订单中逾期期数
multi_loan_order_info_inloanorders_overduetermcnt
逻辑：(t4.settled_time is null or t4.settled_time>t3.use_create_time) and loan_end_date < use_create_time and (settled_time is null or settled_time> loan_end_date)
含义：当前仍在贷且已逾期的订单期数
业务意义：这是最需要关注的高风险订单

-- 在贷订单结清期数
multi_loan_order_info_inloanorders_completetermcnt
逻辑：(t4.settled_time is null or t4.settled_time>t3.use_create_time) and settled_time < use_create_time
含义：在贷订单中已经结清的期数
业务意义：反映在贷订单的还款进度

-- 在贷订单结清本金总额
multi_loan_order_info_inloanorders_completeprincipal
逻辑：sum(repaid_principal)
含义：在贷订单中已还本金总额
业务意义：反映用户的还款能力

授信-借款时间间隔统计
-- 授信-借款时间间隔的标准差/最小/平均/最大
multi_loan_order_info_inloanorders_calccreditgapstd
multi_loan_order_info_inloanorders_calccreditgapmin
multi_loan_order_info_inloanorders_calccreditgapmean
multi_loan_order_info_inloanorders_calccreditgapmax
逻辑：datediff(create_time, t7.create_time)
含义：从授信到实际用款的时间差的统计指标
业务意义：
标准差大：用户用款行为不稳定
平均值大：用户倾向于获得授信后很久才用款
最小值小：用户有过紧急用款的情况

续借订单特征
-- 续借订单逾期vs结清比例
multi_loan_order_info_multiloanorders_overduevscompletetermratio
逻辑：续借订单逾期数 / 续借订单结清数
含义：续借行为中，逾期和结清的比例关系
业务意义：如果这个比例高，说明续借用户风险较高

-- 续借订单本金标准差
multi_loan_order_info_multiloanorders_orderprincipalstd
逻辑：stddev(real_loan_amt)
含义：续借订单借款金额的波动性
业务意义：金额波动大可能说明用户资金需求不稳定

# 三、PART 2 特征解析（MEXICO_MULTI_LOAN_IN_LOAN_ORDER）
## 3.1 最远订单在贷特征
-- 最远订单结清期数
multi_loan_in_loan_order_furthest_completedinstalcnt
逻辑：order_asc_rank=1 and settled_time is not null and settled_time < use_create_time
含义：最早订单中已结清的期数
业务意义：反映用户最早借款的还款完整性

-- 最远订单未到期结清金额
multi_loan_in_loan_order_furthest_completednotdueloanamount
逻辑：sum(repaid_principal) where 提前结清
含义：最早订单中提前结清的本金总额
业务意义：提前还款金额大，说明用户资金实力强

## 3.2 最近订单在贷特征
提前还款天数统计
-- 最近订单提前还款天数平均/最大/标准差
multi_loan_in_loan_order_recentfirst_completedadvanceinstaldaysavg
multi_loan_in_loan_order_recentfirst_completedadvanceinstaldaysmax
multi_loan_in_loan_order_recentfirst_completedadvanceinstaldaysstd
逻辑：datediff(loan_end_date, settled_time) where 提前结清
含义：最近订单中提前还款的提前天数统计
业务意义：
平均值大：用户习惯性提前很多天还款
标准差小：提前还款行为很稳定
最大值大：有过大幅提前还款记录

时间段分布特征
-- 最近订单创建时间时段（one-hot编码）
multi_loan_in_loan_order_recentfirst_createdtimeperiodonehotvo_noon
multi_loan_in_loan_order_recentfirst_createdtimeperiodonehotvo_night
...
逻辑：根据创建小时数设置0/1标志
含义：用户在哪个时间段创建订单
业务意义：可用于构建用户画像，不同时间段的用户可能有不同风险特征

逾期特征
-- 最近订单逾期期数
multi_loan_in_loan_order_recentfirst_overdueinstalcnt
逻辑：loan_end_date < use_create_time and (settled_time is null or settled_time > loan_end_date)
含义：最近订单中逾期未还的期数
业务意义：如果最近订单有逾期，说明用户当前风险较高

-- 最近订单逾期比例
multi_loan_in_loan_order_recentfirst_overdueinstalratio
逻辑：逾期期数 / 总期数
含义：逾期期数占总期数的比例
业务意义：反映最近订单的风险程度

## 3.3 订单间隔特征
-- 最近订单创建时间与用信时间间隔
multi_loan_in_loan_order_recentfirst_createdordertimegap
逻辑：datediff(use_create_time, creadit_use_create_time)
含义：从最近订单创建到本次用信申请的天数
业务意义：时间间隔短可能说明用户有连续的借款需求

-- 最近订单首次结清时间间隔
multi_loan_in_loan_order_recentfirst_firstcompletedinstalgap
逻辑：datediff(use_create_time, first_settled_time)
含义：从最近订单首次结清到本次用信申请的天数
业务意义：结清后很快又申请，可能说明用户对信贷依赖度高

## 3.4 放款天数特征
-- 最近订单放款天数
multi_loan_in_loan_order_recentfirst_payoutdays
逻辑：datediff(loan_end_date, loan_start_date) + 1
含义：借款期限（天）
业务意义：用户选择的借款期限，短期限可能说明资金周转需求
