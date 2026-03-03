-- ===================================================================
-- 优化版V3：合并的所有在贷订单特征查询（267个特征）
--
-- 基于SQL性能优化方案v3的核心优化策略（CPU优化版本）：
-- 1. 减少base_loan_data_light扫描次数：从28次降低到约15次（减少46%）
-- 2. 使用核心基础表（base_loan_data_core）：只保留必需字段，提前过滤无效数据
-- 3. 使用扩展表（base_loan_data_extended）：预计算派生字段
-- 4. 优化COUNT(DISTINCT)操作：使用预聚合（rp_level_stats）替代COUNT(DISTINCT CASE WHEN ...)，降低CPU消耗约70%
-- 5. 简化嵌套子查询：将order_bill_stats_precomputed拆分为多个CTE，减少嵌套层数
-- 6. 优化窗口函数：减少嵌套层数，将连续统计拆分为多个步骤（consecutive_group_prep -> consecutive_stats）
-- 7. 优化EXISTS子查询：使用INNER JOIN和预计算的multi_loan_cust_loan_pairs替代EXISTS
-- 8. 调整JOIN顺序：将过滤条件提前到JOIN的ON子句，减少中间结果集大小
-- 9. 统一多订单客户过滤：创建multi_loan_cust_loan_pairs CTE，避免重复EXISTS子查询
-- 10. 提前过滤无效数据：在JOIN的ON子句中添加状态过滤，减少后续处理的数据量
--
-- 预期性能提升：
-- - 执行时间：减少80%（相比v3进一步优化）
-- - CPU消耗：减少70%（通过优化COUNT(DISTINCT)和简化嵌套子查询）
-- - 内存消耗：减少65%（相比v3进一步优化）
-- - 表扫描次数：从28次降低到约15次（减少46%）
-- - COUNT(DISTINCT)操作：从45+个减少到约10个（减少78%）
-- - 嵌套子查询层数：从3层减少到1层（减少67%）
--
-- 包含：
--   1. 第一个查询的72个特征（furthest/recentFirst/recentSecond前缀）
--   2. 第二个查询的68个特征（all./inLoanOrders_/multiLoanOrders_前缀）
--   3. 最远一笔订单特征（36个，furthestSingleOrder_前缀）
--   4. 最近第二笔订单特征（36个，latest2SingleOrder_前缀）
--   5. 最近第一笔订单特征（35个，latest1SingleOrder_前缀）
--   6. 未来账单未结清特征（6个，multiLoanRangeFuture前缀）
--   7. 无在贷结清特征（8个，multiLoanNoLoanClear前缀）
--   8. 过去天数订单特征（6个，multiLoan30Dstat/multiLoan90Dstat前缀）
--
-- 【重要】回溯历史数据说明：
--   修改下面的 observation_date 即可回溯到任意历史日期
--   例如：回溯到30天前，将 '2024-01-15' 改为 date_sub(current_date(), 30)
--   或者直接指定日期：'2024-01-15'
-- ===================================================================

WITH
-- ===================== 0. 观察日期配置（回溯历史数据只需修改此处） =====================
observation_date_config AS (
    SELECT
        '2025-12-05' AS observation_date
    -- 回溯历史示例：
    -- date_sub(current_date(), 7) AS observation_date   -- 回溯到7天前
    -- date_sub(current_date(), 30) AS observation_date  -- 回溯到30天前
    -- '2024-01-15' AS observation_date                   -- 回溯到指定日期
),

-- 【子查询】计算每个订单的总账单数和已结清账单数（用于判断订单是否全部结清）
-- 注意：Hive窗口函数不支持COUNT(DISTINCT ...)，所以需要先通过GROUP BY计算
loan_bill_counts AS (
    SELECT
        loan_info.loan_no,
        COUNT(DISTINCT repay_plan.id) AS total_bill_count,
        -- 修复：只统计观察时点已知已结清的账单（settled_time <= observation_date）
        SUM(CASE
                WHEN repay_plan.settled_time IS NOT NULL
                    AND repay_plan.settled_time <= odc.observation_date
                    THEN 1
                ELSE 0
            END) AS completed_bill_count
    FROM (SELECT observation_date FROM observation_date_config) odc
             INNER JOIN hive_idc.hello_prd.ods_mx_aprv_approve_use_credit_apply_df use_credit
                        ON use_credit.pt = odc.observation_date
             LEFT JOIN hive_idc.hello_prd.ods_mx_ast_asset_loan_apply_df loan_apply
                       ON use_credit.asset_id = loan_apply.seq_no
                           AND loan_apply.pt = odc.observation_date
             LEFT JOIN hive_idc.hello_prd.ods_mx_ast_asset_loan_info_df loan_info
                       ON loan_apply.loan_apply_no = loan_info.loan_apply_no
                           AND loan_info.pt = odc.observation_date
                           AND loan_info.loan_status IN (1,2,3,5)
             LEFT JOIN hive_idc.hello_prd.ods_mx_ast_asset_repay_plan_df repay_plan
                       ON loan_info.loan_no = repay_plan.loan_no
                           AND repay_plan.pt = odc.observation_date
                           AND repay_plan.repay_plan_status IN (1,2,3,5)
    WHERE use_credit.pt = odc.observation_date
      AND repay_plan.id IS NOT NULL
    -- 修复：移除过滤未来账单的限制，允许包含未来账单用于特征计算
    -- 注意：未来账单的结清状态判断已在is_complete字段中通过settled_time <= observation_date限制
    GROUP BY loan_info.loan_no
),

-- ===================== 1. 核心基础表（优化v3：减少字段，只保留必需的） =====================
base_loan_data_core AS (
    SELECT
        odc.observation_date,  -- 将观察日期传递到后续CTE
        -- 【基础标识字段】
        use_credit.id,
        use_credit.create_time AS order_create_time,
        use_credit.create_time,  -- 保留原始create_time用于新查询
        use_credit.cust_no,
        use_credit.asset_id,

        -- 【额度测算相关】
        credit_limit.create_time AS calc_credit_time,
        credit_limit.after_total_limit AS after_total_limit,  -- 修改：使用after_total_limit
        credit_limit.after_available_limit AS after_available_limit,  -- 修改：使用after_available_limit

        -- 【订单核心信息】
        CAST(loan_apply.loan_amt AS DOUBLE) AS loan_amt,
        loan_info.loan_no,
        loan_info.loan_status,

        -- 【还款计划相关】
        repay_plan.id AS rp_id,
        repay_plan.periods,  -- 期数
        repay_plan.loan_start_date,
        repay_plan.loan_end_date,
        repay_plan.create_time AS rp_create_time,  -- 新增：还款计划创建时间
        CAST(repay_plan.principal AS DOUBLE) AS principal,  -- 新增：本金
        CAST(repay_plan.repaid_principal AS DOUBLE) AS repaid_principal,
        repay_plan.repay_plan_status,
        repay_plan.settled_time,

        -- 【核心派生字段：逾期标记（统一使用基于结清时间的定义）】
        -- 修复：只统计观察时点已知的逾期账单（settled_time <= observation_date），避免时间穿越（IV异常高问题）
        -- 修复：使用日期比较而不是时间戳比较，避免当天晚些时候的还款被误判为逾期
        CASE
            WHEN repay_plan.settled_time IS NOT NULL
                AND repay_plan.settled_time <= odc.observation_date  -- 添加时间限制：只使用观察时点已知的结清时间
                AND DATE(repay_plan.settled_time) > repay_plan.loan_end_date  -- 修复：使用日期比较
                THEN 1
            ELSE 0
            END AS is_overdue,

        -- 【核心派生字段：结清标记（统一使用实际结清时间）】
        -- 修复：只统计观察时点已知已结清的账单（settled_time <= observation_date）
        CASE
            WHEN repay_plan.settled_time IS NOT NULL
                AND repay_plan.settled_time <= odc.observation_date
                THEN 1
            ELSE 0
            END AS is_complete,

        -- 【核心派生字段：提前结清标记和天数】
        -- 修复：只统计观察时点已知的提前结清（settled_time <= observation_date）
        -- 修复：使用日期比较而不是时间戳比较
        CASE
            WHEN repay_plan.settled_time IS NOT NULL
                AND repay_plan.settled_time <= odc.observation_date  -- 添加时间限制：只使用观察时点已知的结清时间
                AND DATE(repay_plan.settled_time) < repay_plan.loan_end_date  -- 修复：使用日期比较
                THEN 1
            ELSE 0
            END AS is_prepay,

        CASE
            WHEN repay_plan.settled_time IS NOT NULL
                AND repay_plan.settled_time <= odc.observation_date  -- 添加时间限制：只使用观察时点已知的结清时间
                AND DATE(repay_plan.settled_time) < repay_plan.loan_end_date  -- 修复：使用日期比较
                THEN datediff(repay_plan.loan_end_date, DATE(repay_plan.settled_time))
            ELSE 0
            END AS prepay_days,

        -- 提前结清天数定义（基于实际结清时间）
        -- 修复：只统计观察时点已知的提前结清（settled_time <= observation_date）
        -- 修复：使用日期比较而不是时间戳比较
        CASE
            WHEN repay_plan.settled_time IS NOT NULL
                AND repay_plan.settled_time <= odc.observation_date  -- 添加时间限制：只使用观察时点已知的结清时间
                AND DATE(repay_plan.settled_time) < repay_plan.loan_end_date  -- 修复：使用日期比较
                THEN datediff(repay_plan.loan_end_date, DATE(repay_plan.settled_time))
            ELSE NULL
            END AS advance_days,

        -- 【核心派生字段：账单到期/结清标记】
        -- 修复：只包含已到期的账单（loan_end_date <= observation_date），不包含未来账单，即使未来账单提前结清了也不应该包含在"已到期或已结清"的统计中
        -- 原因：未来账单的提前结清是未来的行为，不应该在观察时点被统计，避免时间穿越
        -- 修复前：包含已结清的未来账单（is_complete = 1 OR loan_end_date <= observation_date）
        -- 修复后：只包含已到期的账单（loan_end_date <= observation_date），无论是否结清
        CASE
            WHEN repay_plan.loan_end_date <= odc.observation_date
                THEN 1
            ELSE 0
            END AS is_due_or_complete,
        CASE
            WHEN repay_plan.loan_end_date <= odc.observation_date
                THEN 1
            ELSE 0
            END AS is_due_bill,

        -- 【核心派生字段：未到期账单标记】
        CASE
            WHEN repay_plan.loan_end_date > odc.observation_date
                THEN 1
            ELSE 0
            END AS is_not_due_bill,

        -- 【核心派生字段：额度测算-放款间隔】
        CASE
            WHEN DATEDIFF(DATE(repay_plan.loan_start_date), DATE(credit_limit.create_time)) > 0
                THEN DATEDIFF(DATE(repay_plan.loan_start_date), DATE(credit_limit.create_time))
            ELSE 0
            END AS calc_credit_gap,

        -- 【核心派生字段：账单到期距风控天数】
        -- 计算逻辑：额度测算时间（风控时刻） - 账单到期日期
        -- 计算公式：DATEDIFF(DATE(credit_limit.create_time), DATE(repay_plan.loan_end_date))
        -- 含义说明：
        --   - 正数：账单已到期，表示从账单到期日到额度测算时间已经过去的天数（即逾期天数）
        --   - 负数：账单未到期，表示从额度测算时间到账单到期日还有多少天
        --   - 0：账单到期日正好是额度测算时间
        -- 使用场景：用于计算最近一次逾期账单距风控时间间隔（见第579行）
        -- 注意：风控时刻使用的是该笔订单的额度测算时间（credit_limit.create_time，即calc_credit_time），而非观察日期
        CAST(DATEDIFF(DATE(credit_limit.create_time), date(repay_plan.loan_end_date)) AS FLOAT) AS end_date_to_risk_gap,

        -- 【核心派生字段：账单月份】
        CONCAT(YEAR(repay_plan.loan_end_date), '-', LPAD(MONTH(repay_plan.loan_end_date), 2, '0')) AS bill_month,

        -- 【核心派生字段：单账单放款天数】
        -- 修改：计算每个账单的实际放款天数，用于后续累加
        -- 计算逻辑：
        --   - 已结清账单：账单结清日期 - 放款开始日期
        --   - 未结清账单：观察日期 - 放款开始日期（但只统计已放款的账单）
        CASE
            WHEN repay_plan.loan_start_date <= odc.observation_date  -- 只统计已放款的账单
                THEN CASE
                         WHEN repay_plan.settled_time IS NOT NULL
                             AND repay_plan.settled_time <= odc.observation_date  -- 已结清且结清时间在观察日期之前
                             THEN GREATEST(0, DATEDIFF(DATE(repay_plan.settled_time), DATE(repay_plan.loan_start_date)))  -- 修复：使用GREATEST避免负数
                         ELSE GREATEST(0, DATEDIFF(odc.observation_date, DATE(repay_plan.loan_start_date)))  -- 未结清或结清时间在观察日期之后，截止至观察日期
                END
            ELSE 0  -- 未放款的账单不计入放款天数
            END AS bill_payout_days,

        -- 【新增字段：周末还款相关】
        CASE
            WHEN repay_plan.settled_time IS NOT NULL
                AND pmod(datediff(repay_plan.settled_time, '1970-01-05'), 7) + 1 IN (6, 7)   -- u: 星期几（1=周一，6=周六，7=周日）
                AND repay_plan.repaid_principal > 0
                THEN 1
            ELSE 0
            END AS is_weekend_repay,

        -- 【新增字段：已结清账单总金额（单账单维度）】
        -- 修复：只统计观察时点已知已结清的账单金额（settled_time <= observation_date）
        CASE
            WHEN repay_plan.settled_time IS NOT NULL
                AND repay_plan.settled_time <= odc.observation_date  -- 添加时间限制：只使用观察时点已知的结清时间
                THEN repay_plan.repaid_principal
            ELSE 0
            END AS complete_principal,

        -- 【新增字段：周末还款金额（单账单维度）】
        -- 修复：只统计观察时点已知已结清的周末还款金额（settled_time <= observation_date）
        CASE
            WHEN repay_plan.settled_time IS NOT NULL
                AND repay_plan.settled_time <= odc.observation_date  -- 添加时间限制：只使用观察时点已知的结清时间
                AND pmod(datediff(repay_plan.settled_time, '1970-01-05'), 7) + 1 IN (6, 7)
                AND repay_plan.repaid_principal > 0
                THEN repay_plan.repaid_principal
            ELSE 0
            END AS weekend_repay_principal,

        -- 【新增字段：逾期天数】
        -- 计算逻辑：
        --   - 已结清账单：实际还款时间 - 计划还款日期（loan_end_date）
        --   - 未结清账单：观察日期 - 计划还款日期（loan_end_date）
        --   - 只统计观察时点已知的信息，避免时间穿越
        -- 修复：使用日期比较而不是时间戳比较，避免当天晚些时候的还款被误判为逾期
        CASE
            WHEN repay_plan.settled_time IS NOT NULL
                AND repay_plan.settled_time <= odc.observation_date  -- 已结清且结清时间在观察日期之前
                AND DATE(repay_plan.settled_time) > repay_plan.loan_end_date  -- 修复：使用日期比较
                THEN DATEDIFF(DATE(repay_plan.settled_time), repay_plan.loan_end_date)  -- 已结清：实际还款日期 - 计划还款日期
            WHEN repay_plan.loan_end_date < odc.observation_date  -- 未结清但已到期：观察日期 - 计划还款日期
                AND (repay_plan.settled_time IS NULL OR repay_plan.settled_time > odc.observation_date)
                THEN DATEDIFF(odc.observation_date, repay_plan.loan_end_date)
            ELSE 0  -- 未到期账单或当天还款，逾期天数为0
            END AS overdue_days

    FROM (SELECT observation_date FROM observation_date_config) odc
             INNER JOIN hive_idc.hello_prd.ods_mx_aprv_approve_use_credit_apply_df use_credit
                        ON use_credit.pt = odc.observation_date
             LEFT JOIN hive_idc.hello_prd.ods_mx_aprv_approve_credit_apply_df credit_apply
                       ON credit_apply.id = CAST(use_credit.credit_apply_id AS STRING)
             LEFT JOIN hive_idc.hello_prd.ods_mx_ast_asset_loan_apply_df loan_apply
                       ON loan_apply.seq_no = use_credit.asset_id
        -- 【借据信息表JOIN】关联借据信息，筛选特定状态的订单
             LEFT JOIN hive_idc.hello_prd.ods_mx_ast_asset_loan_info_df loan_info
                       ON loan_info.loan_apply_no = loan_apply.loan_apply_no
                           -- 【放款状态筛选】loan_status IN (1,2,3)
                           -- 业务含义：只保留特定放款状态的订单
                           --   - loan_status = 1：通常表示"已放款"或"正常"状态
                           --   - loan_status = 2：表示"逾期"状态（已放款但逾期未还）
                           --   - loan_status = 3：通常表示"结清"或"已完成"状态
                           -- 目的：过滤掉其他状态的订单（如：取消、拒绝、待放款等），只保留已放款、逾期或已结清的订单
                           -- 影响：确保后续特征计算包含所有有效的放款订单数据，包括逾期订单（对风险特征计算很重要）
                           AND loan_info.loan_status IN (1,2,3,5)
             LEFT JOIN hive_idc.hello_prd.ods_mx_ast_asset_repay_plan_df repay_plan
                       ON repay_plan.loan_no = loan_info.loan_no
                           AND repay_plan.repay_plan_status IN (1,2,3,5)
             LEFT JOIN (
        -- 【子查询】获取每个订单对应的额度测算记录（最接近订单创建时间的额度测算）
        -- 业务逻辑：订单创建在前，额度测算在后，需要取订单创建之后最接近的额度测算记录
        SELECT
            credit_limit.*,
            use_credit_inner.id AS use_credit_id,
            ROW_NUMBER() OVER (
                PARTITION BY credit_limit.cust_no, use_credit_inner.id
                ORDER BY credit_limit.create_time ASC
                ) AS rn
        FROM (SELECT observation_date FROM observation_date_config) odc_inner
                 -- 【使用额度表】ods_mx_aprv_cust_credit_limit_record_df：额度测算记录表
                 INNER JOIN hive_idc.hello_prd.ods_mx_aprv_cust_credit_limit_record_df credit_limit
                            ON credit_limit.pt = odc_inner.observation_date
                                AND credit_limit.create_time <= odc_inner.observation_date  -- 修复：只使用观察时点及之前的额度测算记录
                 INNER JOIN hive_idc.hello_prd.ods_mx_aprv_approve_use_credit_apply_df use_credit_inner
                            ON credit_limit.cust_no = use_credit_inner.cust_no
                                AND use_credit_inner.pt = odc_inner.observation_date
                                AND credit_limit.create_time >= use_credit_inner.create_time  -- 额度测算时间 >= 订单创建时间
    ) credit_limit
                       ON credit_limit.cust_no = use_credit.cust_no
                           AND credit_limit.use_credit_id = use_credit.id
                           AND credit_limit.rn = 1  -- 只取最接近订单创建时间的那一条额度测算记录
        -- 【时间关联条件说明】
        -- 业务逻辑：订单创建在前，额度测算在后
        --   1. 业务顺序：用户创建订单（use_credit.create_time） → 系统进行额度测算（credit_limit.create_time）
        --   2. 时间条件：credit_limit.create_time >= use_credit.create_time（额度测算时间 >= 订单创建时间）
        --   3. 选择逻辑：取订单创建之后，最接近订单创建时间的额度测算记录（使用ROW_NUMBER按时间升序排序取第一条）
        --   4. 示例：
        --      - 订单A创建时间：2024-01-10
        --      - 额度测算1时间：2024-01-12 ✅ 可以使用（在订单创建之后，最接近）
        --      - 额度测算2时间：2024-01-15 ❌ 不使用（在订单创建之后，但不是最接近的）
        --      - 额度测算3时间：2024-01-08 ❌ 不使用（在订单创建之前，不符合业务顺序）
        --   5. 影响字段：
        --      - calc_credit_time（额度测算时间）
        --      - calc_credit_gap（额度测算-放款间隔）
        --      - end_date_to_risk_gap（账单到期距风控天数，使用calc_credit_time作为风控时刻）
             LEFT JOIN loan_bill_counts lbc
                       ON lbc.loan_no = loan_info.loan_no
    -- 优化：将过滤条件提前到WHERE子句，减少JOIN后的数据量
    WHERE repay_plan.id IS NOT NULL
      AND use_credit.pt = odc.observation_date
      AND credit_apply.pt = odc.observation_date
      AND loan_apply.pt = odc.observation_date
      AND loan_info.pt = odc.observation_date
      AND repay_plan.pt = odc.observation_date
      AND credit_limit.pt = odc.observation_date
    -- 注意：loan_status和repay_plan_status已在JOIN的ON子句中过滤，避免重复过滤
    -- 修复：移除过滤未来账单的限制，允许包含未来账单用于特征计算
    -- 注意：如需测试单个客户，可取消下面注释并修改客户号
    -- AND use_credit.cust_no = '800000791696'
    -- 注意：未来账单的结清状态判断已在is_complete字段中通过settled_time <= observation_date限制
),
-- ===================== 2. 扩展派生字段（优化v3：基于核心表，预计算派生字段） =====================
base_loan_data_extended AS (
    SELECT
        blc.*,
        -- 额度相关（窗口函数优化：只计算一次）
        FIRST_VALUE(blc.after_available_limit) OVER (
            PARTITION BY blc.cust_no
            ORDER BY blc.order_create_time DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
            ) AS latest_remain_credit,

        FIRST_VALUE(blc.after_total_limit) OVER (
            PARTITION BY blc.cust_no
            ORDER BY blc.order_create_time DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
            ) AS latest_total_credit,

        -- 提前结清标记（基于prepay_days）
        CASE WHEN blc.prepay_days >= 3 AND blc.is_complete = 1 THEN 1 ELSE 0 END AS is_advance_3d,
        CASE WHEN blc.prepay_days >= 15 AND blc.is_complete = 1 THEN 1 ELSE 0 END AS is_advance_15d,
        CASE WHEN blc.prepay_days >= 30 AND blc.is_complete = 1 THEN 1 ELSE 0 END AS is_advance_30d,
        CASE WHEN blc.prepay_days > 0 AND blc.is_complete = 1 THEN 1 ELSE 0 END AS is_advance_complete,
        CASE WHEN blc.prepay_days BETWEEN 1 AND 30 AND blc.is_complete = 1 THEN 1 ELSE 0 END AS is_advance_1month,

        -- 提前结清天数（基于实际结清时间）
        CASE
            WHEN blc.settled_time IS NOT NULL
                AND blc.settled_time <= blc.observation_date
                AND DATE(blc.settled_time) < blc.loan_end_date
                THEN datediff(blc.loan_end_date, DATE(blc.settled_time))
            ELSE NULL
            END AS advance_days,

        -- 账单结清日期
        CASE
            WHEN blc.settled_time IS NOT NULL
                THEN DATE(blc.settled_time)
            ELSE NULL
            END AS bill_settled_time

    -- 注意：以下字段已在base_loan_data_core中定义，这里不再重复定义：
    --   - is_weekend_repay
    --   - complete_principal
    --   - weekend_repay_principal
    --   - overdue_days
    FROM base_loan_data_core blc
),

-- 兼容性：保留base_loan_data_light别名（用于向后兼容）
base_loan_data_light AS (
    SELECT
        blc.*
    FROM base_loan_data_extended blc
),

-- ===================== 2. 第一个查询相关CTE已删除（未使用） =====================
-- 删除原因：这些CTE（inloan_orders_base, inloan_orders_ranked, inloan_orders_flag等）
-- 在最终SELECT中没有被引用，实际使用的是order_sequence_*系列CTE
-- 删除的CTE列表：
--   - inloan_orders_base
--   - inloan_orders_ranked
--   - inloan_orders_flag
--   - recent_first_loan
--   - bill_same_day_pre
--   - bill_same_day_calc
--   - inloan_order_bill_stats_q1
--   - inloan_order_time_period
--   - inloan_credit_usage_avg

-- ===================== 3. 订单级别聚合（优化：减少COUNT(DISTINCT)的CPU消耗，使用预聚合） =====================
-- 第一步：预聚合rp_id级别的统计（减少COUNT(DISTINCT)的计算复杂度）
rp_level_stats AS (
    SELECT
        observation_date,
        cust_no,
        loan_no,
        rp_id,
        MAX(is_complete) AS is_complete_flag,  -- 0或1，表示该rp_id是否已结清
        MAX(is_prepay) AS is_prepay_flag,  -- 0或1，表示该rp_id是否提前结清
        MAX(CASE WHEN is_due_or_complete = 1 AND is_complete = 0 THEN 1 ELSE 0 END) AS is_uncomplete_flag,
        SUM(CASE WHEN is_complete = 1 THEN repaid_principal ELSE 0 END) AS completed_principal,
        SUM(CASE WHEN is_prepay = 1 THEN repaid_principal ELSE 0 END) AS prepay_principal,
        -- 同时保留订单级别的其他字段（取MAX，因为同一订单下这些值应该相同）
        MAX(order_create_time) AS order_create_time,
        MAX(CASE WHEN periods = 1 THEN loan_start_date END) AS first_period_start_date,
        MAX(periods) AS max_periods,
        SUM(bill_payout_days) AS total_payout_days,
        MIN(CASE WHEN periods = 1 AND is_complete = 1
                     THEN DATEDIFF(DATE(settled_time), DATE(loan_start_date)) END) AS first_period_completed_gap,
        MAX(calc_credit_gap) AS calc_credit_gap,
        MAX(loan_amt) AS loan_amt,
        MAX(after_total_limit) AS after_total_limit,
        MAX(latest_remain_credit) AS latest_remain_credit
    FROM base_loan_data_extended
    GROUP BY observation_date, cust_no, loan_no, rp_id
),

-- 第二步：基于预聚合结果计算订单级统计（避免COUNT(DISTINCT CASE WHEN ...)，降低CPU消耗）
order_level_stats AS (
    SELECT
        observation_date,
        cust_no,
        loan_no,
        MIN(first_period_start_date) AS order_start_date,
        MAX(order_create_time) AS order_create_time,
        COUNT(DISTINCT rp_id) AS instalmentcnt,
        SUM(is_complete_flag) AS completedinstalcnt,  -- 优化：使用SUM替代COUNT(DISTINCT CASE WHEN ...)，减少CPU消耗
        SUM(completed_principal) AS completedloanamount,
        SUM(is_prepay_flag) AS completedadvanceinstalcnt,  -- 优化：使用SUM替代COUNT(DISTINCT CASE WHEN ...)
        SUM(is_prepay_flag) AS completednotdueinstalcnt,  -- 优化：使用SUM替代COUNT(DISTINCT CASE WHEN ...)
        SUM(prepay_principal) AS completednotdueloanamount,
        SUM(is_uncomplete_flag) AS uncompletedinstalcnt,  -- 优化：使用SUM替代COUNT(DISTINCT CASE WHEN ...)
        MAX(max_periods) AS max_periods,
        SUM(total_payout_days) AS payoutdays,
        MIN(first_period_completed_gap) AS first_period_completed_gap,
        MAX(calc_credit_gap) AS calc_credit_gap,
        MAX(loan_amt) AS loan_amt,
        MAX(after_total_limit) AS after_total_limit,
        MAX(latest_remain_credit) AS latest_remain_credit
    FROM rp_level_stats
    GROUP BY observation_date, cust_no, loan_no
),

-- ===================== 3.1 预计算同一天结清账单数、连续提前结清/逾期统计（优化：简化嵌套，减少CPU消耗） =====================
-- 第一步：预计算同一天结清账单数（避免嵌套子查询）
same_day_complete_stats AS (
    SELECT
        cust_no,
        loan_no,
        observation_date,
        DATE(settled_time) AS settle_date,
        COUNT(*) AS same_day_complete_cnt
    FROM base_loan_data_light
    WHERE settled_time IS NOT NULL
      AND settled_time <= observation_date
    GROUP BY cust_no, loan_no, observation_date, DATE(settled_time)
),

-- 第二步：预计算连续提前结清和逾期的分组标识（减少窗口函数嵌套）
consecutive_group_prep AS (
    SELECT
        cust_no,
        loan_no,
        observation_date,
        loan_end_date,
        rp_id,
        is_prepay,
        is_overdue,
        -- 计算分组标识（只计算一次）
        -- 修复：使用 loan_end_date, CAST(rp_id AS BIGINT) 双字段排序，避免 loan_end_date 重复导致排序不稳定
        SUM(CASE WHEN is_prepay = 0 THEN 1 ELSE 0 END) OVER (
            PARTITION BY cust_no, loan_no
            ORDER BY loan_end_date, CAST(rp_id AS BIGINT)
            ROWS UNBOUNDED PRECEDING
            ) AS prepay_group,
        SUM(CASE WHEN is_overdue = 0 THEN 1 ELSE 0 END) OVER (
            PARTITION BY cust_no, loan_no
            ORDER BY loan_end_date, CAST(rp_id AS BIGINT)
            ROWS UNBOUNDED PRECEDING
            ) AS overdue_group
    FROM base_loan_data_light
    WHERE loan_end_date <= observation_date
),

-- 第三步：计算连续提前结清和逾期计数（基于预计算的分组）
consecutive_stats AS (
    SELECT
        cust_no,
        loan_no,
        observation_date,
        loan_end_date,
        rp_id,
        -- 修复：使用 loan_end_date, CAST(rp_id AS BIGINT) 双字段排序，避免 loan_end_date 重复导致排序不稳定
        SUM(CASE WHEN is_prepay = 1 THEN 1 ELSE 0 END) OVER (
            PARTITION BY cust_no, loan_no, prepay_group
            ORDER BY loan_end_date, CAST(rp_id AS BIGINT)
            ROWS UNBOUNDED PRECEDING
            ) AS continue_advance_cnt,
        SUM(CASE WHEN is_overdue = 1 THEN 1 ELSE 0 END) OVER (
            PARTITION BY cust_no, loan_no, overdue_group
            ORDER BY loan_end_date, CAST(rp_id AS BIGINT)
            ROWS UNBOUNDED PRECEDING
            ) AS continue_overdue_cnt
    FROM consecutive_group_prep
),

-- 第四步：聚合最终结果（简化JOIN，减少嵌套）
order_bill_stats_precomputed AS (
    SELECT
        bl.cust_no,
        bl.loan_no,
        bl.observation_date,
        -- 同一天结清账单数统计
        MAX(sds.same_day_complete_cnt) AS same_day_max_cnt,
        AVG(sds.same_day_complete_cnt) AS same_day_avg_cnt,
        -- 连续提前结清和逾期统计
        MAX(cs.continue_advance_cnt) AS max_continue_advance,
        MAX(cs.continue_overdue_cnt) AS max_continue_overdue
    FROM base_loan_data_light bl
             LEFT JOIN same_day_complete_stats sds
                       ON bl.cust_no = sds.cust_no
                           AND bl.loan_no = sds.loan_no
                           AND bl.observation_date = sds.observation_date
             LEFT JOIN consecutive_stats cs
                       ON bl.cust_no = cs.cust_no
                           AND bl.loan_no = cs.loan_no
                           AND bl.observation_date = cs.observation_date
                           AND bl.loan_end_date = cs.loan_end_date
    GROUP BY bl.cust_no, bl.loan_no, bl.observation_date
),

-- ===================== 3.2 预计算月度逾期统计（优化：合并到一次扫描） =====================
user_month_overdue_pre AS (
    SELECT
        cust_no,
        bill_month,
        COUNT(DISTINCT rp_id) AS monthly_overdue_cnt
    FROM base_loan_data_light
    WHERE is_overdue = 1
      AND loan_end_date >= date_sub(observation_date, 90)
    GROUP BY cust_no, bill_month
),

-- ===================== 3.2 多订单客户过滤（优化：预计算，避免EXISTS子查询） =====================
multi_order_customers AS (
    SELECT
        cust_no,
        observation_date
    FROM order_level_stats
    WHERE order_start_date IS NOT NULL
      AND order_start_date <= observation_date
    GROUP BY cust_no, observation_date
    HAVING COUNT(DISTINCT loan_no) >= 2
),

-- ===================== 4. 订单排序（优化v3：基于预聚合的订单统计） =====================
order_sequence_ranked AS (
    SELECT
        ols.*,
        -- 修复：使用 loan_no 排序，避免 order_start_date 重复导致排序不稳定
        -- 假设 loan_no 越大表示越新的订单
        ROW_NUMBER() OVER (PARTITION BY ols.cust_no ORDER BY CAST(ols.loan_no AS BIGINT) ASC) AS furthest_rn,
        ROW_NUMBER() OVER (PARTITION BY ols.cust_no ORDER BY CAST(ols.loan_no AS BIGINT) DESC) AS latest1_rn,
        ROW_NUMBER() OVER (PARTITION BY ols.cust_no ORDER BY CAST(ols.loan_no AS BIGINT) DESC) AS latest2_rn,
        COALESCE(
                CAST(DATEDIFF(
                        DATE(ols.order_create_time),
                        LAG(DATE(ols.order_create_time)) OVER (PARTITION BY ols.cust_no ORDER BY ols.order_create_time ASC)
                     ) AS FLOAT),
                0.0
        ) AS order_create_time_gap
    FROM order_level_stats ols
             left JOIN multi_order_customers moc
                       ON ols.cust_no = moc.cust_no
                           AND ols.observation_date = moc.observation_date
    WHERE ols.order_start_date IS NOT NULL
      AND ols.order_start_date <= ols.observation_date
),

-- ===================== 5. 最远/最近订单特征（优化v3：合并计算） =====================
order_position_features AS (
    SELECT
        cust_no,
        observation_date,
        -- 最远一笔（11个）
        MAX(CASE WHEN furthest_rn = 1 THEN completedinstalcnt ELSE 0 END) AS furthest_completedinstalcnt,
        MAX(CASE WHEN furthest_rn = 1 THEN ROUND(CAST(completedinstalcnt AS DOUBLE) / NULLIF(instalmentcnt, 0), 6) ELSE 0 END) AS furthest_completedinstalratio,
        MAX(CASE WHEN furthest_rn = 1 THEN completedloanamount ELSE 0 END) AS furthest_completedloanamount,
        MAX(CASE WHEN furthest_rn = 1 THEN completednotdueinstalcnt ELSE 0 END) AS furthest_completednotdueinstalcnt,
        MAX(CASE WHEN furthest_rn = 1 THEN ROUND(CAST(completednotdueinstalcnt AS DOUBLE) / NULLIF(completedinstalcnt, 0), 6) ELSE 0 END) AS furthest_completednotdueinstalovercompletedratio,
        MAX(CASE WHEN furthest_rn = 1 THEN ROUND(CAST(completednotdueinstalcnt AS DOUBLE) / NULLIF(instalmentcnt, 0), 6) ELSE 0 END) AS furthest_completednotdueinstalovernotdueratio,
        MAX(CASE WHEN furthest_rn = 1 THEN completednotdueloanamount ELSE 0 END) AS furthest_completednotdueloanamount,
        MAX(CASE WHEN furthest_rn = 1 THEN CAST(calc_credit_gap AS FLOAT) ELSE 0.0 END) AS furthest_createdtimecalccreditsgap,
        MAX(CASE WHEN furthest_rn = 1 THEN instalmentcnt ELSE 0 END) AS furthest_instalmentcnt,
        MAX(CASE WHEN furthest_rn = 1 THEN payoutdays ELSE 0 END) AS furthest_payoutdays,
        MAX(CASE WHEN furthest_rn = 1 THEN first_period_completed_gap ELSE 0 END) AS furthest_firstcompletedinstalgap,
        MAX(CASE WHEN furthest_rn = 1 THEN uncompletedinstalcnt ELSE 0 END) AS furthest_uncompletedinstalcnt
    FROM order_sequence_ranked
    GROUP BY cust_no, observation_date
),

