-- name 23个特征新的
-- type StarRocks
-- author zhanglifeng703@hellobike.com
-- create time 2026-01-12 00:19:18
-- desc 
WITH ua AS (
  SELECT
    ua.id          AS ua_id,
    ua.asset_id    AS asset_id,
    ua.cust_no,
    ua.create_time AS ua_time,
    DATE(ua.create_time) AS ua_date
  FROM fintech.dwd_rsk_approve_use_credit_apply_rt ua
  WHERE  EXISTS (
      SELECT 1
      FROM fintech.dwd_rsk_approve_use_credit_apply_rt x
      WHERE x.cust_no = ua.cust_no
        AND x.create_time >= '2025-12-01'
    )
),

ua_agg AS (
  SELECT cust_no, asset_id, MAX(ua_time) AS ua_time
  FROM ua
  GROUP BY cust_no, asset_id
),

latest_order AS (
  SELECT *
  FROM (
    SELECT ua.*,
           ROW_NUMBER() OVER (PARTITION BY ua.cust_no ORDER BY ua.ua_time DESC) rn
    FROM ua_agg ua
  ) t
  WHERE rn = 1
),

-- 历史订单（包含当前单；仅用 ua_time 及以前）
hist_orders AS (
  SELECT
    cur.cust_no,
    cur.asset_id  AS cur_asset_id,
    cur.ua_time   AS cur_ua_time,
    DATE(cur.ua_time) AS cur_ua_date,
    hist.asset_id AS hist_asset_id,
    hist.ua_time  AS hist_ua_time,
    DATE(hist.ua_time) AS hist_ua_date
  FROM latest_order cur
  JOIN ua_agg hist
    ON hist.cust_no = cur.cust_no
   AND hist.ua_time <= cur.ua_time
),

-- 额度记录（不按日拆分；不限定 pt，是否穿越由 cl_time ≤ hist_ua_time 控制）
limit_fixed AS (
  SELECT
    cl.cust_no,
    cl.seq_no       AS asset_id,
    cl.create_time  AS cl_time,
    cl.before_total_limit,
    cl.after_pre_use_limit
  FROM fintech.dwd_rsk_cust_credit_limit_record_rt cl
  WHERE (cl.limit_type = 0 OR cl.limit_type IS NULL OR TRIM(CAST(cl.limit_type AS STRING)) = '')
    AND cl.type IN (2,4)
),

limit_temp AS (
  SELECT
    cl.cust_no,
    cl.seq_no       AS asset_id,
    cl.create_time  AS cl_time,
    cl.before_total_limit,
    cl.after_pre_use_limit
  FROM fintech.dwd_rsk_cust_credit_limit_record_rt cl
  WHERE cl.limit_type = 2
    AND cl.type IN (2,4)
),

-- 为每个历史订单挑 cl_time ≤ hist_ua_time 的最近一条固定额度快照
pick_fixed AS (
  SELECT *
  FROM (
    SELECT
      h.cust_no, h.cur_asset_id, h.cur_ua_time, h.hist_asset_id, h.hist_ua_time,
      f.before_total_limit  AS before_total_limit_fixed,
      f.after_pre_use_limit AS after_pre_use_limit_fixed,
      ROW_NUMBER() OVER (
        PARTITION BY h.cust_no, h.cur_asset_id, h.cur_ua_time, h.hist_asset_id
        ORDER BY f.cl_time DESC
      ) AS rn
    FROM hist_orders h
    LEFT JOIN limit_fixed f
      ON f.cust_no  = h.cust_no
     AND f.asset_id = h.hist_asset_id
     AND f.cl_time <= h.hist_ua_time
  ) t
  WHERE rn = 1
),

-- 为每个历史订单挑 cl_time ≤ hist_ua_time 的最近一条临额快照
pick_temp AS (
  SELECT *
  FROM (
    SELECT
      h.cust_no, h.cur_asset_id, h.cur_ua_time, h.hist_asset_id, h.hist_ua_time,
      t.before_total_limit  AS before_total_limit_temp,
      t.after_pre_use_limit AS after_pre_use_limit_temp,
      ROW_NUMBER() OVER (
        PARTITION BY h.cust_no, h.cur_asset_id, h.cur_ua_time, h.hist_asset_id
        ORDER BY t.cl_time DESC
      ) AS rn
    FROM hist_orders h
    LEFT JOIN limit_temp t
      ON t.cust_no  = h.cust_no
     AND t.asset_id = h.hist_asset_id
     AND t.cl_time <= h.hist_ua_time
  ) z
  WHERE rn = 1
),

