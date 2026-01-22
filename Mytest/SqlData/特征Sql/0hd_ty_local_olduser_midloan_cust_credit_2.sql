
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