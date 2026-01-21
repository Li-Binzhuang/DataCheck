WITH        
-- 支用申请工作流表
workflow_table as     
(select * from
    (select
    id as aprv_rule_id,
    apply_id,
    create_time as credit_time,
        cust_no,
        create_time as disburse_time,
        get_json_object(response_param,
        '$.eventCode') eventCode                            
    from
        hive_idc.hello_prd.ods_mx_aprv_approve_rule_record_df                            
    where
        pt = date_sub(current_date, 1)                                            
        and rule_type = 'USE_CREDIT_APPLY'                                            
        and (                     response_param NOT LIKE '%"demoEnable": true%'                                                
        or response_param is null                 )                                            
        and (                     business_type = 'CYCLE'                                                
        or business_type is null                 )          ) t        
where
    eventCode = 'P2011LH' ),        
-- 为每个支用申请记录找到上次放款时间
    last_loan_info AS (     SELECT
        w.aprv_rule_id,
        w.cust_no,
        w.credit_time,
        MAX(a.create_time) AS last_loan_start_date                    
    FROM
        workflow_table w                        
    LEFT JOIN
        (             SELECT
            *                                        
        FROM
            hive_idc.hello_prd.ods_mx_ast_asset_loan_info_df                                        
        WHERE
            pt = date_sub(current_date(), 1)                                                        
            and loan_status <> 4         ) a                                        
            ON a.cust_no = w.cust_no                                                
            AND a.create_time < w.credit_time                    
    GROUP BY
        w.aprv_rule_id,
        w.cust_no,
        w.credit_time ) SELECT
            w.aprv_rule_id,
            w.cust_no,
            w.apply_id,
            w.credit_time,
-- plus. 本次支用申请时间距离上次放款时间间隔分钟数
CAST((UNIX_TIMESTAMP(w.credit_time,
            'yyyy-MM-dd HH:mm:ss')        - UNIX_TIMESTAMP(ll.last_loan_start_date,
            'yyyy-MM-dd HH:mm:ss')) / 60 AS INT)  AS disbruse_to_last_granting_mins                            
        FROM
            workflow_table w        
-- 关联上次放款时间
        LEFT JOIN
            last_loan_info ll                                                    
                ON w.aprv_rule_id = ll.aprv_rule_id                                                        
                AND w.cust_no = ll.cust_no                                                        
                AND w.credit_time = ll.credit_time        
-- 关联首次放款信息
        WHERE
            w.credit_time IS NOT NULL;

select
    use_apply_id ,
    cust_no,
    ua_time,
    rl_reoffer_repeatloan_v1 as last_reoffer_rl_reoffer_repeatloan_v1     
from
    (select
        apply_id as use_apply_id,
        create_time as use_time,
        row_number() OVER(PARTITION                     
    by
        apply_id                     
    order by
        create_time DESC)  rule_rank                            
    from
        hive_idc.hello_prd.ods_mx_aprv_approve_rule_record_df                              
    where
        pt=date_sub(current_date,1)                                     
        and create_time >= '2026-01-19'                                    
        and rule_type ='USE_CREDIT_APPLY'                                     
        and (
            response_param NOT LIKE '%"demoEnable": true%'                                                     
            or response_param is null                                    
        )) disburse_workflow                    
-- 用信申请表
left join
    (
        select
            credit_apply_id,
            create_time as ua_time,
            id as usage_id                                         
        from
            hive_idc.hello_prd.ods_mx_aprv_approve_use_credit_apply_df          
--用信支用申请表
        WHERE
            pt = date_sub(current_date(),1)                          
    ) use_credit                                     
        on cast(use_credit.usage_id as STRING)  = cast(disburse_workflow.use_apply_id as STRING)         
-- reoffer 工作流表
left join
    (
        select
            id as reoffer_workflow_id,
            cust_no,
            audit_status,
            apply_id,
            get_json_object(response_param,
            '$.riskInfo.rl_reoffer_repeatloan_v1') AS rl_reoffer_repeatloan_v1,
            to_date(create_time) credit_date                                     
        from
            hive_idc.hello_prd.ods_mx_aprv_approve_rule_record_df                                      
        where
            pt = date_sub(current_date(),1)                                                     
            and create_time >= '2026-01-12'                                                     
            and rule_type = 'CREDIT_APPLY'                                                     
            and response_param NOT LIKE '%"demoEnable": true%'                                                     
            and (
                business_type = 'CYCLE'                                                                     
                or business_type is null                                                    
            )                                                      
            and get_json_object(response_param, '$.eventCode') = 'R1001'                     
    ) reoffer                                      
        on reoffer.apply_id = use_credit.credit_apply_id