-- 用信特征 离线特征
-- ============================================================================
-- 贷中特征衍生 - 海哥还款特征（修正版）
-- 基于新的base_loan_data，尽量减少临时表
-- 特征：前第1、2、3笔订单的还款行为特征（共42个特征）
-- ============================================================================
-- ============================================================================
-- 中间表1：期次粒度底表 base_loan_data
-- ============================================================================
WITH base_loan_data AS (
  SELECT
    m0.cust_no -- 客户号
,
    m0.use_credit_apply_id -- 用信申请id
,
    m0.use_create_time -- 用信申请创建时间
,
    m5.create_time -- 用信申请落表时间（历史订单）
,
    m5.rp_create_time -- 还款计划落表时间
,
    m0.use_credit_apply_date -- 用信申请创建时间年月日
,
    m0.use_amount -- 用信金额
,
    m0.use_period -- 用信期数
,
    m5.loaninfo_create_time,
    m5.loan_period,
    m5.real_loan_amt,
    m5.id -- 还款计划表id
,
    m5.loan_no,
    m5.periods -- 还款计划表中当前账单是第几期
,
    datediff(
      to_date(m0.use_create_time),
      to_date(m5.create_time)
    ) AS applyinterval,
    m5.settled_time,
    m5.loan_day,
    m5.loan_end_date -- 应还日期
,
    m5.loan_amt,
    m5.repaid_principal,
    m5.principal_all,CASE
      WHEN m5.settled_time <= m0.use_create_time THEN datediff(
        to_date(m5.settled_time),
        to_date(m5.loan_end_date)
      )
      WHEN (
        m5.settled_time IS NULL
        OR m5.settled_time > m0.use_create_time
      )
      AND to_date(m0.use_create_time) > m5.loan_end_date THEN datediff(
        to_date(m0.use_create_time),
        to_date(m5.loan_end_date)
      )
      ELSE NULL
    END AS overduedays,
    IF(
      m5.settled_time <= m0.use_create_time,
      datediff(
        to_date(m5.settled_time),
        to_date(m5.loan_end_date)
      ),
      NULL
    ) AS overduedays_pay,
    IF(
      m5.settled_time <= m0.use_create_time
      AND to_date(m5.settled_time) < m5.loan_end_date,
      abs(
        datediff(
          to_date(m5.settled_time),
          to_date(m5.loan_end_date)
        )
      ),
      NULL
    ) AS prepaydays,CASE
      WHEN m5.settled_time <= m0.use_create_time
      OR m5.loan_end_date < to_date(m0.use_create_time) THEN 1
      ELSE 0
    END AS is_valid_period,
    dense_rank() OVER (
      PARTITION BY m0.cust_no,
      m0.use_credit_apply_id
      ORDER BY
        m5.create_time DESC
    ) AS rank
  FROM
    (
      SELECT
        cust_no,
        use_credit_apply_id,
        use_create_time,
        substr(use_create_time, 1, 10) AS use_credit_apply_date,
        use_period,
        use_amount
      FROM
        hive_idc.oversea.dws_trd_credit_apply_use_loan_df
      WHERE
        pt = '20260106'
    ) AS m0
    INNER JOIN (
      SELECT
        m1.cust_no,
        m4.id,
        m3.loan_no,
        m4.periods,
        m1.create_time -- 用信申请落表时间
,
        m3.create_time AS loaninfo_create_time,
        m3.loan_period -- 期数
,
        m3.loan_day -- 天数
,
        m3.real_loan_amt -- 本金
,
        m4.create_time AS rp_create_time -- 还款计划生成时间
,
        m4.settled_time,
        m4.loan_end_date,
        m4.repaid_principal -- 已还本金
,(m4.repaid_principal + m4.principal) AS principal_all,
        m2.loan_amt
      FROM
        (
          SELECT
            *
          FROM
            fintech.dwd_rsk_approve_use_credit_apply_rt
        ) AS m1
        INNER JOIN (
          SELECT
            *
          FROM
            fintech.dwd_rsk_asset_loan_apply_rt
        ) AS m2 ON m1.asset_id = m2.seq_no
        INNER JOIN (
          SELECT
            *
          FROM
            fintech.dwd_trd_ast_loan_info_rt
          WHERE
            loan_status <> 4
            AND (
              optype <> 'DELETE'
              OR optype IS NULL
            )
        ) AS m3 ON m2.loan_apply_no = m3.loan_apply_no
        INNER JOIN (
          SELECT
            *
          FROM
            fintech.dwd_trd_ast_repay_plan_rt
          WHERE
            repay_plan_status <> 4
            AND (
              optype <> 'DELETE'
              OR optype IS NULL
            )
        ) AS m4 ON m3.loan_no = m4.loan_no
    ) AS m5 ON m0.cust_no = m5.cust_no
  WHERE
    m0.use_create_time > m5.rp_create_time
    AND m5.cust_no IN (
      SELECT
        DISTINCT cust_no
      FROM
        fintech.dwd_trd_ast_repay_plan_rt
      WHERE
        create_time > '2025-10-01'
    )
) -- ============================================================================
-- 中间表2：订单粒度 + 订单排序（修正：使用ROW_NUMBER而非LAG）
-- 按时间倒序排列：order_seq=1是最近的历史订单，order_seq=2是次近的...
-- ============================================================================
,
order_ranked AS (
  SELECT
    cust_no,
    use_credit_apply_id,
    use_create_time,
    loan_no,
    loan_amt,
    MIN(create_time) AS order_create_time -- 使用ROW_NUMBER按时间倒序排列，1=前第1笔（最近），2=前第2笔...
,
    ROW_NUMBER() OVER (
      PARTITION BY cust_no,
      use_credit_apply_id
      ORDER BY
        MIN(create_time) DESC
    ) AS order_seq
  FROM
    base_loan_data
  GROUP BY
    cust_no,
    use_credit_apply_id,
    use_create_time,
    loan_no,
    loan_amt
) -- ============================================================================
-- 中间表3：统一处理前1/2/3笔订单的还款数据
-- ============================================================================
,
all_prev_repayments AS (
  SELECT
    orr.cust_no,
    orr.use_credit_apply_id,
    orr.use_create_time,
    orr.order_seq AS prev_order_num -- 1=前第1笔，2=前第2笔，3=前第3笔
,
    bld.settled_time,
    bld.repaid_principal,
    bld.loan_amt,
    DATE(bld.settled_time) AS repay_date,
    DAYOFWEEK(bld.settled_time) AS day_of_week,
    HOUR(bld.settled_time) AS repay_hour,
    LAG(bld.settled_time) OVER (
      PARTITION BY orr.cust_no,
      orr.use_credit_apply_id,
      orr.use_create_time,
      orr.order_seq
      ORDER BY
        bld.settled_time
    ) AS prev_settled_time
  FROM
    order_ranked orr
    INNER JOIN base_loan_data bld ON orr.cust_no = bld.cust_no
    AND orr.use_credit_apply_id = bld.use_credit_apply_id
    AND orr.loan_no = bld.loan_no -- 用order_seq对应的loan_no关联
  WHERE
    orr.order_seq IN (1, 2, 3) -- 只取前3笔订单
    AND bld.settled_time IS NOT NULL
    AND bld.settled_time < orr.use_create_time
    AND bld.rp_create_time < orr.use_create_time
) -- ============================================================================
-- 中间表4：统一计算所有特征
-- ============================================================================
,
repayment_features AS (
  SELECT
    cust_no,
    use_credit_apply_id,
    use_create_time,
    prev_order_num,
    COUNT(DISTINCT settled_time) AS cnt -- 还款次数
,
    MAX(loan_amt) AS total_amount -- 订单总金额
,
    MIN(per_settlement_amount) AS amount_min -- 单次还款最小金额
,
    MAX(per_settlement_amount) AS amount_max -- 单次还款最大金额
,
    STDDEV(per_settlement_amount) AS amount_std -- 单次金额标准差
,
    MIN(repay_hour) AS hour_min -- 还款最早时刻
,
    MAX(repay_hour) AS hour_max -- 还款最晚时刻
,
    SUM(
      CASE
        WHEN day_of_week = 1 THEN 1
        ELSE 0
      END
    ) AS on_weekend_cnt -- 周末还款次数
,
    SUM(
      CASE
        WHEN day_of_week = 1 THEN per_settlement_amount
        ELSE 0
      END
    ) AS on_weekend_amount -- 周末还款金额
,
    MAX(DATEDIFF(repay_date, DATE(prev_settled_time))) AS gap_days_max -- 相邻两次还款最大间隔天数
,
    MIN(DATEDIFF(repay_date, DATE(prev_settled_time))) AS gap_days_min -- 相邻两次还款最小间隔天数
  FROM
    (
      SELECT
        cust_no,
        use_credit_apply_id,
        use_create_time,
        prev_order_num,
        settled_time,
        MAX(loan_amt) AS loan_amt,
        DATE(settled_time) AS repay_date,
        DAYOFWEEK(settled_time) AS day_of_week,
        HOUR(settled_time) AS repay_hour,
        MAX(prev_settled_time) AS prev_settled_time,
        SUM(repaid_principal) AS per_settlement_amount -- 单次还款金额
      FROM
        all_prev_repayments
      GROUP BY
        cust_no,
        use_credit_apply_id,
        use_create_time,
        prev_order_num,
        settled_time
    ) t
  GROUP BY
    cust_no,
    use_credit_apply_id,
    use_create_time,
    prev_order_num
) -- ============================================================================
-- 最终输出：42个还款特征
-- ============================================================================
SELECT
  *
