 --DROP TABLE IF EXISTS hello_da.midloan_overdue_features;

-- CREATE TABLE IF NOT EXISTS hello_da.midloan_overdue_features(
--     `ua_id` BIGINT,
--     `cust_no` STRING,
--     `ua_time` STRING,
--     `ua_date` DATE,
--     `days_since_first_overdue` BIGINT,
--     `last_3_term_is_overdue` INT,
--     `last_3_term_overdue` INT,
--     `last_5_term_is_overdue` INT,
--     `last_5_term_overdue` INT,
--     `last_10_term_is_overdue` INT,
--     `last_10_term_overdue` INT,
--     `last_1_period_is_overdue` INT,
--     `last_1_period_overdue` INT,
--     `last_2_period_is_overdue` INT,
--     `last_2_period_overdue` INT,
--     `last_3_period_is_overdue` INT,
--     `last_3_period_overdue` INT,
--     `last_4_period_is_overdue` INT,
--     `last_4_period_overdue` INT,
--     `first_ontime_days_ago` BIGINT,
--     `total_assets_15d` BIGINT,
--     `last_15d_assets_over_0d` BIGINT,
--     `last_15d_assets_over_0d_ratio` DOUBLE,
--     `total_assets_30d` BIGINT,
--     `last_30d_assets_over_0d` BIGINT,
--     `last_30d_assets_over_0d_ratio` DOUBLE,
--     `total_assets_45d` BIGINT,
--     `last_45d_assets_over_0d` BIGINT,
--     `last_45d_assets_over_0d_ratio` DOUBLE,
--     `total_assets_60d` BIGINT,
--     `last_60d_assets_over_0d` BIGINT,
--     `last_60d_assets_over_0d_ratio` DOUBLE,
--     `total_assets_90d` BIGINT,
--     `last_90d_assets_over_0d` BIGINT,
--     `last_90d_assets_over_0d_ratio` DOUBLE,
--     `last_overdue_1d` BIGINT,
--     `last_overdue_3d` BIGINT,
--     `last_overdue_5d` BIGINT,
--     `last_overdue_7d` BIGINT,
--     `last_overdue_10d` BIGINT,
--     `last_overdue_11d` BIGINT,
--     `last_overdue_13d` BIGINT
--  )partitioned by (pt string comment '贷中逾期相关特征')
-- stored as orc lifecycle 365;

insert overwrite table hello_da.midloan_overdue_features
partition (pt = '${bdp.system.bizdate2}')

