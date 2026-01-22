-- 授信申请--> 用信申请-->资产申请(借款申请)--额度-->借据(贷款)
-- 数据覆盖：
-- -- 授信申请表 ods_mx_aprv_approve_credit_apply_df
-- -- 授信产品表 ods_mx_aprv_approve_credit_apply_product_df 聚合到授信维度
-- -- 用信申请表 ods_mx_aprv_approve_use_credit_apply_df
-- -- 资产申请进件表 ods_mx_ast_asset_loan_apply_df
-- -- 三方放款流水表 ods_mx_ast_asset_pay_founder_loan_flow_df
-- -- 借据信息表 ods_mx_ast_asset_loan_info_df
-- -- 规则执行记录表 ods_mx_aprv_approve_rule_record_df （授信规则，用信规则）
-- -- 账户标签表 ods_mx_cust_cust_account_tag_df 

CREATE TABLE IF NOT EXISTS hello_prd.dws_trd_credit_apply_use_loan_df(
    -- 授信
    credit_apply_id string COMMENT'授信申请ID_授信进件号',
    cust_no string COMMENT'客户号',
    hash_id_no string COMMENT'客户证件号',
    first_credit_date DATE COMMENT'客户首笔授信(成功)日期',
    first_credit_days BIGINT COMMENT'客户首笔授信(成功)日期距今天数',
    first_credit_limit_amount decimal(32,8) COMMENT'客户首笔授信(成功)授信限额',
    latest_credit_date DATE COMMENT'客户最近一笔授信(成功)日期',
    latest_credit_limit_amount decimal(32,8) COMMENT'客户最近一笔授信(成功)授信限额',

    credit_rule_type string COMMENT'授信规则类型: pre_credit,credit,use_credit',
    credit_platform string COMMENT'授信申请平台: ANDROID,IOS,WEB_H5 etc.',

    credit_limit_amount decimal(32,8) COMMENT'授信限额',
    credit_validity_end_date string COMMENT'有效期止日期',
    credit_status bigint COMMENT'进件状态: 100:INIT,200:Processing,300:Fail,400:Success',
    credit_remark string COMMENT'授信备注',
    credit_create_time string COMMENT'授信进件创建时间',
    credit_update_time string COMMENT'授信进件更新时间',
    credit_audit_status string COMMENT'审批状态,PASS or REFUSE',
    credit_app_system string COMMENT'系统名称',
    credit_cooling_off_date string COMMENT'授信申请冷静期',
    user_type bigint COMMENT'用户类型1:new user 2:old user',
    refuse_result_delay_time string COMMENT'拒绝结果延迟时间',
    blind_lend bigint COMMENT'是否盲放 1-盲放， 其他-非盲放',
    credit_approve_state	string	COMMENT'最终审批状态:[CYCLE/SINGLE]_[REFUSE/PASS]',
    -- 循环贷授信状态（通过/拒绝） 单笔单批授信状态（未过/通过、拒绝）
    cycle_approve_state string	COMMENT'循环贷审批状态:REFUSE/PASS',
    single_approve_state string	COMMENT'单笔单批审批状态:非单笔单批:null/REFUSE/PASS]',

    credit_product_cnt bigint COMMENT'授信产品数',
    credit_product_str string COMMENT'授信产品期数,多个产品用逗号隔开',
    -- 用信
    use_credit_apply_id string COMMENT'用信申请id:用信表标识',
    asset_id string COMMENT'用信申请流水号',
    use_credit_rank bigint COMMENT'用信序号:是否首笔用信',
    first_use_credit_date DATE COMMENT'客户首笔用信(成功)日期',
    first_use_credit_days BIGINT COMMENT'客户首笔用信(成功)日期距今天数',
    -- use_channel string COMMENT'用信进件渠道: ANDROID,IO,H5,OFFLINE etc.',
    use_rule_type string COMMENT'用信规则类型: pre_credit,credit,use_credit',
    use_platform string COMMENT'用信申请平台: ANDROID,IOS,WEB_H5 etc.',
    use_amount decimal(32,8) COMMENT'用信金额',
    use_datetime string COMMENT'用信时间',

    use_period string COMMENT'用信期数',
    use_loan_days bigint COMMENT'用信天数',
    use_remark string COMMENT'用信申请备注',
    use_status bigint COMMENT'用信状态: 100:INIT,200:Processing,300:Fail,400:Success',
    is_lift_cooling_off_period bigint COMMENT'是否冷静期内',
    use_create_time string COMMENT'用信申请创建时间',
    use_update_time string COMMENT'用信申请更新时间',
    use_audit_status string COMMENT'用信审批状态,PASS or REFUSE',
    final_status_time string COMMENT'状态在终态的时间',
    use_approve_state string COMMENT'审批状态',
    use_cooling_off_date  string COMMENT'用信申请冷静期日期',
    -- 资产申请进件
    loan_apply_no string COMMENT'申请单号',
    prod_code string COMMENT'产品编号',
    loan_apply_date string COMMENT'申请日期，YYYYMMDD',
    apply_status bigint COMMENT'0-审核中，1-审核失败，2-待放款，3-放款成功，4-结束放款，5-放款中，6-放款失败，7-放款异常，8-取消签约，9-重新放款',
    apply_sub_status bigint COMMENT'借款子状态，0:正常，1:待补充支付信息，9:已结清',
    service_fee_mode string COMMENT'收费模式，00:前置模式，01:后置模式，02:按期模式',
    service_fee_rate decimal(32,8) COMMENT'服务费率',
    day_interest_rate decimal(32,8) COMMENT'日利率',
    day_penalty_interest_rate decimal(32,8) COMMENT'罚息日利率',
    period_day string COMMENT'期次天数比例',
    loan_purpose string COMMENT'借款用途',
    loan_apply_remark string COMMENT'备注',
    repay_plan_calc_type string COMMENT'还款计划计算方式',
    interest_mode string COMMENT'计息方式，01:按日计息;02:按期计息',
    loan_apply_create_time string COMMENT'创建时间',
    cust_account_type string COMMENT'客户账户类型',
    upload_agreement_flag bigint COMMENT'协议上传标识',
    
    --借据信息
    loan_no string COMMENT'借据号:关联还款计划',
    loan_id string COMMENT'借据号',
    capital_loan_no string COMMENT'资方放款流水号',
    loan_first_flag bigint COMMENT'是否首笔借据:1是,其他否',
    first_loan_date date COMMENT'首笔借据开始日期',
    first_loan_days bigint COMMENT'首笔借据开始日期距今天数',
    loan_mob_days bigint COMMENT'本笔借据开始日期距今天数',
    loan_period bigint COMMENT'借款期数',
    loan_day bigint COMMENT'借款天数',
    loan_amt decimal(32,8) COMMENT'合同金额',
    real_loan_amt decimal(32,8) COMMENT'实际放款金额',
    principal decimal(32,8) COMMENT'本金',
    overdue_principal decimal(32,8) COMMENT'逾期本金',
    service_fee decimal(32,8) COMMENT'服务费',
    interest decimal(32,8) COMMENT'利息',
    penalty decimal(32,8) COMMENT'罚息',
    loan_service_fee_rate decimal(32,8) COMMENT'手续费率',
    loan_day_interest_rate decimal(32,8) COMMENT'日利率',
    penalty_interest_rate decimal(32,8) COMMENT'罚息利率',
    loan_status string COMMENT'借据状态,1:正常，2:结清，3：逾期，4:坏账，5:取消订单',
    settled_time string COMMENT'结清时间',
    settled_status string COMMENT'结清状态,0:未结清，1:正常结清，2:逾期结清，3:提前结清',
    loan_start_date string COMMENT'借据开始日',
    loan_end_date string COMMENT'借据结束日',
    first_repay_date string COMMENT'首次还款日',
    interest_date string COMMENT'起息日',
    bad_debt_time string COMMENT'坏账时间',
    repaid_principal decimal(32,8) COMMENT'已还本金',
    repaid_service_fee decimal(32,8) COMMENT'已还手续费',
    repaid_interest decimal(32,8) COMMENT'已还利息',
    repaid_penalty decimal(32,8) COMMENT'已还罚息',
    repay_mode string COMMENT'还款方式，100:按期还款',
    last_repay_date string COMMENT'上次还款时间',
    loan_way string COMMENT'线下/线上放款: 1-线下 2线上',
    loan_create_time string COMMENT'创建日期时间',
    discount_principal decimal(32,8) COMMENT'折扣本金',
    discount_interest decimal(32,8) COMMENT'折扣利息',
    discount_service_fee decimal(32,8) COMMENT'折扣服务费',
    discount_penalty decimal(32,8) COMMENT'折扣罚息',
    -- 规则记录 授信
    credit_fail_code  string COMMENT'失败码',
    -- 规则记录 用信规则
    use_fail_code  string COMMENT'失败码',
    business_type string COMMENT'业务类型:循环贷，单笔单批',
    cust_bussiness_tag string COMMENT'用户业务标签类型:循环贷，单笔单批'

 )comment'授用信借款信息明细表'partitioned by(
    pt string
 )stored as orc 
 lifecycle 365;

