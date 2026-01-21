--DROP TABLE IF EXISTS hello_da.dty_kb_features_hive;


-- !在子查询中先过滤分区
-- 创建表
-- CREATE TABLE hello_da.dty_kb_features_hive
-- (
--     `ua_id` BIGINT COMMENT 'ID',
--     `ua_time` STRING COMMENT 'Creation time',
--     `cust_no` STRING COMMENT 'cust no',
--     `ca_user_type` BIGINT COMMENT 'User type 1:new user 2:old user',
--     `asset_id` STRING COMMENT 'Related use credit apply ID',
--     `la_seq_no` STRING COMMENT '申请流水号',
--     `li_loan_apply_no` STRING COMMENT '借据号',
--     `la_loan_apply_no` STRING COMMENT '申请单号',
--     `rp_id` STRING,
--     `rp_cust_no` STRING COMMENT '借据号',
--     `settled_time` STRING COMMENT '结清时间',
--     `loan_end_date` STRING COMMENT '分期结束日期',
--     `loan_no` STRING COMMENT '借据号',
--     `li_id` BIGINT COMMENT 'id',
--     `plat_status` STRING COMMENT '返回状态',
--     `pay_time` STRING COMMENT '资方放款日期',
--     `principal_all` DECIMAL(33,8),
--     `repay_plan_time` STRING COMMENT '创建日期时间',
--     `overdue_days` INT
-- )
-- COMMENT '贷中特征底表'
-- PARTITIONED BY (`pt` STRING COMMENT '分区日期')
-- STORED AS ORC 
-- LIFECYCLE 365;

-- 插入数据到指定分区
insert overwrite table hello_da.dty_kb_features_hive PARTITION (pt = '${bdp.system.bizdate2}')
SELECT 
    ua.id as ua_id,
    ua.create_time as ua_time,
    ua.cust_no,
    ca.user_type as ca_user_type, 
    ua.asset_id,
    la.seq_no as la_seq_no,
    li.loan_apply_no as li_loan_apply_no,
    la.loan_apply_no as la_loan_apply_no,
    CAST(rp.id as STRING) as rp_id,
    rp.cust_no as rp_cust_no,
    rp.settled_time, 
    rp.loan_end_date,
    rp.loan_no,
    li.id as li_id,
    pf.plat_status,
    pf.pay_time, 
    -- 如果是分区,每天principal都是应还本金，不会更新
    (rp.principal + rp.repaid_principal) as principal_all,
    -- rp.principal as principal_all,
    rp.create_time as repay_plan_time,
    DATEDIFF(date(rp.settled_time), rp.loan_end_date) as overdue_days
FROM (SELECT * FROM hello_prd.ods_mx_aprv_approve_use_credit_apply_df WHERE pt = '${bdp.system.bizdate2}' and SUBSTR(create_time,1,10) = '${bdp.system.bizdate2}') ua
LEFT JOIN (SELECT * FROM hello_prd.ods_mx_aprv_approve_credit_apply_df WHERE pt = '${bdp.system.bizdate2}') ca 
    ON ca.id = CAST(ua.credit_apply_id as STRING)
LEFT JOIN (SELECT * FROM hello_prd.ods_mx_ast_asset_loan_apply_df WHERE pt = '${bdp.system.bizdate2}') la 
    ON la.seq_no = ua.asset_id
LEFT JOIN (SELECT * FROM hello_prd.ods_mx_ast_asset_loan_info_df WHERE pt = '${bdp.system.bizdate2}' and loan_status != 4 ) li --枚举值4为取消订单
    ON li.loan_apply_no = la.loan_apply_no
LEFT JOIN (SELECT * FROM hello_prd.ods_mx_ast_asset_pay_founder_loan_flow_df WHERE pt = '${bdp.system.bizdate2}') pf 
    ON li.loan_apply_no = pf.loan_apply_no
LEFT JOIN (SELECT * FROM hello_prd.ods_mx_ast_asset_repay_plan_df WHERE pt = '${bdp.system.bizdate2}' and repay_plan_status != 4) rp  --枚举值4为取消订单
    ON rp.loan_no = li.loan_no;
--WHERE rp.id IS NOT NULL;


--DROP TABLE IF EXISTS hello_da.midloan_credit_occupation;

