------------------------------------------------------------------------------------------
-- 所属主题:：国际金融/ 贷中特征 feature etl
-- author：凡西
-- 事项：贷中部分订单类特征开发，分组名称：MEXICO_MULTI_LOAN_IN_LOAN_ORDER、MEXICO_MULTI_LOAN_ORDER_INFO

-- 重要提示：为了方便回溯测试 核对数据，我们以下的sql均以【每天发起用信申请的用户 + 用信申请时间】作为计算特征的目标人群；真实场景中以【调用特征用户当时的实际业务时间为准】
-- 代码主要分为PART1 和PART2 两部分；分别针对两波特征进行了计算，
------------------------------------------------------------------------------------------



-- 1）先构建一个用户样本；sql中以【每天发起用信申请的用户 + 用信申请时间】作为计算特征的目标人群；真实场景中以【调用特征用户当时的实际业务时间为准】
-- target_user只是服务于实时特征上线前，和后端结果回溯上线使用；
with target_user as (
    select create_time as use_create_time,cust_no
    from hive_idc.oversea.ods_mx_aprv_approve_use_credit_apply_df
    where pt ='${dt}' ---yyymmdd格式
    and replace(substr(create_time,1,10) ,'-', '')  ='${dt}'
),
-- 基于target_user中的用户和时间，我们把用户的授信、借款、还款的订单都拉出来，形成一个临时表，主要服务于在贷订单行为的统计；
target_user_credit_loan_repay_info as (
    select t3.*
          ,dense_rank()over(partition by t1.cust_no,t1.use_create_time order by t2.create_time asc) as order_asc_rank ---升序排序，1即为最远一笔
          ,dense_rank()over(partition by t1.cust_no,t1.use_create_time order by t2.create_time desc) as order_desc_rank ---降序排序，1即为最近一笔
          ,t7.create_time as credit_create_time
          ,t6.create_time as creadit_use_create_time
    from
    (
        select t1.cust_no
            ,t1.use_create_time
            ,t2.id
            ,t2.loan_info
            ,t2.settled_time
            ,t2.create_time
            ,t2.repaid_principal
            ,t2.period
        from target_user as t1
        left join (
            select *
            from hive_idc.oversea.ods_mx_ast_asset_repay_plan_df
            where pt ='${dt}' ---yyymmdd格式
            and replace(substr(create_time,1,10) ,'-', '') <='${dt}'
            and repay_plan_status != 4
        ) as t2
        on t1.cust_no = t2.cust_no
        where t2.create_time < t1.create_time    --约束查询之前该用户的还款计划数据
    ) as t3
    left join (select loan_info,loan_apply_no from hive_idc.oversea.ods_mx_ast_asset_loan_info_df where pt ='${dt}' and loan_status != 4) as t4 on t3.loan_no = t4.loan_no
    left join (select loan_apply_no,seq_no from hive_idc.oversea.ods_mx_ast_asset_loan_apply_df where pt ='${dt}') as t5 on t4.loan_apply_no = t5.loan_apply_no
    left join (select asset_id,create_time,credit_apply_id from hive_idc.oversea.ods_mx_aprv_approve_use_credit_apply_df where pt ='${dt}') as t6 on t5.seq_no = t6.asset_id
    left join (select id,create_time from hive_idc.oversea.ods_mx_aprv_approve_credit_apply_df where pt='${dt}' ) as t7 on t6.credit_apply_id = t7.id
    where t4.settled_time is null or t4.settled_time>t3.use_create_time --限制是未结清的订单
)


-----------------------------------------------------------------------------------------------
-- PART 1 : 第一部分特征

-- 2）调用实时特征时，对应用户历史订单行为（基于还款计划）；
-- and t2.update_time < t1.create_time   --约束查询之前该用户的还款计划数据
-- and (t2.settled_time is null or t2.settled_time < t1.create_time)   --约束查询之前该用户的还款计划数据
-- 在贷款订单逻辑：(t4.settled_time is null or t4.settled_time>t3.use_create_time)
-- 逾期账单的逻辑：t3.loan_end_date < substr(t3.use_create_time,1,10) and (t3.settled_time is null or substr(t3.settled_time,1,10)> t3.loan_end_date)
-- 在贷续借订单逻辑：(t4.settled_time is null or t4.settled_time>t3.use_create_time) and t3.order_asc_rank>1
-- 到期账单逻辑：t3.loan_end_date <= substr(t3.use_create_time,1,10)
-- 提前结清：t3.settled_time < t3.use_create_time and substr(t3.settled_time,1,10) < t3.loan_end_date