with approve_credit_apply_day as(
    select *,row_number() over(partition by cust_no order by create_time) as rk
    from hello_prd.ods_mx_aprv_approve_credit_apply_df --授信申请表 
    where pt = '${bdp.system.bizdate2}' and is_delete = 0
), approve_credit_apply_product_day as (
    select credit_apply_id,count(id) as credit_product_cnt,CONCAT_WS(',', COLLECT_LIST(CAST(period AS STRING))) AS credit_product_str 
    from hello_prd.ods_mx_aprv_approve_credit_apply_product_df -- 授信产品表
    where pt = '${bdp.system.bizdate2}' and is_delete = 0
    group by credit_apply_id
), approve_use_credit_day as(
    select *,row_number() over(partition by cust_no order by create_time) as rk
    from hello_prd.ods_mx_aprv_approve_use_credit_apply_df --用信申请表
    where pt = '${bdp.system.bizdate2}' and is_delete = 0
), asset_loan_day as (
    select t.*,row_number() over(partition by t.cust_no order by s.pay_time) as rk
    from hello_prd.ods_mx_ast_asset_loan_info_df t  --借据信息表
    left join hello_prd.ods_mx_ast_asset_pay_founder_loan_flow_df s --三方放款流水表
    on t.loan_apply_no = s.loan_apply_no and s.pt ='${bdp.system.bizdate2}' 
    where t.pt = '${bdp.system.bizdate2}'
)
INSERT OVERWRITE TABLE  hello_prd.dws_trd_credit_apply_use_loan_df PARTITION (pt = '${bdp.system.bizdate2}')
select
    -- 授信
    cast(cre.id as string) as credit_apply_id,
    cre.cust_no as cust_no,
    cre.hash_id_no as hash_id_no,
    date(fir_cre.create_time) as first_credit_date,
    datediff(to_date('${bdp.system.bizdate2}'),date(fir_cre.create_time)) as first_credit_days,
    fir_cre.credit_limit_amount as first_credit_limit_amount,
    date(las_cre.create_time) as latest_credit_date,
    las_cre.credit_limit_amount as latest_credit_limit_amount,
    cre.rule_type  as credit_rule_type,
    cre.platform  as credit_platform,

    cre.credit_limit_amount  as credit_limit_amount,
    cre.validity_end_date  as credit_validity_end_date,
    cre.status  as credit_status,
    cre.remark  as credit_remark,
    cre.create_time  as credit_create_time,
    cre.update_time  as credit_update_time,
    cre.audit_status  as credit_audit_status,
    cre.app_system  as credit_app_system,
    cre.cooling_off_date  as credit_cooling_off_date,
    cre.user_type  as user_type,
    cre.refuse_result_delay_time  as refuse_result_delay_time,
    cre.blind_lend  as blind_lend,
    cre.approve_state as credit_approve_state,
    case when cre.approve_state = 'CYCLE_PASS' then 'PASS' else 'REFUSE' end as cycle_approve_state,
    case when cre.approve_state = 'SINGLE_PASS' then 'PASS' when cre.approve_state = 'SINGLE_REFUSE' then 'REFUSE' else null end as single_approve_state,

    pro.credit_product_cnt as credit_product_cnt,
    pro.credit_product_str as credit_product_str,
    -- 用信
    cast(usc.id as string) as use_credit_apply_id,
    usc.asset_id,
    -- usc.use_channel as use_channel,
    usc.rk as use_credit_rank,
    date(fir_use.create_time) as first_use_credit_date,
    datediff(to_date('${bdp.system.bizdate2}'),date(fir_use.create_time)) as first_use_credit_days,
    usc.rule_type as use_rule_type,
    usc.platform as use_platform,
    usc.use_amount as use_amount,
    usc.use_datetime as use_datetime,
    -- usc.interest_amount as interest_amount,
    usc.period as use_period,
    usc.loan_days as use_loan_days,
    usc.remark as use_remark,
    usc.status as use_status,
    usc.is_lift_cooling_off_period as is_lift_cooling_off_period,
    usc.create_time as use_create_time,
    usc.update_time as use_update_time,
    usc.audit_status as use_audit_status,
    usc.final_status_time as final_status_time,
    usc.approve_state as use_approve_state,
    usc.cooling_off_date as use_cooling_off_date,
    --资产申请进件
    ala.loan_apply_no as loan_apply_no,
    ala.prod_code as prod_code,
    ala.loan_apply_date as loan_apply_date,
    ala.apply_status as apply_status,
    ala.apply_sub_status as apply_sub_status,
    ala.service_fee_mode as service_fee_mode,
    ala.service_fee_rate as service_fee_rate,
    ala.day_interest_rate as day_interest_rate,
    ala.day_penalty_interest_rate as day_penalty_interest_rate,
    ala.period_day as period_day,
    ala.loan_purpose as loan_purpose,
    ala.remark as loan_apply_remark,
    ala.repay_plan_calc_type as repay_plan_calc_type,
    ala.interest_mode as interest_mode,
    ala.create_time as loan_apply_create_time,
    ala.cust_account_type as cust_account_type,
    ala.upload_agreement_flag as upload_agreement_flag,

    --借据信息
    ali.loan_no as loan_no,
    ali.loan_id as loan_id,
    ali.capital_loan_no as capital_loan_no,
    ali.rk as loan_first_flag,
    date(fir_loan.loan_start_date) as first_loan_date,
    datediff(to_date('${bdp.system.bizdate2}'),date(fir_loan.loan_start_date)) as first_loan_days ,
    datediff(to_date('${bdp.system.bizdate2}'),date(ali.loan_start_date)) as loan_mob_days,
    ali.loan_period as loan_period,
    ali.loan_day as loan_day,
    ali.loan_amt as loan_amt,
    ali.real_loan_amt as real_loan_amt,
    ali.principal as principal,
    ali.overdue_principal as overdue_principal,
    ali.service_fee as service_fee,
    ali.interest as interest,
    ali.penalty as penalty,
    ali.service_fee_rate as loan_service_fee_rate,
    ali.day_interest_rate as loan_day_interest_rate,
    ali.penalty_interest_rate as penalty_interest_rate,
    ali.loan_status as loan_status,
    ali.settled_time as settled_time,
    ali.settled_status as settled_status,
    ali.loan_start_date as loan_start_date,
    ali.loan_end_date as loan_end_date,
    ali.first_repay_date as first_repay_date,
    ali.interest_date as interest_date,
    ali.bad_debt_time as bad_debt_time,
    ali.repaid_principal as repaid_principal,
    ali.repaid_service_fee as repaid_service_fee,
    ali.repaid_interest as repaid_interest,
    ali.repaid_penalty as repaid_penalty,
    ali.repay_mode as repay_mode,
    ali.last_repay_date as last_repay_date,
    ali.loan_way as loan_way,
    ali.create_time as loan_create_time,
    ali.discount_principal as discount_principal,
    ali.discount_interest as discount_interest,
    ali.discount_service_fee as discount_service_fee,
    ali.discount_penalty as discount_penalty,
    -- 授信申请进件规则记录
    get_json_object(carr.response_param, '$.failCode') as credit_fail_code,
    -- 用信申请进件规则记录
    get_json_object(uarr.response_param, '$.failCode') AS use_fail_code,
    uarr.business_type,
    tag.tag_value as cust_bussiness_tag 
