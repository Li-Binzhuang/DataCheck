------------------------------------------------------------------------------------------
-- 所属主题:：国际金融/ 贷中特征 feature etl
-- author：凡西，2026.2.27 
-- 事项：贷中部分订单类特征开发，分组名称：MEXICO_MULTI_LOAN_IN_LOAN_ORDER
-- 备注：此次开发用于补充年前剩余60+未完成部分的开发

-- 重要提示：为了方便回溯测试 核对数据，我们以下的sql均以【每天发起用信申请的用户 + 用信申请时间】作为计算特征的目标人群；真实场景中以【调用特征用户当时的实际业务时间为准】
------------------------------------------------------------------------------------------



--------------PART 1：先构建两个临时表，target_user、target_user_credit_loan_repay_info



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
          ---以下针对在贷未结清的订单参与dense_rank排序
          ,case when t4.settled_time is null or t4.settled_time>t3.use_create_time then dense_rank()over(partition by t3.cust_no,t3.use_create_time order by t3.create_time asc) else null end as order_asc_rank ---升序排序，1即为最远一笔
          ,case when t4.settled_time is null or t4.settled_time>t3.use_create_time then dense_rank()over(partition by t3.cust_no,t3.use_create_time order by t3.create_time desc) else null end as order_desc_rank ---降序排序，1即为最近一笔
          ---以下针对所有订单参与dense_rank排序
          ,dense_rank()over(partition by t3.cust_no,t3.use_create_time order by t3.create_time asc) as total_order_asc_rank ---升序排序，1即为最远一笔
          ,dense_rank()over(partition by t3.cust_no,t3.use_create_time order by t3.create_time desc) as total_order_desc_rank ---降序排序，1即为最近一笔
          ,t7.create_time as credit_create_time
          ,t6.create_time as creadit_use_create_time
          ,t6.id as use_credit_apply_id
          --新增一个额度使用率字段
          ,t8.creditlimit_use_ratio
          --新增一个该期账单是否提前结清字段
          ,if(t3.settled_time < t3.use_create_time and substr(t3.settled_time,1,10) < t3.loan_end_date,1,0) as is_tqjq
          ,if(t3.settled_time < t3.use_create_time and substr(t3.settled_time,1,10) < t3.loan_end_date and substr(t3.settled_time,1,10)>date_sub(t3.loan_end_date,15),1,0) as is_tqjq_15d
          ,if(t3.settled_time < t3.use_create_time and substr(t3.settled_time,1,10) < t3.loan_end_date and substr(t3.settled_time,1,10)>date_sub(t3.loan_end_date,7),1,0) as is_tqjq_7d
          ,if(t3.settled_time < t3.use_create_time and substr(t3.settled_time,1,10) < t3.loan_end_date and substr(t3.settled_time,1,10)>date_sub(t3.loan_end_date,3),1,0) as is_tqjq_3d
          --新增一个是否逾期的字段
          ,if(t3.loan_end_date < substr(t3.use_create_time,1,10) and (t3.settled_time is null or substr(t3.settled_time,1,10)> t3.loan_end_date),1,0) as is_overdue
          --新增一个loan_no是否是在贷订单的标记字段，以大幅精简sql复杂度；
          ,if(t4.settled_time is null or t4.settled_time>t3.use_create_time, 1, 0) as is_unclear_tag
          --新增用户当时的剩余可用额度
          ,t9.available_limit
    from
    (
        select t1.cust_no
            ,t1.use_create_time
            ,t2.id
            ,t2.loan_no
            ,t2.settled_time
            ,t2.create_time    
            ,t2.repaid_principal      
            ,t2.periods
            ,t2.loan_end_date
            ,t2.loan_start_date
        from target_user as t1
        left join (
            select *
            from hive_idc.oversea.ods_mx_ast_asset_repay_plan_df
            where pt ='${dt}' ---yyymmdd格式
            and replace(substr(create_time,1,10) ,'-', '') <='${dt}'
            and repay_plan_status != 4
        ) as t2
        on t1.cust_no = t2.cust_no
        where t2.create_time < t1.use_create_time    --约束查询之前该用户的还款计划数据
    ) as t3
    left join (select loan_no,loan_apply_no,settled_time from hive_idc.oversea.ods_mx_ast_asset_loan_info_df where pt ='${dt}' and loan_status != 4) as t4 on t3.loan_no = t4.loan_no
    left join (select loan_apply_no,seq_no from hive_idc.oversea.ods_mx_ast_asset_loan_apply_df where pt ='${dt}') as t5 on t4.loan_apply_no = t5.loan_apply_no
    left join (select asset_id,create_time,credit_apply_id,id from hive_idc.oversea.ods_mx_aprv_approve_use_credit_apply_df where pt ='${dt}') as t6 on t5.seq_no = t6.asset_id
    left join (select id,create_time from hive_idc.oversea.ods_mx_aprv_approve_credit_apply_df where pt='${dt}' ) as t7 on t6.credit_apply_id = t7.id
    left join(
               ---这一步的目的是用信表和额度流水表credit_limit_record关联，通过卡时间的方式，把用户用信申请当时的额度使用率提取出来；
                select use_create_time,cust_no,id,use_amount,after_total_limit,after_available_limit,after_use_limit,after_pre_use_limit
                      ,after_pre_use_limit/(before_available_limit+before_pre_use_limit) as creditlimit_use_ratio
                from(
                    select p1.use_create_time
                        ,p1.cust_no
                        ,p1.id
                        ,p1.use_amount
                        ,row_number()over(partition by p1.id,p1.cust_no order by p2.update_time desc) as rank_
                        ,p2.after_total_limit
                        ,p2.after_available_limit
                        ,p2.after_use_limit
                        ,p2.after_pre_use_limit
                        ,p2.before_available_limit
                        ,p2.before_pre_use_limit
                    from(
                        select create_time as use_create_time,cust_no, id, asset_id,use_amount
                        from hive_idc.oversea.ods_mx_aprv_approve_use_credit_apply_df
                        where pt ='${dt}' ---yyymmdd格式
                    ) as p1
                    left join(
                        select after_expire_date,cust_no,after_total_limit,after_available_limit,create_time,update_time,after_use_limit,after_pre_use_limit,before_available_limit,before_pre_use_limit
                        from hive_idc.oversea.ods_mx_aprv_cust_credit_limit_record_df
                        where pt ='${dt}' ---yyymmdd格式
                        and is_delete=0
                    ) as p2
                    on p1.cust_no = p2.cust_no
                    where p2.update_time<p1.use_create_time
                    and p2.after_expire_date>p1.use_create_time
                ) as tmp where rank_ =1
            ) as t8
    on t6.id = t8.id