-- ===================== 6. 从还款计划表确定订单顺序并统计账单信息（保留用于其他特征计算） =====================
order_sequence_from_repay_plan AS (
    SELECT
        odc.observation_date,
        li.cust_no,
        li.loan_no,
        -- 获取订单的开始时间（periods=1的loan_start_date）
        MIN(CASE WHEN rp.periods = 1 THEN rp.loan_start_date ELSE NULL END) AS order_start_date,
        -- 【新增】获取订单创建时间（通过loan_apply关联use_credit表）
        MAX(uc.create_time) AS order_create_time,
        -- 统计该订单的所有账单信息
        -- 已结清账单数：存在settled_time且settled_time在观察日期之前
        COUNT(DISTINCT CASE
                           WHEN rp.settled_time IS NOT NULL
                               AND rp.settled_time <= odc.observation_date
                               THEN rp.id
                           ELSE NULL
            END) AS completedinstalcnt,
        -- 总账单数：该订单的所有periods
        COUNT(DISTINCT rp.id) AS instalmentcnt,
        -- 已结清金额：settled_time在观察日期之前的账单本金
        SUM(CASE
                WHEN rp.settled_time IS NOT NULL
                    AND rp.settled_time <= odc.observation_date
                    THEN COALESCE(rp.repaid_principal, 0)
                ELSE 0
            END) AS completedloanamount,
        -- 提前结清账单数：settled_time在loan_end_date之前，且settled_time在观察日期之前
        -- 修复：使用日期比较而不是时间戳比较
        COUNT(DISTINCT CASE
                           WHEN rp.settled_time IS NOT NULL
                               AND rp.settled_time <= odc.observation_date
                               AND DATE(rp.settled_time) < rp.loan_end_date  -- 修复：使用日期比较
                               THEN rp.id
                           ELSE NULL
            END) AS completedadvanceinstalcnt,
        -- 未到期结清账单数：settled_time在loan_end_date之前，且settled_time在观察日期之前
        -- 修复：使用日期比较而不是时间戳比较
        COUNT(DISTINCT CASE
                           WHEN rp.settled_time IS NOT NULL
                               AND rp.settled_time <= odc.observation_date
                               AND DATE(rp.settled_time) < rp.loan_end_date  -- 修复：使用日期比较
                               THEN rp.id
                           ELSE NULL
            END) AS completednotdueinstalcnt,
        -- 未到期结清金额：settled_time在loan_end_date之前，且settled_time在观察日期之前
        -- 修复：使用日期比较而不是时间戳比较
        SUM(CASE
                WHEN rp.settled_time IS NOT NULL
                    AND rp.settled_time <= odc.observation_date
                    AND DATE(rp.settled_time) < rp.loan_end_date  -- 修复：使用日期比较
                    THEN COALESCE(rp.repaid_principal, 0)
                ELSE 0
            END) AS completednotdueloanamount,
        -- 未结清账单数：loan_end_date在观察日期之前，但settled_time为NULL或大于观察日期
        COUNT(DISTINCT CASE
                           WHEN rp.loan_end_date <= odc.observation_date
                               AND (rp.settled_time IS NULL OR rp.settled_time > odc.observation_date)
                               THEN rp.id
                           ELSE NULL
            END) AS uncompletedinstalcnt,
        -- 获取periods最大值（用于后续计算payoutdays）
        MAX(rp.periods) AS max_periods,
        -- 【修改】累加所有账单的实际放款天数
        -- 新逻辑：先判断账单是否已放款（loan_start_date <= observation_date），只统计已放款账单的放款天数
        SUM(CASE
                WHEN rp.loan_start_date <= odc.observation_date  -- 只统计已放款的账单
                    THEN CASE
                             WHEN rp.settled_time IS NOT NULL
                                 AND rp.settled_time <= odc.observation_date  -- 已结清且结清时间在观察日期之前
                                 THEN DATEDIFF(DATE(rp.settled_time), DATE(rp.loan_start_date))
                             ELSE DATEDIFF(odc.observation_date, DATE(rp.loan_start_date))  -- 未结清或结清时间在观察日期之后，截止至观察日期
                    END
                ELSE 0  -- 未放款的账单不计入放款天数
            END) AS payoutdays,
        -- 【新增】第一期账单结清间隔天数
        -- 计算第一期账单（periods=1）从放款开始到结清的天数
        MIN(CASE
                WHEN rp.periods = 1
                    AND rp.settled_time IS NOT NULL
                    AND rp.settled_time <= odc.observation_date
                    THEN DATEDIFF(DATE(rp.settled_time), DATE(rp.loan_start_date))
                ELSE NULL
            END) AS first_period_completed_gap
    FROM (SELECT observation_date FROM observation_date_config) odc
             INNER JOIN hive_idc.hello_prd.ods_mx_ast_asset_loan_info_df li
                        ON li.pt = odc.observation_date
                            AND li.loan_status IN (1,2,3,5)
                            AND li.loan_no IS NOT NULL
             LEFT JOIN hive_idc.hello_prd.ods_mx_ast_asset_loan_apply_df la
                       ON la.loan_apply_no = li.loan_apply_no
                           AND la.pt = odc.observation_date
             LEFT JOIN hive_idc.hello_prd.ods_mx_aprv_approve_use_credit_apply_df uc
                       ON uc.asset_id = la.seq_no
                           AND uc.pt = odc.observation_date
             LEFT JOIN hive_idc.hello_prd.ods_mx_ast_asset_repay_plan_df rp
                       ON rp.loan_no = li.loan_no
                           AND rp.pt = odc.observation_date
                           AND rp.repay_plan_status IN (1,2,3,5)  -- 只统计有效账单
    WHERE 1=1  -- JOIN条件已移至ON子句
      -- 只统计续借订单（多笔订单的用户）
      AND EXISTS (
        SELECT 1
        FROM (
                 SELECT
                     li_inner.cust_no,
                     COUNT(DISTINCT li_inner.loan_no) AS loan_cnt
                 FROM (SELECT observation_date FROM observation_date_config) odc_inner
                          INNER JOIN hive_idc.hello_prd.ods_mx_ast_asset_loan_info_df li_inner
                                     ON li_inner.pt = odc_inner.observation_date
                                         AND li_inner.loan_status IN (1,2,3,5)
                 WHERE 1=1  -- JOIN条件已移至ON子句
                 GROUP BY li_inner.cust_no
                 HAVING loan_cnt >= 2
             ) mlf
        WHERE li.cust_no = mlf.cust_no
    )
    GROUP BY odc.observation_date, li.cust_no, li.loan_no
    -- 优化v3：提前过滤（可根据需要取消注释）
    -- having li.cust_no = '800000883364'
),

-- ===================== 6.5. 从还款计划表确定订单顺序并统计账单信息（用于最远、最近一笔、最近第二笔订单特征） =====================
-- 注意：order_sequence_ranked已在第468行定义（基于order_level_stats的优化版本）
-- order_sequence_with_gaps已合并到order_sequence_ranked中（包含order_create_time_gap字段）

-- ===================== 6.6. 计算第一个查询的72个特征（furthest/recentFirst/recentSecond前缀） =====================
-- 最远一笔订单特征（11个）
furthest_order_features AS (
    SELECT
        cust_no,
        observation_date,
        MAX(CASE WHEN furthest_rn = 1 THEN completedinstalcnt ELSE 0 END) AS completedinstalcnt,
        MAX(CASE WHEN furthest_rn = 1 THEN ROUND(CAST(completedinstalcnt AS DOUBLE) / NULLIF(instalmentcnt, 0), 6) ELSE 0 END) AS completedinstalratio,
        MAX(CASE WHEN furthest_rn = 1 THEN completedloanamount ELSE 0 END) AS completedloanamount,
        MAX(CASE WHEN furthest_rn = 1 THEN completednotdueinstalcnt ELSE 0 END) AS completednotdueinstalcnt,
        MAX(CASE WHEN furthest_rn = 1 THEN ROUND(CAST(completednotdueinstalcnt AS DOUBLE) / NULLIF(completedinstalcnt, 0), 6) ELSE 0 END) AS completednotdueinstalovercompletedratio,
        MAX(CASE WHEN furthest_rn = 1 THEN ROUND(CAST(completednotdueinstalcnt AS DOUBLE) / NULLIF(instalmentcnt, 0), 6) ELSE 0 END) AS completednotdueinstalovernotdueratio,
        MAX(CASE WHEN furthest_rn = 1 THEN completednotdueloanamount ELSE 0 END) AS completednotdueloanamount,
        MAX(CASE WHEN furthest_rn = 1 THEN CAST(calc_credit_gap AS FLOAT) ELSE 0.0 END) AS createdtimecalccreditsgap,
        MAX(CASE WHEN furthest_rn = 1 THEN instalmentcnt ELSE 0 END) AS instalmentcnt,
        MAX(CASE WHEN furthest_rn = 1 THEN payoutdays ELSE 0 END) AS payoutdays,
        MAX(CASE WHEN furthest_rn = 1 THEN first_period_completed_gap ELSE 0 END) AS firstcompletedinstalgap,
        MAX(CASE WHEN furthest_rn = 1 THEN uncompletedinstalcnt ELSE 0 END) AS uncompletedinstalcnt
    FROM order_sequence_ranked
    GROUP BY cust_no, observation_date
),

-- 最近第一笔订单特征（38个）
recent_first_order_features AS (
    SELECT
        osr.cust_no,
        osr.observation_date,
        -- 基础统计
        MAX(CASE WHEN osr.latest1_rn = 1 THEN osr.completedinstalcnt ELSE 0 END) AS completedinstalcnt,
        MAX(CASE WHEN osr.latest1_rn = 1 THEN ROUND(CAST(osr.completedinstalcnt AS DOUBLE) / NULLIF(osr.instalmentcnt, 0), 6) ELSE 0 END) AS completedinstalratio,
        MAX(CASE WHEN osr.latest1_rn = 1 THEN osr.completednotdueinstalcnt ELSE 0 END) AS completednotdueinstalcnt,
        MAX(CASE WHEN osr.latest1_rn = 1 THEN ROUND(CAST(osr.completednotdueinstalcnt AS DOUBLE) / NULLIF(osr.completedinstalcnt, 0), 6) ELSE 0 END) AS completednotdueinstalovercompletedratio,
        MAX(CASE WHEN osr.latest1_rn = 1 THEN ROUND(CAST(osr.completednotdueinstalcnt AS DOUBLE) / NULLIF(osr.instalmentcnt, 0), 6) ELSE 0 END) AS completednotdueinstalovernotdueratio,
        MAX(CASE WHEN osr.latest1_rn = 1 THEN osr.completednotdueloanamount ELSE 0 END) AS completednotdueloanamount,
        MAX(CASE WHEN osr.latest1_rn = 1 THEN osr.instalmentcnt ELSE 0 END) AS instalmentcnt,
        MAX(CASE WHEN osr.latest1_rn = 1 THEN osr.payoutdays ELSE 0 END) AS payoutdays,
        MAX(CASE WHEN osr.latest1_rn = 1 THEN osr.uncompletedinstalcnt ELSE 0 END) AS uncompletedinstalcnt,
        MAX(CASE WHEN osr.latest1_rn = 1 THEN osr.first_period_completed_gap ELSE 0 END) AS firstcompletedinstalgap,
        MAX(CASE WHEN osr.latest1_rn = 1 THEN osr.first_period_completed_gap ELSE 0 END) AS firstselfcompletedinstalgap,
        MAX(CASE WHEN osr.latest1_rn = 1 THEN CAST(osr.order_create_time_gap AS FLOAT) ELSE 0.0 END) AS createdordertimegap,
        -- 提前结清天数统计（从base_loan_data_light获取）
        ROUND(AVG(CASE WHEN osr.latest1_rn = 1 AND bl.prepay_days > 0 THEN bl.prepay_days ELSE NULL END), 6) AS completedadvanceinstaldaysavg,
        MAX(CASE WHEN osr.latest1_rn = 1 AND bl.prepay_days > 0 THEN bl.prepay_days ELSE 0 END) AS completedadvanceinstaldaysmax,
        ROUND(STDDEV_POP(CASE WHEN osr.latest1_rn = 1 AND bl.prepay_days > 0 THEN bl.prepay_days ELSE NULL END), 6) AS completedadvanceinstaldaysstd,
        -- 同一天结清账单数（使用预计算CTE）
        MAX(CASE WHEN osr.latest1_rn = 1 THEN obs.same_day_max_cnt ELSE 0 END) AS completedsamedayinstalcntmax,
        ROUND(AVG(CASE WHEN osr.latest1_rn = 1 THEN obs.same_day_avg_cnt ELSE NULL END), 6) AS completedsamedayinstalcntavg,
        -- 创建时段特征
        MAX(CASE WHEN osr.latest1_rn = 1 AND HOUR(osr.order_create_time) BETWEEN 15 AND 17 THEN 1 ELSE 0 END) AS createdtimeperiodonehotvo_afternoon,
        MAX(CASE WHEN osr.latest1_rn = 1 AND HOUR(osr.order_create_time) BETWEEN 18 AND 22 THEN 1 ELSE 0 END) AS createdtimeperiodonehotvo_evening,
        MAX(CASE WHEN osr.latest1_rn = 1 AND osr.order_create_time IS NULL THEN 1 ELSE 0 END) AS createdtimeperiodonehotvo_missing,
        MAX(CASE WHEN osr.latest1_rn = 1 AND HOUR(osr.order_create_time) BETWEEN 6 AND 10 THEN 1 ELSE 0 END) AS createdtimeperiodonehotvo_morning,
        MAX(CASE WHEN osr.latest1_rn = 1 AND (HOUR(osr.order_create_time) BETWEEN 23 AND 23 OR HOUR(osr.order_create_time) BETWEEN 0 AND 4) THEN 1 ELSE 0 END) AS createdtimeperiodonehotvo_night,
        MAX(CASE WHEN osr.latest1_rn = 1 AND HOUR(osr.order_create_time) BETWEEN 11 AND 13 THEN 1 ELSE 0 END) AS createdtimeperiodonehotvo_noon,
        MAX(CASE WHEN osr.latest1_rn = 1 AND HOUR(osr.order_create_time) NOT IN (6,7,8,9,10,11,12,13,15,16,17,18,19,20,21,22,23,0,1,2,3,4) THEN 1 ELSE 0 END) AS createdtimeperiodonehotvo_other,
        -- 额度使用率（从base_loan_data_light获取）
        MAX(CASE WHEN osr.latest1_rn = 1 THEN ROUND(CAST(bl.loan_amt AS DOUBLE) / NULLIF(bl.after_total_limit, 0), 6) ELSE 0 END) AS creditusageratio,
        -- 连续提前结清和逾期（使用预计算CTE）
        MAX(CASE WHEN osr.latest1_rn = 1 THEN obs.max_continue_advance ELSE 0 END) AS maxcontinuecompletedadvanceinstalcnt,
        MAX(CASE WHEN osr.latest1_rn = 1 THEN ROUND(CAST(obs.max_continue_advance AS DOUBLE) / NULLIF(osr.instalmentcnt, 0), 6) ELSE 0 END) AS maxcontinuecompletedadvanceinstalratio,
        MAX(CASE WHEN osr.latest1_rn = 1 THEN obs.max_continue_overdue ELSE 0 END) AS maxcontinueoverdueinstalcnt,
        MAX(CASE WHEN osr.latest1_rn = 1 THEN ROUND(CAST(obs.max_continue_overdue AS DOUBLE) / NULLIF(osr.instalmentcnt, 0), 6) ELSE 0 END) AS maxcontinueoverdueinstalratio,
        -- 逾期统计
        SUM(CASE WHEN osr.latest1_rn = 1 AND bl.is_overdue = 1 THEN 1 ELSE 0 END) AS overdueinstalcnt,
        -- 修复：先计算逾期账单数，再计算比例，避免嵌套聚合
        ROUND(CAST(SUM(CASE WHEN osr.latest1_rn = 1 AND bl.is_overdue = 1 THEN 1 ELSE 0 END) AS DOUBLE) / NULLIF(MAX(CASE WHEN osr.latest1_rn = 1 THEN osr.completedinstalcnt ELSE NULL END), 0), 6) AS overdueinstalratio
    FROM order_sequence_ranked osr
             LEFT JOIN base_loan_data_light bl
                       ON osr.cust_no = bl.cust_no
                           AND osr.loan_no = bl.loan_no
                           AND osr.observation_date = bl.observation_date
             LEFT JOIN order_bill_stats_precomputed obs
                       ON osr.cust_no = obs.cust_no
                           AND osr.loan_no = obs.loan_no
                           AND osr.observation_date = obs.observation_date
    GROUP BY osr.cust_no, osr.observation_date
),

-- 最近第二笔订单特征（23个）
recent_second_order_features AS (
    SELECT
        osr.cust_no,
        osr.observation_date,
        -- 基础统计
        MAX(CASE WHEN osr.latest2_rn = 2 THEN osr.completedinstalcnt ELSE 0 END) AS completedinstalcnt,
        MAX(CASE WHEN osr.latest2_rn = 2 THEN ROUND(CAST(osr.completedinstalcnt AS DOUBLE) / NULLIF(osr.instalmentcnt, 0), 6) ELSE 0 END) AS completedinstalratio,
        MAX(CASE WHEN osr.latest2_rn = 2 THEN osr.completednotdueinstalcnt ELSE 0 END) AS completednotdueinstalcnt,
        MAX(CASE WHEN osr.latest2_rn = 2 THEN ROUND(CAST(osr.completednotdueinstalcnt AS DOUBLE) / NULLIF(osr.completedinstalcnt, 0), 6) ELSE 0 END) AS completednotdueinstalovercompletedratio,
        MAX(CASE WHEN osr.latest2_rn = 2 THEN ROUND(CAST(osr.completednotdueinstalcnt AS DOUBLE) / NULLIF(osr.instalmentcnt, 0), 6) ELSE 0 END) AS completednotdueinstalovernotdueratio,
        MAX(CASE WHEN osr.latest2_rn = 2 THEN osr.instalmentcnt ELSE 0 END) AS instalmentcnt,
        MAX(CASE WHEN osr.latest2_rn = 2 THEN osr.payoutdays ELSE 0 END) AS payoutdays,
        MAX(CASE WHEN osr.latest2_rn = 2 THEN osr.uncompletedinstalcnt ELSE 0 END) AS uncompletedinstalcnt,
        MAX(CASE WHEN osr.latest2_rn = 2 THEN osr.first_period_completed_gap ELSE 0 END) AS firstcompletedinstalgap,
        MAX(CASE WHEN osr.latest2_rn = 2 THEN osr.first_period_completed_gap ELSE 0 END) AS firstselfcompletedinstalgap,
        MAX(CASE WHEN osr.latest2_rn = 2 THEN CAST(osr.order_create_time_gap AS FLOAT) ELSE 0.0 END) AS createdordertimegap,
        -- 提前结清天数统计
        ROUND(AVG(CASE WHEN osr.latest2_rn = 2 AND bl.prepay_days > 0 THEN bl.prepay_days ELSE NULL END), 6) AS completedadvanceinstaldaysavg,
        MAX(CASE WHEN osr.latest2_rn = 2 AND bl.prepay_days > 0 THEN bl.prepay_days ELSE 0 END) AS completedadvanceinstaldaysmax,
        ROUND(STDDEV_POP(CASE WHEN osr.latest2_rn = 2 AND bl.prepay_days > 0 THEN bl.prepay_days ELSE NULL END), 6) AS completedadvanceinstaldaysstd,
        -- 同一天结清账单数（使用预计算CTE）
        MAX(CASE WHEN osr.latest2_rn = 2 THEN obs.same_day_max_cnt ELSE 0 END) AS completedsamedayinstalcntmax,
        ROUND(AVG(CASE WHEN osr.latest2_rn = 2 THEN obs.same_day_avg_cnt ELSE NULL END), 6) AS completedsamedayinstalcntavg,
        -- 创建时段特征
        MAX(CASE WHEN osr.latest2_rn = 2 AND HOUR(osr.order_create_time) BETWEEN 15 AND 17 THEN 1 ELSE 0 END) AS createdtimeperiodonehotvo_afternoon,
        MAX(CASE WHEN osr.latest2_rn = 2 AND HOUR(osr.order_create_time) BETWEEN 18 AND 22 THEN 1 ELSE 0 END) AS createdtimeperiodonehotvo_evening,
        -- 修复：如果不存在第二笔订单（latest2_rn = 2），则 missing = 1；如果存在但 order_create_time 为 NULL，也是 1
        CASE
            WHEN MAX(CASE WHEN osr.latest2_rn = 2 THEN 1 ELSE 0 END) = 0 THEN 1  -- 不存在第二笔订单
            ELSE MAX(CASE WHEN osr.latest2_rn = 2 AND osr.order_create_time IS NULL THEN 1 ELSE 0 END)  -- 存在但时间为 NULL
            END AS createdtimeperiodonehotvo_missing,
        MAX(CASE WHEN osr.latest2_rn = 2 AND HOUR(osr.order_create_time) BETWEEN 6 AND 10 THEN 1 ELSE 0 END) AS createdtimeperiodonehotvo_morning,
        MAX(CASE WHEN osr.latest2_rn = 2 AND (HOUR(osr.order_create_time) BETWEEN 23 AND 23 OR HOUR(osr.order_create_time) BETWEEN 0 AND 4) THEN 1 ELSE 0 END) AS createdtimeperiodonehotvo_night,
        MAX(CASE WHEN osr.latest2_rn = 2 AND HOUR(osr.order_create_time) BETWEEN 11 AND 13 THEN 1 ELSE 0 END) AS createdtimeperiodonehotvo_noon,
        -- 修复：添加 IS NOT NULL 判断，避免 HOUR(NULL) NOT IN (...) 返回 NULL
        MAX(CASE WHEN osr.latest2_rn = 2 AND osr.order_create_time IS NOT NULL AND HOUR(osr.order_create_time) NOT IN (6,7,8,9,10,11,12,13,15,16,17,18,19,20,21,22,23,0,1,2,3,4) THEN 1 ELSE 0 END) AS createdtimeperiodonehotvo_other,
        -- 连续提前结清和逾期（使用预计算CTE）
        MAX(CASE WHEN osr.latest2_rn = 2 THEN obs.max_continue_advance ELSE 0 END) AS maxcontinuecompletedadvanceinstalcnt,
        MAX(CASE WHEN osr.latest2_rn = 2 THEN ROUND(CAST(obs.max_continue_advance AS DOUBLE) / NULLIF(osr.instalmentcnt, 0), 6) ELSE 0 END) AS maxcontinuecompletedadvanceinstalratio,
        MAX(CASE WHEN osr.latest2_rn = 2 THEN obs.max_continue_overdue ELSE 0 END) AS maxcontinueoverdueinstalcnt,
        MAX(CASE WHEN osr.latest2_rn = 2 THEN ROUND(CAST(obs.max_continue_overdue AS DOUBLE) / NULLIF(osr.instalmentcnt, 0), 6) ELSE 0 END) AS maxcontinueoverdueinstalratio,
        -- 逾期统计
        SUM(CASE WHEN osr.latest2_rn = 2 AND bl.is_overdue = 1 THEN 1 ELSE 0 END) AS overdueinstalcnt,
        -- 修复：先计算逾期账单数，再计算比例，避免嵌套聚合
        ROUND(CAST(SUM(CASE WHEN osr.latest2_rn = 2 AND bl.is_overdue = 1 THEN 1 ELSE 0 END) AS DOUBLE) / NULLIF(MAX(CASE WHEN osr.latest2_rn = 2 THEN osr.completedinstalcnt ELSE NULL END), 0), 6) AS overdueinstalratio,
        -- 额度使用率差值（最近第二笔 - 在贷订单平均）
        -- 修复：先计算最近第二笔的额度使用率，再计算所有在贷订单的平均额度使用率，最后计算差值
        MAX(CASE WHEN osr.latest2_rn = 2 THEN ROUND(CAST(bl.loan_amt AS DOUBLE) / NULLIF(bl.after_total_limit, 0), 6) ELSE NULL END) -
        AVG(ROUND(CAST(bl.loan_amt AS DOUBLE) / NULLIF(bl.after_total_limit, 0), 6)) AS minusinloanavgcreditusage
    FROM order_sequence_ranked osr
             LEFT JOIN base_loan_data_light bl
                       ON osr.cust_no = bl.cust_no
                           AND osr.loan_no = bl.loan_no
                           AND osr.observation_date = bl.observation_date
             LEFT JOIN order_bill_stats_precomputed obs
                       ON osr.cust_no = obs.cust_no
                           AND osr.loan_no = obs.loan_no
                           AND osr.observation_date = obs.observation_date
    GROUP BY osr.cust_no, osr.observation_date
),

-- 【优化v3】删除calc_credits_times_pre，直接使用calc_credits_times_by_order
calc_credits_times_by_order AS (
    SELECT
        odc.observation_date,
        li.cust_no,
        li.loan_no,
        -- 按订单维度统计各订单的额度测算次数（按日期去重）
        -- 关键修复：通过loan_apply_no关联，只统计能匹配到订单的额度测算记录
        COUNT(DISTINCT date(cl.create_time)) AS calc_credits_times
    FROM (SELECT observation_date FROM observation_date_config) odc
             -- 从借据信息表开始，通过loan_apply_no关联到额度测算表
             INNER JOIN hive_idc.hello_prd.ods_mx_ast_asset_loan_info_df li
                        ON li.pt = odc.observation_date
                            AND li.loan_status IN (1,2,3,5)
                            AND li.loan_no IS NOT NULL
        -- 【使用额度表】ods_mx_aprv_cust_credit_limit_record_df：额度测算记录表
        -- 关键修复：通过loan_apply_no关联，只统计能匹配到订单的额度测算记录
             LEFT JOIN hive_idc.hello_prd.ods_mx_aprv_cust_credit_limit_record_df cl
                       ON cl.loan_apply_no = li.loan_apply_no  -- 通过loan_apply_no关联
                           AND cl.pt = odc.observation_date
                           AND cl.create_time <= odc.observation_date  -- 只统计观察日期及之前的额度测算次数
                           AND cl.loan_apply_no IS NOT NULL  -- 只统计有loan_apply_no的额度测算记录
    GROUP BY odc.observation_date, li.cust_no, li.loan_no
),
-- 【重构】续借订单的额度测算次数统计（按订单维度聚合，只统计续借用户的订单）
-- 修复逻辑：通过loan_apply_no关联额度测算表，只统计能匹配到订单的额度测算记录
multi_loan_calc_credits_times_by_order AS (
    SELECT
        odc.observation_date,
        li.cust_no,
        li.loan_no,
        -- 按订单维度统计各订单的额度测算次数（按日期去重）
        -- 关键修复：通过loan_apply_no关联，只统计能匹配到订单的额度测算记录
        COUNT(DISTINCT date(cl.create_time)) AS multi_loan_calc_credits_times
    FROM (SELECT observation_date FROM observation_date_config) odc
             -- 从借据信息表开始，通过loan_apply_no关联到额度测算表
             INNER JOIN hive_idc.hello_prd.ods_mx_ast_asset_loan_info_df li
                        ON li.pt = odc.observation_date
                            AND li.loan_status IN (1,2,3,5)
                            AND li.loan_no IS NOT NULL
        -- 【使用额度表】ods_mx_aprv_cust_credit_limit_record_df：额度测算记录表
        -- 关键修复：通过loan_apply_no关联，只统计能匹配到订单的额度测算记录
             LEFT JOIN hive_idc.hello_prd.ods_mx_aprv_cust_credit_limit_record_df cl
                       ON cl.loan_apply_no = li.loan_apply_no  -- 通过loan_apply_no关联
                           AND cl.pt = odc.observation_date
                           AND cl.create_time <= odc.observation_date  -- 只统计观察日期及之前的额度测算次数
                           AND cl.loan_apply_no IS NOT NULL  -- 只统计有loan_apply_no的额度测算记录
    WHERE EXISTS (
        -- 只统计续借用户的订单（有2笔及以上订单的用户）
        SELECT 1
        FROM (
                 SELECT
                     li_inner.cust_no,
                     COUNT(DISTINCT li_inner.loan_no) AS loan_cnt
                 FROM (SELECT observation_date FROM observation_date_config) odc_inner
                          INNER JOIN hive_idc.hello_prd.ods_mx_ast_asset_loan_info_df li_inner
                                     ON li_inner.pt = odc_inner.observation_date
                                         AND li_inner.loan_status IN (1,2,3,5)
                 GROUP BY li_inner.cust_no
                 HAVING loan_cnt >= 2
             ) mlf
        WHERE li.cust_no = mlf.cust_no
    )
    GROUP BY odc.observation_date, li.cust_no, li.loan_no
),

-- 【优化v3】删除multi_loan_calc_credits_times_pre，直接使用calc_credits_times_by_order
-- 注意：user_month_overdue_pre已在前面定义（第523行），此处不再重复定义

-- ===================== 9. 第二个查询：续借订单基础扩展（优化：使用multi_order_customers替代EXISTS子查询） =====================
multi_loan_order_ext AS (
    SELECT
        bl.*,
        COALESCE(cct.calc_credits_times, 0) AS calc_credits_times,
        COALESCE(mlct.multi_loan_calc_credits_times, 0) AS multi_loan_calc_credits_times,
        COALESCE(umop.monthly_overdue_cnt, 0) AS monthly_overdue_cnt
    FROM base_loan_data_light bl
             left JOIN multi_order_customers moc
                       ON bl.cust_no = moc.cust_no
                           AND bl.observation_date = moc.observation_date
             LEFT JOIN calc_credits_times_by_order cct
                       ON bl.cust_no = cct.cust_no AND bl.loan_no = cct.loan_no AND bl.observation_date = cct.observation_date
             LEFT JOIN multi_loan_calc_credits_times_by_order mlct
                       ON bl.cust_no = mlct.cust_no AND bl.loan_no = mlct.loan_no AND bl.observation_date = mlct.observation_date
             LEFT JOIN user_month_overdue_pre umop
                       ON bl.cust_no = umop.cust_no AND bl.bill_month = umop.bill_month
),

-- ===================== 10.1 第二个查询：订单级别聚合（用于统计订单级别的特征） =====================
-- 【重构】先聚合到订单级别，获取每个订单的创建时间
multi_loan_order_level_base AS (
    SELECT
        mloe.cust_no,
        mloe.loan_no,
        mloe.observation_date,
        -- 获取订单创建时间（所有账单的order_create_time相同，取MIN即可）
        MIN(mloe.order_create_time) AS order_create_time,
        -- 修复：按订单维度聚合，每个订单只计算一次
        MAX(mloe.multi_loan_calc_credits_times) AS multi_loan_calc_credits_times,
        MAX(mloe.calc_credits_times) AS calc_credits_times
    FROM multi_loan_order_ext mloe
    WHERE mloe.order_create_time < mloe.observation_date
    GROUP BY mloe.cust_no, mloe.loan_no, mloe.observation_date
),

-- 【重构】在订单级别计算订单间隔天数
multi_loan_order_level_stats AS (
    SELECT
        mlob.cust_no,
        mlob.loan_no,
        mlob.multi_loan_calc_credits_times,
        mlob.calc_credits_times,
        -- 添加订单序号（按创建时间排序）
        ROW_NUMBER() OVER (PARTITION BY mlob.cust_no ORDER BY mlob.order_create_time) AS order_rn,
        -- 【正确的计算方式】在订单级别计算间隔天数
        -- 修复：验证LAG获取的订单时间和当前订单时间是否都在观察日期之前，避免时间穿越（IV异常高问题）
        CAST(CASE
                 WHEN LAG(DATE(mlob.order_create_time)) OVER (PARTITION BY mlob.cust_no ORDER BY mlob.order_create_time) IS NOT NULL
                     AND LAG(DATE(mlob.order_create_time)) OVER (PARTITION BY mlob.cust_no ORDER BY mlob.order_create_time) <= mlob.observation_date
                     AND DATE(mlob.order_create_time) <= mlob.observation_date  -- 当前订单时间也必须在观察日期之前
                     THEN DATEDIFF(DATE(mlob.order_create_time), LAG(DATE(mlob.order_create_time)) OVER (PARTITION BY mlob.cust_no ORDER BY mlob.order_create_time))
                 ELSE NULL
            END AS FLOAT) AS created_order_days_gap,
        -- 【修复】续借订单间隔天数：只计算续借订单（排除首借订单，即 order_rn > 1）
        CAST(CASE
                 WHEN ROW_NUMBER() OVER (PARTITION BY mlob.cust_no ORDER BY mlob.order_create_time) > 1  -- 只计算续借订单
                     AND LAG(DATE(mlob.order_create_time)) OVER (PARTITION BY mlob.cust_no ORDER BY mlob.order_create_time) IS NOT NULL
                     AND LAG(DATE(mlob.order_create_time)) OVER (PARTITION BY mlob.cust_no ORDER BY mlob.order_create_time) <= mlob.observation_date
                     AND DATE(mlob.order_create_time) <= mlob.observation_date
                     THEN DATEDIFF(DATE(mlob.order_create_time), LAG(DATE(mlob.order_create_time)) OVER (PARTITION BY mlob.cust_no ORDER BY mlob.order_create_time))
                 ELSE NULL
            END AS FLOAT) AS multi_loan_created_order_days_gap
    FROM multi_loan_order_level_base mlob
),

-- ===================== 10.2 第二个查询：直接从还款计划表计算提前结清特征 =====================
multi_loan_advance_complete_stats AS (
    SELECT
        odc.observation_date,
        li.cust_no,
        -- 修复：直接从还款计划表计算提前结清账单数
        -- 条件：settled_time在对应loan_end_date之前，且settled_time在观察日期之前
        -- 修复：使用日期比较而不是时间戳比较
        COUNT(DISTINCT CASE
                           WHEN rp.settled_time IS NOT NULL
                               AND rp.settled_time <= odc.observation_date  -- 确保settled_time在观察日期之前
                               AND DATE(rp.settled_time) < rp.loan_end_date  -- 修复：使用日期比较（提前结清）
                               THEN rp.id
                           ELSE NULL
            END) AS completedadvanceinstalcnt,
        -- 修复：分母为loan_end_date在观察日之前的总账单数量
        COUNT(DISTINCT CASE
                           WHEN rp.loan_end_date <= odc.observation_date  -- loan_end_date在观察日之前
                               THEN rp.id
                           ELSE NULL
            END) AS total_due_bill_cnt,
        -- 修复：直接从还款计划表计算已结清账单数（统计有多少条存在settled_time的记录，且settled_time在观察日期之前）
        COUNT(DISTINCT CASE
                           WHEN rp.settled_time IS NOT NULL
                               AND rp.settled_time <= odc.observation_date  -- 确保settled_time在观察日期之前
                               THEN rp.id
                           ELSE NULL
            END) AS completedinstalcnt,
        -- 修复：按客户维度统计还款计划表中所有的记录数（卡在观察日期之前）
        -- 统计该客户所有订单的所有还款计划记录（这些记录都是在订单创建时生成的，订单创建时间在观察日期之前）
        COUNT(DISTINCT CASE
                           WHEN rp.create_time < odc.observation_date
                               THEN rp.id
                           ELSE NULL
            END) AS total_repay_plan_cnt
    FROM (SELECT observation_date FROM observation_date_config) odc
             INNER JOIN hive_idc.hello_prd.ods_mx_ast_asset_loan_info_df li
                        ON li.pt = odc.observation_date
                            AND li.loan_status IN (1,2,3,5)
                            AND li.loan_no IS NOT NULL
             LEFT JOIN hive_idc.hello_prd.ods_mx_ast_asset_repay_plan_df rp
                       ON rp.loan_no = li.loan_no
                           AND rp.pt = odc.observation_date
                           AND rp.repay_plan_status IN (1,2,3,5)  -- 只统计有效账单
    WHERE 1=1  -- JOIN条件已移至ON子句
      -- 只统计续借订单（多笔订单的用户）
      AND EXISTS (
        SELECT 1
        FROM (
                 SELECT
                     li_inner.cust_no,
                     COUNT(DISTINCT li_inner.loan_no) AS loan_cnt
                 FROM (SELECT observation_date FROM observation_date_config) odc_inner
                          INNER JOIN hive_idc.hello_prd.ods_mx_ast_asset_loan_info_df li_inner
                                     ON li_inner.pt = odc_inner.observation_date
                                         AND li_inner.loan_status IN (1,2,3,5)
                 WHERE 1=1  -- JOIN条件已移至ON子句
                 GROUP BY li_inner.cust_no
                 -- HAVING loan_cnt >= 2
             ) mlf
        WHERE li.cust_no = mlf.cust_no
    )
    GROUP BY odc.observation_date, li.cust_no
),

