-- name 贷中特征_99_无观察时间
-- type StarRocks
-- author chenenze909@hellobike.com
-- create time 2026-01-12 05:34:24
-- desc 
WITH 
-- ===================== 0. 各客户最新订单创建时间作为观察日期 =====================
customer_observation_date AS (
    SELECT 
        cust_no,
        MAX(create_time) AS observation_date  -- 各客户的最新use_credit.create_time作为观察日期
    FROM hive_idc.hello_prd.ods_mx_aprv_approve_use_credit_apply_df
    WHERE pt = DATE_SUB(CURRENT_DATE(), 2)  -- 使用昨天的分区
    -- and cust_no = '800000003371'
    GROUP BY cust_no
),

-- ===================== 1. 基础表：复用原有base_loan_data_light结构 =====================
base_loan_data_light AS (
    SELECT 
        cod.observation_date,  -- 添加观察日期字段
        use_credit.id,
        use_credit.create_time AS order_create_time,  -- 订单创建时间（即use_credit表的credit_time）
        use_credit.cust_no,
        use_credit.asset_id,
        use_credit.approve_state,  -- 申请状态（用于筛选通过的申请）
        credit_limit.create_time AS calc_credit_time,
        credit_limit.total_limit,
        credit_limit.available_limit,
        credit_apply.create_time AS first_credit_time,  -- 首次授信时间（credit_apply表的create_time）
        -- 说明：first_credit_time是订单级别的字段，同一个loan_no下的所有periods账单值相同（正常业务逻辑）
        CAST(loan_apply.loan_amt AS DOUBLE) AS loan_amt,
        loan_info.loan_no,
        repay_plan.loan_start_date,  -- 放款时间（repay_plan表的loan_start_date，账单级别字段）
        -- 说明：loan_start_date是账单级别的字段，repay_plan表中同一订单下不同periods的账单的放款时间都是独立的
        loan_info.loan_status,
        repay_plan.id AS rp_id,
        repay_plan.periods,
        repay_plan.loan_end_date,
        CAST(repay_plan.principal AS DOUBLE) AS principal,
        CAST(repay_plan.repaid_principal AS DOUBLE) AS repaid_principal,
        repay_plan.repay_plan_status,
        repay_plan.settled_time,
        -- 原计算逻辑（保留用于其他用途，新逻辑在order_level_stats中计算）
        -- 注意：使用repay_plan.loan_start_date（账单级别），每个账单的calc_credit_gap可能不同
        GREATEST(DATEDIFF(DATE(repay_plan.loan_start_date), DATE(credit_limit.create_time)), 0) AS calc_credit_gap,
        -- 逾期判断：包括两种情况
        -- 1. 已结清但结清时间晚于到期日（只使用观察日期及之前的结清时间，避免时间穿越）
        -- 2. 未结清但观察日期已超过到期日
        CASE 
            WHEN (repay_plan.settled_time IS NOT NULL 
                AND repay_plan.settled_time <= cod.observation_date  -- 修复：只使用观察日期及之前的结清时间
                AND datediff(date(repay_plan.settled_time), date(repay_plan.loan_end_date)) > 0)
            OR (repay_plan.settled_time IS NULL 
                AND datediff(cod.observation_date, date(repay_plan.loan_end_date)) > 0)
            OR (repay_plan.settled_time IS NOT NULL 
                AND date(repay_plan.settled_time) > cod.observation_date  -- 修复：对于未来结清的账单，如果观察日期已超过到期日，也算逾期
                AND datediff(cod.observation_date, date(repay_plan.loan_end_date)) > 0)
            THEN 1 
            ELSE 0 
        END AS is_overdue_new,
        -- 修复：只统计观察日期及之前已结清的账单，避免时间穿越
        CASE WHEN repay_plan.settled_time IS NOT NULL 
            AND repay_plan.settled_time <= cod.observation_date 
            THEN 1 
            ELSE 0 
        END AS is_complete_new,
        -- 修复：只统计观察日期及之前已提前结清的账单，避免时间穿越
        CASE 
            WHEN repay_plan.settled_time IS NOT NULL 
                AND repay_plan.settled_time <= cod.observation_date  -- 修复：只使用观察日期及之前的结清时间
                AND datediff(date(repay_plan.loan_end_date), date(repay_plan.settled_time)) > 0 
            THEN 1 
            ELSE 0 
        END AS is_prepay,
        -- 修复：只计算观察日期及之前已提前结清的账单的提前天数，避免时间穿越
        CASE 
            WHEN repay_plan.settled_time IS NOT NULL 
                AND repay_plan.settled_time <= cod.observation_date  -- 修复：只使用观察日期及之前的结清时间
                AND datediff(date(repay_plan.loan_end_date), date(repay_plan.settled_time)) > 0 
            THEN datediff(date(repay_plan.loan_end_date), date(repay_plan.settled_time))
            ELSE 0 
        END AS prepay_days,
        -- 逾期天数：已结清用结清时间计算（只使用观察日期及之前的结清时间），未结清用观察日期计算
        -- 修复：只使用观察日期及之前的结清时间，避免时间穿越
        CASE 
            WHEN repay_plan.settled_time IS NOT NULL 
                AND repay_plan.settled_time <= cod.observation_date  -- 修复：只使用观察日期及之前的结清时间
                AND datediff(date(repay_plan.settled_time), date(repay_plan.loan_end_date)) > 0 
            THEN datediff(date(repay_plan.settled_time), date(repay_plan.loan_end_date))
            WHEN (repay_plan.settled_time IS NULL 
                OR date(repay_plan.settled_time) > cod.observation_date)  -- 修复：未结清或未来结清的账单，用观察日期计算
                AND datediff(cod.observation_date, date(repay_plan.loan_end_date)) > 0
            THEN datediff(cod.observation_date, date(repay_plan.loan_end_date))
            ELSE 0 
        END AS overdue_days,
        HOUR(use_credit.create_time) AS order_apply_hour,
        CASE 
            WHEN pmod(datediff(use_credit.create_time, '1970-01-05'), 7) + 1 IN (6, 7) 
            THEN 1 
            ELSE 0 
        END AS is_weekend_order
    FROM customer_observation_date cod
    INNER JOIN hive_idc.hello_prd.ods_mx_aprv_approve_use_credit_apply_df use_credit
        ON use_credit.cust_no = cod.cust_no
        AND use_credit.pt = DATE_SUB(CURRENT_DATE(), 2)
    LEFT JOIN hive_idc.hello_prd.ods_mx_aprv_approve_credit_apply_df credit_apply 
        ON credit_apply.id = CAST(use_credit.credit_apply_id AS STRING)
        AND credit_apply.pt = DATE_SUB(CURRENT_DATE(), 2)
    LEFT JOIN hive_idc.hello_prd.ods_mx_ast_asset_loan_apply_df loan_apply 
        ON loan_apply.seq_no = use_credit.asset_id
        AND loan_apply.pt = DATE_SUB(CURRENT_DATE(), 2)
    LEFT JOIN hive_idc.hello_prd.ods_mx_ast_asset_loan_info_df loan_info 
        ON loan_info.loan_apply_no = loan_apply.loan_apply_no 
        AND loan_info.loan_status IN (1,2,3,5)
        AND loan_info.pt = DATE_SUB(CURRENT_DATE(), 2)
    LEFT JOIN hive_idc.hello_prd.ods_mx_ast_asset_repay_plan_df repay_plan 
        ON repay_plan.loan_no = loan_info.loan_no 
        AND repay_plan.repay_plan_status IN (1,2,3,5)
        AND repay_plan.pt = DATE_SUB(CURRENT_DATE(), 2)
    LEFT JOIN (
        -- 【子查询】获取每个订单对应的额度测算记录（最接近订单创建时间的额度测算）
        -- 业务逻辑：订单创建在前，额度测算在后，需要取订单创建之后最接近的额度测算记录
        SELECT 
            credit_limit.*,
            use_credit_inner.id AS use_credit_id,
            cod_inner.observation_date,
            ROW_NUMBER() OVER (
                PARTITION BY credit_limit.cust_no, use_credit_inner.id 
                ORDER BY credit_limit.create_time ASC
            ) AS rn
        FROM customer_observation_date cod_inner
        INNER JOIN hive_idc.hello_prd.ods_mx_aprv_cust_credit_limit_df credit_limit
            ON credit_limit.cust_no = cod_inner.cust_no
            AND credit_limit.pt = DATE_SUB(CURRENT_DATE(), 2)
        INNER JOIN hive_idc.hello_prd.ods_mx_aprv_approve_use_credit_apply_df use_credit_inner
            ON credit_limit.cust_no = use_credit_inner.cust_no
            AND use_credit_inner.pt = DATE_SUB(CURRENT_DATE(), 2)
            AND credit_limit.create_time >= use_credit_inner.create_time  -- 修正：额度测算时间 >= 订单创建时间（先用信申请，再到额度测算）
            AND credit_limit.create_time <= cod_inner.observation_date  -- 只使用观察时点及之前的额度测算记录，避免时间穿越
    ) credit_limit 
        ON credit_limit.cust_no = use_credit.cust_no
        AND credit_limit.use_credit_id = use_credit.id
        AND credit_limit.rn = 1  -- 只取最接近订单创建时间的那一条额度测算记录
    WHERE repay_plan.id IS NOT NULL
        -- 修复：repay_plan.create_time也需要在观察时间点之前，才视为成功生成的订单记录
        -- 确保只有repay_plan.create_time <= observation_date的记录才被视为有效订单记录
        AND repay_plan.create_time <= cod.observation_date
),

-- ===================== 1.1 订单最大期数（用于计算订单结清时间） =====================
order_max_periods AS (
    SELECT 
        cust_no,
        loan_no,
        MAX(periods) AS max_periods
    FROM base_loan_data_light
    GROUP BY cust_no, loan_no
),

