-- name midloan_overdue_ratio
-- type Spark SQL
-- author dongtianyu790@hellobike.com
-- create time 2025-09-17 08:10:44
-- desc 贷中特征中name11的特征
--show create table hello_da.midloan_overdue_ratio;
--DROP table hello_da.midloan_overdue_ratio;

-- CREATE TABLE IF NOT EXISTS hello_da.midloan_overdue_ratio(
--     `ua_id` BIGINT COMMENT'ID',
--     `cust_no` STRING COMMENT'cust no',
--     `ua_time` STRING COMMENT'Creation time',
--     `ua_date` DATE,
--     `total_mature_count` BIGINT,
--     `overdue_1d_ratio` DECIMAL(38,4) ,
--     `overdue_3d_ratio` DECIMAL(38,4) ,
--     `overdue_5d_ratio` DECIMAL(38,4) ,
--     `overdue_7d_ratio` DECIMAL(38,4) ,
--     `overdue_10d_ratio` DECIMAL(38,4) 
--  )partitioned by (pt string comment '贷中逾期和到期的比值特征')
-- stored as orc lifecycle 365;

insert overwrite table hello_da.midloan_overdue_ratio
partition (pt = '${bdp.system.bizdate2}')

-- *** """NAME11:overdue_1d_ratio 逾期为1天的期数与该用户到期期数的比值""" --
SELECT 
    r.ua_id,
    r.cust_no,
    r.ua_time,
    r.ua_date,
    COALESCE(c.total_mature_count, 0) AS total_mature_count,
    -- 各逾期天数的还款占比
    CASE 
        WHEN COALESCE(c.total_mature_count, 0) = 0 THEN 0 
        ELSE ROUND(COALESCE(c.overdue_1_count, 0) * 1.0 / c.total_mature_count, 4) 
    END AS overdue_1d_ratio,
    CASE 
        WHEN COALESCE(c.total_mature_count, 0) = 0 THEN 0 
        ELSE ROUND(COALESCE(c.overdue_3_count, 0) * 1.0 / c.total_mature_count, 4) 
    END AS overdue_3d_ratio,
    CASE 
        WHEN COALESCE(c.total_mature_count, 0) = 0 THEN 0 
        ELSE ROUND(COALESCE(c.overdue_5_count, 0) * 1.0 / c.total_mature_count, 4) 
    END AS overdue_5d_ratio,
    CASE 
        WHEN COALESCE(c.total_mature_count, 0) = 0 THEN 0 
        ELSE ROUND(COALESCE(c.overdue_7_count, 0) * 1.0 / c.total_mature_count, 4) 
    END AS overdue_7d_ratio,
    CASE 
        WHEN COALESCE(c.total_mature_count, 0) = 0 THEN 0 
        ELSE ROUND(COALESCE(c.overdue_10_count, 0) * 1.0 / c.total_mature_count, 4) 
    END AS overdue_10d_ratio
FROM (
    SELECT DISTINCT
        ua_id,
        cust_no,
        ua_time,
        CAST(ua_time AS DATE) AS ua_date
    FROM hello_da.dty_kb_features_hive 
    WHERE pt = '${bdp.system.bizdate2}'
) r
LEFT JOIN (
    SELECT 
        r_sub.ua_id,
        r_sub.cust_no,
        r_sub.ua_time,
        COUNT(1) AS total_mature_count,
        SUM(CASE WHEN DATEDIFF(date(h.settled_time), h.loan_end_date) = 1 THEN 1 ELSE 0 END) AS overdue_1_count,
        SUM(CASE WHEN DATEDIFF(date(h.settled_time), h.loan_end_date) = 3 THEN 1 ELSE 0 END) AS overdue_3_count,
        SUM(CASE WHEN DATEDIFF(date(h.settled_time), h.loan_end_date) = 5 THEN 1 ELSE 0 END) AS overdue_5_count,
        SUM(CASE WHEN DATEDIFF(date(h.settled_time), h.loan_end_date) = 7 THEN 1 ELSE 0 END) AS overdue_7_count,
        SUM(CASE WHEN DATEDIFF(date(h.settled_time), h.loan_end_date) = 10 THEN 1 ELSE 0 END) AS overdue_10_count
    FROM (
        SELECT DISTINCT
            ua_id,
            cust_no,
            ua_time,
            CAST(ua_time AS DATE) AS ua_date
        FROM hello_da.dty_kb_features_hive 
        WHERE pt = '${bdp.system.bizdate2}'
    ) r_sub
    LEFT JOIN (
        SELECT * 
        FROM hello_prd.ods_mx_ast_asset_repay_plan_df 
        WHERE pt = '${bdp.system.bizdate2}' and  repay_plan_status != 4
    ) h ON r_sub.cust_no = h.cust_no
    WHERE h.loan_end_date <= r_sub.ua_date
      AND h.create_time < r_sub.ua_time
      AND h.settled_time < r_sub.ua_time --1120修
    GROUP BY r_sub.ua_id, r_sub.cust_no, r_sub.ua_time
) c ON r.ua_id = c.ua_id 
    AND r.cust_no = c.cust_no 
    AND r.ua_time = c.ua_time