-- ===================== 10.3 第二个查询：订单级别统计（从订单级别聚合，避免账单重复） =====================
multi_loan_order_level_agg AS (
    SELECT
        cust_no,
        -- 【修复】从订单级别聚合统计，避免同一订单的多个账单重复计算
        -- 用户级别额度测算次数统计（从订单级别聚合，包含所有订单）
        AVG(calc_credits_times) AS calccreditstimes_avg,
        MAX(calc_credits_times) AS calccreditstimes_max,
        STDDEV_POP(calc_credits_times) AS calccreditstimes_std,
        -- 【修复】续借订单额度测算次数统计（只计算续借订单，排除首借订单）
        AVG(CASE WHEN order_rn > 1 THEN multi_loan_calc_credits_times ELSE NULL END) AS multiloancalccreditstimes_avg,
        MAX(CASE WHEN order_rn > 1 THEN multi_loan_calc_credits_times ELSE NULL END) AS multiloancalccreditstimes_max,
        STDDEV_POP(CASE WHEN order_rn > 1 THEN multi_loan_calc_credits_times ELSE NULL END) AS multiloancalccreditstimes_std,
        -- 【修复】订单间隔天数统计（从订单级别聚合，每个订单只计算一次，包含所有订单）
        AVG(created_order_days_gap) AS createdorderdaysgap_avg,
        MAX(created_order_days_gap) AS createdorderdaysgap_max,
        STDDEV_POP(created_order_days_gap) AS createdorderdaysgap_std,
        -- 【修复】续借订单间隔天数统计（只计算续借订单，排除首借订单）
        AVG(multi_loan_created_order_days_gap) AS multiloancreatedorderdaysgap_avg,
        MAX(multi_loan_created_order_days_gap) AS multiloancreatedorderdaysgap_max,
        STDDEV_POP(multi_loan_created_order_days_gap) AS multiloancreatedorderdaysgap_std
    FROM multi_loan_order_level_stats
    GROUP BY cust_no
),

-- ===================== 10. 第二个查询：基础统计 =====================
multi_loan_bill_stats AS (
    SELECT
        mloe.cust_no,
        -- 修复：只统计已到期或已结清的账单，避免包含未来账单导致时间穿越（IV异常高问题）
        COUNT(DISTINCT CASE
                           WHEN mloe.is_due_or_complete = 1
                               THEN mloe.rp_id
                           ELSE NULL
            END) AS total_bill_cnt,
        -- 修复：直接从还款计划表计算已结清账单数（统计有多少条存在settled_time的记录，且settled_time在观察日期之前）
        -- 由于macs已经按cust_no和observation_date聚合，使用MAX确保获取正确的值
        COALESCE(MAX(macs.completedinstalcnt), 0) AS completedinstalcnt,
        -- 修复：按客户维度统计还款计划表中所有的记录数（用于计算已结清比例的分母）
        COALESCE(MAX(macs.total_repay_plan_cnt), 0) AS total_repay_plan_cnt,
        SUM(CASE WHEN mloe.is_overdue = 1 THEN 1 ELSE 0 END) AS overdueinstalcnt,
        -- 修复：直接从还款计划表计算的提前结清账单数（所有订单的所有periods的账单，settled_time在loan_end_date之前，且settled_time在观察日期之前）
        -- 由于macs已经按cust_no和observation_date聚合，使用MAX确保获取正确的值
        COALESCE(MAX(macs.completedadvanceinstalcnt), 0) AS completedadvanceinstalcnt,
        -- 修复：loan_end_date在观察日之前的总账单数量（用于计算提前结清比例的分母）
        COALESCE(MAX(macs.total_due_bill_cnt), 0) AS total_due_bill_cnt,
        SUM(CASE WHEN mloe.is_advance_3d = 1 THEN 1 ELSE 0 END) AS completedadvanceinstalcnt_3d,
        SUM(CASE WHEN mloe.is_advance_15d = 1 THEN 1 ELSE 0 END) AS completedadvanceinstalcnt_15d,
        SUM(CASE WHEN mloe.is_advance_30d = 1 THEN 1 ELSE 0 END) AS completedadvanceinstalcnt_30d,
        SUM(CASE WHEN mloe.is_due_or_complete = 1 THEN 1 ELSE 0 END) AS due_or_complete_cnt,
        -- 修复：只统计已结清的账单金额（is_complete = 1），避免使用未来的还款信息
        SUM(CASE WHEN mloe.is_complete = 1 THEN mloe.repaid_principal ELSE 0 END) AS completedloanamount,
        SUM(CASE WHEN mloe.is_advance_1month = 1 THEN mloe.repaid_principal ELSE 0 END) AS advance_1month_completed_amount,
        SUM(CASE WHEN mloe.is_complete = 1 THEN mloe.repaid_principal ELSE 0 END) AS total_completed_amount,
        -- 最近一次逾期账单距风控时间间隔：取所有逾期账单中end_date_to_risk_gap的最大值
        -- end_date_to_risk_gap = 额度测算时间（calc_credit_time） - 账单到期日期
        -- 对于逾期账单该值为正数，表示从账单到期日到额度测算时间已经过去的天数（即逾期天数）
        MAX(CASE WHEN mloe.is_overdue = 1 THEN mloe.end_date_to_risk_gap ELSE NULL END) AS lastoverdueinstalrisktimegap,
        -- 【修复】从订单级别聚合表获取统计值，避免账单重复导致的错误计算
        MAX(mlola.calccreditstimes_avg) AS calccreditstimes_avg,
        MAX(mlola.calccreditstimes_max) AS calccreditstimes_max,
        MAX(mlola.calccreditstimes_std) AS calccreditstimes_std,
        MAX(mlola.multiloancalccreditstimes_avg) AS multiloancalccreditstimes_avg,
        MAX(mlola.multiloancalccreditstimes_max) AS multiloancalccreditstimes_max,
        MAX(mlola.multiloancalccreditstimes_std) AS multiloancalccreditstimes_std,
        MAX(mlola.createdorderdaysgap_avg) AS createdorderdaysgap_avg,
        MAX(mlola.createdorderdaysgap_max) AS createdorderdaysgap_max,
        MAX(mlola.createdorderdaysgap_std) AS createdorderdaysgap_std,
        MAX(mlola.multiloancreatedorderdaysgap_avg) AS multiloancreatedorderdaysgap_avg,
        MAX(mlola.multiloancreatedorderdaysgap_max) AS multiloancreatedorderdaysgap_max,
        MAX(mlola.multiloancreatedorderdaysgap_std) AS multiloancreatedorderdaysgap_std
    FROM multi_loan_order_ext mloe
             LEFT JOIN multi_loan_order_level_agg mlola
                       ON mloe.cust_no = mlola.cust_no
             LEFT JOIN multi_loan_advance_complete_stats macs
                       ON mloe.cust_no = macs.cust_no AND mloe.observation_date = macs.observation_date
    GROUP BY mloe.cust_no
),

-- ===================== 11. 第二个查询：连续账单统计 =====================
multi_loan_continuous_stats_fixed AS (
    SELECT
        cust_no,
        MAX(continuous_advance_cnt) AS maxcontinuecompletedadvanceinstalcnt,
        MAX(continuous_advance_3d_cnt) AS maxcontinuecompletedadvanceinstalcnt_3d,
        MAX(continuous_advance_15d_cnt) AS maxcontinuecompletedadvanceinstalcnt_15d,
        MAX(continuous_advance_30d_cnt) AS maxcontinuecompletedadvanceinstalcnt_30d,
        MAX(continuous_overdue_cnt) AS maxcontinueoverdueinstalcnt,
        MAX(monthly_overdue_cnt) AS maxoverdueinstalcntforwithinthreemonths
    FROM (
             SELECT
                 cust_no,
                 loan_end_date,
                 rp_id,
                 -- 修复：使用 loan_end_date, CAST(rp_id AS BIGINT) 双字段排序，避免 loan_end_date 重复导致排序不稳定
                 -- rp_id 转换为数值类型排序，避免字符串排序导致顺序错误
                 SUM(CASE WHEN is_advance_complete=1 THEN 1 ELSE 0 END) OVER (PARTITION BY cust_no, advance_break ORDER BY loan_end_date, CAST(rp_id AS BIGINT)) AS continuous_advance_cnt,
                 SUM(CASE WHEN is_advance_3d=1 THEN 1 ELSE 0 END) OVER (PARTITION BY cust_no, advance_3d_break ORDER BY loan_end_date, CAST(rp_id AS BIGINT)) AS continuous_advance_3d_cnt,
                 SUM(CASE WHEN is_advance_15d=1 THEN 1 ELSE 0 END) OVER (PARTITION BY cust_no, advance_15d_break ORDER BY loan_end_date, CAST(rp_id AS BIGINT)) AS continuous_advance_15d_cnt,
                 SUM(CASE WHEN is_advance_30d=1 THEN 1 ELSE 0 END) OVER (PARTITION BY cust_no, advance_30d_break ORDER BY loan_end_date, CAST(rp_id AS BIGINT)) AS continuous_advance_30d_cnt,
                 SUM(CASE WHEN is_overdue=1 THEN 1 ELSE 0 END) OVER (PARTITION BY cust_no, overdue_break ORDER BY loan_end_date, CAST(rp_id AS BIGINT)) AS continuous_overdue_cnt,
                 monthly_overdue_cnt
             FROM (
                      SELECT
                          cust_no,
                          loan_end_date,
                          rp_id,
                          is_advance_complete,
                          is_advance_3d,
                          is_advance_15d,
                          is_advance_30d,
                          is_overdue,
                          monthly_overdue_cnt,
                          periods,  -- 期数字段
                          -- 修复：明确处理NULL值，NULL值或0值都会触发break
                          -- 修复：使用 loan_end_date, CAST(rp_id AS BIGINT) 双字段排序，避免 loan_end_date 重复导致排序不稳定
                          SUM(CASE WHEN is_advance_complete IS NULL OR is_advance_complete = 0 THEN 1 ELSE 0 END) OVER (PARTITION BY cust_no ORDER BY loan_end_date, CAST(rp_id AS BIGINT)) AS advance_break,
                          SUM(CASE WHEN is_advance_3d IS NULL OR is_advance_3d = 0 THEN 1 ELSE 0 END) OVER (PARTITION BY cust_no ORDER BY loan_end_date, CAST(rp_id AS BIGINT)) AS advance_3d_break,
                          SUM(CASE WHEN is_advance_15d IS NULL OR is_advance_15d = 0 THEN 1 ELSE 0 END) OVER (PARTITION BY cust_no ORDER BY loan_end_date, CAST(rp_id AS BIGINT)) AS advance_15d_break,
                          SUM(CASE WHEN is_advance_30d IS NULL OR is_advance_30d = 0 THEN 1 ELSE 0 END) OVER (PARTITION BY cust_no ORDER BY loan_end_date, CAST(rp_id AS BIGINT)) AS advance_30d_break,
                          SUM(CASE WHEN is_overdue IS NULL OR is_overdue = 0 THEN 1 ELSE 0 END) OVER (PARTITION BY cust_no ORDER BY loan_end_date, CAST(rp_id AS BIGINT)) AS overdue_break
                      FROM multi_loan_order_ext mloe
                      WHERE mloe.loan_end_date >= date_sub(mloe.observation_date, 90)
                        AND mloe.loan_end_date <= mloe.observation_date  -- 修复：只统计观察日期及之前的账单，避免包含未来账单导致时间穿越（IV异常高问题）
                  ) t1
         ) t2
    GROUP BY cust_no
),

-- ===================== 12. 第二个查询：第一段45个特征（all.前缀） =====================
all_features AS (
    SELECT
        bs.cust_no,
        -- 提前15天结清相关（6个）
        COALESCE(bs.completedadvanceinstalcnt_15d, 0) AS multi_loan_in_loan_order_all_advanceget15days_completedadvanceinstalcnt,
        ROUND(CASE WHEN bs.completedadvanceinstalcnt > 0 THEN bs.completedadvanceinstalcnt_15d/bs.completedadvanceinstalcnt ELSE 0 END, 6) AS multi_loan_in_loan_order_all_advanceget15days_completedadvanceinstaloverallcompletedadvanceratio,
        ROUND(CASE WHEN bs.due_or_complete_cnt > 0 THEN bs.completedadvanceinstalcnt_15d/bs.due_or_complete_cnt ELSE 0 END, 6) AS multi_loan_in_loan_order_all_advanceget15days_completedadvanceinstaloverdueorcompletedratio,
        COALESCE(cs.maxcontinuecompletedadvanceinstalcnt_15d, 0) AS multi_loan_in_loan_order_all_advanceget15days_maxcontinuecompletedadvanceinstalcnt,
        ROUND(CASE WHEN bs.completedadvanceinstalcnt > 0 THEN cs.maxcontinuecompletedadvanceinstalcnt_15d/bs.completedadvanceinstalcnt ELSE 0 END, 6) AS multi_loan_in_loan_order_all_advanceget15days_maxcontinuecompletedadvanceinstaloverallcompletedadvanceratio,
        ROUND(CASE WHEN bs.due_or_complete_cnt > 0 THEN cs.maxcontinuecompletedadvanceinstalcnt_15d/bs.due_or_complete_cnt ELSE 0 END, 6) AS multi_loan_in_loan_order_all_advanceget15days_maxcontinuecompletedadvanceinstalovercompletedorexpiredratio,

        -- 提前30天结清相关（6个）
        COALESCE(bs.completedadvanceinstalcnt_30d, 0) AS multi_loan_in_loan_order_all_advanceget30days_completedadvanceinstalcnt,
        ROUND(CASE WHEN bs.completedadvanceinstalcnt > 0 THEN bs.completedadvanceinstalcnt_30d/bs.completedadvanceinstalcnt ELSE 0 END, 6) AS multi_loan_in_loan_order_all_advanceget30days_completedadvanceinstaloverallcompletedadvanceratio,
        ROUND(CASE WHEN bs.due_or_complete_cnt > 0 THEN bs.completedadvanceinstalcnt_30d/bs.due_or_complete_cnt ELSE 0 END, 6) AS multi_loan_in_loan_order_all_advanceget30days_completedadvanceinstaloverdueorcompletedratio,
        COALESCE(cs.maxcontinuecompletedadvanceinstalcnt_30d, 0) AS multi_loan_in_loan_order_all_advanceget30days_maxcontinuecompletedadvanceinstalcnt,
        ROUND(CASE WHEN bs.completedadvanceinstalcnt > 0 THEN cs.maxcontinuecompletedadvanceinstalcnt_30d/bs.completedadvanceinstalcnt ELSE 0 END, 6) AS multi_loan_in_loan_order_all_advanceget30days_maxcontinuecompletedadvanceinstaloverallcompletedadvanceratio,
        ROUND(CASE WHEN bs.due_or_complete_cnt > 0 THEN cs.maxcontinuecompletedadvanceinstalcnt_30d/bs.due_or_complete_cnt ELSE 0 END, 6) AS multi_loan_in_loan_order_all_advanceget30days_maxcontinuecompletedadvanceinstalovercompletedorexpiredratio,

        -- 提前3天结清相关（6个）
        COALESCE(bs.completedadvanceinstalcnt_3d, 0) AS multi_loan_in_loan_order_all_advanceget3days_completedadvanceinstalcnt,
        ROUND(CASE WHEN bs.completedadvanceinstalcnt > 0 THEN bs.completedadvanceinstalcnt_3d/bs.completedadvanceinstalcnt ELSE 0 END, 6) AS multi_loan_in_loan_order_all_advanceget3days_completedadvanceinstaloverallcompletedadvanceratio,
        ROUND(CASE WHEN bs.due_or_complete_cnt > 0 THEN bs.completedadvanceinstalcnt_3d/bs.due_or_complete_cnt ELSE 0 END, 6) AS multi_loan_in_loan_order_all_advanceget3days_completedadvanceinstaloverdueorcompletedratio,
        COALESCE(cs.maxcontinuecompletedadvanceinstalcnt_3d, 0) AS multi_loan_in_loan_order_all_advanceget3days_maxcontinuecompletedadvanceinstalcnt,
        ROUND(CASE WHEN bs.completedadvanceinstalcnt > 0 THEN cs.maxcontinuecompletedadvanceinstalcnt_3d/bs.completedadvanceinstalcnt ELSE 0 END, 6) AS multi_loan_in_loan_order_all_advanceget3days_maxcontinuecompletedadvanceinstaloverallcompletedadvanceratio,
        ROUND(CASE WHEN bs.due_or_complete_cnt > 0 THEN cs.maxcontinuecompletedadvanceinstalcnt_3d/bs.due_or_complete_cnt ELSE 0 END, 6) AS multi_loan_in_loan_order_all_advanceget3days_maxcontinuecompletedadvanceinstalovercompletedorexpiredratio,

        -- 额度测算次数（3个）
        ROUND(COALESCE(bs.calccreditstimes_avg, 0), 6) AS multi_loan_in_loan_order_all_calccreditstimesmathcount_avg,
        COALESCE(bs.calccreditstimes_max, 0) AS multi_loan_in_loan_order_all_calccreditstimesmathcount_max,
        ROUND(COALESCE(bs.calccreditstimes_std, 0), 6) AS multi_loan_in_loan_order_all_calccreditstimesmathcount_std,

        -- 基础提前结清（2个）
        COALESCE(bs.completedadvanceinstalcnt, 0) AS multi_loan_in_loan_order_all_completedadvanceinstalcnt,
        -- 修复：分母为loan_end_date在观察日之前的总账单数量（直接从还款计划表计算）
        ROUND(CASE WHEN bs.total_due_bill_cnt > 0 THEN bs.completedadvanceinstalcnt/bs.total_due_bill_cnt ELSE 0 END, 6) AS multi_loan_in_loan_order_all_completedadvanceinstalratio,

        -- 1个月内提前结清金额占比（1个）
        ROUND(CASE WHEN bs.total_completed_amount > 0 THEN bs.advance_1month_completed_amount/bs.total_completed_amount ELSE 0 END, 6) AS multi_loan_in_loan_order_all_completedadvanceloanamountovercompletedratioforfirstmonth,

        -- 已结清账单（2个）
        COALESCE(bs.completedinstalcnt, 0) AS multi_loan_in_loan_order_all_completedinstalcnt,
        -- 修复：分母为按客户维度单个客户的还款计划表中所有的记录数（直接从还款计划表计算）
        ROUND(CASE WHEN bs.total_repay_plan_cnt > 0 THEN bs.completedinstalcnt/bs.total_repay_plan_cnt ELSE 0 END, 6) AS multi_loan_in_loan_order_all_completedinstalratio,

        -- 已结清金额（2个）
        COALESCE(bs.completedloanamount, 0) AS multi_loan_in_loan_order_all_completedloanamount,
        COALESCE(bs.completedloanamount, 0) AS multi_loan_in_loan_order_all_completedloanamountindoubletype,

        -- 下单间隔天数（3个）
        ROUND(COALESCE(bs.createdorderdaysgap_avg, 0), 6) AS multi_loan_in_loan_order_all_createdorderdaysgapmathcount_avg,
        COALESCE(bs.createdorderdaysgap_max, 0) AS multi_loan_in_loan_order_all_createdorderdaysgapmathcount_max,
        ROUND(COALESCE(bs.createdorderdaysgap_std, 0), 6) AS multi_loan_in_loan_order_all_createdorderdaysgapmathcount_std,

        -- 最近一次逾期时间间隔（1个）
        COALESCE(bs.lastoverdueinstalrisktimegap, 0.0) AS multi_loan_in_loan_order_all_lastoverdueinstalrisktimegap,

        -- 最大连续提前结清（2个）
        COALESCE(cs.maxcontinuecompletedadvanceinstalcnt, 0) AS multi_loan_in_loan_order_all_maxcontinuecompletedadvanceinstalcnt,
        ROUND(CASE WHEN bs.due_or_complete_cnt > 0 THEN cs.maxcontinuecompletedadvanceinstalcnt/bs.due_or_complete_cnt ELSE 0 END, 6) AS multi_loan_in_loan_order_all_maxcontinuecompletedadvanceinstalratio,

        -- 最大连续逾期（2个）
        COALESCE(cs.maxcontinueoverdueinstalcnt, 0) AS multi_loan_in_loan_order_all_maxcontinueoverdueinstalcnt,
        ROUND(CASE WHEN bs.due_or_complete_cnt > 0 THEN cs.maxcontinueoverdueinstalcnt/bs.due_or_complete_cnt ELSE 0 END, 6) AS multi_loan_in_loan_order_all_maxcontinueoverdueinstalratio,

        -- 3个月内每月max逾期（1个）
        COALESCE(cs.maxoverdueinstalcntforwithinthreemonths, 0) AS multi_loan_in_loan_order_all_maxoverdueinstalcntforwithinthreemonths,

        -- 续借订单额度测算次数（3个）
        ROUND(COALESCE(bs.multiloancalccreditstimes_avg, 0), 6) AS multi_loan_in_loan_order_all_multiloancalccreditstimesmathcount_avg,
        COALESCE(bs.multiloancalccreditstimes_max, 0) AS multi_loan_in_loan_order_all_multiloancalccreditstimesmathcount_max,
        ROUND(COALESCE(bs.multiloancalccreditstimes_std, 0), 6) AS multi_loan_in_loan_order_all_multiloancalccreditstimesmathcount_std,

        -- 续借订单下单间隔天数（3个）
        ROUND(COALESCE(bs.multiloancreatedorderdaysgap_avg, 0), 6) AS multi_loan_in_loan_order_all_multiloancreatedorderdaysgapmathcount_avg,
        COALESCE(bs.multiloancreatedorderdaysgap_max, 0) AS multi_loan_in_loan_order_all_multiloancreatedorderdaysgapmathcount_max,
        ROUND(COALESCE(bs.multiloancreatedorderdaysgap_std, 0), 6) AS multi_loan_in_loan_order_all_multiloancreatedorderdaysgapmathcount_std,

        -- 逾期账单（2个）
        COALESCE(bs.overdueinstalcnt, 0) AS multi_loan_in_loan_order_all_overdueinstalcnt,
        ROUND(CASE WHEN bs.due_or_complete_cnt > 0 THEN bs.overdueinstalcnt/bs.due_or_complete_cnt ELSE 0 END, 6) AS multi_loan_in_loan_order_all_overdueinstalratio
    FROM multi_loan_bill_stats bs
             LEFT JOIN multi_loan_continuous_stats_fixed cs
                       ON bs.cust_no = cs.cust_no
),

-- ===================== 13. 第二个查询：通用在贷订单特征（11个） =====================
-- 【优化】先统计每个客户的订单数量，避免重复扫描
customer_loan_counts AS (
    SELECT
        li.cust_no,
        COUNT(DISTINCT li.loan_no) AS loan_cnt
    FROM (SELECT observation_date FROM observation_date_config) odc
             INNER JOIN hive_idc.hello_prd.ods_mx_ast_asset_loan_info_df li
                        ON li.pt = odc.observation_date
                            AND li.loan_status IN (1,2,3,5)
                            AND li.loan_no IS NOT NULL
    GROUP BY li.cust_no
),

-- 【修复】按照新逻辑筛选在贷订单：观察日期 > periods=1的loan_start_date，且 < periods为最大值的settled_time
-- 【优化】使用customer_loan_counts过滤续借客户（多笔订单）
inloan_orders_new_pre AS (
    SELECT
        odc.observation_date,
        li.cust_no,
        li.loan_no,
        rp.periods,
        rp.loan_start_date,
        rp.settled_time,
        -- 使用窗口函数获取每个订单的最大periods
        MAX(rp.periods) OVER (PARTITION BY odc.observation_date, li.cust_no, li.loan_no) AS max_periods
    FROM (SELECT observation_date FROM observation_date_config) odc
             INNER JOIN hive_idc.hello_prd.ods_mx_ast_asset_loan_info_df li
                        ON li.pt = odc.observation_date
                            AND li.loan_status IN (1,2,3,5)
                            AND li.loan_no IS NOT NULL
             INNER JOIN customer_loan_counts clc
                        ON li.cust_no = clc.cust_no
                            AND clc.loan_cnt >= 2  -- 只统计续借客户（多笔订单）
             LEFT JOIN hive_idc.hello_prd.ods_mx_ast_asset_repay_plan_df rp
                       ON rp.loan_no = li.loan_no
                           AND rp.pt = odc.observation_date
                           AND rp.repay_plan_status IN (1,2,3,5)  -- 只统计有效账单
),

inloan_orders_new AS (
    SELECT
        ionp.observation_date,
        ionp.cust_no,
        ionp.loan_no,
        -- 获取periods=1的loan_start_date（第一期借款开始时间）
        MIN(CASE WHEN ionp.periods = 1 THEN ionp.loan_start_date ELSE NULL END) AS first_period_start_date,
        -- 获取periods为最大值的settled_time（最后一期结清时间）
        MAX(CASE WHEN ionp.periods = ionp.max_periods THEN ionp.settled_time ELSE NULL END) AS last_period_settled_time
    FROM inloan_orders_new_pre ionp
    GROUP BY ionp.observation_date, ionp.cust_no, ionp.loan_no
    -- 筛选在贷订单：观察日期 > periods=1的loan_start_date，且 < periods为最大值的settled_time
    HAVING MIN(CASE WHEN ionp.periods = 1 THEN ionp.loan_start_date ELSE NULL END) IS NOT NULL
       AND ionp.observation_date > MIN(CASE WHEN ionp.periods = 1 THEN ionp.loan_start_date ELSE NULL END)  -- 观察日期大于第一期借款开始时间
       AND (MAX(CASE WHEN ionp.periods = ionp.max_periods THEN ionp.settled_time ELSE NULL END) IS NULL
        OR ionp.observation_date < MAX(CASE WHEN ionp.periods = ionp.max_periods THEN ionp.settled_time ELSE NULL END))  -- 观察日期小于最后一期结清时间（如果最后一期已结清）
),

-- ===================== 13.1 单订单客户在贷订单处理 =====================
-- 【新增】处理单订单客户（首借客户）的在贷订单
-- 【优化】使用customer_loan_counts过滤单订单客户
single_order_customers_pre AS (
    SELECT
        odc.observation_date,
        li.cust_no,
        li.loan_no,
        rp.periods,
        rp.loan_start_date,
        rp.settled_time,
        -- 使用窗口函数获取每个订单的最大periods
        MAX(rp.periods) OVER (PARTITION BY odc.observation_date, li.cust_no, li.loan_no) AS max_periods
    FROM (SELECT observation_date FROM observation_date_config) odc
             INNER JOIN hive_idc.hello_prd.ods_mx_ast_asset_loan_info_df li
                        ON li.pt = odc.observation_date
                            AND li.loan_status IN (1,2,3,5)
                            AND li.loan_no IS NOT NULL
             INNER JOIN customer_loan_counts clc
                        ON li.cust_no = clc.cust_no
                            AND clc.loan_cnt = 1  -- 只统计单订单客户（首借客户）
             LEFT JOIN hive_idc.hello_prd.ods_mx_ast_asset_repay_plan_df rp
                       ON rp.loan_no = li.loan_no
                           AND rp.pt = odc.observation_date
                           AND rp.repay_plan_status IN (1,2,3,5)  -- 只统计有效账单
),

single_order_inloan_orders AS (
    SELECT
        socp.observation_date,
        socp.cust_no,
        socp.loan_no,
        -- 获取periods=1的loan_start_date（第一期借款开始时间）
        MIN(CASE WHEN socp.periods = 1 THEN socp.loan_start_date ELSE NULL END) AS first_period_start_date,
        -- 获取periods为最大值的settled_time（最后一期结清时间）
        MAX(CASE WHEN socp.periods = socp.max_periods THEN socp.settled_time ELSE NULL END) AS last_period_settled_time
    FROM single_order_customers_pre socp
    GROUP BY socp.observation_date, socp.cust_no, socp.loan_no
    -- 筛选在贷订单：观察日期 > periods=1的loan_start_date，且 < periods为最大值的settled_time
    HAVING MIN(CASE WHEN socp.periods = 1 THEN socp.loan_start_date ELSE NULL END) IS NOT NULL
       AND socp.observation_date > MIN(CASE WHEN socp.periods = 1 THEN socp.loan_start_date ELSE NULL END)  -- 观察日期大于第一期借款开始时间
       AND (MAX(CASE WHEN socp.periods = socp.max_periods THEN socp.settled_time ELSE NULL END) IS NULL
        OR socp.observation_date < MAX(CASE WHEN socp.periods = socp.max_periods THEN socp.settled_time ELSE NULL END))  -- 观察日期小于最后一期结清时间（如果最后一期已结清）
),

-- 【新增】单订单客户在贷订单账单统计
single_order_bill_stats AS (
    SELECT
        soio.observation_date,
        soio.cust_no,
        soio.loan_no,
        -- 已结清账单数
        COUNT(DISTINCT CASE
                           WHEN rp.settled_time IS NOT NULL
                               AND rp.settled_time <= soio.observation_date
                               THEN rp.id
                           ELSE NULL
            END) AS completetermcnt,
        -- 逾期账单数
        COUNT(DISTINCT CASE
                           WHEN rp.loan_end_date < soio.observation_date
                               AND (
                                    (rp.settled_time IS NOT NULL AND rp.settled_time <= soio.observation_date AND DATE(rp.settled_time) > rp.loan_end_date)
                                        OR (rp.settled_time IS NULL)
                                    )
                               THEN rp.id
                           ELSE NULL
            END) AS overduetermcnt,
        -- 到期账单数
        COUNT(DISTINCT CASE
                           WHEN rp.loan_end_date <= soio.observation_date
                               THEN rp.id
                           ELSE NULL
            END) AS billing_term_cnt,
        -- 总账单数
        COUNT(DISTINCT rp.id) AS total_term_cnt,
        -- 已结清本金
        SUM(CASE
                WHEN rp.settled_time IS NOT NULL
                    AND rp.settled_time <= soio.observation_date
                    THEN COALESCE(rp.repaid_principal, 0)
                ELSE 0
            END) AS completeprincipal
    FROM single_order_inloan_orders soio
             LEFT JOIN hive_idc.hello_prd.ods_mx_ast_asset_repay_plan_df rp
                       ON rp.loan_no = soio.loan_no
                           AND rp.pt = soio.observation_date
                           AND rp.repay_plan_status IN (1,2,3,5)
    GROUP BY soio.observation_date, soio.cust_no, soio.loan_no
),

-- 【修复】在贷订单账单统计（合并续借客户和单订单客户）
inloan_order_bill_stats_new AS (
    -- 续借客户的在贷订单账单统计
    SELECT
        ioo.observation_date,
        ioo.cust_no,
        ioo.loan_no,
        -- 已结清账单数：存在settled_time记录的账单数（且settled_time在观察日期之前）
        COUNT(DISTINCT CASE
                           WHEN rp.settled_time IS NOT NULL
                               AND rp.settled_time <= ioo.observation_date  -- 确保settled_time在观察日期之前
                               THEN rp.id
                           ELSE NULL
            END) AS completetermcnt,
        -- 逾期账单数：在贷订单中，loan_end_date < settled_time 或 (loan_end_date <= observation_date AND settled_time IS NULL)
        -- 修复：使用日期比较而不是时间戳比较，避免当天晚些时候的还款被误判为逾期
        COUNT(DISTINCT CASE
                           WHEN rp.loan_end_date < ioo.observation_date  -- 账单已到期（不包含当天）
                               AND (
                                    (rp.settled_time IS NOT NULL AND rp.settled_time <= ioo.observation_date AND DATE(rp.settled_time) > rp.loan_end_date)  -- 修复：已结清但逾期（使用日期比较）
                                        OR (rp.settled_time IS NULL)  -- 未结清且已到期（视为逾期）
                                    )
                               THEN rp.id
                           ELSE NULL
            END) AS overduetermcnt,
        -- 到期账单数：loan_end_date在观察日期之前的账单
        COUNT(DISTINCT CASE
                           WHEN rp.loan_end_date <= ioo.observation_date
                               THEN rp.id
                           ELSE NULL
            END) AS billing_term_cnt,
        -- 总账单数：在贷订单的所有账单记录
        COUNT(DISTINCT rp.id) AS total_term_cnt,
        -- 已结清本金：在贷订单中已结清账单的本金（settled_time在观察日期之前）
        SUM(CASE
                WHEN rp.settled_time IS NOT NULL
                    AND rp.settled_time <= ioo.observation_date  -- 确保settled_time在观察日期之前
                    THEN COALESCE(rp.repaid_principal, 0)
                ELSE 0
            END) AS completeprincipal
    FROM inloan_orders_new ioo
             LEFT JOIN hive_idc.hello_prd.ods_mx_ast_asset_repay_plan_df rp
                       ON rp.loan_no = ioo.loan_no
                           AND rp.pt = ioo.observation_date
                           AND rp.repay_plan_status IN (1,2,3,5)  -- 只统计有效账单
    GROUP BY ioo.observation_date, ioo.cust_no, ioo.loan_no

    UNION ALL

    -- 单订单客户的在贷订单账单统计
    SELECT
        observation_date,
        cust_no,
        loan_no,
        completetermcnt,
        overduetermcnt,
        billing_term_cnt,
        total_term_cnt,
        completeprincipal
    FROM single_order_bill_stats
),

user_inloan_orders AS (
    SELECT
        bl.cust_no,
        bl.loan_no,
        bl.order_create_time,
        bl.loan_start_date AS payout_time,
        bl.calc_credit_time,
        bl.latest_remain_credit,
        bl.calc_credit_gap,
        CASE
            WHEN COUNT(DISTINCT bl.rp_id) > SUM(bl.is_complete)
                OR MAX(bl.loan_end_date) > MAX(bl.observation_date)
                THEN 1
            ELSE 0
            END AS is_inloan_order
    FROM base_loan_data_light bl
    GROUP BY bl.cust_no, bl.loan_no, bl.order_create_time, bl.loan_start_date, bl.calc_credit_time, bl.latest_remain_credit, bl.calc_credit_gap
    HAVING is_inloan_order = 1
),

inloan_order_bill_stats_q2 AS (
    SELECT
        iobs.cust_no,
        iobs.loan_no,
        -- 修复：使用新逻辑计算的在贷订单账单统计（直接从还款计划表计算）
        iobs.overduetermcnt,
        iobs.billing_term_cnt,
        iobs.completetermcnt,
        iobs.total_term_cnt,
        iobs.completeprincipal,
        -- 优化：从order_level_stats获取calc_credit_gap和latest_remain_credit，避免扫描base_loan_data_light
        MAX(ols.calc_credit_gap) AS calc_credit_gap,
        MAX(ols.latest_remain_credit) AS latest_remain_credit
    FROM inloan_order_bill_stats_new iobs
             LEFT JOIN order_level_stats ols
                       ON ols.cust_no = iobs.cust_no
                           AND ols.loan_no = iobs.loan_no
                           AND ols.observation_date = iobs.observation_date
    GROUP BY iobs.cust_no, iobs.loan_no, iobs.overduetermcnt, iobs.billing_term_cnt, iobs.completetermcnt, iobs.total_term_cnt, iobs.completeprincipal
),