-- ===================== 2. 订单级别聚合（用于计算订单维度的特征） =====================
order_level_stats AS (
    SELECT 
        bld.cust_no,
        bld.loan_no,
        -- 添加observation_date字段（同一订单的observation_date应该一致，使用MAX或MIN均可）
        MAX(bld.observation_date) AS observation_date,
        MIN(bld.order_create_time) AS order_create_time,  -- 订单创建时间（use_credit表的create_time）
        MIN(bld.loan_start_date) AS loan_start_date,
        MIN(bld.calc_credit_time) AS calc_credit_time,
        MIN(bld.first_credit_time) AS first_credit_time,  -- 首次授信时间（credit_apply表的create_time）
        MAX(bld.loan_amt) AS loan_amt,
        MAX(bld.periods) AS periods,
        MAX(bld.order_apply_hour) AS order_apply_hour,
        MAX(bld.is_weekend_order) AS is_weekend_order,
        -- 订单是否结清（只统计观察日期及之前已结清的订单）
        -- 修复：一笔订单有多笔不同periods的账单，只有在所有账单均已结清(settled_time不为NULL且<=观察时间)情况下，订单才算是结清
        -- 逻辑：只有当订单下所有账单的is_complete_new都为1时，订单才算结清
        -- 使用MIN(is_complete_new)：如果所有账单都是1，那么最小值就是1；如果有任何一个账单是0，最小值就是0
        CASE WHEN MIN(bld.is_complete_new) = 1 THEN 1 ELSE 0 END AS is_order_complete,
        -- 订单结清时间（按各订单最大期数periods的账单的结清时间作为订单结清时间）
        -- 修复：只使用观察日期及之前的结清时间，避免时间穿越
        -- 注意：只有当订单下所有账单都结清时（is_order_complete=1），order_complete_time才有意义
        -- 逻辑：使用各订单最大期数periods的账单的结清时间作为订单结清时间
        MAX(CASE 
            WHEN bld.is_complete_new = 1 
                AND bld.settled_time IS NOT NULL 
                AND bld.settled_time <= bld.observation_date  -- 修复：只使用观察日期及之前的结清时间
                AND bld.periods = omp.max_periods  -- 只取最大期数periods的账单
            THEN bld.settled_time 
            ELSE NULL 
        END) AS order_complete_time,
        -- 订单实际借款天数（从放款到结清）
        -- 修复：改回原逻辑，按订单下所有账单的放款到实际还款的日期之和计算
        -- 逻辑：对于已完成订单，计算该订单下所有账单的实际借款天数总和
        --   1. 对于每个账单：
        --      - 如果放款日 > 观察日期，则视为未放款，不计算（返回0）
        --      - 如果放款日 <= 观察日期：
        --        - 如果账单已结清（settled_time IS NOT NULL 且 settled_time <= 观察日期）：
        --          * 如果settled_time < loan_start_date（结清时间早于放款时间），则实际借款天数置为0
        --          * 否则使用：结清日期 - 放款日期
        --        - 如果账单未结清（settled_time IS NULL 或 settled_time > 观察日期），则使用：观察日期 - 放款日期
        --   2. 将所有账单的实际借款天数加起来，得到订单实际借款天数
        --   3. 只有已完成订单才返回计算结果，未完成订单返回0
        CASE 
            WHEN MIN(bld.is_complete_new) = 1 THEN  -- 订单已完成（所有账单均已结清）
                SUM(CASE 
                    WHEN bld.loan_start_date IS NOT NULL 
                        AND bld.loan_start_date <= bld.observation_date  -- 放款日 <= 观察日期（已放款）
                    THEN 
                        CASE 
                            -- 账单已结清：使用结清日期 - 放款日期
                            WHEN bld.settled_time IS NOT NULL 
                                AND bld.settled_time <= bld.observation_date  -- 只使用观察日期及之前的结清时间
                            THEN 
                                CASE 
                                    -- 修复：如果settled_time < loan_start_date，则实际借款天数置为0
                                    WHEN bld.settled_time < bld.loan_start_date THEN 0
                                    ELSE DATEDIFF(DATE(bld.settled_time), DATE(bld.loan_start_date))
                                END
                            -- 账单未结清：使用观察日期 - 放款日期
                            ELSE DATEDIFF(bld.observation_date, DATE(bld.loan_start_date))
                        END
                    ELSE 0  -- 放款日 > 观察日期，视为未放款，不计算
                END)
            ELSE 0  -- 订单未完成，返回0
        END AS order_inloan_days,
        -- 订单实际借款天数（所有订单，包括未完成的）
        -- 修复：不要求订单是否完成，计算所有在观察日期前已放款的账单的实际借款天数
        -- 逻辑：
        --   1. 对于每个账单：
        --      - 如果放款日 > 观察日期，则视为未放款，不计算（返回0）
        --      - 如果放款日 <= 观察日期：
        --        - 如果账单已结清（settled_time IS NOT NULL 且 settled_time <= 观察日期）：
        --          * 如果settled_time < loan_start_date（结清时间早于放款时间），则实际借款天数置为0
        --          * 否则使用：结清日期 - 放款日期
        --        - 如果账单未结清（settled_time IS NULL 或 settled_time > 观察日期），则使用：观察日期 - 放款日期
        --   2. 将所有账单的实际借款天数加起来，得到订单实际借款天数
        -- 注意：这里使用base_loan_data_light中的原始字段（每个账单的loan_start_date和settled_time），逐个账单判断后再聚合
        SUM(CASE 
            WHEN bld.loan_start_date IS NOT NULL 
                AND bld.loan_start_date <= bld.observation_date  -- 放款日 <= 观察日期（已放款）
            THEN 
                CASE 
                    -- 账单已结清：使用结清日期 - 放款日期
                    WHEN bld.settled_time IS NOT NULL 
                        AND bld.settled_time <= bld.observation_date  -- 只使用观察日期及之前的结清时间
                    THEN 
                        CASE 
                            -- 修复：如果settled_time < loan_start_date，则实际借款天数置为0
                            WHEN bld.settled_time < bld.loan_start_date THEN 0
                            ELSE DATEDIFF(DATE(bld.settled_time), DATE(bld.loan_start_date))
                        END
                    -- 账单未结清：使用观察日期 - 放款日期
                    ELSE DATEDIFF(bld.observation_date, DATE(bld.loan_start_date))
                END
            ELSE 0  -- 放款日 > 观察日期，视为未放款，不计算
        END) AS order_inloan_days_all,  -- 所有订单的实际借款天数（包括未完成的）
        -- 订单借款期限总和（计划还款日 - 放款日期）
        -- 修复：首先确认订单是否已完成（所有账单均已结清且结清时间<=观察日期），只有已完成订单才计算
        -- 逻辑：对于已完成订单，计算该订单下所有账单的计划还款日减去放款日的总和
        -- 修复：只计算观察日期及之前已结清的账单，避免时间穿越
        -- 注意：这里使用base_loan_data_light中的原始字段（每个账单的loan_start_date），逐个账单判断后再聚合
        -- 只有当订单下所有账单的is_complete_new都为1时（即订单已完成），才计算order_loan_term
        CASE 
            WHEN MIN(bld.is_complete_new) = 1 THEN  -- 订单已完成（所有账单均已结清）
                SUM(CASE 
                    WHEN bld.is_complete_new = 1 
                        AND bld.loan_end_date IS NOT NULL 
                        AND bld.loan_start_date IS NOT NULL
                        AND DATE(bld.loan_start_date) < bld.observation_date  -- 修复：确保放款时间在观察日期之前（不包含当天）
                    THEN DATEDIFF(DATE(bld.loan_end_date), DATE(bld.loan_start_date))
                    ELSE 0 
                END)
            ELSE 0  -- 订单未完成，返回0
        END AS order_loan_term,  -- 借款期限总和（天数）
        -- 订单总逾期天数（订单下所有账单的逾期天数总和）
        -- 修复：先计算订单下所有账单的逾期天数，加总作为该订单的逾期天数
        SUM(bld.overdue_days) AS order_overdue_days_sum,
        -- 订单最大逾期天数（与订单总逾期天数相同，用于在客户维度取最大值）
        -- 修复：订单级别使用总和，客户维度取最大值
        SUM(bld.overdue_days) AS order_overdue_days_max,
        -- 订单提前结清天数总和
        -- 修复：计算订单下所有提前结清账单的提前天数总和
        -- 逻辑：先按账单聚合到订单，计算订单下所有提前结清账单的提前天数总和
        SUM(bld.prepay_days) AS order_prepay_days_sum,
        -- 订单最大提前结清天数
        MAX(bld.prepay_days) AS order_prepay_days_max,
        -- 订单提前结清笔数（账单级别）
        SUM(CASE WHEN bld.is_prepay = 1 THEN 1 ELSE 0 END) AS prepay_bill_cnt,
        -- 订单提前>=3天结清笔数（账单级别）
        SUM(CASE WHEN bld.prepay_days >= 3 THEN 1 ELSE 0 END) AS prepay_3days_bill_cnt,
        -- 订单逾期笔数（账单级别）
        SUM(CASE WHEN bld.is_overdue_new = 1 THEN 1 ELSE 0 END) AS overdue_bill_cnt,
        -- 订单逾期>=3天笔数（账单级别）
        SUM(CASE WHEN bld.overdue_days >= 3 THEN 1 ELSE 0 END) AS overdue_3days_bill_cnt,
        -- 订单是否有逾期标签（不管几天）：只要有逾期的账单，就给订单挂一个曾发生逾期标签
        CASE WHEN SUM(CASE WHEN bld.is_overdue_new = 1 THEN 1 ELSE 0 END) > 0 THEN 1 ELSE 0 END AS has_order_overdue,
        -- 订单是否有逾期>=3天标签：只要有逾期>=3天的账单，就给订单挂一个曾发生逾期>=3天标签
        CASE WHEN SUM(CASE WHEN bld.overdue_days >= 3 THEN 1 ELSE 0 END) > 0 THEN 1 ELSE 0 END AS has_order_overdue_3days,
        -- 订单是否有提前结清标签：只要有提前结清的账单，就给订单挂一个曾发生提前结清标签
        CASE WHEN SUM(CASE WHEN bld.is_prepay = 1 THEN 1 ELSE 0 END) > 0 THEN 1 ELSE 0 END AS has_order_prepay,
        -- 订单是否有提前>=3天结清标签：只要有提前>=3天结清的账单，就给订单挂一个曾发生提前>=3天结清标签
        CASE WHEN SUM(CASE WHEN bld.prepay_days >= 3 THEN 1 ELSE 0 END) > 0 THEN 1 ELSE 0 END AS has_order_prepay_3days,
        -- 订单已结清账单本金总和
        -- 修复：首先确认订单是否已完成（所有账单均已结清且结清时间<=观察日期），只有已完成订单才计算
        -- 只有当订单下所有账单的is_complete_new都为1时（即订单已完成），才计算completed_instal_principal_sum
        CASE 
            WHEN MIN(bld.is_complete_new) = 1 THEN  -- 订单已完成（所有账单均已结清）
                SUM(CASE WHEN bld.is_complete_new = 1 THEN bld.repaid_principal ELSE 0 END)
            ELSE 0  -- 订单未完成，返回0
        END AS completed_instal_principal_sum,
        -- 注意：在贷账单数不在订单维度聚合，而是在客户维度直接从账单维度统计
        -- 订单额度测算间隔（原逻辑，保留用于其他用途）
        AVG(bld.calc_credit_gap) AS calc_credit_gap,
        AVG(bld.calc_credit_gap) AS calc_credit_gap_mean
    FROM base_loan_data_light bld
    LEFT JOIN order_max_periods omp 
        ON bld.cust_no = omp.cust_no 
        AND bld.loan_no = omp.loan_no
    GROUP BY bld.cust_no, bld.loan_no
),

-- ===================== 2.1 所有观察日期前的参考时间点（settled_time和credit_apply.create_time） =====================
-- 说明：收集所有观察日期前的repay_plan.settled_time和匹配上use_credit的credit_apply.create_time
-- 逻辑：
--   1. 从base_loan_data_light中获取所有观察日期前的settled_time
--   2. 从credit_apply表中获取所有匹配上use_credit的create_time（通过use_credit.credit_apply_id = credit_apply.id）
--   3. 合并这两类时间点作为参考时间点
all_reference_times AS (
    -- 所有观察日期前的settled_time
    SELECT 
        cod.cust_no,
        bld.settled_time AS reference_time,
        cod.observation_date
    FROM customer_observation_date cod
    INNER JOIN base_loan_data_light bld 
        ON cod.cust_no = bld.cust_no
        AND bld.settled_time IS NOT NULL
        AND bld.settled_time <= cod.observation_date  -- 只使用观察日期及之前的settled_time
    
    UNION ALL
    
    -- 所有匹配上use_credit的credit_apply.create_time（观察日期前）
    SELECT 
        cod.cust_no,
        credit_apply.create_time AS reference_time,
        cod.observation_date
    FROM customer_observation_date cod
    INNER JOIN hive_idc.hello_prd.ods_mx_aprv_approve_use_credit_apply_df use_credit
        ON use_credit.cust_no = cod.cust_no
        AND use_credit.pt = DATE_SUB(CURRENT_DATE(), 2)
    INNER JOIN hive_idc.hello_prd.ods_mx_aprv_approve_credit_apply_df credit_apply 
        ON credit_apply.id = CAST(use_credit.credit_apply_id AS STRING)
        AND credit_apply.pt = DATE_SUB(CURRENT_DATE(), 2)
        AND credit_apply.create_time <= cod.observation_date  -- 只使用观察日期及之前的credit_apply.create_time
),

-- ===================== 2.2 每个订单创建时间往前最近的参考时间点（settled_time或credit_apply.create_time） =====================
-- 说明：对于每个use_credit.create_time，找到该客户所有参考时间点中往前最近的一个（无论是settled_time还是credit_apply.create_time）
-- 逻辑：精确到秒进行匹配，找到小于use_credit.create_time的最大参考时间点
order_prev_reference_time AS (
    SELECT 
        ols.cust_no,
        ols.loan_no,
        ols.order_create_time,
        ols.observation_date,
        -- 找到该订单创建时间往前最近的参考时间点（精确到秒）
        -- 逻辑：在该客户所有参考时间点中，找到小于order_create_time的最大值
        MAX(CASE 
            WHEN art.reference_time < ols.order_create_time  -- 精确到秒比较
            THEN art.reference_time 
            ELSE NULL 
        END) AS prev_reference_time
    FROM order_level_stats ols
    LEFT JOIN all_reference_times art 
        ON ols.cust_no = art.cust_no
        AND ols.observation_date = art.observation_date
        AND art.reference_time < ols.order_create_time  -- 只考虑该订单创建时间之前的参考时间点
    GROUP BY ols.cust_no, ols.loan_no, ols.order_create_time, ols.observation_date
),

-- ===================== 2.3 订单级别统计（添加新的额度测算间隔计算） =====================
-- 说明：计算"历次下单时间距离一次风控时间的间隔"
-- 计算逻辑：
--   1. 统计时间窗口内所有订单的use_credit.create_time
--   2. 统计所有观察日期前的repay_plan.settled_time和匹配上use_credit的credit_apply.create_time
--   3. 每个use_credit.create_time往前取最近的任意settled_time或credit_apply.create_time
--   4. 取时间间隔作为calc_credit_gap_new
--   5. 如果往前不存在settled_time或credit_apply.create_time，则为空值null
order_level_stats_with_credit_gap AS (
    SELECT 
        ols.*,
        oprt.prev_reference_time,  -- 往前最近的参考时间点（settled_time或credit_apply.create_time）
        -- 新的额度测算间隔计算逻辑
        CASE 
            -- 如果存在往前最近的参考时间点，计算时间间隔
            WHEN oprt.prev_reference_time IS NOT NULL 
            THEN GREATEST(DATEDIFF(DATE(ols.order_create_time), DATE(oprt.prev_reference_time)), 0)
            -- 如果往前不存在settled_time或credit_apply.create_time，则为空值null
            ELSE NULL
        END AS calc_credit_gap_new  -- 新的额度测算间隔（历次下单时间距离一次风控时间的间隔）
    FROM order_level_stats ols
    LEFT JOIN order_prev_reference_time oprt 
        ON ols.cust_no = oprt.cust_no 
        AND ols.loan_no = oprt.loan_no
        AND ols.order_create_time = oprt.order_create_time
        AND ols.observation_date = oprt.observation_date
),

-- ===================== 3. 续借订单标记 =====================
-- 修复：按订单创建时间从早到晚排序，除开最早一笔，其他都为续借订单
user_multi_loan_flag AS (
    SELECT 
        cust_no,
        loan_no,
        -- 按订单创建时间从早到晚排序，最早的一笔订单（rn=1）不是续借订单，其他都是续借订单
        CASE 
            WHEN ROW_NUMBER() OVER (PARTITION BY cust_no ORDER BY order_create_time ASC) = 1 THEN 0  -- 最早的一笔订单不是续借
            ELSE 1  -- 其他订单都是续借
        END AS is_multi_loan
    FROM order_level_stats_with_credit_gap
),

-- ===================== 4. 订单内连续逾期统计（账单级别） =====================
-- 修复：计算同一订单的账单，连续的periods均发生逾期的最大期数
-- 逻辑：同一订单的账单，按periods排序，找出连续逾期的最大期数（该值必然大于等于2）
bill_overdue_sequence AS (
    SELECT 
        cust_no,
        loan_no,
        periods,
        is_overdue_new,
        overdue_days,
        -- 中断标记：当账单没有逾期时，中断标记+1
        SUM(CASE WHEN is_overdue_new = 0 THEN 1 ELSE 0 END) OVER (
            PARTITION BY cust_no, loan_no 
            ORDER BY periods
        ) AS overdue_break,
        -- 中断标记（>=3天逾期）：逾期不超过3天者不视为逾期账单
        SUM(CASE WHEN overdue_days < 3 OR is_overdue_new = 0 THEN 1 ELSE 0 END) OVER (
            PARTITION BY cust_no, loan_no 
            ORDER BY periods
        ) AS overdue_3days_break
    FROM base_loan_data_light
),

bill_overdue_continuous AS (
    SELECT 
        cust_no,
        loan_no,
        -- 连续逾期期数（同一订单内，按periods排序）
        SUM(is_overdue_new) OVER (
            PARTITION BY cust_no, loan_no, overdue_break 
            ORDER BY periods
        ) AS continuous_overdue_periods,
        -- 连续逾期>=3天期数
        SUM(CASE WHEN overdue_days >= 3 THEN 1 ELSE 0 END) OVER (
            PARTITION BY cust_no, loan_no, overdue_3days_break 
            ORDER BY periods
        ) AS continuous_overdue_3days_periods
    FROM bill_overdue_sequence
),

-- 订单内连续逾期的最大期数
order_max_continuous_overdue AS (
    SELECT 
        cust_no,
        loan_no,
        -- 订单内连续逾期的最大期数（该值必然大于等于2，如果小于2则返回0）
        MAX(CASE 
            WHEN continuous_overdue_periods >= 1 THEN continuous_overdue_periods 
            ELSE 0 
        END) AS max_continuous_overdue_periods,
        -- 订单内连续逾期>=3天的最大期数（该值必然大于等于2，如果小于2则返回0）
        MAX(CASE 
            WHEN continuous_overdue_3days_periods >= 1 THEN continuous_overdue_3days_periods 
            ELSE 0 
        END) AS max_continuous_overdue_3days_periods
    FROM bill_overdue_continuous
    GROUP BY cust_no, loan_no
),

-- ===================== 5. 按时间窗口计算连续逾期订单数（修复时间窗口筛选问题） =====================
-- 说明：先按时间窗口筛选订单，再计算连续逾期订单数，确保统计逻辑正确
-- 修复：当仅取最近90天窗口的数据时，连续计数应该基于90天内的订单，而不是全部历史订单

