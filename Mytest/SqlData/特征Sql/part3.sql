-- name 贷中特征衍生_order
-- type StarRocks
-- author dongtianyu790@hellobike.com
-- create time 2025-12-01 00:51:01
-- desc 

WITH base_loan_data as (SELECT 
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
    rp.periods,
    li.id as li_id,
    -- pf.plat_status,
    -- pf.pay_time, 
    la.loan_amt,
    -- 如果是分区,每天principal都是应还本金，不会更新
    (rp.principal + rp.repaid_principal) as principal_all,
    -- rp.principal as principal_all,
    rp.create_time as repay_plan_time,
    case 
    when rp.settled_time is not null then
        datediff(date(rp.settled_time), date(rp.loan_end_date))
    else
        datediff(date('2025-12-07'), date(rp.loan_end_date))
    end as overdue_days
FROM (SELECT * FROM fintech.dwd_rsk_approve_use_credit_apply_rt ) ua
LEFT JOIN (SELECT * FROM fintech.dwd_rsk_approve_credit_apply_rt ) ca 
    ON ca.id = CAST(ua.credit_apply_id as STRING)
LEFT JOIN (SELECT * FROM fintech.dwd_rsk_asset_loan_apply_rt ) la -- 资产申请进件表
    ON la.seq_no = ua.asset_id
LEFT JOIN (SELECT * FROM  fintech.dwd_trd_ast_loan_info_rt WHERE loan_status <> 4 AND (optype <> 'DELETE' OR optype IS NULL)) li 
    ON li.loan_apply_no = la.loan_apply_no
-- LEFT JOIN (SELECT * FROM hello_prd.ods_mx_ast_asset_pay_founder_loan_flow_df WHERE create_time > '2025-12-01') pf 
--     ON li.loan_apply_no = pf.loan_apply_no
LEFT JOIN (SELECT * FROM fintech.dwd_trd_ast_repay_plan_rt WHERE repay_plan_status <> 4 AND (optype <> 'DELETE' OR optype IS NULL)) rp 
    ON rp.loan_no = li.loan_no)
--WHERE rp.id IS NOT NULL and datediff('2025-12-07', rp.loan_end_date) > 7 and ua.cust_no in (select distinct cust_no from fintech.dwd_rsk_approve_use_credit_apply_rt where create_time >='2025-10-01'))




----========================================第一类：当前订单特征==================================================
-- 只计算当前订单特征（x=0）
select * from (
SELECT 
    bld.ua_id,
    bld.cust_no,
    bld.ua_time,
    -- ========== 当前订单特征 (x=0) ==========
    
    -- 1. 当前订单借款时刻（0-23）
    -- 原始特征名: local_midloan.Mexorder.currentOrderRiskVO.CreationTimeInHour
    EXTRACT(HOUR FROM bld.ua_time) as local_olduser_order_currentorderriskvo_creationtimeinhour_v2,
    
    -- 2. 当前订单借款是否在周末【明年实行双休，25年还是单休】
    -- 原始特征名: local_midloan.Mexorder.currentOrderRiskVO.isCreationTimeOnWeekend
    CASE 
        WHEN DAYOFWEEK(bld.ua_time) = 1 -- 周日
        THEN 1 
        ELSE 0 
    END as local_olduser_order_currentorderriskvo_iscreationtimeonweekend_v2,

    
    -- 3. 当前订单借款是否在周六
    -- 原始特征名: local_midloan.Mexorder.currentOrderRiskVO.isCreationTimeOnSaturday
    CASE 
        WHEN DAYOFWEEK(bld.ua_time) = 7 -- 周六
        THEN 1 
        ELSE 0 
    END as local_olduser_order_currentorderriskvo_iscreationtimeonsaturday_v2,
    
    -- 4. 当前订单借款时间是否在11点后15点前
    -- 原始特征名: local_midloan.Mexorder.currentOrderRiskVO.isCreationTimeWithin11amTo14pm
    -- 注意：这里x=0，就是当前订单本身
    CASE 
        WHEN EXTRACT(HOUR FROM bld.ua_time) >= 11 AND EXTRACT(HOUR FROM bld.ua_time) < 15 
        THEN 1 
        ELSE 0 
    END as local_olduser_order_currentorderriskvo_iscreationtimewithin11amto14pm_v2,
    
    -- 5. 当前订单借款时间是否在15点后18点前
    -- 原始特征名: local_midloan.Mexorder.currentOrderRiskVO.isCreationTimeWithin15pmTo17pm
    CASE 
        WHEN EXTRACT(HOUR FROM bld.ua_time) >= 15 AND EXTRACT(HOUR FROM bld.ua_time) < 18 
        THEN 1 
        ELSE 0 
    END as local_olduser_order_currentorderriskvo_iscreationtimewithin15pmto17pm_v2,
    
    -- 6. 当前订单借款时间是否在18点后23点前
    -- 原始特征名: local_midloan.Mexorder.currentOrderRiskVO.isCreationTimeWithin18pmTo22pm
    CASE 
        WHEN EXTRACT(HOUR FROM bld.ua_time) >= 18 AND EXTRACT(HOUR FROM bld.ua_time) < 23 
        THEN 1 
        ELSE 0 
    END as local_olduser_order_currentorderriskvo_iscreationtimewithin18pmto22pm_v2,
    
    -- 7. 当前订单借款时间是否在23点后5点前
    -- 原始特征名: local_midloan.Mexorder.currentOrderRiskVO.isCreationTimeWithin23pmTo5am
    CASE 
        WHEN EXTRACT(HOUR FROM bld.ua_time) >= 23 OR EXTRACT(HOUR FROM bld.ua_time) < 6
        THEN 1 
        ELSE 0 
    END as local_olduser_order_currentorderriskvo_iscreationtimewithin23pmto5am_v2,
    
    -- 8. 当前订单借款时间是否在6点后11点前
    -- 原始特征名: local_midloan.Mexorder.currentOrderRiskVO.isCreationTimeWithin6amTo10am
    CASE 
        WHEN EXTRACT(HOUR FROM bld.ua_time) >= 6 AND EXTRACT(HOUR FROM bld.ua_time) < 11 
        THEN 1 
        ELSE 0 
    END as local_olduser_order_currentorderriskvo_iscreationtimewithin6amto10am_v2,

    -- 9. 当前订单借款金额
    bld.loan_amt as local_olduser_order_currentorderriskvo_orderloanamount_v2

FROM base_loan_data bld
ORDER BY bld.cust_no, bld.ua_time ) t
where ua_time>='2026-01-08 01:29:30'
order by ua_time desc;