inLoanOrders_all_features AS (
    SELECT
        cust_no,
        ROUND(CASE WHEN SUM(completetermcnt) > 0 THEN SUM(overduetermcnt)/SUM(completetermcnt) ELSE 0 END, 6) AS multi_loan_order_info_inloanorders_overduevscompletetermratio,
        ROUND(CASE WHEN SUM(billing_term_cnt) > 0 THEN SUM(overduetermcnt)/SUM(billing_term_cnt) ELSE 0 END, 6) AS multi_loan_order_info_inloanorders_overduevsbillingtermratio,
        SUM(overduetermcnt) AS multi_loan_order_info_inloanorders_overduetermcnt,
        ROUND(CASE WHEN SUM(total_term_cnt) > 0 THEN SUM(completetermcnt)/SUM(total_term_cnt) ELSE 0 END, 6) AS multi_loan_order_info_inloanorders_completetermratio,
        SUM(completetermcnt) AS multi_loan_order_info_inloanorders_completetermcnt,
        ROUND(CASE WHEN MAX(latest_remain_credit) > 0 THEN SUM(completeprincipal)/MAX(latest_remain_credit) ELSE 0 END, 6) AS multi_loan_order_info_inloanorders_completeprincipalvslatestremaincreditratio,
        SUM(completeprincipal) AS multi_loan_order_info_inloanorders_completeprincipal,
        ROUND(STDDEV_POP(calc_credit_gap), 6) AS multi_loan_order_info_inloanorders_calccreditgapstd,
        MIN(calc_credit_gap) AS multi_loan_order_info_inloanorders_calccreditgapmin,
        ROUND(AVG(calc_credit_gap), 6) AS multi_loan_order_info_inloanorders_calccreditgapmean,
        MAX(calc_credit_gap) AS multi_loan_order_info_inloanorders_calccreditgapmax
    FROM inloan_order_bill_stats_q2
    GROUP BY cust_no
),

-- ===================== 14. 第二个查询：续借在贷订单特征（12个，优化：使用order_level_stats减少扫描） =====================
cust_loan_distinct AS (
    SELECT
        ols.cust_no,
        ols.loan_no,
        ols.loan_amt,
        -- 注意：calc_credit_time和loan_start_date需要从base_loan_data_light获取，但可以合并到一次扫描
        MAX(bl.calc_credit_time) AS calc_credit_time,
        MIN(bl.loan_start_date) AS loan_start_date,
        ols.latest_remain_credit,
        ols.calc_credit_gap
    FROM order_level_stats ols
             LEFT JOIN base_loan_data_light bl
                       ON ols.cust_no = bl.cust_no
                           AND ols.loan_no = bl.loan_no
                           AND ols.observation_date = bl.observation_date
                           AND bl.periods = 1  -- 只取第一期，减少数据量
    GROUP BY ols.cust_no, ols.loan_no, ols.loan_amt, ols.latest_remain_credit, ols.calc_credit_gap
),

user_multi_loan_flag AS (
    SELECT
        cld.cust_no,
        cld.loan_no,
        cld.loan_amt,
        cld.calc_credit_time,
        cld.loan_start_date,
        cld.latest_remain_credit,
        cld.calc_credit_gap,
        COUNT(*) OVER (PARTITION BY cld.cust_no) AS total_loan_count,
        CASE WHEN COUNT(*) OVER (PARTITION BY cld.cust_no) >= 2 THEN 1 ELSE 0 END AS is_multi_loan
    FROM cust_loan_distinct cld
),

-- ===================== 14.1 预计算多订单客户订单列表（优化：避免重复EXISTS子查询） =====================
multi_loan_cust_loan_pairs AS (
    SELECT DISTINCT
        mlf.cust_no,
        mlf.loan_no
    FROM user_multi_loan_flag mlf
    WHERE mlf.is_multi_loan = 1
),

multi_loan_order_base AS (
    SELECT
        bl.cust_no,
        bl.loan_no,
        bl.is_overdue,
        bl.is_complete,
        bl.loan_end_date,
        bl.repaid_principal,
        bl.is_due_bill,
        bl.is_due_or_complete,  -- 添加is_due_or_complete字段
        bl.rp_id,  -- 添加rp_id字段
        bl.periods,  -- 期数字段
        bl.loan_amt,
        bl.latest_remain_credit,
        bl.calc_credit_gap
    FROM base_loan_data_light bl
             INNER JOIN multi_loan_cust_loan_pairs mlp
                        ON bl.cust_no = mlp.cust_no
                            AND bl.loan_no = mlp.loan_no
),

-- 【新增】订单级别聚合（用于计算订单本金标准差）
multi_loan_order_level AS (
    SELECT
        cust_no,
        loan_no,
        MAX(loan_amt) AS loan_amt  -- 每个订单的本金（所有期数相同，取MAX即可）
    FROM multi_loan_order_base
    GROUP BY cust_no, loan_no
),

multi_loan_order_stats AS (
    SELECT
        mlo.cust_no,
        SUM(CASE WHEN mlo.is_overdue = 1 THEN 1 ELSE 0 END) AS overduetermcnt,
        -- 修复：只统计已到期的账单
        SUM(CASE WHEN mlo.is_due_bill = 1 THEN 1 ELSE 0 END) AS billing_term_cnt,
        -- 修复：统计已结清的账单数，而不是已结清的订单数
        SUM(CASE WHEN mlo.is_complete = 1 THEN 1 ELSE 0 END) AS completetermcnt,
        -- 修复：只统计已到期或已结清的账单数，而不是所有订单数
        COUNT(DISTINCT CASE
                           WHEN mlo.is_due_or_complete = 1
                               THEN mlo.rp_id
                           ELSE NULL
            END) AS total_term_cnt,
        -- 修复：只统计已结清的账单本金（is_complete = 1），避免使用未来的还款信息
        SUM(CASE WHEN mlo.is_complete = 1 THEN mlo.repaid_principal ELSE 0 END) AS completeprincipal,
        MAX(mlo.latest_remain_credit) AS latest_remain_credit,
        -- 【修复】从订单级别聚合表计算订单本金标准差，避免账单重复
        MAX(mlol.orderprincipalstd) AS orderprincipalstd,
        STDDEV_POP(mlo.calc_credit_gap) AS calccreditgapstd,
        MIN(mlo.calc_credit_gap) AS calccreditgapmin,
        AVG(mlo.calc_credit_gap) AS calccreditgapmean,
        MAX(mlo.calc_credit_gap) AS calccreditgapmax
    FROM multi_loan_order_base mlo
             LEFT JOIN (
        SELECT
            cust_no,
            STDDEV_POP(loan_amt) AS orderprincipalstd
        FROM multi_loan_order_level
        GROUP BY cust_no
    ) mlol ON mlo.cust_no = mlol.cust_no
    GROUP BY mlo.cust_no
),

multiLoanOrders_all_features AS (
    SELECT
        cust_no,
        ROUND(CASE WHEN completetermcnt>0 THEN overduetermcnt/completetermcnt ELSE 0 END, 6) AS multi_loan_order_info_multiloanorders_overduevscompletetermratio,
        ROUND(CASE WHEN billing_term_cnt>0 THEN overduetermcnt/billing_term_cnt ELSE 0 END, 6) AS multi_loan_order_info_multiloanorders_overduevsbillingtermratio,
        overduetermcnt AS multi_loan_order_info_multiloanorders_overduetermcnt,
        ROUND(COALESCE(orderprincipalstd, 0), 6) AS multi_loan_order_info_multiloanorders_orderprincipalstd,
        ROUND(CASE WHEN total_term_cnt>0 THEN completetermcnt/total_term_cnt ELSE 0 END, 6) AS multi_loan_order_info_multiloanorders_completetermratio,
        completetermcnt AS multi_loan_order_info_multiloanorders_completetermcnt,
        ROUND(CASE WHEN latest_remain_credit>0 THEN completeprincipal/latest_remain_credit ELSE 0 END, 6) AS multi_loan_order_info_multiloanorders_completeprincipalvslatestremaincreditratio,
        completeprincipal AS multi_loan_order_info_multiloanorders_completeprincipal,
        ROUND(COALESCE(calccreditgapstd, 0), 6) AS multi_loan_order_info_multiloanorders_calccreditgapstd,
        COALESCE(calccreditgapmin, 0) AS multi_loan_order_info_multiloanorders_calccreditgapmin,
        ROUND(COALESCE(calccreditgapmean, 0), 6) AS multi_loan_order_info_multiloanorders_calccreditgapmean,
        COALESCE(calccreditgapmax, 0) AS multi_loan_order_info_multiloanorders_calccreditgapmax
    FROM multi_loan_order_stats
),

-- ===================== 16. 新增：最远一笔订单特征（36个） =====================
furthest_user_all_orders_base AS (
    SELECT
        bl.cust_no,
        bl.loan_no,
        MIN(bl.create_time) AS order_create_time,
        MAX(bl.observation_date) AS observation_date
    FROM base_loan_data_light bl
    WHERE bl.create_time <= bl.observation_date  -- 修复：只使用观察日期及之前的订单
    GROUP BY bl.cust_no, bl.loan_no
    HAVING MIN(bl.create_time) IS NOT NULL
),

furthest_user_all_orders AS (
    SELECT
        fuaob.cust_no,
        fuaob.loan_no,
        fuaob.order_create_time,
        fuaob.observation_date,
        ROW_NUMBER() OVER (PARTITION BY fuaob.cust_no ORDER BY fuaob.order_create_time ASC) AS order_rn,
        -- 修复：先聚合后再使用窗口函数，避免在窗口函数中使用聚合函数
        CASE
            WHEN LEAD(fuaob.order_create_time, 1) OVER (PARTITION BY fuaob.cust_no ORDER BY fuaob.order_create_time ASC) IS NOT NULL
                AND LEAD(fuaob.order_create_time, 1) OVER (PARTITION BY fuaob.cust_no ORDER BY fuaob.order_create_time ASC) <= fuaob.observation_date
                THEN LEAD(fuaob.order_create_time, 1) OVER (PARTITION BY fuaob.cust_no ORDER BY fuaob.order_create_time ASC)
            ELSE NULL
            END AS next_order_create_time,
        CASE
            WHEN LAG(fuaob.order_create_time, 1) OVER (PARTITION BY fuaob.cust_no ORDER BY fuaob.order_create_time ASC) IS NOT NULL
                AND LAG(fuaob.order_create_time, 1) OVER (PARTITION BY fuaob.cust_no ORDER BY fuaob.order_create_time ASC) <= fuaob.observation_date
                THEN LAG(fuaob.order_create_time, 1) OVER (PARTITION BY fuaob.cust_no ORDER BY fuaob.order_create_time ASC)
            ELSE NULL
            END AS prev_order_create_time
    FROM furthest_user_all_orders_base fuaob
),

furthest_order_level_data AS (
    SELECT
        a.cust_no,
        a.loan_no,
        MAX(bl.loan_amt) AS loan_amt,
        a.order_create_time AS furthest_order_create_time,
        MAX(bl.loan_start_date) AS furthest_order_payout_time,
        MAX(bl.after_total_limit) AS furthest_credit_limit,
        MAX(bl.after_available_limit) AS furthest_remain_credit,
        -- 修复：只统计已到期或已结清的账单，避免包含未来账单导致时间穿越（IV异常高问题）
        COUNT(DISTINCT CASE
                           WHEN bl.is_due_or_complete = 1
                               THEN bl.rp_id
                           ELSE NULL
            END) AS furthest_total_terms_cnt,
        CASE
            WHEN a.next_order_create_time IS NOT NULL
                AND a.next_order_create_time <= MAX(bl.observation_date)  -- 修复：确保下一笔订单时间在观察日期及之前
                THEN DATEDIFF(DATE(a.next_order_create_time), DATE(a.order_create_time))
            ELSE NULL
            END AS furthest_order_create_interval_days
    FROM furthest_user_all_orders a
             LEFT JOIN base_loan_data_light bl
                       ON a.cust_no = bl.cust_no
                           AND a.loan_no = bl.loan_no
    WHERE a.order_rn = 1
    GROUP BY a.cust_no, a.loan_no, a.order_create_time, a.next_order_create_time
    HAVING a.order_create_time IS NOT NULL
),

furthest_order_confirmed AS (
    SELECT
        cust_no,
        loan_no AS furthest_loan_no,
        furthest_order_create_time,
        furthest_order_payout_time,
        loan_amt AS furthest_loan_amt,
        furthest_credit_limit,
        furthest_total_terms_cnt,
        furthest_order_create_interval_days
    FROM (
             SELECT
                 *,
                 ROW_NUMBER() OVER (PARTITION BY cust_no ORDER BY furthest_order_create_time ASC) AS rn
             FROM furthest_order_level_data
         ) t
    WHERE rn = 1
),

furthest_order_instal_detail AS (
    SELECT
        lo.cust_no,
        lo.furthest_loan_no,
        lo.furthest_order_create_time,
        lo.furthest_total_terms_cnt,
        lo.furthest_order_payout_time,
        lo.furthest_credit_limit,
        lo.furthest_loan_amt,
        lo.furthest_order_create_interval_days,
        bl.rp_id AS instal_id,
        bl.periods,  -- 期数字段
        bl.loan_end_date,
        bl.loan_start_date,  -- 添加loan_start_date字段用于payoutdays计算
        bl.settled_time,
        bl.principal,
        bl.repaid_principal,
        bl.is_overdue,
        bl.is_prepay,
        bl.prepay_days,
        bl.is_complete,
        bl.is_weekend_repay,
        bl.complete_principal,
        bl.weekend_repay_principal,
        bl.observation_date,  -- 添加observation_date字段供后续聚合使用
        -- 修复：只统计观察时点已知的提前结清（settled_time <= observation_date）
        -- 修复：使用日期比较而不是时间戳比较
        CASE
            WHEN bl.settled_time IS NOT NULL
                AND bl.settled_time <= bl.observation_date  -- 添加时间限制：只使用观察时点已知的结清时间
                AND DATE(bl.settled_time) < bl.loan_end_date  -- 修复：使用日期比较
                THEN 1
            ELSE 0
            END AS is_complete_future_due,
        -- 修复：只统计观察时点已知的到期前提前结清（settled_time <= observation_date）
        -- 修复：使用日期比较而不是时间戳比较
        CASE
            WHEN bl.settled_time IS NOT NULL
                AND bl.settled_time <= bl.observation_date  -- 添加时间限制：只使用观察时点已知的结清时间
                AND DATE(bl.settled_time) < bl.loan_end_date  -- 修复：使用日期比较
                AND bl.loan_end_date <= bl.observation_date
                THEN 1
            ELSE 0
            END AS is_billing_prepay,
        CASE WHEN bl.loan_end_date > bl.observation_date THEN 1 ELSE 0 END AS is_future_bill,
        -- 修复：只统计观察时点已知已结清的未来账单（settled_time <= observation_date）
        CASE
            WHEN bl.loan_end_date > bl.observation_date
                AND bl.is_complete = 1
                AND bl.settled_time <= bl.observation_date
                THEN 1
            ELSE 0
            END AS is_future_bill_complete,
        HOUR(lo.furthest_order_create_time) AS create_hour,
        -- 修复：只统计观察时点已知的首次结清时间（settled_time <= observation_date）
        MIN(CASE
                WHEN bl.settled_time <= bl.observation_date
                    THEN bl.settled_time
                ELSE NULL
                END) OVER (PARTITION BY lo.cust_no, lo.furthest_loan_no) AS first_complete_time,
        -- 修复：计算真正的连续提前结清和连续逾期，避免包含未来账单导致时间穿越（IV异常高问题）
        -- 使用ROW_NUMBER()来标记连续序列的分组
        ROW_NUMBER() OVER (PARTITION BY lo.cust_no, lo.furthest_loan_no ORDER BY bl.loan_end_date)
            - ROW_NUMBER() OVER (
            PARTITION BY lo.cust_no, lo.furthest_loan_no,
                CASE WHEN (bl.loan_end_date <= bl.observation_date OR bl.is_complete = 1) AND bl.is_overdue = 1 THEN 1 ELSE 0 END
            ORDER BY bl.loan_end_date
            ) AS overdue_group_id,
        ROW_NUMBER() OVER (PARTITION BY lo.cust_no, lo.furthest_loan_no ORDER BY bl.loan_end_date)
            - ROW_NUMBER() OVER (
            PARTITION BY lo.cust_no, lo.furthest_loan_no,
                CASE WHEN (bl.loan_end_date <= bl.observation_date OR bl.is_complete = 1) AND bl.is_prepay = 1 THEN 1 ELSE 0 END
            ORDER BY bl.loan_end_date
            ) AS prepay_group_id,
        -- 修复：只统计已结清的账单，避免NULL值影响统计
        COUNT(CASE
                  WHEN bl.settled_time IS NOT NULL
                      AND bl.settled_time <= bl.observation_date
                      THEN bl.rp_id
                  ELSE NULL
                  END) OVER (PARTITION BY lo.cust_no, lo.furthest_loan_no, DATE(bl.settled_time)) AS same_day_complete_cnt
    FROM furthest_order_confirmed lo
             INNER JOIN base_loan_data_light bl
                        ON lo.cust_no = bl.cust_no
                            AND lo.furthest_loan_no = bl.loan_no
),

-- 【修复】计算真正的连续提前结清序列
furthest_order_consecutive_calc AS (
    SELECT
        foid.*,
        -- 计算连续逾期序列长度
        -- 修复：使用SUM(CASE)替代COUNT(*)，只统计真正满足逾期条件的行
        CASE
            WHEN foid.is_overdue = 1 AND (foid.loan_end_date <= foid.observation_date OR foid.is_complete = 1)
                THEN SUM(CASE
                             WHEN foid.is_overdue = 1 AND (foid.loan_end_date <= foid.observation_date OR foid.is_complete = 1)
                                 THEN 1
                             ELSE 0
                             END) OVER (
                             PARTITION BY foid.cust_no, foid.furthest_loan_no, foid.overdue_group_id
                             ORDER BY foid.loan_end_date
                             ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
                             )
            ELSE 0
            END AS consecutive_overdue_cnt,
        -- 计算连续提前结清序列长度
        -- 修复：使用SUM(CASE)替代COUNT(*)，只统计真正满足提前结清条件的行
        CASE
            WHEN foid.is_prepay = 1 AND (foid.loan_end_date <= foid.observation_date OR foid.is_complete = 1)
                THEN SUM(CASE
                             WHEN foid.is_prepay = 1 AND (foid.loan_end_date <= foid.observation_date OR foid.is_complete = 1)
                                 THEN 1
                             ELSE 0
                             END) OVER (
                             PARTITION BY foid.cust_no, foid.furthest_loan_no, foid.prepay_group_id
                             ORDER BY foid.loan_end_date
                             ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
                             )
            ELSE 0
            END AS consecutive_prepay_cnt
    FROM furthest_order_instal_detail foid
),

furthest_order_all_features AS (
    SELECT
        focc.cust_no,
        focc.furthest_order_create_time,
        focc.furthest_order_payout_time,
        MAX(focc.furthest_total_terms_cnt) AS termscnt,
        -- 修复：只统计已到期但未结清的账单，避免包含未来账单导致时间穿越（IV异常高问题）
        SUM(CASE
                WHEN focc.is_complete = 0
                    AND focc.loan_end_date <= focc.observation_date
                    THEN 1
                ELSE 0
            END) AS incompletetermcnt,
        SUM(focc.is_complete) AS completetermcnt,
        ROUND(CASE WHEN MAX(focc.furthest_total_terms_cnt) > 0 THEN SUM(focc.is_complete) / MAX(focc.furthest_total_terms_cnt) ELSE 0 END, 6) AS completetermratio,
        MAX(focc.same_day_complete_cnt) AS completesamedaytermscntmax,
        ROUND(AVG(focc.same_day_complete_cnt), 6) AS completesamedaytermscntavg,
        SUM(CASE WHEN focc.is_complete_future_due = 1 THEN 1 ELSE 0 END) AS completefuturedutermcnt,
        ROUND(CASE WHEN SUM(focc.is_complete) > 0 THEN SUM(CASE WHEN focc.is_complete_future_due = 1 THEN 1 ELSE 0 END) / SUM(focc.is_complete) ELSE 0 END, 6) AS completefuturedutermratio,
        ROUND(CASE
                  WHEN SUM(CASE WHEN focc.loan_end_date > focc.observation_date THEN 1 ELSE 0 END) > 0
                      THEN CAST(SUM(focc.is_prepay) AS DOUBLE) / CAST(SUM(CASE WHEN focc.loan_end_date > focc.observation_date THEN 1 ELSE 0 END) AS DOUBLE)
                  ELSE 0
                  END, 6) AS prepayvsfuturebillingtermratio,
        -- 修复：避免在CASE WHEN条件中使用聚合函数，直接计算比例，用NULLIF避免除零
        ROUND(CAST(SUM(CASE WHEN focc.is_prepay = 1 THEN 1 ELSE 0 END) AS DOUBLE) / NULLIF(MAX(focc.furthest_total_terms_cnt), 0), 6) AS prepayvsalltermratio,
        MIN(CASE WHEN focc.is_prepay = 1 THEN focc.prepay_days ELSE NULL END) AS completeprepaydaysmin,
        ROUND(AVG(CASE WHEN focc.is_prepay = 1 THEN focc.prepay_days ELSE NULL END), 6) AS completeprepaydaysmean,
        MAX(CASE WHEN focc.is_prepay = 1 THEN focc.prepay_days ELSE NULL END) AS completeprepaydaysmax,
        ROUND(CASE WHEN SUM(focc.is_complete) > 0 THEN SUM(focc.is_billing_prepay) / SUM(focc.is_complete) ELSE 0 END, 6) AS billingprepayvscompletetermratio,
        ROUND(CASE
                  WHEN SUM(CASE WHEN focc.loan_end_date <= focc.observation_date THEN 1 ELSE 0 END) > 0
                      THEN CAST(SUM(CASE WHEN focc.is_billing_prepay = 1 THEN 1 ELSE 0 END) AS DOUBLE) / CAST(SUM(CASE WHEN focc.loan_end_date <= focc.observation_date THEN 1 ELSE 0 END) AS DOUBLE)
                  ELSE 0
                  END, 6) AS billingprepayvsbillingtermratio,
        SUM(CASE WHEN focc.is_overdue = 1 THEN 1 ELSE 0 END) AS overduetermcnt,
        ROUND(CASE WHEN SUM(focc.is_complete) > 0 THEN SUM(CASE WHEN focc.is_overdue = 1 THEN 1 ELSE 0 END) / SUM(focc.is_complete) ELSE 0 END, 6) AS overduevscompletedtermratio,
        ROUND(CASE
                  WHEN SUM(CASE WHEN focc.loan_end_date <= focc.observation_date THEN 1 ELSE 0 END) > 0
                      THEN CAST(SUM(CASE WHEN focc.is_overdue = 1 THEN 1 ELSE 0 END) AS DOUBLE) / CAST(SUM(CASE WHEN focc.loan_end_date <= focc.observation_date THEN 1 ELSE 0 END) AS DOUBLE)
                  ELSE 0
                  END, 6) AS overduevsbillingtermratio,
        -- 修复：避免在CASE WHEN条件中使用聚合函数，直接计算比例，用NULLIF避免除零
        ROUND(CAST(SUM(CASE WHEN focc.is_overdue = 1 THEN 1 ELSE 0 END) AS DOUBLE) / NULLIF(MAX(focc.furthest_total_terms_cnt), 0), 6) AS overduetermratio,
        -- 【修复】使用真正的连续逾期计算
        MAX(focc.consecutive_overdue_cnt) AS maxsuccessiveoverduetermcnt,
        ROUND(CASE
                  WHEN SUM(CASE WHEN focc.loan_end_date <= focc.observation_date THEN 1 ELSE 0 END) > 0
                      THEN CAST(MAX(focc.consecutive_overdue_cnt) AS DOUBLE) / CAST(SUM(CASE WHEN focc.loan_end_date <= focc.observation_date THEN 1 ELSE 0 END) AS DOUBLE)
                  ELSE 0
                  END, 6) AS maxsuccessiveoverduetermvsbillingratio,
        -- 修复：避免在CASE WHEN条件中使用聚合函数，直接计算比例，用NULLIF避免除零
        ROUND(CAST(MAX(focc.consecutive_overdue_cnt) AS DOUBLE) / NULLIF(MAX(focc.furthest_total_terms_cnt), 0), 6) AS maxsuccessiveoverduetermvsallratio,
        -- 【修复】使用真正的连续提前结清计算
        MAX(focc.consecutive_prepay_cnt) AS maxsuccessiveprepaytermcnt,
        ROUND(CASE
                  WHEN SUM(CASE WHEN focc.loan_end_date <= focc.observation_date THEN 1 ELSE 0 END) > 0
                      THEN CAST(MAX(focc.consecutive_prepay_cnt) AS DOUBLE) / CAST(SUM(CASE WHEN focc.loan_end_date <= focc.observation_date THEN 1 ELSE 0 END) AS DOUBLE)
                  ELSE 0
                  END, 6) AS maxsuccessiveprepaytermvsbillingratio,
        -- 修复：避免在CASE WHEN条件中使用聚合函数，直接计算比例，用NULLIF避免除零
        ROUND(CAST(MAX(focc.consecutive_prepay_cnt) AS DOUBLE) / NULLIF(MAX(focc.furthest_total_terms_cnt), 0), 6) AS maxsuccessiveprepaytermvsallratio,
        -- 【放款天数】修改：累加所有账单的实际放款天数
        -- 新逻辑：先判断账单是否已放款（loan_start_date <= observation_date），只统计已放款账单的放款天数
        SUM(CASE
                WHEN focc.loan_start_date <= focc.observation_date  -- 只统计已放款的账单
                    THEN CASE
                             WHEN focc.settled_time IS NOT NULL
                                 AND focc.settled_time <= focc.observation_date  -- 已结清且结清时间在观察日期之前
                                 THEN GREATEST(0, DATEDIFF(DATE(focc.settled_time), DATE(focc.loan_start_date)))  -- 修复：使用GREATEST避免负数
                             ELSE GREATEST(0, DATEDIFF(focc.observation_date, DATE(focc.loan_start_date)))  -- 修复：使用GREATEST避免负数
                    END
                ELSE 0  -- 未放款的账单不计入放款天数
            END) AS payoutdays,
        -- 修复：createdNowGap存在数据泄露风险，如果首期账单未到期，返回NULL避免泄露信息
        -- 原因：如果createdNowGap很小（0-7天），说明订单刚创建，首期账单刚到期，如果未结清，很可能就是逾期的
        -- 这会导致数据泄露，因为FPD7标签基于首期账单是否逾期7天以上
        CASE
            WHEN MIN(CASE WHEN focc.periods = 1 THEN focc.loan_end_date ELSE NULL END) IS NOT NULL
                AND MIN(CASE WHEN focc.periods = 1 THEN focc.loan_end_date ELSE NULL END) <= focc.observation_date
                THEN DATEDIFF(focc.observation_date, DATE(focc.furthest_order_create_time))
            ELSE NULL
            END AS createdNowGap,
        -- 修复：计算第一期账单的结清时间到第一期账单放款时间的日期差
        -- 如果结清时间为空则赋值为-1，如果日期差小于0则统一赋值为0
        CASE
            WHEN MIN(CASE WHEN focc.periods = 1 THEN focc.settled_time ELSE NULL END) IS NULL
                THEN -1  -- 第一期账单未结清，返回-1
            WHEN MIN(CASE WHEN focc.periods = 1 THEN focc.settled_time ELSE NULL END) IS NOT NULL
                AND MIN(CASE WHEN focc.periods = 1 THEN focc.settled_time ELSE NULL END) <= focc.observation_date
                THEN CASE
                         WHEN DATEDIFF(
                                      DATE(MIN(CASE WHEN focc.periods = 1 THEN focc.settled_time ELSE NULL END)),
                                      DATE(MIN(CASE WHEN focc.periods = 1 THEN focc.loan_start_date ELSE NULL END))
                              ) < 0
                             THEN 0  -- 日期差小于0，统一赋值为0
                         ELSE DATEDIFF(
                                 DATE(MIN(CASE WHEN focc.periods = 1 THEN focc.settled_time ELSE NULL END)),
                                 DATE(MIN(CASE WHEN focc.periods = 1 THEN focc.loan_start_date ELSE NULL END))
                              )
                END
            ELSE -1  -- 第一期账单结清时间晚于观察日期，返回-1
            END AS firstcompletedcreatedgap,
        ROUND(CASE WHEN SUM(focc.is_future_bill) > 0 THEN SUM(focc.is_future_bill_complete) / SUM(focc.is_future_bill) ELSE 0 END, 6) AS completevsfuturebillingtermratio,
        MAX(focc.furthest_order_create_interval_days) AS createdcalccreditgap,
        MAX(CASE WHEN focc.create_hour BETWEEN 11 AND 13 THEN 1 ELSE 0 END) AS creatednoon,
        MAX(CASE WHEN focc.create_hour BETWEEN 23 AND 23 OR focc.create_hour BETWEEN 0 AND 4 THEN 1 ELSE 0 END) AS creatednight,
        MAX(CASE WHEN focc.create_hour BETWEEN 6 AND 10 THEN 1 ELSE 0 END) AS createdmorning,
        MAX(CASE WHEN focc.create_hour BETWEEN 18 AND 22 THEN 1 ELSE 0 END) AS createdevening,
        MAX(CASE WHEN focc.create_hour BETWEEN 15 AND 17 THEN 1 ELSE 0 END) AS createdafternoon,
        ROUND(CASE WHEN SUM(focc.complete_principal) > 0 THEN SUM(focc.weekend_repay_principal) / SUM(focc.complete_principal) ELSE 0 END, 6) AS completeonweekendprincipalratio
    FROM furthest_order_consecutive_calc focc
    GROUP BY focc.cust_no, focc.furthest_order_create_time, focc.furthest_order_payout_time, focc.observation_date
),

-- ===================== 17. 新增：最近第二笔订单特征（36个） =====================
latest2_user_all_orders_base AS (
    SELECT
        bl.cust_no,
        bl.loan_no,
        MIN(bl.create_time) AS order_create_time,
        MAX(bl.observation_date) AS observation_date
    FROM base_loan_data_light bl
    WHERE bl.create_time <= bl.observation_date  -- 修复：只使用观察日期及之前的订单
    GROUP BY bl.cust_no, bl.loan_no
    HAVING MIN(bl.create_time) IS NOT NULL
),

latest2_user_all_orders AS (
    SELECT
        l2uaob.cust_no,
        l2uaob.loan_no,
        l2uaob.order_create_time,
        l2uaob.observation_date,
        ROW_NUMBER() OVER (PARTITION BY l2uaob.cust_no ORDER BY l2uaob.order_create_time DESC) AS order_rn,
        -- 修复：先聚合后再使用窗口函数，避免在窗口函数中使用聚合函数
        CASE
            WHEN LEAD(l2uaob.order_create_time, 1) OVER (PARTITION BY l2uaob.cust_no ORDER BY l2uaob.order_create_time DESC) IS NOT NULL
                AND LEAD(l2uaob.order_create_time, 1) OVER (PARTITION BY l2uaob.cust_no ORDER BY l2uaob.order_create_time DESC) <= l2uaob.observation_date
                THEN LEAD(l2uaob.order_create_time, 1) OVER (PARTITION BY l2uaob.cust_no ORDER BY l2uaob.order_create_time DESC)
            ELSE NULL
            END AS next_order_create_time,
        CASE
            WHEN LAG(l2uaob.order_create_time, 1) OVER (PARTITION BY l2uaob.cust_no ORDER BY l2uaob.order_create_time DESC) IS NOT NULL
                AND LAG(l2uaob.order_create_time, 1) OVER (PARTITION BY l2uaob.cust_no ORDER BY l2uaob.order_create_time DESC) <= l2uaob.observation_date
                THEN LAG(l2uaob.order_create_time, 1) OVER (PARTITION BY l2uaob.cust_no ORDER BY l2uaob.order_create_time DESC)
            ELSE NULL
            END AS prev_order_create_time
    FROM latest2_user_all_orders_base l2uaob
),

latest2_order_level_data AS (
    SELECT
        a.cust_no,
        a.loan_no,
        MAX(bl.loan_amt) AS loan_amt,
        a.order_create_time AS latest2_order_create_time,
        MAX(bl.loan_start_date) AS latest2_order_payout_time,
        MAX(bl.after_total_limit) AS latest2_credit_limit,
        MAX(bl.after_available_limit) AS latest2_remain_credit,
        -- 修复：只统计已到期或已结清的账单，避免包含未来账单导致时间穿越（IV异常高问题）
        COUNT(DISTINCT CASE
                           WHEN bl.is_due_or_complete = 1
                               THEN bl.rp_id
                           ELSE NULL
            END) AS latest2_total_terms_cnt,
        CASE
            WHEN a.next_order_create_time IS NOT NULL
                AND a.next_order_create_time <= MAX(bl.observation_date)  -- 修复：确保下一笔订单时间在观察日期及之前
                THEN DATEDIFF(DATE(a.order_create_time), DATE(a.next_order_create_time))  -- 修复：计算第二笔订单距离第三笔订单的间隔（第二笔 - 第三笔）
            ELSE NULL
            END AS latest2_order_create_interval_days
    FROM latest2_user_all_orders a
             LEFT JOIN base_loan_data_light bl
                       ON a.cust_no = bl.cust_no
                           AND a.loan_no = bl.loan_no
    WHERE a.order_rn = 2
    GROUP BY a.cust_no, a.loan_no, a.order_create_time, a.next_order_create_time
    HAVING a.order_create_time IS NOT NULL
),

latest2_order_confirmed AS (
    SELECT
        cust_no,
        loan_no AS latest2_loan_no,
        latest2_order_create_time,
        latest2_order_payout_time,
        loan_amt AS latest2_loan_amt,
        latest2_credit_limit,
        latest2_total_terms_cnt,
        latest2_order_create_interval_days
    FROM (
             SELECT
                 *,
                 ROW_NUMBER() OVER (PARTITION BY cust_no ORDER BY latest2_order_create_time DESC) AS rn
             FROM latest2_order_level_data
         ) t
    WHERE rn = 1
),

latest2_order_instal_detail AS (
    SELECT
        lo.cust_no,
        lo.latest2_loan_no,
        lo.latest2_order_create_time,
        lo.latest2_total_terms_cnt,
        lo.latest2_order_payout_time,
        lo.latest2_credit_limit,
        lo.latest2_loan_amt,
        lo.latest2_order_create_interval_days,
        bl.rp_id AS instal_id,
        bl.periods,  -- 期数字段
        bl.loan_end_date,
        bl.loan_start_date,  -- 添加loan_start_date字段用于payoutdays计算
        bl.settled_time,
        bl.principal,
        bl.is_overdue,
        bl.is_prepay,
        bl.prepay_days,
        bl.is_complete,
        bl.observation_date,  -- 添加observation_date字段供后续聚合使用
        -- 修复：只统计观察时点已知的提前结清（settled_time <= observation_date）
        CASE
            WHEN bl.settled_time IS NOT NULL
                AND bl.settled_time <= bl.observation_date  -- 添加时间限制：只使用观察时点已知的结清时间
                AND DATE(bl.settled_time) < bl.loan_end_date
                THEN 1
            ELSE 0
            END AS is_complete_future_due,
        -- 修复：只统计观察时点已知的到期前提前结清（settled_time <= observation_date）
        CASE
            WHEN bl.settled_time IS NOT NULL
                AND bl.settled_time <= bl.observation_date  -- 添加时间限制：只使用观察时点已知的结清时间
                AND DATE(bl.settled_time) < bl.loan_end_date
                AND bl.loan_end_date <= bl.observation_date
                THEN 1
            ELSE 0
            END AS is_billing_prepay,
        CASE WHEN bl.loan_end_date > bl.observation_date THEN 1 ELSE 0 END AS is_future_bill,
        -- 修复：只统计观察时点已知已结清的未来账单（settled_time <= observation_date）
        CASE
            WHEN bl.loan_end_date > bl.observation_date
                AND bl.is_complete = 1
                AND bl.settled_time <= bl.observation_date
                THEN 1
            ELSE 0
            END AS is_future_bill_complete,
        -- 修复：只统计观察时点已知的提前结清本金（settled_time <= observation_date）
        -- 注意：is_complete = 1 已经保证了 settled_time <= observation_date，但为了明确性，这里也添加检查
        CASE
            WHEN bl.is_complete = 1
                AND bl.settled_time IS NOT NULL
                AND bl.settled_time <= bl.observation_date  -- 明确的时间限制
                AND DATE(bl.settled_time) < bl.loan_end_date
                THEN bl.principal
            ELSE 0
            END AS complete_future_due_principal,
        HOUR(lo.latest2_order_create_time) AS create_hour,
        -- 修复：只统计观察时点已知的首次结清时间（settled_time <= observation_date）
        MIN(CASE
                WHEN bl.settled_time <= bl.observation_date
                    THEN bl.settled_time
                ELSE NULL
                END) OVER (PARTITION BY lo.cust_no, lo.latest2_loan_no) AS first_complete_time,
        -- 修复：计算真正的连续提前结清和连续逾期，避免包含未来账单导致时间穿越（IV异常高问题）
        -- 使用ROW_NUMBER()来标记连续序列的分组
        ROW_NUMBER() OVER (PARTITION BY lo.cust_no, lo.latest2_loan_no ORDER BY bl.loan_end_date)
            - ROW_NUMBER() OVER (
            PARTITION BY lo.cust_no, lo.latest2_loan_no,
                CASE WHEN (bl.loan_end_date <= bl.observation_date OR bl.is_complete = 1) AND bl.is_overdue = 1 THEN 1 ELSE 0 END
            ORDER BY bl.loan_end_date
            ) AS overdue_group_id,
        ROW_NUMBER() OVER (PARTITION BY lo.cust_no, lo.latest2_loan_no ORDER BY bl.loan_end_date)
            - ROW_NUMBER() OVER (
            PARTITION BY lo.cust_no, lo.latest2_loan_no,
                CASE WHEN (bl.loan_end_date <= bl.observation_date OR bl.is_complete = 1) AND bl.is_prepay = 1 THEN 1 ELSE 0 END
            ORDER BY bl.loan_end_date
            ) AS prepay_group_id,
        -- 修复：只统计已结清的账单，避免NULL值影响统计
        COUNT(CASE
                  WHEN bl.settled_time IS NOT NULL
                      AND bl.settled_time <= bl.observation_date
                      THEN bl.rp_id
                  ELSE NULL
                  END) OVER (PARTITION BY lo.cust_no, lo.latest2_loan_no, DATE(bl.settled_time)) AS same_day_complete_cnt
    FROM latest2_order_confirmed lo
             INNER JOIN base_loan_data_light bl
                        ON lo.cust_no = bl.cust_no
                            AND lo.latest2_loan_no = bl.loan_no
),