-- 90天窗口的连续逾期订单数
order_overdue_sequence_90d AS (
    SELECT 
        ols.cust_no,
        ols.loan_no,
        ols.order_create_time,
        ols.has_order_overdue,
        ols.has_order_overdue_3days,
        -- 中断标记：当订单没有逾期标签时，中断标记+1（基于90天窗口内的订单）
        SUM(CASE WHEN ols.has_order_overdue = 0 THEN 1 ELSE 0 END) OVER (
            PARTITION BY ols.cust_no 
            ORDER BY ols.order_create_time
        ) AS overdue_break,
        -- 中断标记（>=3天逾期）
        SUM(CASE WHEN ols.has_order_overdue_3days = 0 THEN 1 ELSE 0 END) OVER (
            PARTITION BY ols.cust_no 
            ORDER BY ols.order_create_time
        ) AS overdue_3days_break
    FROM order_level_stats_with_credit_gap ols
    WHERE ols.order_create_time >= date_sub(ols.observation_date, 90)
        AND ols.order_create_time < ols.observation_date
),

order_overdue_continuous_90d AS (
    SELECT 
        cust_no,
        loan_no,
        has_order_overdue,
        has_order_overdue_3days,
        -- 连续逾期订单数（客户级别，按订单创建时间排序，基于90天窗口）
        SUM(has_order_overdue) OVER (
            PARTITION BY cust_no, overdue_break 
            ORDER BY order_create_time
        ) AS continuous_overdue_order_cnt,
        -- 连续逾期>=3天订单数（客户级别，按订单创建时间排序，基于90天窗口）
        SUM(has_order_overdue_3days) OVER (
            PARTITION BY cust_no, overdue_3days_break 
            ORDER BY order_create_time
        ) AS continuous_overdue_3days_order_cnt
    FROM order_overdue_sequence_90d
),

-- 180天窗口的连续逾期订单数
order_overdue_sequence_180d AS (
    SELECT 
        ols.cust_no,
        ols.loan_no,
        ols.order_create_time,
        ols.has_order_overdue,
        ols.has_order_overdue_3days,
        -- 中断标记：当订单没有逾期标签时，中断标记+1（基于180天窗口内的订单）
        SUM(CASE WHEN ols.has_order_overdue = 0 THEN 1 ELSE 0 END) OVER (
            PARTITION BY ols.cust_no 
            ORDER BY ols.order_create_time
        ) AS overdue_break,
        -- 中断标记（>=3天逾期）
        SUM(CASE WHEN ols.has_order_overdue_3days = 0 THEN 1 ELSE 0 END) OVER (
            PARTITION BY ols.cust_no 
            ORDER BY ols.order_create_time
        ) AS overdue_3days_break
    FROM order_level_stats_with_credit_gap ols
    WHERE ols.order_create_time >= date_sub(ols.observation_date, 180)
        AND ols.order_create_time < ols.observation_date
),

order_overdue_continuous_180d AS (
    SELECT 
        cust_no,
        loan_no,
        has_order_overdue,
        has_order_overdue_3days,
        -- 连续逾期订单数（客户级别，按订单创建时间排序，基于180天窗口）
        SUM(has_order_overdue) OVER (
            PARTITION BY cust_no, overdue_break 
            ORDER BY order_create_time
        ) AS continuous_overdue_order_cnt,
        -- 连续逾期>=3天订单数（客户级别，按订单创建时间排序，基于180天窗口）
        SUM(has_order_overdue_3days) OVER (
            PARTITION BY cust_no, overdue_3days_break 
            ORDER BY order_create_time
        ) AS continuous_overdue_3days_order_cnt
    FROM order_overdue_sequence_180d
),

-- 10000天窗口的连续逾期订单数
order_overdue_sequence_10000d AS (
    SELECT 
        ols.cust_no,
        ols.loan_no,
        ols.order_create_time,
        ols.has_order_overdue,
        ols.has_order_overdue_3days,
        -- 中断标记：当订单没有逾期标签时，中断标记+1（基于10000天窗口内的订单）
        SUM(CASE WHEN ols.has_order_overdue = 0 THEN 1 ELSE 0 END) OVER (
            PARTITION BY ols.cust_no 
            ORDER BY ols.order_create_time
        ) AS overdue_break,
        -- 中断标记（>=3天逾期）
        SUM(CASE WHEN ols.has_order_overdue_3days = 0 THEN 1 ELSE 0 END) OVER (
            PARTITION BY ols.cust_no 
            ORDER BY ols.order_create_time
        ) AS overdue_3days_break
    FROM order_level_stats_with_credit_gap ols
    WHERE ols.order_create_time >= date_sub(ols.observation_date, 10000)
        AND ols.order_create_time < ols.observation_date
),

order_overdue_continuous_10000d AS (
    SELECT 
        cust_no,
        loan_no,
        has_order_overdue,
        has_order_overdue_3days,
        -- 连续逾期订单数（客户级别，按订单创建时间排序，基于10000天窗口）
        SUM(has_order_overdue) OVER (
            PARTITION BY cust_no, overdue_break 
            ORDER BY order_create_time
        ) AS continuous_overdue_order_cnt,
        -- 连续逾期>=3天订单数（客户级别，按订单创建时间排序，基于10000天窗口）
        SUM(has_order_overdue_3days) OVER (
            PARTITION BY cust_no, overdue_3days_break 
            ORDER BY order_create_time
        ) AS continuous_overdue_3days_order_cnt
    FROM order_overdue_sequence_10000d
),

-- ===================== 5.1 在贷账单数和已结清账单本金预计算（避免StarRocks关联子查询限制） =====================
uncompleted_instal_stats AS (
    SELECT 
        bld.cust_no,
        bld.observation_date,
        -- 90天在贷账单数
        SUM(CASE 
            WHEN bld.order_create_time >= date_sub(bld.observation_date, 90)
                AND bld.order_create_time < bld.observation_date
                AND bld.loan_start_date IS NOT NULL 
                AND DATE(bld.loan_start_date) < bld.observation_date
                AND (bld.settled_time IS NULL OR DATE(bld.settled_time) > bld.observation_date)
            THEN 1 
            ELSE 0 
        END) AS uncompleted_instal_cnt_90d,
        -- 180天在贷账单数
        SUM(CASE 
            WHEN bld.order_create_time >= date_sub(bld.observation_date, 180)
                AND bld.order_create_time < bld.observation_date
                AND bld.loan_start_date IS NOT NULL 
                AND DATE(bld.loan_start_date) < bld.observation_date
                AND (bld.settled_time IS NULL OR DATE(bld.settled_time) > bld.observation_date)
            THEN 1 
            ELSE 0 
        END) AS uncompleted_instal_cnt_180d,
        -- 10000天在贷账单数
        SUM(CASE 
            WHEN bld.order_create_time >= date_sub(bld.observation_date, 10000)
                AND bld.order_create_time < bld.observation_date
                AND bld.loan_start_date IS NOT NULL 
                AND DATE(bld.loan_start_date) < bld.observation_date
                AND (bld.settled_time IS NULL OR DATE(bld.settled_time) > bld.observation_date)
            THEN 1 
            ELSE 0 
        END) AS uncompleted_instal_cnt_10000d,
        -- 180天已结清账单本金总和
        SUM(CASE 
            WHEN bld.order_create_time >= date_sub(bld.observation_date, 180)
                AND bld.order_create_time < bld.observation_date
                AND bld.settled_time IS NOT NULL 
                AND bld.settled_time <= bld.observation_date
            THEN bld.repaid_principal 
            ELSE 0 
        END) AS completed_instal_principal_sum_180d,
        -- 10000天已结清账单本金总和
        SUM(CASE 
            WHEN bld.order_create_time >= date_sub(bld.observation_date, 10000)
                AND bld.order_create_time < bld.observation_date
                AND bld.settled_time IS NOT NULL 
                AND bld.settled_time <= bld.observation_date
            THEN bld.repaid_principal 
            ELSE 0 
        END) AS completed_instal_principal_sum_10000d
    FROM base_loan_data_light bld
    GROUP BY bld.cust_no, bld.observation_date
),

-- ===================== 5.3 申请距离上笔结清间隔（基于账单级别settled_time，所有时间窗口） =====================
-- 说明：确定时间窗口内所有use_credit申请记录，取各申请时间，从申请时间往前看取各申请往前最近的账单settled_time，
--       作为最近一笔结清时间，两两之间的日期差为时间间隔，无需统一到订单维度
-- 逻辑：
--   1. 筛选时间窗口内的use_credit申请记录（order_create_time）
--   2. 对于每个申请记录，找到往前最近的账单settled_time（精确到秒）
--   3. 计算间隔天数：order_create_time - prev_settled_time
--   4. 聚合取最大值、最小值、平均值

-- 90天窗口：申请距离上笔结清间隔
-- 先获取唯一的申请记录（去重，因为base_loan_data_light是账单级别的）
-- 只统计approve_state为'CYCLE_PASS'或'SINGLE_PASS'的申请记录
use_credit_unique_90d AS (
    SELECT DISTINCT
        cust_no,
        order_create_time,  -- use_credit申请时间
        observation_date
    FROM base_loan_data_light
    WHERE order_create_time >= date_sub(observation_date, 90)
        AND order_create_time < observation_date  -- 排除观察日期当天的申请
        AND approve_state IN ('CYCLE_PASS', 'SINGLE_PASS')  -- 只统计通过的申请
),

use_credit_last_settled_gap_90d AS (
    SELECT 
        uc.cust_no,
        uc.order_create_time,  -- use_credit申请时间
        uc.observation_date,
        -- 找到该申请时间往前最近的settled_time（精确到秒）
        -- 在该客户所有账单的settled_time中查找
        MAX(CASE 
            WHEN bld.settled_time IS NOT NULL 
                AND bld.settled_time < uc.order_create_time  -- 精确到秒比较
            THEN bld.settled_time 
            ELSE NULL 
        END) AS prev_settled_time
    FROM use_credit_unique_90d uc
    LEFT JOIN base_loan_data_light bld 
        ON uc.cust_no = bld.cust_no
        AND bld.settled_time IS NOT NULL
        AND bld.settled_time < uc.order_create_time  -- 只考虑该申请时间之前的settled_time
    GROUP BY uc.cust_no, uc.order_create_time, uc.observation_date
),

customer_order_last_complete_gap_90d AS (
    SELECT 
        ulsg.cust_no,
        ulsg.observation_date,
        -- 计算间隔天数并聚合
        MAX(CASE 
            WHEN ulsg.prev_settled_time IS NOT NULL
            THEN DATEDIFF(DATE(ulsg.order_create_time), DATE(ulsg.prev_settled_time))
            ELSE NULL 
        END) AS orderLastCompleteGapMax,
        ROUND(AVG(CASE 
            WHEN ulsg.prev_settled_time IS NOT NULL
            THEN DATEDIFF(DATE(ulsg.order_create_time), DATE(ulsg.prev_settled_time))
            ELSE NULL 
        END), 6) AS orderLastCompleteGapMean,
        MIN(CASE 
            WHEN ulsg.prev_settled_time IS NOT NULL
            THEN DATEDIFF(DATE(ulsg.order_create_time), DATE(ulsg.prev_settled_time))
            ELSE NULL 
        END) AS orderLastCompleteGapMin
    FROM use_credit_last_settled_gap_90d ulsg
    GROUP BY ulsg.cust_no, ulsg.observation_date
),

-- 180天窗口：申请距离上笔结清间隔
-- 先获取唯一的申请记录（去重，因为base_loan_data_light是账单级别的）
-- 只统计approve_state为'CYCLE_PASS'或'SINGLE_PASS'的申请记录
use_credit_unique_180d AS (
    SELECT DISTINCT
        cust_no,
        order_create_time,  -- use_credit申请时间
        observation_date
    FROM base_loan_data_light
    WHERE order_create_time >= date_sub(observation_date, 180)
        AND order_create_time < observation_date  -- 排除观察日期当天的申请
        AND approve_state IN ('CYCLE_PASS', 'SINGLE_PASS')  -- 只统计通过的申请
),

use_credit_last_settled_gap_180d AS (
    SELECT 
        uc.cust_no,
        uc.order_create_time,  -- use_credit申请时间
        uc.observation_date,
        -- 找到该申请时间往前最近的settled_time（精确到秒）
        -- 在该客户所有账单的settled_time中查找
        MAX(CASE 
            WHEN bld.settled_time IS NOT NULL 
                AND bld.settled_time < uc.order_create_time  -- 精确到秒比较
            THEN bld.settled_time 
            ELSE NULL 
        END) AS prev_settled_time
    FROM use_credit_unique_180d uc
    LEFT JOIN base_loan_data_light bld 
        ON uc.cust_no = bld.cust_no
        AND bld.settled_time IS NOT NULL
        AND bld.settled_time < uc.order_create_time  -- 只考虑该申请时间之前的settled_time
    GROUP BY uc.cust_no, uc.order_create_time, uc.observation_date
),

customer_order_last_complete_gap_180d AS (
    SELECT 
        ulsg.cust_no,
        ulsg.observation_date,
        -- 计算间隔天数并聚合
        MAX(CASE 
            WHEN ulsg.prev_settled_time IS NOT NULL
            THEN DATEDIFF(DATE(ulsg.order_create_time), DATE(ulsg.prev_settled_time))
            ELSE NULL 
        END) AS orderLastCompleteGapMax,
        ROUND(AVG(CASE 
            WHEN ulsg.prev_settled_time IS NOT NULL
            THEN DATEDIFF(DATE(ulsg.order_create_time), DATE(ulsg.prev_settled_time))
            ELSE NULL 
        END), 6) AS orderLastCompleteGapMean,
        MIN(CASE 
            WHEN ulsg.prev_settled_time IS NOT NULL
            THEN DATEDIFF(DATE(ulsg.order_create_time), DATE(ulsg.prev_settled_time))
            ELSE NULL 
        END) AS orderLastCompleteGapMin
    FROM use_credit_last_settled_gap_180d ulsg
    GROUP BY ulsg.cust_no, ulsg.observation_date
),

-- 10000天窗口：申请距离上笔结清间隔
-- 先获取唯一的申请记录（去重，因为base_loan_data_light是账单级别的）
-- 只统计approve_state为'CYCLE_PASS'或'SINGLE_PASS'的申请记录
use_credit_unique_10000d AS (
    SELECT DISTINCT
        cust_no,
        order_create_time,  -- use_credit申请时间
        observation_date
    FROM base_loan_data_light
    WHERE order_create_time >= date_sub(observation_date, 10000)
        AND order_create_time < observation_date  -- 排除观察日期当天的申请
        AND approve_state IN ('CYCLE_PASS', 'SINGLE_PASS')  -- 只统计通过的申请
),

