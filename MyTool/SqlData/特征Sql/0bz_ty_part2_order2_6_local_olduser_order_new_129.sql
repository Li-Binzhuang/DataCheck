-- name part2_sql实际特征_国内
-- type StarRocks
-- author zhanglifeng703@hellobike.com
-- create time 2026-01-07 03:43:53
-- desc 
-- ============================================================================
-- 贷中特征衍生完整SQL - 共129个特征
-- 策略：使用最少中间表，尽量减少重复计算
--   1. base_loan_data: 期次粒度底表（已有）
--   2. order_level_data: 订单粒度汇总表
--   3. order_ranked: 订单排序表（含连续订单数计算）
-- ============================================================================

-- ============================================================================
-- 中间表1：期次粒度底表 base_loan_data (原始SQL)
-- ============================================================================
WITH base_loan_data AS (
    SELECT m0.cust_no                                                           -- 客户号
          ,m0.use_credit_apply_id                                               -- 用信申请id
          ,m0.use_create_time                                                   -- 用信申请创建时间
          ,m5.create_time                                                       -- 用信申请落表时间（历史订单）
          ,m5.rp_create_time                                                    -- 还款计划落表时间
         -- ,m0.use_credit_apply_date                                             -- 用信申请创建时间年月日
         -- ,m0.use_amount                                                        -- 用信金额
         -- ,m0.use_period                                                        -- 用信期数
          ,m5.loaninfo_create_time 
          ,m5.loan_period
          ,m5.real_loan_amt
          ,m5.id                                                                -- 还款计划表id
          ,m5.loan_no 
          ,m5.periods                                                           -- 还款计划表中当前账单是第几期
          ,datediff(to_date(m0.use_create_time), to_date(m5.create_time)) AS applyinterval 
          -- 用户还款时间（保留原始值，不置空）
          ,m5.settled_time
          ,m5.loan_day 
          ,m5.loan_end_date                                                     -- 应还日期
          -- 逾期天数计算逻辑：
          -- 1. settled_time <= use_create_time: overduedays = settled_time - loan_end_date
          -- 2. settled_time > use_create_time 或 null，且 use_create_time > loan_end_date: overduedays = date(use_create_time) - loan_end_date
          -- 3. settled_time > use_create_time 或 null，且 use_create_time <= loan_end_date: overduedays = null（未到期）
          ,CASE WHEN m5.settled_time <= m0.use_create_time
                THEN datediff(to_date(m5.settled_time), to_date(m5.loan_end_date))
                WHEN (m5.settled_time IS NULL OR m5.settled_time > m0.use_create_time) 
                     AND to_date(m0.use_create_time) > m5.loan_end_date
                THEN datediff(to_date(m0.use_create_time), to_date(m5.loan_end_date)) 
                ELSE NULL 
           END AS overduedays
          -- 逾期天数（仅已结清且在申请时间之前的）
          ,IF(m5.settled_time <= m0.use_create_time,
              datediff(to_date(m5.settled_time), to_date(m5.loan_end_date)), NULL) AS overduedays_pay
          -- 提前还款天数（仅 settled_time <= use_create_time 且 settled_time < loan_end_date）
          ,IF(m5.settled_time <= m0.use_create_time AND to_date(m5.settled_time) < m5.loan_end_date,
              abs(datediff(to_date(m5.settled_time), to_date(m5.loan_end_date))), NULL) AS prepaydays
          -- 期次是否有效：已结清(settled_time <= use_create_time) 或 已到期(loan_end_date < use_create_time)
          ,CASE WHEN m5.settled_time <= m0.use_create_time
                  OR m5.loan_end_date < to_date(m0.use_create_time)
                THEN 1 ELSE 0 END AS is_valid_period
          -- 订单排名（按历史订单创建时间倒序，rank=1为最近一笔）
          ,dense_rank() OVER (PARTITION BY m0.cust_no, m0.use_credit_apply_id ORDER BY m5.create_time DESC) AS rank
    FROM (
        SELECT cust_no, ua.id as use_credit_apply_id, create_time as use_create_time
        FROM fintech.dwd_rsk_approve_use_credit_apply_rt ua
        
    ) AS m0
    INNER JOIN (
        SELECT m1.cust_no
              ,m4.id
              ,m3.loan_no
              ,m4.periods
              ,m1.create_time                                                   -- 用信申请落表时间
              ,m3.create_time AS loaninfo_create_time
              ,m3.loan_period                                                   -- 期数
              ,m3.loan_day                                                      -- 天数
              ,m3.real_loan_amt                                                 -- 本金
              ,m4.create_time AS rp_create_time                                 -- 还款计划生成时间
              ,m4.settled_time
              ,m4.loan_end_date
        FROM (SELECT * FROM fintech.dwd_rsk_approve_use_credit_apply_rt) AS m1
        INNER JOIN (SELECT * FROM fintech.dwd_rsk_asset_loan_apply_rt) AS m2
            ON m1.asset_id = m2.seq_no
        INNER JOIN (SELECT * FROM fintech.dwd_trd_ast_loan_info_rt 
                    WHERE loan_status <> 4 AND (optype <> 'DELETE' OR optype IS NULL)) AS m3
            ON m2.loan_apply_no = m3.loan_apply_no
        INNER JOIN (SELECT * FROM fintech.dwd_trd_ast_repay_plan_rt 
                    WHERE repay_plan_status <> 4 AND (optype <> 'DELETE' OR optype IS NULL)) AS m4
            ON m3.loan_no = m4.loan_no
    ) AS m5
        ON m0.cust_no = m5.cust_no
    WHERE --m0.use_create_time > m5.create_time          -- 当前申请时间 > 历史订单的用信申请落表时间
        --AND m0.use_create_time > m5.loaninfo_create_time -- 当前申请时间 > 历史订单的贷款信息创建时间
         m0.use_create_time > m5.rp_create_time       -- 当前申请时间 > 历史订单的还款计划落表时间
      AND m5.cust_no IN (SELECT DISTINCT cust_no FROM fintech.dwd_trd_ast_repay_plan_rt WHERE create_time > '2025-10-01')
)