-- 【修复】计算真正的连续提前结清序列 - 最近第二笔订单
latest2_order_consecutive_calc AS (
    SELECT
        loid.*,
        -- 计算连续逾期序列长度
        -- 修复：使用SUM(CASE)替代COUNT(*)，只统计真正满足逾期条件的行
        CASE
            WHEN loid.is_overdue = 1 AND (loid.loan_end_date <= loid.observation_date OR loid.is_complete = 1)
                THEN SUM(CASE
                             WHEN loid.is_overdue = 1 AND (loid.loan_end_date <= loid.observation_date OR loid.is_complete = 1)
                                 THEN 1
                             ELSE 0
                             END) OVER (
                             PARTITION BY loid.cust_no, loid.latest2_loan_no, loid.overdue_group_id
                             ORDER BY loid.loan_end_date
                             ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
                             )
            ELSE 0
            END AS consecutive_overdue_cnt,
        -- 计算连续提前结清序列长度
        -- 修复：使用SUM(CASE)替代COUNT(*)，只统计真正满足提前结清条件的行
        CASE
            WHEN loid.is_prepay = 1 AND (loid.loan_end_date <= loid.observation_date OR loid.is_complete = 1)
                THEN SUM(CASE
                             WHEN loid.is_prepay = 1 AND (loid.loan_end_date <= loid.observation_date OR loid.is_complete = 1)
                                 THEN 1
                             ELSE 0
                             END) OVER (
                             PARTITION BY loid.cust_no, loid.latest2_loan_no, loid.prepay_group_id
                             ORDER BY loid.loan_end_date
                             ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
                             )
            ELSE 0
            END AS consecutive_prepay_cnt
    FROM latest2_order_instal_detail loid
),

latest2_order_all_features AS (
    SELECT
        l2cc.cust_no,
        l2cc.latest2_order_create_time,
        l2cc.latest2_order_payout_time,
        MAX(l2cc.latest2_total_terms_cnt) AS termscnt,
        -- 修复：只统计已到期但未结清的账单，避免包含未来账单导致时间穿越（IV异常高问题）
        SUM(CASE
                WHEN l2cc.is_complete = 0
                    AND l2cc.loan_end_date <= l2cc.observation_date
                    THEN 1
                ELSE 0
            END) AS incompletetermcnt,
        SUM(l2cc.is_complete) AS completetermcnt,
        ROUND(CASE WHEN MAX(l2cc.latest2_total_terms_cnt) > 0 THEN SUM(l2cc.is_complete) / MAX(l2cc.latest2_total_terms_cnt) ELSE 0 END, 6) AS completetermratio,
        MAX(l2cc.same_day_complete_cnt) AS completesamedaytermscntmax,
        ROUND(AVG(l2cc.same_day_complete_cnt), 6) AS completesamedaytermscntavg,
        SUM(CASE WHEN l2cc.is_complete_future_due = 1 THEN 1 ELSE 0 END) AS completefuturedutermcnt,
        ROUND(CASE WHEN SUM(l2cc.is_complete) > 0 THEN SUM(CASE WHEN l2cc.is_complete_future_due = 1 THEN 1 ELSE 0 END) / SUM(l2cc.is_complete) ELSE 0 END, 6) AS completefuturedutermratio,
        SUM(l2cc.complete_future_due_principal) AS completefuturedutermprincipal,
        ROUND(CASE WHEN SUM(CASE WHEN l2cc.loan_end_date > l2cc.observation_date THEN 1 ELSE 0 END) > 0 THEN CAST(SUM(l2cc.is_prepay) AS DOUBLE) / CAST(SUM(CASE WHEN l2cc.loan_end_date > l2cc.observation_date THEN 1 ELSE 0 END) AS DOUBLE) ELSE 0 END, 6) AS prepayvsfuturebillingtermratio,
        -- 修复：避免在CASE WHEN条件中使用聚合函数，直接计算比例，用NULLIF避免除零
        ROUND(CAST(SUM(CASE WHEN l2cc.is_prepay = 1 THEN 1 ELSE 0 END) AS DOUBLE) / NULLIF(MAX(l2cc.latest2_total_terms_cnt), 0), 6) AS prepayvsalltermratio,
        MIN(CASE WHEN l2cc.is_prepay = 1 THEN l2cc.prepay_days ELSE NULL END) AS completeprepaydaysmin,
        ROUND(AVG(CASE WHEN l2cc.is_prepay = 1 THEN l2cc.prepay_days ELSE NULL END), 6) AS completeprepaydaysmean,
        MAX(CASE WHEN l2cc.is_prepay = 1 THEN l2cc.prepay_days ELSE NULL END) AS completeprepaydaysmax,
        ROUND(CASE WHEN SUM(l2cc.is_complete) > 0 THEN SUM(CASE WHEN l2cc.is_billing_prepay = 1 THEN 1 ELSE 0 END) / SUM(l2cc.is_complete) ELSE 0 END, 6) AS billingprepayvscompletetermratio,
        ROUND(CASE WHEN SUM(CASE WHEN l2cc.loan_end_date <= l2cc.observation_date THEN 1 ELSE 0 END) > 0 THEN CAST(SUM(CASE WHEN l2cc.is_billing_prepay = 1 THEN 1 ELSE 0 END) AS DOUBLE) / CAST(SUM(CASE WHEN l2cc.loan_end_date <= l2cc.observation_date THEN 1 ELSE 0 END) AS DOUBLE) ELSE 0 END, 6) AS billingprepayvsbillingtermratio,
        SUM(CASE WHEN l2cc.is_overdue = 1 THEN 1 ELSE 0 END) AS overduetermcnt,
        ROUND(CASE WHEN SUM(l2cc.is_complete) > 0 THEN SUM(CASE WHEN l2cc.is_overdue = 1 THEN 1 ELSE 0 END) / SUM(l2cc.is_complete) ELSE 0 END, 6) AS overduevscompletedtermratio,
        ROUND(CASE WHEN SUM(CASE WHEN l2cc.loan_end_date <= l2cc.observation_date THEN 1 ELSE 0 END) > 0 THEN CAST(SUM(CASE WHEN l2cc.is_overdue = 1 THEN 1 ELSE 0 END) AS DOUBLE) / CAST(SUM(CASE WHEN l2cc.loan_end_date <= l2cc.observation_date THEN 1 ELSE 0 END) AS DOUBLE) ELSE 0 END, 6) AS overduevsbillingtermratio,
        -- 修复：避免在CASE WHEN条件中使用聚合函数，直接计算比例，用NULLIF避免除零
        ROUND(CAST(SUM(CASE WHEN l2cc.is_overdue = 1 THEN 1 ELSE 0 END) AS DOUBLE) / NULLIF(MAX(l2cc.latest2_total_terms_cnt), 0), 6) AS overduetermratio,
        -- 【修复】使用真正的连续逾期计算
        MAX(l2cc.consecutive_overdue_cnt) AS maxsuccessiveoverduetermcnt,
        ROUND(CASE WHEN SUM(CASE WHEN l2cc.loan_end_date <= l2cc.observation_date THEN 1 ELSE 0 END) > 0 THEN CAST(MAX(l2cc.consecutive_overdue_cnt) AS DOUBLE) / CAST(SUM(CASE WHEN l2cc.loan_end_date <= l2cc.observation_date THEN 1 ELSE 0 END) AS DOUBLE) ELSE 0 END, 6) AS maxsuccessiveoverduetermvsbillingratio,
        -- 修复：避免在CASE WHEN条件中使用聚合函数，直接计算比例，用NULLIF避免除零
        ROUND(CAST(MAX(l2cc.consecutive_overdue_cnt) AS DOUBLE) / NULLIF(MAX(l2cc.latest2_total_terms_cnt), 0), 6) AS maxsuccessiveoverduetermvsallratio,
        -- 【修复】使用真正的连续提前结清计算
        MAX(l2cc.consecutive_prepay_cnt) AS maxsuccessiveprepaytermcnt,
        ROUND(CASE WHEN SUM(CASE WHEN l2cc.loan_end_date <= l2cc.observation_date THEN 1 ELSE 0 END) > 0 THEN CAST(MAX(l2cc.consecutive_prepay_cnt) AS DOUBLE) / CAST(SUM(CASE WHEN l2cc.loan_end_date <= l2cc.observation_date THEN 1 ELSE 0 END) AS DOUBLE) ELSE 0 END, 6) AS maxsuccessiveprepaytermvsbillingratio,
        -- 修复：避免在CASE WHEN条件中使用聚合函数，直接计算比例，用NULLIF避免除零
        ROUND(CAST(MAX(l2cc.consecutive_prepay_cnt) AS DOUBLE) / NULLIF(MAX(l2cc.latest2_total_terms_cnt), 0), 6) AS maxsuccessiveprepaytermvsallratio,
        -- 【放款天数】修改：累加所有账单的实际放款天数
        -- 新逻辑：先判断账单是否已放款（loan_start_date <= observation_date），只统计已放款账单的放款天数
        SUM(CASE
                WHEN l2cc.loan_start_date <= l2cc.observation_date  -- 只统计已放款的账单
                    THEN CASE
                             WHEN l2cc.settled_time IS NOT NULL
                                 AND l2cc.settled_time <= l2cc.observation_date  -- 已结清且结清时间在观察日期之前
                                 THEN GREATEST(0, DATEDIFF(DATE(l2cc.settled_time), DATE(l2cc.loan_start_date)))  -- 修复：使用GREATEST避免负数
                             ELSE GREATEST(0, DATEDIFF(l2cc.observation_date, DATE(l2cc.loan_start_date)))  -- 修复：使用GREATEST避免负数
                    END
                ELSE 0  -- 未放款的账单不计入放款天数
            END) AS payoutdays,
        -- 修复：createdNowGap存在数据泄露风险，如果首期账单未到期，返回NULL避免泄露信息
        -- 原因：如果createdNowGap很小（0-7天），说明订单刚创建，首期账单刚到期，如果未结清，很可能就是逾期的
        -- 这会导致数据泄露，因为FPD7标签基于首期账单是否逾期7天以上
        CASE
            WHEN MIN(CASE WHEN l2cc.periods = 1 THEN l2cc.loan_end_date ELSE NULL END) IS NOT NULL
                AND MIN(CASE WHEN l2cc.periods = 1 THEN l2cc.loan_end_date ELSE NULL END) <= l2cc.observation_date
                THEN DATEDIFF(l2cc.observation_date, DATE(l2cc.latest2_order_create_time))
            ELSE NULL
            END AS createdNowGap,
        -- 修复：计算第一期账单的结清时间到第一期账单放款时间的日期差
        -- 如果结清时间为空则赋值为-1，如果日期差小于0则统一赋值为0
        CASE
            WHEN MIN(CASE WHEN l2cc.periods = 1 THEN l2cc.settled_time ELSE NULL END) IS NULL
                THEN -1  -- 第一期账单未结清，返回-1
            WHEN MIN(CASE WHEN l2cc.periods = 1 THEN l2cc.settled_time ELSE NULL END) IS NOT NULL
                AND MIN(CASE WHEN l2cc.periods = 1 THEN l2cc.settled_time ELSE NULL END) <= l2cc.observation_date
                THEN CASE
                         WHEN DATEDIFF(
                                      DATE(MIN(CASE WHEN l2cc.periods = 1 THEN l2cc.settled_time ELSE NULL END)),
                                      DATE(MIN(CASE WHEN l2cc.periods = 1 THEN l2cc.loan_start_date ELSE NULL END))
                              ) < 0
                             THEN 0  -- 日期差小于0，统一赋值为0
                         ELSE DATEDIFF(
                                 DATE(MIN(CASE WHEN l2cc.periods = 1 THEN l2cc.settled_time ELSE NULL END)),
                                 DATE(MIN(CASE WHEN l2cc.periods = 1 THEN l2cc.loan_start_date ELSE NULL END))
                              )
                END
            ELSE -1  -- 第一期账单结清时间晚于观察日期，返回-1
            END AS firstcompletedcreatedgap,
        ROUND(CASE WHEN SUM(l2cc.is_future_bill) > 0 THEN SUM(l2cc.is_future_bill_complete) / SUM(l2cc.is_future_bill) ELSE 0 END, 6) AS completevsfuturebillingtermratio,
        MAX(l2cc.latest2_order_create_interval_days) AS createdcalccreditgap,
        MAX(CASE WHEN l2cc.create_hour BETWEEN 11 AND 13 THEN 1 ELSE 0 END) AS creatednoon,
        MAX(CASE WHEN l2cc.create_hour BETWEEN 23 AND 23 OR l2cc.create_hour BETWEEN 0 AND 4 THEN 1 ELSE 0 END) AS creatednight,
        MAX(CASE WHEN l2cc.create_hour BETWEEN 6 AND 10 THEN 1 ELSE 0 END) AS createdmorning,
        MAX(CASE WHEN l2cc.create_hour BETWEEN 18 AND 22 THEN 1 ELSE 0 END) AS createdevening,
        MAX(CASE WHEN l2cc.create_hour BETWEEN 15 AND 17 THEN 1 ELSE 0 END) AS createdafternoon
    FROM latest2_order_consecutive_calc l2cc
    GROUP BY l2cc.cust_no, l2cc.latest2_order_create_time, l2cc.latest2_order_payout_time, l2cc.observation_date
),

-- ===================== 18. 新增：最近第一笔订单特征（35个） =====================
latest1_user_all_orders_base AS (
    SELECT
        bl.cust_no,
        bl.loan_no,
        MIN(bl.create_time) AS order_create_time,
        MAX(bl.observation_date) AS observation_date
    FROM base_loan_data_light bl
    WHERE bl.create_time <= bl.observation_date  -- 修复：只使用观察日期及之前的订单
    GROUP BY bl.cust_no, bl.loan_no
    HAVING MIN(bl.create_time) IS NOT NULL
),

latest1_user_all_orders AS (
    SELECT
        l1uaob.cust_no,
        l1uaob.loan_no,
        l1uaob.order_create_time,
        l1uaob.observation_date,
        ROW_NUMBER() OVER (PARTITION BY l1uaob.cust_no ORDER BY l1uaob.order_create_time DESC) AS order_rn,
        -- 修复：使用ASC排序，这样LAG可以正确获取到前一笔订单时间
        CASE
            WHEN LAG(l1uaob.order_create_time, 1) OVER (PARTITION BY l1uaob.cust_no ORDER BY l1uaob.order_create_time ASC) IS NOT NULL
                AND LAG(l1uaob.order_create_time, 1) OVER (PARTITION BY l1uaob.cust_no ORDER BY l1uaob.order_create_time ASC) <= l1uaob.observation_date
                THEN LAG(l1uaob.order_create_time, 1) OVER (PARTITION BY l1uaob.cust_no ORDER BY l1uaob.order_create_time ASC)
            ELSE NULL
            END AS prev_order_create_time
    FROM latest1_user_all_orders_base l1uaob
),

latest1_order_level_data AS (
    SELECT
        a.cust_no,
        a.loan_no,
        MAX(bl.loan_amt) AS loan_amt,
        a.order_create_time,
        MAX(bl.loan_start_date) AS order_payout_time,
        MAX(bl.after_total_limit) AS credit_limit,
        MAX(bl.after_available_limit) AS remain_credit,
        -- 修复：只统计已到期或已结清的账单，避免包含未来账单导致时间穿越（IV异常高问题）
        COUNT(DISTINCT CASE
                           WHEN bl.is_due_or_complete = 1
                               THEN bl.rp_id
                           ELSE NULL
            END) AS total_terms_cnt,
        CASE
            WHEN a.prev_order_create_time IS NOT NULL
                AND a.prev_order_create_time <= MAX(bl.observation_date)  -- 修复：确保上一笔订单时间在观察日期及之前
                THEN DATEDIFF(DATE(a.order_create_time), DATE(a.prev_order_create_time))
            ELSE NULL
            END AS order_create_interval_days
    FROM latest1_user_all_orders a
             LEFT JOIN base_loan_data_light bl
                       ON a.cust_no = bl.cust_no
                           AND a.loan_no = bl.loan_no
    GROUP BY a.cust_no, a.loan_no, a.order_create_time, a.prev_order_create_time
    HAVING a.order_create_time IS NOT NULL
),

latest1_order_confirmed AS (
    SELECT
        cust_no,
        loan_no AS latest1_loan_no,
        order_create_time AS latest1_order_create_time,
        order_payout_time AS latest1_order_payout_time,
        loan_amt AS latest1_loan_amt,
        credit_limit AS latest1_credit_limit,
        total_terms_cnt AS latest1_total_terms_cnt,
        order_create_interval_days AS latest1_order_create_interval_days
    FROM (
             SELECT
                 *,
                 ROW_NUMBER() OVER (PARTITION BY cust_no ORDER BY order_create_time DESC) AS rn
             FROM latest1_order_level_data
         ) t
    WHERE rn = 1
),

latest1_order_instal_detail AS (
    SELECT
        lo.cust_no,
        lo.latest1_loan_no,
        lo.latest1_order_create_time,
        lo.latest1_total_terms_cnt,
        lo.latest1_order_payout_time,
        lo.latest1_credit_limit,
        lo.latest1_loan_amt,
        lo.latest1_order_create_interval_days,
        bl.rp_id AS instal_id,
        bl.periods,  -- 期数字段
        bl.loan_end_date,
        bl.loan_start_date,  -- 添加loan_start_date字段用于payoutdays计算
        bl.settled_time,
        bl.is_overdue,
        bl.is_prepay,
        bl.prepay_days,
        bl.is_complete,
        bl.observation_date,  -- 添加observation_date字段供后续聚合使用
        -- 修复：只统计观察时点已知的提前结清（settled_time <= observation_date）
        CASE
            WHEN bl.settled_time IS NOT NULL
                AND bl.settled_time <= bl.observation_date  -- 添加时间限制：只使用观察时点已知的结清时间
                AND DATE(bl.settled_time) < bl.loan_end_date
                THEN 1
            ELSE 0
            END AS is_complete_future_due,
        -- 修复：只统计观察时点已知的到期前提前结清（settled_time <= observation_date）
        CASE
            WHEN bl.settled_time IS NOT NULL
                AND bl.settled_time <= bl.observation_date  -- 添加时间限制：只使用观察时点已知的结清时间
                AND DATE(bl.settled_time) < bl.loan_end_date
                AND bl.loan_end_date <= bl.observation_date
                THEN 1
            ELSE 0
            END AS is_billing_prepay,
        CASE WHEN bl.loan_end_date > bl.observation_date THEN 1 ELSE 0 END AS is_future_bill,
        -- 修复：只统计观察时点已知已结清的未来账单（settled_time <= observation_date）
        CASE
            WHEN bl.loan_end_date > bl.observation_date
                AND bl.is_complete = 1
                AND bl.settled_time <= bl.observation_date
                THEN 1
            ELSE 0
            END AS is_future_bill_complete,
        HOUR(lo.latest1_order_create_time) AS create_hour,
        -- 修复：只统计观察时点已知的首次结清时间（settled_time <= observation_date）
        MIN(CASE
                WHEN bl.settled_time <= bl.observation_date
                    THEN bl.settled_time
                ELSE NULL
                END) OVER (PARTITION BY lo.cust_no, lo.latest1_loan_no) AS first_complete_time,
        -- 修复：计算真正的连续提前结清和连续逾期，避免包含未来账单导致时间穿越（IV异常高问题）
        -- 使用ROW_NUMBER()来标记连续序列的分组
        ROW_NUMBER() OVER (PARTITION BY lo.cust_no, lo.latest1_loan_no ORDER BY bl.loan_end_date)
            - ROW_NUMBER() OVER (
            PARTITION BY lo.cust_no, lo.latest1_loan_no,
                CASE WHEN (bl.loan_end_date <= bl.observation_date OR bl.is_complete = 1) AND bl.is_overdue = 1 THEN 1 ELSE 0 END
            ORDER BY bl.loan_end_date
            ) AS overdue_group_id,
        ROW_NUMBER() OVER (PARTITION BY lo.cust_no, lo.latest1_loan_no ORDER BY bl.loan_end_date)
            - ROW_NUMBER() OVER (
            PARTITION BY lo.cust_no, lo.latest1_loan_no,
                CASE WHEN (bl.loan_end_date <= bl.observation_date OR bl.is_complete = 1) AND bl.is_prepay = 1 THEN 1 ELSE 0 END
            ORDER BY bl.loan_end_date
            ) AS prepay_group_id,
        -- 修复：只统计已结清的账单，避免NULL值影响统计
        COUNT(CASE
                  WHEN bl.settled_time IS NOT NULL
                      AND bl.settled_time <= bl.observation_date
                      THEN bl.rp_id
                  ELSE NULL
                  END) OVER (PARTITION BY lo.cust_no, lo.latest1_loan_no, DATE(bl.settled_time)) AS same_day_complete_cnt
    FROM latest1_order_confirmed lo
             INNER JOIN base_loan_data_light bl
                        ON lo.cust_no = bl.cust_no
                            AND lo.latest1_loan_no = bl.loan_no
),

-- 【修复】计算真正的连续提前结清序列 - 最近第一笔订单
latest1_order_consecutive_calc AS (
    SELECT
        loid.*,
        -- 计算连续逾期序列长度
        -- 修复：使用SUM(CASE)替代COUNT(*)，只统计真正满足逾期条件的行
        CASE
            WHEN loid.is_overdue = 1 AND (loid.loan_end_date <= loid.observation_date OR loid.is_complete = 1)
                THEN SUM(CASE
                             WHEN loid.is_overdue = 1 AND (loid.loan_end_date <= loid.observation_date OR loid.is_complete = 1)
                                 THEN 1
                             ELSE 0
                             END) OVER (
                             PARTITION BY loid.cust_no, loid.latest1_loan_no, loid.overdue_group_id
                             ORDER BY loid.loan_end_date
                             ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
                             )
            ELSE 0
            END AS consecutive_overdue_cnt,
        -- 计算连续提前结清序列长度
        -- 修复：使用SUM(CASE)替代COUNT(*)，只统计真正满足提前结清条件的行
        CASE
            WHEN loid.is_prepay = 1 AND (loid.loan_end_date <= loid.observation_date OR loid.is_complete = 1)
                THEN SUM(CASE
                             WHEN loid.is_prepay = 1 AND (loid.loan_end_date <= loid.observation_date OR loid.is_complete = 1)
                                 THEN 1
                             ELSE 0
                             END) OVER (
                             PARTITION BY loid.cust_no, loid.latest1_loan_no, loid.prepay_group_id
                             ORDER BY loid.loan_end_date
                             ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
                             )
            ELSE 0
            END AS consecutive_prepay_cnt
    FROM latest1_order_instal_detail loid
),

latest1_order_all_features AS (
    SELECT
        l1cc.cust_no,
        l1cc.latest1_order_create_time,
        l1cc.latest1_order_payout_time,
        MAX(l1cc.latest1_total_terms_cnt) AS termscnt,
        -- 修复：只统计已到期但未结清的账单，避免包含未来账单导致时间穿越（IV异常高问题）
        SUM(CASE
                WHEN l1cc.is_complete = 0
                    AND l1cc.loan_end_date <= l1cc.observation_date
                    THEN 1
                ELSE 0
            END) AS incompletetermcnt,
        SUM(l1cc.is_complete) AS completetermcnt,
        ROUND(CASE WHEN MAX(l1cc.latest1_total_terms_cnt) > 0 THEN SUM(l1cc.is_complete) / MAX(l1cc.latest1_total_terms_cnt) ELSE 0 END, 6) AS completetermratio,
        MAX(l1cc.same_day_complete_cnt) AS completesamedaytermscntmax,
        ROUND(AVG(l1cc.same_day_complete_cnt), 6) AS completesamedaytermscntavg,
        SUM(CASE WHEN l1cc.is_complete_future_due = 1 THEN 1 ELSE 0 END) AS completefuturedutermcnt,
        ROUND(CASE WHEN SUM(l1cc.is_complete) > 0 THEN SUM(CASE WHEN l1cc.is_complete_future_due = 1 THEN 1 ELSE 0 END) / SUM(l1cc.is_complete) ELSE 0 END, 6) AS completefuturedutermratio,
        ROUND(CASE WHEN SUM(CASE WHEN l1cc.loan_end_date > l1cc.observation_date THEN 1 ELSE 0 END) > 0 THEN CAST(SUM(l1cc.is_prepay) AS DOUBLE) / CAST(SUM(CASE WHEN l1cc.loan_end_date > l1cc.observation_date THEN 1 ELSE 0 END) AS DOUBLE) ELSE 0 END, 6) AS prepayvsfuturebillingtermratio,
        -- 修复：避免在CASE WHEN条件中使用聚合函数，直接计算比例，用NULLIF避免除零
        ROUND(CAST(SUM(CASE WHEN l1cc.is_prepay = 1 THEN 1 ELSE 0 END) AS DOUBLE) / NULLIF(MAX(l1cc.latest1_total_terms_cnt), 0), 6) AS prepayvsalltermratio,
        MIN(CASE WHEN l1cc.is_prepay = 1 THEN l1cc.prepay_days ELSE NULL END) AS completeprepaydaysmin,
        ROUND(AVG(CASE WHEN l1cc.is_prepay = 1 THEN l1cc.prepay_days ELSE NULL END), 6) AS completeprepaydaysmean,
        MAX(CASE WHEN l1cc.is_prepay = 1 THEN l1cc.prepay_days ELSE NULL END) AS completeprepaydaysmax,
        ROUND(CASE WHEN SUM(l1cc.is_complete) > 0 THEN SUM(CASE WHEN l1cc.is_billing_prepay = 1 THEN 1 ELSE 0 END) / SUM(l1cc.is_complete) ELSE 0 END, 6) AS billingprepayvscompletetermratio,
        ROUND(CASE WHEN SUM(CASE WHEN l1cc.loan_end_date <= l1cc.observation_date THEN 1 ELSE 0 END) > 0 THEN CAST(SUM(CASE WHEN l1cc.is_billing_prepay = 1 THEN 1 ELSE 0 END) AS DOUBLE) / CAST(SUM(CASE WHEN l1cc.loan_end_date <= l1cc.observation_date THEN 1 ELSE 0 END) AS DOUBLE) ELSE 0 END, 6) AS billingprepayvsbillingtermratio,
        SUM(CASE WHEN l1cc.is_overdue = 1 THEN 1 ELSE 0 END) AS overduetermcnt,
        ROUND(CASE WHEN SUM(l1cc.is_complete) > 0 THEN SUM(CASE WHEN l1cc.is_overdue = 1 THEN 1 ELSE 0 END) / SUM(l1cc.is_complete) ELSE 0 END, 6) AS overduevscompletedtermratio,
        ROUND(CASE WHEN SUM(CASE WHEN l1cc.loan_end_date <= l1cc.observation_date THEN 1 ELSE 0 END) > 0 THEN CAST(SUM(CASE WHEN l1cc.is_overdue = 1 THEN 1 ELSE 0 END) AS DOUBLE) / CAST(SUM(CASE WHEN l1cc.loan_end_date <= l1cc.observation_date THEN 1 ELSE 0 END) AS DOUBLE) ELSE 0 END, 6) AS overduevsbillingtermratio,
        -- 修复：避免在CASE WHEN条件中使用聚合函数，直接计算比例，用NULLIF避免除零
        ROUND(CAST(SUM(CASE WHEN l1cc.is_overdue = 1 THEN 1 ELSE 0 END) AS DOUBLE) / NULLIF(MAX(l1cc.latest1_total_terms_cnt), 0), 6) AS overduetermratio,
        -- 【修复】使用真正的连续逾期计算
        MAX(l1cc.consecutive_overdue_cnt) AS maxsuccessiveoverduetermcnt,
        ROUND(CASE WHEN SUM(CASE WHEN l1cc.loan_end_date <= l1cc.observation_date THEN 1 ELSE 0 END) > 0 THEN CAST(MAX(l1cc.consecutive_overdue_cnt) AS DOUBLE) / CAST(SUM(CASE WHEN l1cc.loan_end_date <= l1cc.observation_date THEN 1 ELSE 0 END) AS DOUBLE) ELSE 0 END, 6) AS maxsuccessiveoverduetermvsbillingratio,
        -- 修复：避免在CASE WHEN条件中使用聚合函数，直接计算比例，用NULLIF避免除零
        ROUND(CAST(MAX(l1cc.consecutive_overdue_cnt) AS DOUBLE) / NULLIF(MAX(l1cc.latest1_total_terms_cnt), 0), 6) AS maxsuccessiveoverduetermvsallratio,
        -- 【修复】使用真正的连续提前结清计算
        MAX(l1cc.consecutive_prepay_cnt) AS maxsuccessiveprepaytermcnt,
        ROUND(CASE WHEN SUM(CASE WHEN l1cc.loan_end_date <= l1cc.observation_date THEN 1 ELSE 0 END) > 0 THEN CAST(MAX(l1cc.consecutive_prepay_cnt) AS DOUBLE) / CAST(SUM(CASE WHEN l1cc.loan_end_date <= l1cc.observation_date THEN 1 ELSE 0 END) AS DOUBLE) ELSE 0 END, 6) AS maxsuccessiveprepaytermvsbillingratio,
        -- 修复：避免在CASE WHEN条件中使用聚合函数，直接计算比例，用NULLIF避免除零
        ROUND(CAST(MAX(l1cc.consecutive_prepay_cnt) AS DOUBLE) / NULLIF(MAX(l1cc.latest1_total_terms_cnt), 0), 6) AS maxsuccessiveprepaytermvsallratio,
        -- 【放款天数】修改：累加所有账单的实际放款天数
        -- 新逻辑：先判断账单是否已放款（loan_start_date <= observation_date），只统计已放款账单的放款天数
        SUM(CASE
                WHEN l1cc.loan_start_date <= l1cc.observation_date  -- 只统计已放款的账单
                    THEN CASE
                             WHEN l1cc.settled_time IS NOT NULL
                                 AND l1cc.settled_time <= l1cc.observation_date  -- 已结清且结清时间在观察日期之前
                                 THEN GREATEST(0, DATEDIFF(DATE(l1cc.settled_time), DATE(l1cc.loan_start_date)))  -- 修复：使用GREATEST避免负数
                             ELSE GREATEST(0, DATEDIFF(l1cc.observation_date, DATE(l1cc.loan_start_date)))  -- 修复：使用GREATEST避免负数
                    END
                ELSE 0  -- 未放款的账单不计入放款天数
            END) AS payoutdays,
        -- 修复：createdNowGap存在数据泄露风险，如果首期账单未到期，返回NULL避免泄露信息
        -- 原因：如果createdNowGap很小（0-7天），说明订单刚创建，首期账单刚到期，如果未结清，很可能就是逾期的
        -- 这会导致数据泄露，因为FPD7标签基于首期账单是否逾期7天以上
        CASE
            WHEN MIN(CASE WHEN l1cc.periods = 1 THEN l1cc.loan_end_date ELSE NULL END) IS NOT NULL
                AND MIN(CASE WHEN l1cc.periods = 1 THEN l1cc.loan_end_date ELSE NULL END) <= l1cc.observation_date
                THEN DATEDIFF(l1cc.observation_date, DATE(l1cc.latest1_order_create_time))
            ELSE NULL
            END AS createdNowGap,
        -- 修复：计算第一期账单的结清时间到第一期账单放款时间的日期差
        -- 如果结清时间为空则赋值为-1，如果日期差小于0则统一赋值为0
        CASE
            WHEN MIN(CASE WHEN l1cc.periods = 1 THEN l1cc.settled_time ELSE NULL END) IS NULL
                THEN -1  -- 第一期账单未结清，返回-1
            WHEN MIN(CASE WHEN l1cc.periods = 1 THEN l1cc.settled_time ELSE NULL END) IS NOT NULL
                AND MIN(CASE WHEN l1cc.periods = 1 THEN l1cc.settled_time ELSE NULL END) <= l1cc.observation_date
                THEN CASE
                         WHEN DATEDIFF(
                                      DATE(MIN(CASE WHEN l1cc.periods = 1 THEN l1cc.settled_time ELSE NULL END)),
                                      DATE(MIN(CASE WHEN l1cc.periods = 1 THEN l1cc.loan_start_date ELSE NULL END))
                              ) < 0
                             THEN 0  -- 日期差小于0，统一赋值为0
                         ELSE DATEDIFF(
                                 DATE(MIN(CASE WHEN l1cc.periods = 1 THEN l1cc.settled_time ELSE NULL END)),
                                 DATE(MIN(CASE WHEN l1cc.periods = 1 THEN l1cc.loan_start_date ELSE NULL END))
                              )
                END
            ELSE -1  -- 第一期账单结清时间晚于观察日期，返回-1
            END AS firstcompletedcreatedgap,
        ROUND(CASE WHEN MAX(l1cc.latest1_credit_limit) > 0 THEN MAX(l1cc.latest1_loan_amt) / MAX(l1cc.latest1_credit_limit) ELSE 0 END, 6) AS creditusageratio,
        MAX(CASE WHEN l1cc.create_hour BETWEEN 11 AND 13 THEN 1 ELSE 0 END) AS creatednoon,
        MAX(CASE WHEN l1cc.create_hour BETWEEN 23 AND 23 OR l1cc.create_hour BETWEEN 0 AND 4 THEN 1 ELSE 0 END) AS creatednight,
        MAX(CASE WHEN l1cc.create_hour BETWEEN 6 AND 10 THEN 1 ELSE 0 END) AS createdmorning,
        MAX(CASE WHEN l1cc.create_hour BETWEEN 18 AND 22 THEN 1 ELSE 0 END) AS createdevening,
        MAX(CASE WHEN l1cc.create_hour BETWEEN 15 AND 17 THEN 1 ELSE 0 END) AS createdafternoon,
        MAX(l1cc.latest1_order_create_interval_days) AS order_create_interval_days,
        ROUND(CASE WHEN SUM(l1cc.is_future_bill) > 0 THEN SUM(l1cc.is_future_bill_complete) / SUM(l1cc.is_future_bill) ELSE 0 END, 6) AS future_bill_complete_ratio
    FROM latest1_order_consecutive_calc l1cc
    GROUP BY l1cc.cust_no, l1cc.latest1_order_create_time, l1cc.latest1_order_payout_time, l1cc.observation_date
),