use_credit_last_settled_gap_10000d AS (
    SELECT 
        uc.cust_no,
        uc.order_create_time,  -- use_credit申请时间
        uc.observation_date,
        -- 找到该申请时间往前最近的settled_time（精确到秒）
        -- 在该客户所有账单的settled_time中查找
        MAX(CASE 
            WHEN bld.settled_time IS NOT NULL 
                AND bld.settled_time < uc.order_create_time  -- 精确到秒比较
            THEN bld.settled_time 
            ELSE NULL 
        END) AS prev_settled_time
    FROM use_credit_unique_10000d uc
    LEFT JOIN base_loan_data_light bld 
        ON uc.cust_no = bld.cust_no
        AND bld.settled_time IS NOT NULL
        AND bld.settled_time < uc.order_create_time  -- 只考虑该申请时间之前的settled_time
    GROUP BY uc.cust_no, uc.order_create_time, uc.observation_date
),

customer_order_last_complete_gap_10000d AS (
    SELECT 
        ulsg.cust_no,
        ulsg.observation_date,
        -- 计算间隔天数并聚合
        MAX(CASE 
            WHEN ulsg.prev_settled_time IS NOT NULL
            THEN DATEDIFF(DATE(ulsg.order_create_time), DATE(ulsg.prev_settled_time))
            ELSE NULL 
        END) AS orderLastCompleteGapMax,
        ROUND(AVG(CASE 
            WHEN ulsg.prev_settled_time IS NOT NULL
            THEN DATEDIFF(DATE(ulsg.order_create_time), DATE(ulsg.prev_settled_time))
            ELSE NULL 
        END), 6) AS orderLastCompleteGapMean,
        MIN(CASE 
            WHEN ulsg.prev_settled_time IS NOT NULL
            THEN DATEDIFF(DATE(ulsg.order_create_time), DATE(ulsg.prev_settled_time))
            ELSE NULL 
        END) AS orderLastCompleteGapMin
    FROM use_credit_last_settled_gap_10000d ulsg
    GROUP BY ulsg.cust_no, ulsg.observation_date
),

-- ===================== 6. 近90天贷中行为特征（32个） =====================
stat90D_base AS (
    SELECT 
        ols.cust_no,
        ols.loan_no,
        ols.observation_date,  -- 添加observation_date字段
        ols.order_create_time,
        ols.loan_start_date,
        ols.calc_credit_time,
        ols.order_apply_hour,
        ols.is_weekend_order,
        ols.is_order_complete,
        ols.order_complete_time,
        ols.order_inloan_days,
        ols.order_inloan_days_all,  -- 所有订单的实际借款天数（包括未完成的）
        ols.order_loan_term,  -- 订单借款期限（计划还款日 - 放款日期）
        ols.periods,
        ols.order_overdue_days_max,
        ols.order_overdue_days_sum,
        ols.order_prepay_days_sum,
        ols.order_prepay_days_max,
        ols.prepay_bill_cnt,
        ols.prepay_3days_bill_cnt,
        ols.overdue_bill_cnt,
        ols.overdue_3days_bill_cnt,
        ols.has_order_overdue,  -- 订单是否有逾期标签（用于统计逾期订单数量）
        ols.has_order_overdue_3days,  -- 订单是否有逾期>=3天标签（用于统计逾期>=3天订单数量）
        ols.has_order_prepay,  -- 订单是否有提前结清标签（用于统计提前结清订单数量）
        ols.has_order_prepay_3days,  -- 订单是否有提前>=3天结清标签（用于统计提前>=3天结清订单数量）
        ols.completed_instal_principal_sum,
        ols.calc_credit_gap_new AS calc_credit_gap,  -- 使用新的额度测算间隔计算逻辑
        mlf.is_multi_loan,
        omco.max_continuous_overdue_periods,  -- 订单内连续逾期的最大期数（账单级别）
        omco.max_continuous_overdue_3days_periods,  -- 订单内连续逾期>=3天的最大期数（账单级别）
        ooc90d.continuous_overdue_order_cnt,  -- 连续逾期订单数（客户级别，基于90天窗口）
        ooc90d.continuous_overdue_3days_order_cnt  -- 连续逾期>=3天订单数（客户级别，基于90天窗口）
    FROM order_level_stats_with_credit_gap ols
    LEFT JOIN user_multi_loan_flag mlf 
        ON ols.cust_no = mlf.cust_no AND ols.loan_no = mlf.loan_no
    LEFT JOIN order_max_continuous_overdue omco 
        ON ols.cust_no = omco.cust_no AND ols.loan_no = omco.loan_no
    LEFT JOIN order_overdue_continuous_90d ooc90d 
        ON ols.cust_no = ooc90d.cust_no AND ols.loan_no = ooc90d.loan_no
    WHERE ols.order_create_time >= date_sub(ols.observation_date, 90)
        AND ols.order_create_time < ols.observation_date  -- 修改：排除观察日期当天的订单（即最新申请的订单）
),

stat90D AS (
    SELECT 
        base.cust_no,
        base.observation_date,  -- 添加observation_date字段
        MAX(base.order_create_time) AS order_create_time,  -- 最新订单创建时间
        -- calcCreditGapMean: 历次下单时间距离一次风控时间的平均天数间隔
        -- 计算逻辑：
        --   1. 统计时间窗口内所有订单的use_credit.create_time
        --   2. 统计所有观察日期前的repay_plan.settled_time和匹配上use_credit的credit_apply.create_time
        --   3. 每个use_credit.create_time往前取最近的任意settled_time或credit_apply.create_time
        --   4. 取时间间隔作为calc_credit_gap_new
        --   5. 如果往前不存在settled_time或credit_apply.create_time，则为空值null
        --   6. 对所有订单的差值取平均值（NULL值会被AVG函数忽略）
        ROUND(AVG(base.calc_credit_gap), 6) AS calcCreditGapMean,
        
        -- completeMultiLoanOrderCnt: 历史结清续借订单数
        COUNT(DISTINCT CASE WHEN base.is_order_complete = 1 AND base.is_multi_loan = 1 THEN base.loan_no ELSE NULL END) AS completeMultiLoanOrderCnt,
        
        -- completeOrderCnt: 历史结清订单数
        COUNT(DISTINCT CASE WHEN base.is_order_complete = 1 THEN base.loan_no ELSE NULL END) AS completeOrderCnt,
        
        -- completeMultiLoanVsCompleteOrderRatio: 历史结清续借订单占比
        ROUND(CASE 
            WHEN COUNT(DISTINCT CASE WHEN base.is_order_complete = 1 THEN base.loan_no ELSE NULL END) > 0
            THEN COUNT(DISTINCT CASE WHEN base.is_order_complete = 1 AND base.is_multi_loan = 1 THEN base.loan_no ELSE NULL END) / 
                 CAST(COUNT(DISTINCT CASE WHEN base.is_order_complete = 1 THEN base.loan_no ELSE NULL END) AS DOUBLE)
            ELSE 0 
        END, 6) AS completeMultiLoanVsCompleteOrderRatio,
        
        -- payoutOrderCnt: 历史完成打款订单数
        COUNT(DISTINCT CASE WHEN base.loan_start_date IS NOT NULL THEN base.loan_no ELSE NULL END) AS payoutOrderCnt,
        
        -- completeMultiLoanVsPayoutOrderRatio: 历史结清续借订单占放款订单占比
        ROUND(CASE 
            WHEN COUNT(DISTINCT CASE WHEN base.loan_start_date IS NOT NULL THEN base.loan_no ELSE NULL END) > 0
            THEN CAST(COUNT(DISTINCT CASE WHEN base.is_order_complete = 1 AND base.is_multi_loan = 1 THEN base.loan_no ELSE NULL END) AS DOUBLE) / 
                 CAST(COUNT(DISTINCT CASE WHEN base.loan_start_date IS NOT NULL THEN base.loan_no ELSE NULL END) AS DOUBLE)
            ELSE 0 
        END, 6) AS completeMultiLoanVsPayoutOrderRatio,
        
        -- completeOrderInloanDaysCnt: 历史完成订单总实际借款天数
        -- 计算逻辑：所有已完成订单的所有账单（实际还款日 - 放款日）的总和
        -- 先按订单聚合（order_inloan_days = 订单下所有已结清账单的（实际还款日 - 放款日）总和）
        -- 再在所有已完成订单上求和
        SUM(CASE WHEN base.is_order_complete = 1 THEN base.order_inloan_days ELSE 0 END) AS completeOrderInloanDaysCnt,
        
        -- completeOrderInloanDaysAvg: 历史完成订单平均每个订单的总实际借款天数
        -- 计算逻辑：所有已完成订单的 order_inloan_days 的平均值
        -- 其中 order_inloan_days = 订单下所有已结清账单的（实际还款日 - 放款日）总和
        ROUND(AVG(CASE WHEN base.is_order_complete = 1 THEN base.order_inloan_days ELSE NULL END), 6) AS completeOrderInloanDaysAvg,
        
        -- completeOrderAvgInloanDaysRatio: 历史完成订单平均每笔实际借款天数 / 借款期限
        -- 计算逻辑：所有已完成订单的所有账单实际借款天数总和 / 所有已完成订单的所有账单借款期限总和
        -- 分子：所有已完成订单的所有账单（实际还款日 - 放款日）总和 = SUM(所有已完成订单的 order_inloan_days)
        -- 分母：所有已完成订单的所有账单（计划还款日 - 放款日）总和 = SUM(所有已完成订单的 order_loan_term)
        -- 借款期限 = 计划还款日（loan_end_date） - 放款日期（loan_start_date）
        ROUND(CASE 
            WHEN SUM(CASE WHEN base.is_order_complete = 1 THEN base.order_loan_term ELSE 0 END) > 0
            THEN SUM(CASE WHEN base.is_order_complete = 1 THEN base.order_inloan_days ELSE 0 END) / 
                 CAST(SUM(CASE WHEN base.is_order_complete = 1 THEN base.order_loan_term ELSE 0 END) AS DOUBLE)
            ELSE 0 
        END, 6) AS completeOrderAvgInloanDaysRatio,
        
        -- completeOrderMaxInloanDaysRatio: 历史完成订单最大实际借款天数 / 借款期限
        -- 借款期限 = 计划还款日（loan_end_date） - 放款日期（loan_start_date）
        -- 修复：先计算每个订单的比率，再取最大值，避免不同订单的分子分母混用
        ROUND(MAX(CASE 
            WHEN base.is_order_complete = 1 AND base.order_loan_term > 0 
            THEN base.order_inloan_days / CAST(base.order_loan_term AS DOUBLE)
            ELSE NULL 
        END), 6) AS completeOrderMaxInloanDaysRatio,
        
        -- completeOrderMinInloanDaysRatio: 历史完成订单最小实际借款天数 / 借款期限
        -- 借款期限 = 计划还款日（loan_end_date） - 放款日期（loan_start_date）
        -- 修复：先计算每个订单的比率，再取最小值，避免不同订单的分子分母混用
        ROUND(MIN(CASE 
            WHEN base.is_order_complete = 1 AND base.order_loan_term > 0 
            THEN base.order_inloan_days / CAST(base.order_loan_term AS DOUBLE)
            ELSE NULL 
        END), 6) AS completeOrderMinInloanDaysRatio,
        
        -- onWeekendOrderCnt: 周末申请订单数
        COUNT(DISTINCT CASE WHEN base.is_weekend_order = 1 THEN base.loan_no ELSE NULL END) AS onWeekendOrderCnt,
        
        -- onWeekendOrderOrderRatio: 周末申请订单比例
        ROUND(CASE 
            WHEN COUNT(DISTINCT base.loan_no) > 0
            THEN COUNT(DISTINCT CASE WHEN base.is_weekend_order = 1 THEN base.loan_no ELSE NULL END) / 
                 CAST(COUNT(DISTINCT base.loan_no) AS DOUBLE)
            ELSE 0 
        END, 6) AS onWeekendOrderOrderRatio,
        
        -- orderApplyHourAvg: 订单平均申请时刻
        ROUND(AVG(base.order_apply_hour), 6) AS orderApplyHourAvg,
        
        -- orderInloanDaysCnt: 历史总实际借款天数
        -- 修复：不要求订单是否完成，计算所有在观察日期前已放款的账单的实际借款天数
        -- 计算逻辑：
        --   1. 对于每个账单：
        --      - 如果放款日 > 观察日期，则视为未放款，不计算
        --      - 如果放款日 <= 观察日期：
        --        - 如果账单已结清（settled_time <= 观察日期），则使用：结清日期 - 放款日期
        --        - 如果账单未结清（settled_time IS NULL 或 settled_time > 观察日期），则使用：观察日期 - 放款日期
        --   2. 将所有账单的实际借款天数加起来，得到订单实际借款天数
        --   3. 按客户聚合得到最终值
        SUM(base.order_inloan_days_all) AS orderInloanDaysCnt,
        
        -- orderInloanDaysAvg: 历史平均每个订单的总实际借款天数
        -- 修复：不要求订单是否完成，计算所有在观察日期前已放款的账单的实际借款天数
        -- 计算逻辑：所有订单的 order_inloan_days_all 的平均值
        -- 其中 order_inloan_days_all = 订单下所有在观察日期前已放款的账单的实际借款天数总和
        ROUND(AVG(base.order_inloan_days_all), 6) AS orderInloanDaysAvg,
        
        -- orderLastCompleteGapMax: 申请距离上笔结清最大间隔天数
        -- 修复：确定时间窗口内所有use_credit申请记录，取各申请时间，从申请时间往前看取各申请往前最近的账单settled_time，
        --       作为最近一笔结清时间，两两之间的日期差为时间间隔，无需统一到订单维度，取最大值
        COALESCE(MAX(colcg90d.orderLastCompleteGapMax), 0) AS orderLastCompleteGapMax,
        
        -- orderLastCompleteGapMean: 申请距离上笔结清平均间隔天数
        -- 修复：确定时间窗口内所有use_credit申请记录，取各申请时间，从申请时间往前看取各申请往前最近的账单settled_time，
        --       作为最近一笔结清时间，两两之间的日期差为时间间隔，无需统一到订单维度，取平均值
        COALESCE(MAX(colcg90d.orderLastCompleteGapMean), 0) AS orderLastCompleteGapMean,
        
        -- orderLastCompleteGapMin: 申请距离上笔结清最小间隔天数
        -- 修复：确定时间窗口内所有use_credit申请记录，取各申请时间，从申请时间往前看取各申请往前最近的账单settled_time，
        --       作为最近一笔结清时间，两两之间的日期差为时间间隔，无需统一到订单维度，取最小值
        COALESCE(MAX(colcg90d.orderLastCompleteGapMin), 0) AS orderLastCompleteGapMin,
        
        -- orderNowMinusApplyHourAvg: 观察日期时间点的小时数—订单平均申请时刻
        -- 修复：observation_date是日期类型，使用观察日期当天的0点（即0小时）作为基准
        ROUND(HOUR(base.observation_date) - AVG(base.order_apply_hour), 6) AS orderNowMinusApplyHourAvg,
        
        -- orderOverdueDaysMax: 所有订单中逾期天数总和最大的那个订单的逾期天数总和
        -- 计算逻辑：先按账单聚合到订单（订单下所有账单的逾期天数总和），再按订单聚合到客户（取最大值）
        MAX(base.order_overdue_days_max) AS orderOverdueDaysMax,
        
        -- orderOverdueDaysSum: 所有订单的逾期天数总和
        -- 计算逻辑：先按账单聚合到订单（订单下所有账单的逾期天数总和），再按订单聚合到客户（求和）
        SUM(base.order_overdue_days_sum) AS orderOverdueDaysSum,
        
        -- orderPrepayDaysAvg: 平均每笔提前结清天数
        -- 计算逻辑：所有订单的所有提前结清账单的提前天数总和 / 所有提前结清账单数
        -- 分子：所有订单的所有提前结清账单的提前天数总和 = SUM(所有订单的 order_prepay_days_sum)
        -- 分母：所有提前结清账单数 = SUM(所有订单的 prepay_bill_cnt)
        ROUND(CASE 
            WHEN SUM(base.prepay_bill_cnt) > 0
            THEN SUM(base.order_prepay_days_sum) / CAST(SUM(base.prepay_bill_cnt) AS DOUBLE)
            ELSE 0 
        END, 6) AS orderPrepayDaysAvg,
        
        -- orderPrepayDaysMax: 最大单笔提前结清天数
        MAX(base.order_prepay_days_max) AS orderPrepayDaysMax,
        
        -- overdue3DaysMaxConsecutiveOrderCnt: 最大连续发生逾期>=3天订单数
        -- 修复：客户级别连续有逾期>=3天标签的订单数（该值必然大于等于2）
        -- 逻辑：所有订单按时间顺序，如果存在连续两个及以上的订单有逾期>=3天标签，则统计连续出现的最大值
        MAX(CASE 
            WHEN base.continuous_overdue_3days_order_cnt >= 1 THEN base.continuous_overdue_3days_order_cnt 
            ELSE 0 
        END) AS overdue3DaysMaxConsecutiveOrderCnt,
        
        -- overdue3DaysOrderCnt: 发生逾期>=3天总笔数
        SUM(base.has_order_overdue_3days) AS overdue3DaysOrderCnt,
        
        -- overdueMaxConsecutiveCnt: 最大连续发生逾期笔数
        -- 修复：同一订单的账单，连续的periods均发生逾期的最大期数
        -- 逻辑：同一订单的账单，按periods排序，找出连续逾期的最大期数，期数取max为连续发生逾期的期数，也为笔数
        --       如果只有一期逾期，认为连续发生逾期笔数为1，对于超过1笔的账单维持原逻辑
        --       这样1笔逾期也反映在最终值上，和0笔逾期进行区分
        MAX(CASE 
            WHEN base.max_continuous_overdue_periods >= 1 THEN base.max_continuous_overdue_periods 
            ELSE 0 
        END) AS overdueMaxConsecutiveCnt,
        
        -- overdueMaxConsecutiveOrderCnt: 最大连续发生逾期订单数
        -- 修复：客户级别连续有逾期标签的订单数（该值必然大于等于2）
        -- 逻辑：所有订单按时间顺序，如果存在连续两个及以上的订单有逾期标签，则统计连续出现的最大值
        MAX(CASE 
            WHEN base.continuous_overdue_order_cnt >= 1 THEN base.continuous_overdue_order_cnt 
            ELSE 0 
        END) AS overdueMaxConsecutiveOrderCnt,
        
        -- overdueOrderCnt: 发生逾期的订单总笔数
        -- 修复：先按账单维度计算逾期，后聚合到订单维度给订单打逾期标（has_order_overdue），
        --       最后按客户聚合统计订单逾期笔数
        -- 逻辑：统计有逾期标签的订单数量（has_order_overdue = 1），而不是统计逾期账单的数量
        SUM(CASE WHEN base.has_order_overdue = 1 THEN 1 ELSE 0 END) AS overdueOrderCnt,
        
        -- prepay3DaysCnt: 提前>=3天结清的笔数
        SUM(base.has_order_prepay_3days) AS prepay3DaysCnt,
        
        -- prepayOrderCnt: 提前结清的笔数
        SUM(base.has_order_prepay) AS prepayOrderCnt,
        
        -- uncompletedInstalCnt: 在贷账单数
        -- 修复：使用预计算的在贷账单数，避免StarRocks关联子查询限制
        COALESCE(MAX(uis.uncompleted_instal_cnt_90d), 0) AS uncompletedInstalCnt
    FROM stat90D_base base
    LEFT JOIN uncompleted_instal_stats uis 
        ON base.cust_no = uis.cust_no 
        AND base.observation_date = uis.observation_date
    LEFT JOIN customer_order_last_complete_gap_90d colcg90d 
        ON base.cust_no = colcg90d.cust_no 
        AND base.observation_date = colcg90d.observation_date
    GROUP BY base.cust_no, base.observation_date
),