-- CREATE TABLE hello_da.midloan_credit_occupation(
--     `ua_id` BIGINT,
--     `ua_time` STRING,
--     `cust_no` STRING,
--     `ua_date` DATE,
--     `current_credit_occupation` DOUBLE,
--     `current_credit_occupation_2` DOUBLE
--  )partitioned by (pt string comment '额度使用率的贷中特征')
-- stored as orc lifecycle 365;

insert overwrite table hello_da.midloan_credit_occupation
partition (pt = '${bdp.system.bizdate2}')
-- name6 current_credit_occupation当前用信额度占用率,current_credit_occupation_2当前用信额度 比上 授信额度的平方
SELECT
    ua.id as ua_id,
    ua.create_time as ua_time,
    ua.cust_no,
    TO_DATE(ua.create_time) as ua_date,
    -- current_credit_occupation
    CASE 
        WHEN before_total_limit = 0 THEN 0
        WHEN after_pre_use_limit / before_total_limit > 1 THEN 1
        ELSE ROUND(CAST(after_pre_use_limit AS DOUBLE) / before_total_limit, 2)
    END AS current_credit_occupation,
    
    -- current_credit_occupation_2  
    CASE 
        WHEN before_total_limit = 0 THEN 0
        ELSE ROUND(CAST(after_pre_use_limit AS DOUBLE) / POWER(before_total_limit, 2), 4)
    END AS current_credit_occupation_2

FROM (SELECT * FROM hello_prd.ods_mx_aprv_approve_use_credit_apply_df WHERE pt = '${bdp.system.bizdate2}' AND SUBSTR(create_time,1,10) = '${bdp.system.bizdate2}') ua
LEFT JOIN (SELECT * FROM hello_prd.ods_mx_aprv_cust_credit_limit_record_df WHERE pt = '${bdp.system.bizdate2}' and type IN (2, 4) and (limit_type=0 or limit_type is null)) cl
    ON cl.cust_no = ua.cust_no
WHERE  cl.create_time < ua.create_time
    AND TO_DATE(cl.create_time) = TO_DATE(ua.create_time)
    AND ua.asset_id = cl.seq_no;

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

    --SHOW create TABLE hello_da.midloan_prepay_ratio;
--DROP TABLE hello_da.midloan_prepay_ratio;

-- CREATE TABLE IF NOT EXISTS hello_da.midloan_prepay_ratio (
--     `ua_id` BIGINT,
--     `cust_no` STRING,
--     `ua_time` STRING,
--     `ua_date` STRING,
--     `prepay_ratio` DECIMAL(26,4) 
--  )partitioned by (pt string comment '贷中用户到期期次和放款成功笔数占比')
-- stored as orc lifecycle 365;

insert overwrite table hello_da.midloan_prepay_ratio
partition (pt = '${bdp.system.bizdate2}')

-- *** """NAME7 prepay_ratio用户到期期次和放款成功笔数占比""" 
SELECT 
    r.ua_id,
    r.cust_no,
    r.ua_time,
    SUBSTR(r.ua_time,1,10) AS ua_date,
    CASE WHEN loan_count > 0 THEN ROUND(mature_count * 1.0 / loan_count, 4) ELSE 0 END AS prepay_ratio
FROM (
    SELECT 
        r.ua_id,
        r.cust_no,
        r.ua_time,
        COUNT(CASE WHEN h.loan_end_date <= r.ua_date AND h.create_time < r.ua_time THEN 1 END) AS mature_count,
        COUNT(CASE WHEN h.create_time < r.ua_time THEN 1 END) AS loan_count
    FROM (SELECT DISTINCT
        ua_id,
        cust_no,
        ua_time,
        CAST(ua_time AS DATE) AS ua_date
        FROM hello_da.dty_kb_features_hive WHERE pt = '${bdp.system.bizdate2}' and ua_time IS NOT NULL) r
    LEFT JOIN hello_prd.ods_mx_ast_asset_repay_plan_df h  
        ON r.cust_no = h.cust_no 
        AND h.pt='${bdp.system.bizdate2}' and repay_plan_status != 4
    GROUP BY r.ua_id, r.cust_no, r.ua_time
) r