select t3.cust_no
      ,t3.use_create_time
      ----最远一笔订单相关
      ,count(if(t3.order_asc_rank=1 and t3.settled_time is not null and t3.settled_time < t3.use_create_time ,t3.id ,null)) as multi_loan_order_info_furthestsingleorder_completetermcnt
      ,count(if(t3.order_asc_rank=1 and t3.settled_time is not null and t3.settled_time < t3.use_create_time ,t3.id ,null))/count(if(t3.order_asc_rank=1, t3.id, null)) as multi_loan_order_info_furthestsingleorder_completetermratio
    --   ,sum(if(order_asc_rank=1 and settled_time is not null and settled_time < use_create_time , repaid_principal+repaid_interest+repaid_service_fee+repaid_penalty,0)) as multi_loan_in_loan_order_furthest_completedloanamount
      ,count(if(t3.order_asc_rank=1 and t3.settled_time is not null and t3.settled_time < t3.use_create_time and substr(t3.settled_time,1,10) < t3.loan_end_date, t3.id ,null)) as multi_loan_order_info_furthestsingleorder_completefutureduetermcnt
      ,count(if(t3.order_asc_rank=1 and t3.settled_time is not null and t3.settled_time < t3.use_create_time and substr(t3.settled_time,1,10) < t3.loan_end_date, t3.id ,null))/count(if(t3.order_asc_rank=1 and t3.settled_time is not null and t3.settled_time < t3.use_create_time ,t3.id ,null)) as multi_loan_order_info_furthestsingleorder_completefutureduetermratio
      ,count(if(t3.order_asc_rank=1 and t3.settled_time is not null and t3.settled_time < t3.use_create_time and substr(t3.settled_time,1,10) < t3.loan_end_date, t3.id ,null))/count(if(t3.order_asc_rank=1 and t3.loan_end_date >substr(t3.use_create_time,1,10) ,t3.id ,null)) as multi_loan_order_info_furthestsingleorder_prepayvsfuturebillingtermratio
    --   ,count(if(order_asc_rank=1 and settled_time is not null and settled_time < use_create_time and substr(settled_time,1,10) < loan_end_date,repaid_principal+repaid_interest+repaid_service_fee+repaid_penalty ,0)) as multi_loan_in_loan_order_furthest_completednotdueloanamount
      ,max(if(t3.order_asc_rank=1, t3.periods, null)) as multi_loan_order_info_furthestsingleorder_termscnt
      ,(datediff(max(if(t3.order_asc_rank=1, t3.loan_end_date, null)),min(if(t3.order_asc_rank=1, t3.loan_start_date, null))) + 1) as multi_loan_order_info_furthestsingleorder_payoutdays
      ,count(if(t3.order_asc_rank=1 and (t3.settled_time is null or t3.settled_time > t3.use_create_time) ,t3.id ,null)) as multi_loan_order_info_furthestsingleorder_incompletetermcnt
      ,count(if(t3.order_asc_rank=1 and t3.settled_time is not null and t3.settled_time < t3.use_create_time and substr(t3.settled_time,1,10) < t3.loan_end_date,t3.id ,null))/max(if(t3.order_asc_rank=1,t3.periods, null)) as multi_loan_order_info_furthestsingleorder_prepayvsalltermratio
      ,count(if(t3.order_asc_rank=1 and t3.settled_time is not null and t3.settled_time < t3.use_create_time and substr(t3.settled_time,1,10)> t3.loan_end_date,t3.id ,null))/count(if(t3.order_asc_rank=1 and t3.settled_time is not null and t3.settled_time < t3.use_create_time ,t3.id ,null)) as multi_loan_order_info_furthestsingleorder_overduevscompletedtermratio
      ,count(if(t3.order_asc_rank=1 and t3.loan_end_date < substr(t3.use_create_time,1,10) and (t3.settled_time is null or substr(t3.settled_time,1,10)> t3.loan_end_date),t3.id,null))/count(if(t3.order_asc_rank=1 and t3.loan_end_date <= substr(t3.use_create_time,1,10),t3.id,null)) as multi_loan_order_info_furthestsingleorder_overduevsbillingtermratio
      ,count(if(t3.order_asc_rank=1 and t3.loan_end_date < substr(t3.use_create_time,1,10) and (t3.settled_time is null or substr(t3.settled_time,1,10)> t3.loan_end_date),t3.id,null))/max(if(t3.order_asc_rank=1,t3.periods, null)) as multi_loan_order_info_furthestsingleorder_overduetermratio
      ,count(if(t3.order_asc_rank=1 and t3.loan_end_date < substr(t3.use_create_time,1,10) and (t3.settled_time is null or substr(t3.settled_time,1,10)> t3.loan_end_date),t3.id,null)) as multi_loan_order_info_furthestsingleorder_overduetermcnt
      ,datediff(min(if(t3.order_asc_rank=1 and t3.settled_time is not null and t3.settled_time < t3.use_create_time, cast(t3.settled_time as date), null)),min(if(t3.order_asc_rank=1,cast(t3.create_time as date), null))) as multi_loan_order_info_furthestsingleorder_firstcompletedcreatedgap
      ,datediff(cast(t3.use_create_time as date), min(if(t3.order_asc_rank=1,cast(t6.create_time as date), null))) as multi_loan_order_info_furthestsingleorder_creatednowgap
      ,max(if(t3.order_asc_rank=1 and substr(t6.create_time, 12, 2) in('11','12','13'), 1, 0)) as multi_loan_order_info_furthestsingleorder_creatednoon
      ,max(if(t3.order_asc_rank=1 and substr(t6.create_time, 12, 2) in('23','00','01','02','03','04'), 1, 0)) as multi_loan_order_info_furthestsingleorder_creatednight
      ,max(if(t3.order_asc_rank=1 and substr(t6.create_time, 12, 2) in('05','06','07','08','09','10'), 1, 0)) as multi_loan_order_info_furthestsingleorder_createdmorning
      ,max(if(t3.order_asc_rank=1 and substr(t6.create_time, 12, 2) in('18','19','20','21','22'), 1, 0)) as multi_loan_order_info_furthestsingleorder_createdevening
      ,max(if(t3.order_asc_rank=1 and substr(t6.create_time, 12, 2) in('14','15','16','17'), 1, 0)) as multi_loan_order_info_furthestsingleorder_createdafternoon
      ,count(if(t3.order_asc_rank=1 and t3.settled_time is not null and t3.settled_time < t3.use_create_time ,t3.id ,null))/count(if(t3.order_asc_rank=1 and t3.loan_end_date > substr(t3.use_create_time,1,10) ,t3.id ,null)) as multi_loan_order_info_furthestsingleorder_completevsfuturebillingtermratio
      ,min(if(t3.order_asc_rank=1 and t3.settled_time is not null and t3.settled_time < t3.use_create_time and substr(t3.settled_time,1,10) < t3.loan_end_date, datediff(cast(t3.loan_end_date as date), cast(substr(t3.settled_time,1,10) as date)),null)) as multi_loan_order_info_furthestsingleorder_completeprepaydaysmin
      ,avg(if(t3.order_asc_rank=1 and t3.settled_time is not null and t3.settled_time < t3.use_create_time and substr(t3.settled_time,1,10) < t3.loan_end_date, datediff(cast(t3.loan_end_date as date), cast(substr(t3.settled_time,1,10) as date)),null)) as multi_loan_order_info_furthestsingleorder_completeprepaydaysmean
      ,max(if(t3.order_asc_rank=1 and t3.settled_time is not null and t3.settled_time < t3.use_create_time and substr(t3.settled_time,1,10) < t3.loan_end_date, datediff(cast(t3.loan_end_date as date), cast(substr(t3.settled_time,1,10) as date)),null)) as multi_loan_order_info_furthestsingleorder_completeprepaydaysmax
      ,sum(if(t3.order_asc_rank=1 and t3.settled_time is not null and t3.settled_time < t3.use_create_time and dayofweek(str_to_date(substr(t3.settled_time,1,10), '%Y-%m-%d')) IN (1, 7), t3.repaid_principal+t3.repaid_interest+t3.repaid_service_fee+t3.repaid_penalty,0))/sum(if(t3.order_asc_rank=1 and t3.settled_time is not null and t3.settled_time < t3.use_create_time , t3.repaid_principal+t3.repaid_interest+t3.repaid_service_fee+t3.repaid_penalty,0)) as multi_loan_order_info_furthestsingleorder_completeonweekendprincipalratio
      ,count(if(t3.order_asc_rank=1 and t3.settled_time is not null and t3.settled_time < t3.use_create_time and substr(t3.settled_time,1,10) < t3.loan_end_date,t3.id ,null))/count(if(t3.order_asc_rank=1 and t3.settled_time is not null and t3.settled_time < t3.use_create_time and substr(t3.settled_time,1,10)<=t3.last_loan_end_date ,t3.id ,null)) as multi_loan_order_info_furthestsingleorder_billingprepayvscompletetermratio
      ,count(if(t3.order_asc_rank=1 and t3.settled_time is not null and t3.settled_time < t3.use_create_time and substr(t3.settled_time,1,10) < t3.loan_end_date,t3.id ,null))/count(if(t3.order_asc_rank=1 and t3.loan_end_date <= substr(t3.use_create_time,1,10),t3.id,null)) as multi_loan_order_info_furthestsingleorder_billingprepayvsbillingtermratio
      ----最近第一笔订单相关
      ,max(if(t3.order_desc_rank=1 and substr(t6.create_time, 12, 2) in('11','12','13'), 1, 0)) as multi_loan_order_info_latest1singleorder_creatednoon
      ,max(if(t3.order_desc_rank=1 and substr(t6.create_time, 12, 2) in('23','00','01','02','03','04'), 1, 0)) as multi_loan_order_info_latest1singleorder_creatednight
      ,max(if(t3.order_desc_rank=1 and substr(t6.create_time, 12, 2) in('05','06','07','08','09','10'), 1, 0)) as multi_loan_order_info_latest1singleorder_createdmorning
      ,max(if(t3.order_desc_rank=1 and substr(t6.create_time, 12, 2) in('18','19','20','21','22'), 1, 0)) as multi_loan_order_info_latest1singleorder_createdevening
      ,max(if(t3.order_desc_rank=1 and substr(t6.create_time, 12, 2) in('14','15','16','17'), 1, 0)) as multi_loan_order_info_latest1singleorder_createdafternoon
      ,max(if(t3.order_desc_rank=1,datediff(cast(t6.create_time as date),cast(t7.create_time as date)),null)) as multi_loan_order_info_latest1singleorder_createdcalccreditgap
      ,count(if(t3.order_desc_rank=1 and t3.settled_time is not null and t3.settled_time<t3.use_create_time and t3.loan_end_date >substr(t3.use_create_time,1,10),t3.id,null))/count(if(t3.order_desc_rank=1 and t3.loan_end_date >substr(t3.use_create_time,1,10),t3.id,null)) as multi_loan_order_info_latest1singleorder_completevsfuturebillingtermratio
      ,count(if(t3.order_desc_rank=1 and t3.settled_time is not null and t3.settled_time<t3.use_create_time, t3.id, null))/max(if(t3.order_desc_rank=1,t3.periods, null)) as multi_loan_order_info_latest1singleorder_completetermratio
      ,count(if(t3.order_desc_rank=1 and t3.settled_time is not null and t3.settled_time<t3.use_create_time, t3.id, null)) as multi_loan_order_info_latest1singleorder_completetermcnt
      ,min(if(t3.order_desc_rank=1 and t3.settled_time is not null and t3.settled_time < t3.use_create_time and substr(t3.settled_time,1,10) < t3.loan_end_date, datediff(cast(t3.loan_end_date as date), cast(substr(t3.settled_time,1,10) as date)),null)) as multi_loan_order_info_latest1singleorder_completeprepaydaysmin
      ,avg(if(t3.order_desc_rank=1 and t3.settled_time is not null and t3.settled_time < t3.use_create_time and substr(t3.settled_time,1,10) < t3.loan_end_date, datediff(cast(t3.loan_end_date as date), cast(substr(t3.settled_time,1,10) as date)),null)) as multi_loan_order_info_latest1singleorder_completeprepaydaysmean
      ,max(if(t3.order_desc_rank=1 and t3.settled_time is not null and t3.settled_time < t3.use_create_time and substr(t3.settled_time,1,10) < t3.loan_end_date, datediff(cast(t3.loan_end_date as date), cast(substr(t3.settled_time,1,10) as date)),null)) as multi_loan_order_info_latest1singleorder_completeprepaydaysmax
      ,count(if(t3.order_desc_rank=1 and t3.settled_time is not null and t3.settled_time < t3.use_create_time and substr(t3.settled_time,1,10) < t3.loan_end_date, t3.id ,null))/count(if(t3.order_desc_rank=1 and t3.settled_time is not null and t3.settled_time < t3.use_create_time ,t3.id ,null)) as multi_loan_order_info_latest1singleorder_completefutureduetermratio
      ,count(if(t3.order_desc_rank=1 and t3.settled_time is not null and t3.settled_time < t3.use_create_time and substr(t3.settled_time,1,10) < t3.loan_end_date, t3.id ,null)) as multi_loan_order_info_latest1singleorder_completefutureduetermcnt
      ,count(if(t3.order_desc_rank=1 and t3.settled_time is not null and t3.settled_time < t3.use_create_time and substr(t3.settled_time,1,10) < t3.loan_end_date,t3.id ,null))/count(if(t3.order_desc_rank=1 and t3.settled_time is not null and t3.settled_time < t3.use_create_time and substr(t3.settled_time,1,10)<=t3.last_loan_end_date ,t3.id ,null)) as multi_loan_order_info_latest1singleorder_billingprepayvscompletetermratio
      ,count(if(t3.order_desc_rank=1 and t3.settled_time is not null and t3.settled_time < t3.use_create_time and substr(t3.settled_time,1,10) < t3.loan_end_date,t3.id ,null))/count(if(t3.order_desc_rank=1 and t3.loan_end_date <= substr(t3.use_create_time,1,10),t3.id,null)) as multi_loan_order_info_latest1singleorder_billingprepayvsbillingtermratio
      ,datediff(cast(t3.use_create_time as date), min(if(t3.order_desc_rank=1,cast(t6.create_time as date), null))) as multi_loan_order_info_latest1singleorder_creatednowgap
      ,datediff(min(if(t3.order_desc_rank=1 and t3.settled_time is not null and t3.settled_time < t3.use_create_time, cast(t3.settled_time as date), null)),min(if(t3.order_desc_rank=1,cast(t3.create_time as date), null))) as multi_loan_order_info_latest1singleorder_firstcompletedcreatedgap
      ,count(if(t3.order_desc_rank=1 and (t3.settled_time is null or t3.settled_time > t3.use_create_time) ,t3.id ,null)) as multi_loan_order_info_latest1singleorder_incompletetermcnt
      ,count(if(t3.order_desc_rank=1 and t3.loan_end_date < substr(t3.use_create_time,1,10) and (t3.settled_time is null or substr(t3.settled_time,1,10)> t3.loan_end_date),t3.id,null)) as multi_loan_order_info_latest1singleorder_overduetermcnt
      ,count(if(t3.order_desc_rank=1 and t3.loan_end_date < substr(t3.use_create_time,1,10) and (t3.settled_time is null or substr(t3.settled_time,1,10)> t3.loan_end_date),t3.id,null))/max(if(t3.order_desc_rank=1,t3.periods, null)) as multi_loan_order_info_latest1singleorder_overduetermratio
      ,count(if(t3.order_desc_rank=1 and t3.loan_end_date < substr(t3.use_create_time,1,10) and (t3.settled_time is null or substr(t3.settled_time,1,10)> t3.loan_end_date),t3.id,null))/count(if(t3.order_desc_rank=1 and t3.loan_end_date <= substr(t3.use_create_time,1,10),t3.id,null)) as multi_loan_order_info_latest1singleorder_overduevsbillingtermratio
      ,count(if(t3.order_desc_rank=1 and t3.settled_time is not null and t3.settled_time < t3.use_create_time and substr(t3.settled_time,1,10)> t3.loan_end_date,t3.id ,null))/count(if(t3.order_desc_rank=1 and t3.settled_time is not null and t3.settled_time < t3.use_create_time ,t3.id ,null)) as multi_loan_order_info_latest1singleorder_overduevscompletedtermratio
      ,(datediff(max(if(t3.order_desc_rank=1, t3.loan_end_date, null)),min(if(t3.order_desc_rank=1, t3.loan_start_date, null))) + 1) as multi_loan_order_info_latest1singleorder_payoutdays
      ,count(if(t3.order_desc_rank=1 and t3.settled_time is not null and t3.settled_time < t3.use_create_time and substr(t3.settled_time,1,10) < t3.loan_end_date,t3.id ,null))/max(if(t3.order_desc_rank=1,t3.periods, null)) as multi_loan_order_info_latest1singleorder_prepayvsalltermratio
      ,count(if(t3.order_desc_rank=1 and t3.settled_time is not null and t3.settled_time < t3.use_create_time and substr(t3.settled_time,1,10) < t3.loan_end_date, t3.id ,null))/count(if(t3.order_desc_rank=1 and t3.loan_end_date >substr(t3.use_create_time,1,10) ,t3.id ,null)) as multi_loan_order_info_latest1singleorder_prepayvsfuturebillingtermratio
      ,max(if(t3.order_desc_rank=1, t3.periods, null)) as multi_loan_order_info_latest1singleorder_termscnt
      ----最近第二笔订单相关
      ,max(if(t3.order_desc_rank=2 and substr(t6.create_time, 12, 2) in('11','12','13'), 1, 0)) as multi_loan_order_info_latest2singleorder_creatednoon
      ,max(if(t3.order_desc_rank=2 and substr(t6.create_time, 12, 2) in('23','00','01','02','03','04'), 1, 0)) as multi_loan_order_info_latest2singleorder_creatednight
      ,max(if(t3.order_desc_rank=2 and substr(t6.create_time, 12, 2) in('05','06','07','08','09','10'), 1, 0)) as multi_loan_order_info_latest2singleorder_createdmorning
      ,max(if(t3.order_desc_rank=2 and substr(t6.create_time, 12, 2) in('18','19','20','21','22'), 1, 0)) as multi_loan_order_info_latest2singleorder_createdevening
      ,max(if(t3.order_desc_rank=2 and substr(t6.create_time, 12, 2) in('14','15','16','17'), 1, 0)) as multi_loan_order_info_latest2singleorder_createdafternoon
      ,max(if(t3.order_desc_rank=2,datediff(cast(t6.create_time as date),cast(t7.create_time as date)),null)) as multi_loan_order_info_latest2singleorder_createdcalccreditgap
      ,count(if(t3.order_desc_rank=2 and t3.settled_time is not null and t3.settled_time<t3.use_create_time and t3.loan_end_date >substr(t3.use_create_time,1,10),t3.id,null))/count(if(t3.order_desc_rank=2 and t3.loan_end_date >substr(t3.use_create_time,1,10),t3.id,null)) as multi_loan_order_info_latest2singleorder_completevsfuturebillingtermratio
      ,count(if(t3.order_desc_rank=2 and t3.settled_time is not null and t3.settled_time<t3.use_create_time, t3.id, null))/max(if(t3.order_desc_rank=2,t3.periods, null)) as multi_loan_order_info_latest2singleorder_completetermratio
      ,count(if(t3.order_desc_rank=2 and t3.settled_time is not null and t3.settled_time<t3.use_create_time, t3.id, null)) as multi_loan_order_info_latest2singleorder_completetermcnt
      ,min(if(t3.order_desc_rank=2 and t3.settled_time is not null and t3.settled_time < t3.use_create_time and substr(t3.settled_time,1,10) < t3.loan_end_date, datediff(cast(t3.loan_end_date as date), cast(substr(t3.settled_time,1,10) as date)),null)) as multi_loan_order_info_latest2singleorder_completeprepaydaysmin
      ,avg(if(t3.order_desc_rank=2 and t3.settled_time is not null and t3.settled_time < t3.use_create_time and substr(t3.settled_time,1,10) < t3.loan_end_date, datediff(cast(t3.loan_end_date as date), cast(substr(t3.settled_time,1,10) as date)),null)) as multi_loan_order_info_latest2singleorder_completeprepaydaysmean
      ,max(if(t3.order_desc_rank=2 and t3.settled_time is not null and t3.settled_time < t3.use_create_time and substr(t3.settled_time,1,10) < t3.loan_end_date, datediff(cast(t3.loan_end_date as date), cast(substr(t3.settled_time,1,10) as date)),null)) as multi_loan_order_info_latest2singleorder_completeprepaydaysmax
      ,count(if(t3.order_desc_rank=2 and t3.settled_time is not null and t3.settled_time < t3.use_create_time and substr(t3.settled_time,1,10) < t3.loan_end_date, t3.id ,null))/count(if(t3.order_desc_rank=2 and t3.settled_time is not null and t3.settled_time < t3.use_create_time ,t3.id ,null)) as multi_loan_order_info_latest2singleorder_completefutureduetermratio
      ,count(if(t3.order_desc_rank=2 and t3.settled_time is not null and t3.settled_time < t3.use_create_time and substr(t3.settled_time,1,10) < t3.loan_end_date, t3.id ,null)) as multi_loan_order_info_latest2singleorder_completefutureduetermcnt
      ,count(if(t3.order_desc_rank=2 and t3.settled_time is not null and t3.settled_time < t3.use_create_time and substr(t3.settled_time,1,10) < t3.loan_end_date,t3.id ,null))/count(if(t3.order_desc_rank=2 and t3.settled_time is not null and t3.settled_time < t3.use_create_time and substr(t3.settled_time,1,10)<=t3.last_loan_end_date ,t3.id ,null)) as multi_loan_order_info_latest2singleorder_billingprepayvscompletetermratio
      ,count(if(t3.order_desc_rank=2 and t3.settled_time is not null and t3.settled_time < t3.use_create_time and substr(t3.settled_time,1,10) < t3.loan_end_date,t3.id ,null))/count(if(t3.order_desc_rank=2 and t3.loan_end_date <= substr(t3.use_create_time,1,10),t3.id,null)) as multi_loan_order_info_latest2singleorder_billingprepayvsbillingtermratio
      ,datediff(cast(t3.use_create_time as date), min(if(t3.order_desc_rank=2,cast(t6.create_time as date), null))) as multi_loan_order_info_latest2singleorder_creatednowgap
      ,datediff(min(if(t3.order_desc_rank=2 and t3.settled_time is not null and t3.settled_time < t3.use_create_time, cast(t3.settled_time as date), null)),min(if(t3.order_desc_rank=2,cast(t3.create_time as date), null))) as multi_loan_order_info_latest2singleorder_firstcompletedcreatedgap
      ,count(if(t3.order_desc_rank=2 and (t3.settled_time is null or t3.settled_time > t3.use_create_time) ,t3.id ,null)) as multi_loan_order_info_latest2singleorder_incompletetermcnt
      ,count(if(t3.order_desc_rank=2 and t3.loan_end_date < substr(t3.use_create_time,1,10) and (t3.settled_time is null or substr(t3.settled_time,1,10)> t3.loan_end_date),t3.id,null)) as multi_loan_order_info_latest2singleorder_overduetermcnt
      ,count(if(t3.order_desc_rank=2 and t3.loan_end_date < substr(t3.use_create_time,1,10) and (t3.settled_time is null or substr(t3.settled_time,1,10)> t3.loan_end_date),t3.id,null))/max(if(t3.order_desc_rank=2,t3.periods, null)) as multi_loan_order_info_latest2singleorder_overduetermratio
      ,count(if(t3.order_desc_rank=2 and t3.loan_end_date < substr(t3.use_create_time,1,10) and (t3.settled_time is null or substr(t3.settled_time,1,10)> t3.loan_end_date),t3.id,null))/count(if(t3.order_desc_rank=2 and t3.loan_end_date <= substr(t3.use_create_time,1,10),t3.id,null)) as multi_loan_order_info_latest2singleorder_overduevsbillingtermratio
      ,count(if(t3.order_desc_rank=2 and t3.settled_time is not null and t3.settled_time < t3.use_create_time and substr(t3.settled_time,1,10)> t3.loan_end_date,t3.id ,null))/count(if(t3.order_desc_rank=2 and t3.settled_time is not null and t3.settled_time < t3.use_create_time ,t3.id ,null)) as multi_loan_order_info_latest2singleorder_overduevscompletedtermratio
      ,(datediff(max(if(t3.order_desc_rank=2, t3.loan_end_date, null)),min(if(t3.order_desc_rank=2, t3.loan_start_date, null))) + 1) as multi_loan_order_info_latest2singleorder_payoutdays
      ,count(if(t3.order_desc_rank=2 and t3.settled_time is not null and t3.settled_time < t3.use_create_time and substr(t3.settled_time,1,10) < t3.loan_end_date,t3.id ,null))/max(if(t3.order_desc_rank=2,t3.periods, null)) as multi_loan_order_info_latest2singleorder_prepayvsalltermratio
      ,count(if(t3.order_desc_rank=2 and t3.settled_time is not null and t3.settled_time < t3.use_create_time and substr(t3.settled_time,1,10) < t3.loan_end_date, t3.id ,null))/count(if(t3.order_desc_rank=2 and t3.loan_end_date >substr(t3.use_create_time,1,10) ,t3.id ,null)) as multi_loan_order_info_latest2singleorder_prepayvsfuturebillingtermratio
      ,max(if(t3.order_desc_rank=2, t3.periods, null)) as multi_loan_order_info_latest2singleorder_termscnt
      ----未来90-180天订单特征、0-90天特征
      ,count(if(t3.loan_end_date>=date_add(substr(t3.use_create_time, 1, 10),90) and t3.loan_end_date<=date_add(substr(t3.use_create_time, 1, 10),180) and (t3.settled_time is null or t3.settled_time>t3.use_create_time),t3.id,null)) as multi_loan_order_info_multiloanrangefuture90dto180d_futurebillingunclearinstalcnt
      ,count(if(t3.loan_end_date>date_add(substr(t3.use_create_time, 1, 10),0) and t3.loan_end_date<=date_add(substr(t3.use_create_time, 1, 10),90) and (t3.settled_time is null or t3.settled_time>t3.use_create_time),t3.id,null)) as multi_loan_order_info_multiloanrangefuture0dto90d_futurebillingunclearinstalcnt
      ----过去30天订单信息
      ,count(distinct if(substr(t3.create_time,1,10) < substr(t3.use_create_time,1,10) and substr(t3.create_time,1,10)>=date_add(substr(t3.use_create_time,1,10),-30),t3.loan_no,null)) as multi_loan_order_info_multiloan30dstat_payoutordercnt
      ,count(distinct if(t3.order_asc_rank>1 and substr(t3.create_time,1,10) < substr(t3.use_create_time,1,10) and substr(t3.create_time,1,10)>=date_add(substr(t3.use_create_time,1,10),-30),t3.loan_no,null)) as multi_loan_order_info_multiloan30dstat_payoutmultiloanordercnt
      ----过去90天订单信息
      ,count(if(substr(t3.settled_time,1,10) < substr(t3.use_create_time,1,10) and substr(t3.settled_time,1,10)>=date_add(substr(t3.use_create_time,1,10),-90), t3.id,null)) as multi_loan_order_info_multiloannoloanclear90dstat_clearordercnt
      ,count(if(substr(t3.settled_time,1,10) < substr(t3.use_create_time,1,10) and substr(t3.settled_time,1,10)>=date_add(substr(t3.use_create_time,1,10),-90), t3.id,null))/count(if(t3.loan_end_date <= substr(t3.use_create_time,1,10) and t3.loan_end_date>=date_add(substr(t3.use_create_time,1,10),-90), t3.id,null)) as multi_loan_order_info_multiloannoloanclear90dstat_clearorderratio
      ,count(distinct if(substr(t3.create_time,1,10) < substr(t3.use_create_time,1,10) and substr(t3.create_time,1,10)>=date_add(substr(t3.use_create_time,1,10),-90),t3.loan_no,null)) as multi_loan_order_info_multiloan90dstat_payoutordercnt
      ,count(distinct if(t3.order_asc_rank>1 and substr(t3.create_time,1,10) < substr(t3.use_create_time,1,10) and substr(t3.create_time,1,10)>=date_add(substr(t3.use_create_time,1,10),-90),t3.loan_no,null)) as multi_loan_order_info_multiloan90dstat_payoutmultiloanordercnt
      ----过去180天订单信息
      ,count(if(substr(t3.settled_time,1,10) < substr(t3.use_create_time,1,10) and substr(t3.settled_time,1,10)>=date_add(substr(t3.use_create_time,1,10),-180), t3.id,null)) as multi_loan_order_info_multiloannoloanclear180dstat_clearordercnt
      ,count(if(substr(t3.settled_time,1,10) < substr(t3.use_create_time,1,10) and substr(t3.settled_time,1,10)>=date_add(substr(t3.use_create_time,1,10),-180), t3.id,null))/count(if(t3.loan_end_date <= substr(t3.use_create_time,1,10) and t3.loan_end_date>=date_add(substr(t3.use_create_time,1,10),-180), t3.id,null)) as multi_loan_order_info_multiloannoloanclear180dstat_clearorderratio
      -----在贷、续借订单的几个特征(loan_info表中settled_time代表用户订单整笔结清时间)：MEXICO_MULTI_LOAN_ORDER_INFO
      ,count(if((t4.settled_time is null or t4.settled_time>t3.use_create_time) and t3.loan_end_date < substr(t3.use_create_time,1,10) and (t3.settled_time is null or substr(t3.settled_time,1,10)> t3.loan_end_date), t3.id,null)) as multi_loan_order_info_inloanorders_overduetermcnt
      ,count(if((t4.settled_time is null or t4.settled_time>t3.use_create_time) and t3.settled_time<t3.use_create_time, t3.id, null)) as multi_loan_order_info_inloanorders_completetermcnt
      ,count(if((t4.settled_time is null or t4.settled_time>t3.use_create_time) and t3.settled_time<t3.use_create_time, t3.id, null))/count(if(t4.settled_time is null or t4.settled_time>t3.use_create_time, t3.id, null)) as multi_loan_order_info_inloanorders_completetermratio
      ,sum(if((t4.settled_time is null or t4.settled_time>t3.use_create_time) and t3.settled_time<t3.use_create_time, t3.repaid_principal, 0)) as multi_loan_order_info_inloanorders_completeprincipal

      ,count(if((t4.settled_time is null or t4.settled_time>t3.use_create_time) and t3.loan_end_date < substr(t3.use_create_time,1,10) and (t3.settled_time is null or substr(t3.settled_time,1,10)> t3.loan_end_date),t3.id,null))/count(if((t4.settled_time is null or t4.settled_time>t3.use_create_time) and t3.settled_time<t3.use_create_time,t3.id,null)) as multi_loan_order_info_inloanorders_overduevscompletetermratio
      ,count(if((t4.settled_time is null or t4.settled_time>t3.use_create_time) and t3.loan_end_date < substr(t3.use_create_time,1,10) and (t3.settled_time is null or substr(t3.settled_time,1,10)> t3.loan_end_date),t3.id,null))/count(if((t4.settled_time is null or t4.settled_time>t3.use_create_time) and t3.loan_end_date<=substr(t3.use_create_time,1,10),t3.id,null)) as multi_loan_order_info_inloanorders_overduevsbillingtermratio
      ---注意：这里的t3.period =1是为了去重去这个订单的create_time创建时间作为打款时间，后端实现逻辑可以自己考虑
      ,stddev(datediff(if((t4.settled_time is null or t4.settled_time>t3.use_create_time) and t3.period =1,cast(t3.create_time as date),null),if((t4.settled_time is null or t4.settled_time>t3.use_create_time) and t3.period =1,cast(t7.create_time as date),null))) as multi_loan_order_info_inloanorders_calccreditgapstd
      ,min(datediff(if((t4.settled_time is null or t4.settled_time>t3.use_create_time) and t3.period =1,cast(t3.create_time as date),null),if((t4.settled_time is null or t4.settled_time>t3.use_create_time) and t3.period =1,cast(t7.create_time as date),null))) as multi_loan_order_info_inloanorders_calccreditgapmin
      ,avg(datediff(if((t4.settled_time is null or t4.settled_time>t3.use_create_time) and t3.period =1,cast(t3.create_time as date),null),if((t4.settled_time is null or t4.settled_time>t3.use_create_time) and t3.period =1,cast(t7.create_time as date),null))) as multi_loan_order_info_inloanorders_calccreditgapmean
      ,max(datediff(if((t4.settled_time is null or t4.settled_time>t3.use_create_time) and t3.period =1,cast(t3.create_time as date),null),if((t4.settled_time is null or t4.settled_time>t3.use_create_time) and t3.period =1,cast(t7.create_time as date),null))) as multi_loan_order_info_inloanorders_calccreditgapmax
      ,count(if((t4.settled_time is null or t4.settled_time>t3.use_create_time) and t3.loan_end_date < substr(t3.use_create_time,1,10) and (t3.settled_time is null or substr(t3.settled_time,1,10)> t3.loan_end_date), t3.id,null))/count(if((t4.settled_time is null or t4.settled_time>t3.use_create_time) and t3.settled_time<t3.use_create_time, t3.id, null)) as multi_loan_order_info_multiloanorders_overduevscompletetermratio
      ,count(if((t4.settled_time is null or t4.settled_time>t3.use_create_time) and t3.order_asc_rank>1 and t3.loan_end_date < substr(t3.use_create_time,1,10) and (t3.settled_time is null or substr(t3.settled_time,1,10)> t3.loan_end_date), t3.id,null))/count(if((t4.settled_time is null or t4.settled_time>t3.use_create_time) and t3.order_asc_rank>1 and t3.loan_end_date <= substr(t3.use_create_time,1,10),t3.id,null)) as multi_loan_order_info_multiloanorders_overduevsbillingtermratio
      ,count(if((t4.settled_time is null or t4.settled_time>t3.use_create_time) and t3.order_asc_rank>1 and t3.loan_end_date < substr(t3.use_create_time,1,10) and (t3.settled_time is null or substr(t3.settled_time,1,10)> t3.loan_end_date), t3.id,null)) as multi_loan_order_info_multiloanorders_overduetermcnt
      ,stddev(if((t4.settled_time is null or t4.settled_time>t3.use_create_time) and t3.order_asc_rank>1 and t3.period=1, t4.real_loan_amt,0)) as multi_loan_order_info_multiloanorders_orderprincipalstd
      ,count(if((t4.settled_time is null or t4.settled_time>t3.use_create_time) and t3.order_asc_rank>1 and t3.settled_time<t3.use_create_time, t3.id, null))/count(if(t4.settled_time is null or t4.settled_time>t3.use_create_time and t3.order_asc_rank>1, t3.id, null)) as multi_loan_order_info_multiloanorders_completetermratio
      ,count(if((t4.settled_time is null or t4.settled_time>t3.use_create_time) and t3.order_asc_rank>1 and t3.settled_time<t3.use_create_time, t3.id, null)) as multi_loan_order_info_multiloanorders_completetermcnt
      ,sum(if((t4.settled_time is null or t4.settled_time>t3.use_create_time) and t3.order_asc_rank>1 and t3.settled_time<t3.use_create_time, t3.repaid_principal, 0)) as multi_loan_order_info_multiloanorders_completeprincipal
      ,stddev(datediff(if((t4.settled_time is null or t4.settled_time>t3.use_create_time)  and t3.order_asc_rank>1 and t3.period =1,cast(t3.create_time as date),null),if((t4.settled_time is null or t4.settled_time>t3.use_create_time) and t3.order_asc_rank>1 and t3.period =1,cast(t7.create_time as date),null))) as multi_loan_order_info_multiloanorders_calccreditgapstd
      ,min(datediff(if((t4.settled_time is null or t4.settled_time>t3.use_create_time) and t3.order_asc_rank>1 and t3.period =1,cast(t3.create_time as date),null),if((t4.settled_time is null or t4.settled_time>t3.use_create_time) and t3.order_asc_rank>1 and t3.period =1,cast(t7.create_time as date),null))) as multi_loan_order_info_multiloanorders_calccreditgapmin
      ,avg(datediff(if((t4.settled_time is null or t4.settled_time>t3.use_create_time) and t3.order_asc_rank>1 and t3.period =1,cast(t3.create_time as date),null),if((t4.settled_time is null or t4.settled_time>t3.use_create_time) and t3.order_asc_rank>1 and t3.period =1,cast(t7.create_time as date),null))) as multi_loan_order_info_multiloanorders_calccreditgapmean
      ,max(datediff(if((t4.settled_time is null or t4.settled_time>t3.use_create_time) and t3.order_asc_rank>1 and t3.period =1,cast(t3.create_time as date),null),if((t4.settled_time is null or t4.settled_time>t3.use_create_time) and t3.order_asc_rank>1 and t3.period =1,cast(t7.create_time as date),null))) as multi_loan_order_info_multiloanorders_calccreditgapmax
      ----在贷订单另外一批：MEXICO_MULTI_LOAN_IN_LOAN_ORDER
      ,count(if((t4.settled_time is null or t4.settled_time>t3.use_create_time) and t3.order_asc_rank>1 and t3.settled_time < t3.use_create_time and substr(t3.settled_time,1,10) < date_add(t3.loan_end_date,-15),t3.id,null)) as multi_loan_in_loan_order_all_advanceget15days_completedadvanceinstalcnt
      ,count(if((t4.settled_time is null or t4.settled_time>t3.use_create_time) and t3.order_asc_rank>1 and t3.settled_time < t3.use_create_time and substr(t3.settled_time,1,10) < date_add(t3.loan_end_date,-15),t3.id,null))/count(if((t4.settled_time is null or t4.settled_time>t3.use_create_time) and t3.order_asc_rank>1 and t3.settled_time < t3.use_create_time and substr(t3.settled_time,1,10) < t3.loan_end_date,t3.id,null)) as multi_loan_in_loan_order_all_advanceget15days_completedadvanceinstaloverallcompletedadvanceratio
      ,count(if((t4.settled_time is null or t4.settled_time>t3.use_create_time) and t3.order_asc_rank>1 and t3.settled_time < t3.use_create_time and substr(t3.settled_time,1,10) < date_add(t3.loan_end_date,-15),t3.id,null))/count(if((t4.settled_time is null or t4.settled_time>t3.use_create_time) and t3.order_asc_rank>1 and (t3.settled_time < t3.use_create_time or t3.loan_end_date <= substr(t3.use_create_time,1,10)),t3.id,null)) as multi_loan_in_loan_order_all_advanceget15days_completedadvanceinstaloverdueorcompletedratio
      ,count(if((t4.settled_time is null or t4.settled_time>t3.use_create_time) and t3.order_asc_rank>1 and t3.settled_time < t3.use_create_time and substr(t3.settled_time,1,10) < date_add(t3.loan_end_date,-7),t3.id,null)) as multi_loan_in_loan_order_all_advanceget7days_completedadvanceinstalcnt
      ,count(if((t4.settled_time is null or t4.settled_time>t3.use_create_time) and t3.order_asc_rank>1 and t3.settled_time < t3.use_create_time and substr(t3.settled_time,1,10) < date_add(t3.loan_end_date,-7),t3.id,null))/count(if((t4.settled_time is null or t4.settled_time>t3.use_create_time) and t3.order_asc_rank>1 and t3.settled_time < t3.use_create_time and substr(t3.settled_time,1,10) < t3.loan_end_date,t3.id,null)) as multi_loan_in_loan_order_all_advanceget7days_completedadvanceinstaloverallcompletedadvanceratio
      ,count(if((t4.settled_time is null or t4.settled_time>t3.use_create_time) and t3.order_asc_rank>1 and t3.settled_time < t3.use_create_time and substr(t3.settled_time,1,10) < date_add(t3.loan_end_date,-7),t3.id,null))/count(if((t4.settled_time is null or t4.settled_time>t3.use_create_time) and t3.order_asc_rank>1 and (t3.settled_time < t3.use_create_time or t3.loan_end_date <= substr(t3.use_create_time,1,10)),t3.id,null)) as multi_loan_in_loan_order_all_advanceget7days_completedadvanceinstaloverdueorcompletedratio
      ,count(if((t4.settled_time is null or t4.settled_time>t3.use_create_time) and t3.order_asc_rank>1 and t3.settled_time < t3.use_create_time and substr(t3.settled_time,1,10) < date_add(t3.loan_end_date,-3),t3.id,null)) as multi_loan_in_loan_order_all_advanceget3days_completedadvanceinstalcnt
      ,count(if((t4.settled_time is null or t4.settled_time>t3.use_create_time) and t3.order_asc_rank>1 and t3.settled_time < t3.use_create_time and substr(t3.settled_time,1,10) < date_add(t3.loan_end_date,-3),t3.id,null))/count(if((t4.settled_time is null or t4.settled_time>t3.use_create_time) and t3.order_asc_rank>1 and t3.settled_time < t3.use_create_time and substr(t3.settled_time,1,10) < t3.loan_end_date,t3.id,null)) as multi_loan_in_loan_order_all_advanceget3days_completedadvanceinstaloverallcompletedadvanceratio
      ,count(if((t4.settled_time is null or t4.settled_time>t3.use_create_time) and t3.order_asc_rank>1 and t3.settled_time < t3.use_create_time and substr(t3.settled_time,1,10) < date_add(t3.loan_end_date,-3),t3.id,null))/count(if((t4.settled_time is null or t4.settled_time>t3.use_create_time) and t3.order_asc_rank>1 and (t3.settled_time < t3.use_create_time or t3.loan_end_date <= substr(t3.use_create_time,1,10)),t3.id,null)) as multi_loan_in_loan_order_all_advanceget3days_completedadvanceinstaloverdueorcompletedratio
      ,count(if((t4.settled_time is null or t4.settled_time>t3.use_create_time) and t3.order_asc_rank>1 and t3.settled_time < t3.use_create_time and substr(t3.settled_time,1,10) < t3.loan_end_date, t3.id,null)) as multi_loan_in_loan_order_all_completedadvanceinstalcnt
      ,count(if((t4.settled_time is null or t4.settled_time>t3.use_create_time) and t3.order_asc_rank>1 and t3.settled_time < t3.use_create_time and substr(t3.settled_time,1,10) < t3.loan_end_date,t3.id,null))/count(if((t4.settled_time is null or t4.settled_time>t3.use_create_time) and t3.order_asc_rank>1 and (t3.settled_time < t3.use_create_time or t3.loan_end_date <= substr(t3.use_create_time,1,10)),t3.id,null)) as multi_loan_in_loan_order_all_completedadvanceinstalratio
      ,sum(if((t4.settled_time is null or t4.settled_time>t3.use_create_time) and t3.order_asc_rank>1 and t3.settled_time < t3.use_create_time and substr(t3.settled_time,1,10) >= date_add(t3.loan_end_date,-30) and substr(t3.settled_time,1,10) < date_add(t3.loan_end_date,0) ,t3.repaid_principal,0))/sum(if((t4.settled_time is null or t4.settled_time>t3.use_create_time) and t3.order_asc_rank>1 and t3.settled_time < t3.use_create_time,t3.repaid_principal,0)) as multi_loan_in_loan_order_all_completedadvanceloanamountovercompletedratioforfirstmonth
      ,count(if((t4.settled_time is null or t4.settled_time>t3.use_create_time) and t3.order_asc_rank>1 and t3.settled_time < t3.use_create_time,t3.id,null)) as multi_loan_in_loan_order_all_completedinstalcnt
      ,count(if((t4.settled_time is null or t4.settled_time>t3.use_create_time) and t3.order_asc_rank>1 and t3.settled_time < t3.use_create_time,t3.id,null))/count(if((t4.settled_time is null or t4.settled_time>t3.use_create_time) and t3.order_asc_rank>1,t3.id,null)) as multi_loan_in_loan_order_all_completedinstalratio
      ,sum(if((t4.settled_time is null or t4.settled_time>t3.use_create_time) and t3.order_asc_rank>1 and t3.settled_time < t3.use_create_time,t3.repaid_principal,0)) as multi_loan_in_loan_order_all_completedloanamount
      ,avg(if((t4.settled_time is null or t4.settled_time>t3.use_create_time) and t3.order_asc_rank>1 and t3.period=1,datediff(cast(t3.use_create_time as date), cast(t6.create_time as date)),null)) as multi_loan_in_loan_order_all_createdorderdaysgapmathcount_avg
      ,max(if((t4.settled_time is null or t4.settled_time>t3.use_create_time) and t3.order_asc_rank>1 and t3.period=1,datediff(cast(t3.use_create_time as date), cast(t6.create_time as date)),null)) as multi_loan_in_loan_order_all_createdorderdaysgapmathcount_max
      ,stddev(if((t4.settled_time is null or t4.settled_time>t3.use_create_time) and t3.order_asc_rank>1 and t3.period=1,datediff(cast(t3.use_create_time as date), cast(t6.create_time as date)),null)) as multi_loan_in_loan_order_all_createdorderdaysgapmathcount_std
      ,max(if((t4.settled_time is null or t4.settled_time>t3.use_create_time) and t3.order_asc_rank>1 and t3.loan_end_date < substr(t3.use_create_time,1,10) and (t3.settled_time is null or substr(t3.settled_time,1,10)> t3.loan_end_date), datediff(cast(t3.loan_end_date as date), cast(t6.create_time as date)),null)) as multi_loan_in_loan_order_all_lastoverdueinstalrisktimegap