-- 计算单单使用率（固定 & 有效）
usage_per_hist AS (
  SELECT
    h.cust_no,
    h.cur_asset_id,
    h.cur_ua_time,
    h.hist_asset_id,

    pf.before_total_limit_fixed,
    pf.after_pre_use_limit_fixed,
    COALESCE(pt.before_total_limit_temp, 0)  AS before_total_limit_temp,
    COALESCE(pt.after_pre_use_limit_temp, 0) AS after_pre_use_limit_temp,

    CASE
      WHEN COALESCE(pf.before_total_limit_fixed,0) <= 0 THEN NULL
      ELSE LEAST(COALESCE(pf.after_pre_use_limit_fixed,0), pf.before_total_limit_fixed)
           / pf.before_total_limit_fixed
    END AS credit_usage_ratio_fixed,

    CASE
      WHEN COALESCE(pf.before_total_limit_fixed,0) + COALESCE(pt.before_total_limit_temp,0) <= 0 THEN NULL
      ELSE LEAST(COALESCE(pf.after_pre_use_limit_fixed,0) + COALESCE(pt.after_pre_use_limit_temp,0),
                 COALESCE(pf.before_total_limit_fixed,0) + COALESCE(pt.before_total_limit_temp,0))
           / (COALESCE(pf.before_total_limit_fixed,0) + COALESCE(pt.before_total_limit_temp,0))
    END AS credit_usage_ratio_effective
  FROM hist_orders h
  LEFT JOIN pick_fixed pf
    ON pf.cust_no = h.cust_no
   AND pf.cur_asset_id = h.cur_asset_id
   AND pf.cur_ua_time = h.cur_ua_time
   AND pf.hist_asset_id = h.hist_asset_id
  LEFT JOIN pick_temp pt
    ON pt.cust_no = h.cust_no
   AND pt.cur_asset_id = h.cur_asset_id
   AND pt.cur_ua_time = h.cur_ua_time
   AND pt.hist_asset_id = h.hist_asset_id
),

-- 全量历史订单（含当前）上聚合 min/avg/max
usage_agg AS (
  SELECT
    cust_no,
    cur_asset_id,
    cur_ua_time,
    MIN(credit_usage_ratio_fixed)     AS mincreditusageratio_fixed,
    AVG(credit_usage_ratio_fixed)     AS avgcreditusageratio_fixed,
    MAX(credit_usage_ratio_fixed)     AS maxcreditusageratio_fixed,
    MIN(credit_usage_ratio_effective) AS mincreditusageratio_effective,
    AVG(credit_usage_ratio_effective) AS avgcreditusageratio_effective,
    MAX(credit_usage_ratio_effective) AS maxcreditusageratio_effective
  FROM usage_per_hist
  GROUP BY cust_no, cur_asset_id, cur_ua_time
),

-- 补齐当前单的 ua_id
lo_with_id AS (
  SELECT
    lo.*,
    k.ua_id
  FROM latest_order lo
  LEFT JOIN (
    SELECT cust_no, asset_id, ua_time, MAX(ua_id) AS ua_id
    FROM ua
    GROUP BY cust_no, asset_id, ua_time
  ) k
    ON k.cust_no  = lo.cust_no
   AND k.asset_id = lo.asset_id
   AND k.ua_time  = lo.ua_time
)

select * from(
SELECT
  lo.ua_id,
  lo.cust_no,
  --lo.asset_id  AS cur_asset_id,
  concat(lo.ua_time,'a') as ua_time,
  --固定额度
  CAST(agg.mincreditusageratio_fixed     AS DECIMAL(18,6)) AS local_olduser_uncompleted_mincreditusageratio_fixed_v2,
  CAST(agg.avgcreditusageratio_fixed     AS DECIMAL(18,6)) AS local_olduser_uncompleted_avgcreditusageratio_fixed_v2,
  CAST(agg.maxcreditusageratio_fixed     AS DECIMAL(18,6)) AS local_olduser_uncompleted_maxcreditusageratio_fixed_v2,
  --有效额度
  CAST(agg.mincreditusageratio_effective AS DECIMAL(18,6)) AS local_olduser_uncompleted_mincreditusageratio_effective_v2,
  CAST(agg.avgcreditusageratio_effective AS DECIMAL(18,6)) AS local_olduser_uncompleted_avgcreditusageratio_effective_v2,
  CAST(agg.maxcreditusageratio_effective AS DECIMAL(18,6)) AS local_olduser_uncompleted_maxcreditusageratio_effective_v2
FROM lo_with_id lo
LEFT JOIN usage_agg agg
  ON agg.cust_no      = lo.cust_no
 AND agg.cur_asset_id = lo.asset_id
 And agg.cur_ua_time  = lo.ua_time ) t where ua_time>='2026-01-16 05:37:00'
  order by ua_time desc;