-- show create table hello_da.midloan_repayment_settlement_feature_123;
-- DROP TABLE IF EXISTS hello_da.midloan_repayment_settlement_feature_123;
-- DROP TABLE hello_da.midloan_repayment_settlement_feature_123;
-- CREATE TABLE IF NOT EXISTS hello_da.midloan_repayment_settlement_feature_123(
--     `ua_id` BIGINT,
--     `cust_no` STRING,
--     `ua_time` STRING,
--     `ua_date` DATE,
--     `principal_uatime_add_7d_no_settled` DECIMAL(38,8) ,
--     `principal_uatime_add_15d_no_settled` DECIMAL(38,8) ,
--     `principal_uatime_add_30d_no_settled` DECIMAL(38,8) ,
--     `principal_uatime_add_45d_no_settled` DECIMAL(38,8) ,
--     `principal_uatime_add_7d` DECIMAL(38,8),
--     `principal_uatime_add_15d` DECIMAL(38,8),
--     `principal_uatime_add_30d` DECIMAL(38,8),
--     `principal_uatime_add_45d` DECIMAL(38,8),
--     `last_7d_total_cnt` BIGINT,
--     `last_7d_overdue_0d_cnt` BIGINT,
--     `last_7d_overdue_1d_cnt` BIGINT,
--     `last_7d_overdue_2d_cnt` BIGINT,
--     `last_7d_overdue_3d_cnt` BIGINT,
--     `last_7d_overdue_cnt` BIGINT,
--     `last_15d_total_cnt` BIGINT,
--     `last_15d_overdue_0d_cnt` BIGINT,
--     `last_15d_overdue_1d_cnt` BIGINT,
--     `last_15d_overdue_2d_cnt` BIGINT,
--     `last_15d_overdue_3d_cnt` BIGINT,
--     `last_15d_overdue_cnt` BIGINT,
--     `last_30d_total_cnt` BIGINT,
--     `last_30d_overdue_0d_cnt` BIGINT,
--     `last_30d_overdue_1d_cnt` BIGINT,
--     `last_30d_overdue_2d_cnt` BIGINT,
--     `last_30d_overdue_3d_cnt` BIGINT,
--     `last_30d_overdue_cnt` BIGINT,
--     `last_45d_total_cnt` BIGINT,
--     `last_45d_overdue_0d_cnt` BIGINT,
--     `last_45d_overdue_1d_cnt` BIGINT,
--     `last_45d_overdue_2d_cnt` BIGINT,
--     `last_45d_overdue_3d_cnt` BIGINT,
--     `last_45d_overdue_cnt` BIGINT,
--     `last_60d_total_cnt` BIGINT,
--     `last_60d_overdue_0d_cnt` BIGINT,
--     `last_60d_overdue_1d_cnt` BIGINT,
--     `last_60d_overdue_2d_cnt` BIGINT,
--     `last_60d_overdue_3d_cnt` BIGINT,
--     `last_60d_overdue_cnt` BIGINT,
--     `last_75d_total_cnt` BIGINT,
--     `last_75d_overdue_0d_cnt` BIGINT,
--     `last_75d_overdue_1d_cnt` BIGINT,
--     `last_75d_overdue_2d_cnt` BIGINT,
--     `last_75d_overdue_3d_cnt` BIGINT,
--     `last_75d_overdue_cnt` BIGINT,
--     `last_90d_total_cnt` BIGINT,
--     `last_90d_overdue_0d_cnt` BIGINT,
--     `last_90d_overdue_1d_cnt` BIGINT,
--     `last_90d_overdue_2d_cnt` BIGINT,
--     `last_90d_overdue_3d_cnt` BIGINT,
--     `last_90d_overdue_cnt` BIGINT,
--     `last_180d_total_cnt` BIGINT,
--     `last_180d_overdue_0d_cnt` BIGINT,
--     `last_180d_overdue_1d_cnt` BIGINT,
--     `last_180d_overdue_2d_cnt` BIGINT,
--     `last_180d_overdue_3d_cnt` BIGINT,
--     `last_180d_overdue_cnt` BIGINT,
--     `last_7d_overdue_0d_ratio` DOUBLE,
--     `last_7d_overdue_1d_ratio` DOUBLE,
--     `last_7d_overdue_2d_ratio` DOUBLE,
--     `last_7d_overdue_3d_ratio` DOUBLE,
--     `last_7d_overdue_ratio` DOUBLE,
--     `last_15d_overdue_0d_ratio` DOUBLE,
--     `last_15d_overdue_1d_ratio` DOUBLE,
--     `last_15d_overdue_2d_ratio` DOUBLE,
--     `last_15d_overdue_3d_ratio` DOUBLE,
--     `last_15d_overdue_ratio` DOUBLE,
--     `last_30d_overdue_0d_ratio` DOUBLE,
--     `last_30d_overdue_1d_ratio` DOUBLE,
--     `last_30d_overdue_2d_ratio` DOUBLE,
--     `last_30d_overdue_3d_ratio` DOUBLE,
--     `last_30d_overdue_ratio` DOUBLE,
--     `last_45d_overdue_0d_ratio` DOUBLE,
--     `last_45d_overdue_1d_ratio` DOUBLE,
--     `last_45d_overdue_2d_ratio` DOUBLE,
--     `last_45d_overdue_3d_ratio` DOUBLE,
--     `last_45d_overdue_ratio` DOUBLE,
--     `last_60d_overdue_0d_ratio` DOUBLE,
--     `last_60d_overdue_1d_ratio` DOUBLE,
--     `last_60d_overdue_2d_ratio` DOUBLE,
--     `last_60d_overdue_3d_ratio` DOUBLE,
--     `last_60d_overdue_ratio` DOUBLE,
--     `last_75d_overdue_0d_ratio` DOUBLE,
--     `last_75d_overdue_1d_ratio` DOUBLE,
--     `last_75d_overdue_2d_ratio` DOUBLE,
--     `last_75d_overdue_3d_ratio` DOUBLE,
--     `last_75d_overdue_ratio` DOUBLE,
--     `last_90d_overdue_0d_ratio` DOUBLE,
--     `last_90d_overdue_1d_ratio` DOUBLE,
--     `last_90d_overdue_2d_ratio` DOUBLE,
--     `last_90d_overdue_3d_ratio` DOUBLE,
--     `last_90d_overdue_ratio` DOUBLE,
--     `last_180d_overdue_0d_ratio` DOUBLE,
--     `last_180d_overdue_1d_ratio` DOUBLE,
--     `last_180d_overdue_2d_ratio` DOUBLE,
--     `last_180d_overdue_3d_ratio` DOUBLE,
--     `last_180d_overdue_ratio` DOUBLE
--  )partitioned by (pt string comment '未还金额以及结清相关贷中特征')
-- stored as orc lifecycle 365;