-- ===================== 7. 近180天贷中行为特征（33个） =====================
stat180D_base AS (
    SELECT 
        ols.cust_no,
        ols.loan_no,
        ols.observation_date,  -- 添加observation_date字段
        ols.order_create_time,
        ols.loan_start_date,
        ols.calc_credit_time,
        ols.order_apply_hour,
        ols.is_weekend_order,
        ols.is_order_complete,
        ols.order_complete_time,
        ols.order_inloan_days,
        ols.order_inloan_days_all,  -- 所有订单的实际借款天数（包括未完成的）
        ols.order_loan_term,  -- 订单借款期限（计划还款日 - 放款日期）
        ols.periods,
        ols.order_overdue_days_max,
        ols.order_overdue_days_sum,
        ols.order_prepay_days_sum,
        ols.order_prepay_days_max,
        ols.prepay_bill_cnt,
        ols.prepay_3days_bill_cnt,
        ols.overdue_bill_cnt,
        ols.overdue_3days_bill_cnt,
        ols.has_order_overdue,  -- 订单是否有逾期标签（用于统计逾期订单数量）
        ols.has_order_overdue_3days,  -- 订单是否有逾期>=3天标签（用于统计逾期>=3天订单数量）
        ols.has_order_prepay,  -- 订单是否有提前结清标签（用于统计提前结清订单数量）
        ols.has_order_prepay_3days,  -- 订单是否有提前>=3天结清标签（用于统计提前>=3天结清订单数量）
        ols.completed_instal_principal_sum,
        ols.calc_credit_gap_new AS calc_credit_gap,  -- 使用新的额度测算间隔计算逻辑
        mlf.is_multi_loan,
        omco.max_continuous_overdue_periods,  -- 订单内连续逾期的最大期数（账单级别）
        omco.max_continuous_overdue_3days_periods,  -- 订单内连续逾期>=3天的最大期数（账单级别）
        ooc180d.continuous_overdue_order_cnt,  -- 连续逾期订单数（客户级别，基于180天窗口）
        ooc180d.continuous_overdue_3days_order_cnt  -- 连续逾期>=3天订单数（客户级别，基于180天窗口）
    FROM order_level_stats_with_credit_gap ols
    LEFT JOIN user_multi_loan_flag mlf 
        ON ols.cust_no = mlf.cust_no AND ols.loan_no = mlf.loan_no
    LEFT JOIN order_max_continuous_overdue omco 
        ON ols.cust_no = omco.cust_no AND ols.loan_no = omco.loan_no
    LEFT JOIN order_overdue_continuous_180d ooc180d 
        ON ols.cust_no = ooc180d.cust_no AND ols.loan_no = ooc180d.loan_no
    WHERE ols.order_create_time >= date_sub(ols.observation_date, 180)
        AND ols.order_create_time < ols.observation_date  -- 修改：排除观察日期当天的订单（即最新申请的订单）
),

stat180D AS (
    SELECT 
        base.cust_no,
        base.observation_date,  -- 添加observation_date字段
        MAX(base.order_create_time) AS order_create_time,  -- 最新订单创建时间
        ROUND(AVG(base.calc_credit_gap), 6) AS calcCreditGapMean,
        -- completedInstalPrincipalSum: 历史已结清账单本金总和
        -- 修复：改为直接从账单级别计算，不聚合到订单
        -- 逻辑：统计时间窗口内所有settled_time在观察日期之前的账单的结清本金总和
        COALESCE(MAX(uis.completed_instal_principal_sum_180d), 0) AS completedInstalPrincipalSum,
        COUNT(DISTINCT CASE WHEN base.is_order_complete = 1 AND base.is_multi_loan = 1 THEN base.loan_no ELSE NULL END) AS completeMultiLoanOrderCnt,
        ROUND(CASE 
            WHEN COUNT(DISTINCT CASE WHEN base.is_order_complete = 1 THEN base.loan_no ELSE NULL END) > 0
            THEN COUNT(DISTINCT CASE WHEN base.is_order_complete = 1 AND base.is_multi_loan = 1 THEN base.loan_no ELSE NULL END) / 
                 CAST(COUNT(DISTINCT CASE WHEN base.is_order_complete = 1 THEN base.loan_no ELSE NULL END) AS DOUBLE)
            ELSE 0 
        END, 6) AS completeMultiLoanVsCompleteOrderRatio,
        COUNT(DISTINCT CASE WHEN base.loan_start_date IS NOT NULL THEN base.loan_no ELSE NULL END) AS payoutOrderCnt,
        ROUND(CASE 
            WHEN COUNT(DISTINCT CASE WHEN base.loan_start_date IS NOT NULL THEN base.loan_no ELSE NULL END) > 0
            THEN CAST(COUNT(DISTINCT CASE WHEN base.is_order_complete = 1 AND base.is_multi_loan = 1 THEN base.loan_no ELSE NULL END) AS DOUBLE) / 
                 CAST(COUNT(DISTINCT CASE WHEN base.loan_start_date IS NOT NULL THEN base.loan_no ELSE NULL END) AS DOUBLE)
            ELSE 0 
        END, 6) AS completeMultiLoanVsPayoutOrderRatio,
        -- completeOrderAvgInloanDaysRatio: 历史完成订单平均每笔实际借款天数 / 借款期限
        -- 计算逻辑：所有已完成订单的所有账单实际借款天数总和 / 所有已完成订单的所有账单借款期限总和
        -- 分子：所有已完成订单的所有账单（实际还款日 - 放款日）总和 = SUM(所有已完成订单的 order_inloan_days)
        -- 分母：所有已完成订单的所有账单（计划还款日 - 放款日）总和 = SUM(所有已完成订单的 order_loan_term)
        -- 借款期限 = 计划还款日（loan_end_date） - 放款日期（loan_start_date）
        ROUND(CASE 
            WHEN SUM(CASE WHEN base.is_order_complete = 1 THEN base.order_loan_term ELSE 0 END) > 0
            THEN SUM(CASE WHEN base.is_order_complete = 1 THEN base.order_inloan_days ELSE 0 END) / 
                 CAST(SUM(CASE WHEN base.is_order_complete = 1 THEN base.order_loan_term ELSE 0 END) AS DOUBLE)
            ELSE 0 
        END, 6) AS completeOrderAvgInloanDaysRatio,
        COUNT(DISTINCT CASE WHEN base.is_order_complete = 1 THEN base.loan_no ELSE NULL END) AS completeOrderCnt,
        ROUND(AVG(CASE WHEN base.is_order_complete = 1 THEN base.order_inloan_days ELSE NULL END), 6) AS completeOrderInloanDaysAvg,
        SUM(CASE WHEN base.is_order_complete = 1 THEN base.order_inloan_days ELSE 0 END) AS completeOrderInloanDaysCnt,
        -- completeOrderMaxInloanDaysRatio: 历史完成订单最大实际借款天数 / 借款期限
        -- 借款期限 = 计划还款日（loan_end_date） - 放款日期（loan_start_date）
        -- 修复：先计算每个订单的比率，再取最大值，避免不同订单的分子分母混用
        ROUND(MAX(CASE 
            WHEN base.is_order_complete = 1 AND base.order_loan_term > 0 
            THEN base.order_inloan_days / CAST(base.order_loan_term AS DOUBLE)
            ELSE NULL 
        END), 6) AS completeOrderMaxInloanDaysRatio,
        -- completeOrderMinInloanDaysRatio: 历史完成订单最小实际借款天数 / 借款期限
        -- 借款期限 = 计划还款日（loan_end_date） - 放款日期（loan_start_date）
        -- 修复：先计算每个订单的比率，再取最小值，避免不同订单的分子分母混用
        ROUND(MIN(CASE 
            WHEN base.is_order_complete = 1 AND base.order_loan_term > 0 
            THEN base.order_inloan_days / CAST(base.order_loan_term AS DOUBLE)
            ELSE NULL 
        END), 6) AS completeOrderMinInloanDaysRatio,
        COUNT(DISTINCT CASE WHEN base.is_weekend_order = 1 THEN base.loan_no ELSE NULL END) AS onWeekendOrderCnt,
        ROUND(CASE 
            WHEN COUNT(DISTINCT base.loan_no) > 0
            THEN COUNT(DISTINCT CASE WHEN base.is_weekend_order = 1 THEN base.loan_no ELSE NULL END) / 
                 CAST(COUNT(DISTINCT base.loan_no) AS DOUBLE)
            ELSE 0 
        END, 6) AS onWeekendOrderOrderRatio,
        ROUND(AVG(base.order_apply_hour), 6) AS orderApplyHourAvg,
        -- orderInloanDaysAvg: 历史平均每个订单的总实际借款天数
        -- 修复：不要求订单是否完成，计算所有在观察日期前已放款的账单的实际借款天数
        -- 计算逻辑：所有订单的 order_inloan_days_all 的平均值
        -- 其中 order_inloan_days_all = 订单下所有在观察日期前已放款的账单的实际借款天数总和
        ROUND(AVG(base.order_inloan_days_all), 6) AS orderInloanDaysAvg,
        -- orderInloanDaysCnt: 历史总实际借款天数
        -- 修复：不要求订单是否完成，计算所有在观察日期前已放款的账单的实际借款天数
        -- 计算逻辑：
        --   1. 对于每个账单：
        --      - 如果放款日 > 观察日期，则视为未放款，不计算
        --      - 如果放款日 <= 观察日期：
        --        - 如果账单已结清（settled_time <= 观察日期），则使用：结清日期 - 放款日期
        --        - 如果账单未结清（settled_time IS NULL 或 settled_time > 观察日期），则使用：观察日期 - 放款日期
        --   2. 将所有账单的实际借款天数加起来，得到订单实际借款天数
        --   3. 按客户聚合得到最终值
        SUM(base.order_inloan_days_all) AS orderInloanDaysCnt,
        -- orderLastCompleteGapMax: 申请距离上笔结清最大间隔天数
        -- 修复：确定时间窗口内所有use_credit申请记录，取各申请时间，从申请时间往前看取各申请往前最近的账单settled_time，
        --       作为最近一笔结清时间，两两之间的日期差为时间间隔，无需统一到订单维度，取最大值
        COALESCE(MAX(colcg180d.orderLastCompleteGapMax), 0) AS orderLastCompleteGapMax,
        -- orderLastCompleteGapMean: 申请距离上笔结清平均间隔天数
        -- 修复：确定时间窗口内所有use_credit申请记录，取各申请时间，从申请时间往前看取各申请往前最近的账单settled_time，
        --       作为最近一笔结清时间，两两之间的日期差为时间间隔，无需统一到订单维度，取平均值
        COALESCE(MAX(colcg180d.orderLastCompleteGapMean), 0) AS orderLastCompleteGapMean,
        -- orderLastCompleteGapMin: 申请距离上笔结清最小间隔天数
        -- 修复：确定时间窗口内所有use_credit申请记录，取各申请时间，从申请时间往前看取各申请往前最近的账单settled_time，
        --       作为最近一笔结清时间，两两之间的日期差为时间间隔，无需统一到订单维度，取最小值
        COALESCE(MAX(colcg180d.orderLastCompleteGapMin), 0) AS orderLastCompleteGapMin,
        -- 修复：observation_date是日期类型，使用观察日期当天的0点（即0小时）作为基准
        ROUND(HOUR(base.observation_date) - AVG(base.order_apply_hour), 6) AS orderNowMinusApplyHourAvg,
        -- orderOverdueDaysMax: 所有订单中逾期天数总和最大的那个订单的逾期天数总和
        -- 计算逻辑：先按账单聚合到订单（订单下所有账单的逾期天数总和），再按订单聚合到客户（取最大值）
        MAX(base.order_overdue_days_max) AS orderOverdueDaysMax,
        -- orderOverdueDaysSum: 所有订单的逾期天数总和
        -- 计算逻辑：先按账单聚合到订单（订单下所有账单的逾期天数总和），再按订单聚合到客户（求和）
        SUM(base.order_overdue_days_sum) AS orderOverdueDaysSum,
        -- orderPrepayDaysAvg: 平均每笔提前结清天数
        -- 计算逻辑：所有订单的所有提前结清账单的提前天数总和 / 所有提前结清账单数
        -- 分子：所有订单的所有提前结清账单的提前天数总和 = SUM(所有订单的 order_prepay_days_sum)
        -- 分母：所有提前结清账单数 = SUM(所有订单的 prepay_bill_cnt)
        ROUND(CASE 
            WHEN SUM(base.prepay_bill_cnt) > 0
            THEN SUM(base.order_prepay_days_sum) / CAST(SUM(base.prepay_bill_cnt) AS DOUBLE)
            ELSE 0 
        END, 6) AS orderPrepayDaysAvg,
        MAX(base.order_prepay_days_max) AS orderPrepayDaysMax,
        -- overdue3DaysMaxConsecutiveOrderCnt: 最大连续发生逾期>=3天订单数
        -- 修复：客户级别连续有逾期>=3天标签的订单数（该值必然大于等于2）
        -- 逻辑：所有订单按时间顺序，如果存在连续两个及以上的订单有逾期>=3天标签，则统计连续出现的最大值
        MAX(CASE 
            WHEN base.continuous_overdue_3days_order_cnt >= 1 THEN base.continuous_overdue_3days_order_cnt 
            ELSE 0 
        END) AS overdue3DaysMaxConsecutiveOrderCnt,
        SUM(base.has_order_overdue_3days) AS overdue3DaysOrderCnt,
        -- overdueMaxConsecutiveCnt: 最大连续发生逾期笔数
        -- 修复：同一订单的账单，连续的periods均发生逾期的最大期数
        -- 逻辑：同一订单的账单，按periods排序，找出连续逾期的最大期数，期数取max为连续发生逾期的期数，也为笔数
        --       如果只有一期逾期，认为连续发生逾期笔数为1，对于超过1笔的账单维持原逻辑
        --       这样1笔逾期也反映在最终值上，和0笔逾期进行区分
        MAX(CASE 
            WHEN base.max_continuous_overdue_periods >= 1 THEN base.max_continuous_overdue_periods 
            ELSE 0 
        END) AS overdueMaxConsecutiveCnt,
        -- overdueMaxConsecutiveOrderCnt: 最大连续发生逾期订单数
        -- 修复：客户级别连续有逾期标签的订单数（该值必然大于等于2）
        -- 逻辑：所有订单按时间顺序，如果存在连续两个及以上的订单有逾期标签，则统计连续出现的最大值
        MAX(CASE 
            WHEN base.continuous_overdue_order_cnt >= 1 THEN base.continuous_overdue_order_cnt 
            ELSE 0 
        END) AS overdueMaxConsecutiveOrderCnt,
        -- overdueOrderCnt: 发生逾期的订单总笔数
        -- 修复：先按账单维度计算逾期，后聚合到订单维度给订单打逾期标（has_order_overdue），
        --       最后按客户聚合统计订单逾期笔数
        -- 逻辑：统计有逾期标签的订单数量（has_order_overdue = 1），而不是统计逾期账单的数量
        SUM(CASE WHEN base.has_order_overdue = 1 THEN 1 ELSE 0 END) AS overdueOrderCnt,
        SUM(base.has_order_prepay_3days) AS prepay3DaysCnt,
        SUM(base.has_order_prepay) AS prepayOrderCnt,
        -- uncompletedInstalCnt: 在贷账单数
        -- 修复：使用预计算的在贷账单数，避免StarRocks关联子查询限制
        COALESCE(MAX(uis.uncompleted_instal_cnt_180d), 0) AS uncompletedInstalCnt
    FROM stat180D_base base
    LEFT JOIN uncompleted_instal_stats uis 
        ON base.cust_no = uis.cust_no 
        AND base.observation_date = uis.observation_date
    LEFT JOIN customer_order_last_complete_gap_180d colcg180d 
        ON base.cust_no = colcg180d.cust_no 
        AND base.observation_date = colcg180d.observation_date
    GROUP BY base.cust_no, base.observation_date
),