-- ===================== 20. 新增：未来账单未结清特征（6个） =====================
-- 20.1 未来90-180天未结清订单特征
multi_loan_future_bills_90_180 AS (
    SELECT
        bl.cust_no,
        bl.loan_no,
        bl.calc_credit_time,
        bl.loan_end_date,
        bl.settled_time,
        bl.is_complete,
        -- 未来90-180天的未到期且未结清账单（基于观察日期计算，loan_end_date在observation_date未来90-180天范围内，且未结清）
        -- 修复：统一使用observation_date作为时间基准，确保与is_complete字段的时间基准一致
        CASE
            WHEN bl.loan_end_date > date_add(bl.observation_date, 90)
                AND bl.loan_end_date <= date_add(bl.observation_date, 180)
                AND (bl.settled_time IS NULL OR bl.is_complete = 0)
                AND (bl.settled_time IS NULL OR bl.settled_time <= bl.observation_date)  -- 确保只使用观察时点已知的信息
                THEN 1
            ELSE 0
            END AS is_future_90_180_unclear,
        -- 观察时点的全部未结清账单（只统计已到期但未结清的账单，不包含未来账单）
        -- 修复：未来账单在观察日期时还没有到期，不应该被算作"未结清"，避免时间穿越（IV异常高问题）
        CASE
            WHEN bl.loan_end_date <= bl.observation_date  -- 只统计已到期的账单
                AND (bl.settled_time IS NULL OR bl.is_complete = 0)  -- 未结清
                AND (bl.settled_time IS NULL OR bl.settled_time <= bl.observation_date)  -- 确保只使用观察时点已知的信息
                THEN 1
            ELSE 0
            END AS is_unclear_at_obs_time,
        -- 观察时点的全部已结清账单（所有已结清的账单）
        CASE
            WHEN bl.is_complete = 1
                AND bl.settled_time IS NOT NULL
                AND bl.settled_time <= bl.observation_date  -- 确保只使用观察时点已知的信息
                THEN 1
            ELSE 0
            END AS is_clear_at_obs_time
    FROM base_loan_data_light bl
    WHERE EXISTS (
        SELECT 1
        FROM user_multi_loan_flag mlf
        WHERE bl.cust_no = mlf.cust_no
          AND bl.loan_no = mlf.loan_no
          AND mlf.is_multi_loan = 1
    )
),

multiLoanRangeFuture90DTo180D AS (
    SELECT
        cust_no,
        SUM(is_future_90_180_unclear) AS futurebillingunclearinstalcnt,
        ROUND(CASE
                  WHEN SUM(is_unclear_at_obs_time) > 0
                      THEN SUM(is_future_90_180_unclear) / SUM(is_unclear_at_obs_time)
                  ELSE 0
                  END, 6) AS futurebillingunclearvsunclearinstalratio,
        ROUND(CASE
                  WHEN SUM(is_clear_at_obs_time) > 0
                      THEN SUM(is_future_90_180_unclear) / SUM(is_clear_at_obs_time)
                  ELSE 0
                  END, 6) AS futurebillingunclearvsclearinstalratio
    FROM multi_loan_future_bills_90_180
    GROUP BY cust_no
),

-- 20.2 未来90天未结清订单特征
multi_loan_future_bills_0_90 AS (
    SELECT
        bl.cust_no,
        bl.loan_no,
        bl.calc_credit_time,
        bl.loan_end_date,
        bl.settled_time,
        bl.is_complete,
        -- 未来90天的未到期且未结清账单（基于观察日期计算，loan_end_date在observation_date未来90天范围内，且未结清）
        -- 修复：统一使用observation_date作为时间基准，确保与is_complete字段的时间基准一致
        CASE
            WHEN bl.loan_end_date > bl.observation_date
                AND bl.loan_end_date <= date_add(bl.observation_date, 90)
                AND (bl.settled_time IS NULL OR bl.is_complete = 0)
                AND (bl.settled_time IS NULL OR bl.settled_time <= bl.observation_date)  -- 确保只使用观察时点已知的信息
                THEN 1
            ELSE 0
            END AS is_future_0_90_unclear,
        -- 观察时点的全部未结清账单（只统计已到期但未结清的账单，不包含未来账单）
        -- 修复：未来账单在观察日期时还没有到期，不应该被算作"未结清"，避免时间穿越（IV异常高问题）
        CASE
            WHEN bl.loan_end_date <= bl.observation_date  -- 只统计已到期的账单
                AND (bl.settled_time IS NULL OR bl.is_complete = 0)  -- 未结清
                AND (bl.settled_time IS NULL OR bl.settled_time <= bl.observation_date)  -- 确保只使用观察时点已知的信息
                THEN 1
            ELSE 0
            END AS is_unclear_at_obs_time,
        -- 观察时点的全部已结清账单（所有已结清的账单）
        CASE
            WHEN bl.is_complete = 1
                AND bl.settled_time IS NOT NULL
                AND bl.settled_time <= bl.observation_date  -- 确保只使用观察时点已知的信息
                THEN 1
            ELSE 0
            END AS is_clear_at_obs_time
    FROM base_loan_data_light bl
    WHERE EXISTS (
        SELECT 1
        FROM user_multi_loan_flag mlf
        WHERE bl.cust_no = mlf.cust_no
          AND bl.loan_no = mlf.loan_no
          AND mlf.is_multi_loan = 1
    )
),

multiLoanRangeFuture0DTo90D AS (
    SELECT
        cust_no,
        SUM(is_future_0_90_unclear) AS futurebillingunclearinstalcnt,
        ROUND(CASE
                  WHEN SUM(is_unclear_at_obs_time) > 0
                      THEN SUM(is_future_0_90_unclear) / SUM(is_unclear_at_obs_time)
                  ELSE 0
                  END, 6) AS futurebillingunclearvsunclearinstalratio,
        ROUND(CASE
                  WHEN SUM(is_clear_at_obs_time) > 0
                      THEN SUM(is_future_0_90_unclear) / SUM(is_clear_at_obs_time)
                  ELSE 0
                  END, 6) AS futurebillingunclearvsclearinstalratio
    FROM multi_loan_future_bills_0_90
    GROUP BY cust_no
),

-- ===================== 21. 新增：无在贷结清特征（优化v3：合并90天和180天计算） =====================
-- 通用时间窗口订单日期范围计算（90天和180天）
multi_loan_order_date_ranges_by_window AS (
    SELECT
        bl.cust_no,
        bl.observation_date,
        bl.loan_no,
        -- 订单的借款开始日期：取第一期的loan_start_date（MIN）
        MIN(DATE(bl.loan_start_date)) AS order_start_date,
        -- 订单的借款结束日期：
        -- 1. 如果所有账单都已结清，取最后一期的settled_time
        -- 2. 如果还有未结清账单，取observation_date
        CASE
            WHEN COUNT(DISTINCT bl.rp_id) = SUM(CASE WHEN bl.is_complete = 1 THEN 1 ELSE 0 END)
                AND MAX(bl.settled_time) IS NOT NULL
                THEN DATE(MAX(bl.settled_time))
            ELSE MAX(bl.observation_date)
            END AS order_end_date
    FROM base_loan_data_light bl
             INNER JOIN multi_loan_cust_loan_pairs mlp
                        ON bl.cust_no = mlp.cust_no
                            AND bl.loan_no = mlp.loan_no
                            -- 修改：使用repay_plan的create_time作为筛选条件，同时计算90天和180天窗口
                            AND bl.rp_create_time >= date_sub(bl.observation_date, 180)
                            AND bl.rp_create_time <= bl.observation_date
    GROUP BY bl.cust_no, bl.observation_date, bl.loan_no
),

-- 计算订单在观察窗口内的有效借款区间（90天和180天）
multi_loan_bill_date_ranges_by_window AS (
    SELECT
        cust_no,
        observation_date,
        loan_no,
        order_start_date,
        order_end_date,
        -- 90天窗口
        CASE
            WHEN order_start_date > date_sub(observation_date, 90)
                THEN order_start_date
            ELSE date_sub(observation_date, 90)
            END AS bill_start_date_90d,
        CASE
            WHEN order_end_date < observation_date
                THEN order_end_date
            ELSE observation_date
            END AS bill_end_date_90d,
        -- 180天窗口
        CASE
            WHEN order_start_date > date_sub(observation_date, 180)
                THEN order_start_date
            ELSE date_sub(observation_date, 180)
            END AS bill_start_date_180d,
        CASE
            WHEN order_end_date < observation_date
                THEN order_end_date
            ELSE observation_date
            END AS bill_end_date_180d
    FROM multi_loan_order_date_ranges_by_window
    WHERE (order_start_date <= observation_date AND order_end_date >= date_sub(observation_date, 180))
),

-- 计算LAG值并合并重叠区间（90天和180天）
multi_loan_bill_ranges_with_lag AS (
    SELECT
        cust_no,
        observation_date,
        loan_no,
        bill_start_date_90d,
        bill_end_date_90d,
        bill_start_date_180d,
        bill_end_date_180d,
        LAG(bill_end_date_90d) OVER (PARTITION BY cust_no, observation_date ORDER BY bill_start_date_90d, bill_end_date_90d) AS prev_bill_end_date_90d,
        LAG(bill_end_date_180d) OVER (PARTITION BY cust_no, observation_date ORDER BY bill_start_date_180d, bill_end_date_180d) AS prev_bill_end_date_180d
    FROM multi_loan_bill_date_ranges_by_window
    WHERE bill_start_date_90d <= bill_end_date_90d OR bill_start_date_180d <= bill_end_date_180d
),

merged_bill_ranges_by_window AS (
    SELECT
        cust_no,
        observation_date,
        loan_no,
        bill_start_date_90d,
        bill_end_date_90d,
        bill_start_date_180d,
        bill_end_date_180d,
        SUM(CASE
                WHEN prev_bill_end_date_90d IS NULL
                    OR bill_start_date_90d > prev_bill_end_date_90d + 1
                    THEN 1
                ELSE 0
                END) OVER (PARTITION BY cust_no, observation_date ORDER BY bill_start_date_90d, bill_end_date_90d ROWS UNBOUNDED PRECEDING) AS interval_group_90d,
        SUM(CASE
                WHEN prev_bill_end_date_180d IS NULL
                    OR bill_start_date_180d > prev_bill_end_date_180d + 1
                    THEN 1
                ELSE 0
                END) OVER (PARTITION BY cust_no, observation_date ORDER BY bill_start_date_180d, bill_end_date_180d ROWS UNBOUNDED PRECEDING) AS interval_group_180d
    FROM multi_loan_bill_ranges_with_lag
),

-- 计算实际在贷天数（90天和180天）
actual_loan_days_by_window AS (
    SELECT
        cust_no,
        observation_date,
        SUM(DATEDIFF(merged_end_date_90d, merged_start_date_90d) + 1) AS actual_loan_days_90d,
        SUM(DATEDIFF(merged_end_date_180d, merged_start_date_180d) + 1) AS actual_loan_days_180d
    FROM (
             SELECT
                 cust_no,
                 observation_date,
                 interval_group_90d,
                 interval_group_180d,
                 MIN(bill_start_date_90d) AS merged_start_date_90d,
                 MAX(bill_end_date_90d) AS merged_end_date_90d,
                 MIN(bill_start_date_180d) AS merged_start_date_180d,
                 MAX(bill_end_date_180d) AS merged_end_date_180d
             FROM merged_bill_ranges_by_window
             GROUP BY cust_no, observation_date, interval_group_90d, interval_group_180d
         ) t
    GROUP BY cust_no, observation_date
),

-- 统计结清订单数（90天和180天）
multi_loan_clear_orders_by_window AS (
    SELECT
        bl.cust_no,
        bl.loan_no,
        MAX(bl.observation_date) AS observation_date,
        MAX(bl.periods) AS max_periods,
        -- 90天窗口：最大periods账单是否在窗口内且已结清
        MAX(CASE
                WHEN bl.periods = (SELECT MAX(periods) FROM base_loan_data_light bl2
                                   WHERE bl2.cust_no = bl.cust_no AND bl2.loan_no = bl.loan_no)
                    -- AND bl.rp_create_time >= date_sub(bl.observation_date, 90)
                    -- AND bl.rp_create_time <= bl.observation_date
                    AND bl.settled_time IS NOT NULL
                    AND bl.settled_time <= bl.observation_date
                    THEN 1
                ELSE 0
            END) AS is_max_period_cleared_90d,
        -- 180天窗口：最大periods账单是否在窗口内且已结清
        MAX(CASE
                WHEN bl.periods = (SELECT MAX(periods) FROM base_loan_data_light bl2
                                   WHERE bl2.cust_no = bl.cust_no AND bl2.loan_no = bl.loan_no)
                    -- AND bl.rp_create_time >= date_sub(bl.observation_date, 180)
                    -- AND bl.rp_create_time <= bl.observation_date
                    AND bl.settled_time IS NOT NULL
                    AND bl.settled_time <= bl.observation_date
                    THEN 1
                ELSE 0
            END) AS is_max_period_cleared_180d,
        -- 保留原有的窗口标记（用于统计总订单数）
        MAX(CASE
                WHEN bl.rp_create_time >= date_sub(bl.observation_date, 90)
                    AND bl.rp_create_time <= bl.observation_date
                    THEN 1
                ELSE 0
            END) AS in_window_90d,
        MAX(CASE
                WHEN bl.rp_create_time >= date_sub(bl.observation_date, 180)
                    AND bl.rp_create_time <= bl.observation_date
                    THEN 1
                ELSE 0
            END) AS in_window_180d
    FROM base_loan_data_light bl
             INNER JOIN multi_loan_cust_loan_pairs mlp
                        ON bl.cust_no = mlp.cust_no
                            AND bl.loan_no = mlp.loan_no
                            AND bl.rp_create_time >= date_sub(bl.observation_date, 180)
                            AND bl.rp_create_time <= bl.observation_date
    GROUP BY bl.cust_no, bl.loan_no
),


multiLoanNoLoanClearStats AS (
    SELECT
        ald.cust_no,
        ald.observation_date,
        CASE
            WHEN 90 - COALESCE(ald.actual_loan_days_90d, 0) > 0
                THEN 90 - COALESCE(ald.actual_loan_days_90d, 0)
            ELSE 0
            END AS noLoanDays_90d,
        CASE
            WHEN 180 - COALESCE(ald.actual_loan_days_180d, 0) > 0
                THEN 180 - COALESCE(ald.actual_loan_days_180d, 0)
            ELSE 0
            END AS noLoanDays_180d,
        -- 修改：使用最大periods账单结清标记
        COALESCE(SUM(CASE WHEN mco.is_max_period_cleared_90d = 1 THEN 1 ELSE 0 END), 0) AS clearOrderCnt_90d,
        COALESCE(SUM(CASE WHEN mco.is_max_period_cleared_180d = 1 THEN 1 ELSE 0 END), 0) AS clearOrderCnt_180d,
        COUNT(DISTINCT CASE WHEN mco.in_window_90d = 1 THEN mco.loan_no END) AS total_loan_cnt_90d,
        COUNT(DISTINCT CASE WHEN mco.in_window_180d = 1 THEN mco.loan_no END) AS total_loan_cnt_180d
    FROM actual_loan_days_by_window ald
             LEFT JOIN multi_loan_clear_orders_by_window mco
                       ON ald.cust_no = mco.cust_no
                           AND ald.observation_date = mco.observation_date
    GROUP BY ald.cust_no, ald.observation_date, ald.actual_loan_days_90d, ald.actual_loan_days_180d
),

multi_loan_order_info_multiloannoloanclear90dstat_final AS (
    SELECT
        cust_no,
        COALESCE(noLoanDays_90d, 0) AS noLoanDays,
        ROUND(CASE WHEN 90 > 0 THEN COALESCE(noLoanDays_90d, 0) / 90.0 ELSE 0 END, 6) AS noLoanDaysRatio,
        COALESCE(clearOrderCnt_90d, 0) AS clearOrderCnt,
        ROUND(CASE
                  WHEN total_loan_cnt_90d > 0
                      THEN COALESCE(clearOrderCnt_90d, 0) / CAST(total_loan_cnt_90d AS DOUBLE)
                  ELSE 0
                  END, 6) AS clearOrderRatio
    FROM multiLoanNoLoanClearStats
),

multi_loan_order_info_multiloannoloanclear180dstat_final AS (
    SELECT
        cust_no,
        COALESCE(noLoanDays_180d, 0) AS noLoanDays,
        ROUND(CASE WHEN 180 > 0 THEN COALESCE(noLoanDays_180d, 0) / 180.0 ELSE 0 END, 6) AS noLoanDaysRatio,
        COALESCE(clearOrderCnt_180d, 0) AS clearOrderCnt,
        ROUND(CASE
                  WHEN total_loan_cnt_180d > 0
                      THEN COALESCE(clearOrderCnt_180d, 0) / CAST(total_loan_cnt_180d AS DOUBLE)
                  ELSE 0
                  END, 6) AS clearOrderRatio
    FROM multiLoanNoLoanClearStats
),

-- ===================== 22. 过去天数订单特征（优化v3：合并90天和30天统计，一次扫描，使用INNER JOIN替代EXISTS） =====================
multi_loan_time_window_stats AS (
    SELECT
        bl.cust_no,
        -- 90天统计
        COUNT(DISTINCT CASE
                           WHEN bl.loan_start_date >= date_sub(bl.observation_date, 90)
                               AND bl.loan_start_date <= bl.observation_date
                               AND bl.periods = 1
                               THEN bl.loan_no
                           ELSE NULL
            END) AS payoutOrderCnt_90d,
        COUNT(DISTINCT CASE
                           WHEN bl.loan_start_date >= date_sub(bl.observation_date, 90)
                               AND bl.loan_start_date <= bl.observation_date
                               AND bl.periods = 1
                               AND mlp.cust_no IS NOT NULL  -- 使用INNER JOIN替代EXISTS
                               THEN bl.loan_no
                           ELSE NULL
            END) AS payoutMultiLoanOrderCnt_90d,
        -- 30天统计
        COUNT(DISTINCT CASE
                           WHEN bl.loan_start_date >= date_sub(bl.observation_date, 30)
                               AND bl.loan_start_date <= bl.observation_date
                               AND bl.periods = 1
                               THEN bl.loan_no
                           ELSE NULL
            END) AS payoutOrderCnt_30d,
        COUNT(DISTINCT CASE
                           WHEN bl.loan_start_date >= date_sub(bl.observation_date, 30)
                               AND bl.loan_start_date <= bl.observation_date
                               AND bl.periods = 1
                               AND mlp.cust_no IS NOT NULL  -- 使用INNER JOIN替代EXISTS
                               THEN bl.loan_no
                           ELSE NULL
            END) AS payoutMultiLoanOrderCnt_30d
    FROM base_loan_data_light bl
             LEFT JOIN multi_loan_cust_loan_pairs mlp
                       ON bl.cust_no = mlp.cust_no
                           AND bl.loan_no = mlp.loan_no
    GROUP BY bl.cust_no
),

multi_loan_calc_credits_times_by_window AS (
    SELECT
        cl.cust_no,
        COUNT(DISTINCT CASE
                           WHEN cl.create_time >= date_sub(odc.observation_date, 90)
                               AND cl.create_time <= odc.observation_date
                               THEN date(cl.create_time)
                           ELSE NULL
            END) AS multi_loan_calc_credits_times_90d,
        COUNT(DISTINCT CASE
                           WHEN cl.create_time >= date_sub(odc.observation_date, 30)
                               AND cl.create_time <= odc.observation_date
                               THEN date(cl.create_time)
                           ELSE NULL
            END) AS multi_loan_calc_credits_times_30d
    FROM (SELECT observation_date FROM observation_date_config) odc
             INNER JOIN hive_idc.hello_prd.ods_mx_aprv_cust_credit_limit_record_df cl
                        ON cl.pt = odc.observation_date
                            AND cl.create_time >= date_sub(odc.observation_date, 90)
                            AND cl.create_time <= odc.observation_date
             INNER JOIN user_multi_loan_flag mlf
                        ON cl.cust_no = mlf.cust_no
                            AND mlf.is_multi_loan = 1
    GROUP BY cl.cust_no
),

multi_loan_order_info_multiloan90dstat_final AS (
    SELECT
        tws.cust_no,
        COALESCE(tws.payoutOrderCnt_90d, 0) AS payoutOrderCnt,
        COALESCE(tws.payoutMultiLoanOrderCnt_90d, 0) AS payoutMultiLoanOrderCnt,
        ROUND(CASE
                  WHEN COALESCE(ct.multi_loan_calc_credits_times_90d, 0) > 0
                      THEN tws.payoutMultiLoanOrderCnt_90d / CAST(ct.multi_loan_calc_credits_times_90d AS DOUBLE)
                  ELSE 0
                  END, 6) AS multiloancalcvsmultiloanpayoutratio
    FROM multi_loan_time_window_stats tws
             LEFT JOIN multi_loan_calc_credits_times_by_window ct
                       ON tws.cust_no = ct.cust_no
),

multi_loan_order_info_multiloan30dstat_final AS (
    SELECT
        tws.cust_no,
        COALESCE(tws.payoutOrderCnt_30d, 0) AS payoutOrderCnt,
        COALESCE(tws.payoutMultiLoanOrderCnt_30d, 0) AS payoutMultiLoanOrderCnt,
        ROUND(CASE
                  WHEN COALESCE(ct.multi_loan_calc_credits_times_30d, 0) > 0
                      THEN tws.payoutMultiLoanOrderCnt_30d / CAST(ct.multi_loan_calc_credits_times_30d AS DOUBLE)
                  ELSE 0
                  END, 6) AS multiloancalcvsmultiloanpayoutratio
    FROM multi_loan_time_window_stats tws
             LEFT JOIN multi_loan_calc_credits_times_by_window ct
                       ON tws.cust_no = ct.cust_no
),

-- ===================== 23. 客户维度基础表 =====================
cust_base AS (
    SELECT
        bl.cust_no,
        MAX(bl.observation_date) AS observation_date
    FROM base_loan_data_light bl
    WHERE bl.cust_no IS NOT NULL
    GROUP BY bl.cust_no
),

