WITH base_loan_data AS (
  SELECT DISTINCT
         ua.id          AS ua_id,
         ua.create_time AS ua_time,
         ua.cust_no,
         li.loan_no     AS current_loan_no
  FROM fintech.dwd_rsk_approve_use_credit_apply_rt ua
  LEFT JOIN fintech.dwd_rsk_asset_loan_apply_rt la
    ON la.seq_no = ua.asset_id
  LEFT JOIN fintech.dwd_trd_ast_loan_info_rt li
    ON li.loan_apply_no = la.loan_apply_no
   AND li.loan_status <> 4
   AND (li.optype <> 'DELETE' OR li.optype IS NULL)
  WHERE li.loan_no IS NOT NULL
),

-- 统计时点集合
applications AS (
  SELECT DISTINCT ua_id, ua_time, cust_no, current_loan_no
  FROM base_loan_data
),

-- 每笔订单的自身申请时间（用于圈定“历史订单”：loan_ua_time < t.ua_time）
loans_dim AS (
  SELECT
    a.cust_no,
    a.current_loan_no AS loan_no,
    MIN(a.ua_time)    AS loan_ua_time
  FROM applications a
  GROUP BY a.cust_no, a.current_loan_no
),

-- 对每个 t，取其之前的历史订单
t_loans AS (
  SELECT t.cust_no, t.ua_id, t.ua_time, ld.loan_no
  FROM applications t
  JOIN loans_dim ld
    ON ld.cust_no = t.cust_no
   AND ld.loan_ua_time < t.ua_time
),

-- 在 t 的 as-of 视角下取历史订单的分期（仅纳入 rp.create_time < t.ua_time）
inst_asof AS (
  SELECT
    tl.cust_no, tl.ua_id, tl.ua_time, tl.loan_no,
    rp.periods, rp.loan_end_date, rp.settled_time, rp.id AS rp_id
  FROM t_loans tl
  JOIN fintech.dwd_trd_ast_repay_plan_rt rp
    ON rp.repay_plan_status <> 4
   AND (rp.optype <> 'DELETE' OR rp.optype IS NULL)
   AND rp.loan_no = tl.loan_no
   AND rp.create_time IS NOT NULL
   AND rp.create_time < tl.ua_time
),

-- 在 t 的时点对历史订单逐期打标，并用 LAG 判断相邻两期
inst_flags AS (
  SELECT
    i.cust_no, i.ua_id, i.ua_time, i.loan_no,
    i.periods, i.loan_end_date, i.settled_time,

    CASE
      WHEN i.settled_time IS NOT NULL
       AND i.settled_time <= i.ua_time
       AND i.settled_time  <  i.loan_end_date
      THEN 1 ELSE 0
    END AS is_prepay_inst,

    CASE
      WHEN i.settled_time IS NOT NULL
       AND i.settled_time <= i.ua_time
       AND date(i.settled_time)  >  i.loan_end_date
      THEN 1
      WHEN (i.settled_time IS NULL OR i.settled_time > i.ua_time)
       AND date(i.ua_time) > i.loan_end_date
      THEN 1
      ELSE 0
    END AS is_overdue_asof,

    LAG(
      CASE
        WHEN i.settled_time IS NOT NULL
         AND i.settled_time <= i.ua_time
         AND i.settled_time  <  i.loan_end_date
        THEN 1 ELSE 0
      END
    ) OVER (
      PARTITION BY i.cust_no, i.ua_id, i.ua_time, i.loan_no
      ORDER BY COALESCE(i.loan_end_date, i.periods), i.periods, i.rp_id
    ) AS prev_is_prepay_inst,

    LAG(
      CASE
        WHEN i.settled_time IS NOT NULL
         AND i.settled_time < i.ua_time
         AND date(i.settled_time)  >  i.loan_end_date
        THEN 1
        WHEN (i.settled_time IS NULL OR i.settled_time > i.ua_time)
         AND date(i.ua_time) > i.loan_end_date
        THEN 1
        ELSE 0
      END
    ) OVER (
      PARTITION BY i.cust_no, i.ua_id, i.ua_time, i.loan_no
      ORDER BY COALESCE(i.loan_end_date, i.periods), i.periods, i.rp_id
    ) AS prev_is_overdue_asof
  FROM inst_asof i
),

-- 历史订单是否出现“相邻两期均为1”
loan_pair_flags AS (
  SELECT
    cust_no, ua_id, ua_time, loan_no,
    MAX(CASE WHEN is_overdue_asof = 1 AND prev_is_overdue_asof = 1 THEN 1 ELSE 0 END) AS has_consecutive_overdue,
    MAX(CASE WHEN is_prepay_inst  = 1 AND prev_is_prepay_inst  = 1 THEN 1 ELSE 0 END) AS has_consecutive_prepay
  FROM inst_flags
  GROUP BY cust_no, ua_id, ua_time, loan_no
),

-- 按 t 累计“历史上出现连续两期”的订单个数
history_consecutive_counts AS (
  SELECT
    ua_id, ua_time, cust_no,
    COUNT(DISTINCT CASE WHEN has_consecutive_overdue = 1 THEN loan_no END)  AS hist_consecutive_overdue_orders,
    COUNT(DISTINCT CASE WHEN has_consecutive_prepay  = 1 THEN loan_no END)  AS hist_consecutive_prepayment_orders
  FROM loan_pair_flags
  GROUP BY ua_id, ua_time, cust_no
)

select * from (
SELECT
  a.ua_id,
  a.ua_time,
  a.cust_no,
  COALESCE(hcc.hist_consecutive_overdue_orders,   0) AS local_olduser_order_totalorderriskvo_continuousoverdueorders_v2,
  COALESCE(hcc.hist_consecutive_prepayment_orders,0) AS local_olduser_order_totalorderriskvo_continuousprepaymentorders_v2
FROM applications a
LEFT JOIN history_consecutive_counts hcc
  ON hcc.cust_no = a.cust_no AND hcc.ua_id = a.ua_id AND hcc.ua_time = a.ua_time) t
where ua_time>='2026-01-08 01:29:30'
order by ua_time desc;