FROM(
    SELECT
      bld.cust_no,
      bld.use_credit_apply_id,
      bld.use_create_time -- ========== 最近第1笔订单还款特征（14个）==========
,
      COALESCE(
        MAX(
          CASE
            WHEN rf.prev_order_num = 1 THEN rf.cnt
          END
        ),
        0
      ) AS local_olduser_repayment_new_recent1singleorderrepayment_cnt_v2 -- 最近第1笔订单还款特征_还款次数
,
      COALESCE(
        MAX(
          CASE
            WHEN rf.prev_order_num = 1 THEN rf.amount_min
          END
        ),
        0
      ) AS local_olduser_repayment_new_recent1singleorderrepayment_amountmin_v2 -- 最近第1笔订单还款特征_单次还款最小金额
,
      COALESCE(
        MAX(
          CASE
            WHEN rf.prev_order_num = 1 THEN rf.amount_max
          END
        ),
        0
      ) AS local_olduser_repayment_new_recent1singleorderrepayment_amountmax_v2 -- 最近第1笔订单还款特征_单次还款最大金额
,
      ROUND(
        COALESCE(
          MAX(
            CASE
              WHEN rf.prev_order_num = 1 THEN rf.amount_std
            END
          ),
          0
        ),
        6
      ) AS local_olduser_repayment_new_recent1singleorderrepayment_amountstd_v2 -- 最近第1笔订单还款特征_单次金额标准差
,
      COALESCE(
        MAX(
          CASE
            WHEN rf.prev_order_num = 1 THEN rf.hour_min
          END
        ),
        0
      ) AS local_olduser_repayment_new_recent1singleorderrepayment_hourmin_v2 -- 最近第1笔订单还款特征_还款最早时刻
,
      COALESCE(
        MAX(
          CASE
            WHEN rf.prev_order_num = 1 THEN rf.hour_max
          END
        ),
        0
      ) AS local_olduser_repayment_new_recent1singleorderrepayment_hourmax_v2 -- 最近第1笔订单还款特征_还款最晚时刻
,
      COALESCE(
        MAX(
          CASE
            WHEN rf.prev_order_num = 1 THEN rf.on_weekend_cnt
          END
        ),
        0
      ) AS local_olduser_repayment_new_recent1singleorderrepayment_onweekendcnt_v2 -- 最近第1笔订单还款特征_周末还款次数
,
      COALESCE(
        MAX(
          CASE
            WHEN rf.prev_order_num = 1 THEN rf.on_weekend_amount
          END
        ),
        0
      ) AS local_olduser_repayment_new_recent1singleorderrepayment_onweekendamount_v2 -- 最近第1笔订单还款特征_周末还款金额
,
      MAX(
        CASE
          WHEN rf.prev_order_num = 1 THEN rf.gap_days_min
        END
      ) AS local_olduser_repayment_new_recent1singleorderrepayment_gapdaysmin_v2 -- 最近第1笔订单还款特征_相邻两次还款最小间隔天数
,
      MAX(
        CASE
          WHEN rf.prev_order_num = 1 THEN rf.gap_days_max
        END
      ) AS local_olduser_repayment_new_recent1singleorderrepayment_gapdaysmax_v2 -- 最近第1笔订单还款特征_相邻两次还款最大间隔天数
,
      ROUND(
        CASE
          WHEN COALESCE(
            MAX(
              CASE
                WHEN rf.prev_order_num = 1 THEN rf.total_amount
              END
            ),
            0
          ) > 0 THEN COALESCE(
            MAX(
              CASE
                WHEN rf.prev_order_num = 1 THEN rf.amount_min
              END
            ),
            0
          ) / MAX(
            CASE
              WHEN rf.prev_order_num = 1 THEN rf.total_amount
            END
          )
          ELSE 0
        END,
        6
      ) AS local_olduser_repayment_new_recent1singleorderrepayment_minamountratio_v2 -- 最近第1笔订单还款特征_单次还款最小金额占总金额比例
,
      ROUND(
        CASE
          WHEN COALESCE(
            MAX(
              CASE
                WHEN rf.prev_order_num = 1 THEN rf.total_amount
              END
            ),
            0
          ) > 0 THEN COALESCE(
            MAX(
              CASE
                WHEN rf.prev_order_num = 1 THEN rf.amount_max
              END
            ),
            0
          ) / MAX(
            CASE
              WHEN rf.prev_order_num = 1 THEN rf.total_amount
            END
          )
          ELSE 0
        END,
        6
      ) AS local_olduser_repayment_new_recent1singleorderrepayment_maxamountratio_v2 -- 最近第1笔订单还款特征_单次还款最大金额占总金额比例
,
      ROUND(
        CASE
          WHEN COALESCE(
            MAX(
              CASE
                WHEN rf.prev_order_num = 1 THEN rf.total_amount
              END
            ),
            0
          ) > 0 THEN COALESCE(
            MAX(
              CASE
                WHEN rf.prev_order_num = 1 THEN rf.on_weekend_amount
              END
            ),
            0
          ) / MAX(
            CASE
              WHEN rf.prev_order_num = 1 THEN rf.total_amount
            END
          )
          ELSE 0
        END,
        6
      ) AS local_olduser_repayment_new_recent1singleorderrepayment_onweekendamountratio_v2 -- 最近第1笔订单还款特征_周末还款金额占比
,
      ROUND(
        CASE
          WHEN COALESCE(
            MAX(
              CASE
                WHEN rf.prev_order_num = 1 THEN rf.cnt
              END
            ),
            0
          ) > 0 THEN COALESCE(
            MAX(
              CASE
                WHEN rf.prev_order_num = 1 THEN rf.on_weekend_cnt
              END
            ),
            0
          ) / CAST(
            MAX(
              CASE
                WHEN rf.prev_order_num = 1 THEN rf.cnt
              END
            ) AS FLOAT
          )
          ELSE 0
        END,
        6
      ) AS local_olduser_repayment_new_recent1singleorderrepayment_onweekendratio_v2 -- 最近第1笔订单还款特征_周末还款次数占比
      -- ========== 最近第2笔订单还款特征（14个）==========
,
      COALESCE(
        MAX(
          CASE
            WHEN rf.prev_order_num = 2 THEN rf.cnt
          END
        ),
        0
      ) AS local_olduser_repayment_new_recent2singleorderrepayment_cnt_v2 -- 最近第2笔订单还款特征_还款次数
,
      COALESCE(
        MAX(
          CASE
            WHEN rf.prev_order_num = 2 THEN rf.amount_min
          END
        ),
        0
      ) AS local_olduser_repayment_new_recent2singleorderrepayment_amountmin_v2 -- 最近第2笔订单还款特征_单次还款最小金额
,
      COALESCE(
        MAX(
          CASE
            WHEN rf.prev_order_num = 2 THEN rf.amount_max
          END
        ),
        0
      ) AS local_olduser_repayment_new_recent2singleorderrepayment_amountmax_v2 -- 最近第2笔订单还款特征_单次还款最大金额
,
      ROUND(
        COALESCE(
          MAX(
            CASE
              WHEN rf.prev_order_num = 2 THEN rf.amount_std
            END
          ),
          0
        ),
        6
      ) AS local_olduser_repayment_new_recent2singleorderrepayment_amountstd_v2 -- 最近第2笔订单还款特征_单次金额标准差
,
      COALESCE(
        MAX(
          CASE
            WHEN rf.prev_order_num = 2 THEN rf.hour_min
          END
        ),
        0
      ) AS local_olduser_repayment_new_recent2singleorderrepayment_hourmin_v2 -- 最近第2笔订单还款特征_还款最早时刻
,
      COALESCE(
        MAX(
          CASE
            WHEN rf.prev_order_num = 2 THEN rf.hour_max
          END
        ),
        0
      ) AS local_olduser_repayment_new_recent2singleorderrepayment_hourmax_v2 -- 最近第2笔订单还款特征_还款最晚时刻
,
      COALESCE(
        MAX(
          CASE
            WHEN rf.prev_order_num = 2 THEN rf.on_weekend_cnt
          END
        ),
        0
      ) AS local_olduser_repayment_new_recent2singleorderrepayment_onweekendcnt_v2 -- 最近第2笔订单还款特征_周末还款次数
,
      COALESCE(
        MAX(
          CASE
            WHEN rf.prev_order_num = 2 THEN rf.on_weekend_amount
          END
        ),
        0
      ) AS local_olduser_repayment_new_recent2singleorderrepayment_onweekendamount_v2 -- 最近第2笔订单还款特征_周末还款金额
,
      MAX(
        CASE
          WHEN rf.prev_order_num = 2 THEN rf.gap_days_min
        END
      ) AS local_olduser_repayment_new_recent2singleorderrepayment_gapdaysmin_v2 -- 最近第2笔订单还款特征_相邻两次还款最小间隔天数
,
      MAX(
        CASE
          WHEN rf.prev_order_num = 2 THEN rf.gap_days_max
        END
      ) AS local_olduser_repayment_new_recent2singleorderrepayment_gapdaysmax_v2 -- 最近第2笔订单还款特征_相邻两次还款最大间隔天数
,
      ROUND(
        CASE
          WHEN COALESCE(
            MAX(
              CASE
                WHEN rf.prev_order_num = 2 THEN rf.total_amount
              END
            ),
            0
          ) > 0 THEN COALESCE(
            MAX(
              CASE
                WHEN rf.prev_order_num = 2 THEN rf.amount_min
              END
            ),
            0
          ) / MAX(
            CASE
              WHEN rf.prev_order_num = 2 THEN rf.total_amount
            END
          )
          ELSE 0
        END,
        6
      ) AS local_olduser_repayment_new_recent2singleorderrepayment_minamountratio_v2 -- 最近第2笔订单还款特征_单次还款最小金额占总金额比例
,
      ROUND(
        CASE
          WHEN COALESCE(
            MAX(
              CASE
                WHEN rf.prev_order_num = 2 THEN rf.total_amount
              END
            ),
            0
          ) > 0 THEN COALESCE(
            MAX(
              CASE
                WHEN rf.prev_order_num = 2 THEN rf.amount_max
              END
            ),
            0
          ) / MAX(
            CASE
              WHEN rf.prev_order_num = 2 THEN rf.total_amount
            END
          )
          ELSE 0
        END,
        6
      ) AS local_olduser_repayment_new_recent2singleorderrepayment_maxamountratio_v2 -- 最近第2笔订单还款特征_单次还款最大金额占总金额比例
,
      ROUND(
        CASE
          WHEN COALESCE(
            MAX(
              CASE
                WHEN rf.prev_order_num = 2 THEN rf.total_amount
              END
            ),
            0
          ) > 0 THEN COALESCE(
            MAX(
              CASE
                WHEN rf.prev_order_num = 2 THEN rf.on_weekend_amount
              END
            ),
            0
          ) / MAX(
            CASE
              WHEN rf.prev_order_num = 2 THEN rf.total_amount
            END
          )
          ELSE 0
        END,
        6
      ) AS local_olduser_repayment_new_recent2singleorderrepayment_onweekendamountratio_v2 -- 最近第2笔订单还款特征_周末还款金额占比
,
      ROUND(
        CASE
          WHEN COALESCE(
            MAX(
              CASE
                WHEN rf.prev_order_num = 2 THEN rf.cnt
              END
            ),
            0
          ) > 0 THEN COALESCE(
            MAX(
              CASE
                WHEN rf.prev_order_num = 2 THEN rf.on_weekend_cnt
              END
            ),
            0
          ) / CAST(
            MAX(
              CASE
                WHEN rf.prev_order_num = 2 THEN rf.cnt
              END
            ) AS FLOAT
          )
          ELSE 0
        END,
        6
      ) AS local_olduser_repayment_new_recent2singleorderrepayment_onweekendratio_v2 -- 最近第2笔订单还款特征_周末还款次数占比
      -- ========== 最近第3笔订单还款特征（14个）==========
,
      COALESCE(
        MAX(
          CASE
            WHEN rf.prev_order_num = 3 THEN rf.cnt
          END
        ),
        0
      ) AS local_olduser_repayment_new_recent3singleorderrepayment_cnt_v2 -- 最近第3笔订单还款特征_还款次数
,
      COALESCE(
        MAX(
          CASE
            WHEN rf.prev_order_num = 3 THEN rf.amount_min
          END
        ),
        0
      ) AS local_olduser_repayment_new_recent3singleorderrepayment_amountmin_v2 -- 最近第3笔订单还款特征_单次还款最小金额
,
      COALESCE(
        MAX(
          CASE
            WHEN rf.prev_order_num = 3 THEN rf.amount_max
          END
        ),
        0
      ) AS local_olduser_repayment_new_recent3singleorderrepayment_amountmax_v2 -- 最近第3笔订单还款特征_单次还款最大金额
,
      ROUND(
        COALESCE(
          MAX(
            CASE
              WHEN rf.prev_order_num = 3 THEN rf.amount_std
            END
          ),
          0
        ),
        6
      ) AS local_olduser_repayment_new_recent3singleorderrepayment_amountstd_v2 -- 最近第3笔订单还款特征_单次金额标准差
,
      COALESCE(
        MAX(
          CASE
            WHEN rf.prev_order_num = 3 THEN rf.hour_min
          END
        ),
        0
      ) AS local_olduser_repayment_new_recent3singleorderrepayment_hourmin_v2 -- 最近第3笔订单还款特征_还款最早时刻
,
      COALESCE(
        MAX(
          CASE
            WHEN rf.prev_order_num = 3 THEN rf.hour_max
          END
        ),
        0
      ) AS local_olduser_repayment_new_recent3singleorderrepayment_hourmax_v2 -- 最近第3笔订单还款特征_还款最晚时刻
,
      COALESCE(
        MAX(
          CASE
            WHEN rf.prev_order_num = 3 THEN rf.on_weekend_cnt
          END
        ),
        0
      ) AS local_olduser_repayment_new_recent3singleorderrepayment_onweekendcnt_v2 -- 最近第3笔订单还款特征_周末还款次数
,
      COALESCE(
        MAX(
          CASE
            WHEN rf.prev_order_num = 3 THEN rf.on_weekend_amount
          END
        ),
        0
      ) AS local_olduser_repayment_new_recent3singleorderrepayment_onweekendamount_v2 -- 最近第3笔订单还款特征_周末还款金额
,
      MAX(
        CASE
          WHEN rf.prev_order_num = 3 THEN rf.gap_days_min
        END
      ) AS local_olduser_repayment_new_recent3singleorderrepayment_gapdaysmin_v2 -- 最近第3笔订单还款特征_相邻两次还款最小间隔天数
,
      MAX(
        CASE
          WHEN rf.prev_order_num = 3 THEN rf.gap_days_max
        END
      ) AS local_olduser_repayment_new_recent3singleorderrepayment_gapdaysmax_v2 -- 最近第3笔订单还款特征_相邻两次还款最大间隔天数
,
      ROUND(
        CASE
          WHEN COALESCE(
            MAX(
              CASE
                WHEN rf.prev_order_num = 3 THEN rf.total_amount
              END
            ),
            0
          ) > 0 THEN COALESCE(
            MAX(
              CASE
                WHEN rf.prev_order_num = 3 THEN rf.amount_min
              END
            ),
            0
          ) / MAX(
            CASE
              WHEN rf.prev_order_num = 3 THEN rf.total_amount
            END
          )
          ELSE 0
        END,
        6
      ) AS local_olduser_repayment_new_recent3singleorderrepayment_minamountratio_v2 -- 最近第3笔订单还款特征_单次还款最小金额占总金额比例
,
      ROUND(
        CASE
          WHEN COALESCE(
            MAX(
              CASE
                WHEN rf.prev_order_num = 3 THEN rf.total_amount
              END
            ),
            0
          ) > 0 THEN COALESCE(
            MAX(
              CASE
                WHEN rf.prev_order_num = 3 THEN rf.amount_max
              END
            ),
            0
          ) / MAX(
            CASE
              WHEN rf.prev_order_num = 3 THEN rf.total_amount
            END
          )
          ELSE 0
        END,
        6
      ) AS local_olduser_repayment_new_recent3singleorderrepayment_maxamountratio_v2 -- 最近第3笔订单还款特征_单次还款最大金额占总金额比例
,
      ROUND(
        CASE
          WHEN COALESCE(
            MAX(
              CASE
                WHEN rf.prev_order_num = 3 THEN rf.total_amount
              END
            ),
            0
          ) > 0 THEN COALESCE(
            MAX(
              CASE
                WHEN rf.prev_order_num = 3 THEN rf.on_weekend_amount
              END
            ),
            0
          ) / MAX(
            CASE
              WHEN rf.prev_order_num = 3 THEN rf.total_amount
            END
          )
          ELSE 0
        END,
        6
      ) AS local_olduser_repayment_new_recent3singleorderrepayment_onweekendamountratio_v2 -- 最近第3笔订单还款特征_周末还款金额占比
,
      ROUND(
        CASE
          WHEN COALESCE(
            MAX(
              CASE
                WHEN rf.prev_order_num = 3 THEN rf.cnt
              END
            ),
            0
          ) > 0 THEN COALESCE(
            MAX(
              CASE
                WHEN rf.prev_order_num = 3 THEN rf.on_weekend_cnt
              END
            ),
            0
          ) / CAST(
            MAX(
              CASE
                WHEN rf.prev_order_num = 3 THEN rf.cnt
              END
            ) AS FLOAT
          )
          ELSE 0
        END,
        6
      ) AS local_olduser_repayment_new_recent3singleorderrepayment_onweekendratio_v2 -- 最近第3笔订单还款特征_周末还款次数占比
    FROM
      (
        SELECT
          DISTINCT cust_no,
          use_credit_apply_id,
          use_create_time
        FROM
          base_loan_data
      ) bld
      LEFT JOIN repayment_features rf ON bld.cust_no = rf.cust_no
      AND bld.use_credit_apply_id = rf.use_credit_apply_id
      AND bld.use_create_time = rf.use_create_time
    GROUP BY
      bld.cust_no,
      bld.use_credit_apply_id,
      bld.use_create_time
  ) t
where
  use_create_time >= '2026-01-06 00:00:00'order by use_create_time;