insert overwrite table hello_da.midloan_repayment_settlement_feature_123
partition (pt = '${bdp.system.bizdate2}')
SELECT
        ua_id,
        cust_no,
        ua_time,
        ua_date,
        --*** """NAME1""" ***--
        principal_uatime_add_7d_no_settled,
        principal_uatime_add_15d_no_settled,
        principal_uatime_add_30d_no_settled,
        principal_uatime_add_45d_no_settled,
        principal_uatime_add_7d,
        principal_uatime_add_15d,
        principal_uatime_add_30d,
        principal_uatime_add_45d,
        --*** """NAME2""" ***--
        last_7d_total_cnt,
        last_7d_overdue_0d_cnt,
        last_7d_overdue_1d_cnt,
        last_7d_overdue_2d_cnt,
        last_7d_overdue_3d_cnt,
        last_7d_overdue_cnt,
        last_15d_total_cnt,
        last_15d_overdue_0d_cnt,
        last_15d_overdue_1d_cnt,
        last_15d_overdue_2d_cnt,
        last_15d_overdue_3d_cnt,
        last_15d_overdue_cnt,
        last_30d_total_cnt,
        last_30d_overdue_0d_cnt,
        last_30d_overdue_1d_cnt,
        last_30d_overdue_2d_cnt,
        last_30d_overdue_3d_cnt,
        last_30d_overdue_cnt,
        last_45d_total_cnt,
        last_45d_overdue_0d_cnt,
        last_45d_overdue_1d_cnt,
        last_45d_overdue_2d_cnt,
        last_45d_overdue_3d_cnt,
        last_45d_overdue_cnt,
        last_60d_total_cnt,
        last_60d_overdue_0d_cnt,
        last_60d_overdue_1d_cnt,
        last_60d_overdue_2d_cnt,
        last_60d_overdue_3d_cnt,
        last_60d_overdue_cnt,
        last_75d_total_cnt,
        last_75d_overdue_0d_cnt,
        last_75d_overdue_1d_cnt,
        last_75d_overdue_2d_cnt,
        last_75d_overdue_3d_cnt,
        last_75d_overdue_cnt,
        last_90d_total_cnt,
        last_90d_overdue_0d_cnt,
        last_90d_overdue_1d_cnt,
        last_90d_overdue_2d_cnt,
        last_90d_overdue_3d_cnt,
        last_90d_overdue_cnt,
        last_180d_total_cnt,
        last_180d_overdue_0d_cnt,
        last_180d_overdue_1d_cnt,
        last_180d_overdue_2d_cnt,
        last_180d_overdue_3d_cnt,
        last_180d_overdue_cnt,
        -- *** """NAME3:最近{window}天逾期{days}天内结清占比,最近{window}天总逾期结清占比最近{window}天总结清比例"""
        -- 7天窗口占比特征
        CASE WHEN last_7d_total_cnt>0 THEN ROUND(last_7d_overdue_0d_cnt/last_7d_total_cnt,4) ELSE 0 END AS last_7d_overdue_0d_ratio,
        CASE WHEN last_7d_total_cnt>0 THEN ROUND(last_7d_overdue_1d_cnt/last_7d_total_cnt,4) ELSE 0 END AS last_7d_overdue_1d_ratio,
        CASE WHEN last_7d_total_cnt>0 THEN ROUND(last_7d_overdue_2d_cnt/last_7d_total_cnt,4) ELSE 0 END AS last_7d_overdue_2d_ratio,
        CASE WHEN last_7d_total_cnt>0 THEN ROUND(last_7d_overdue_3d_cnt/last_7d_total_cnt,4) ELSE 0 END AS last_7d_overdue_3d_ratio,
        CASE WHEN last_7d_total_cnt>0 THEN ROUND(last_7d_overdue_cnt/last_7d_total_cnt,4) ELSE 0 END AS last_7d_overdue_ratio,
        -- 15天窗口占比特征
        CASE WHEN last_15d_total_cnt>0 THEN ROUND(last_15d_overdue_0d_cnt/last_15d_total_cnt,4) ELSE 0 END AS last_15d_overdue_0d_ratio,
        CASE WHEN last_15d_total_cnt>0 THEN ROUND(last_15d_overdue_1d_cnt/last_15d_total_cnt,4) ELSE 0 END AS last_15d_overdue_1d_ratio,
        CASE WHEN last_15d_total_cnt>0 THEN ROUND(last_15d_overdue_2d_cnt/last_15d_total_cnt,4) ELSE 0 END AS last_15d_overdue_2d_ratio,
        CASE WHEN last_15d_total_cnt>0 THEN ROUND(last_15d_overdue_3d_cnt/last_15d_total_cnt,4) ELSE 0 END AS last_15d_overdue_3d_ratio,
        CASE WHEN last_15d_total_cnt>0 THEN ROUND(last_15d_overdue_cnt/last_15d_total_cnt,4) ELSE 0 END AS last_15d_overdue_ratio,
        -- 30天窗口占比特征
        CASE WHEN last_30d_total_cnt>0 THEN ROUND(last_30d_overdue_0d_cnt/last_30d_total_cnt,4) ELSE 0 END AS last_30d_overdue_0d_ratio,
        CASE WHEN last_30d_total_cnt>0 THEN ROUND(last_30d_overdue_1d_cnt/last_30d_total_cnt,4) ELSE 0 END AS last_30d_overdue_1d_ratio,
        CASE WHEN last_30d_total_cnt>0 THEN ROUND(last_30d_overdue_2d_cnt/last_30d_total_cnt,4) ELSE 0 END AS last_30d_overdue_2d_ratio,
        CASE WHEN last_30d_total_cnt>0 THEN ROUND(last_30d_overdue_3d_cnt/last_30d_total_cnt,4) ELSE 0 END AS last_30d_overdue_3d_ratio,
        CASE WHEN last_30d_total_cnt>0 THEN ROUND(last_30d_overdue_cnt/last_30d_total_cnt,4) ELSE 0 END AS last_30d_overdue_ratio,
        -- 45天窗口占比特征
        CASE WHEN last_45d_total_cnt>0 THEN ROUND(last_45d_overdue_0d_cnt/last_45d_total_cnt,4) ELSE 0 END AS last_45d_overdue_0d_ratio,
        CASE WHEN last_45d_total_cnt>0 THEN ROUND(last_45d_overdue_1d_cnt/last_45d_total_cnt,4) ELSE 0 END AS last_45d_overdue_1d_ratio,
        CASE WHEN last_45d_total_cnt>0 THEN ROUND(last_45d_overdue_2d_cnt/last_45d_total_cnt,4) ELSE 0 END AS last_45d_overdue_2d_ratio,
        CASE WHEN last_45d_total_cnt>0 THEN ROUND(last_45d_overdue_3d_cnt/last_45d_total_cnt,4) ELSE 0 END AS last_45d_overdue_3d_ratio,
        CASE WHEN last_45d_total_cnt>0 THEN ROUND(last_45d_overdue_cnt/last_45d_total_cnt,4) ELSE 0 END AS last_45d_overdue_ratio,	
        -- 60天窗口占比特征
        CASE WHEN last_60d_total_cnt>0 THEN ROUND(last_60d_overdue_0d_cnt/last_60d_total_cnt,4) ELSE 0 END AS last_60d_overdue_0d_ratio,
        CASE WHEN last_60d_total_cnt>0 THEN ROUND(last_60d_overdue_1d_cnt/last_60d_total_cnt,4) ELSE 0 END AS last_60d_overdue_1d_ratio,
        CASE WHEN last_60d_total_cnt>0 THEN ROUND(last_60d_overdue_2d_cnt/last_60d_total_cnt,4) ELSE 0 END AS last_60d_overdue_2d_ratio,
        CASE WHEN last_60d_total_cnt>0 THEN ROUND(last_60d_overdue_3d_cnt/last_60d_total_cnt,4) ELSE 0 END AS last_60d_overdue_3d_ratio,
        CASE WHEN last_60d_total_cnt>0 THEN ROUND(last_60d_overdue_cnt/last_60d_total_cnt,4) ELSE 0 END AS last_60d_overdue_ratio,
        -- 75天窗口占比特征
        CASE WHEN last_75d_total_cnt>0 THEN ROUND(last_75d_overdue_0d_cnt/last_75d_total_cnt,4) ELSE 0 END AS last_75d_overdue_0d_ratio,
        CASE WHEN last_75d_total_cnt>0 THEN ROUND(last_75d_overdue_1d_cnt/last_75d_total_cnt,4) ELSE 0 END AS last_75d_overdue_1d_ratio,
        CASE WHEN last_75d_total_cnt>0 THEN ROUND(last_75d_overdue_2d_cnt/last_75d_total_cnt,4) ELSE 0 END AS last_75d_overdue_2d_ratio,
        CASE WHEN last_75d_total_cnt>0 THEN ROUND(last_75d_overdue_3d_cnt/last_75d_total_cnt,4) ELSE 0 END AS last_75d_overdue_3d_ratio,
        CASE WHEN last_75d_total_cnt>0 THEN ROUND(last_75d_overdue_cnt/last_75d_total_cnt,4) ELSE 0 END AS last_75d_overdue_ratio,	
        -- 90天窗口占比特征
        CASE WHEN last_90d_total_cnt>0 THEN ROUND(last_90d_overdue_0d_cnt/last_90d_total_cnt,4) ELSE 0 END AS last_90d_overdue_0d_ratio,
        CASE WHEN last_90d_total_cnt>0 THEN ROUND(last_90d_overdue_1d_cnt/last_90d_total_cnt,4) ELSE 0 END AS last_90d_overdue_1d_ratio,
        CASE WHEN last_90d_total_cnt>0 THEN ROUND(last_90d_overdue_2d_cnt/last_90d_total_cnt,4) ELSE 0 END AS last_90d_overdue_2d_ratio,
        CASE WHEN last_90d_total_cnt>0 THEN ROUND(last_90d_overdue_3d_cnt/last_90d_total_cnt,4) ELSE 0 END AS last_90d_overdue_3d_ratio,
        CASE WHEN last_90d_total_cnt>0 THEN ROUND(last_90d_overdue_cnt/last_90d_total_cnt,4) ELSE 0 END AS last_90d_overdue_ratio,
        -- 180天窗口占比特征
        CASE WHEN last_180d_total_cnt>0 THEN ROUND(last_180d_overdue_0d_cnt/last_180d_total_cnt,4) ELSE 0 END AS last_180d_overdue_0d_ratio,
        CASE WHEN last_180d_total_cnt>0 THEN ROUND(last_180d_overdue_1d_cnt/last_180d_total_cnt,4) ELSE 0 END AS last_180d_overdue_1d_ratio,
        CASE WHEN last_180d_total_cnt>0 THEN ROUND(last_180d_overdue_2d_cnt/last_180d_total_cnt,4) ELSE 0 END AS last_180d_overdue_2d_ratio,
        CASE WHEN last_180d_total_cnt>0 THEN ROUND(last_180d_overdue_3d_cnt/last_180d_total_cnt,4) ELSE 0 END AS last_180d_overdue_3d_ratio,
        CASE WHEN last_180d_total_cnt>0 THEN ROUND(last_180d_overdue_cnt/last_180d_total_cnt,4) ELSE 0 END AS last_180d_overdue_ratio