from
(
    select t1.cust_no
          ,t1.use_create_time
          ,t2.id
          ,t2.loan_info
          ,t2.settled_time
          ,t2.create_time
          ,dense_rank()over(partition by t1.cust_no,t1.use_create_time order by t2.create_time asc) as order_asc_rank ---升序排序，1即为最远一笔
          ,dense_rank()over(partition by t1.cust_no,t1.use_create_time order by t2.create_time desc) as order_desc_rank ---降序排序，1即为最近一笔
          ,last_value(t2.loan_end_date) over (partition by t1.cust_no,t1.use_create_time,t2.loan_info order by t2.loan_end_date desc) as last_loan_end_date --该笔订单的整体到期时间
          ,t3.period
    from target_user as t1
    left join (
        select *
        from hive_idc.oversea.ods_mx_ast_asset_repay_plan_df
        where pt ='${dt}' ---yyymmdd格式
        and replace(substr(create_time,1,10) ,'-', '') <='${dt}'
        and repay_plan_status != 4
    ) as t2
    on t1.cust_no = t2.cust_no
    where t2.create_time < t1.create_time    --约束查询之前该用户的还款计划数据
) as t3
left join (select loan_info,loan_apply_no,settled_time from hive_idc.oversea.ods_mx_ast_asset_loan_info_df where pt ='${dt}' and loan_status != 4) as t4 on t3.loan_no = t4.loan_no
left join (select loan_apply_no,seq_no from hive_idc.oversea.ods_mx_ast_asset_loan_apply_df where pt ='${dt}') as t5 on t4.loan_apply_no = t5.loan_apply_no
left join (select asset_id,create_time,credit_apply_id from hive_idc.oversea.ods_mx_aprv_approve_use_credit_apply_df where pt ='${dt}') as t6 on t5.seq_no = t6.asset_id
left join (select id,create_time from hive_idc.oversea.ods_mx_aprv_approve_credit_apply_df where pt='${dt}' ) as t7 on t6.credit_apply_id = t7.id