from approve_credit_apply_day cre --授信申请表 
left join (select cust_no,create_time,credit_limit_amount,row_number() over(partition by cust_no order by create_time) as rk from approve_credit_apply_day where audit_status = 'PASS') fir_cre --授信首笔(成功)
    on cre.cust_no = fir_cre.cust_no and fir_cre.rk =1
left join (select cust_no,create_time,credit_limit_amount,row_number() over(partition by cust_no order by create_time desc) as rk_desc from approve_credit_apply_day where audit_status = 'PASS') las_cre --授信首笔(成功)
    on cre.cust_no = las_cre.cust_no and las_cre.rk_desc =1
left join approve_credit_apply_product_day pro -- 授信产品表_聚合授信维度
    on cre.id = pro.credit_apply_id
left join approve_use_credit_day as usc --用信申请表
    on cre.id  = usc.credit_apply_id
left join (select cust_no,min(create_time) as create_time from approve_use_credit_day where audit_status = 'PASS' group by cust_no) fir_use -- 用信首笔(成功)
    on cre.cust_no = fir_use.cust_no 
left join hello_prd.ods_mx_ast_asset_loan_apply_df ala --资产申请进件表
    on usc.asset_id = ala.seq_no and ala.pt = '${bdp.system.bizdate2}'
left join asset_loan_day ali--借据信息表
    on ala.loan_apply_no = ali.loan_apply_no 