-- ===================== 8. 近10000天贷中行为特征（33个） =====================
stat10000D_base AS (
    SELECT 
        ols.cust_no,
        ols.loan_no,
        ols.observation_date,  -- 添加observation_date字段
        ols.order_create_time,
        ols.loan_start_date,
        ols.calc_credit_time,
        ols.order_apply_hour,
        ols.is_weekend_order,
        ols.is_order_complete,
        ols.order_complete_time,
        ols.order_inloan_days,
        ols.order_inloan_days_all,  -- 所有订单的实际借款天数（包括未完成的）
        ols.order_loan_term,  -- 订单借款期限（计划还款日 - 放款日期）
        ols.periods,
        ols.order_overdue_days_max,
        ols.order_overdue_days_sum,
        ols.order_prepay_days_sum,
        ols.order_prepay_days_max,
        ols.prepay_bill_cnt,
        ols.prepay_3days_bill_cnt,
        ols.overdue_bill_cnt,
        ols.overdue_3days_bill_cnt,
        ols.has_order_overdue,  -- 订单是否有逾期标签（用于统计逾期订单数量）
        ols.has_order_overdue_3days,  -- 订单是否有逾期>=3天标签（用于统计逾期>=3天订单数量）
        ols.has_order_prepay,  -- 订单是否有提前结清标签（用于统计提前结清订单数量）
        ols.has_order_prepay_3days,  -- 订单是否有提前>=3天结清标签（用于统计提前>=3天结清订单数量）
        ols.completed_instal_principal_sum,
        ols.calc_credit_gap_new AS calc_credit_gap,  -- 使用新的额度测算间隔计算逻辑
        mlf.is_multi_loan,
        omco.max_continuous_overdue_periods,  -- 订单内连续逾期的最大期数（账单级别）
        omco.max_continuous_overdue_3days_periods,  -- 订单内连续逾期>=3天的最大期数（账单级别）
        ooc10000d.continuous_overdue_order_cnt,  -- 连续逾期订单数（客户级别，基于10000天窗口）
        ooc10000d.continuous_overdue_3days_order_cnt  -- 连续逾期>=3天订单数（客户级别，基于10000天窗口）
    FROM order_level_stats_with_credit_gap ols
    LEFT JOIN user_multi_loan_flag mlf 
        ON ols.cust_no = mlf.cust_no AND ols.loan_no = mlf.loan_no
    LEFT JOIN order_max_continuous_overdue omco 
        ON ols.cust_no = omco.cust_no AND ols.loan_no = omco.loan_no
    LEFT JOIN order_overdue_continuous_10000d ooc10000d 
        ON ols.cust_no = ooc10000d.cust_no AND ols.loan_no = ooc10000d.loan_no
    WHERE ols.order_create_time >= date_sub(ols.observation_date, 10000)
        AND ols.order_create_time < ols.observation_date  -- 修改：排除观察日期当天的订单（即最新申请的订单）
),