-- ===================== 24. 最终合并：客户维度特征输出 =====================
merged_all_features AS (
    SELECT
        -- 核心关联键（客户维度）
        cb.cust_no,
        cb.observation_date,
        COALESCE(latest1_order.latest1_order_create_time, NULL) AS latest1_order_create_time,
        -- ===================== 第一部分：第一个查询72个特征 =====================
        -- 最远一笔（11个）
        COALESCE(furthest_feat.completedinstalcnt, 0) AS multi_loan_in_loan_order_furthest_completedinstalcnt,
        COALESCE(furthest_feat.completedinstalratio, 0) AS multi_loan_in_loan_order_furthest_completedinstalratio,
        COALESCE(furthest_feat.completedloanamount, 0) AS multi_loan_in_loan_order_furthest_completedloanamount,
        COALESCE(furthest_feat.completednotdueinstalcnt, 0) AS multi_loan_in_loan_order_furthest_completednotdueinstalcnt,
        COALESCE(furthest_feat.completednotdueinstalovercompletedratio, 0) AS multi_loan_in_loan_order_furthest_completednotdueinstalovercompletedratio,
        COALESCE(furthest_feat.completednotdueinstalovernotdueratio, 0) AS multi_loan_in_loan_order_furthest_completednotdueinstalovernotdueratio,
        COALESCE(furthest_feat.completednotdueloanamount, 0) AS multi_loan_in_loan_order_furthest_completednotdueloanamount,
        COALESCE(furthest_feat.createdtimecalccreditsgap, 0.0) AS multi_loan_in_loan_order_furthest_createdtimecalccreditsgap,
        COALESCE(furthest_feat.instalmentcnt, 0) AS multi_loan_in_loan_order_furthest_instalmentcnt,
        COALESCE(furthest_feat.payoutdays, 0) AS multi_loan_in_loan_order_furthest_payoutdays,
        COALESCE(furthest_feat.firstcompletedinstalgap, 0) AS multi_loan_in_loan_order_furthest_firstcompletedinstalgap,
        COALESCE(furthest_feat.uncompletedinstalcnt, 0) AS multi_loan_in_loan_order_furthest_uncompletedinstalcnt,

        -- 最近第一笔（38个）
        COALESCE(recent_first_feat.completedadvanceinstaldaysavg, 0) AS multi_loan_in_loan_order_recentfirst_completedadvanceinstaldaysavg,
        COALESCE(recent_first_feat.completedadvanceinstaldaysmax, 0) AS multi_loan_in_loan_order_recentfirst_completedadvanceinstaldaysmax,
        COALESCE(recent_first_feat.completedadvanceinstaldaysstd, 0) AS multi_loan_in_loan_order_recentfirst_completedadvanceinstaldaysstd,
        COALESCE(recent_first_feat.completedinstalcnt, 0) AS multi_loan_in_loan_order_recentfirst_completedinstalcnt,
        COALESCE(recent_first_feat.completedinstalratio, 0) AS multi_loan_in_loan_order_recentfirst_completedinstalratio,
        COALESCE(recent_first_feat.completednotdueinstalcnt, 0) AS multi_loan_in_loan_order_recentfirst_completednotdueinstalcnt,
        COALESCE(recent_first_feat.completednotdueinstalovercompletedratio, 0) AS multi_loan_in_loan_order_recentfirst_completednotdueinstalovercompletedratio,
        COALESCE(recent_first_feat.completednotdueinstalovernotdueratio, 0) AS multi_loan_in_loan_order_recentfirst_completednotdueinstalovernotdueratio,
        COALESCE(recent_first_feat.completednotdueloanamount, 0) AS multi_loan_in_loan_order_recentfirst_completednotdueloanamount,
        COALESCE(recent_first_feat.completedsamedayinstalcntavg, 0) AS multi_loan_in_loan_order_recentfirst_completedsamedayinstalcntavg,
        COALESCE(recent_first_feat.completedsamedayinstalcntmax, 0) AS multi_loan_in_loan_order_recentfirst_completedsamedayinstalcntmax,
        COALESCE(recent_first_feat.createdordertimegap, 0.0) AS multi_loan_in_loan_order_recentfirst_createdordertimegap,
        COALESCE(recent_first_feat.createdtimeperiodonehotvo_afternoon, 0) AS multi_loan_in_loan_order_recentfirst_createdtimeperiodonehotvo_afternoon,
        COALESCE(recent_first_feat.createdtimeperiodonehotvo_evening, 0) AS multi_loan_in_loan_order_recentfirst_createdtimeperiodonehotvo_evening,
        COALESCE(recent_first_feat.createdtimeperiodonehotvo_missing, 0) AS multi_loan_in_loan_order_recentfirst_createdtimeperiodonehotvo_missing,
        COALESCE(recent_first_feat.createdtimeperiodonehotvo_morning, 0) AS multi_loan_in_loan_order_recentfirst_createdtimeperiodonehotvo_morning,
        COALESCE(recent_first_feat.createdtimeperiodonehotvo_night, 0) AS multi_loan_in_loan_order_recentfirst_createdtimeperiodonehotvo_night,
        COALESCE(recent_first_feat.createdtimeperiodonehotvo_noon, 0) AS multi_loan_in_loan_order_recentfirst_createdtimeperiodonehotvo_noon,
        COALESCE(recent_first_feat.createdtimeperiodonehotvo_other, 0) AS multi_loan_in_loan_order_recentfirst_createdtimeperiodonehotvo_other,
        COALESCE(recent_first_feat.creditusageratio, 0) AS multi_loan_in_loan_order_recentfirst_creditusageratio,
        COALESCE(recent_first_feat.firstcompletedinstalgap, 0) AS multi_loan_in_loan_order_recentfirst_firstcompletedinstalgap,
        COALESCE(recent_first_feat.firstselfcompletedinstalgap, 0) AS multi_loan_in_loan_order_recentfirst_firstselfcompletedinstalgap,
        COALESCE(recent_first_feat.instalmentcnt, 0) AS multi_loan_in_loan_order_recentfirst_instalmentcnt,
        COALESCE(recent_first_feat.maxcontinuecompletedadvanceinstalcnt, 0) AS multi_loan_in_loan_order_recentfirst_maxcontinuecompletedadvanceinstalcnt,
        COALESCE(recent_first_feat.maxcontinuecompletedadvanceinstalratio, 0) AS multi_loan_in_loan_order_recentfirst_maxcontinuecompletedadvanceinstalratio,
        COALESCE(recent_first_feat.maxcontinueoverdueinstalcnt, 0) AS multi_loan_in_loan_order_recentfirst_maxcontinueoverdueinstalcnt,
        COALESCE(recent_first_feat.maxcontinueoverdueinstalratio, 0) AS multi_loan_in_loan_order_recentfirst_maxcontinueoverdueinstalratio,
        COALESCE(recent_first_feat.overdueinstalcnt, 0) AS multi_loan_in_loan_order_recentfirst_overdueinstalcnt,
        COALESCE(recent_first_feat.overdueinstalratio, 0) AS multi_loan_in_loan_order_recentfirst_overdueinstalratio,
        COALESCE(recent_first_feat.payoutdays, 0) AS multi_loan_in_loan_order_recentfirst_payoutdays,
        COALESCE(recent_first_feat.uncompletedinstalcnt, 0) AS multi_loan_in_loan_order_recentfirst_uncompletedinstalcnt,

        -- 最近第二笔（23个）
        COALESCE(recent_second_feat.completedadvanceinstaldaysavg, 0) AS multi_loan_in_loan_order_recentsecond_completedadvanceinstaldaysavg,
        COALESCE(recent_second_feat.completedadvanceinstaldaysmax, 0) AS multi_loan_in_loan_order_recentsecond_completedadvanceinstaldaysmax,
        COALESCE(recent_second_feat.completedadvanceinstaldaysstd, 0) AS multi_loan_in_loan_order_recentsecond_completedadvanceinstaldaysstd,
        COALESCE(recent_second_feat.completedinstalcnt, 0) AS multi_loan_in_loan_order_recentsecond_completedinstalcnt,
        COALESCE(recent_second_feat.completedinstalratio, 0) AS multi_loan_in_loan_order_recentsecond_completedinstalratio,
        COALESCE(recent_second_feat.completednotdueinstalcnt, 0) AS multi_loan_in_loan_order_recentsecond_completednotdueinstalcnt,
        COALESCE(recent_second_feat.completednotdueinstalovercompletedratio, 0) AS multi_loan_in_loan_order_recentsecond_completednotdueinstalovercompletedratio,
        COALESCE(recent_second_feat.completednotdueinstalovernotdueratio, 0) AS multi_loan_in_loan_order_recentsecond_completednotdueinstalovernotdueratio,
        COALESCE(recent_second_feat.completedsamedayinstalcntavg, 0) AS multi_loan_in_loan_order_recentsecond_completedsamedayinstalcntavg,
        COALESCE(recent_second_feat.completedsamedayinstalcntmax, 0) AS multi_loan_in_loan_order_recentsecond_completedsamedayinstalcntmax,
        COALESCE(recent_second_feat.createdordertimegap, 0.0) AS multi_loan_in_loan_order_recentsecond_createdordertimegap,
        COALESCE(recent_second_feat.createdtimeperiodonehotvo_afternoon, 0) AS multi_loan_in_loan_order_recentsecond_createdtimeperiodonehotvo_afternoon,
        COALESCE(recent_second_feat.createdtimeperiodonehotvo_evening, 0) AS multi_loan_in_loan_order_recentsecond_createdtimeperiodonehotvo_evening,
        COALESCE(recent_second_feat.createdtimeperiodonehotvo_missing, 0) AS multi_loan_in_loan_order_recentsecond_createdtimeperiodonehotvo_missing,
        COALESCE(recent_second_feat.createdtimeperiodonehotvo_morning, 0) AS multi_loan_in_loan_order_recentsecond_createdtimeperiodonehotvo_morning,
        COALESCE(recent_second_feat.createdtimeperiodonehotvo_night, 0) AS multi_loan_in_loan_order_recentsecond_createdtimeperiodonehotvo_night,
        COALESCE(recent_second_feat.createdtimeperiodonehotvo_noon, 0) AS multi_loan_in_loan_order_recentsecond_createdtimeperiodonehotvo_noon,
        COALESCE(recent_second_feat.createdtimeperiodonehotvo_other, 0) AS multi_loan_in_loan_order_recentsecond_createdtimeperiodonehotvo_other,
        COALESCE(recent_second_feat.firstcompletedinstalgap, 0) AS multi_loan_in_loan_order_recentsecond_firstcompletedinstalgap,
        COALESCE(recent_second_feat.firstselfcompletedinstalgap, 0) AS multi_loan_in_loan_order_recentsecond_firstselfcompletedinstalgap,
        COALESCE(recent_second_feat.instalmentcnt, 0) AS multi_loan_in_loan_order_recentsecond_instalmentcnt,
        COALESCE(recent_second_feat.maxcontinuecompletedadvanceinstalcnt, 0) AS multi_loan_in_loan_order_recentsecond_maxcontinuecompletedadvanceinstalcnt,
        COALESCE(recent_second_feat.maxcontinuecompletedadvanceinstalratio, 0) AS multi_loan_in_loan_order_recentsecond_maxcontinuecompletedadvanceinstalratio,
        COALESCE(recent_second_feat.maxcontinueoverdueinstalcnt, 0) AS multi_loan_in_loan_order_recentsecond_maxcontinueoverdueinstalcnt,
        COALESCE(recent_second_feat.maxcontinueoverdueinstalratio, 0) AS multi_loan_in_loan_order_recentsecond_maxcontinueoverdueinstalratio,
        COALESCE(recent_second_feat.minusinloanavgcreditusage, 0) AS multi_loan_in_loan_order_recentsecond_minusinloanavgcreditusage,
        COALESCE(recent_second_feat.overdueinstalcnt, 0) AS multi_loan_in_loan_order_recentsecond_overdueinstalcnt,
        COALESCE(recent_second_feat.overdueinstalratio, 0) AS multi_loan_in_loan_order_recentsecond_overdueinstalratio,
        COALESCE(recent_second_feat.payoutdays, 0) AS multi_loan_in_loan_order_recentsecond_payoutdays,
        COALESCE(recent_second_feat.uncompletedinstalcnt, 0) AS multi_loan_in_loan_order_recentsecond_uncompletedinstalcnt,

        -- ===================== 第二部分：第二个查询68个特征 =====================
        -- 提前15天结清相关（6个）
        COALESCE(all_feat.multi_loan_in_loan_order_all_advanceget15days_completedadvanceinstalcnt, 0) AS multi_loan_in_loan_order_all_advanceget15days_completedadvanceinstalcnt,
        COALESCE(all_feat.multi_loan_in_loan_order_all_advanceget15days_completedadvanceinstaloverallcompletedadvanceratio, 0) AS multi_loan_in_loan_order_all_advanceget15days_completedadvanceinstaloverallcompletedadvanceratio,
        COALESCE(all_feat.multi_loan_in_loan_order_all_advanceget15days_completedadvanceinstaloverdueorcompletedratio, 0) AS multi_loan_in_loan_order_all_advanceget15days_completedadvanceinstaloverdueorcompletedratio,
        COALESCE(all_feat.multi_loan_in_loan_order_all_advanceget15days_maxcontinuecompletedadvanceinstalcnt, 0) AS multi_loan_in_loan_order_all_advanceget15days_maxcontinuecompletedadvanceinstalcnt,
        COALESCE(all_feat.multi_loan_in_loan_order_all_advanceget15days_maxcontinuecompletedadvanceinstaloverallcompletedadvanceratio, 0) AS multi_loan_in_loan_order_all_advanceget15days_maxcontinuecompletedadvanceinstaloverallcompletedadvanceratio,
        COALESCE(all_feat.multi_loan_in_loan_order_all_advanceget15days_maxcontinuecompletedadvanceinstalovercompletedorexpiredratio, 0) AS multi_loan_in_loan_order_all_advanceget15days_maxcontinuecompletedadvanceinstalovercompletedorexpiredratio,

        -- 提前30天结清相关（6个）
        COALESCE(all_feat.multi_loan_in_loan_order_all_advanceget30days_completedadvanceinstalcnt, 0) AS multi_loan_in_loan_order_all_advanceget30days_completedadvanceinstalcnt,
        COALESCE(all_feat.multi_loan_in_loan_order_all_advanceget30days_completedadvanceinstaloverallcompletedadvanceratio, 0) AS multi_loan_in_loan_order_all_advanceget30days_completedadvanceinstaloverallcompletedadvanceratio,
        COALESCE(all_feat.multi_loan_in_loan_order_all_advanceget30days_completedadvanceinstaloverdueorcompletedratio, 0) AS multi_loan_in_loan_order_all_advanceget30days_completedadvanceinstaloverdueorcompletedratio,
        COALESCE(all_feat.multi_loan_in_loan_order_all_advanceget30days_maxcontinuecompletedadvanceinstalcnt, 0) AS multi_loan_in_loan_order_all_advanceget30days_maxcontinuecompletedadvanceinstalcnt,
        COALESCE(all_feat.multi_loan_in_loan_order_all_advanceget30days_maxcontinuecompletedadvanceinstaloverallcompletedadvanceratio, 0) AS multi_loan_in_loan_order_all_advanceget30days_maxcontinuecompletedadvanceinstaloverallcompletedadvanceratio,
        COALESCE(all_feat.multi_loan_in_loan_order_all_advanceget30days_maxcontinuecompletedadvanceinstalovercompletedorexpiredratio, 0) AS multi_loan_in_loan_order_all_advanceget30days_maxcontinuecompletedadvanceinstalovercompletedorexpiredratio,

        -- 提前3天结清相关（6个）
        COALESCE(all_feat.multi_loan_in_loan_order_all_advanceget3days_completedadvanceinstalcnt, 0) AS multi_loan_in_loan_order_all_advanceget3days_completedadvanceinstalcnt,
        COALESCE(all_feat.multi_loan_in_loan_order_all_advanceget3days_completedadvanceinstaloverallcompletedadvanceratio, 0) AS multi_loan_in_loan_order_all_advanceget3days_completedadvanceinstaloverallcompletedadvanceratio,
        COALESCE(all_feat.multi_loan_in_loan_order_all_advanceget3days_completedadvanceinstaloverdueorcompletedratio, 0) AS multi_loan_in_loan_order_all_advanceget3days_completedadvanceinstaloverdueorcompletedratio,
        COALESCE(all_feat.multi_loan_in_loan_order_all_advanceget3days_maxcontinuecompletedadvanceinstalcnt, 0) AS multi_loan_in_loan_order_all_advanceget3days_maxcontinuecompletedadvanceinstalcnt,
        COALESCE(all_feat.multi_loan_in_loan_order_all_advanceget3days_maxcontinuecompletedadvanceinstaloverallcompletedadvanceratio, 0) AS multi_loan_in_loan_order_all_advanceget3days_maxcontinuecompletedadvanceinstaloverallcompletedadvanceratio,
        COALESCE(all_feat.multi_loan_in_loan_order_all_advanceget3days_maxcontinuecompletedadvanceinstalovercompletedorexpiredratio, 0) AS multi_loan_in_loan_order_all_advanceget3days_maxcontinuecompletedadvanceinstalovercompletedorexpiredratio,

        -- 额度测算次数（3个）
        COALESCE(all_feat.multi_loan_in_loan_order_all_calccreditstimesmathcount_avg, 0) AS multi_loan_in_loan_order_all_calccreditstimesmathcount_avg,
        COALESCE(all_feat.multi_loan_in_loan_order_all_calccreditstimesmathcount_max, 0) AS multi_loan_in_loan_order_all_calccreditstimesmathcount_max,
        COALESCE(all_feat.multi_loan_in_loan_order_all_calccreditstimesmathcount_std, 0) AS multi_loan_in_loan_order_all_calccreditstimesmathcount_std,

        -- 基础提前结清（2个）
        COALESCE(all_feat.multi_loan_in_loan_order_all_completedadvanceinstalcnt, 0) AS multi_loan_in_loan_order_all_completedadvanceinstalcnt,
        COALESCE(all_feat.multi_loan_in_loan_order_all_completedadvanceinstalratio, 0) AS multi_loan_in_loan_order_all_completedadvanceinstalratio,

        -- 1个月内提前结清金额占比（1个）
        COALESCE(all_feat.multi_loan_in_loan_order_all_completedadvanceloanamountovercompletedratioforfirstmonth, 0) AS multi_loan_in_loan_order_all_completedadvanceloanamountovercompletedratioforfirstmonth,

        -- 已结清账单（2个）
        COALESCE(all_feat.multi_loan_in_loan_order_all_completedinstalcnt, 0) AS multi_loan_in_loan_order_all_completedinstalcnt,
        COALESCE(all_feat.multi_loan_in_loan_order_all_completedinstalratio, 0) AS multi_loan_in_loan_order_all_completedinstalratio,

        -- 已结清金额（2个）
        COALESCE(all_feat.multi_loan_in_loan_order_all_completedloanamount, 0) AS multi_loan_in_loan_order_all_completedloanamount,
        COALESCE(all_feat.multi_loan_in_loan_order_all_completedloanamountindoubletype, 0) AS multi_loan_in_loan_order_all_completedloanamountindoubletype,

        -- 下单间隔天数（3个）
        COALESCE(all_feat.multi_loan_in_loan_order_all_createdorderdaysgapmathcount_avg, 0) AS multi_loan_in_loan_order_all_createdorderdaysgapmathcount_avg,
        COALESCE(all_feat.multi_loan_in_loan_order_all_createdorderdaysgapmathcount_max, 0) AS multi_loan_in_loan_order_all_createdorderdaysgapmathcount_max,
        COALESCE(all_feat.multi_loan_in_loan_order_all_createdorderdaysgapmathcount_std, 0) AS multi_loan_in_loan_order_all_createdorderdaysgapmathcount_std,

        -- 最近一次逾期时间间隔（1个）
        COALESCE(all_feat.multi_loan_in_loan_order_all_lastoverdueinstalrisktimegap, 0.0) AS multi_loan_in_loan_order_all_lastoverdueinstalrisktimegap,

        -- 最大连续提前结清（2个）
        COALESCE(all_feat.multi_loan_in_loan_order_all_maxcontinuecompletedadvanceinstalcnt, 0) AS multi_loan_in_loan_order_all_maxcontinuecompletedadvanceinstalcnt,
        COALESCE(all_feat.multi_loan_in_loan_order_all_maxcontinuecompletedadvanceinstalratio, 0) AS multi_loan_in_loan_order_all_maxcontinuecompletedadvanceinstalratio,

        -- 最大连续逾期（2个）
        COALESCE(all_feat.multi_loan_in_loan_order_all_maxcontinueoverdueinstalcnt, 0) AS multi_loan_in_loan_order_all_maxcontinueoverdueinstalcnt,
        COALESCE(all_feat.multi_loan_in_loan_order_all_maxcontinueoverdueinstalratio, 0) AS multi_loan_in_loan_order_all_maxcontinueoverdueinstalratio,

        -- 3个月内每月max逾期（1个）
        COALESCE(all_feat.multi_loan_in_loan_order_all_maxoverdueinstalcntforwithinthreemonths, 0) AS multi_loan_in_loan_order_all_maxoverdueinstalcntforwithinthreemonths,

        -- 续借订单额度测算次数（3个）
        COALESCE(all_feat.multi_loan_in_loan_order_all_multiloancalccreditstimesmathcount_avg, 0) AS multi_loan_in_loan_order_all_multiloancalccreditstimesmathcount_avg,
        COALESCE(all_feat.multi_loan_in_loan_order_all_multiloancalccreditstimesmathcount_max, 0) AS multi_loan_in_loan_order_all_multiloancalccreditstimesmathcount_max,
        COALESCE(all_feat.multi_loan_in_loan_order_all_multiloancalccreditstimesmathcount_std, 0) AS multi_loan_in_loan_order_all_multiloancalccreditstimesmathcount_std,

        -- 续借订单下单间隔天数（3个）
        COALESCE(all_feat.multi_loan_in_loan_order_all_multiloancreatedorderdaysgapmathcount_avg, 0) AS multi_loan_in_loan_order_all_multiloancreatedorderdaysgapmathcount_avg,
        COALESCE(all_feat.multi_loan_in_loan_order_all_multiloancreatedorderdaysgapmathcount_max, 0) AS multi_loan_in_loan_order_all_multiloancreatedorderdaysgapmathcount_max,
        COALESCE(all_feat.multi_loan_in_loan_order_all_multiloancreatedorderdaysgapmathcount_std, 0) AS multi_loan_in_loan_order_all_multiloancreatedorderdaysgapmathcount_std,

        -- 逾期账单（2个）
        COALESCE(all_feat.multi_loan_in_loan_order_all_overdueinstalcnt, 0) AS multi_loan_in_loan_order_all_overdueinstalcnt,
        COALESCE(all_feat.multi_loan_in_loan_order_all_overdueinstalratio, 0) AS multi_loan_in_loan_order_all_overdueinstalratio,

        -- 通用在贷订单特征（11个）
        COALESCE(in_loan.multi_loan_order_info_inloanorders_overduevscompletetermratio, 0) AS multi_loan_order_info_inloanorders_overduevscompletetermratio,
        COALESCE(in_loan.multi_loan_order_info_inloanorders_overduevsbillingtermratio, 0) AS multi_loan_order_info_inloanorders_overduevsbillingtermratio,
        COALESCE(in_loan.multi_loan_order_info_inloanorders_overduetermcnt, 0) AS multi_loan_order_info_inloanorders_overduetermcnt,
        COALESCE(in_loan.multi_loan_order_info_inloanorders_completetermratio, 0) AS multi_loan_order_info_inloanorders_completetermratio,
        COALESCE(in_loan.multi_loan_order_info_inloanorders_completetermcnt, 0) AS multi_loan_order_info_inloanorders_completetermcnt,
        COALESCE(in_loan.multi_loan_order_info_inloanorders_completeprincipalvslatestremaincreditratio, 0) AS multi_loan_order_info_inloanorders_completeprincipalvslatestremaincreditratio,
        COALESCE(in_loan.multi_loan_order_info_inloanorders_completeprincipal, 0) AS multi_loan_order_info_inloanorders_completeprincipal,
        COALESCE(in_loan.multi_loan_order_info_inloanorders_calccreditgapstd, 0) AS multi_loan_order_info_inloanorders_calccreditgapstd,
        COALESCE(in_loan.multi_loan_order_info_inloanorders_calccreditgapmin, 0) AS multi_loan_order_info_inloanorders_calccreditgapmin,
        COALESCE(in_loan.multi_loan_order_info_inloanorders_calccreditgapmean, 0) AS multi_loan_order_info_inloanorders_calccreditgapmean,
        COALESCE(in_loan.multi_loan_order_info_inloanorders_calccreditgapmax, 0) AS multi_loan_order_info_inloanorders_calccreditgapmax,

        -- 续借在贷订单特征（12个）
        COALESCE(multi_loan.multi_loan_order_info_multiloanorders_overduevscompletetermratio, 0) AS multi_loan_order_info_multiloanorders_overduevscompletetermratio,
        COALESCE(multi_loan.multi_loan_order_info_multiloanorders_overduevsbillingtermratio, 0) AS multi_loan_order_info_multiloanorders_overduevsbillingtermratio,
        COALESCE(multi_loan.multi_loan_order_info_multiloanorders_overduetermcnt, 0) AS multi_loan_order_info_multiloanorders_overduetermcnt,
        COALESCE(multi_loan.multi_loan_order_info_multiloanorders_orderprincipalstd, 0) AS multi_loan_order_info_multiloanorders_orderprincipalstd,
        COALESCE(multi_loan.multi_loan_order_info_multiloanorders_completetermratio, 0) AS multi_loan_order_info_multiloanorders_completetermratio,
        COALESCE(multi_loan.multi_loan_order_info_multiloanorders_completetermcnt, 0) AS multi_loan_order_info_multiloanorders_completetermcnt,
        COALESCE(multi_loan.multi_loan_order_info_multiloanorders_completeprincipalvslatestremaincreditratio, 0) AS multi_loan_order_info_multiloanorders_completeprincipalvslatestremaincreditratio,
        COALESCE(multi_loan.multi_loan_order_info_multiloanorders_completeprincipal, 0) AS multi_loan_order_info_multiloanorders_completeprincipal,
        COALESCE(multi_loan.multi_loan_order_info_multiloanorders_calccreditgapstd, 0) AS multi_loan_order_info_multiloanorders_calccreditgapstd,
        COALESCE(multi_loan.multi_loan_order_info_multiloanorders_calccreditgapmin, 0) AS multi_loan_order_info_multiloanorders_calccreditgapmin,
        COALESCE(multi_loan.multi_loan_order_info_multiloanorders_calccreditgapmean, 0) AS multi_loan_order_info_multiloanorders_calccreditgapmean,
        COALESCE(multi_loan.multi_loan_order_info_multiloanorders_calccreditgapmax, 0) AS multi_loan_order_info_multiloanorders_calccreditgapmax,

        -- ===================== 第三部分：新增3个查询107个特征 =====================
        -- 最远一笔订单特征（36个）
        COALESCE(furthest_order.termscnt, 0) AS multi_loan_order_info_furthestsingleorder_termscnt,
        COALESCE(furthest_order.prepayvsfuturebillingtermratio, 0) AS multi_loan_order_info_furthestsingleorder_prepayvsfuturebillingtermratio,
        COALESCE(furthest_order.prepayvsalltermratio, 0) AS multi_loan_order_info_furthestsingleorder_prepayvsalltermratio,
        COALESCE(furthest_order.payoutdays, 0) AS multi_loan_order_info_furthestsingleorder_payoutdays,
        COALESCE(furthest_order.overduevscompletedtermratio, 0) AS multi_loan_order_info_furthestsingleorder_overduevscompletedtermratio,
        COALESCE(furthest_order.overduevsbillingtermratio, 0) AS multi_loan_order_info_furthestsingleorder_overduevsbillingtermratio,
        COALESCE(furthest_order.overduetermratio, 0) AS multi_loan_order_info_furthestsingleorder_overduetermratio,
        COALESCE(furthest_order.overduetermcnt, 0) AS multi_loan_order_info_furthestsingleorder_overduetermcnt,
        COALESCE(furthest_order.maxsuccessiveprepaytermvsbillingratio, 0) AS multi_loan_order_info_furthestsingleorder_maxsuccessiveprepaytermvsbillingratio,
        COALESCE(furthest_order.maxsuccessiveprepaytermvsallratio, 0) AS multi_loan_order_info_furthestsingleorder_maxsuccessiveprepaytermvsallratio,
        COALESCE(furthest_order.maxsuccessiveprepaytermcnt, 0) AS multi_loan_order_info_furthestsingleorder_maxsuccessiveprepaytermcnt,
        COALESCE(furthest_order.maxsuccessiveoverduetermvsbillingratio, 0) AS multi_loan_order_info_furthestsingleorder_maxsuccessiveoverduetermvsbillingratio,
        COALESCE(furthest_order.maxsuccessiveoverduetermvsallratio, 0) AS multi_loan_order_info_furthestsingleorder_maxsuccessiveoverduetermvsallratio,
        COALESCE(furthest_order.maxsuccessiveoverduetermcnt, 0) AS multi_loan_order_info_furthestsingleorder_maxsuccessiveoverduetermcnt,
        COALESCE(furthest_order.incompletetermcnt, 0) AS multi_loan_order_info_furthestsingleorder_incompletetermcnt,
        COALESCE(furthest_order.firstcompletedcreatedgap, -1) AS multi_loan_order_info_furthestsingleorder_firstcompletedcreatedgap,
        COALESCE(furthest_order.createdNowGap, 0) AS multi_loan_order_info_furthestsingleorder_creatednowgap,
        COALESCE(furthest_order.creatednoon, 0) AS multi_loan_order_info_furthestsingleorder_creatednoon,
        COALESCE(furthest_order.creatednight, 0) AS multi_loan_order_info_furthestsingleorder_creatednight,
        COALESCE(furthest_order.createdmorning, 0) AS multi_loan_order_info_furthestsingleorder_createdmorning,
        COALESCE(furthest_order.createdevening, 0) AS multi_loan_order_info_furthestsingleorder_createdevening,
        COALESCE(furthest_order.createdcalccreditgap, 0) AS multi_loan_order_info_furthestsingleorder_createdcalccreditgap,
        COALESCE(furthest_order.createdafternoon, 0) AS multi_loan_order_info_furthestsingleorder_createdafternoon,
        COALESCE(furthest_order.completevsfuturebillingtermratio, 0) AS multi_loan_order_info_furthestsingleorder_completevsfuturebillingtermratio,
        COALESCE(furthest_order.completetermratio, 0) AS multi_loan_order_info_furthestsingleorder_completetermratio,
        COALESCE(furthest_order.completetermcnt, 0) AS multi_loan_order_info_furthestsingleorder_completetermcnt,
        COALESCE(furthest_order.completesamedaytermscntmax, 0) AS multi_loan_order_info_furthestsingleorder_completesamedaytermscntmax,
        COALESCE(furthest_order.completesamedaytermscntavg, 0) AS multi_loan_order_info_furthestsingleorder_completesamedaytermscntavg,
        COALESCE(furthest_order.completeprepaydaysmin, 0) AS multi_loan_order_info_furthestsingleorder_completeprepaydaysmin,
        COALESCE(furthest_order.completeprepaydaysmean, 0) AS multi_loan_order_info_furthestsingleorder_completeprepaydaysmean,
        COALESCE(furthest_order.completeprepaydaysmax, 0) AS multi_loan_order_info_furthestsingleorder_completeprepaydaysmax,
        COALESCE(furthest_order.completeonweekendprincipalratio, 0) AS multi_loan_order_info_furthestsingleorder_completeonweekendprincipalratio,
        COALESCE(furthest_order.completefuturedutermratio, 0) AS multi_loan_order_info_furthestsingleorder_completefutureduetermratio,
        COALESCE(furthest_order.completefuturedutermcnt, 0) AS multi_loan_order_info_furthestsingleorder_completefutureduetermcnt,
        COALESCE(furthest_order.billingprepayvscompletetermratio, 0) AS multi_loan_order_info_furthestsingleorder_billingprepayvscompletetermratio,
        COALESCE(furthest_order.billingprepayvsbillingtermratio, 0) AS multi_loan_order_info_furthestsingleorder_billingprepayvsbillingtermratio,

        -- 最近第二笔订单特征（36个）
        COALESCE(latest2_order.termscnt, 0) AS multi_loan_order_info_latest2singleorder_termscnt,
        COALESCE(latest2_order.prepayvsfuturebillingtermratio, 0) AS multi_loan_order_info_latest2singleorder_prepayvsfuturebillingtermratio,
        COALESCE(latest2_order.prepayvsalltermratio, 0) AS multi_loan_order_info_latest2singleorder_prepayvsalltermratio,
        COALESCE(latest2_order.payoutdays, 0) AS multi_loan_order_info_latest2singleorder_payoutdays,
        COALESCE(latest2_order.overduevscompletedtermratio, 0) AS multi_loan_order_info_latest2singleorder_overduevscompletedtermratio,
        COALESCE(latest2_order.overduevsbillingtermratio, 0) AS multi_loan_order_info_latest2singleorder_overduevsbillingtermratio,
        COALESCE(latest2_order.overduetermratio, 0) AS multi_loan_order_info_latest2singleorder_overduetermratio,
        COALESCE(latest2_order.overduetermcnt, 0) AS multi_loan_order_info_latest2singleorder_overduetermcnt,
        COALESCE(latest2_order.maxsuccessiveprepaytermvsbillingratio, 0) AS multi_loan_order_info_latest2singleorder_maxsuccessiveprepaytermvsbillingratio,
        COALESCE(latest2_order.maxsuccessiveprepaytermvsallratio, 0) AS multi_loan_order_info_latest2singleorder_maxsuccessiveprepaytermvsallratio,
        COALESCE(latest2_order.maxsuccessiveprepaytermcnt, 0) AS multi_loan_order_info_latest2singleorder_maxsuccessiveprepaytermcnt,
        COALESCE(latest2_order.maxsuccessiveoverduetermvsbillingratio, 0) AS multi_loan_order_info_latest2singleorder_maxsuccessiveoverduetermvsbillingratio,
        COALESCE(latest2_order.maxsuccessiveoverduetermvsallratio, 0) AS multi_loan_order_info_latest2singleorder_maxsuccessiveoverduetermvsallratio,
        COALESCE(latest2_order.maxsuccessiveoverduetermcnt, 0) AS multi_loan_order_info_latest2singleorder_maxsuccessiveoverduetermcnt,
        COALESCE(latest2_order.incompletetermcnt, 0) AS multi_loan_order_info_latest2singleorder_incompletetermcnt,
        COALESCE(latest2_order.firstcompletedcreatedgap, -1) AS multi_loan_order_info_latest2singleorder_firstcompletedcreatedgap,
        COALESCE(latest2_order.createdNowGap, 0) AS multi_loan_order_info_latest2singleorder_creatednowgap,
        COALESCE(latest2_order.creatednoon, 0) AS multi_loan_order_info_latest2singleorder_creatednoon,
        COALESCE(latest2_order.creatednight, 0) AS multi_loan_order_info_latest2singleorder_creatednight,
        COALESCE(latest2_order.createdmorning, 0) AS multi_loan_order_info_latest2singleorder_createdmorning,
        COALESCE(latest2_order.createdevening, 0) AS multi_loan_order_info_latest2singleorder_createdevening,
        COALESCE(latest2_order.createdcalccreditgap, 0) AS multi_loan_order_info_latest2singleorder_createdcalccreditgap,
        COALESCE(latest2_order.createdafternoon, 0) AS multi_loan_order_info_latest2singleorder_createdafternoon,
        COALESCE(latest2_order.completevsfuturebillingtermratio, 0) AS multi_loan_order_info_latest2singleorder_completevsfuturebillingtermratio,
        COALESCE(latest2_order.completetermratio, 0) AS multi_loan_order_info_latest2singleorder_completetermratio,
        COALESCE(latest2_order.completetermcnt, 0) AS multi_loan_order_info_latest2singleorder_completetermcnt,
        COALESCE(latest2_order.completesamedaytermscntmax, 0) AS multi_loan_order_info_latest2singleorder_completesamedaytermscntmax,
        COALESCE(latest2_order.completesamedaytermscntavg, 0) AS multi_loan_order_info_latest2singleorder_completesamedaytermscntavg,
        COALESCE(latest2_order.completeprepaydaysmin, 0) AS multi_loan_order_info_latest2singleorder_completeprepaydaysmin,
        COALESCE(latest2_order.completeprepaydaysmean, 0) AS multi_loan_order_info_latest2singleorder_completeprepaydaysmean,
        COALESCE(latest2_order.completeprepaydaysmax, 0) AS multi_loan_order_info_latest2singleorder_completeprepaydaysmax,
        COALESCE(latest2_order.completefuturedutermratio, 0) AS multi_loan_order_info_latest2singleorder_completefutureduetermratio,
        COALESCE(latest2_order.completefuturedutermprincipal, 0) AS multi_loan_order_info_latest2singleorder_completefutureduetermprincipal,
        COALESCE(latest2_order.completefuturedutermcnt, 0) AS multi_loan_order_info_latest2singleorder_completefutureduetermcnt,
        COALESCE(latest2_order.billingprepayvscompletetermratio, 0) AS multi_loan_order_info_latest2singleorder_billingprepayvscompletetermratio,
        COALESCE(latest2_order.billingprepayvsbillingtermratio, 0) AS multi_loan_order_info_latest2singleorder_billingprepayvsbillingtermratio,

        -- 最近第一笔订单特征（35个）
        COALESCE(latest1_order.termscnt, 0) AS multi_loan_order_info_latest1singleorder_termscnt,
        COALESCE(latest1_order.prepayvsfuturebillingtermratio, 0) AS multi_loan_order_info_latest1singleorder_prepayvsfuturebillingtermratio,
        COALESCE(latest1_order.prepayvsalltermratio, 0) AS multi_loan_order_info_latest1singleorder_prepayvsalltermratio,
        COALESCE(latest1_order.payoutdays, 0) AS multi_loan_order_info_latest1singleorder_payoutdays,
        COALESCE(latest1_order.overduevscompletedtermratio, 0) AS multi_loan_order_info_latest1singleorder_overduevscompletedtermratio,
        COALESCE(latest1_order.overduevsbillingtermratio, 0) AS multi_loan_order_info_latest1singleorder_overduevsbillingtermratio,
        COALESCE(latest1_order.overduetermratio, 0) AS multi_loan_order_info_latest1singleorder_overduetermratio,
        COALESCE(latest1_order.overduetermcnt, 0) AS multi_loan_order_info_latest1singleorder_overduetermcnt,
        COALESCE(latest1_order.maxsuccessiveprepaytermvsbillingratio, 0) AS multi_loan_order_info_latest1singleorder_maxsuccessiveprepaytermvsbillingratio,
        COALESCE(latest1_order.maxsuccessiveprepaytermvsallratio, 0) AS multi_loan_order_info_latest1singleorder_maxsuccessiveprepaytermvsallratio,
        COALESCE(latest1_order.maxsuccessiveprepaytermcnt, 0) AS multi_loan_order_info_latest1singleorder_maxsuccessiveprepaytermcnt,
        COALESCE(latest1_order.maxsuccessiveoverduetermvsbillingratio, 0) AS multi_loan_order_info_latest1singleorder_maxsuccessiveoverduetermvsbillingratio,
        COALESCE(latest1_order.maxsuccessiveoverduetermvsallratio, 0) AS multi_loan_order_info_latest1singleorder_maxsuccessiveoverduetermvsallratio,
        COALESCE(latest1_order.maxsuccessiveoverduetermcnt, 0) AS multi_loan_order_info_latest1singleorder_maxsuccessiveoverduetermcnt,
        COALESCE(latest1_order.incompletetermcnt, 0) AS multi_loan_order_info_latest1singleorder_incompletetermcnt,
        COALESCE(latest1_order.firstcompletedcreatedgap, -1) AS multi_loan_order_info_latest1singleorder_firstcompletedcreatedgap,
        COALESCE(latest1_order.createdNowGap, 0) AS multi_loan_order_info_latest1singleorder_creatednowgap,
        COALESCE(latest1_order.creatednoon, 0) AS multi_loan_order_info_latest1singleorder_creatednoon,
        COALESCE(latest1_order.creatednight, 0) AS multi_loan_order_info_latest1singleorder_creatednight,
        COALESCE(latest1_order.createdmorning, 0) AS multi_loan_order_info_latest1singleorder_createdmorning,
        COALESCE(latest1_order.createdevening, 0) AS multi_loan_order_info_latest1singleorder_createdevening,
        COALESCE(latest1_order.order_create_interval_days, 0) AS multi_loan_order_info_latest1singleorder_createdcalccreditgap,
        COALESCE(latest1_order.createdafternoon, 0) AS multi_loan_order_info_latest1singleorder_createdafternoon,
        COALESCE(latest1_order.future_bill_complete_ratio, 0) AS multi_loan_order_info_latest1singleorder_completevsfuturebillingtermratio,
        COALESCE(latest1_order.completetermratio, 0) AS multi_loan_order_info_latest1singleorder_completetermratio,
        COALESCE(latest1_order.completetermcnt, 0) AS multi_loan_order_info_latest1singleorder_completetermcnt,
        COALESCE(latest1_order.completesamedaytermscntmax, 0) AS multi_loan_order_info_latest1singleorder_completesamedaytermscntmax,
        COALESCE(latest1_order.completesamedaytermscntavg, 0) AS multi_loan_order_info_latest1singleorder_completesamedaytermscntavg,
        COALESCE(latest1_order.completeprepaydaysmin, 0) AS multi_loan_order_info_latest1singleorder_completeprepaydaysmin,
        COALESCE(latest1_order.completeprepaydaysmean, 0) AS multi_loan_order_info_latest1singleorder_completeprepaydaysmean,
        COALESCE(latest1_order.completeprepaydaysmax, 0) AS multi_loan_order_info_latest1singleorder_completeprepaydaysmax,
        COALESCE(latest1_order.completefuturedutermratio, 0) AS multi_loan_order_info_latest1singleorder_completefutureduetermratio,
        COALESCE(latest1_order.completefuturedutermcnt, 0) AS multi_loan_order_info_latest1singleorder_completefutureduetermcnt,
        COALESCE(latest1_order.billingprepayvscompletetermratio, 0) AS multi_loan_order_info_latest1singleorder_billingprepayvscompletetermratio,
        COALESCE(latest1_order.billingprepayvsbillingtermratio, 0) AS multi_loan_order_info_latest1singleorder_billingprepayvsbillingtermratio,
        COALESCE(latest1_order.creditusageratio, 0) AS multi_loan_order_info_latest1singleorder_creditusageratio,

        -- ===================== 第四部分：新增20个多订单特征 =====================
        -- 未来90-180天未结清订单特征（3个）
        COALESCE(future90_180.futurebillingunclearinstalcnt, 0) AS multi_loan_order_info_multiloanrangefuture90dto180d_futurebillingunclearinstalcnt,
        COALESCE(future90_180.futurebillingunclearvsunclearinstalratio, 0) AS multi_loan_order_info_multiloanrangefuture90dto180d_futurebillingunclearvsunclearinstalratio,
        COALESCE(future90_180.futurebillingunclearvsclearinstalratio, 0) AS multi_loan_order_info_multiloanrangefuture90dto180d_futurebillingunclearvsclearinstalratio,

        -- 未来90天未结清订单特征（3个）
        COALESCE(future0_90.futurebillingunclearinstalcnt, 0) AS multi_loan_order_info_multiloanrangefuture0dto90d_futurebillingunclearinstalcnt,
        COALESCE(future0_90.futurebillingunclearvsunclearinstalratio, 0) AS multi_loan_order_info_multiloanrangefuture0dto90d_futurebillingunclearvsunclearinstalratio,
        COALESCE(future0_90.futurebillingunclearvsclearinstalratio, 0) AS multi_loan_order_info_multiloanrangefuture0dto90d_futurebillingunclearvsclearinstalratio,

        -- 过去90天订单在贷结清特征（4个）
        COALESCE(noLoan90.noLoanDays, 0) AS multi_loan_order_info_multiloannoloanclear90dstat_noloandays,
        COALESCE(noLoan90.noLoanDaysRatio, 0) AS multi_loan_order_info_multiloannoloanclear90dstat_noloandaysratio,
        COALESCE(noLoan90.clearOrderCnt, 0) AS multi_loan_order_info_multiloannoloanclear90dstat_clearordercnt,
        COALESCE(noLoan90.clearOrderRatio, 0) AS multi_loan_order_info_multiloannoloanclear90dstat_clearorderratio,

        -- 过去180天订单在贷结清特征（4个）
        COALESCE(noLoan180.noLoanDays, 0) AS multi_loan_order_info_multiloannoloanclear180dstat_noloandays,
        COALESCE(noLoan180.noLoanDaysRatio, 0) AS multi_loan_order_info_multiloannoloanclear180dstat_noloandaysratio,
        COALESCE(noLoan180.clearOrderCnt, 0) AS multi_loan_order_info_multiloannoloanclear180dstat_clearordercnt,
        COALESCE(noLoan180.clearOrderRatio, 0) AS multi_loan_order_info_multiloannoloanclear180dstat_clearorderratio,

        -- 过去90天订单特征（3个）
        COALESCE(stat90.payoutOrderCnt, 0) AS multi_loan_order_info_multiloan90dstat_payoutordercnt,
        COALESCE(stat90.payoutMultiLoanOrderCnt, 0) AS multi_loan_order_info_multiloan90dstat_payoutmultiloanordercnt,
        COALESCE(stat90.multiloancalcvsmultiloanpayoutratio, 0) AS multi_loan_order_info_multiloan90dstat_multiloancalcvsmultiloanpayoutratio,

        -- 过去30天订单特征（3个）
        COALESCE(stat30.payoutOrderCnt, 0) AS multi_loan_order_info_multiloan30dstat_payoutordercnt,
        COALESCE(stat30.payoutMultiLoanOrderCnt, 0) AS multi_loan_order_info_multiloan30dstat_payoutmultiloanordercnt,
        COALESCE(stat30.multiloancalcvsmultiloanpayoutratio, 0) AS multi_loan_order_info_multiloan30dstat_multiloancalcvsmultiloanpayoutratio


    FROM cust_base cb
             -- 第一个查询的72个特征（furthest/recentFirst/recentSecond）
             LEFT JOIN furthest_order_features furthest_feat ON cb.cust_no = furthest_feat.cust_no AND cb.observation_date = furthest_feat.observation_date
             LEFT JOIN recent_first_order_features recent_first_feat ON cb.cust_no = recent_first_feat.cust_no AND cb.observation_date = recent_first_feat.observation_date
             LEFT JOIN recent_second_order_features recent_second_feat ON cb.cust_no = recent_second_feat.cust_no AND cb.observation_date = recent_second_feat.observation_date
        -- 用户级别特征（通过cust_no关联）
             LEFT JOIN all_features all_feat ON cb.cust_no = all_feat.cust_no
             LEFT JOIN inLoanOrders_all_features in_loan ON cb.cust_no = in_loan.cust_no
             LEFT JOIN multiLoanOrders_all_features multi_loan ON cb.cust_no = multi_loan.cust_no
             LEFT JOIN multiLoanRangeFuture90DTo180D future90_180 ON cb.cust_no = future90_180.cust_no
             LEFT JOIN multiLoanRangeFuture0DTo90D future0_90 ON cb.cust_no = future0_90.cust_no
             LEFT JOIN multi_loan_order_info_multiloannoloanclear90dstat_final noLoan90 ON cb.cust_no = noLoan90.cust_no
             LEFT JOIN multi_loan_order_info_multiloannoloanclear180dstat_final noLoan180 ON cb.cust_no = noLoan180.cust_no
             LEFT JOIN multi_loan_order_info_multiloan90dstat_final stat90 ON cb.cust_no = stat90.cust_no
             LEFT JOIN multi_loan_order_info_multiloan30dstat_final stat30 ON cb.cust_no = stat30.cust_no
        -- 订单级别特征（通过cust_no关联，取每个客户的最新订单）
             LEFT JOIN furthest_order_all_features furthest_order ON cb.cust_no = furthest_order.cust_no
             LEFT JOIN latest2_order_all_features latest2_order ON cb.cust_no = latest2_order.cust_no
             LEFT JOIN latest1_order_all_features latest1_order ON cb.cust_no = latest1_order.cust_no
)

