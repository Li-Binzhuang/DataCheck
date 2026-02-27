-- 1）先构建一个用户样本；sql中以【每天发起用信申请的用户 + 用信申请时间】作为计算特征的目标人群；真实场景中以【调用特征用户当时的实际业务时间为准】
-- target_user只是服务于实时特征上线前，和后端结果回溯上线使用；
with target_user as (
    select id as apply_id, create_time as use_create_time,cust_no
    from hive_idc.oversea.ods_mx_aprv_approve_use_credit_apply_df
    where pt ='${dt}' ---yyymmdd格式
      and replace(substr(create_time,1,10) ,'-', '')  ='${dt}'
),
-- 基于target_user中的用户和时间，我们把用户的授信、借款、还款的订单都拉出来，形成一个临时表，主要服务于在贷订单行为的统计；
     target_user_credit_loan_repay_info as (
         select t3.*
              ,dense_rank()over(partition by t3.cust_no,t3.use_create_time order by t3.loan_create_time asc) as order_asc_rank -- 升序排序，1即为最远一笔
              ,dense_rank()over(partition by t3.cust_no,t3.use_create_time order by t3.loan_create_time desc) as order_desc_rank -- 降序排序，1即为最近一笔
              ,t7.create_time as credit_create_time
              ,t6.create_time as creadit_use_create_time
         from
             (
                 select t1.apply_id
                      ,t1.cust_no
                      ,t1.use_create_time
                      ,t2.id
                      ,t2.loan_no
                      ,t2.settled_time
                      ,t2.create_time
                      ,t2.repaid_principal
                      ,t2.periods
                      ,t2.loan_end_date
                      ,t2.loan_start_date
                      ,ala.create_time as loan_create_time
                 from target_user as t1
                          left join (
                     select *
                     from hive_idc.oversea.ods_mx_ast_asset_repay_plan_df
                     where pt ='${dt}' ---yyymmdd格式
                       and replace(substr(create_time,1,10) ,'-', '') <='${dt}'
                       and repay_plan_status != 4
                 ) as t2 on t1.cust_no = t2.cust_no
                          left join (select * from hive_idc.oversea.ods_mx_ast_asset_loan_info_df where pt ='${dt}') ali ON t2.loan_no = ali.loan_no
                          left join (select * from hive_idc.oversea.ods_mx_ast_asset_loan_apply_df where pt ='${dt}') ala ON ali.loan_apply_no = ala.loan_apply_no
                 where t2.create_time < t1.use_create_time    -- 约束查询之前该用户的还款计划数据
             ) as t3
                 left join (select loan_no,loan_apply_no,settled_time from hive_idc.oversea.ods_mx_ast_asset_loan_info_df where pt ='${dt}' and loan_status != 4) as t4 on t3.loan_no = t4.loan_no
                 left join (select loan_apply_no,seq_no from hive_idc.oversea.ods_mx_ast_asset_loan_apply_df where pt ='${dt}') as t5 on t4.loan_apply_no = t5.loan_apply_no
                 left join (select asset_id,create_time,credit_apply_id from hive_idc.oversea.ods_mx_aprv_approve_use_credit_apply_df where pt ='${dt}') as t6 on t5.seq_no = t6.asset_id
                 left join (select id,create_time from hive_idc.oversea.ods_mx_aprv_approve_credit_apply_df where pt='${dt}' ) as t7 on t6.credit_apply_id = t7.id
         where t4.settled_time is null or t4.settled_time>t3.use_create_time -- 限制是未结清的订单
     )

-- PART 2 : 第二部分特征（针对在贷订单的首次和末次、最近第二次等特征）