stat10000D AS (
    SELECT 
        base.cust_no,
        base.observation_date,  -- 添加observation_date字段
        MAX(base.order_create_time) AS order_create_time,  -- 最新订单创建时间
        ROUND(AVG(base.calc_credit_gap), 6) AS calcCreditGapMean,
        -- completedInstalPrincipalSum: 历史已结清账单本金总和
        -- 修复：改为直接从账单级别计算，不聚合到订单
        -- 逻辑：统计时间窗口内所有settled_time在观察日期之前的账单的结清本金总和
        COALESCE(MAX(uis.completed_instal_principal_sum_10000d), 0) AS completedInstalPrincipalSum,
        COUNT(DISTINCT CASE WHEN base.is_order_complete = 1 AND base.is_multi_loan = 1 THEN base.loan_no ELSE NULL END) AS completeMultiLoanOrderCnt,
        ROUND(CASE 
            WHEN COUNT(DISTINCT CASE WHEN base.is_order_complete = 1 THEN base.loan_no ELSE NULL END) > 0
            THEN COUNT(DISTINCT CASE WHEN base.is_order_complete = 1 AND base.is_multi_loan = 1 THEN base.loan_no ELSE NULL END) / 
                 CAST(COUNT(DISTINCT CASE WHEN base.is_order_complete = 1 THEN base.loan_no ELSE NULL END) AS DOUBLE)
            ELSE 0 
        END, 6) AS completeMultiLoanVsCompleteOrderRatio,
        COUNT(DISTINCT CASE WHEN base.loan_start_date IS NOT NULL THEN base.loan_no ELSE NULL END) AS payoutOrderCnt,
        ROUND(CASE 
            WHEN COUNT(DISTINCT CASE WHEN base.loan_start_date IS NOT NULL THEN base.loan_no ELSE NULL END) > 0
            THEN CAST(COUNT(DISTINCT CASE WHEN base.is_order_complete = 1 AND base.is_multi_loan = 1 THEN base.loan_no ELSE NULL END) AS DOUBLE) / 
                 CAST(COUNT(DISTINCT CASE WHEN base.loan_start_date IS NOT NULL THEN base.loan_no ELSE NULL END) AS DOUBLE)
            ELSE 0 
        END, 6) AS completeMultiLoanVsPayoutOrderRatio,
        -- completeOrderAvgInloanDaysRatio: 历史完成订单平均每笔实际借款天数 / 借款期限
        -- 计算逻辑：所有已完成订单的所有账单实际借款天数总和 / 所有已完成订单的所有账单借款期限总和
        -- 分子：所有已完成订单的所有账单（实际还款日 - 放款日）总和 = SUM(所有已完成订单的 order_inloan_days)
        -- 分母：所有已完成订单的所有账单（计划还款日 - 放款日）总和 = SUM(所有已完成订单的 order_loan_term)
        -- 借款期限 = 计划还款日（loan_end_date） - 放款日期（loan_start_date）
        ROUND(CASE 
            WHEN SUM(CASE WHEN base.is_order_complete = 1 THEN base.order_loan_term ELSE 0 END) > 0
            THEN SUM(CASE WHEN base.is_order_complete = 1 THEN base.order_inloan_days ELSE 0 END) / 
                 CAST(SUM(CASE WHEN base.is_order_complete = 1 THEN base.order_loan_term ELSE 0 END) AS DOUBLE)
            ELSE 0 
        END, 6) AS completeOrderAvgInloanDaysRatio,
        COUNT(DISTINCT CASE WHEN base.is_order_complete = 1 THEN base.loan_no ELSE NULL END) AS completeOrderCnt,
        ROUND(AVG(CASE WHEN base.is_order_complete = 1 THEN base.order_inloan_days ELSE NULL END), 6) AS completeOrderInloanDaysAvg,
        SUM(CASE WHEN base.is_order_complete = 1 THEN base.order_inloan_days ELSE 0 END) AS completeOrderInloanDaysCnt,
        -- completeOrderMaxInloanDaysRatio: 历史完成订单最大实际借款天数 / 借款期限
        -- 借款期限 = 计划还款日（loan_end_date） - 放款日期（loan_start_date）
        -- 修复：先计算每个订单的比率，再取最大值，避免不同订单的分子分母混用
        ROUND(MAX(CASE 
            WHEN base.is_order_complete = 1 AND base.order_loan_term > 0 
            THEN base.order_inloan_days / CAST(base.order_loan_term AS DOUBLE)
            ELSE NULL 
        END), 6) AS completeOrderMaxInloanDaysRatio,
        -- completeOrderMinInloanDaysRatio: 历史完成订单最小实际借款天数 / 借款期限
        -- 借款期限 = 计划还款日（loan_end_date） - 放款日期（loan_start_date）
        -- 修复：先计算每个订单的比率，再取最小值，避免不同订单的分子分母混用
        ROUND(MIN(CASE 
            WHEN base.is_order_complete = 1 AND base.order_loan_term > 0 
            THEN base.order_inloan_days / CAST(base.order_loan_term AS DOUBLE)
            ELSE NULL 
        END), 6) AS completeOrderMinInloanDaysRatio,
        COUNT(DISTINCT CASE WHEN base.is_weekend_order = 1 THEN base.loan_no ELSE NULL END) AS onWeekendOrderCnt,
        ROUND(CASE 
            WHEN COUNT(DISTINCT base.loan_no) > 0
            THEN COUNT(DISTINCT CASE WHEN base.is_weekend_order = 1 THEN base.loan_no ELSE NULL END) / 
                 CAST(COUNT(DISTINCT base.loan_no) AS DOUBLE)
            ELSE 0 
        END, 6) AS onWeekendOrderOrderRatio,
        ROUND(AVG(base.order_apply_hour), 6) AS orderApplyHourAvg,
        -- orderInloanDaysAvg: 历史平均每个订单的总实际借款天数
        -- 修复：不要求订单是否完成，计算所有在观察日期前已放款的账单的实际借款天数
        -- 计算逻辑：所有订单的 order_inloan_days_all 的平均值
        -- 其中 order_inloan_days_all = 订单下所有在观察日期前已放款的账单的实际借款天数总和
        ROUND(AVG(base.order_inloan_days_all), 6) AS orderInloanDaysAvg,
        -- orderInloanDaysCnt: 历史总实际借款天数
        -- 修复：不要求订单是否完成，计算所有在观察日期前已放款的账单的实际借款天数
        -- 计算逻辑：
        --   1. 对于每个账单：
        --      - 如果放款日 > 观察日期，则视为未放款，不计算
        --      - 如果放款日 <= 观察日期：
        --        - 如果账单已结清（settled_time <= 观察日期），则使用：结清日期 - 放款日期
        --        - 如果账单未结清（settled_time IS NULL 或 settled_time > 观察日期），则使用：观察日期 - 放款日期
        --   2. 将所有账单的实际借款天数加起来，得到订单实际借款天数
        --   3. 按客户聚合得到最终值
        SUM(base.order_inloan_days_all) AS orderInloanDaysCnt,
        -- orderLastCompleteGapMax: 申请距离上笔结清最大间隔天数
        -- 修复：确定时间窗口内所有use_credit申请记录，取各申请时间，从申请时间往前看取各申请往前最近的账单settled_time，
        --       作为最近一笔结清时间，两两之间的日期差为时间间隔，无需统一到订单维度，取最大值
        COALESCE(MAX(colcg10000d.orderLastCompleteGapMax), 0) AS orderLastCompleteGapMax,
        -- orderLastCompleteGapMean: 申请距离上笔结清平均间隔天数
        -- 修复：确定时间窗口内所有use_credit申请记录，取各申请时间，从申请时间往前看取各申请往前最近的账单settled_time，
        --       作为最近一笔结清时间，两两之间的日期差为时间间隔，无需统一到订单维度，取平均值
        COALESCE(MAX(colcg10000d.orderLastCompleteGapMean), 0) AS orderLastCompleteGapMean,
        -- orderLastCompleteGapMin: 申请距离上笔结清最小间隔天数
        -- 修复：确定时间窗口内所有use_credit申请记录，取各申请时间，从申请时间往前看取各申请往前最近的账单settled_time，
        --       作为最近一笔结清时间，两两之间的日期差为时间间隔，无需统一到订单维度，取最小值
        COALESCE(MAX(colcg10000d.orderLastCompleteGapMin), 0) AS orderLastCompleteGapMin,
        -- 修复：observation_date是日期类型，使用观察日期当天的0点（即0小时）作为基准
        ROUND(HOUR(base.observation_date) - AVG(base.order_apply_hour), 6) AS orderNowMinusApplyHourAvg,
        -- orderOverdueDaysMax: 所有订单中逾期天数总和最大的那个订单的逾期天数总和
        -- 计算逻辑：先按账单聚合到订单（订单下所有账单的逾期天数总和），再按订单聚合到客户（取最大值）
        MAX(base.order_overdue_days_max) AS orderOverdueDaysMax,
        -- orderOverdueDaysSum: 所有订单的逾期天数总和
        -- 计算逻辑：先按账单聚合到订单（订单下所有账单的逾期天数总和），再按订单聚合到客户（求和）
        SUM(base.order_overdue_days_sum) AS orderOverdueDaysSum,
        -- orderPrepayDaysAvg: 平均每笔提前结清天数
        -- 计算逻辑：所有订单的所有提前结清账单的提前天数总和 / 所有提前结清账单数
        -- 分子：所有订单的所有提前结清账单的提前天数总和 = SUM(所有订单的 order_prepay_days_sum)
        -- 分母：所有提前结清账单数 = SUM(所有订单的 prepay_bill_cnt)
        ROUND(CASE 
            WHEN SUM(base.prepay_bill_cnt) > 0
            THEN SUM(base.order_prepay_days_sum) / CAST(SUM(base.prepay_bill_cnt) AS DOUBLE)
            ELSE 0 
        END, 6) AS orderPrepayDaysAvg,
        MAX(base.order_prepay_days_max) AS orderPrepayDaysMax,
        -- overdue3DaysMaxConsecutiveOrderCnt: 最大连续发生逾期>=3天订单数
        -- 修复：客户级别连续有逾期>=3天标签的订单数（该值必然大于等于2）
        -- 逻辑：所有订单按时间顺序，如果存在连续两个及以上的订单有逾期>=3天标签，则统计连续出现的最大值
        MAX(CASE 
            WHEN base.continuous_overdue_3days_order_cnt >= 1 THEN base.continuous_overdue_3days_order_cnt 
            ELSE 0 
        END) AS overdue3DaysMaxConsecutiveOrderCnt,
        SUM(base.has_order_overdue_3days) AS overdue3DaysOrderCnt,
        -- overdueMaxConsecutiveCnt: 最大连续发生逾期笔数
        -- 修复：同一订单的账单，连续的periods均发生逾期的最大期数
        -- 逻辑：同一订单的账单，按periods排序，找出连续逾期的最大期数，期数取max为连续发生逾期的期数，也为笔数
        --       如果只有一期逾期，认为连续发生逾期笔数为1，对于超过1笔的账单维持原逻辑
        --       这样1笔逾期也反映在最终值上，和0笔逾期进行区分
        MAX(CASE 
            WHEN base.max_continuous_overdue_periods >= 1 THEN base.max_continuous_overdue_periods 
            ELSE 0 
        END) AS overdueMaxConsecutiveCnt,
        -- overdueMaxConsecutiveOrderCnt: 最大连续发生逾期订单数
        -- 修复：客户级别连续有逾期标签的订单数（该值必然大于等于2）
        -- 逻辑：所有订单按时间顺序，如果存在连续两个及以上的订单有逾期标签，则统计连续出现的最大值
        MAX(CASE 
            WHEN base.continuous_overdue_order_cnt >= 1 THEN base.continuous_overdue_order_cnt 
            ELSE 0 
        END) AS overdueMaxConsecutiveOrderCnt,
        -- overdueOrderCnt: 发生逾期的订单总笔数
        -- 修复：先按账单维度计算逾期，后聚合到订单维度给订单打逾期标（has_order_overdue），
        --       最后按客户聚合统计订单逾期笔数
        -- 逻辑：统计有逾期标签的订单数量（has_order_overdue = 1），而不是统计逾期账单的数量
        SUM(CASE WHEN base.has_order_overdue = 1 THEN 1 ELSE 0 END) AS overdueOrderCnt,
        SUM(base.has_order_prepay_3days) AS prepay3DaysCnt,
        SUM(base.has_order_prepay) AS prepayOrderCnt,
        -- uncompletedInstalCnt: 在贷账单数
        -- 修复：使用预计算的在贷账单数，避免StarRocks关联子查询限制
        COALESCE(MAX(uis.uncompleted_instal_cnt_10000d), 0) AS uncompletedInstalCnt
    FROM stat10000D_base base
    LEFT JOIN uncompleted_instal_stats uis 
        ON base.cust_no = uis.cust_no 
        AND base.observation_date = uis.observation_date
    LEFT JOIN customer_order_last_complete_gap_10000d colcg10000d 
        ON base.cust_no = colcg10000d.cust_no 
        AND base.observation_date = colcg10000d.observation_date
    GROUP BY base.cust_no, base.observation_date
)