left join (select cust_no,min(loan_start_date) as loan_start_date from asset_loan_day group by cust_no) fir_loan
    on cre.cust_no = fir_loan.cust_no  
--规则执行记录表 ods_mx_aprv_approve_rule_record_df 
-- 授信规则记录 授信申请ID对应最新一条规则记录
left join (select apply_id,response_param,business_type,row_number()over(partition by apply_id order by id desc) rk 
    from hello_prd.ods_mx_aprv_approve_rule_record_df 
    where pt = '${bdp.system.bizdate2}' and rule_type = 'CREDIT_APPLY' and is_delete = 0) as carr
    on cre.id = carr.apply_id and carr.rk=1
-- 用信规则记录 用信申请ID对应最新一条规则记录
left join (select apply_id,response_param,business_type,row_number()over(partition by apply_id order by id desc) rk 
    from hello_prd.ods_mx_aprv_approve_rule_record_df 
    where pt = '${bdp.system.bizdate2}' and rule_type = 'USE_CREDIT_APPLY' and is_delete = 0) as uarr
    on usc.id = uarr.apply_id and uarr.rk=1
left join hello_prd.ods_mx_cust_cust_account_tag_df tag 
    on cre.cust_no =tag.cust_no and tag_key = 'CREDIT_MODEL' and tag.pt = '${bdp.system.bizdate2}' 
;