SELECT 
    ua_id,
    cust_no,
    ua_time,
    ua_date,

    -- *** """NAME10 首次逾期还款距今天数days_since_first_overdue
    CASE 
        WHEN first_overdue_date IS NOT NULL 
             AND first_overdue_date < ua_time
        THEN FLOOR((unix_timestamp(ua_time) - unix_timestamp(first_overdue_date))/(3600*24))
        ELSE -1  -- 标识无逾期记录
    END AS days_since_first_overdue,
    
    -- *** """NAME4: 用户近3，5，10期内逾期天数的最大值last_{day}_term_overdue,以及是否逾期；用户n期的逾期天数以及是否逾期last_{day}_period_overdue"""
    -- 用户近3期内逾期天数的最大值,以及是否逾期
    MAX(CASE WHEN rank_num <= 3 THEN CAST(overdue_days > 0 AS INT) ELSE NULL END) AS last_3_term_is_overdue,
    MAX(CASE WHEN rank_num <= 3 THEN overdue_days ELSE NULL END) AS last_3_term_overdue,
    -- 用户近5期内逾期天数的最大值,以及是否逾期
    MAX(CASE WHEN rank_num <= 5 THEN CAST(overdue_days > 0 AS INT) ELSE NULL END) AS last_5_term_is_overdue,
    MAX(CASE WHEN rank_num <= 5 THEN overdue_days ELSE NULL END) AS last_5_term_overdue,
    -- 用户近10期内逾期天数的最大值,以及是否逾期
    MAX(CASE WHEN rank_num <= 10 THEN CAST(overdue_days > 0 AS INT) ELSE NULL END) AS last_10_term_is_overdue,
    MAX(CASE WHEN rank_num <= 10 THEN overdue_days ELSE NULL END) AS last_10_term_overdue,
    -- 用户最近1期的逾期天数，以及是否逾期
    MAX(CASE WHEN rank_num = 1 THEN CAST(overdue_days > 0 AS INT) ELSE NULL END) AS last_1_period_is_overdue,
    MAX(CASE WHEN rank_num = 1 THEN overdue_days ELSE NULL END) AS last_1_period_overdue,
    --用户最近第2期的逾期天数，以及是否逾期
    MAX(CASE WHEN rank_num = 2 THEN CAST(overdue_days > 0 AS INT) ELSE NULL END) AS last_2_period_is_overdue,
    MAX(CASE WHEN rank_num = 2 THEN overdue_days ELSE NULL END) AS last_2_period_overdue,
    --用户最近第3期的逾期天数，以及是否逾期
    MAX(CASE WHEN rank_num = 3 THEN CAST(overdue_days > 0 AS INT) ELSE NULL END) AS last_3_period_is_overdue,
    MAX(CASE WHEN rank_num = 3 THEN overdue_days ELSE NULL END) AS last_3_period_overdue,
    --用户最近第4期的逾期天数，以及是否逾期
    MAX(CASE WHEN rank_num = 4 THEN CAST(overdue_days > 0 AS INT) ELSE NULL END) AS last_4_period_is_overdue,
    MAX(CASE WHEN rank_num = 4 THEN overdue_days ELSE NULL END) AS last_4_period_overdue,

    -- *** """NAME9: first_ontime_days_ago 首次按时还款距今天数"""--
    FLOOR((unix_timestamp(ua_time) - unix_timestamp(first_ontime_settled_time))/(3600*24)) AS first_ontime_days_ago,
    
    -- *** """NAME5: 用户近3，5，10期内逾期天数的最大值last_{day}_term_overdue,以及是否逾期；用户n期的逾期天数以及是否逾期last_{day}_period_overdue"""
    -- 15天窗口
    COUNT(DISTINCT CASE WHEN settled_time >= DATE_SUB(ua_time, 15) AND settled_time < ua_time THEN loan_no END) AS total_assets_15d,
    COUNT(DISTINCT CASE WHEN settled_time >= DATE_SUB(ua_time, 15) AND settled_time < ua_time AND overdue_days > 0 THEN loan_no END) AS last_15d_assets_over_0d,
    CASE WHEN COUNT(DISTINCT CASE WHEN settled_time >= DATE_SUB(ua_time, 15) AND settled_time < ua_time THEN loan_no END) > 0 
         THEN ROUND(CAST(COUNT(DISTINCT CASE WHEN settled_time >= DATE_SUB(ua_time, 15) AND settled_time < ua_time AND overdue_days > 0 THEN loan_no END) AS DOUBLE) / 
                    COUNT(DISTINCT CASE WHEN settled_time >= DATE_SUB(ua_time, 15) AND settled_time < ua_time THEN loan_no END), 4) 
         ELSE 0.0 END AS last_15d_assets_over_0d_ratio,
    
    -- 30天窗口
    COUNT(DISTINCT CASE WHEN settled_time >= DATE_SUB(ua_time, 30) AND settled_time < ua_time THEN loan_no END) AS total_assets_30d,
    COUNT(DISTINCT CASE WHEN settled_time >= DATE_SUB(ua_time, 30) AND settled_time < ua_time AND overdue_days > 0 THEN loan_no END) AS last_30d_assets_over_0d,
    CASE WHEN COUNT(DISTINCT CASE WHEN settled_time >= DATE_SUB(ua_time, 30) AND settled_time < ua_time THEN loan_no END) > 0 
         THEN ROUND(CAST(COUNT(DISTINCT CASE WHEN settled_time >= DATE_SUB(ua_time, 30) AND settled_time < ua_time AND overdue_days > 0 THEN loan_no END) AS DOUBLE) / 
                COUNT(DISTINCT CASE WHEN settled_time >= DATE_SUB(ua_time, 30) AND settled_time < ua_time THEN loan_no END), 4) 
         ELSE 0.0 END AS last_30d_assets_over_0d_ratio,

    -- 45天窗口
    COUNT(DISTINCT CASE WHEN settled_time >= DATE_SUB(ua_time, 45) AND settled_time < ua_time THEN loan_no END) AS total_assets_45d,
    COUNT(DISTINCT CASE WHEN settled_time >= DATE_SUB(ua_time, 45) AND settled_time < ua_time AND overdue_days > 0 THEN loan_no END) AS last_45d_assets_over_0d,
    CASE WHEN COUNT(DISTINCT CASE WHEN settled_time >= DATE_SUB(ua_time, 45) AND settled_time < ua_time THEN loan_no END) > 0 
         THEN ROUND(CAST(COUNT(DISTINCT CASE WHEN settled_time >= DATE_SUB(ua_time, 45) AND settled_time < ua_time AND overdue_days > 0 THEN loan_no END) AS DOUBLE) / 
                COUNT(DISTINCT CASE WHEN settled_time >= DATE_SUB(ua_time, 45) AND settled_time < ua_time THEN loan_no END), 4) 
         ELSE 0.0 END AS last_45d_assets_over_0d_ratio,

    -- 60天窗口
    COUNT(DISTINCT CASE WHEN settled_time >= DATE_SUB(ua_time, 60) AND settled_time < ua_time THEN loan_no END) AS total_assets_60d,
    COUNT(DISTINCT CASE WHEN settled_time >= DATE_SUB(ua_time, 60) AND settled_time < ua_time AND overdue_days > 0 THEN loan_no END) AS last_60d_assets_over_0d,
    CASE WHEN COUNT(DISTINCT CASE WHEN settled_time >= DATE_SUB(ua_time, 60) AND settled_time < ua_time THEN loan_no END) > 0 
         THEN ROUND(CAST(COUNT(DISTINCT CASE WHEN settled_time >= DATE_SUB(ua_time, 60) AND settled_time < ua_time AND overdue_days > 0 THEN loan_no END) AS DOUBLE) / 
                COUNT(DISTINCT CASE WHEN settled_time >= DATE_SUB(ua_time, 60) AND settled_time < ua_time THEN loan_no END), 4) 
         ELSE 0.0 END AS last_60d_assets_over_0d_ratio,
    
    -- 90天窗口
    COUNT(DISTINCT CASE WHEN settled_time >= DATE_SUB(ua_time, 90) AND settled_time < ua_time THEN loan_no END) AS total_assets_90d,
    COUNT(DISTINCT CASE WHEN settled_time >= DATE_SUB(ua_time, 90) AND settled_time < ua_time AND overdue_days > 0 THEN loan_no END) AS last_90d_assets_over_0d,
    CASE WHEN COUNT(DISTINCT CASE WHEN settled_time >= DATE_SUB(ua_time, 90) AND settled_time < ua_time THEN loan_no END) > 0 
         THEN ROUND(CAST(COUNT(DISTINCT CASE WHEN settled_time >= DATE_SUB(ua_time, 90) AND settled_time < ua_time AND overdue_days > 0 THEN loan_no END) AS DOUBLE) / 
                COUNT(DISTINCT CASE WHEN settled_time >= DATE_SUB(ua_time, 90) AND settled_time < ua_time THEN loan_no END), 4) 
         ELSE 0.0 END AS last_90d_assets_over_0d_ratio,

   -- *** """NAME8:last_overdue_{day}d 最近一次逾期1/3/5/7/10/11/12/13/14天还款距今的天数"""
    -- 最近一次逾期1天还款距今天数
    MAX(CASE WHEN overdue_days = 1 THEN FLOOR((unix_timestamp(ua_time) - unix_timestamp(last_settled_time))/(3600*24)) ELSE NULL END) AS last_overdue_1d,
    -- 最近一次逾期3天还款距今天数
    MAX(CASE WHEN overdue_days = 3 THEN FLOOR((unix_timestamp(ua_time) - unix_timestamp(last_settled_time))/(3600*24)) ELSE NULL END) AS last_overdue_3d,
    -- 最近一次逾期5天还款距今天数
    MAX(CASE WHEN overdue_days = 5 THEN FLOOR((unix_timestamp(ua_time) - unix_timestamp(last_settled_time))/(3600*24)) ELSE NULL END) AS last_overdue_5d,
    -- 最近一次逾期7天还款距今天数
    MAX(CASE WHEN overdue_days = 7 THEN FLOOR((unix_timestamp(ua_time) - unix_timestamp(last_settled_time))/(3600*24)) ELSE NULL END) AS last_overdue_7d,
    -- 最近一次逾期10天还款距今天数
    MAX(CASE WHEN overdue_days = 10 THEN FLOOR((unix_timestamp(ua_time) - unix_timestamp(last_settled_time))/(3600*24)) ELSE NULL END) AS last_overdue_10d,
    -- 最近一次逾期11天还款距今天数
    MAX(CASE WHEN overdue_days = 11 THEN FLOOR((unix_timestamp(ua_time) - unix_timestamp(last_settled_time))/(3600*24)) ELSE NULL END) AS last_overdue_11d,
    -- 最近一次逾期13天还款距今天数
    MAX(CASE WHEN overdue_days = 13 THEN FLOOR((unix_timestamp(ua_time) - unix_timestamp(last_settled_time))/(3600*24)) ELSE NULL END) AS last_overdue_13d

FROM (
    SELECT 
        du.ua_id,
        du.cust_no,
        du.ua_time,
        du.ua_date,
        h.loan_no,
        h.settled_time,
        h.loan_end_date,
        DATEDIFF(date(h.settled_time), h.loan_end_date) as overdue_days,
        
        -- 排名特征（用于逾期特征）
        ROW_NUMBER() OVER (PARTITION BY du.ua_id, du.cust_no ORDER BY h.loan_end_date DESC,h.id ASC) as rank_num,-- 墨西哥时间11月16日21:33分修改，按照h.id ASC来跑
        
        -- 首次按时还款时间（用于时间特征）
        MIN(CASE WHEN DATEDIFF(date(h.settled_time), h.loan_end_date) = 0 THEN h.settled_time END) 
            OVER (PARTITION BY du.ua_id, du.cust_no, du.ua_time) AS first_ontime_settled_time,
            
        -- 每种逾期天数的最新还款时间
        MAX(h.settled_time) OVER (PARTITION BY du.ua_id, du.cust_no, du.ua_time, DATEDIFF(date(h.settled_time), h.loan_end_date)) AS last_settled_time,
            
        -- 首次逾期时间（新增）
        MIN(CASE WHEN DATEDIFF(date(h.settled_time), h.loan_end_date) > 0 THEN h.settled_time END) 
            OVER (PARTITION BY du.ua_id, du.cust_no, du.ua_time) AS first_overdue_date
            
    FROM (
        SELECT DISTINCT 
            ua_id,
            cust_no,
            ua_time,
            CAST(ua_time AS DATE) AS ua_date
        FROM hello_da.dty_kb_features_hive WHERE pt = '${bdp.system.bizdate2}'
    ) du
    LEFT JOIN (
        SELECT 
            id,
            cust_no,
            loan_no,
            settled_time,
            loan_end_date,
            create_time,
            DATEDIFF(date(settled_time), loan_end_date) as overdue_days
        FROM hello_prd.ods_mx_ast_asset_repay_plan_df WHERE pt = '${bdp.system.bizdate2}' and repay_plan_status != 4
    ) h ON du.cust_no = h.cust_no
        WHERE h.create_time < du.ua_time
        AND h.loan_end_date <= du.ua_date
        AND h.settled_time < du.ua_time
) combined_data
GROUP BY ua_id, cust_no, ua_time, ua_date, first_ontime_settled_time, first_overdue_date;