-- ===================== 9. 最终输出：98个特征 =====================
select * from(
SELECT 
    use_credit.id AS use_credit_id,
    COALESCE(s90.cust_no, s180.cust_no, s10000.cust_no, '') AS cust_no,  -- 客户编号（确保无空值）
    COALESCE(s90.observation_date, s180.observation_date, s10000.observation_date, CURRENT_DATE()) AS observation_date,  -- 观察日期（确保无空值）
    -- COALESCE(s90.order_create_time, s180.order_create_time, s10000.order_create_time) AS order_create_time,  -- 最新订单创建时间
    COALESCE(s90.calcCreditGapMean, 0) AS local_midloan_order_info_stat90d_calccreditgapmean_v2,
    
    -- 1.2 订单结清相关（5个）
    COALESCE(s90.completeOrderCnt, 0) AS local_midloan_order_info_stat90d_completeordercnt_v2,  -- 历史结清订单数
    COALESCE(s90.completeMultiLoanOrderCnt, 0) AS local_midloan_order_info_stat90d_completemultiloanordercnt_v2,  -- 历史结清续借订单数
    COALESCE(s90.completeMultiLoanVsCompleteOrderRatio, 0) AS local_midloan_order_info_stat90d_completemultiloanvscompleteorderratio_v2,  -- 历史结清续借订单占比
    COALESCE(s90.completeMultiLoanVsPayoutOrderRatio, 0) AS local_midloan_order_info_stat90d_completemultiloanvspayoutorderratio_v2,  -- 历史结清续借订单占放款订单占比
    COALESCE(s90.payoutOrderCnt, 0) AS local_midloan_order_info_stat90d_payoutordercnt_v2,  -- 历史完成打款订单数
    
    -- 1.3 借款天数相关（7个）
    COALESCE(s90.completeOrderInloanDaysCnt, 0) AS local_midloan_order_info_stat90d_completeorderinloandayscnt_v2,  -- 历史完成订单总实际借款天数
    COALESCE(s90.completeOrderInloanDaysAvg, 0) AS local_midloan_order_info_stat90d_completeorderinloandaysavg_v2,  -- 历史完成订单平均每笔实际借款天数
    COALESCE(s90.completeOrderAvgInloanDaysRatio, 0) AS local_midloan_order_info_stat90d_completeorderavginloandaysratio_v2,  -- 历史完成订单平均每笔实际借款天数 / 借款期限（借款期限=计划还款日-放款日期）
    COALESCE(s90.completeOrderMaxInloanDaysRatio, 0) AS local_midloan_order_info_stat90d_completeordermaxinloandaysratio_v2,  -- 历史完成订单最大实际借款天数 / 借款期限（借款期限=计划还款日-放款日期）
    COALESCE(s90.completeOrderMinInloanDaysRatio, 0) AS local_midloan_order_info_stat90d_completeordermininloandaysratio_v2,  -- 历史完成订单最小实际借款天数 / 借款期限（借款期限=计划还款日-放款日期）
    COALESCE(s90.orderInloanDaysAvg, 0) AS local_midloan_order_info_stat90d_orderinloandaysavg_v2,  -- 历史平均每笔实际借款天数
    COALESCE(s90.orderInloanDaysCnt, 0) AS local_midloan_order_info_stat90d_orderinloandayscnt_v2,  -- 历史总实际借款天数
    
    -- 1.4 申请时间相关（4个）
    COALESCE(s90.orderApplyHourAvg, 0) AS local_midloan_order_info_stat90d_orderapplyhouravg_v2,  -- 订单平均申请时刻
    COALESCE(s90.orderNowMinusApplyHourAvg, 0) AS local_midloan_order_info_stat90d_ordernowminusapplyhouravg_v2,  -- 当前借款时间点的小时数—订单平均申请时刻
    COALESCE(s90.onWeekendOrderCnt, 0) AS local_midloan_order_info_stat90d_onweekendordercnt_v2,  -- 周末申请订单数
    COALESCE(s90.onWeekendOrderOrderRatio, 0) AS local_midloan_order_info_stat90d_onweekendorderorderratio_v2,  -- 周末申请订单比例
    
    -- 1.5 结清间隔相关（3个）
    COALESCE(s90.orderLastCompleteGapMax, 0) AS local_midloan_order_info_stat90d_orderlastcompletegapmax_v2,  -- 申请距离上笔结清最大间隔天数
    COALESCE(s90.orderLastCompleteGapMean, 0) AS local_midloan_order_info_stat90d_orderlastcompletegapmean_v2,  -- 申请距离上笔结清平均间隔天数
    COALESCE(s90.orderLastCompleteGapMin, 0) AS local_midloan_order_info_stat90d_orderlastcompletegapmin_v2,  -- 申请距离上笔结清最小间隔天数
    
    -- 1.6 逾期相关（7个）
    COALESCE(s90.orderOverdueDaysMax, 0) AS local_midloan_order_info_stat90d_orderoverduedaysmax_v2,  -- 所有订单中逾期天数总和最大的那个订单的逾期天数总和
    COALESCE(s90.orderOverdueDaysSum, 0) AS local_midloan_order_info_stat90d_orderoverduedayssum_v2,  -- 所有订单的逾期天数总和
    COALESCE(s90.overdueOrderCnt, 0) AS local_midloan_order_info_stat90d_overdueordercnt_v2,  -- 发生逾期总笔数
    COALESCE(s90.overdue3DaysOrderCnt, 0) AS local_midloan_order_info_stat90d_overdue3daysordercnt_v2,  -- 发生逾期>=3天总笔数
    COALESCE(s90.overdueMaxConsecutiveCnt, 0) AS local_midloan_order_info_stat90d_overduemaxconsecutivecnt_v2,  -- 最大连续发生逾期笔数
    COALESCE(s90.overdueMaxConsecutiveOrderCnt, 0) AS local_midloan_order_info_stat90d_overduemaxconsecutiveordercnt_v2,  -- 最大连续发生逾期订单数
    COALESCE(s90.overdue3DaysMaxConsecutiveOrderCnt, 0) AS local_midloan_order_info_stat90d_overdue3daysmaxconsecutiveordercnt_v2,  -- 最大连续发生逾期>=3天订单数
    
    -- 1.7 提前结清相关（4个）
    COALESCE(s90.orderPrepayDaysAvg, 0) AS local_midloan_order_info_stat90d_orderprepaydaysavg_v2,  -- 平均每笔提前结清天数
    COALESCE(s90.orderPrepayDaysMax, 0) AS local_midloan_order_info_stat90d_orderprepaydaysmax_v2,  -- 最大单笔提前结清天数
    COALESCE(s90.prepayOrderCnt, 0) AS local_midloan_order_info_stat90d_prepayordercnt_v2,  -- 提前结清的笔数
    COALESCE(s90.prepay3DaysCnt, 0) AS local_midloan_order_info_stat90d_prepay3dayscnt_v2,  -- 提前>=3天结清的笔数
    
    -- 1.8 在贷相关（1个）
    COALESCE(s90.uncompletedInstalCnt, 0) AS local_midloan_order_info_stat90d_uncompletedinstalcnt_v2,  -- 在贷账单数
    
    -- ===================== stat180D特征（33个）- 近180天的贷中行为特征 =====================
    -- 2.1 额度测算相关（1个）
    -- 历次下单时间距离一次风控时间的平均天数间隔
    -- 计算逻辑：
    --   1. 统计时间窗口内所有订单的use_credit.create_time
    --   2. 统计所有观察日期前的repay_plan.settled_time和匹配上use_credit的credit_apply.create_time
    --   3. 每个use_credit.create_time往前取最近的任意settled_time或credit_apply.create_time
    --   4. 取时间间隔作为calc_credit_gap_new
    --   5. 如果往前不存在settled_time或credit_apply.create_time，则为空值null
    --   6. 对所有订单的差值取平均值（NULL值会被AVG函数忽略）
    COALESCE(s180.calcCreditGapMean, 0) AS local_midloan_order_info_stat180d_calccreditgapmean_v2,
    
    -- 2.2 订单结清相关（6个）
    COALESCE(s180.completeOrderCnt, 0) AS local_midloan_order_info_stat180d_completeordercnt_v2,  -- 历史结清订单数
    COALESCE(s180.completeMultiLoanOrderCnt, 0) AS local_midloan_order_info_stat180d_completemultiloanordercnt_v2,  -- 历史结清续借订单数
    COALESCE(s180.completeMultiLoanVsCompleteOrderRatio, 0) AS local_midloan_order_info_stat180d_completemultiloanvscompleteorderratio_v2,  -- 历史结清续借订单占比
    COALESCE(s180.completeMultiLoanVsPayoutOrderRatio, 0) AS local_midloan_order_info_stat180d_completemultiloanvspayoutorderratio_v2,  -- 历史结清续借订单占放款订单占比
    COALESCE(s180.payoutOrderCnt, 0) AS local_midloan_order_info_stat180d_payoutordercnt_v2,  -- 历史完成打款订单数
    COALESCE(s180.completedInstalPrincipalSum, 0) AS local_midloan_order_info_stat180d_completedinstalprincipalsum_v2,  -- 历史已结清账单本金总和
    
    -- 2.3 借款天数相关（7个）
    COALESCE(s180.completeOrderInloanDaysCnt, 0) AS local_midloan_order_info_stat180d_completeorderinloandayscnt_v2,  -- 历史完成订单总实际借款天数
    COALESCE(s180.completeOrderInloanDaysAvg, 0) AS local_midloan_order_info_stat180d_completeorderinloandaysavg_v2,  -- 历史完成订单平均每笔实际借款天数
    COALESCE(s180.completeOrderAvgInloanDaysRatio, 0) AS local_midloan_order_info_stat180d_completeorderavginloandaysratio_v2,  -- 历史完成订单平均每笔实际借款天数 / 借款期限（借款期限=计划还款日-放款日期）
    COALESCE(s180.completeOrderMaxInloanDaysRatio, 0) AS local_midloan_order_info_stat180d_completeordermaxinloandaysratio_v2,  -- 历史完成订单最大实际借款天数 / 借款期限（借款期限=计划还款日-放款日期）
    COALESCE(s180.completeOrderMinInloanDaysRatio, 0) AS local_midloan_order_info_stat180d_completeordermininloandaysratio_v2,  -- 历史完成订单最小实际借款天数 / 借款期限（借款期限=计划还款日-放款日期）
    COALESCE(s180.orderInloanDaysAvg, 0) AS local_midloan_order_info_stat180d_orderinloandaysavg_v2,  -- 历史平均每笔实际借款天数
    COALESCE(s180.orderInloanDaysCnt, 0) AS local_midloan_order_info_stat180d_orderinloandayscnt_v2,  -- 历史总实际借款天数
    
    -- 2.4 申请时间相关（4个）
    COALESCE(s180.orderApplyHourAvg, 0) AS local_midloan_order_info_stat180d_orderapplyhouravg_v2,  -- 订单平均申请时刻
    COALESCE(s180.orderNowMinusApplyHourAvg, 0) AS local_midloan_order_info_stat180d_ordernowminusapplyhouravg_v2,  -- 当前借款时间点的小时数—订单平均申请时刻
    COALESCE(s180.onWeekendOrderCnt, 0) AS local_midloan_order_info_stat180d_onweekendordercnt_v2,  -- 周末申请订单数
    COALESCE(s180.onWeekendOrderOrderRatio, 0) AS local_midloan_order_info_stat180d_onweekendorderorderratio_v2,  -- 周末申请订单比例
    
    -- 2.5 结清间隔相关（3个）
    COALESCE(s180.orderLastCompleteGapMax, 0) AS local_midloan_order_info_stat180d_orderlastcompletegapmax_v2,  -- 申请距离上笔结清最大间隔天数
    COALESCE(s180.orderLastCompleteGapMean, 0) AS local_midloan_order_info_stat180d_orderlastcompletegapmean_v2,  -- 申请距离上笔结清平均间隔天数
    COALESCE(s180.orderLastCompleteGapMin, 0) AS local_midloan_order_info_stat180d_orderlastcompletegapmin_v2,  -- 申请距离上笔结清最小间隔天数
    
    -- 2.6 逾期相关（7个）
    COALESCE(s180.orderOverdueDaysMax, 0) AS local_midloan_order_info_stat180d_orderoverduedaysmax_v2,  -- 单笔最大逾期天数
    COALESCE(s180.orderOverdueDaysSum, 0) AS local_midloan_order_info_stat180d_orderoverduedayssum_v2,  -- 总逾期天数
    COALESCE(s180.overdueOrderCnt, 0) AS local_midloan_order_info_stat180d_overdueordercnt_v2,  -- 发生逾期总笔数
    COALESCE(s180.overdue3DaysOrderCnt, 0) AS local_midloan_order_info_stat180d_overdue3daysordercnt_v2,  -- 发生逾期>=3天总笔数
    COALESCE(s180.overdueMaxConsecutiveCnt, 0) AS local_midloan_order_info_stat180d_overduemaxconsecutivecnt_v2,  -- 最大连续发生逾期笔数
    COALESCE(s180.overdueMaxConsecutiveOrderCnt, 0) AS local_midloan_order_info_stat180d_overduemaxconsecutiveordercnt_v2,  -- 最大连续发生逾期订单数
    COALESCE(s180.overdue3DaysMaxConsecutiveOrderCnt, 0) AS local_midloan_order_info_stat180d_overdue3daysmaxconsecutiveordercnt_v2,  -- 最大连续发生逾期>=3天订单数
    
    -- 2.7 提前结清相关（4个）
    COALESCE(s180.orderPrepayDaysAvg, 0) AS local_midloan_order_info_stat180d_orderprepaydaysavg_v2,  -- 平均每笔提前结清天数
    COALESCE(s180.orderPrepayDaysMax, 0) AS local_midloan_order_info_stat180d_orderprepaydaysmax_v2,  -- 最大单笔提前结清天数
    COALESCE(s180.prepayOrderCnt, 0) AS local_midloan_order_info_stat180d_prepayordercnt_v2,  -- 提前结清的笔数
    COALESCE(s180.prepay3DaysCnt, 0) AS local_midloan_order_info_stat180d_prepay3dayscnt_v2,  -- 提前>=3天结清的笔数
    
    -- 2.8 在贷相关（1个）
    COALESCE(s180.uncompletedInstalCnt, 0) AS local_midloan_order_info_stat180d_uncompletedinstalcnt_v2,  -- 在贷账单数
    
    -- ===================== stat10000D特征（33个）- 近10000天的贷中行为特征 =====================
    -- 3.1 额度测算相关（1个）
    -- 历次下单时间距离一次风控时间的平均天数间隔
    -- 计算逻辑：
    --   1. 统计时间窗口内所有订单的use_credit.create_time
    --   2. 统计所有观察日期前的repay_plan.settled_time和匹配上use_credit的credit_apply.create_time
    --   3. 每个use_credit.create_time往前取最近的任意settled_time或credit_apply.create_time
    --   4. 取时间间隔作为calc_credit_gap_new
    --   5. 如果往前不存在settled_time或credit_apply.create_time，则为空值null
    --   6. 对所有订单的差值取平均值（NULL值会被AVG函数忽略）
    COALESCE(s10000.calcCreditGapMean, 0) AS local_midloan_order_info_stat10000d_calccreditgapmean_v2,
    
    -- 3.2 订单结清相关（6个）
    COALESCE(s10000.completeOrderCnt, 0) AS local_midloan_order_info_stat10000d_completeordercnt_v2,  -- 历史结清订单数
    COALESCE(s10000.completeMultiLoanOrderCnt, 0) AS local_midloan_order_info_stat10000d_completemultiloanordercnt_v2,  -- 历史结清续借订单数
    COALESCE(s10000.completeMultiLoanVsCompleteOrderRatio, 0) AS local_midloan_order_info_stat10000d_completemultiloanvscompleteorderratio_v2,  -- 历史结清续借订单占比
    COALESCE(s10000.completeMultiLoanVsPayoutOrderRatio, 0) AS local_midloan_order_info_stat10000d_completemultiloanvspayoutorderratio_v2,  -- 历史结清续借订单占放款订单占比
    COALESCE(s10000.payoutOrderCnt, 0) AS local_midloan_order_info_stat10000d_payoutordercnt_v2,  -- 历史完成打款订单数
    COALESCE(s10000.completedInstalPrincipalSum, 0) AS local_midloan_order_info_stat10000d_completedinstalprincipalsum_v2,  -- 历史已结清账单本金总和
    
    -- 3.3 借款天数相关（7个）
    COALESCE(s10000.completeOrderInloanDaysCnt, 0) AS local_midloan_order_info_stat10000d_completeorderinloandayscnt_v2,  -- 历史完成订单总实际借款天数
    COALESCE(s10000.completeOrderInloanDaysAvg, 0) AS local_midloan_order_info_stat10000d_completeorderinloandaysavg_v2,  -- 历史完成订单平均每笔实际借款天数
    COALESCE(s10000.completeOrderAvgInloanDaysRatio, 0) AS local_midloan_order_info_stat10000d_completeorderavginloandaysratio_v2,  -- 历史完成订单平均每笔实际借款天数 / 借款期限（借款期限=计划还款日-放款日期）
    COALESCE(s10000.completeOrderMaxInloanDaysRatio, 0) AS local_midloan_order_info_stat10000d_completeordermaxinloandaysratio_v2,  -- 历史完成订单最大实际借款天数 / 借款期限（借款期限=计划还款日-放款日期）
    COALESCE(s10000.completeOrderMinInloanDaysRatio, 0) AS local_midloan_order_info_stat10000d_completeordermininloandaysratio_v2,  -- 历史完成订单最小实际借款天数 / 借款期限（借款期限=计划还款日-放款日期）
    COALESCE(s10000.orderInloanDaysAvg, 0) AS local_midloan_order_info_stat10000d_orderinloandaysavg_v2,  -- 历史平均每笔实际借款天数
    COALESCE(s10000.orderInloanDaysCnt, 0) AS local_midloan_order_info_stat10000d_orderinloandayscnt_v2,  -- 历史总实际借款天数
    
    -- 3.4 申请时间相关（4个）
    COALESCE(s10000.orderApplyHourAvg, 0) AS local_midloan_order_info_stat10000d_orderapplyhouravg_v2,  -- 订单平均申请时刻
    COALESCE(s10000.orderNowMinusApplyHourAvg, 0) AS local_midloan_order_info_stat10000d_ordernowminusapplyhouravg_v2,  -- 当前借款时间点的小时数—订单平均申请时刻
    COALESCE(s10000.onWeekendOrderCnt, 0) AS local_midloan_order_info_stat10000d_onweekendordercnt_v2,  -- 周末申请订单数
    COALESCE(s10000.onWeekendOrderOrderRatio, 0) AS local_midloan_order_info_stat10000d_onweekendorderorderratio_v2,  -- 周末申请订单比例
    
    -- 3.5 结清间隔相关（3个）
    COALESCE(s10000.orderLastCompleteGapMax, 0) AS local_midloan_order_info_stat10000d_orderlastcompletegapmax_v2,  -- 申请距离上笔结清最大间隔天数
    COALESCE(s10000.orderLastCompleteGapMean, 0) AS local_midloan_order_info_stat10000d_orderlastcompletegapmean_v2,  -- 申请距离上笔结清平均间隔天数
    COALESCE(s10000.orderLastCompleteGapMin, 0) AS local_midloan_order_info_stat10000d_orderlastcompletegapmin_v2,  -- 申请距离上笔结清最小间隔天数
    
    -- 3.6 逾期相关（7个）
    COALESCE(s10000.orderOverdueDaysMax, 0) AS local_midloan_order_info_stat10000d_orderoverduedaysmax_v2,  -- 单笔最大逾期天数
    COALESCE(s10000.orderOverdueDaysSum, 0) AS local_midloan_order_info_stat10000d_orderoverduedayssum_v2,  -- 总逾期天数
    COALESCE(s10000.overdueOrderCnt, 0) AS local_midloan_order_info_stat10000d_overdueordercnt_v2,  -- 发生逾期总笔数
    COALESCE(s10000.overdue3DaysOrderCnt, 0) AS local_midloan_order_info_stat10000d_overdue3daysordercnt_v2,  -- 发生逾期>=3天总笔数
    COALESCE(s10000.overdueMaxConsecutiveCnt, 0) AS local_midloan_order_info_stat10000d_overduemaxconsecutivecnt_v2,  -- 最大连续发生逾期笔数
    COALESCE(s10000.overdueMaxConsecutiveOrderCnt, 0) AS local_midloan_order_info_stat10000d_overduemaxconsecutiveordercnt_v2,  -- 最大连续发生逾期订单数
    COALESCE(s10000.overdue3DaysMaxConsecutiveOrderCnt, 0) AS local_midloan_order_info_stat10000d_overdue3daysmaxconsecutiveordercnt_v2,  -- 最大连续发生逾期>=3天订单数
    
    -- 3.7 提前结清相关（4个）
    COALESCE(s10000.orderPrepayDaysAvg, 0) AS local_midloan_order_info_stat10000d_orderprepaydaysavg_v2,  -- 平均每笔提前结清天数
    COALESCE(s10000.orderPrepayDaysMax, 0) AS local_midloan_order_info_stat10000d_orderprepaydaysmax_v2,  -- 最大单笔提前结清天数
    COALESCE(s10000.prepayOrderCnt, 0) AS local_midloan_order_info_stat10000d_prepayordercnt_v2,  -- 提前结清的笔数
    COALESCE(s10000.prepay3DaysCnt, 0) AS local_midloan_order_info_stat10000d_prepay3dayscnt_v2,  -- 提前>=3天结清的笔数
    
    -- 3.8 在贷相关（1个）
    COALESCE(s10000.uncompletedInstalCnt, 0) AS local_midloan_order_info_stat10000d_uncompletedinstalcnt_v2  -- 在贷账单数
FROM stat90D s90
FULL OUTER JOIN stat180D s180 
    ON s90.cust_no = s180.cust_no
    AND s90.observation_date = s180.observation_date  -- 添加observation_date匹配：确保不同时间窗口的特征来自同一观察日期
FULL OUTER JOIN stat10000D s10000 
    ON COALESCE(s90.cust_no, s180.cust_no) = s10000.cust_no
    AND COALESCE(s90.observation_date, s180.observation_date) = s10000.observation_date
LEFT JOIN hive_idc.hello_prd.ods_mx_aprv_approve_use_credit_apply_df use_credit
    ON use_credit.cust_no = COALESCE(s90.cust_no, s180.cust_no, s10000.cust_no)
    AND use_credit.create_time = COALESCE(s90.observation_date, s180.observation_date, s10000.observation_date)
    AND use_credit.pt =DATE_SUB(CURRENT_DATE(), 2)
WHERE COALESCE(s90.cust_no, s180.cust_no, s10000.cust_no) IS NOT NULL) t
-- where observation_date>'2026-01-21 06:08:00'
order by observation_date desc;