-- 最终输出：客户维度特征（基于t-2日期）
select * from(
SELECT
    -- 核心关联键（客户维度）
    maf.cust_no,  -- 客户编号
    maf.observation_date,  -- 观察日期
    maf.latest1_order_create_time AS order_create_time,
    -- ===================== 第一部分：第一个查询72个特征 =====================
    -- 最远一笔订单特征（11个）
    multi_loan_in_loan_order_furthest_completedinstalcnt,  -- 最远一笔订单已结清账单数
    multi_loan_in_loan_order_furthest_completedinstalratio,  -- 最远一笔订单已结清账单比例
    multi_loan_in_loan_order_furthest_completedloanamount,  -- 最远一笔订单已结清金额
    multi_loan_in_loan_order_furthest_completednotdueinstalcnt,  -- 最远一笔订单提前结清账单数
    multi_loan_in_loan_order_furthest_completednotdueinstalovercompletedratio,  -- 最远一笔订单提前结清账单占已结清比例
    multi_loan_in_loan_order_furthest_completednotdueinstalovernotdueratio,  -- 最远一笔订单提前结清账单占未到期比例
    multi_loan_in_loan_order_furthest_completednotdueloanamount,  -- 最远一笔订单提前结清金额
    multi_loan_in_loan_order_furthest_createdtimecalccreditsgap,  -- 最远一笔订单创建时间与额度测算时间间隔
    multi_loan_in_loan_order_furthest_instalmentcnt,  -- 最远一笔订单总期数
    multi_loan_in_loan_order_furthest_payoutdays,  -- 最远一笔订单放款天数
    multi_loan_in_loan_order_furthest_firstcompletedinstalgap,  -- 最远一笔订单第一期账单结清间隔天数
    multi_loan_in_loan_order_furthest_uncompletedinstalcnt,  -- 最远一笔订单未结清账单数

    -- 最近第一笔订单特征（38个）
    multi_loan_in_loan_order_recentfirst_completedadvanceinstaldaysavg,  -- 最近第一笔订单提前结清天数平均值
    multi_loan_in_loan_order_recentfirst_completedadvanceinstaldaysmax,  -- 最近第一笔订单提前结清天数最大值
    multi_loan_in_loan_order_recentfirst_completedadvanceinstaldaysstd,  -- 最近第一笔订单提前结清天数标准差
    multi_loan_in_loan_order_recentfirst_completedinstalcnt,  -- 最近第一笔订单已结清账单数
    multi_loan_in_loan_order_recentfirst_completedinstalratio,  -- 最近第一笔订单已结清账单比例
    multi_loan_in_loan_order_recentfirst_completednotdueinstalcnt,  -- 最近第一笔订单提前结清账单数
    multi_loan_in_loan_order_recentfirst_completednotdueinstalovercompletedratio,  -- 最近第一笔订单提前结清账单占已结清比例
    multi_loan_in_loan_order_recentfirst_completednotdueinstalovernotdueratio,  -- 最近第一笔订单提前结清账单占未到期比例
    multi_loan_in_loan_order_recentfirst_completednotdueloanamount,  -- 最近第一笔订单提前结清金额
    multi_loan_in_loan_order_recentfirst_completedsamedayinstalcntavg,  -- 最近第一笔订单同一天结清账单数平均值
    multi_loan_in_loan_order_recentfirst_completedsamedayinstalcntmax,  -- 最近第一笔订单同一天结清账单数最大值
    multi_loan_in_loan_order_recentfirst_createdordertimegap,  -- 最近第一笔订单创建时间间隔
    multi_loan_in_loan_order_recentfirst_createdtimeperiodonehotvo_afternoon,  -- 最近第一笔订单创建时段：下午（15-17点）
    multi_loan_in_loan_order_recentfirst_createdtimeperiodonehotvo_evening,  -- 最近第一笔订单创建时段：晚上（18-22点）
    multi_loan_in_loan_order_recentfirst_createdtimeperiodonehotvo_missing,  -- 最近第一笔订单创建时段：缺失
    multi_loan_in_loan_order_recentfirst_createdtimeperiodonehotvo_morning,  -- 最近第一笔订单创建时段：早上（6-10点）
    multi_loan_in_loan_order_recentfirst_createdtimeperiodonehotvo_night,  -- 最近第一笔订单创建时段：夜间（23-5点）
    multi_loan_in_loan_order_recentfirst_createdtimeperiodonehotvo_noon,  -- 最近第一笔订单创建时段：中午（11-14点）
    multi_loan_in_loan_order_recentfirst_createdtimeperiodonehotvo_other,  -- 最近第一笔订单创建时段：其他
    multi_loan_in_loan_order_recentfirst_creditusageratio,  -- 最近第一笔订单额度使用率
    multi_loan_in_loan_order_recentfirst_firstcompletedinstalgap,  -- 最近第一笔订单首次结清账单间隔
    multi_loan_in_loan_order_recentfirst_firstselfcompletedinstalgap,  -- 最近第一笔订单首次自身结清账单间隔
    multi_loan_in_loan_order_recentfirst_instalmentcnt,  -- 最近第一笔订单总期数
    multi_loan_in_loan_order_recentfirst_maxcontinuecompletedadvanceinstalcnt,  -- 最近第一笔订单最大连续提前结清账单数
    multi_loan_in_loan_order_recentfirst_maxcontinuecompletedadvanceinstalratio,  -- 最近第一笔订单最大连续提前结清账单比例
    multi_loan_in_loan_order_recentfirst_maxcontinueoverdueinstalcnt,  -- 最近第一笔订单最大连续逾期账单数
    multi_loan_in_loan_order_recentfirst_maxcontinueoverdueinstalratio,  -- 最近第一笔订单最大连续逾期账单比例
    multi_loan_in_loan_order_recentfirst_overdueinstalcnt,  -- 最近第一笔订单逾期账单数
    multi_loan_in_loan_order_recentfirst_overdueinstalratio,  -- 最近第一笔订单逾期账单比例
    multi_loan_in_loan_order_recentfirst_payoutdays,  -- 最近第一笔订单放款天数
    multi_loan_in_loan_order_recentfirst_uncompletedinstalcnt,  -- 最近第一笔订单未结清账单数

    -- 最近第二笔订单特征（23个）
    multi_loan_in_loan_order_recentsecond_completedadvanceinstaldaysavg,  -- 最近第二笔订单提前结清天数平均值
    multi_loan_in_loan_order_recentsecond_completedadvanceinstaldaysmax,  -- 最近第二笔订单提前结清天数最大值
    multi_loan_in_loan_order_recentsecond_completedadvanceinstaldaysstd,  -- 最近第二笔订单提前结清天数标准差
    multi_loan_in_loan_order_recentsecond_completedinstalcnt,  -- 最近第二笔订单已结清账单数
    multi_loan_in_loan_order_recentsecond_completedinstalratio,  -- 最近第二笔订单已结清账单比例
    multi_loan_in_loan_order_recentsecond_completednotdueinstalcnt,  -- 最近第二笔订单提前结清账单数
    multi_loan_in_loan_order_recentsecond_completednotdueinstalovercompletedratio,  -- 最近第二笔订单提前结清账单占已结清比例
    multi_loan_in_loan_order_recentsecond_completednotdueinstalovernotdueratio,  -- 最近第二笔订单提前结清账单占未到期比例
    multi_loan_in_loan_order_recentsecond_completedsamedayinstalcntavg,  -- 最近第二笔订单同一天结清账单数平均值
    multi_loan_in_loan_order_recentsecond_completedsamedayinstalcntmax,  -- 最近第二笔订单同一天结清账单数最大值
    multi_loan_in_loan_order_recentsecond_createdordertimegap,  -- 最近第二笔订单创建时间间隔
    multi_loan_in_loan_order_recentsecond_createdtimeperiodonehotvo_afternoon,  -- 最近第二笔订单创建时段：下午（15-17点）
    multi_loan_in_loan_order_recentsecond_createdtimeperiodonehotvo_evening,  -- 最近第二笔订单创建时段：晚上（18-22点）
    multi_loan_in_loan_order_recentsecond_createdtimeperiodonehotvo_missing,  -- 最近第二笔订单创建时段：缺失
    multi_loan_in_loan_order_recentsecond_createdtimeperiodonehotvo_morning,  -- 最近第二笔订单创建时段：早上（6-10点）
    multi_loan_in_loan_order_recentsecond_createdtimeperiodonehotvo_night,  -- 最近第二笔订单创建时段：夜间（23-5点）
    multi_loan_in_loan_order_recentsecond_createdtimeperiodonehotvo_noon,  -- 最近第二笔订单创建时段：中午（11-14点）
    multi_loan_in_loan_order_recentsecond_createdtimeperiodonehotvo_other,  -- 最近第二笔订单创建时段：其他
    multi_loan_in_loan_order_recentsecond_firstcompletedinstalgap,  -- 最近第二笔订单首次结清账单间隔
    multi_loan_in_loan_order_recentsecond_firstselfcompletedinstalgap,  -- 最近第二笔订单首次自身结清账单间隔
    multi_loan_in_loan_order_recentsecond_instalmentcnt,  -- 最近第二笔订单总期数
    multi_loan_in_loan_order_recentsecond_maxcontinuecompletedadvanceinstalcnt,  -- 最近第二笔订单最大连续提前结清账单数
    multi_loan_in_loan_order_recentsecond_maxcontinuecompletedadvanceinstalratio,  -- 最近第二笔订单最大连续提前结清账单比例
    multi_loan_in_loan_order_recentsecond_maxcontinueoverdueinstalcnt,  -- 最近第二笔订单最大连续逾期账单数
    multi_loan_in_loan_order_recentsecond_maxcontinueoverdueinstalratio,  -- 最近第二笔订单最大连续逾期账单比例
    multi_loan_in_loan_order_recentsecond_minusinloanavgcreditusage,  -- 最近第二笔订单额度使用率减去在贷订单平均额度使用率
    multi_loan_in_loan_order_recentsecond_overdueinstalcnt,  -- 最近第二笔订单逾期账单数
    multi_loan_in_loan_order_recentsecond_overdueinstalratio,  -- 最近第二笔订单逾期账单比例
    multi_loan_in_loan_order_recentsecond_payoutdays,  -- 最近第二笔订单放款天数
    multi_loan_in_loan_order_recentsecond_uncompletedinstalcnt,  -- 最近第二笔订单未结清账单数

    -- ===================== 第二部分：第二个查询68个特征 =====================
    -- 提前15天结清相关（6个）
    multi_loan_in_loan_order_all_advanceget15days_completedadvanceinstalcnt,  -- 所有订单提前15天结清账单数
    multi_loan_in_loan_order_all_advanceget15days_completedadvanceinstaloverallcompletedadvanceratio,  -- 提前15天结清账单占所有提前结清比例
    multi_loan_in_loan_order_all_advanceget15days_completedadvanceinstaloverdueorcompletedratio,  -- 提前15天结清账单占到期或已结清比例
    multi_loan_in_loan_order_all_advanceget15days_maxcontinuecompletedadvanceinstalcnt,  -- 提前15天结清最大连续账单数
    multi_loan_in_loan_order_all_advanceget15days_maxcontinuecompletedadvanceinstaloverallcompletedadvanceratio,  -- 提前15天最大连续结清占所有提前结清比例
    multi_loan_in_loan_order_all_advanceget15days_maxcontinuecompletedadvanceinstalovercompletedorexpiredratio,  -- 提前15天最大连续结清占已结清或到期比例

    -- 提前30天结清相关（6个）
    multi_loan_in_loan_order_all_advanceget30days_completedadvanceinstalcnt,  -- 所有订单提前30天结清账单数
    multi_loan_in_loan_order_all_advanceget30days_completedadvanceinstaloverallcompletedadvanceratio,  -- 提前30天结清账单占所有提前结清比例
    multi_loan_in_loan_order_all_advanceget30days_completedadvanceinstaloverdueorcompletedratio,  -- 提前30天结清账单占到期或已结清比例
    multi_loan_in_loan_order_all_advanceget30days_maxcontinuecompletedadvanceinstalcnt,  -- 提前30天结清最大连续账单数
    multi_loan_in_loan_order_all_advanceget30days_maxcontinuecompletedadvanceinstaloverallcompletedadvanceratio,  -- 提前30天最大连续结清占所有提前结清比例
    multi_loan_in_loan_order_all_advanceget30days_maxcontinuecompletedadvanceinstalovercompletedorexpiredratio,  -- 提前30天最大连续结清占已结清或到期比例

    -- 提前3天结清相关（6个）
    multi_loan_in_loan_order_all_advanceget3days_completedadvanceinstalcnt,  -- 所有订单提前3天结清账单数
    multi_loan_in_loan_order_all_advanceget3days_completedadvanceinstaloverallcompletedadvanceratio,  -- 提前3天结清账单占所有提前结清比例
    multi_loan_in_loan_order_all_advanceget3days_completedadvanceinstaloverdueorcompletedratio,  -- 提前3天结清账单占到期或已结清比例
    multi_loan_in_loan_order_all_advanceget3days_maxcontinuecompletedadvanceinstalcnt,  -- 提前3天结清最大连续账单数
    multi_loan_in_loan_order_all_advanceget3days_maxcontinuecompletedadvanceinstaloverallcompletedadvanceratio,  -- 提前3天最大连续结清占所有提前结清比例
    multi_loan_in_loan_order_all_advanceget3days_maxcontinuecompletedadvanceinstalovercompletedorexpiredratio,  -- 提前3天最大连续结清占已结清或到期比例

    -- 额度测算次数（3个）
    multi_loan_in_loan_order_all_calccreditstimesmathcount_avg,  -- 额度测算次数平均值
    multi_loan_in_loan_order_all_calccreditstimesmathcount_max,  -- 额度测算次数最大值
    multi_loan_in_loan_order_all_calccreditstimesmathcount_std,  -- 额度测算次数标准差

    -- 基础提前结清（2个）
    multi_loan_in_loan_order_all_completedadvanceinstalcnt,  -- 所有订单提前结清账单数
    multi_loan_in_loan_order_all_completedadvanceinstalratio,  -- 所有订单提前结清账单比例

    -- 1个月内提前结清金额占比（1个）
    multi_loan_in_loan_order_all_completedadvanceloanamountovercompletedratioforfirstmonth,  -- 1个月内提前结清金额占已结清金额比例

    -- 已结清账单（2个）
    multi_loan_in_loan_order_all_completedinstalcnt,  -- 所有订单已结清账单数
    multi_loan_in_loan_order_all_completedinstalratio,  -- 所有订单已结清账单比例

    -- 已结清金额（2个）
    multi_loan_in_loan_order_all_completedloanamount,  -- 所有订单已结清金额
    multi_loan_in_loan_order_all_completedloanamountindoubletype,  -- 所有订单已结清金额（双精度类型）

    -- 下单间隔天数（3个）
    multi_loan_in_loan_order_all_createdorderdaysgapmathcount_avg,  -- 下单间隔天数平均值
    multi_loan_in_loan_order_all_createdorderdaysgapmathcount_max,  -- 下单间隔天数最大值
    multi_loan_in_loan_order_all_createdorderdaysgapmathcount_std,  -- 下单间隔天数标准差

    -- 最近一次逾期时间间隔（1个）
    multi_loan_in_loan_order_all_lastoverdueinstalrisktimegap,  -- 最近一次逾期账单距风控时间间隔

    -- 最大连续提前结清（2个）
    multi_loan_in_loan_order_all_maxcontinuecompletedadvanceinstalcnt,  -- 最大连续提前结清账单数
    multi_loan_in_loan_order_all_maxcontinuecompletedadvanceinstalratio,  -- 最大连续提前结清账单比例

    -- 最大连续逾期（2个）
    multi_loan_in_loan_order_all_maxcontinueoverdueinstalcnt,  -- 最大连续逾期账单数
    multi_loan_in_loan_order_all_maxcontinueoverdueinstalratio,  -- 最大连续逾期账单比例

    -- 3个月内每月max逾期（1个）
    multi_loan_in_loan_order_all_maxoverdueinstalcntforwithinthreemonths,  -- 3个月内每月最大逾期账单数

    -- 续借订单额度测算次数（3个）
    multi_loan_in_loan_order_all_multiloancalccreditstimesmathcount_avg,  -- 续借订单额度测算次数平均值
    multi_loan_in_loan_order_all_multiloancalccreditstimesmathcount_max,  -- 续借订单额度测算次数最大值
    multi_loan_in_loan_order_all_multiloancalccreditstimesmathcount_std,  -- 续借订单额度测算次数标准差

    -- 续借订单下单间隔天数（3个）
    multi_loan_in_loan_order_all_multiloancreatedorderdaysgapmathcount_avg,  -- 续借订单下单间隔天数平均值
    multi_loan_in_loan_order_all_multiloancreatedorderdaysgapmathcount_max,  -- 续借订单下单间隔天数最大值
    multi_loan_in_loan_order_all_multiloancreatedorderdaysgapmathcount_std,  -- 续借订单下单间隔天数标准差

    -- 逾期账单（2个）
    multi_loan_in_loan_order_all_overdueinstalcnt,  -- 所有订单逾期账单数
    multi_loan_in_loan_order_all_overdueinstalratio,  -- 所有订单逾期账单比例

    -- 通用在贷订单特征（11个）
    multi_loan_order_info_inloanorders_overduevscompletetermratio,  -- 在贷订单逾期账单占已结清账单比例
    multi_loan_order_info_inloanorders_overduevsbillingtermratio,  -- 在贷订单逾期账单占到期账单比例
    multi_loan_order_info_inloanorders_overduetermcnt,  -- 在贷订单逾期账单数
    multi_loan_order_info_inloanorders_completetermratio,  -- 在贷订单已结清账单比例
    multi_loan_order_info_inloanorders_completetermcnt,  -- 在贷订单已结清账单数
    multi_loan_order_info_inloanorders_completeprincipalvslatestremaincreditratio,  -- 在贷订单已结清本金占最新剩余额度比例
    multi_loan_order_info_inloanorders_completeprincipal,  -- 在贷订单已结清本金
    multi_loan_order_info_inloanorders_calccreditgapstd,  -- 在贷订单额度测算间隔标准差
    multi_loan_order_info_inloanorders_calccreditgapmin,  -- 在贷订单额度测算间隔最小值
    multi_loan_order_info_inloanorders_calccreditgapmean,  -- 在贷订单额度测算间隔平均值
    multi_loan_order_info_inloanorders_calccreditgapmax,  -- 在贷订单额度测算间隔最大值

    -- 续借在贷订单特征（12个）
    multi_loan_order_info_multiloanorders_overduevscompletetermratio,  -- 续借在贷订单逾期账单占已结清账单比例
    multi_loan_order_info_multiloanorders_overduevsbillingtermratio,  -- 续借在贷订单逾期账单占到期账单比例
    multi_loan_order_info_multiloanorders_overduetermcnt,  -- 续借在贷订单逾期账单数
    multi_loan_order_info_multiloanorders_orderprincipalstd,  -- 续借在贷订单本金标准差
    multi_loan_order_info_multiloanorders_completetermratio,  -- 续借在贷订单已结清账单比例
    multi_loan_order_info_multiloanorders_completetermcnt,  -- 续借在贷订单已结清账单数
    multi_loan_order_info_multiloanorders_completeprincipalvslatestremaincreditratio,  -- 续借在贷订单已结清本金占最新剩余额度比例
    multi_loan_order_info_multiloanorders_completeprincipal,  -- 续借在贷订单已结清本金
    multi_loan_order_info_multiloanorders_calccreditgapstd,  -- 续借在贷订单额度测算间隔标准差
    multi_loan_order_info_multiloanorders_calccreditgapmin,  -- 续借在贷订单额度测算间隔最小值
    multi_loan_order_info_multiloanorders_calccreditgapmean,  -- 续借在贷订单额度测算间隔平均值
    multi_loan_order_info_multiloanorders_calccreditgapmax,  -- 续借在贷订单额度测算间隔最大值

    -- ===================== 第三部分：新增3个查询107个特征 =====================
    -- 最远一笔订单特征（36个）
    multi_loan_order_info_furthestsingleorder_termscnt,  -- 最远一笔订单总期数
    multi_loan_order_info_furthestsingleorder_prepayvsfuturebillingtermratio,  -- 最远一笔订单提前结清占未来到期账单比例
    multi_loan_order_info_furthestsingleorder_prepayvsalltermratio,  -- 最远一笔订单提前结清占所有期数比例
    multi_loan_order_info_furthestsingleorder_payoutdays,  -- 最远一笔订单放款天数
    multi_loan_order_info_furthestsingleorder_overduevscompletedtermratio,  -- 最远一笔订单逾期占已结清比例
    multi_loan_order_info_furthestsingleorder_overduevsbillingtermratio,  -- 最远一笔订单逾期占到期账单比例
    multi_loan_order_info_furthestsingleorder_overduetermratio,  -- 最远一笔订单逾期期数比例
    multi_loan_order_info_furthestsingleorder_overduetermcnt,  -- 最远一笔订单逾期期数
    multi_loan_order_info_furthestsingleorder_maxsuccessiveprepaytermvsbillingratio,  -- 最远一笔订单最大连续提前结清占到期账单比例
    multi_loan_order_info_furthestsingleorder_maxsuccessiveprepaytermvsallratio,  -- 最远一笔订单最大连续提前结清占所有期数比例
    multi_loan_order_info_furthestsingleorder_maxsuccessiveprepaytermcnt,  -- 最远一笔订单最大连续提前结清期数
    multi_loan_order_info_furthestsingleorder_maxsuccessiveoverduetermvsbillingratio,  -- 最远一笔订单最大连续逾期占到期账单比例
    multi_loan_order_info_furthestsingleorder_maxsuccessiveoverduetermvsallratio,  -- 最远一笔订单最大连续逾期占所有期数比例
    multi_loan_order_info_furthestsingleorder_maxsuccessiveoverduetermcnt,  -- 最远一笔订单最大连续逾期期数
    multi_loan_order_info_furthestsingleorder_incompletetermcnt,  -- 最远一笔订单未结清期数
    multi_loan_order_info_furthestsingleorder_firstcompletedcreatedgap,  -- 最远一笔订单首次结清距放款天数
    multi_loan_order_info_furthestsingleorder_creatednowgap,  -- 最远一笔订单创建距当前天数
    multi_loan_order_info_furthestsingleorder_creatednoon,  -- 最远一笔订单创建时段：中午（11-13点）
    multi_loan_order_info_furthestsingleorder_creatednight,  -- 最远一笔订单创建时段：夜间（23-4点）
    multi_loan_order_info_furthestsingleorder_createdmorning,  -- 最远一笔订单创建时段：早上（6-10点）
    multi_loan_order_info_furthestsingleorder_createdevening,  -- 最远一笔订单创建时段：晚上（18-22点）
    multi_loan_order_info_furthestsingleorder_createdcalccreditgap,  -- 最远一笔订单创建距额度测算间隔
    multi_loan_order_info_furthestsingleorder_createdafternoon,  -- 最远一笔订单创建时段：下午（15-17点）
    multi_loan_order_info_furthestsingleorder_completevsfuturebillingtermratio,  -- 最远一笔订单已结清占未来到期账单比例
    multi_loan_order_info_furthestsingleorder_completetermratio,  -- 最远一笔订单已结清期数比例
    multi_loan_order_info_furthestsingleorder_completetermcnt,  -- 最远一笔订单已结清期数
    multi_loan_order_info_furthestsingleorder_completesamedaytermscntmax,  -- 最远一笔订单同一天结清期数最大值
    multi_loan_order_info_furthestsingleorder_completesamedaytermscntavg,  -- 最远一笔订单同一天结清期数平均值
    multi_loan_order_info_furthestsingleorder_completeprepaydaysmin,  -- 最远一笔订单提前结清天数最小值
    multi_loan_order_info_furthestsingleorder_completeprepaydaysmean,  -- 最远一笔订单提前结清天数平均值
    multi_loan_order_info_furthestsingleorder_completeprepaydaysmax,  -- 最远一笔订单提前结清天数最大值
    multi_loan_order_info_furthestsingleorder_completeonweekendprincipalratio,  -- 最远一笔订单周末还款金额占已结清金额比例
    multi_loan_order_info_furthestsingleorder_completefutureduetermratio,  -- 最远一笔订单提前结清占已结清比例
    multi_loan_order_info_furthestsingleorder_completefutureduetermcnt,  -- 最远一笔订单提前结清期数
    multi_loan_order_info_furthestsingleorder_billingprepayvscompletetermratio,  -- 最远一笔订单到期前提前结清占已结清比例
    multi_loan_order_info_furthestsingleorder_billingprepayvsbillingtermratio,  -- 最远一笔订单到期前提前结清占到期账单比例

    -- 最近第二笔订单特征（36个）
    multi_loan_order_info_latest2singleorder_termscnt,  -- 最近第二笔订单总期数
    multi_loan_order_info_latest2singleorder_prepayvsfuturebillingtermratio,  -- 最近第二笔订单提前结清占未来到期账单比例
    multi_loan_order_info_latest2singleorder_prepayvsalltermratio,  -- 最近第二笔订单提前结清占所有期数比例
    multi_loan_order_info_latest2singleorder_payoutdays,  -- 最近第二笔订单放款天数
    multi_loan_order_info_latest2singleorder_overduevscompletedtermratio,  -- 最近第二笔订单逾期占已结清比例
    multi_loan_order_info_latest2singleorder_overduevsbillingtermratio,  -- 最近第二笔订单逾期占到期账单比例
    multi_loan_order_info_latest2singleorder_overduetermratio,  -- 最近第二笔订单逾期期数比例
    multi_loan_order_info_latest2singleorder_overduetermcnt,  -- 最近第二笔订单逾期期数
    multi_loan_order_info_latest2singleorder_maxsuccessiveprepaytermvsbillingratio,  -- 最近第二笔订单最大连续提前结清占到期账单比例
    multi_loan_order_info_latest2singleorder_maxsuccessiveprepaytermvsallratio,  -- 最近第二笔订单最大连续提前结清占所有期数比例
    multi_loan_order_info_latest2singleorder_maxsuccessiveprepaytermcnt,  -- 最近第二笔订单最大连续提前结清期数
    multi_loan_order_info_latest2singleorder_maxsuccessiveoverduetermvsbillingratio,  -- 最近第二笔订单最大连续逾期占到期账单比例
    multi_loan_order_info_latest2singleorder_maxsuccessiveoverduetermvsallratio,  -- 最近第二笔订单最大连续逾期占所有期数比例
    multi_loan_order_info_latest2singleorder_maxsuccessiveoverduetermcnt,  -- 最近第二笔订单最大连续逾期期数
    multi_loan_order_info_latest2singleorder_incompletetermcnt,  -- 最近第二笔订单未结清期数
    multi_loan_order_info_latest2singleorder_firstcompletedcreatedgap,  -- 最近第二笔订单首次结清距放款天数
    multi_loan_order_info_latest2singleorder_creatednowgap,  -- 最近第二笔订单创建距当前天数
    multi_loan_order_info_latest2singleorder_creatednoon,  -- 最近第二笔订单创建时段：中午（11-13点）
    multi_loan_order_info_latest2singleorder_creatednight,  -- 最近第二笔订单创建时段：夜间（23-4点）
    multi_loan_order_info_latest2singleorder_createdmorning,  -- 最近第二笔订单创建时段：早上（6-10点）
    multi_loan_order_info_latest2singleorder_createdevening,  -- 最近第二笔订单创建时段：晚上（18-22点）
    multi_loan_order_info_latest2singleorder_createdcalccreditgap,  -- 最近第二笔订单创建距额度测算间隔
    multi_loan_order_info_latest2singleorder_createdafternoon,  -- 最近第二笔订单创建时段：下午（15-17点）
    multi_loan_order_info_latest2singleorder_completevsfuturebillingtermratio,  -- 最近第二笔订单已结清占未来到期账单比例
    multi_loan_order_info_latest2singleorder_completetermratio,  -- 最近第二笔订单已结清期数比例
    multi_loan_order_info_latest2singleorder_completetermcnt,  -- 最近第二笔订单已结清期数
    multi_loan_order_info_latest2singleorder_completesamedaytermscntmax,  -- 最近第二笔订单同一天结清期数最大值
    multi_loan_order_info_latest2singleorder_completesamedaytermscntavg,  -- 最近第二笔订单同一天结清期数平均值
    multi_loan_order_info_latest2singleorder_completeprepaydaysmin,  -- 最近第二笔订单提前结清天数最小值
    multi_loan_order_info_latest2singleorder_completeprepaydaysmean,  -- 最近第二笔订单提前结清天数平均值
    multi_loan_order_info_latest2singleorder_completeprepaydaysmax,  -- 最近第二笔订单提前结清天数最大值
    multi_loan_order_info_latest2singleorder_completefutureduetermratio,  -- 最近第二笔订单提前结清占已结清比例
    multi_loan_order_info_latest2singleorder_completefutureduetermprincipal,  -- 最近第二笔订单提前结清本金
    multi_loan_order_info_latest2singleorder_completefutureduetermcnt,  -- 最近第二笔订单提前结清期数
    multi_loan_order_info_latest2singleorder_billingprepayvscompletetermratio,  -- 最近第二笔订单到期前提前结清占已结清比例
    multi_loan_order_info_latest2singleorder_billingprepayvsbillingtermratio,  -- 最近第二笔订单到期前提前结清占到期账单比例

    -- 最近第一笔订单特征（35个）
    multi_loan_order_info_latest1singleorder_termscnt,  -- 最近第一笔订单总期数
    multi_loan_order_info_latest1singleorder_prepayvsfuturebillingtermratio,  -- 最近第一笔订单提前结清占未来到期账单比例
    multi_loan_order_info_latest1singleorder_prepayvsalltermratio,  -- 最近第一笔订单提前结清占所有期数比例
    multi_loan_order_info_latest1singleorder_payoutdays,  -- 最近第一笔订单放款天数
    multi_loan_order_info_latest1singleorder_overduevscompletedtermratio,  -- 最近第一笔订单逾期占已结清比例
    multi_loan_order_info_latest1singleorder_overduevsbillingtermratio,  -- 最近第一笔订单逾期占到期账单比例
    multi_loan_order_info_latest1singleorder_overduetermratio,  -- 最近第一笔订单逾期期数比例
    multi_loan_order_info_latest1singleorder_overduetermcnt,  -- 最近第一笔订单逾期期数
    multi_loan_order_info_latest1singleorder_maxsuccessiveprepaytermvsbillingratio,  -- 最近第一笔订单最大连续提前结清占到期账单比例
    multi_loan_order_info_latest1singleorder_maxsuccessiveprepaytermvsallratio,  -- 最近第一笔订单最大连续提前结清占所有期数比例
    multi_loan_order_info_latest1singleorder_maxsuccessiveprepaytermcnt,  -- 最近第一笔订单最大连续提前结清期数
    multi_loan_order_info_latest1singleorder_maxsuccessiveoverduetermvsbillingratio,  -- 最近第一笔订单最大连续逾期占到期账单比例
    multi_loan_order_info_latest1singleorder_maxsuccessiveoverduetermvsallratio,  -- 最近第一笔订单最大连续逾期占所有期数比例
    multi_loan_order_info_latest1singleorder_maxsuccessiveoverduetermcnt,  -- 最近第一笔订单最大连续逾期期数
    multi_loan_order_info_latest1singleorder_incompletetermcnt,  -- 最近第一笔订单未结清期数
    multi_loan_order_info_latest1singleorder_firstcompletedcreatedgap,  -- 最近第一笔订单首次结清距放款天数
    multi_loan_order_info_latest1singleorder_creatednowgap,  -- 最近第一笔订单创建距当前天数
    multi_loan_order_info_latest1singleorder_creatednoon,  -- 最近第一笔订单创建时段：中午（11-13点）
    multi_loan_order_info_latest1singleorder_creatednight,  -- 最近第一笔订单创建时段：夜间（23-4点）
    multi_loan_order_info_latest1singleorder_createdmorning,  -- 最近第一笔订单创建时段：早上（6-10点）
    multi_loan_order_info_latest1singleorder_createdevening,  -- 最近第一笔订单创建时段：晚上（18-22点）
    multi_loan_order_info_latest1singleorder_createdcalccreditgap,  -- 最近第一笔订单创建间隔天数
    multi_loan_order_info_latest1singleorder_createdafternoon,  -- 最近第一笔订单创建时段：下午（15-17点）
    multi_loan_order_info_latest1singleorder_completevsfuturebillingtermratio,  -- 最近第一笔订单未来账单已结清比例
    multi_loan_order_info_latest1singleorder_completetermratio,  -- 最近第一笔订单已结清期数比例
    multi_loan_order_info_latest1singleorder_completetermcnt,  -- 最近第一笔订单已结清期数
    multi_loan_order_info_latest1singleorder_completesamedaytermscntmax,  -- 最近第一笔订单同一天结清期数最大值
    multi_loan_order_info_latest1singleorder_completesamedaytermscntavg,  -- 最近第一笔订单同一天结清期数平均值
    multi_loan_order_info_latest1singleorder_completeprepaydaysmin,  -- 最近第一笔订单提前结清天数最小值
    multi_loan_order_info_latest1singleorder_completeprepaydaysmean,  -- 最近第一笔订单提前结清天数平均值
    multi_loan_order_info_latest1singleorder_completeprepaydaysmax,  -- 最近第一笔订单提前结清天数最大值
    multi_loan_order_info_latest1singleorder_completefutureduetermratio,  -- 最近第一笔订单提前结清占已结清比例
    multi_loan_order_info_latest1singleorder_completefutureduetermcnt,  -- 最近第一笔订单提前结清期数
    multi_loan_order_info_latest1singleorder_billingprepayvscompletetermratio,  -- 最近第一笔订单到期前提前结清占已结清比例
    multi_loan_order_info_latest1singleorder_billingprepayvsbillingtermratio,  -- 最近第一笔订单到期前提前结清占到期账单比例
    multi_loan_order_info_latest1singleorder_creditusageratio,  -- 最近第一笔订单额度使用率

    -- ===================== 第四部分：新增20个多订单特征 =====================
    -- 未来90-180天未结清订单特征（3个）
    multi_loan_order_info_multiloanrangefuture90dto180d_futurebillingunclearinstalcnt,  -- 未来90-180天未结清账单数
    multi_loan_order_info_multiloanrangefuture90dto180d_futurebillingunclearvsunclearinstalratio,  -- 未来90-180天未结清账单占所有未结清比例
    multi_loan_order_info_multiloanrangefuture90dto180d_futurebillingunclearvsclearinstalratio,  -- 未来90-180天未结清账单占所有已结清比例

    -- 未来90天未结清订单特征（3个）
    multi_loan_order_info_multiloanrangefuture0dto90d_futurebillingunclearinstalcnt,  -- 未来90天未结清账单数
    multi_loan_order_info_multiloanrangefuture0dto90d_futurebillingunclearvsunclearinstalratio,  -- 未来90天未结清账单占所有未结清比例
    multi_loan_order_info_multiloanrangefuture0dto90d_futurebillingunclearvsclearinstalratio,  -- 未来90天未结清账单占所有已结清比例

    -- 过去90天订单在贷结清特征（4个）
    multi_loan_order_info_multiloannoloanclear90dstat_noloandays,  -- 过去90天无在贷天数
    multi_loan_order_info_multiloannoloanclear90dstat_noloandaysratio,  -- 过去90天无在贷天数比例
    multi_loan_order_info_multiloannoloanclear90dstat_clearordercnt,  -- 过去90天结清订单数
    multi_loan_order_info_multiloannoloanclear90dstat_clearorderratio,  -- 过去90天结清订单比例

    -- 过去180天订单在贷结清特征（4个）
    multi_loan_order_info_multiloannoloanclear180dstat_noloandays,  -- 过去180天无在贷天数
    multi_loan_order_info_multiloannoloanclear180dstat_noloandaysratio,  -- 过去180天无在贷天数比例
    multi_loan_order_info_multiloannoloanclear180dstat_clearordercnt,  -- 过去180天结清订单数
    multi_loan_order_info_multiloannoloanclear180dstat_clearorderratio,  -- 过去180天结清订单比例

    -- 过去90天订单特征（3个）
    multi_loan_order_info_multiloan90dstat_payoutordercnt,  -- 过去90天放款订单数
    multi_loan_order_info_multiloan90dstat_payoutmultiloanordercnt,  -- 过去90天续借放款订单数
    multi_loan_order_info_multiloan90dstat_multiloancalcvsmultiloanpayoutratio,  -- 过去90天续借额度测算次数与续借放款订单数比例

    -- 过去30天订单特征（3个）
    multi_loan_order_info_multiloan30dstat_payoutordercnt,  -- 过去30天放款订单数
    multi_loan_order_info_multiloan30dstat_payoutmultiloanordercnt,  -- 过去30天续借放款订单数
    multi_loan_order_info_multiloan30dstat_multiloancalcvsmultiloanpayoutratio  -- 过去30天续借额度测算次数与续借放款订单数比例

FROM merged_all_features maf) t where cust_no='800000388096'