-----------------------------------------------------------------------------------------------
--PART 2 : 第二部分特征（针对在贷订单的首次和末次、最近第二次等特征）

select cust_no
      ,use_create_time
      ---最远一笔订单的特征，MEXICO_MULTI_LOAN_IN_LOAN_ORDER，
      ,count(if(order_asc_rank=1 and settled_time is not null and settled_time <use_create_time ,id ,null)) as multi_loan_in_loan_order_furthest_completedinstalcnt
      ,count(if(order_asc_rank=1 and settled_time is not null and settled_time <use_create_time ,id ,null))/count(if(order_asc_rank=1,id ,null)) as multi_loan_in_loan_order_furthest_completedinstalratio
      ,sum(if(order_asc_rank=1 and settled_time is not null and settled_time <use_create_time ,repaid_principal ,0)) as multi_loan_in_loan_order_furthest_completedloanamount
      ,count(if(order_asc_rank=1 and settled_time is not null and settled_time <use_create_time and substr(settled_time,1,10) < loan_end_date ,id ,null)) as multi_loan_in_loan_order_furthest_completednotdueinstalcnt
      ,count(if(order_asc_rank=1 and settled_time is not null and settled_time <use_create_time and substr(settled_time,1,10) < loan_end_date ,id ,null))/count(if(order_asc_rank=1 and settled_time is not null and settled_time <use_create_time ,id ,null))  as multi_loan_in_loan_order_furthest_completednotdueinstalovercompletedratio
      ,count(if(order_asc_rank=1 and settled_time is not null and settled_time <use_create_time and substr(settled_time,1,10) < loan_end_date ,id ,null))/count(if(order_asc_rank=1 and loan_end_date>substr(use_create_time,1,10),id,null)) as multi_loan_in_loan_order_furthest_completednotdueinstalovernotdueratio
      ,sum(if(order_asc_rank=1 and settled_time is not null and settled_time <use_create_time and substr(settled_time,1,10) < loan_end_date ,repaid_principal ,0)) as multi_loan_in_loan_order_furthest_completednotdueloanamount
      ,max(if(order_asc_rank=1,period,null)) as multi_loan_in_loan_order_furthest_instalmentcnt
      ,(datediff(max(if(order_asc_rank=1, loan_end_date, null)),min(if(order_asc_rank=1, loan_start_date, null))) + 1) as multi_loan_in_loan_order_furthest_payoutdays
      ,count(if(order_asc_rank=1 and (settled_time is null or settled_time>use_create_time),id,null)) as multi_loan_in_loan_order_furthest_uncompletedinstalcnt
      ,max(if(order_asc_rank=1,datediff(cast(creadit_use_create_time as date),cast(credit_create_time as date)),null)) as multi_loan_in_loan_order_furthest_createdtimecalccreditsgap
     ---最近一笔订单的特征，MEXICO_MULTI_LOAN_IN_LOAN_ORDER，
     ,avg(if(order_desc_rank=1 and settled_time is not null and settled_time < use_create_time and substr(settled_time,1,10) < loan_end_date, datediff(cast(loan_end_date as date), cast(substr(settled_time,1,10) as date)),null)) as multi_loan_in_loan_order_recentfirst_completedadvanceinstaldaysavg
     ,max(if(order_desc_rank=1 and settled_time is not null and settled_time < use_create_time and substr(settled_time,1,10) < loan_end_date, datediff(cast(loan_end_date as date), cast(substr(settled_time,1,10) as date)),null)) as multi_loan_in_loan_order_recentfirst_completedadvanceinstaldaysmax
     ,stddev(if(order_desc_rank=1 and settled_time is not null and settled_time < use_create_time and substr(settled_time,1,10) < loan_end_date, datediff(cast(loan_end_date as date), cast(substr(settled_time,1,10) as date)),null)) as multi_loan_in_loan_order_recentfirst_completedadvanceinstaldaysstd
     ,count(if(order_desc_rank=1 and settled_time is not null and settled_time <use_create_time ,id ,null)) as multi_loan_in_loan_order_recentfirst_completedinstalcnt
     ,count(if(order_desc_rank=1 and settled_time is not null and settled_time <use_create_time ,id ,null))/count(if(order_desc_rank=1,id ,null)) as multi_loan_in_loan_order_recentfirst_completedinstalratio
     ,count(if(order_desc_rank=1 and settled_time is not null and settled_time <use_create_time and substr(settled_time,1,10) < loan_end_date ,id ,null)) as multi_loan_in_loan_order_recentfirst_completednotdueinstalcnt
     ,count(if(order_desc_rank=1 and settled_time is not null and settled_time <use_create_time and substr(settled_time,1,10) < loan_end_date ,id ,null))/count(if(order_desc_rank=1 and settled_time is not null and settled_time <use_create_time ,id ,null)) as multi_loan_in_loan_order_recentfirst_completednotdueinstalovercompletedratio
     ,count(if(order_desc_rank=1 and settled_time is not null and settled_time <use_create_time and substr(settled_time,1,10) < loan_end_date ,id ,null))/count(if(order_desc_rank=1 and loan_end_date>substr(use_create_time,1,10),id,null)) as multi_loan_in_loan_order_recentfirst_completednotdueinstalovernotdueratio
     ,sum(if(order_desc_rank=1 and settled_time is not null and settled_time <use_create_time and substr(settled_time,1,10) < loan_end_date ,repaid_principal ,0)) as multi_loan_in_loan_order_recentfirst_completednotdueloanamount
     ,max(if(order_desc_rank=1 and substr(creadit_use_create_time, 12, 2) in('11','12','13'), 1, 0)) as multi_loan_in_loan_order_recentfirst_createdtimeperiodonehotvo_noon
     ,max(if(order_desc_rank=1 and substr(creadit_use_create_time, 12, 2) in('23','00','01','02','03','04'), 1, 0)) as multi_loan_in_loan_order_recentfirst_createdtimeperiodonehotvo_night
     ,max(if(order_desc_rank=1 and substr(creadit_use_create_time, 12, 2) in('05','06','07','08','09','10'), 1, 0)) as multi_loan_in_loan_order_recentfirst_createdtimeperiodonehotvo_morning
     ,max(if(order_desc_rank=1 and substr(creadit_use_create_time, 12, 2) in('18','19','20','21','22'), 1, 0)) as multi_loan_in_loan_order_recentfirst_createdtimeperiodonehotvo_evening
     ,max(if(order_desc_rank=1 and substr(creadit_use_create_time, 12, 2) in('14','15','16','17'), 1, 0)) as multi_loan_in_loan_order_recentfirst_createdtimeperiodonehotvo_afternoon
     ,max(if(order_desc_rank=2 and substr(creadit_use_create_time, 12, 2) in('11','12','13'), 1, 0)) as multi_loan_in_loan_order_recentsecond_createdtimeperiodonehotvo_noon
     ,max(if(order_desc_rank=2 and substr(creadit_use_create_time, 12, 2) in('23','00','01','02','03','04'), 1, 0)) as multi_loan_in_loan_order_recentsecond_createdtimeperiodonehotvo_night
     ,max(if(order_desc_rank=2 and substr(creadit_use_create_time, 12, 2) in('05','06','07','08','09','10'), 1, 0)) as multi_loan_in_loan_order_recentsecond_createdtimeperiodonehotvo_morning
     ,max(if(order_desc_rank=2 and substr(creadit_use_create_time, 12, 2) in('18','19','20','21','22'), 1, 0)) as multi_loan_in_loan_order_recentsecond_createdtimeperiodonehotvo_evening
     ,max(if(order_desc_rank=2 and substr(creadit_use_create_time, 12, 2) in('14','15','16','17'), 1, 0)) as multi_loan_in_loan_order_recentsecond_createdtimeperiodonehotvo_afternoon
     ,max(if(order_desc_rank=1,datediff(user_create_time,creadit_use_create_time),null)) as multi_loan_in_loan_order_recentfirst_createdordertimegap
     ,max(if(order_desc_rank=2,datediff(user_create_time,creadit_use_create_time),null)) as multi_loan_in_loan_order_recentsecond_createdordertimegap
     ,max(if(order_desc_rank=1 and settled_time is not null and settled_time<use_create_time, datediff(cast(use_create_time as date), cast(settled_time as date)))) as multi_loan_in_loan_order_recentfirst_firstcompletedinstalgap
     ,max(if(order_desc_rank=2 and settled_time is not null and settled_time<use_create_time, datediff(cast(use_create_time as date), cast(settled_time as date)))) as multi_loan_in_loan_order_recentsecond_firstcompletedinstalgap
     ,max(if(order_desc_rank=1,period,null)) as multi_loan_in_loan_order_recentfirst_instalmentcnt
     ,max(if(order_desc_rank=2,period,null)) as multi_loan_in_loan_order_recentsecond_instalmentcnt
     ,count(if(order_desc_rank=1 and loan_end_date < substr(use_create_time,1,10) and (settled_time is null or substr(settled_time,1,10)> loan_end_date),id,null)) as multi_loan_in_loan_order_recentfirst_overdueinstalcnt
     ,count(if(order_desc_rank=2 and loan_end_date < substr(use_create_time,1,10) and (settled_time is null or substr(settled_time,1,10)> loan_end_date),id,null)) as multi_loan_in_loan_order_recentsecond_overdueinstalcnt
     ,count(if(order_desc_rank=1 and loan_end_date < substr(use_create_time,1,10) and (settled_time is null or substr(settled_time,1,10)> loan_end_date),id,null))/count(if(order_desc_rank=1 ,id,null)) as multi_loan_in_loan_order_recentfirst_overdueinstalratio
     ,count(if(order_desc_rank=2 and loan_end_date < substr(use_create_time,1,10) and (settled_time is null or substr(settled_time,1,10)> loan_end_date),id,null))/count(if(order_desc_rank=2 ,id,null)) as multi_loan_in_loan_order_recentsecond_overdueinstalratio
     ,(datediff(max(if(order_desc_rank=1, loan_end_date, null)),min(if(order_desc_rank=1, loan_start_date, null))) + 1) as multi_loan_in_loan_order_recentfirst_payoutdays
     ,(datediff(max(if(order_desc_rank=2, loan_end_date, null)),min(if(order_desc_rank=1, loan_start_date, null))) + 1) as multi_loan_in_loan_order_recentsecond_payoutdays
     ,count(if(order_desc_rank=1 and (settled_time is null or settled_time>use_create_time),id,null)) as multi_loan_in_loan_order_recentfirst_uncompletedinstalcnt
     ,count(if(order_desc_rank=2 and (settled_time is null or settled_time>use_create_time),id,null)) as multi_loan_in_loan_order_recentsecond_uncompletedinstalcnt
     ,avg(if(order_asc_rank=2 and settled_time is not null and settled_time < use_create_time and substr(settled_time,1,10) < loan_end_date, datediff(cast(loan_end_date as date), cast(substr(settled_time,1,10) as date)),null)) as multi_loan_in_loan_order_recentsecond_completedadvanceinstaldaysavg
     ,max(if(order_asc_rank=2 and settled_time is not null and settled_time < use_create_time and substr(settled_time,1,10) < loan_end_date, datediff(cast(loan_end_date as date), cast(substr(settled_time,1,10) as date)),null)) as multi_loan_in_loan_order_recentsecond_completedadvanceinstaldaysmax
     ,stddev(if(order_asc_rank=2 and settled_time is not null and settled_time < use_create_time and substr(settled_time,1,10) < loan_end_date, datediff(cast(loan_end_date as date), cast(substr(settled_time,1,10) as date)),null)) as multi_loan_in_loan_order_recentsecond_completedadvanceinstaldaysstd
     ,count(if(order_desc_rank=2 and settled_time is not null and settled_time <use_create_time ,id ,null)) as multi_loan_in_loan_order_recentsecond_completedinstalcnt
     ,count(if(order_desc_rank=2 and settled_time is not null and settled_time <use_create_time ,id ,null))/count(if(order_desc_rank=2,id ,null)) as multi_loan_in_loan_order_recentsecond_completedinstalratio
     ,count(if(order_desc_rank=2 and settled_time is not null and settled_time <use_create_time and substr(settled_time,1,10) < loan_end_date ,id ,null))  as multi_loan_in_loan_order_recentsecond_completednotdueinstalcnt
     ,count(if(order_desc_rank=2 and settled_time is not null and settled_time <use_create_time and substr(settled_time,1,10) < loan_end_date ,id ,null))/count(if(order_desc_rank=2 and settled_time is not null and settled_time <use_create_time ,id ,null)) as multi_loan_in_loan_order_recentsecond_completednotdueinstalovercompletedratio
     ,count(if(order_desc_rank=2 and settled_time is not null and settled_time <use_create_time and substr(settled_time,1,10) < loan_end_date ,id ,null))/count(if(order_desc_rank=2 and loan_end_date>substr(use_create_time,1,10),id,null)) as multi_loan_in_loan_order_recentsecond_completednotdueinstalovernotdueratio
     ,max(if(order_desc_rank=2,datediff(user_create_time,creadit_use_create_time),null)) as multi_loan_in_loan_order_recentsecond_createdordertimegap
from target_user_credit_loan_repay_info
group by cust_no,use_create_time