-- ============================================================================
-- 中间表2：订单粒度汇总表 order_level_data
-- 将期次粒度聚合到订单粒度，计算每笔订单的汇总指标
-- 支持最多8期贷款
-- ============================================================================
, order_level_data AS (
    SELECT 
        cust_no
       ,use_credit_apply_id
       ,use_create_time
       --,use_credit_apply_date
       --,use_amount
       --,use_period
       ,loan_no
       ,create_time                                                             -- 订单创建时间
       ,loaninfo_create_time
       ,loan_period
       ,real_loan_amt
       
       -- 订单排名（按订单维度去重后的rank，取每个loan_no的最小rank）
       ,MIN(rank) AS order_rank
       
       -- ========== 逾期相关（仅计算有效期次：is_valid_period=1）==========
       ,SUM(CASE WHEN is_valid_period = 1 AND overduedays > 0 THEN overduedays ELSE 0 END) AS sum_overduedays  -- 总逾期天数（只累加>0的）【order3和order4修改】
       ,MAX(CASE WHEN is_valid_period = 1 THEN overduedays END) AS max_overduedays                      -- 最大逾期天数
       ,ROUND(AVG(CASE WHEN is_valid_period = 1 AND overduedays > 0 THEN overduedays END), 6) AS avg_overduedays  -- 平均逾期天数
       ,MIN(CASE WHEN is_valid_period = 1 AND overduedays > 0 THEN overduedays END) AS min_overduedays_positive  -- 最小逾期天数(>0)
       ,SUM(CASE WHEN is_valid_period = 1 AND overduedays > 0 THEN 1 ELSE 0 END) AS overdue_instalments -- 有逾期的期次数
       ,IF(SUM(CASE WHEN is_valid_period = 1 AND overduedays > 0 THEN 1 ELSE 0 END) > 0, 1, 0) AS has_overdue  -- 是否有逾期订单
       
       -- ========== 提前还款相关（仅计算有效期次：is_valid_period=1）==========
       ,SUM(CASE WHEN is_valid_period = 1 THEN COALESCE(prepaydays, 0) ELSE 0 END) AS sum_prepaydays    -- 总提前还款天数
       ,MAX(CASE WHEN is_valid_period = 1 THEN prepaydays END) AS max_prepaydays                        -- 最大提前还款天数
       ,ROUND(AVG(CASE WHEN is_valid_period = 1 AND prepaydays > 0 THEN prepaydays END), 6) AS avg_prepaydays  -- 平均提前还款天数
       ,MIN(CASE WHEN is_valid_period = 1 AND prepaydays > 0 THEN prepaydays END) AS min_prepaydays_positive  -- 最小提前还款天数(>0)
       ,SUM(CASE WHEN is_valid_period = 1 AND prepaydays > 0 THEN 1 ELSE 0 END) AS prepay_instalments   -- 有提前还款的期次数
       ,IF(SUM(CASE WHEN is_valid_period = 1 AND prepaydays > 0 THEN 1 ELSE 0 END) > 0, 1, 0) AS has_prepay  -- 是否有提前还款订单
       
       -- ========== 时间相关 ==========
       ,HOUR(create_time) AS borrow_hour                                        -- 借款时刻（0-23）
       ,DAYOFWEEK(create_time) AS day_of_week                                   -- 周几（1=周日，7=周六）
       ,IF(DAYOFWEEK(create_time) IN (1), 1, 0) AS is_weekend                -- 是否周末
       ,IF(HOUR(create_time) >= 23 OR HOUR(create_time) < 6, 1, 0) AS is_23to5  -- 23点-5点
       ,IF(HOUR(create_time) >= 6 AND HOUR(create_time) < 11, 1, 0) AS is_6to10 -- 6点-11点
       ,IF(HOUR(create_time) >= 11 AND HOUR(create_time) < 15, 1, 0) AS is_11to14 -- 11点-15点
       ,IF(HOUR(create_time) >= 15 AND HOUR(create_time) < 18, 1, 0) AS is_15to17 -- 15点-18点
       ,IF(HOUR(create_time) >= 18 AND HOUR(create_time) < 23, 1, 0) AS is_18to22 -- 18点-23点
       
       -- ========== 通用分期统计（仅计算有效期次）==========
       -- 首次逾期期数
       ,MIN(CASE WHEN is_valid_period = 1 AND overduedays > 0 THEN periods END) AS first_overdue_period
       
       -- ========== 分期明细相关（仅计算有效期次：is_valid_period=1）- 支持1-8期 ==========
       -- 各期逾期天数 (1-8期)
       ,MAX(CASE WHEN is_valid_period = 1 AND periods = 1 THEN overduedays END) AS period1_overduedays
       ,MAX(CASE WHEN is_valid_period = 1 AND periods = 2 THEN overduedays END) AS period2_overduedays
       ,MAX(CASE WHEN is_valid_period = 1 AND periods = 3 THEN overduedays END) AS period3_overduedays
       ,MAX(CASE WHEN is_valid_period = 1 AND periods = 4 THEN overduedays END) AS period4_overduedays
       ,MAX(CASE WHEN is_valid_period = 1 AND periods = 5 THEN overduedays END) AS period5_overduedays
       ,MAX(CASE WHEN is_valid_period = 1 AND periods = 6 THEN overduedays END) AS period6_overduedays
       ,MAX(CASE WHEN is_valid_period = 1 AND periods = 7 THEN overduedays END) AS period7_overduedays
       ,MAX(CASE WHEN is_valid_period = 1 AND periods = 8 THEN overduedays END) AS period8_overduedays
       -- 各期是否逾期 (1-8期)
       ,MAX(CASE WHEN is_valid_period = 1 AND periods = 1 AND overduedays > 0 THEN 1 ELSE 0 END) AS period1_overdue
       ,MAX(CASE WHEN is_valid_period = 1 AND periods = 2 AND overduedays > 0 THEN 1 ELSE 0 END) AS period2_overdue
       ,MAX(CASE WHEN is_valid_period = 1 AND periods = 3 AND overduedays > 0 THEN 1 ELSE 0 END) AS period3_overdue
       ,MAX(CASE WHEN is_valid_period = 1 AND periods = 4 AND overduedays > 0 THEN 1 ELSE 0 END) AS period4_overdue
       ,MAX(CASE WHEN is_valid_period = 1 AND periods = 5 AND overduedays > 0 THEN 1 ELSE 0 END) AS period5_overdue
       ,MAX(CASE WHEN is_valid_period = 1 AND periods = 6 AND overduedays > 0 THEN 1 ELSE 0 END) AS period6_overdue
       ,MAX(CASE WHEN is_valid_period = 1 AND periods = 7 AND overduedays > 0 THEN 1 ELSE 0 END) AS period7_overdue
       ,MAX(CASE WHEN is_valid_period = 1 AND periods = 8 AND overduedays > 0 THEN 1 ELSE 0 END) AS period8_overdue
       -- 各期结清日期（仅 settled_time <= use_create_time 的期次）(1-8期)
       ,MAX(CASE WHEN settled_time <= use_create_time AND periods = 1 THEN to_date(settled_time) END) AS period1_settled_date
       ,MAX(CASE WHEN settled_time <= use_create_time AND periods = 2 THEN to_date(settled_time) END) AS period2_settled_date
       ,MAX(CASE WHEN settled_time <= use_create_time AND periods = 3 THEN to_date(settled_time) END) AS period3_settled_date
       ,MAX(CASE WHEN settled_time <= use_create_time AND periods = 4 THEN to_date(settled_time) END) AS period4_settled_date
       ,MAX(CASE WHEN settled_time <= use_create_time AND periods = 5 THEN to_date(settled_time) END) AS period5_settled_date
       ,MAX(CASE WHEN settled_time <= use_create_time AND periods = 6 THEN to_date(settled_time) END) AS period6_settled_date
       ,MAX(CASE WHEN settled_time <= use_create_time AND periods = 7 THEN to_date(settled_time) END) AS period7_settled_date
       ,MAX(CASE WHEN settled_time <= use_create_time AND periods = 8 THEN to_date(settled_time) END) AS period8_settled_date
       -- 各期提前还款天数 (1-8期)
       ,MAX(CASE WHEN is_valid_period = 1 AND periods = 1 THEN prepaydays END) AS period1_prepaydays
       ,MAX(CASE WHEN is_valid_period = 1 AND periods = 2 THEN prepaydays END) AS period2_prepaydays
       ,MAX(CASE WHEN is_valid_period = 1 AND periods = 3 THEN prepaydays END) AS period3_prepaydays
       ,MAX(CASE WHEN is_valid_period = 1 AND periods = 4 THEN prepaydays END) AS period4_prepaydays
       ,MAX(CASE WHEN is_valid_period = 1 AND periods = 5 THEN prepaydays END) AS period5_prepaydays
       ,MAX(CASE WHEN is_valid_period = 1 AND periods = 6 THEN prepaydays END) AS period6_prepaydays
       ,MAX(CASE WHEN is_valid_period = 1 AND periods = 7 THEN prepaydays END) AS period7_prepaydays
       ,MAX(CASE WHEN is_valid_period = 1 AND periods = 8 THEN prepaydays END) AS period8_prepaydays
       -- 各期是否提前还款 (1-8期)
       ,MAX(CASE WHEN is_valid_period = 1 AND periods = 1 AND prepaydays > 0 THEN 1 ELSE 0 END) AS period1_prepay
       ,MAX(CASE WHEN is_valid_period = 1 AND periods = 2 AND prepaydays > 0 THEN 1 ELSE 0 END) AS period2_prepay
       ,MAX(CASE WHEN is_valid_period = 1 AND periods = 3 AND prepaydays > 0 THEN 1 ELSE 0 END) AS period3_prepay
       ,MAX(CASE WHEN is_valid_period = 1 AND periods = 4 AND prepaydays > 0 THEN 1 ELSE 0 END) AS period4_prepay
       ,MAX(CASE WHEN is_valid_period = 1 AND periods = 5 AND prepaydays > 0 THEN 1 ELSE 0 END) AS period5_prepay
       ,MAX(CASE WHEN is_valid_period = 1 AND periods = 6 AND prepaydays > 0 THEN 1 ELSE 0 END) AS period6_prepay
       ,MAX(CASE WHEN is_valid_period = 1 AND periods = 7 AND prepaydays > 0 THEN 1 ELSE 0 END) AS period7_prepay
       ,MAX(CASE WHEN is_valid_period = 1 AND periods = 8 AND prepaydays > 0 THEN 1 ELSE 0 END) AS period8_prepay
       
    FROM base_loan_data
    GROUP BY cust_no, use_credit_apply_id, use_create_time,   
             loan_no, create_time, loaninfo_create_time, loan_period, real_loan_amt
)