from (
    SELECT 
        kb.ua_id,
        kb.cust_no,
        kb.ua_time,
        kb.ua_date,
        --*** """NAME1:近N天应还总额principal_uatime_add_{day}d_no_settled，计算用信节点时间往后推的应该要还的本金"""
        SUM(CASE 
            WHEN rp.create_time < kb.ua_time 
                 AND DATEDIFF(rp.loan_end_date, kb.ua_date) BETWEEN 1 AND 7 --在0到7天内，不包含0天和包含7天
            THEN (rp.principal + rp.repaid_principal)
            ELSE 0 
        END) as principal_uatime_add_7d_no_settled,
        
        SUM(CASE 
            WHEN rp.create_time < kb.ua_time 
                 AND DATEDIFF(rp.loan_end_date, kb.ua_date) BETWEEN 1 AND 15 --在1到15天内
            THEN (rp.principal + rp.repaid_principal) 
            ELSE 0 
        END) as principal_uatime_add_15d_no_settled,
        
        SUM(CASE 
            WHEN rp.create_time < kb.ua_time 
                 AND DATEDIFF(rp.loan_end_date, kb.ua_date) BETWEEN 1 AND 30 --在1到30天内
            THEN (rp.principal + rp.repaid_principal) 
            ELSE 0 
        END) as principal_uatime_add_30d_no_settled,
        
        SUM(CASE 
            WHEN rp.create_time < kb.ua_time 
                 AND DATEDIFF(rp.loan_end_date, kb.ua_date) BETWEEN 1 AND 45 --在1到45天内
            THEN (rp.principal + rp.repaid_principal) 
            ELSE 0 
        END) as principal_uatime_add_45d_no_settled,
        -- *** """NAME1_1:近N天应还总额principal_uatime_add_{day}d，计算用信节点时间往后推的待还本金,提前结清就不计算在内了，主要是用于bcard_v3"""
        SUM(CASE 
            WHEN rp.create_time < kb.ua_time 
                 AND (rp.settled_time >= kb.ua_time OR rp.settled_time IS NULL)
                 AND DATEDIFF(rp.loan_end_date, kb.ua_date) <= 7 
            THEN (rp.principal + rp.repaid_principal)
            ELSE 0 
        END) as principal_uatime_add_7d,

        SUM(CASE 
            WHEN rp.create_time < kb.ua_time 
                 AND (rp.settled_time >= kb.ua_time OR rp.settled_time IS NULL)
                 AND DATEDIFF(rp.loan_end_date, kb.ua_date) <= 15 
            THEN (rp.principal + rp.repaid_principal)
            ELSE 0 
        END) as principal_uatime_add_15d,

        SUM(CASE 
            WHEN rp.create_time < kb.ua_time 
                 AND (rp.settled_time >= kb.ua_time OR rp.settled_time IS NULL)
                 AND DATEDIFF(rp.loan_end_date, kb.ua_date) <= 30 
            THEN (rp.principal + rp.repaid_principal)
            ELSE 0 
        END) as principal_uatime_add_30d,

        SUM(CASE 
            WHEN rp.create_time < kb.ua_time 
                 AND (rp.settled_time >= kb.ua_time OR rp.settled_time IS NULL)
                 AND DATEDIFF(rp.loan_end_date, kb.ua_date) <= 45 
            THEN (rp.principal + rp.repaid_principal)
            ELSE 0 
        END) as principal_uatime_add_45d,

        -- *** """NAME2:最近{窗口}天总结清次数(总结清次数/到期的期数), 最近{window}天逾期{days}天内结清次数""" 
        -- 7天窗口的特征
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 7) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date THEN 1 END) AS last_7d_total_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 7) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) = 0 THEN 1 END) AS last_7d_overdue_0d_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 7) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) > 0 AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) <= 1 THEN 1 END) AS last_7d_overdue_1d_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 7) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) > 0 AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) <= 2 THEN 1 END) AS last_7d_overdue_2d_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 7) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) > 0 AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) <= 3 THEN 1 END) AS last_7d_overdue_3d_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 7) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) > 0 THEN 1 END) AS last_7d_overdue_cnt,
        -- 15天窗口的特征
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 15) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date THEN 1 END) AS last_15d_total_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 15) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) = 0 THEN 1 END) AS last_15d_overdue_0d_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 15) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) > 0 AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) <= 1 THEN 1 END) AS last_15d_overdue_1d_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 15) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) > 0 AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) <= 2 THEN 1 END) AS last_15d_overdue_2d_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 15) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) > 0 AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) <= 3 THEN 1 END) AS last_15d_overdue_3d_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 15) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) > 0 THEN 1 END) AS last_15d_overdue_cnt,
        -- 30天窗口的特征
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 30) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date THEN 1 END) AS last_30d_total_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 30) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) = 0 THEN 1 END) AS last_30d_overdue_0d_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 30) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) > 0 AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) <= 1 THEN 1 END) AS last_30d_overdue_1d_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 30) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) > 0 AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) <= 2 THEN 1 END) AS last_30d_overdue_2d_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 30) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) > 0 AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) <= 3 THEN 1 END) AS last_30d_overdue_3d_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 30) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) > 0 THEN 1 END) AS last_30d_overdue_cnt,
        -- 45天窗口的特征
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 45) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date THEN 1 END) AS last_45d_total_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 45) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) = 0 THEN 1 END) AS last_45d_overdue_0d_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 45) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) > 0 AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) <= 1 THEN 1 END) AS last_45d_overdue_1d_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 45) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) > 0 AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) <= 2 THEN 1 END) AS last_45d_overdue_2d_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 45) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) > 0 AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) <= 3 THEN 1 END) AS last_45d_overdue_3d_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 45) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) > 0 THEN 1 END) AS last_45d_overdue_cnt,
        -- 60天窗口的特征
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 60) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date THEN 1 END) AS last_60d_total_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 60) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) = 0 THEN 1 END) AS last_60d_overdue_0d_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 60) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) > 0 AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) <= 1 THEN 1 END) AS last_60d_overdue_1d_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 60) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) > 0 AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) <= 2 THEN 1 END) AS last_60d_overdue_2d_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 60) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) > 0 AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) <= 3 THEN 1 END) AS last_60d_overdue_3d_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 60) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) > 0 THEN 1 END) AS last_60d_overdue_cnt,
        -- 75天窗口的特征
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 75) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date THEN 1 END) AS last_75d_total_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 75) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) = 0 THEN 1 END) AS last_75d_overdue_0d_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 75) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) > 0 AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) <= 1 THEN 1 END) AS last_75d_overdue_1d_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 75) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) > 0 AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) <= 2 THEN 1 END) AS last_75d_overdue_2d_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 75) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) > 0 AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) <= 3 THEN 1 END) AS last_75d_overdue_3d_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 75) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) > 0 THEN 1 END) AS last_75d_overdue_cnt,
        -- 90天窗口的特征
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 90) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date THEN 1 END) AS last_90d_total_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 90) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) = 0 THEN 1 END) AS last_90d_overdue_0d_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 90) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) > 0 AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) <= 1 THEN 1 END) AS last_90d_overdue_1d_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 90) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) > 0 AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) <= 2 THEN 1 END) AS last_90d_overdue_2d_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 90) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) > 0 AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) <= 3 THEN 1 END) AS last_90d_overdue_3d_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 90) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) > 0 THEN 1 END) AS last_90d_overdue_cnt,
        -- 180天窗口的特征
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 180) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date THEN 1 END) AS last_180d_total_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 180) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) = 0 THEN 1 END) AS last_180d_overdue_0d_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 180) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) > 0 AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) <= 1 THEN 1 END) AS last_180d_overdue_1d_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 180) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) > 0 AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) <= 2 THEN 1 END) AS last_180d_overdue_2d_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 180) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) > 0 AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) <= 3 THEN 1 END) AS last_180d_overdue_3d_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 180) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) > 0 THEN 1 END) AS last_180d_overdue_cnt

    FROM (SELECT DISTINCT
        ua_id,
        cust_no,
        ua_time,
        TO_DATE(ua_time) as ua_date
        FROM hello_da.dty_kb_features_hive where pt = '${bdp.system.bizdate2}') kb
    LEFT JOIN (SELECT * FROM hello_prd.ods_mx_ast_asset_repay_plan_df where pt = '${bdp.system.bizdate2}' and repay_plan_status != 4) rp 
        ON kb.cust_no = rp.cust_no
    GROUP BY kb.ua_id, kb.cust_no, kb.ua_time, kb.ua_date) total;