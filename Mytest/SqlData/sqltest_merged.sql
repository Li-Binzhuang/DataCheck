-- 合并后的SQL查询：将两个SELECT结果合并为一个查询
WITH        
-- 支用申请工作流表
workflow_table AS (
    SELECT * FROM (
        SELECT
            id AS aprv_rule_id,
            apply_id,
            create_time AS credit_time,
            cust_no,
            create_time AS disburse_time,
            get_json_object(response_param, '$.eventCode') AS eventCode                            
        FROM
            hive_idc.hello_prd.ods_mx_aprv_approve_rule_record_df                            
        WHERE
            pt = date_sub(current_date, 1)                                            
            AND rule_type = 'USE_CREDIT_APPLY'                                            
            AND (response_param NOT LIKE '%"demoEnable": true%' OR response_param IS NULL)                                            
            AND (business_type = 'CYCLE' OR business_type IS NULL)
    ) t        
    WHERE eventCode = 'P2011LH'
),        

-- 为每个支用申请记录找到上次放款时间
last_loan_info AS (
    SELECT
        w.aprv_rule_id,
        w.cust_no,
        w.credit_time,
        MAX(a.create_time) AS last_loan_start_date                    
    FROM
        workflow_table w                        
    LEFT JOIN (
        SELECT *                                        
        FROM hive_idc.hello_prd.ods_mx_ast_asset_loan_info_df                                        
        WHERE
            pt = date_sub(current_date(), 1)                                                        
            AND loan_status <> 4
    ) a                                        
        ON a.cust_no = w.cust_no                                                
        AND a.create_time < w.credit_time                    
    GROUP BY
        w.aprv_rule_id,
        w.cust_no,
        w.credit_time
),

-- 第一个查询的结果集
first_query AS (
    SELECT
        w.aprv_rule_id,
        w.cust_no,
        w.apply_id,
        w.credit_time,
        -- plus. 本次支用申请时间距离上次放款时间间隔分钟数
        CAST((UNIX_TIMESTAMP(w.credit_time, 'yyyy-MM-dd HH:mm:ss') - 
              UNIX_TIMESTAMP(ll.last_loan_start_date, 'yyyy-MM-dd HH:mm:ss')) / 60 AS INT) AS disbruse_to_last_granting_mins                            
    FROM
        workflow_table w        
    -- 关联上次放款时间
    LEFT JOIN last_loan_info ll                                                    
        ON w.aprv_rule_id = ll.aprv_rule_id                                                        
        AND w.cust_no = ll.cust_no                                                        
        AND w.credit_time = ll.credit_time        
    WHERE w.credit_time IS NOT NULL
),

-- 用信申请工作流表（第二个查询）
disburse_workflow AS (
    SELECT
        apply_id AS use_apply_id,
        create_time AS use_time,
        row_number() OVER(PARTITION BY apply_id ORDER BY create_time DESC) AS rule_rank                            
    FROM
        hive_idc.hello_prd.ods_mx_aprv_approve_rule_record_df                              
    WHERE
        pt = date_sub(current_date, 1)                                     
        AND create_time >= '2026-01-19'                                    
        AND rule_type = 'USE_CREDIT_APPLY'                                     
        AND (response_param NOT LIKE '%"demoEnable": true%' OR response_param IS NULL)
),

-- 用信申请表
use_credit AS (
    SELECT
        credit_apply_id,
        create_time AS ua_time,
        id AS usage_id                                         
    FROM
        hive_idc.hello_prd.ods_mx_aprv_approve_use_credit_apply_df          
    WHERE
        pt = date_sub(current_date(), 1)
),

-- reoffer 工作流表
reoffer AS (
    SELECT
        id AS reoffer_workflow_id,
        cust_no,
        audit_status,
        apply_id,
        get_json_object(response_param, '$.riskInfo.rl_reoffer_repeatloan_v1') AS rl_reoffer_repeatloan_v1,
        to_date(create_time) AS credit_date                                     
    FROM
        hive_idc.hello_prd.ods_mx_aprv_approve_rule_record_df                                      
    WHERE
        pt = date_sub(current_date(), 1)                                                     
        AND create_time >= '2026-01-12'                                                     
        AND rule_type = 'CREDIT_APPLY'                                                     
        AND response_param NOT LIKE '%"demoEnable": true%'                                                     
        AND (business_type = 'CYCLE' OR business_type IS NULL)                                                      
        AND get_json_object(response_param, '$.eventCode') = 'R1001'
),

-- 第二个查询的结果集
second_query AS (
    SELECT
        dw.use_apply_id,
        uc.cust_no,
        uc.ua_time,
        r.rl_reoffer_repeatloan_v1 AS last_reoffer_rl_reoffer_repeatloan_v1     
    FROM
        disburse_workflow dw                    
    LEFT JOIN use_credit uc                                     
        ON CAST(uc.usage_id AS STRING) = CAST(dw.use_apply_id AS STRING)         
    LEFT JOIN reoffer r                                      
        ON r.apply_id = uc.credit_apply_id
)

-- 合并两个查询结果
SELECT
    fq.aprv_rule_id,
    fq.cust_no,
    fq.apply_id,
    fq.credit_time,
    fq.disbruse_to_last_granting_mins,
    sq.use_apply_id,
    sq.ua_time,
    sq.last_reoffer_rl_reoffer_repeatloan_v1
FROM
    first_query fq
FULL OUTER JOIN second_query sq
    ON fq.apply_id = sq.use_apply_id
    AND fq.cust_no = sq.cust_no;