-- ============================================================================
-- 中间表3：订单排名 + 连续订单数计算
-- 使用窗口函数计算连续逾期/提前还款订单数
-- ============================================================================
, order_ranked AS (
    SELECT 
        *
       ,DENSE_RANK() OVER (PARTITION BY cust_no, use_credit_apply_id ORDER BY create_time DESC) AS order_seq
       -- 累计非逾期订单数（从order_seq=1开始累计）
       ,SUM(1 - has_overdue) OVER (PARTITION BY cust_no, use_credit_apply_id ORDER BY create_time DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cum_no_overdue
       -- 累计非提前还款订单数（从order_seq=1开始累计）
       ,SUM(1 - has_prepay) OVER (PARTITION BY cust_no, use_credit_apply_id ORDER BY create_time DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cum_no_prepay
    FROM order_level_data
)

-- ============================================================================
-- 最终特征衍生 - 共129个特征
-- ============================================================================
select * from (
SELECT 
    use_credit_apply_id
   ,use_create_time
   ,cust_no
   
   -- =========================================================================
   -- 零、前第2笔订单特征 (last2orderriskvo) - 28个 (索引0-27)
   -- =========================================================================
   -- 0. 当前借款小时数减最近两笔借款小时均值
   ,ROUND(HOUR(use_create_time) - AVG(CASE WHEN order_seq IN (1, 2) THEN borrow_hour END), 6)
       AS local_olduser_order_last2orderriskvo_ccurrenthourminuslatest2ordersavgborrowhour_v2
   
   -- 1. 最近两笔深夜下单（23-5点）笔数
   ,SUM(CASE WHEN order_seq IN (1, 2) THEN is_23to5 ELSE 0 END)
       AS local_olduser_order_last2orderriskvo_countcreationtimeifwithin23pmto5aminlatest2orders_v2
   
   -- 2. 最近两笔借款间隔平均（天）
   ,DATEDIFF(MAX(CASE WHEN order_seq = 1 THEN to_date(create_time) END),
             MAX(CASE WHEN order_seq = 2 THEN to_date(create_time) END))
       AS local_olduser_order_last2orderriskvo_creationtimeaverageintervalinlatest2orders_v2
   
   -- 3. 前第2笔借款时刻（0-23）
   ,MAX(CASE WHEN order_seq = 2 THEN borrow_hour END)
       AS local_olduser_order_last2orderriskvo_creationtimeinhour_v2
   
   -- 4. 最近两笔借款时刻（小时）均值
   ,ROUND(AVG(CASE WHEN order_seq IN (1, 2) THEN borrow_hour END), 6)
       AS local_olduser_order_last2orderriskvo_creationtimeinhouravginlatest2orders_v2
   
   -- 5. 前第2笔平均逾期天数（取绝对值）
   -- 前第2笔平均逾期天数（匹配 Java BigDecimal HALF_UP 逻辑）
   ,CASE WHEN MAX(CASE WHEN order_seq = 2 THEN overdue_instalments END) > 0
         THEN CAST(ROUND(
                CAST(MAX(CASE WHEN order_seq = 2 THEN sum_overduedays END) AS DECIMAL(38,10)) 
                / CAST(MAX(CASE WHEN order_seq = 2 THEN overdue_instalments END) AS DECIMAL(38,10))
              , 6) AS DECIMAL(18,6))
         ELSE NULL END
       AS local_olduser_order_last2orderriskvo_instalmentavgoverduedays_v2
   
   -- 6. 前第2笔平均提前还款天数（匹配 Java BigDecimal HALF_UP 逻辑）
   ,CASE WHEN MAX(CASE WHEN order_seq = 2 THEN prepay_instalments END) > 0
         THEN CAST(ROUND(
                CAST(MAX(CASE WHEN order_seq = 2 THEN sum_prepaydays END) AS DECIMAL(38,10)) 
                / CAST(MAX(CASE WHEN order_seq = 2 THEN prepay_instalments END) AS DECIMAL(38,10))
              , 6) AS DECIMAL(18,6))
         ELSE NULL END
       AS local_olduser_order_last2orderriskvo_instalmentavgprepaymentdays_v2
   
   -- 7. 最近两笔平均（单期）提前还款天数 = 总提前结清天数 / 总提前结清期数（匹配 Java BigDecimal HALF_UP 逻辑）
   ,CASE WHEN SUM(CASE WHEN order_seq IN (1, 2) THEN prepay_instalments END) > 0
         THEN CAST(ROUND(
                CAST(SUM(CASE WHEN order_seq IN (1, 2) THEN sum_prepaydays END) AS DECIMAL(38,10)) 
                / CAST(SUM(CASE WHEN order_seq IN (1, 2) THEN prepay_instalments END) AS DECIMAL(38,10))
              , 6) AS DECIMAL(18,6))
         ELSE NULL END
       AS local_olduser_order_last2orderriskvo_instalmentavgprepaymentdaysinlatest2orders_v2
   
   -- 8. 前第2笔最大逾期天数（负数返回0）
   ,GREATEST(COALESCE(MAX(CASE WHEN order_seq = 2 THEN max_overduedays END), 0), 0)
       AS local_olduser_order_last2orderriskvo_instalmentmaxoverduedays_v2
   
   -- 9. 前第2笔最大提前还款天数
   ,MAX(CASE WHEN order_seq = 2 THEN max_prepaydays END)
       AS local_olduser_order_last2orderriskvo_instalmentmaxprepaymentdays_v2
   
   -- 10. 前第2笔总逾期天数（负数返回0）
   ,GREATEST(COALESCE(MAX(CASE WHEN order_seq = 2 THEN sum_overduedays END), 0), 0)
       AS local_olduser_order_last2orderriskvo_instalmentsumoverduedays_v2
   
   -- 11. 前第2笔总提前还款天数
   ,COALESCE(MAX(CASE WHEN order_seq = 2 THEN sum_prepaydays END), 0)
       AS local_olduser_order_last2orderriskvo_instalmentsumprepaymentdays_v2
   
   -- 12. 最近两笔最大（单期）逾期天数（负数返回0）
   ,GREATEST(COALESCE(MAX(CASE WHEN order_seq IN (1, 2) THEN max_overduedays END), 0), 0)
       AS local_olduser_order_last2orderriskvo_instalmentmaxoverduedaysinlatest2orders_v2
   
   -- 13. 最近两笔最大（单期）提前还款天数
   ,MAX(CASE WHEN order_seq IN (1, 2) THEN max_prepaydays END)
       AS local_olduser_order_last2orderriskvo_instalmentmaxprepaymentdaysinlatest2orders_v2
   
   -- 14. 最近两笔最小（单期）逾期天数（>0最小，取绝对值）
   ,ABS(MIN(CASE WHEN order_seq IN (1, 2) THEN min_overduedays_positive END))
       AS local_olduser_order_last2orderriskvo_instalmentminoverduedaysinlatest2orders_v2
   
   -- 15. 最近两笔最小（单期）提前还款天数（>0最小）
   ,MIN(CASE WHEN order_seq IN (1, 2) THEN min_prepaydays_positive END)
       AS local_olduser_order_last2orderriskvo_instalmentminprepaymentdaysinlatest2orders_v2
   
   -- 16. 最近两笔逾期天数总和（负数返回0）
   ,GREATEST(COALESCE(SUM(CASE WHEN order_seq IN (1, 2) THEN sum_overduedays END), 0), 0)
       AS local_olduser_order_last2orderriskvo_sumoverduedaysinlatest2orders_v2
   
   -- 17. 最近两笔提前还款天数总和
   ,COALESCE(SUM(CASE WHEN order_seq IN (1, 2) THEN sum_prepaydays END), 0)
       AS local_olduser_order_last2orderriskvo_sumprepaymentdaysinlatest2orders_v2
   
   -- 18. 最近两笔有逾期的期次数
   ,COALESCE(SUM(CASE WHEN order_seq IN (1, 2) THEN overdue_instalments END), 0)
       AS local_olduser_order_last2orderriskvo_overdueinstalmentsinlatest2orders_v2
   
   -- 19. 最近两笔有提前还款的期次数
   ,COALESCE(SUM(CASE WHEN order_seq IN (1, 2) THEN prepay_instalments END), 0)
       AS local_olduser_order_last2orderriskvo_prepaymentinstalmentsinlatest2orders_v2
   
   -- 20. 最近两笔有逾期的订单笔数
   ,COALESCE(SUM(CASE WHEN order_seq IN (1, 2) THEN has_overdue END), 0)
       AS local_olduser_order_last2orderriskvo_overdueordersinlatest2orders_v2
   
   -- 21. 最近两笔有提前还款的订单笔数
   ,COALESCE(SUM(CASE WHEN order_seq IN (1, 2) THEN has_prepay END), 0)
       AS local_olduser_order_last2orderriskvo_prepaymentordersinlatest2orders_v2
   
   -- 22. 前第2笔是否周末下单
   ,MAX(CASE WHEN order_seq = 2 THEN is_weekend END)
       AS local_olduser_order_last2orderriskvo_iscreationtimeonweekend_v2
   
   -- 23. 前第2笔是否11点后15点前下单
   ,MAX(CASE WHEN order_seq = 2 THEN is_11to14 END)
       AS local_olduser_order_last2orderriskvo_iscreationtimewithin11amto14pm_v2
   
   -- 24. 前第2笔是否15点后18点前下单
   ,MAX(CASE WHEN order_seq = 2 THEN is_15to17 END)
       AS local_olduser_order_last2orderriskvo_iscreationtimewithin15pmto17pm_v2
   
   -- 25. 前第2笔是否18点后23点前下单
   ,MAX(CASE WHEN order_seq = 2 THEN is_18to22 END)
       AS local_olduser_order_last2orderriskvo_iscreationtimewithin18pmto22pm_v2
   
   -- 26. 前第2笔是否23点后5点前下单
   ,MAX(CASE WHEN order_seq = 2 THEN is_23to5 END)
       AS local_olduser_order_last2orderriskvo_iscreationtimewithin23pmto5am_v2
   
   -- 27. 前第2笔是否6点后11点前下单
   ,MAX(CASE WHEN order_seq = 2 THEN is_6to10 END)
       AS local_olduser_order_last2orderriskvo_iscreationtimewithin6amto10am_v2
   
   -- =========================================================================
   -- 一、前第3笔订单特征 (last3orderriskvo) - 30个 (索引28-57)
   -- =========================================================================
   -- 28. 当前下单小时数 − 最近3笔订单借款小时均值
   -- 当前小时 - last3HoursAvg，结果再 ROUND 6 位（匹配 Java BigDecimal HALF_UP 逻辑）
   ,CAST(ROUND(
       CAST(HOUR(use_create_time) AS DECIMAL(18,6)) 
       - CAST(ROUND(
           CAST(SUM(CASE WHEN order_seq IN (1, 2, 3) THEN borrow_hour END) AS DECIMAL(38,10)) 
           / CAST(NULLIF(SUM(CASE WHEN order_seq IN (1, 2, 3) THEN 1 END), 0) AS DECIMAL(38,10))
         , 6) AS DECIMAL(18,6))
     , 6) AS DECIMAL(18,6))
       AS local_olduser_order_last3orderriskvo_currenthourminuslatest3ordersavgborrowhour_v2
   
   -- 29. 最近3笔订单中，借款时间在23点–5点的订单数
   ,SUM(CASE WHEN order_seq IN (1, 2, 3) THEN is_23to5 ELSE 0 END)
       AS local_olduser_order_last3orderriskvo_countcreationtimeifwithin23pmto5aminlatest3orders_v2
   
   -- 30. 最近3笔订单的借款时间间隔均值（天）
   ,ROUND((DATEDIFF(MAX(CASE WHEN order_seq = 1 THEN to_date(create_time) END),
              MAX(CASE WHEN order_seq = 3 THEN to_date(create_time) END))) / 2.0, 6)
       AS local_olduser_order_last3orderriskvo_creationtimeaverageintervalinlatest3orders_v2
   
   -- 31. 前第3笔订单的借款时刻（0–23）
   ,MAX(CASE WHEN order_seq = 3 THEN borrow_hour END)
       AS local_olduser_order_last3orderriskvo_creationtimeinhour_v2
   
   -- 32. 最近3笔订单借款小时的均值（匹配 Java BigDecimal HALF_UP 逻辑）
   ,CAST(ROUND(
       CAST(SUM(CASE WHEN order_seq IN (1, 2, 3) THEN borrow_hour END) AS DECIMAL(38,10)) 
       / CAST(NULLIF(SUM(CASE WHEN order_seq IN (1, 2, 3) THEN 1 END), 0) AS DECIMAL(38,10))
     , 6) AS DECIMAL(18,6))
       AS local_olduser_order_last3orderriskvo_creationtimeinhouravginlatest3orders_v2
   
   -- 33. 前第3笔订单分期的平均逾期天数（取绝对值）
   -- 前第3笔订单分期的平均逾期天数（匹配 Java BigDecimal HALF_UP 逻辑）
   ,CASE WHEN MAX(CASE WHEN order_seq = 3 THEN overdue_instalments END) > 0
         THEN CAST(ROUND(
                CAST(MAX(CASE WHEN order_seq = 3 THEN sum_overduedays END) AS DECIMAL(38,10)) 
                / CAST(MAX(CASE WHEN order_seq = 3 THEN overdue_instalments END) AS DECIMAL(38,10))
              , 6) AS DECIMAL(18,6))
         ELSE NULL END
       AS local_olduser_order_last3orderriskvo_instalmentavgoverduedays_v2
   
   -- 34. 前第3笔订单分期的平均提前还款天数（匹配 Java BigDecimal HALF_UP 逻辑）
   ,CASE WHEN MAX(CASE WHEN order_seq = 3 THEN prepay_instalments END) > 0
         THEN CAST(ROUND(
                CAST(MAX(CASE WHEN order_seq = 3 THEN sum_prepaydays END) AS DECIMAL(38,10)) 
                / CAST(MAX(CASE WHEN order_seq = 3 THEN prepay_instalments END) AS DECIMAL(38,10))
              , 6) AS DECIMAL(18,6))
         ELSE NULL END
       AS local_olduser_order_last3orderriskvo_instalmentavgprepaymentdays_v2
   
   -- 35. 最近3笔订单分期的平均（单期）提前还款天数 = 总提前结清天数 / 总提前结清期数（匹配 Java HALF_UP 逻辑）
   ,CASE WHEN SUM(CASE WHEN order_seq IN (1, 2, 3) THEN sum_prepaydays END) > 0 
              AND SUM(CASE WHEN order_seq IN (1, 2, 3) THEN prepay_instalments END) > 0
         THEN CAST(ROUND(
                CAST(SUM(CASE WHEN order_seq IN (1, 2, 3) THEN sum_prepaydays END) AS DECIMAL(38,10)) 
                / CAST(SUM(CASE WHEN order_seq IN (1, 2, 3) THEN prepay_instalments END) AS DECIMAL(38,10))
              , 6) AS DECIMAL(18,6))
         ELSE NULL END
       AS local_olduser_order_last3orderriskvo_instalmentavgprepaymentdaysinlatest3orders_v2
   
   -- 36. 前第3笔订单的最大（单期）逾期天数（>=0，否则NULL）
   ,CASE WHEN MAX(CASE WHEN order_seq = 3 THEN max_overduedays END) > 0
         THEN MAX(CASE WHEN order_seq = 3 THEN max_overduedays END)
         ELSE NULL END
       AS local_olduser_order_last3orderriskvo_instalmentmaxoverduedays_v2
   
   -- 37. 前第3笔订单的最大（单期）提前还款天数
   ,MAX(CASE WHEN order_seq = 3 THEN max_prepaydays END)
       AS local_olduser_order_last3orderriskvo_instalmentmaxprepaymentdays_v2
   
   -- 38. 最近3笔订单中最小（单期）逾期天数（忽略≤0，取绝对值）
   ,ABS(MIN(CASE WHEN order_seq IN (1, 2, 3) THEN min_overduedays_positive END))
       AS local_olduser_order_last3orderriskvo_instalmentminoverduedaysinlatest3orders_v2
   
   -- 39. 前第3笔订单的最小（单期）提前还款天数（忽略≤0）
   ,MAX(CASE WHEN order_seq = 3 THEN min_prepaydays_positive END)
       AS local_olduser_order_last3orderriskvo_instalmentminprepaymentdays_v2
   
   -- 40. 最近3笔订单中最小（单期）提前还款天数（忽略≤0）
   ,MIN(CASE WHEN order_seq IN (1, 2, 3) THEN min_prepaydays_positive END)
       AS local_olduser_order_last3orderriskvo_instalmentminprepaymentdaysinlatest3orders_v2
   
   -- 41. 前第3笔订单分期逾期天数总和（取绝对值）
   ,ABS(COALESCE(MAX(CASE WHEN order_seq = 3 THEN sum_overduedays END), 0))
       AS local_olduser_order_last3orderriskvo_instalmentsumoverduedays_v2
   
   -- 42. 前第3笔订单分期提前还款天数总和
   ,COALESCE(MAX(CASE WHEN order_seq = 3 THEN sum_prepaydays END), 0)
       AS local_olduser_order_last3orderriskvo_instalmentsumprepaymentdays_v2
   
   -- 43. 前第3笔订单是否周末借款
   ,MAX(CASE WHEN order_seq = 3 THEN is_weekend END)
       AS local_olduser_order_last3orderriskvo_iscreationtimeonweekend_v2
   
   -- 44. 前第3笔订单借款时间是否在 11–15 点
   ,MAX(CASE WHEN order_seq = 3 THEN is_11to14 END)
       AS local_olduser_order_last3orderriskvo_iscreationtimewithin11amto14pm_v2
   
   -- 45. 前第3笔订单借款时间是否在 15–18 点
   ,MAX(CASE WHEN order_seq = 3 THEN is_15to17 END)
       AS local_olduser_order_last3orderriskvo_iscreationtimewithin15pmto17pm_v2
   
   -- 46. 前第3笔订单借款时间是否在 18–23 点
   ,MAX(CASE WHEN order_seq = 3 THEN is_18to22 END)
       AS local_olduser_order_last3orderriskvo_iscreationtimewithin18pmto22pm_v2
   
   -- 47. 前第3笔订单借款时间是否在 23–6 点
   ,MAX(CASE WHEN order_seq = 3 THEN is_23to5 END)
       AS local_olduser_order_last3orderriskvo_iscreationtimewithin23pmto5am_v2
   
   -- 48. 前第3笔订单借款时间是否在 6–11 点
   ,MAX(CASE WHEN order_seq = 3 THEN is_6to10 END)
       AS local_olduser_order_last3orderriskvo_iscreationtimewithin6amto10am_v2
   
   -- 49. 最近3笔订单的平均提前还款天数（按订单有无提前还款取均值）
   -- last3OrderSumPrepayDays / last3OrderSumPrepayOrderCount（匹配 Java BigDecimal HALF_UP 逻辑）
   ,CASE WHEN SUM(CASE WHEN order_seq IN (1, 2, 3) AND has_prepay = 1 THEN 1 ELSE 0 END) > 0
         THEN CAST(ROUND(
                CAST(SUM(CASE WHEN order_seq IN (1, 2, 3) AND has_prepay = 1 THEN sum_prepaydays END) AS DECIMAL(38,10)) 
                / CAST(SUM(CASE WHEN order_seq IN (1, 2, 3) AND has_prepay = 1 THEN 1 END) AS DECIMAL(38,10))
              , 6) AS DECIMAL(18,6))
         ELSE NULL END
       AS local_olduser_order_last3orderriskvo_orderavgprepaymentdaysinlatest3orders_v2
   
   -- 50. 最近3笔订单的最大逾期天数（单期，>=0时取值，否则NULL）
   ,CASE WHEN MAX(CASE WHEN order_seq IN (1, 2, 3) THEN max_overduedays END) > 0
         THEN MAX(CASE WHEN order_seq IN (1, 2, 3) THEN max_overduedays END)
         ELSE NULL END
       AS local_olduser_order_last3orderriskvo_ordermaxflatdaysutilratioinlatest3orders_v2
   
   -- 51. 最近3笔订单的最大提前还款天数（单期）
   ,MAX(CASE WHEN order_seq IN (1, 2, 3) THEN max_prepaydays END)
       AS local_olduser_order_last3orderriskvo_ordermaxprepaymentdaysinlatest3orders_v2
   
   -- 52. 最近3笔订单中发生逾期的分期次数
   ,COALESCE(SUM(CASE WHEN order_seq IN (1, 2, 3) THEN overdue_instalments END), 0)
       AS local_olduser_order_last3orderriskvo_overdueinstalmentsinlatest3orders_v2
   
   -- 53. 最近3笔订单中发生逾期的订单笔数
   ,COALESCE(SUM(CASE WHEN order_seq IN (1, 2, 3) THEN has_overdue END), 0)
       AS local_olduser_order_last3orderriskvo_overdueordersinlatest3orders_v2
   
   -- 54. 最近3笔订单中发生提前还款的分期次数
   ,COALESCE(SUM(CASE WHEN order_seq IN (1, 2, 3) THEN prepay_instalments END), 0)
       AS local_olduser_order_last3orderriskvo_prepaymentinstalmentsinlatest3orders_v2
   
   -- 55. 最近3笔订单中发生提前还款的订单笔数
   ,COALESCE(SUM(CASE WHEN order_seq IN (1, 2, 3) THEN has_prepay END), 0)
       AS local_olduser_order_last3orderriskvo_prepaymentordersinlatest3orders_v2
   
   -- 56. 最近3笔订单的逾期天数总和（取绝对值）
   ,ABS(COALESCE(SUM(CASE WHEN order_seq IN (1, 2, 3) THEN sum_overduedays END), 0))
       AS local_olduser_order_last3orderriskvo_sumoverduedaysinlatest3orders_v2
   
   -- 57. 最近3笔订单的提前还款天数总和
   ,COALESCE(SUM(CASE WHEN order_seq IN (1, 2, 3) THEN sum_prepaydays END), 0)
       AS local_olduser_order_last3orderriskvo_sumprepaymentdaysinlatest3orders_v2
   
   -- =========================================================================
   -- 二、当前订单特征 (currentorderriskvo) - 4个 (索引58, 63-65)
   -- =========================================================================
   -- 58. 当前订单是第几笔
   ,MAX(order_seq) + 1 AS local_olduser_order_currentorderriskvo_orderseq_v2
   
   -- 59. 前第1笔的订单Sequence
   ,CASE WHEN MAX(order_seq)  > 0
         THEN MAX(order_seq) 
         ELSE NULL END
       AS local_olduser_order_last1orderriskvo_orderseq_v2
   
   -- 60. 前第2笔的订单Sequence
   ,CASE WHEN MAX(order_seq) - 1 > 0
         THEN MAX(order_seq) - 1
         ELSE NULL END
       AS local_olduser_order_last2orderriskvo_orderseq_v2
   
   -- 61. 前第3笔的订单Sequence
   ,CASE WHEN MAX(order_seq) - 2 > 0
         THEN MAX(order_seq) - 2
         ELSE NULL END
       AS local_olduser_order_last3orderriskvo_orderseq_v2
   
   -- 62. 前第4笔的订单Sequence
   ,CASE WHEN MAX(order_seq) - 3 > 0
         THEN MAX(order_seq) - 3
         ELSE NULL END
       AS local_olduser_order_last4orderriskvo_orderseq_v2

   
   -- 63. 上笔订单距当前订单的时间间隔（天）
   ,DATEDIFF(to_date(use_create_time), MAX(CASE WHEN order_seq = 1 THEN to_date(create_time) END)) 
       AS local_olduser_order_currentorderriskvo_orderintervaltime_timespanbetweenlastorderandcurrentinday_v2
   
   -- 64. 上笔订单距当前订单的时间间隔（小时）
   ,CAST((UNIX_TIMESTAMP(use_create_time) - MAX(CASE WHEN order_seq = 1 THEN UNIX_TIMESTAMP(create_time) END)) / 3600 AS BIGINT)
       AS local_olduser_order_currentorderriskvo_orderintervaltime_timespanbetweenlastorderandcurrentinhour_v2
   
   -- 65. 上笔订单距当前订单的时间间隔（毫秒）
   ,(UNIX_TIMESTAMP(use_create_time) - MAX(CASE WHEN order_seq = 1 THEN UNIX_TIMESTAMP(create_time) END)) * 1000
       AS local_olduser_order_currentorderriskvo_orderintervaltime_timespanbetweenlastorderandcurrentinmillisecond_v2
   
   -- =========================================================================
   -- 三、前第1笔分期明细特征 (last1orderinstalmentriskvo) - 14个 (索引66-79)
   -- 支持最多8期贷款
   -- =========================================================================
   -- 66. 前一笔同日最多结清的期数（支持8期）
   -- 如果所有期次都没有有效的settled_date，则返回0
   ,MAX(CASE WHEN order_seq = 1 THEN 
       CASE WHEN COALESCE(period1_settled_date, period2_settled_date, period3_settled_date, period4_settled_date,
                          period5_settled_date, period6_settled_date, period7_settled_date, period8_settled_date) IS NULL
            THEN 0  -- 所有期次都没有结清日期，返回0
            ELSE GREATEST(
               -- 从第1期开始的连续同日结清数（只有当period1有值时才计算）
               CASE WHEN period1_settled_date IS NOT NULL THEN 1 ELSE 0 END
                 + COALESCE(CASE WHEN period1_settled_date IS NOT NULL AND period1_settled_date = period2_settled_date THEN 1 ELSE 0 END, 0)
                 + COALESCE(CASE WHEN period1_settled_date IS NOT NULL AND period1_settled_date = period2_settled_date AND period2_settled_date = period3_settled_date THEN 1 ELSE 0 END, 0)
                 + COALESCE(CASE WHEN period1_settled_date IS NOT NULL AND period1_settled_date = period2_settled_date AND period2_settled_date = period3_settled_date AND period3_settled_date = period4_settled_date THEN 1 ELSE 0 END, 0)
                 + COALESCE(CASE WHEN period1_settled_date IS NOT NULL AND period1_settled_date = period2_settled_date AND period2_settled_date = period3_settled_date AND period3_settled_date = period4_settled_date AND period4_settled_date = period5_settled_date THEN 1 ELSE 0 END, 0)
                 + COALESCE(CASE WHEN period1_settled_date IS NOT NULL AND period1_settled_date = period2_settled_date AND period2_settled_date = period3_settled_date AND period3_settled_date = period4_settled_date AND period4_settled_date = period5_settled_date AND period5_settled_date = period6_settled_date THEN 1 ELSE 0 END, 0)
                 + COALESCE(CASE WHEN period1_settled_date IS NOT NULL AND period1_settled_date = period2_settled_date AND period2_settled_date = period3_settled_date AND period3_settled_date = period4_settled_date AND period4_settled_date = period5_settled_date AND period5_settled_date = period6_settled_date AND period6_settled_date = period7_settled_date THEN 1 ELSE 0 END, 0)
                 + COALESCE(CASE WHEN period1_settled_date IS NOT NULL AND period1_settled_date = period2_settled_date AND period2_settled_date = period3_settled_date AND period3_settled_date = period4_settled_date AND period4_settled_date = period5_settled_date AND period5_settled_date = period6_settled_date AND period6_settled_date = period7_settled_date AND period7_settled_date = period8_settled_date THEN 1 ELSE 0 END, 0),
               -- 从第2期开始的连续同日结清数
               CASE WHEN period2_settled_date IS NOT NULL THEN 1 ELSE 0 END
                 + COALESCE(CASE WHEN period2_settled_date IS NOT NULL AND period2_settled_date = period3_settled_date THEN 1 ELSE 0 END, 0)
                 + COALESCE(CASE WHEN period2_settled_date IS NOT NULL AND period2_settled_date = period3_settled_date AND period3_settled_date = period4_settled_date THEN 1 ELSE 0 END, 0)
                 + COALESCE(CASE WHEN period2_settled_date IS NOT NULL AND period2_settled_date = period3_settled_date AND period3_settled_date = period4_settled_date AND period4_settled_date = period5_settled_date THEN 1 ELSE 0 END, 0)
                 + COALESCE(CASE WHEN period2_settled_date IS NOT NULL AND period2_settled_date = period3_settled_date AND period3_settled_date = period4_settled_date AND period4_settled_date = period5_settled_date AND period5_settled_date = period6_settled_date THEN 1 ELSE 0 END, 0)
                 + COALESCE(CASE WHEN period2_settled_date IS NOT NULL AND period2_settled_date = period3_settled_date AND period3_settled_date = period4_settled_date AND period4_settled_date = period5_settled_date AND period5_settled_date = period6_settled_date AND period6_settled_date = period7_settled_date THEN 1 ELSE 0 END, 0)
                 + COALESCE(CASE WHEN period2_settled_date IS NOT NULL AND period2_settled_date = period3_settled_date AND period3_settled_date = period4_settled_date AND period4_settled_date = period5_settled_date AND period5_settled_date = period6_settled_date AND period6_settled_date = period7_settled_date AND period7_settled_date = period8_settled_date THEN 1 ELSE 0 END, 0),
               -- 从第3期开始
               CASE WHEN period3_settled_date IS NOT NULL THEN 1 ELSE 0 END
                 + COALESCE(CASE WHEN period3_settled_date IS NOT NULL AND period3_settled_date = period4_settled_date THEN 1 ELSE 0 END, 0)
                 + COALESCE(CASE WHEN period3_settled_date IS NOT NULL AND period3_settled_date = period4_settled_date AND period4_settled_date = period5_settled_date THEN 1 ELSE 0 END, 0)
                 + COALESCE(CASE WHEN period3_settled_date IS NOT NULL AND period3_settled_date = period4_settled_date AND period4_settled_date = period5_settled_date AND period5_settled_date = period6_settled_date THEN 1 ELSE 0 END, 0)
                 + COALESCE(CASE WHEN period3_settled_date IS NOT NULL AND period3_settled_date = period4_settled_date AND period4_settled_date = period5_settled_date AND period5_settled_date = period6_settled_date AND period6_settled_date = period7_settled_date THEN 1 ELSE 0 END, 0)
                 + COALESCE(CASE WHEN period3_settled_date IS NOT NULL AND period3_settled_date = period4_settled_date AND period4_settled_date = period5_settled_date AND period5_settled_date = period6_settled_date AND period6_settled_date = period7_settled_date AND period7_settled_date = period8_settled_date THEN 1 ELSE 0 END, 0),
               -- 从第4期开始
               CASE WHEN period4_settled_date IS NOT NULL THEN 1 ELSE 0 END
                 + COALESCE(CASE WHEN period4_settled_date IS NOT NULL AND period4_settled_date = period5_settled_date THEN 1 ELSE 0 END, 0)
                 + COALESCE(CASE WHEN period4_settled_date IS NOT NULL AND period4_settled_date = period5_settled_date AND period5_settled_date = period6_settled_date THEN 1 ELSE 0 END, 0)
                 + COALESCE(CASE WHEN period4_settled_date IS NOT NULL AND period4_settled_date = period5_settled_date AND period5_settled_date = period6_settled_date AND period6_settled_date = period7_settled_date THEN 1 ELSE 0 END, 0)
                 + COALESCE(CASE WHEN period4_settled_date IS NOT NULL AND period4_settled_date = period5_settled_date AND period5_settled_date = period6_settled_date AND period6_settled_date = period7_settled_date AND period7_settled_date = period8_settled_date THEN 1 ELSE 0 END, 0),
               -- 从第5期开始
               CASE WHEN period5_settled_date IS NOT NULL THEN 1 ELSE 0 END
                 + COALESCE(CASE WHEN period5_settled_date IS NOT NULL AND period5_settled_date = period6_settled_date THEN 1 ELSE 0 END, 0)
                 + COALESCE(CASE WHEN period5_settled_date IS NOT NULL AND period5_settled_date = period6_settled_date AND period6_settled_date = period7_settled_date THEN 1 ELSE 0 END, 0)
                 + COALESCE(CASE WHEN period5_settled_date IS NOT NULL AND period5_settled_date = period6_settled_date AND period6_settled_date = period7_settled_date AND period7_settled_date = period8_settled_date THEN 1 ELSE 0 END, 0),
               -- 从第6期开始
               CASE WHEN period6_settled_date IS NOT NULL THEN 1 ELSE 0 END
                 + COALESCE(CASE WHEN period6_settled_date IS NOT NULL AND period6_settled_date = period7_settled_date THEN 1 ELSE 0 END, 0)
                 + COALESCE(CASE WHEN period6_settled_date IS NOT NULL AND period6_settled_date = period7_settled_date AND period7_settled_date = period8_settled_date THEN 1 ELSE 0 END, 0),
               -- 从第7期开始
               CASE WHEN period7_settled_date IS NOT NULL THEN 1 ELSE 0 END
                 + COALESCE(CASE WHEN period7_settled_date IS NOT NULL AND period7_settled_date = period8_settled_date THEN 1 ELSE 0 END, 0),
               -- 从第8期开始
               CASE WHEN period8_settled_date IS NOT NULL THEN 1 ELSE 0 END,
               0
           )
       END
   END) AS local_olduser_order_last1orderinstalmentriskvo_samedaymostsettledinstalmentnum_v2
   
   -- 67. 前一笔第1期是否逾期
   ,MAX(CASE WHEN order_seq = 1 THEN period1_overdue END)
       AS local_olduser_order_last1orderinstalmentriskvo_1stinstalmentoverdue_v2
   
   -- 68. 前一笔第1期逾期天数（负数返回0）
   ,GREATEST(COALESCE(MAX(CASE WHEN order_seq = 1 THEN period1_overduedays END), 0), 0)
       AS local_olduser_order_last1orderinstalmentriskvo_1stinstalmentoverduedays_v2
   
   -- 69. 前一笔第2期是否逾期
   ,MAX(CASE WHEN order_seq = 1 THEN period2_overdue END)
       AS local_olduser_order_last1orderinstalmentriskvo_2ndinstalmentoverdue_v2
   
   -- 70. 前一笔第2期逾期天数（负数返回0）
   ,GREATEST(COALESCE(MAX(CASE WHEN order_seq = 1 THEN period2_overduedays END), 0), 0)
       AS local_olduser_order_last1orderinstalmentriskvo_2ndinstalmentoverduedays_v2
   
   -- 71. 前一笔第3期是否逾期
   ,MAX(CASE WHEN order_seq = 1 THEN period3_overdue END)
       AS local_olduser_order_last1orderinstalmentriskvo_3rdinstalmentoverdue_v2
   
   -- 72. 前一笔第3期逾期天数（负数返回0）
   ,GREATEST(COALESCE(MAX(CASE WHEN order_seq = 1 THEN period3_overduedays END), 0), 0)
       AS local_olduser_order_last1orderinstalmentriskvo_3rdinstalmentoverduedays_v2
   
   -- 73. 前一笔第4期逾期天数（负数返回0）
   ,GREATEST(COALESCE(MAX(CASE WHEN order_seq = 1 THEN period4_overduedays END), 0), 0)
       AS local_olduser_order_last1orderinstalmentriskvo_4thinstalmentoverduedays_v2
   
   -- 74. 前一笔第4期是否逾期
   ,MAX(CASE WHEN order_seq = 1 THEN period4_overdue END)
       AS local_olduser_order_last1orderinstalmentriskvo_instalment4overdue_v2
   
   -- 75. 前一笔首次发生逾期的期数（使用通用字段，支持任意期数）
   ,MAX(CASE WHEN order_seq = 1 THEN first_overdue_period END)
       AS local_olduser_order_last1orderinstalmentriskvo_firstoverdueinstalment_v2
   
   -- 76. 前一笔第1与第2期结清日期间隔（天）
   ,MAX(CASE WHEN order_seq = 1 THEN DATEDIFF(period2_settled_date, period1_settled_date) END)
       AS local_olduser_order_last1orderinstalmentriskvo_loan1and2repaymentdatedayspan_v2
   
   -- 77. 前一笔第2与第3期结清日期间隔（天）
   ,MAX(CASE WHEN order_seq = 1 THEN DATEDIFF(period3_settled_date, period2_settled_date) END)
       AS local_olduser_order_last1orderinstalmentriskvo_loan2and3repaymentdatedayspan_v2
   
   -- 78. 前一笔第3与第4期结清日期间隔（天）
   ,MAX(CASE WHEN order_seq = 1 THEN DATEDIFF(period4_settled_date, period3_settled_date) END)
       AS local_olduser_order_last1orderinstalmentriskvo_loan3and4repaymentdatedayspan_v2
   
   -- 79. 前一笔最长连续提前还款期数（支持8期）
   ,MAX(CASE WHEN order_seq = 1 THEN 
       GREATEST(
           -- 从第1期开始的连续提前还款数
           CASE WHEN period1_prepay = 1 THEN 1 ELSE 0 END
             + CASE WHEN period1_prepay = 1 AND period2_prepay = 1 THEN 1 ELSE 0 END
             + CASE WHEN period1_prepay = 1 AND period2_prepay = 1 AND period3_prepay = 1 THEN 1 ELSE 0 END
             + CASE WHEN period1_prepay = 1 AND period2_prepay = 1 AND period3_prepay = 1 AND period4_prepay = 1 THEN 1 ELSE 0 END
             + CASE WHEN period1_prepay = 1 AND period2_prepay = 1 AND period3_prepay = 1 AND period4_prepay = 1 AND period5_prepay = 1 THEN 1 ELSE 0 END
             + CASE WHEN period1_prepay = 1 AND period2_prepay = 1 AND period3_prepay = 1 AND period4_prepay = 1 AND period5_prepay = 1 AND period6_prepay = 1 THEN 1 ELSE 0 END
             + CASE WHEN period1_prepay = 1 AND period2_prepay = 1 AND period3_prepay = 1 AND period4_prepay = 1 AND period5_prepay = 1 AND period6_prepay = 1 AND period7_prepay = 1 THEN 1 ELSE 0 END
             + CASE WHEN period1_prepay = 1 AND period2_prepay = 1 AND period3_prepay = 1 AND period4_prepay = 1 AND period5_prepay = 1 AND period6_prepay = 1 AND period7_prepay = 1 AND period8_prepay = 1 THEN 1 ELSE 0 END,
           -- 从第2期开始
           CASE WHEN period2_prepay = 1 THEN 1 ELSE 0 END
             + CASE WHEN period2_prepay = 1 AND period3_prepay = 1 THEN 1 ELSE 0 END
             + CASE WHEN period2_prepay = 1 AND period3_prepay = 1 AND period4_prepay = 1 THEN 1 ELSE 0 END
             + CASE WHEN period2_prepay = 1 AND period3_prepay = 1 AND period4_prepay = 1 AND period5_prepay = 1 THEN 1 ELSE 0 END
             + CASE WHEN period2_prepay = 1 AND period3_prepay = 1 AND period4_prepay = 1 AND period5_prepay = 1 AND period6_prepay = 1 THEN 1 ELSE 0 END
             + CASE WHEN period2_prepay = 1 AND period3_prepay = 1 AND period4_prepay = 1 AND period5_prepay = 1 AND period6_prepay = 1 AND period7_prepay = 1 THEN 1 ELSE 0 END
             + CASE WHEN period2_prepay = 1 AND period3_prepay = 1 AND period4_prepay = 1 AND period5_prepay = 1 AND period6_prepay = 1 AND period7_prepay = 1 AND period8_prepay = 1 THEN 1 ELSE 0 END,
           -- 从第3期开始
           CASE WHEN period3_prepay = 1 THEN 1 ELSE 0 END
             + CASE WHEN period3_prepay = 1 AND period4_prepay = 1 THEN 1 ELSE 0 END
             + CASE WHEN period3_prepay = 1 AND period4_prepay = 1 AND period5_prepay = 1 THEN 1 ELSE 0 END
             + CASE WHEN period3_prepay = 1 AND period4_prepay = 1 AND period5_prepay = 1 AND period6_prepay = 1 THEN 1 ELSE 0 END
             + CASE WHEN period3_prepay = 1 AND period4_prepay = 1 AND period5_prepay = 1 AND period6_prepay = 1 AND period7_prepay = 1 THEN 1 ELSE 0 END
             + CASE WHEN period3_prepay = 1 AND period4_prepay = 1 AND period5_prepay = 1 AND period6_prepay = 1 AND period7_prepay = 1 AND period8_prepay = 1 THEN 1 ELSE 0 END,
           -- 从第4期开始
           CASE WHEN period4_prepay = 1 THEN 1 ELSE 0 END
             + CASE WHEN period4_prepay = 1 AND period5_prepay = 1 THEN 1 ELSE 0 END
             + CASE WHEN period4_prepay = 1 AND period5_prepay = 1 AND period6_prepay = 1 THEN 1 ELSE 0 END
             + CASE WHEN period4_prepay = 1 AND period5_prepay = 1 AND period6_prepay = 1 AND period7_prepay = 1 THEN 1 ELSE 0 END
             + CASE WHEN period4_prepay = 1 AND period5_prepay = 1 AND period6_prepay = 1 AND period7_prepay = 1 AND period8_prepay = 1 THEN 1 ELSE 0 END,
           -- 从第5期开始
           CASE WHEN period5_prepay = 1 THEN 1 ELSE 0 END
             + CASE WHEN period5_prepay = 1 AND period6_prepay = 1 THEN 1 ELSE 0 END
             + CASE WHEN period5_prepay = 1 AND period6_prepay = 1 AND period7_prepay = 1 THEN 1 ELSE 0 END
             + CASE WHEN period5_prepay = 1 AND period6_prepay = 1 AND period7_prepay = 1 AND period8_prepay = 1 THEN 1 ELSE 0 END,
           -- 从第6期开始
           CASE WHEN period6_prepay = 1 THEN 1 ELSE 0 END
             + CASE WHEN period6_prepay = 1 AND period7_prepay = 1 THEN 1 ELSE 0 END
             + CASE WHEN period6_prepay = 1 AND period7_prepay = 1 AND period8_prepay = 1 THEN 1 ELSE 0 END,
           -- 从第7期开始
           CASE WHEN period7_prepay = 1 THEN 1 ELSE 0 END
             + CASE WHEN period7_prepay = 1 AND period8_prepay = 1 THEN 1 ELSE 0 END,
           -- 从第8期开始
           CASE WHEN period8_prepay = 1 THEN 1 ELSE 0 END,
           0
       )
   END) AS local_olduser_order_last1orderinstalmentriskvo_longestprepaymentinstalment_v2
   
   -- =========================================================================
   -- 四、前第1笔订单特征 (last1orderriskvo) - 约23个 (索引80-102)
   -- =========================================================================
   -- 80. 前第2笔订单距前第1笔订单完成的时间间隔（天）
   ,DATEDIFF(MAX(CASE WHEN order_seq = 1 THEN to_date(create_time) END), 
             MAX(CASE WHEN order_seq = 2 THEN to_date(create_time) END))
       AS local_olduser_order_last1orderriskvo_orderintervaltime_timespanbetweenlastorderandcurrentinday_v2
   
   -- 81. 前第2笔订单距前第1笔订单完成的时间间隔（小时，取整）
   ,CAST((MAX(CASE WHEN order_seq = 1 THEN UNIX_TIMESTAMP(create_time) END) -
          MAX(CASE WHEN order_seq = 2 THEN UNIX_TIMESTAMP(create_time) END)) / 3600 AS BIGINT)
       AS local_olduser_order_last1orderriskvo_orderintervaltime_timespanbetweenlastorderandcurrentinhour_v2
   
   -- 82. 前第2笔订单距前第1笔订单完成的时间间隔（毫秒）
   ,(MAX(CASE WHEN order_seq = 1 THEN UNIX_TIMESTAMP(create_time) END) - 
     MAX(CASE WHEN order_seq = 2 THEN UNIX_TIMESTAMP(create_time) END)) * 1000
       AS local_olduser_order_last1orderriskvo_orderintervaltime_timespanbetweenlastorderandcurrentinmillisecond_v2
   
   -- 83. 前一笔借款时刻（0-23）
   ,MAX(CASE WHEN order_seq = 1 THEN borrow_hour END) 
       AS local_olduser_order_last1orderriskvo_creationtimeinhour_v2
   
   -- 84. 前一笔借款是否在周末
   ,MAX(CASE WHEN order_seq = 1 THEN is_weekend END) 
       AS local_olduser_order_last1orderriskvo_iscreationtimeonweekend_v2
   
   -- 85. 前一笔借款是否在23点后5点前
   ,MAX(CASE WHEN order_seq = 1 THEN is_23to5 END) 
       AS local_olduser_order_last1orderriskvo_iscreationtimewithin23pmto5am_v2
   
   -- 86. 前一笔借款是否在6点后11点前
   ,MAX(CASE WHEN order_seq = 1 THEN is_6to10 END) 
       AS local_olduser_order_last1orderriskvo_iscreationtimewithin6amto10am_v2
   
   -- 87. 前一笔借款是否在11点后15点前
   ,MAX(CASE WHEN order_seq = 1 THEN is_11to14 END) 
       AS local_olduser_order_last1orderriskvo_iscreationtimewithin11amto14pm_v2
   
   -- 88. 前一笔借款是否在15点后18点前
   ,MAX(CASE WHEN order_seq = 1 THEN is_15to17 END) 
       AS local_olduser_order_last1orderriskvo_iscreationtimewithin15pmto17pm_v2
   
   -- 89. 前一笔借款是否在18点后23点前
   ,MAX(CASE WHEN order_seq = 1 THEN is_18to22 END) 
       AS local_olduser_order_last1orderriskvo_iscreationtimewithin18pmto22pm_v2
   
   -- 90. 前一笔平均逾期天数（取绝对值）
   -- TotalOverdueDays / OverdueInstalmentsCount（匹配 Java BigDecimal HALF_UP 逻辑）
   ,CASE WHEN MAX(CASE WHEN order_seq = 1 THEN overdue_instalments END) > 0
         THEN CAST(ROUND(
                CAST(MAX(CASE WHEN order_seq = 1 THEN sum_overduedays END) AS DECIMAL(38,10)) 
                / CAST(MAX(CASE WHEN order_seq = 1 THEN overdue_instalments END) AS DECIMAL(38,10))
              , 6) AS DECIMAL(18,6))
         ELSE NULL END
       AS local_olduser_order_last1orderriskvo_instalmentavgoverduedays_v2
   
   -- 91. 前一笔最大逾期天数（负数返回0）
   ,GREATEST(COALESCE(MAX(CASE WHEN order_seq = 1 THEN max_overduedays END), 0), 0) 
       AS local_olduser_order_last1orderriskvo_instalmentmaxoverduedays_v2
   
   -- 92. 前一笔总逾期天数（负数返回0）
   ,GREATEST(COALESCE(MAX(CASE WHEN order_seq = 1 THEN sum_overduedays END), 0), 0) 
       AS local_olduser_order_last1orderriskvo_instalmentsumoverduedays_v2
   
   -- 93. 前一笔平均提前还款天数
   -- TotalPrepayDays / PrepayInstalmentsCount（匹配 Java BigDecimal HALF_UP 逻辑）
   ,CASE WHEN MAX(CASE WHEN order_seq = 1 THEN prepay_instalments END) > 0
         THEN CAST(ROUND(
                CAST(MAX(CASE WHEN order_seq = 1 THEN sum_prepaydays END) AS DECIMAL(38,10)) 
                / CAST(MAX(CASE WHEN order_seq = 1 THEN prepay_instalments END) AS DECIMAL(38,10))
              , 6) AS DECIMAL(18,6))
         ELSE NULL END
       AS local_olduser_order_last1orderriskvo_instalmentavgprepaymentdays_v2
   
   -- 94. 前一笔最大提前还款天数
   ,MAX(CASE WHEN order_seq = 1 THEN max_prepaydays END) 
       AS local_olduser_order_last1orderriskvo_instalmentmaxprepaymentdays_v2
   
   -- 95. 前一笔总提前还款天数
   ,COALESCE(MAX(CASE WHEN order_seq = 1 THEN sum_prepaydays END), 0) 
       AS local_olduser_order_last1orderriskvo_instalmentsumprepaymentdays_v2
   
   -- 96. 最近1笔有逾期的期次数
   ,COALESCE(MAX(CASE WHEN order_seq = 1 THEN overdue_instalments END), 0) 
       AS local_olduser_order_last1orderriskvo_overdueinstalmentsinlatestxorders_v2
   
   -- 97. 最近1笔是否存在逾期订单（0/1）
   ,COALESCE(MAX(CASE WHEN order_seq = 1 THEN has_overdue END), 0) 
       AS local_olduser_order_last1orderriskvo_overdueordersinlatestxorders_v2
   
   -- 98. 最近1笔有提前还款的期次数
   ,COALESCE(MAX(CASE WHEN order_seq = 1 THEN prepay_instalments END), 0) 
       AS local_olduser_order_last1orderriskvo_prepaymentinstalmentsinlatestxorders_v2
   
   -- 99. 最近1笔是否存在提前还款订单（0/1）
   ,COALESCE(MAX(CASE WHEN order_seq = 1 THEN has_prepay END), 0) 
       AS local_olduser_order_last1orderriskvo_prepaymentordersinlatestxorders_v2
   
   -- 100. 最近1笔逾期天数总和（负数返回0）重复
--    ,GREATEST(COALESCE(MAX(CASE WHEN order_seq = 1 THEN sum_overduedays END), 0), 0) 
--        AS local_olduser_order_last1orderriskvo_sumoverduedaysinlatestxorders_v2
   
   -- 101. 最近1笔最小（单期）逾期天数（取绝对值）
   ,ABS(MAX(CASE WHEN order_seq = 1 THEN min_overduedays_positive END)) 
       AS local_olduser_order_last1orderriskvo_instalmentminoverduedaysinlatestxorders_v2
   
   -- 102. 最近1笔最小（单期）提前还款天数
   ,MAX(CASE WHEN order_seq = 1 THEN min_prepaydays_positive END) 
       AS local_olduser_order_last1orderriskvo_instalmentminprepaymentdaysinlatestxorders_v2
   
   -- =========================================================================
   -- 五、全量订单特征 (totalorderriskvo) - 约12个 (索引103-128)
   -- =========================================================================
   -- 103. 连续逾期订单数（全量）- 从最近一笔开始连续has_overdue=1的订单数
   -- 使用窗口函数计算：cum_no_overdue=0表示从order_seq=1到当前都是连续逾期
--    ,COALESCE(MAX(CASE WHEN cum_no_overdue = 0 THEN order_seq ELSE 0 END), 0)
--        AS local_olduser_order_totalorderriskvo_continuousoverdueorders_v2
   
   -- 104. 连续提前还款订单数（全量）- 从最近一笔开始连续has_prepay=1的订单数
--    ,COALESCE(MAX(CASE WHEN cum_no_prepay = 0 THEN order_seq ELSE 0 END), 0)
--        AS local_olduser_order_totalorderriskvo_continuousprepaymentorders_v2
   
   -- 105. 深夜下单笔数（23–5点）
   ,COALESCE(SUM(is_23to5), 0)
       AS local_olduser_order_totalorderriskvo_countcreationtimeifwithin23pmto5amintotalorders_v2
   
   -- 106. 借款时间间隔均值（天）- 截断6位小数（匹配Java BigDecimal FLOOR）
   ,CAST(FLOOR(
       CAST(COALESCE(DATEDIFF(MAX(CASE WHEN order_seq = 1 THEN to_date(create_time) END), MIN(to_date(create_time))), 0) AS DECIMAL(38,10)) 
       / CAST(NULLIF(COUNT(DISTINCT loan_no) - 1, 0) AS DECIMAL(38,10))
   * 1000000) / 1000000 AS DECIMAL(18,6))
       AS local_olduser_order_totalorderriskvo_creationtimeaverageintervalintotalorders_v2
   
   -- 107. 借款时刻均值（小时）- divide = totalHours / size, HALF_UP 6位小数
   ,CAST(ROUND(
       CAST(SUM(borrow_hour) AS DECIMAL(38,10)) 
       / CAST(NULLIF(COUNT(*), 0) AS DECIMAL(38,10))
     , 6) AS DECIMAL(18,6))
       AS local_olduser_order_totalorderriskvo_creationtimeinhouravgintotalorders_v2
   
   -- 108. 当前小时 − divide，HALF_UP 6位小数
   ,CAST(ROUND(
       CAST(HOUR(use_create_time) AS DECIMAL(18,6)) 
       - CAST(ROUND(
           CAST(SUM(borrow_hour) AS DECIMAL(38,10)) 
           / CAST(NULLIF(COUNT(*), 0) AS DECIMAL(38,10))
         , 6) AS DECIMAL(18,6))
     , 6) AS DECIMAL(18,6))
       AS local_olduser_order_totalorderriskvo_currenthourminusavgborrowhourintotalorders_v2
   
   -- 109. 最大（单期）提前还款天数
   ,MAX(max_prepaydays)
       AS local_olduser_order_totalorderriskvo_ordermaxprepaymentdaysintotalorders_v2
   
   -- 110. 最小（单期）提前还款天数
   ,MIN(min_prepaydays_positive)
       AS local_olduser_order_totalorderriskvo_orderminprepaymentdaysintotalorders_v2
   
   -- 111. 平均提前还款天数（订单粒度）- FLOOR 截断6位小数
   ,CAST(
       FLOOR(
           CAST(SUM(CASE WHEN has_prepay = 1 THEN sum_prepaydays END) AS DECIMAL(38,10)) 
           / CAST(NULLIF(SUM(CASE WHEN has_prepay = 1 THEN 1 END), 0) AS DECIMAL(38,10))
           * 1000000
       ) / 1000000 
     AS DECIMAL(18,6))
       AS local_olduser_order_totalorderriskvo_orderavgprepaymentdaysintotalorders_v2
   
   -- =========================================================================
   -- 六、前第4笔订单特征 (last4orderriskvo) - 约17个 (索引112-128)
   -- =========================================================================
   -- 112. 前第4笔分期逾期天数总和（取绝对值）
   ,ABS(COALESCE(MAX(CASE WHEN order_seq = 4 THEN sum_overduedays END), 0))
       AS local_olduser_order_last4orderriskvo_instalmentsumoverduedays_v2
   
   -- 113. 前第4笔分期平均提前还款天数 - HALF_UP 6位小数
   ,CAST(ROUND(
       CAST(MAX(CASE WHEN order_seq = 4 THEN sum_prepaydays END) AS DECIMAL(38,10)) 
       / CAST(NULLIF(MAX(CASE WHEN order_seq = 4 THEN prepay_instalments END), 0) AS DECIMAL(38,10))
     , 6) AS DECIMAL(18,6))
       AS local_olduser_order_last4orderriskvo_instalmentavgprepaymentdays_v2
   
   -- 114. 前第4笔分期最大逾期天数（取绝对值）
   ,CASE WHEN MAX(CASE WHEN order_seq = 4 THEN max_overduedays END) > 0
         THEN MAX(CASE WHEN order_seq = 4 THEN max_overduedays END)
         ELSE NULL END
       AS local_olduser_order_last4orderriskvo_instalmentmaxoverduedays_v2
   
   -- 115. 前第4笔分期最大提前还款天数
   ,MAX(CASE WHEN order_seq = 4 THEN max_prepaydays END)
       AS local_olduser_order_last4orderriskvo_instalmentmaxprepaymentdays_v2
   
   -- 116. 前第4笔分期最小提前还款天数
   ,MAX(CASE WHEN order_seq = 4 THEN min_prepaydays_positive END)
       AS local_olduser_order_last4orderriskvo_instalmentminprepaymentdays_v2
   
   -- 117. 前第4笔分期提前还款天数总和
   ,COALESCE(MAX(CASE WHEN order_seq = 4 THEN sum_prepaydays END), 0)
       AS local_olduser_order_last4orderriskvo_instalmentsumprepaymentdays_v2
   
   -- 118. 前第4笔是否周末借款
   ,MAX(CASE WHEN order_seq = 4 THEN is_weekend END)
       AS local_olduser_order_last4orderriskvo_iscreationtimeonweekend_v2
   
   -- 119. 前第4笔是否11–15点借款
   ,MAX(CASE WHEN order_seq = 4 THEN is_11to14 END)
       AS local_olduser_order_last4orderriskvo_iscreationtimewithin11amto14pm_v2
   
   -- 120. 前第4笔是否15–18点借款
   ,MAX(CASE WHEN order_seq = 4 THEN is_15to17 END)
       AS local_olduser_order_last4orderriskvo_iscreationtimewithin15pmto17pm_v2
   
   -- 121. 前第4笔是否18–23点借款
   ,MAX(CASE WHEN order_seq = 4 THEN is_18to22 END)
       AS local_olduser_order_last4orderriskvo_iscreationtimewithin18pmto22pm_v2
   
   -- 122. 前第4笔是否23–5点借款
   ,MAX(CASE WHEN order_seq = 4 THEN is_23to5 END)
       AS local_olduser_order_last4orderriskvo_iscreationtimewithin23pmto5am_v2
   
   -- 123. 前第4笔是否6–11点借款
   ,MAX(CASE WHEN order_seq = 4 THEN is_6to10 END)
       AS local_olduser_order_last4orderriskvo_iscreationtimewithin6amto10am_v2
   
   -- 124. 逾期天数总和（取绝对值）
   ,ABS(COALESCE(SUM(sum_overduedays), 0))
       AS local_olduser_order_totalorderriskvo_sumoverduedaysintotalorders_v2
   
   -- 125. 前第4笔至前第1笔间隔（天）
   ,DATEDIFF(MAX(CASE WHEN order_seq = 1 THEN to_date(create_time) END),
             MAX(CASE WHEN order_seq = 4 THEN to_date(create_time) END))
       AS local_olduser_order_last4orderriskvo_orderintervaltime_timespanbetweenlastorderandlast4inday_v2
   
   -- 126. 历史提前还款天数总和
   ,COALESCE(SUM(sum_prepaydays), 0)
       AS local_olduser_order_totalorderriskvo_sumprepaymentdaysintotalorders_v2
   
   -- 127. 前第4笔和前第1笔相差的小时数
   ,CAST((MAX(CASE WHEN order_seq = 1 THEN UNIX_TIMESTAMP(create_time) END) -
           MAX(CASE WHEN order_seq = 4 THEN UNIX_TIMESTAMP(create_time) END)) / 3600 AS BIGINT)
       AS local_olduser_order_last4orderriskvo_orderintervaltime_timespanbetweenlastorderandlast4inhour_v2
   
   -- 128. 前第4笔和前第1笔相差的毫秒数
   ,(MAX(CASE WHEN order_seq = 1 THEN UNIX_TIMESTAMP(create_time) END) -
     MAX(CASE WHEN order_seq = 4 THEN UNIX_TIMESTAMP(create_time) END)) * 1000
       AS local_olduser_order_last4orderriskvo_orderintervaltime_timespanbetweenlastorderandlast4inmillisecond_v2

FROM order_ranked
GROUP BY cust_no, use_credit_apply_id, use_create_time) t
where use_create_time>='2026-01-08 01:29:30'
order by use_create_time desc
;