select max(apply_id) as apply_id
     ,cust_no
     ,use_create_time
     -- 最远一笔订单的特征，MEXICO_MULTI_LOAN_IN_LOAN_ORDER，
     ,coalesce(count(if(order_asc_rank=1 and settled_time is not null and settled_time <use_create_time ,id ,null)), -999) as multi_loan_in_loan_order_furthest_completedinstalcnt
     ,coalesce(round(count(if(order_asc_rank=1 and settled_time is not null and settled_time <use_create_time ,id ,null))/count(if(order_asc_rank=1,id ,null)), 6), -999) as multi_loan_in_loan_order_furthest_completedinstalratio
     ,coalesce(sum(if(order_asc_rank=1 and settled_time is not null and settled_time <use_create_time ,repaid_principal ,0)), -999) as multi_loan_in_loan_order_furthest_completedloanamount
     ,coalesce(count(if(order_asc_rank=1 and settled_time is not null and settled_time <use_create_time and substr(settled_time,1,10) < loan_end_date ,id ,null)), -999) as multi_loan_in_loan_order_furthest_completednotdueinstalcnt
     ,coalesce(round(count(if(order_asc_rank=1 and settled_time is not null and settled_time <use_create_time and substr(settled_time,1,10) < loan_end_date ,id ,null))/count(if(order_asc_rank=1 and settled_time is not null and settled_time <use_create_time ,id ,null)), 6), -999) as multi_loan_in_loan_order_furthest_completednotdueinstalovercompletedratio
     ,coalesce(round(count(if(order_asc_rank=1 and settled_time is not null and settled_time <use_create_time and substr(settled_time,1,10) < loan_end_date ,id ,null))/count(if(order_asc_rank=1 and loan_end_date>substr(use_create_time,1,10),id,null)), 6), -999) as multi_loan_in_loan_order_furthest_completednotdueinstalovernotdueratio
     ,coalesce(sum(if(order_asc_rank=1 and settled_time is not null and settled_time <use_create_time and substr(settled_time,1,10) < loan_end_date ,repaid_principal ,0)), -999) as multi_loan_in_loan_order_furthest_completednotdueloanamount
     ,coalesce(max(if(order_asc_rank=1,periods,null)), -999) as multi_loan_in_loan_order_furthest_instalmentcnt
     ,coalesce((datediff(max(if(order_asc_rank=1, loan_end_date, null)),min(if(order_asc_rank=1, loan_start_date, null))) + 1), -999) as multi_loan_in_loan_order_furthest_payoutdays
     ,coalesce(count(if(order_asc_rank=1 and (settled_time is null or settled_time>use_create_time),id,null)), -999) as multi_loan_in_loan_order_furthest_uncompletedinstalcnt
     ,coalesce(max(if(order_asc_rank=1,datediff(cast(creadit_use_create_time as date),cast(credit_create_time as date)),null)), -999) as multi_loan_in_loan_order_furthest_createdtimecalccreditsgap
     -- 最近一笔订单的特征，MEXICO_MULTI_LOAN_IN_LOAN_ORDER，
     ,coalesce(round(avg(if(order_desc_rank=1 and settled_time is not null and settled_time < use_create_time and substr(settled_time,1,10) < loan_end_date, datediff(cast(loan_end_date as date), cast(substr(settled_time,1,10) as date)),null)), 6), -999) as multi_loan_in_loan_order_recentfirst_completedadvanceinstaldaysavg
     ,coalesce(max(if(order_desc_rank=1 and settled_time is not null and settled_time < use_create_time and substr(settled_time,1,10) < loan_end_date, datediff(cast(loan_end_date as date), cast(substr(settled_time,1,10) as date)),null)), -999) as multi_loan_in_loan_order_recentfirst_completedadvanceinstaldaysmax
     ,coalesce(round(stddev(if(order_desc_rank=1 and settled_time is not null and settled_time < use_create_time and substr(settled_time,1,10) < loan_end_date, datediff(cast(loan_end_date as date), cast(substr(settled_time,1,10) as date)),null)), 6), -999) as multi_loan_in_loan_order_recentfirst_completedadvanceinstaldaysstd
     ,coalesce(count(if(order_desc_rank=1 and settled_time is not null and settled_time <use_create_time ,id ,null)), -999) as multi_loan_in_loan_order_recentfirst_completedinstalcnt
     ,coalesce(round(count(if(order_desc_rank=1 and settled_time is not null and settled_time <use_create_time ,id ,null))/count(if(order_desc_rank=1,id ,null)), 6), -999) as multi_loan_in_loan_order_recentfirst_completedinstalratio
     ,coalesce(count(if(order_desc_rank=1 and settled_time is not null and settled_time <use_create_time and substr(settled_time,1,10) < loan_end_date ,id ,null)), -999) as multi_loan_in_loan_order_recentfirst_completednotdueinstalcnt
     ,coalesce(round(count(if(order_desc_rank=1 and settled_time is not null and settled_time <use_create_time and substr(settled_time,1,10) < loan_end_date ,id ,null))/count(if(order_desc_rank=1 and settled_time is not null and settled_time <use_create_time ,id ,null)), 6), -999) as multi_loan_in_loan_order_recentfirst_completednotdueinstalovercompletedratio
     ,coalesce(round(count(if(order_desc_rank=1 and settled_time is not null and settled_time <use_create_time and substr(settled_time,1,10) < loan_end_date ,id ,null))/count(if(order_desc_rank=1 and loan_end_date>substr(use_create_time,1,10),id,null)), 6), -999) as multi_loan_in_loan_order_recentfirst_completednotdueinstalovernotdueratio
     ,coalesce(sum(if(order_desc_rank=1 and settled_time is not null and settled_time <use_create_time and substr(settled_time,1,10) < loan_end_date ,repaid_principal ,0)), -999) as multi_loan_in_loan_order_recentfirst_completednotdueloanamount
     ,coalesce(max(if(order_desc_rank=1 and substr(creadit_use_create_time, 12, 2) in('11','12','13'), 1, 0)), -999) as multi_loan_in_loan_order_recentfirst_createdtimeperiodonehotvo_noon
     ,coalesce(max(if(order_desc_rank=1 and substr(creadit_use_create_time, 12, 2) in('23','00','01','02','03','04'), 1, 0)), -999) as multi_loan_in_loan_order_recentfirst_createdtimeperiodonehotvo_night
     ,coalesce(max(if(order_desc_rank=1 and substr(creadit_use_create_time, 12, 2) in('05','06','07','08','09','10'), 1, 0)), -999) as multi_loan_in_loan_order_recentfirst_createdtimeperiodonehotvo_morning
     ,coalesce(max(if(order_desc_rank=1 and substr(creadit_use_create_time, 12, 2) in('18','19','20','21','22'), 1, 0)), -999) as multi_loan_in_loan_order_recentfirst_createdtimeperiodonehotvo_evening
     ,coalesce(max(if(order_desc_rank=1 and substr(creadit_use_create_time, 12, 2) in('14','15','16','17'), 1, 0)), -999) as multi_loan_in_loan_order_recentfirst_createdtimeperiodonehotvo_afternoon
     ,coalesce(max(if(order_desc_rank=2 and substr(creadit_use_create_time, 12, 2) in('11','12','13'), 1, 0)), -999) as multi_loan_in_loan_order_recentsecond_createdtimeperiodonehotvo_noon
     ,coalesce(max(if(order_desc_rank=2 and substr(creadit_use_create_time, 12, 2) in('23','00','01','02','03','04'), 1, 0)), -999) as multi_loan_in_loan_order_recentsecond_createdtimeperiodonehotvo_night
     ,coalesce(max(if(order_desc_rank=2 and substr(creadit_use_create_time, 12, 2) in('05','06','07','08','09','10'), 1, 0)), -999) as multi_loan_in_loan_order_recentsecond_createdtimeperiodonehotvo_morning
     ,coalesce(max(if(order_desc_rank=2 and substr(creadit_use_create_time, 12, 2) in('18','19','20','21','22'), 1, 0)), -999) as multi_loan_in_loan_order_recentsecond_createdtimeperiodonehotvo_evening
     ,coalesce(max(if(order_desc_rank=2 and substr(creadit_use_create_time, 12, 2) in('14','15','16','17'), 1, 0)), -999) as multi_loan_in_loan_order_recentsecond_createdtimeperiodonehotvo_afternoon
     ,coalesce(max(if(order_desc_rank=1,datediff(use_create_time,creadit_use_create_time),null)), -999) as multi_loan_in_loan_order_recentfirst_createdordertimegap
     ,coalesce(max(if(order_desc_rank=2,datediff(use_create_time,creadit_use_create_time),null)), -999) as multi_loan_in_loan_order_recentsecond_createdordertimegap
     ,coalesce(max(if(order_desc_rank=1 and settled_time is not null and settled_time<use_create_time, datediff(cast(use_create_time as date), cast(settled_time as date)), null)), -999) as multi_loan_in_loan_order_recentfirst_firstcompletedinstalgap
     ,coalesce(max(if(order_desc_rank=2 and settled_time is not null and settled_time<use_create_time, datediff(cast(use_create_time as date), cast(settled_time as date)),null)), -999) as multi_loan_in_loan_order_recentsecond_firstcompletedinstalgap
     ,coalesce(max(if(order_desc_rank=1,periods,null)), -999) as multi_loan_in_loan_order_recentfirst_instalmentcnt
     ,coalesce(max(if(order_desc_rank=2,periods,null)), -999) as multi_loan_in_loan_order_recentsecond_instalmentcnt
     ,coalesce(count(if(order_desc_rank=1 and loan_end_date < substr(use_create_time,1,10) and (settled_time is null or substr(settled_time,1,10)> loan_end_date),id,null)), -999) as multi_loan_in_loan_order_recentfirst_overdueinstalcnt
     ,coalesce(count(if(order_desc_rank=2 and loan_end_date < substr(use_create_time,1,10) and (settled_time is null or substr(settled_time,1,10)> loan_end_date),id,null)), -999) as multi_loan_in_loan_order_recentsecond_overdueinstalcnt
     ,coalesce(round(count(if(order_desc_rank=1 and loan_end_date < substr(use_create_time,1,10) and (settled_time is null or substr(settled_time,1,10)> loan_end_date),id,null))/count(if(order_desc_rank=1 ,id,null)), 6), -999) as multi_loan_in_loan_order_recentfirst_overdueinstalratio
     ,coalesce(round(count(if(order_desc_rank=2 and loan_end_date < substr(use_create_time,1,10) and (settled_time is null or substr(settled_time,1,10)> loan_end_date),id,null))/count(if(order_desc_rank=2 ,id,null)), 6), -999) as multi_loan_in_loan_order_recentsecond_overdueinstalratio
     ,coalesce((datediff(max(if(order_desc_rank=1, loan_end_date, null)),min(if(order_desc_rank=1, loan_start_date, null))) + 1), -999) as multi_loan_in_loan_order_recentfirst_payoutdays
     ,coalesce((datediff(max(if(order_desc_rank=2, loan_end_date, null)),min(if(order_desc_rank=2, loan_start_date, null))) + 1), -999) as multi_loan_in_loan_order_recentsecond_payoutdays
     ,coalesce(count(if(order_desc_rank=1 and (settled_time is null or settled_time>use_create_time),id,null)), -999) as multi_loan_in_loan_order_recentfirst_uncompletedinstalcnt
     ,coalesce(count(if(order_desc_rank=2 and (settled_time is null or settled_time>use_create_time),id,null)), -999) as multi_loan_in_loan_order_recentsecond_uncompletedinstalcnt
     -- 注意：recentsecond的提前还款天数统计使用order_asc_rank=2（升序第二笔=最远第二笔），这是SQL设计意图
     ,coalesce(round(avg(if(order_asc_rank=2 and settled_time is not null and settled_time < use_create_time and substr(settled_time,1,10) < loan_end_date, datediff(cast(loan_end_date as date), cast(substr(settled_time,1,10) as date)),null)), 6), -999) as multi_loan_in_loan_order_recentsecond_completedadvanceinstaldaysavg
     ,coalesce(max(if(order_asc_rank=2 and settled_time is not null and settled_time < use_create_time and substr(settled_time,1,10) < loan_end_date, datediff(cast(loan_end_date as date), cast(substr(settled_time,1,10) as date)),null)), -999) as multi_loan_in_loan_order_recentsecond_completedadvanceinstaldaysmax
     ,coalesce(round(stddev(if(order_asc_rank=2 and settled_time is not null and settled_time < use_create_time and substr(settled_time,1,10) < loan_end_date, datediff(cast(loan_end_date as date), cast(substr(settled_time,1,10) as date)),null)), 6), -999) as multi_loan_in_loan_order_recentsecond_completedadvanceinstaldaysstd
     ,coalesce(count(if(order_desc_rank=2 and settled_time is not null and settled_time <use_create_time ,id ,null)), -999) as multi_loan_in_loan_order_recentsecond_completedinstalcnt
     ,coalesce(round(count(if(order_desc_rank=2 and settled_time is not null and settled_time <use_create_time ,id ,null))/count(if(order_desc_rank=2,id ,null)), 6), -999) as multi_loan_in_loan_order_recentsecond_completedinstalratio
     ,coalesce(count(if(order_desc_rank=2 and settled_time is not null and settled_time <use_create_time and substr(settled_time,1,10) < loan_end_date ,id ,null)), -999) as multi_loan_in_loan_order_recentsecond_completednotdueinstalcnt
     ,coalesce(round(count(if(order_desc_rank=2 and settled_time is not null and settled_time <use_create_time and substr(settled_time,1,10) < loan_end_date ,id ,null))/count(if(order_desc_rank=2 and settled_time is not null and settled_time <use_create_time ,id ,null)), 6), -999) as multi_loan_in_loan_order_recentsecond_completednotdueinstalovercompletedratio
     ,coalesce(round(count(if(order_desc_rank=2 and settled_time is not null and settled_time <use_create_time and substr(settled_time,1,10) < loan_end_date ,id ,null))/count(if(order_desc_rank=2 and loan_end_date>substr(use_create_time,1,10),id,null)), 6), -999) as multi_loan_in_loan_order_recentsecond_completednotdueinstalovernotdueratio
from target_user_credit_loan_repay_info
group by cust_no,use_create_time;