left join(
               ---这一步的目的把用户当时的额度使用率提取出来；
                select use_create_time,cust_no,(after_total_limit-after_use_limit) as available_limit
                from(
                    select p1.use_create_time
                        ,p1.cust_no
                        ,row_number()over(partition by p1.use_create_time,p1.cust_no order by p2.update_time desc) as rank_
                        ,p2.after_total_limit
                        ,p2.after_available_limit
                        ,p2.after_use_limit
                        ,p2.after_pre_use_limit
                    from target_user as p1
                    left join(
                        select after_expire_date,cust_no,after_total_limit,after_available_limit,create_time,update_time,after_use_limit,after_pre_use_limit
                        from hive_idc.oversea.ods_mx_aprv_cust_credit_limit_record_df
                        where pt ='${dt}' ---yyymmdd格式
                        and is_delete=0
                    ) as p2
                    on p1.cust_no = p2.cust_no
                    where p2.update_time<p1.use_create_time
                    and p2.after_expire_date>p1.use_create_time
                ) as tmp where rank_ =1
            ) as t9
on t3.cust_no = t9.cust_no and t3.use_create_time = t9.use_create_time
)

--------------PART 2：特征计算模块，针对multi_loan_in_loan_order 和multi_loan_order_info_部分逻辑复杂的特征进行计算
select * from (
select m1.use_create_time
      ,m1.cust_no
      ,max(if(m1.order_desc_rank=1, m1.creditlimit_use_ratio, null)) as multi_loan_in_loan_order_recentfirst_creditusageratio
      --notes：为什么平均值前面用了max写法，因为day_settled_cnt_avg本质已经做过了平均，此处只是用max来去重，把数据收敛到1条
      ,max(if(m1.order_desc_rank=1, m2.day_settled_cnt_avg, null)) as multi_loan_in_loan_order_recentfirst_completedsamedayinstalcntavg
      ,max(if(m1.order_desc_rank=1, m2.day_settled_cnt_max, null)) as multi_loan_in_loan_order_recentfirst_completedsamedayinstalcntmax
      ,max(if(m1.order_desc_rank=1, m3.max_cnt, null)) as multi_loan_in_loan_order_recentfirst_maxcontinuecompletedadvanceinstalcnt
      --最近第一笔订单最大连续提前结清账单比例（分母是该订单到期账单数）
      ,max(if(m1.order_desc_rank=1, m3.max_cnt, null))/count(if(m1.order_desc_rank=1 and (m1.loan_end_date <= substr(m1.use_create_time,1,10) or m1.settled_time < m1.use_create_time), m1.id, null)) as multi_loan_in_loan_order_recentfirst_maxcontinuecompletedadvanceinstalratio
      ,max(if(m1.order_desc_rank=1, m4.max_cnt, null)) as multi_loan_in_loan_order_recentfirst_maxcontinueoverdueinstalcnt
      --最近第一笔订单最大连续逾期账单比例（分母是该订单到期账单数）
      ,max(if(m1.order_desc_rank=1, m4.max_cnt, null))/count(if(m1.order_desc_rank=1 and m1.loan_end_date <= substr(m1.use_create_time,1,10), m1.id, null)) as multi_loan_in_loan_order_recentfirst_maxcontinueoverdueinstalratio

      ,max(if(m1.order_desc_rank=2, m2.day_settled_cnt_avg, null)) as multi_loan_in_loan_order_recentsecond_completedsamedayinstalcntavg
      ,max(if(m1.order_desc_rank=2, m2.day_settled_cnt_max, null)) as multi_loan_in_loan_order_recentsecond_completedsamedayinstalcntmax
      ,max(if(m1.order_desc_rank=2, m3.max_cnt, null)) as multi_loan_in_loan_order_recentsecond_maxcontinuecompletedadvanceinstalcnt
      ,max(if(m1.order_desc_rank=2, m3.max_cnt, null))/count(if(m1.order_desc_rank=2 and (m1.loan_end_date <= substr(m1.use_create_time,1,10) or m1.settled_time < m1.use_create_time), m1.id, null)) as multi_loan_in_loan_order_recentsecond_maxcontinuecompletedadvanceinstalratio

      ,max(if(m1.order_desc_rank=2, m4.max_cnt, null)) as multi_loan_in_loan_order_recentsecond_maxcontinueoverdueinstalcnt
      ,max(if(m1.order_desc_rank=2, m4.max_cnt, null))/count(if(m1.order_desc_rank=2 and m1.loan_end_date <= substr(m1.use_create_time,1,10), m1.id, null)) as multi_loan_in_loan_order_recentsecond_maxcontinueoverdueinstalratio
      ,max(if(m1.order_desc_rank=2, m1.creditlimit_use_ratio,null)) - max(m5.creditlimit_use_ratio_avg) as multi_loan_in_loan_order_recentsecond_minusinloanavgcreditusage
      --续贷全部在贷订单信息，提前15d（在贷续借订单逻辑：m1.order_asc_rank>1）
      ,max(if(m1.order_asc_rank>1, m6.max_cnt, null)) as multi_loan_in_loan_order_all_advanceget15days_maxcontinuecompletedadvanceinstalcnt
      ,max(if(m1.order_asc_rank>1, m6.max_cnt, null))/count(if(m1.order_asc_rank>1 and m1.is_tqjq=1, id, null)) as multi_loan_in_loan_order_all_advanceget15days_maxcontinuecompletedadvanceinstaloverallcompletedadvanceratio
      ,max(if(m1.order_asc_rank>1, m6.max_cnt, null))/count(if(m1.order_asc_rank>1 and (m1.loan_end_date <= substr(m1.use_create_time,1,10) or m1.settled_time < m1.use_create_time), m1.id, null)) as multi_loan_in_loan_order_all_advanceget15days_maxcontinuecompletedadvanceinstalovercompletedorexpiredratio
      --续贷全部在贷订单信息，提前7d（在贷续借订单逻辑：m1.order_asc_rank>1）
      ,max(if(m1.order_asc_rank>1, m7.max_cnt, null)) as multi_loan_in_loan_order_all_advanceget7days_maxcontinuecompletedadvanceinstalcnt
      ,max(if(m1.order_asc_rank>1, m7.max_cnt, null))/count(if(m1.order_asc_rank>1 and m1.is_tqjq=1, id, null)) as multi_loan_in_loan_order_all_advanceget7days_maxcontinuecompletedadvanceinstaloverallcompletedadvanceratio
      ,max(if(m1.order_asc_rank>1, m7.max_cnt, null))/count(if(m1.order_asc_rank>1 and (m1.loan_end_date <= substr(m1.use_create_time,1,10) or m1.settled_time < m1.use_create_time), m1.id, null)) as multi_loan_in_loan_order_all_advanceget7days_maxcontinuecompletedadvanceinstalovercompletedorexpiredratio
      --续贷全部在贷订单信息，提前3d（在贷续借订单逻辑：m1.order_asc_rank>1）
      ,max(if(m1.order_asc_rank>1, m8.max_cnt, null)) as multi_loan_in_loan_order_all_advanceget3days_maxcontinuecompletedadvanceinstalcnt
      ,max(if(m1.order_asc_rank>1, m8.max_cnt, null))/count(if(m1.order_asc_rank>1 and m1.is_tqjq=1, id, null)) as multi_loan_in_loan_order_all_advanceget3days_maxcontinuecompletedadvanceinstaloverallcompletedadvanceratio
      ,max(if(m1.order_asc_rank>1, m8.max_cnt, null))/count(if(m1.order_asc_rank>1 and (m1.loan_end_date <= substr(m1.use_create_time,1,10) or m1.settled_time < m1.use_create_time), m1.id, null)) as multi_loan_in_loan_order_all_advanceget3days_maxcontinuecompletedadvanceinstalovercompletedorexpiredratio

      ,max(if(m1.order_asc_rank>1, m3.max_cnt, null)) as multi_loan_in_loan_order_all_maxcontinuecompletedadvanceinstalcnt
      ,max(if(m1.order_asc_rank>1, m3.max_cnt, null))/count(if(m1.order_asc_rank>1 and (m1.loan_end_date <= substr(m1.use_create_time,1,10) or m1.settled_time < m1.use_create_time), m1.id, null)) as multi_loan_in_loan_order_all_maxcontinuecompletedadvanceinstalratio
      ,max(if(m1.order_asc_rank>1, m4.max_cnt, null)) as multi_loan_in_loan_order_all_maxcontinueoverdueinstalcnt
      ,max(if(m1.order_asc_rank>1, m4.max_cnt, null))/count(if(m1.order_asc_rank>1 and m1.loan_end_date <= substr(m1.use_create_time,1,10), m1.id, null)) as multi_loan_in_loan_order_all_maxcontinueoverdueinstalratio
      --续借全部在贷订单_3个月内每月最大逾期账单数，使用greatest取三个值中的最大值
      ,max(if(m1.order_asc_rank>1, greatest(m9.l30d_overdue_cnt, m9.l30d_60d_overdue_cnt, m9.l60d_90d_overdue_cnt), null)) as multi_loan_in_loan_order_all_maxoverdueinstalcntforwithinthreemonths
      ---【multi_loan_order_info】相关特征
      --在贷订单已结清本金占最新剩余额度比例
      ,sum(if(m1.is_unclear_tag=1 and m1.settled_time<m1.use_create_time, m1.repaid_principal, 0))/max(m1.available_limit) as multi_loan_order_info_inloanorders_completeprincipalvslatestremaincreditratio
      --续借在贷订单已结清本金占最新剩余额度比例
      ,sum(if(m1.is_unclear_tag=1 and m1.order_asc_rank>1 and m1.settled_time<m1.use_create_time, m1.repaid_principal, 0))/max(m1.available_limit) as multi_loan_order_info_multiloanorders_completeprincipalvslatestremaincreditratio
      --最远一笔订单最大连续提前结清占到期账单比例
      ,max(if(m1.total_order_asc_rank=1, m3.max_cnt, null))/count(if(m1.total_order_asc_rank=1 and m1.loan_end_date <= substr(m1.use_create_time,1,10), m1.id, null)) as multi_loan_order_info_furthestsingleorder_maxsuccessiveprepaytermvsbillingratio
      --最远一笔订单最大连续提前结清占所有期数比例
      ,max(if(m1.total_order_asc_rank=1, m3.max_cnt, null))/max(if(m1.total_order_asc_rank=1, m1.periods, null)) as multi_loan_order_info_furthestsingleorder_maxsuccessiveprepaytermvsallratio
      --最远一笔订单最大连续提前结清期数
      ,max(if(m1.total_order_asc_rank=1, m3.max_cnt, null)) as multi_loan_order_info_furthestsingleorder_maxsuccessiveprepaytermcnt
      --最远一笔订单最大连续逾期占到期账单比例
      ,max(if(m1.total_order_asc_rank=1, m4.max_cnt, null))/count(if(m1.total_order_asc_rank=1 and m1.loan_end_date <= substr(m1.use_create_time,1,10), m1.id, null)) as multi_loan_order_info_furthestsingleorder_maxsuccessiveoverduetermvsbillingratio
      --最远一笔订单最大连续逾期占所有期数比例
      ,max(if(m1.total_order_asc_rank=1, m4.max_cnt, null))/count(if(m1.total_order_asc_rank=1, m1.periods, null)) as multi_loan_order_info_furthestsingleorder_maxsuccessiveoverduetermvsallratio
      --最远一笔订单最大连续逾期期数
      ,max(if(m1.total_order_asc_rank=1, m4.max_cnt, null)) as multi_loan_order_info_furthestsingleorder_maxsuccessiveoverduetermcnt

       --最近第一笔订单最大连续提前结清占到期账单比例
      ,max(if(m1.total_order_desc_rank=1, m3.max_cnt, null))/count(if(m1.total_order_desc_rank=1 and m1.loan_end_date <= substr(m1.use_create_time,1,10), m1.id, null)) as multi_loan_order_info_latest1singleorder_maxsuccessiveprepaytermvsbillingratio
      --最近第一笔订单最大连续提前结清占所有期数比例
      ,max(if(m1.total_order_desc_rank=1, m3.max_cnt, null))/max(if(m1.total_order_desc_rank=1, m1.periods, null)) as multi_loan_order_info_latest1singleorder_maxsuccessiveprepaytermvsallratio
      --最近第一笔订单最大连续提前结清期数
      ,max(if(m1.total_order_desc_rank=1, m3.max_cnt, null)) as multi_loan_order_info_latest1singleorder_maxsuccessiveprepaytermcnt
      --最近第一笔订单最大连续逾期占到期账单比例
      ,max(if(m1.total_order_desc_rank=1, m4.max_cnt, null))/count(if(m1.total_order_desc_rank=1 and m1.loan_end_date <= substr(m1.use_create_time,1,10), m1.id, null)) as multi_loan_order_info_latest1singleorder_maxsuccessiveoverduetermvsbillingratio
      --最近第一笔订单最大连续逾期占所有期数比例
      ,max(if(m1.total_order_desc_rank=1, m4.max_cnt, null))/count(if(m1.total_order_desc_rank=1, m1.periods, null)) as multi_loan_order_info_latest1singleorder_maxsuccessiveoverduetermvsallratio
      --最近第一笔订单最大连续逾期期数
      ,max(if(m1.total_order_desc_rank=1, m4.max_cnt, null)) as multi_loan_order_info_latest1singleorder_maxsuccessiveoverduetermcnt

      --最近第二笔订单最大连续提前结清占到期账单比例
      ,max(if(m1.total_order_desc_rank=2, m3.max_cnt, null))/count(if(m1.total_order_desc_rank=2 and m1.loan_end_date <= substr(m1.use_create_time,1,10), m1.id, null)) as multi_loan_order_info_latest2singleorder_maxsuccessiveprepaytermvsbillingratio
      --最近第二笔订单最大连续提前结清占所有期数比例
      ,max(if(m1.total_order_desc_rank=2, m3.max_cnt, null))/max(if(m1.total_order_desc_rank=2, m1.periods, null)) as multi_loan_order_info_latest2singleorder_maxsuccessiveprepaytermvsallratio
      --最近第二笔订单最大连续提前结清期数
      ,max(if(m1.total_order_desc_rank=2, m3.max_cnt, null)) as multi_loan_order_info_latest2singleorder_maxsuccessiveprepaytermcnt
      --最近第二笔订单最大连续逾期占到期账单比例
      ,max(if(m1.total_order_desc_rank=2, m4.max_cnt, null))/count(if(m1.total_order_desc_rank=2 and m1.loan_end_date <= substr(m1.use_create_time,1,10), m1.id, null)) as multi_loan_order_info_latest2singleorder_maxsuccessiveoverduetermvsbillingratio
      --最近第二笔订单最大连续逾期占所有期数比例
      ,max(if(m1.total_order_desc_rank=2, m4.max_cnt, null))/count(if(m1.total_order_desc_rank=2, m1.periods, null)) as multi_loan_order_info_latest2singleorder_maxsuccessiveoverduetermvsallratio
      --最近第二笔订单最大连续逾期期数
      ,max(if(m1.total_order_desc_rank=2, m4.max_cnt, null)) as multi_loan_order_info_latest2singleorder_maxsuccessiveoverduetermcnt

      --最远一笔订单同一天结清期数最大值
      ,max(if(m1.total_order_asc_rank=1, m2.day_settled_cnt_max, null)) as multi_loan_order_info_furthestsingleorder_completesamedaytermscntmax
      --最远一笔订单同一天结清期数平均值
      ,max(if(m1.total_order_asc_rank=1, m2.day_settled_cnt_avg, null)) as multi_loan_order_info_furthestsingleorder_completesamedaytermscntavg
      --最近第二笔订单同一天结清期数最大值
      ,max(if(m1.total_order_desc_rank=2, m2.day_settled_cnt_max, null)) as multi_loan_order_info_latest2singleorder_completesamedaytermscntmax
      --最近第二笔订单同一天结清期数平均值
      ,max(if(m1.total_order_desc_rank=2, m2.day_settled_cnt_avg, null)) as multi_loan_order_info_latest2singleorder_completesamedaytermscntavg
      --最近第一笔订单额度使用率
      ,max(if(m1.total_order_desc_rank=1, m1.creditlimit_use_ratio, null)) as multi_loan_order_info_latest1singleorder_creditusageratio
      --未来0-15天未结清账单占所有未结清比例
      ,count(if(m1.loan_end_date >substr(m1.use_create_time,1,10) and m1.loan_end_date<=date_add(substr(m1.use_create_time,1,10),15) and (m1.settled_time is null or m1.settled_time>m1.use_create_time),m1.id, null))/count(if(m1.settled_time is null or m1.settled_time>m1.use_create_time,m1.id,null)) as multi_loan_order_info_multiloanrangefuture0dto15d_futurebillingunclearvsunclearinstalratio
       --未来0-15天未结清账单占所有已结清比例
      ,count(if(m1.loan_end_date >substr(m1.use_create_time,1,10) and m1.loan_end_date<=date_add(substr(m1.use_create_time,1,10),15) and (m1.settled_time is null or m1.settled_time>m1.use_create_time),m1.id, null))/count(if(m1.settled_time < m1.use_create_time,m1.id,null)) as multi_loan_order_info_multiloanrangefuture0dto15d_futurebillingunclearvsclearinstalratio
      --未来15-30天未结清账单占所有未结清比例
      ,count(if(m1.loan_end_date >date_add(substr(m1.use_create_time,1,10),15) and m1.loan_end_date<=date_add(substr(m1.use_create_time,1,10),30) and (m1.settled_time is null or m1.settled_time>m1.use_create_time),m1.id, null))/count(if(m1.settled_time is null or m1.settled_time>m1.use_create_time,m1.id,null)) as multi_loan_order_info_multiloanrangefuture15dto30d_futurebillingunclearvsunclearinstalratio
       --未来15-30天未结清账单占所有已结清比例
      ,count(if(m1.loan_end_date >date_add(substr(m1.use_create_time,1,10),15) and m1.loan_end_date<=date_add(substr(m1.use_create_time,1,10),30) and (m1.settled_time is null or m1.settled_time>m1.use_create_time),m1.id, null))/count(if(m1.settled_time < m1.use_create_time,m1.id,null)) as multi_loan_order_info_multiloanrangefuture15dto30d_futurebillingunclearvsclearinstalratio

      --未来30-60天未结清账单占所有未结清比例
      ,count(if(m1.loan_end_date >date_add(substr(m1.use_create_time,1,10),30) and m1.loan_end_date<=date_add(substr(m1.use_create_time,1,10),60) and (m1.settled_time is null or m1.settled_time>m1.use_create_time),m1.id, null))/count(if(m1.settled_time is null or m1.settled_time>m1.use_create_time,m1.id,null)) as multi_loan_order_info_multiloanrangefuture30dto60d_futurebillingunclearvsunclearinstalratio
       --未来30-60天未结清账单占所有已结清比例
      ,count(if(m1.loan_end_date >date_add(substr(m1.use_create_time,1,10),30) and m1.loan_end_date<=date_add(substr(m1.use_create_time,1,10),60) and (m1.settled_time is null or m1.settled_time>m1.use_create_time),m1.id, null))/count(if(m1.settled_time < m1.use_create_time,m1.id,null)) as multi_loan_order_info_multiloanrangefuture30dto60d_futurebillingunclearvsclearinstalratio

      --未来60-90天未结清账单占所有未结清比例
      ,count(if(m1.loan_end_date >date_add(substr(m1.use_create_time,1,10),60) and m1.loan_end_date<=date_add(substr(m1.use_create_time,1,10),90) and (m1.settled_time is null or m1.settled_time>m1.use_create_time),m1.id, null))/count(if(m1.settled_time is null or m1.settled_time>m1.use_create_time,m1.id,null)) as multi_loan_order_info_multiloanrangefuture60dto90d_futurebillingunclearvsunclearinstalratio
       --未来60-90天未结清账单占所有已结清比例
      ,count(if(m1.loan_end_date >date_add(substr(m1.use_create_time,1,10),60) and m1.loan_end_date<=date_add(substr(m1.use_create_time,1,10),90) and (m1.settled_time is null or m1.settled_time>m1.use_create_time),m1.id, null))/count(if(m1.settled_time < m1.use_create_time,m1.id,null)) as multi_loan_order_info_multiloanrangefuture60dto90d_futurebillingunclearvsclearinstalratio
      --最远一笔订单创建距额度测算间隔
      ,max(if(m1.total_order_asc_rank=1,datediff(cast(m1.creadit_use_create_time as date), cast(m1.credit_create_time as date)),null)) as multi_loan_order_info_furthestsingleorder_createdcalccreditgap
from target_user_credit_loan_repay_info as m1
left join (
    ---notes：该段目的，为了统计近一笔订单的同一天结清账单数平均值等指标，此处逻辑非常绕，无法精简sql
    select loan_no
        ,cust_no
        ,use_create_time
        ,avg(day_settled_cnt) as day_settled_cnt_avg
        ,max(day_settled_cnt) as day_settled_cnt_max
    from (
    select loan_no
        ,cust_no
        ,use_create_time
        ,substr(settled_time,1,10) as settled_date
        ,count(1) as day_settled_cnt
    from target_user_credit_loan_repay_info
    where settled_time is not null
    group by loan_no,cust_no,use_create_time,substr(settled_time,1,10)
    ) as tt group by loan_no,cust_no,use_create_time
) as m2
on m1.loan_no = m2.loan_no and m1.cust_no = m2.cust_no and m1.use_create_time = m2.use_create_time
left join (
    ---notes：该段目的，用以标识出用户发生了连续提前结清这种行为的情况，该逻辑依旧非常绕
    ---如果是连续提前还款，那么记录中的periods和rn相减出来的值肯定是相等的
    select loan_no,cust_no,use_create_time,max(cnt) as max_cnt
    from (
        select loan_no
              ,cust_no
              ,use_create_time
              ,(periods-rn) as diff
              ,count(1) as cnt
        from(
            select loan_no
                  ,periods
                  ,cust_no
                  ,use_create_time
                  ,row_number()over(partition by loan_no order by periods asc) as rn
            from target_user_credit_loan_repay_info
            where is_tqjq=1
            ) as tt1
            group by loan_no,(periods-rn),cust_no,use_create_time
    ) as tt2
    group by loan_no,cust_no,use_create_time
) as m3
on m1.loan_no = m3.loan_no and m1.cust_no = m3.cust_no and m1.use_create_time = m3.use_create_time
left join (
    ---notes：该段目的，用以标识出用户发生了连续逾期这种行为的情况，该逻辑依旧非常绕
    ---如果是连续提前还款，那么记录中的periods和rn相减出来的值肯定是相等的
    select cust_no,use_create_time,loan_no,max(cnt) as max_cnt
    from (
        select  cust_no
               ,use_create_time
               ,loan_no
              ,(periods-rn) as diff
              ,count(1) as cnt
        from(
            select loan_no
                  ,periods
                  ,cust_no
                  ,use_create_time
                  ,row_number()over(partition by loan_no order by periods asc) as rn
            from target_user_credit_loan_repay_info
            where is_overdue=1
            ) as tt1
            group by cust_no,use_create_time,loan_no,(periods-rn)
    ) as tt2
    group by cust_no,use_create_time,loan_no
) as m4
on m1.loan_no = m4.loan_no and m1.cust_no = m4.cust_no and m1.use_create_time = m4.use_create_time
left join (
    ---notes：该段目的，用以先算出平均额度使用率
    select use_create_time,cust_no,avg(creditlimit_use_ratio) as creditlimit_use_ratio_avg
    from(
    select use_create_time,cust_no,loan_no,creditlimit_use_ratio
    from target_user_credit_loan_repay_info
    where is_unclear_tag=1
    group by use_create_time,cust_no,loan_no,creditlimit_use_ratio
    ) as tt1
    group by use_create_time,cust_no
) as m5
on m1.use_create_time = m5.use_create_time and m1.cust_no = m5.cust_no
left join (
    ---notes：该段目的，用以标识出用户发生了连续提前结清这种行为的情况，该逻辑依旧非常绕
    ---如果是连续提前还款，那么记录中的periods和rn相减出来的值肯定是相等的
    select loan_no,cust_no,use_create_time,max(cnt) as max_cnt
    from (
        select loan_no
              ,cust_no
              ,use_create_time
              ,(periods-rn) as diff
              ,count(1) as cnt
        from(
            select loan_no
                  ,periods
                  ,cust_no
                  ,use_create_time
                  ,row_number()over(partition by loan_no order by periods asc) as rn
            from target_user_credit_loan_repay_info
            where is_tqjq_15d=1
            ) as tt1
            group by loan_no,(periods-rn),cust_no,use_create_time
    ) as tt2
    group by loan_no,cust_no,use_create_time
) as m6
on m1.loan_no = m6.loan_no and m1.cust_no = m6.cust_no and m1.use_create_time = m6.use_create_time
left join (
    ---notes：该段目的，用以标识出用户发生了连续提前结清这种行为的情况，该逻辑依旧非常绕
    ---如果是连续提前还款，那么记录中的periods和rn相减出来的值肯定是相等的
    select loan_no,cust_no,use_create_time,max(cnt) as max_cnt
    from (
        select loan_no
              ,cust_no
              ,use_create_time
              ,(periods-rn) as diff
              ,count(1) as cnt
        from(
            select loan_no
                  ,periods
                  ,cust_no
                  ,use_create_time
                  ,row_number()over(partition by loan_no order by periods asc) as rn
            from target_user_credit_loan_repay_info
            where is_tqjq_7d=1
            ) as tt1
            group by loan_no,(periods-rn),cust_no,use_create_time
    ) as tt2
    group by loan_no,cust_no,use_create_time
) as m7
on m1.loan_no = m7.loan_no and m1.cust_no = m7.cust_no and m1.use_create_time = m7.use_create_time
left join (
    ---notes：该段目的，用以标识出用户发生了连续提前结清这种行为的情况，该逻辑依旧非常绕
    ---如果是连续提前还款，那么记录中的periods和rn相减出来的值肯定是相等的
    select loan_no,cust_no,use_create_time,max(cnt) as max_cnt
    from (
        select loan_no
              ,cust_no
              ,use_create_time
              ,(periods-rn) as diff
              ,count(1) as cnt
        from(
            select loan_no
                  ,periods
                  ,cust_no
                  ,use_create_time
                  ,row_number()over(partition by loan_no order by periods asc) as rn
            from target_user_credit_loan_repay_info
            where is_tqjq_3d=1
            ) as tt1
            group by loan_no,(periods-rn),cust_no,use_create_time
    ) as tt2
    group by loan_no,cust_no,use_create_time
) as m8
on m1.loan_no = m8.loan_no and m1.cust_no = m8.cust_no and m1.use_create_time = m8.use_create_time
left join (
    ---notes：该段目的，统计“续借全部在贷订单_3个月内每月最大逾期账单数”字段，逻辑很绕
    select use_create_time
          ,cust_no
          ,count(if(loan_end_date <substr(use_create_time,1,10) and loan_end_date >=date_sub(substr(use_create_time,1,10),30) and is_overdue=1, id, null)) as l30d_overdue_cnt
          ,count(if(loan_end_date <date_sub(substr(use_create_time,1,10),30) and loan_end_date >=date_sub(substr(use_create_time,1,10),60) and is_overdue=1, id, null)) as l30d_60d_overdue_cnt
          ,count(if(loan_end_date <date_sub(substr(use_create_time,1,10),60) and loan_end_date >=date_sub(substr(use_create_time,1,10),90) and is_overdue=1, id, null)) as l60d_90d_overdue_cnt
    from target_user_credit_loan_repay_info
    group by use_create_time,cust_no
) as m9
on m1.cust_no = m9.cust_no and m1.use_create_time = m9.use_create_time
group by m1.use_create_time,m1.cust_no) t


