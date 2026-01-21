with mid_table as (
select m0.cust_no
      ,m0.use_credit_apply_id
      ,m0.use_create_time
      ,m0.use_credit_apply_date
      ,m0.use_amount
      ,m0.use_period
      ,m5.loaninfo_create_time
      ,m5.loan_period
      ,m5.real_loan_amt
      ,m5.id 
      ,m5.loan_no
      ,m5.periods
      ,m5.create_time
      ,datediff(to_date(m0.use_create_time), to_date(m5.create_time)) as applyinterval
      ,m5.settled_time
      ,m5.loan_day
      ,case when m5.loan_end_date<=to_date(m0.use_create_time) and (m5.settled_time < m0.use_create_time or to_date(m5.settled_time) is null) then datediff(coalesce(to_date(m5.settled_time),to_date(m0.use_create_time)),to_date(m5.loan_end_date))
            when m5.loan_end_date<=to_date(m0.use_create_time) and (m5.settled_time >= m0.use_create_time or to_date(m5.settled_time) is null) then datediff(to_date(m0.use_create_time),to_date(m5.loan_end_date)) else null end as overduedays
      ,if(m5.loan_end_date<=to_date(m0.use_create_time) and m5.settled_time < m0.use_create_time ,datediff(coalesce(to_date(m5.settled_time),to_date(m0.use_create_time)),to_date(m5.loan_end_date)),null) as overduedays_pay
      ,if(to_date(m5.settled_time)<=m5.loan_end_date and m5.settled_time < m0.use_create_time ,abs(datediff(to_date(m5.settled_time),to_date(m5.loan_end_date))),null) as prepaydays
      ,dense_rank()over(partition by m0.cust_no,m0.use_credit_apply_id order by m5.create_time desc) as rank
from (
    -- 修改点1：使用最新分区20260106，并取近三个月数据
    select cust_no,use_credit_apply_id,use_create_time,substr(use_create_time,1,10) as use_credit_apply_date,use_period,use_amount
    from hive_idc.oversea.dws_trd_credit_apply_use_loan_df
    where pt = '20260106'  -- 使用最新分区
    and substr(use_create_time,1,10) >= '2025-10-01'  -- 近三个月：2025-10-01到2026-01-06
    ) as m0
inner join (
    select m1.cust_no
          ,m4.id
          ,m3.loan_no
          ,m4.periods
          ,m1.create_time --申请时间
          ,m3.create_time as loaninfo_create_time
          ,m3.loan_period ---期数
          ,m3.loan_day --天数
          ,m3.real_loan_amt ---本金
          ,m4.settled_time
          ,m4.loan_end_date
    from (select *from hive_idc.oversea.ods_mx_aprv_approve_use_credit_apply_df where pt = '20260106' and substr(create_time,1,10) <= '2026-01-06') as m1  -- 使用最新分区
    inner join (select * from hive_idc.oversea.ods_mx_ast_asset_loan_apply_df where pt = '20260106' and substr(create_time,1,10) <= '2026-01-06') as m2  -- 使用最新分区
    on m1.asset_id = m2.seq_no
    inner join (select * from hive_idc.oversea.ods_mx_ast_asset_loan_info_df where loan_status<>'4' and pt = '20260106' and substr(create_time,1,10) <= '2026-01-06') as m3  -- 使用最新分区
    on m2.loan_apply_no = m3.loan_apply_no
    inner join (select * from hive_idc.oversea.ods_mx_ast_asset_repay_plan_df where repay_plan_status<>'4' and pt = '20260106' and substr(create_time,1,10) <= '2026-01-06') as m4  -- 使用最新分区
    on m3.loan_no = m4.loan_no
    ) as m5
on m0.cust_no = m5.cust_no
----一定更要取申请之前的订单
where m0.use_create_time > m5.create_time
and m0.use_create_time > m5.loaninfo_create_time
),

mid_table_payofftags as (
    select cust_no
          ,use_credit_apply_id
          ,use_create_time
          ,loan_no
          ,count(id) as ids
          ,count(if(settled_time is not null and settled_time<use_create_time,id,null)) as settled_ids
    from mid_table
    group by cust_no,use_credit_apply_id,use_create_time,loan_no
    having count(id) = count(if(settled_time is not null and settled_time<use_create_time,id,null))
)
select * from (
select  t1.cust_no
        ,t1.use_credit_apply_id
        ,t1.use_create_time
        ,t1.use_credit_apply_date
        ,if(t1.use_create_time>t2.first_laon_time, datediff(to_date(t1.use_create_time),to_date(t2.first_laon_time)),null) as local_olduser_order_info_firstloannowgapdays_v2
        ,if(t3.cust_no is not null,datediff(to_date(t1.use_create_time),to_date(t3.create_time)),null) as local_olduser_order_info_registernowgapdays_v2
        ,local_olduser_order_info_recent1order_currentorder_createsecondgap_v2
        ,local_olduser_order_info_recent1order_currentorder_createdaygap_v2
        ,local_olduser_order_info_recent1order_currentorder_periodgap_v2
        ,local_olduser_order_info_recent1order_currentorder_amountratio_v2
        ,local_olduser_order_info_recent1order_applyhour_v2
        ,local_olduser_order_info_currentorder_applyhour_v2
        ,local_olduser_order_info_recent1order_currentorder_applyhourgap_v2
        ,local_olduser_order_info_recent1order_night_v2
        ,local_olduser_order_info_recent1order_morning_v2
        ,local_olduser_order_info_recent1order_noon_v2
        ,local_olduser_order_info_recent1order_afternoon_v2
        ,local_olduser_order_info_recent1order_evening_v2
        ,local_olduser_order_info_recent1order_maxoverduedays_v2
        ,local_olduser_order_info_recent1order_minoverduedays_v2
        ,local_olduser_order_info_recent1order_sumoverduedays_v2
        ,local_olduser_order_info_recent1order_sumprepaydays_v2
        ,local_olduser_order_info_recent1order_maxprepaydays_v2
        ,local_olduser_order_info_recent1order_minprepaydays_v2
        ,local_olduser_order_info_recent1order_countidoverduedays_v2
        ,local_olduser_order_info_recent1order_countidprepaydays_v2
        ,local_olduser_order_info_recent1order_payperiods_v2
        ,local_olduser_order_info_recent1ordercurrentday_payperiods_v2
        ,local_olduser_order_info_recent1order_loanamount_v2
        ,local_olduser_order_info_recent1order_repayperiods_v2
        ,local_olduser_order_info_recent1order_period1overdue_v2
        ,local_olduser_order_info_recent1order_period1overduedays_v2
        ,local_olduser_order_info_recent1order_period2overdue_v2
        ,local_olduser_order_info_recent1order_period2overduedays_v2
        ,local_olduser_order_info_recent1order_period3overdue_v2
        ,local_olduser_order_info_recent1order_period3overduedays_v2
        ,local_olduser_order_info_recent1order_period4overdue_v2
        ,local_olduser_order_info_recent1order_period4overduedays_v2
        ,local_olduser_order_info_recent2order_loanhouravg_v2
        ,local_olduser_order_info_recent2ordercurrentorder_loanhourgapavg_v2
        ,local_olduser_order_info_recent2order_nightcnt_v2
        ,local_olduser_order_info_recent2order_morning_v2
        ,local_olduser_order_info_recent2order_noon_v2
        ,local_olduser_order_info_recent2order_afternoon_v2
        ,local_olduser_order_info_recent2order_evening_v2
        ,local_olduser_order_info_recent2order_maxoverduedays_v2
        ,local_olduser_order_info_recent2order_minoverduedays_v2
        ,local_olduser_order_info_recent2order_sumoverduedays_v2
        ,local_olduser_order_info_recent2order_avgoverduedays_v2
        ,local_olduser_order_info_recent2order_maxprepaydays_v2
        ,local_olduser_order_info_recent2order_minprepaydays_v2
        ,local_olduser_order_info_recent2order_sumprepaydays_v2
        ,local_olduser_order_info_recent2order_avgprepaydays_v2
        ,local_olduser_order_info_recent2order_ovedueloannocnt_v2
        ,local_olduser_order_info_recent2order_ovedueidcnt_v2
        ,local_olduser_order_info_recent2order_prepayloannocnt_v2
        ,local_olduser_order_info_recent2order_prepayidcnt_v2
        ,local_olduser_order_info_recent2order_loandaysuseratio_v2
        ,local_olduser_order_info_recent2order_currentloandays_v2
        ,local_olduser_order_info_recent2order_loanamount_v2
        ,local_olduser_order_info_recent2order_period1overdue_v2
        ,local_olduser_order_info_recent2order_period1maxoverduedays_v2
        ,local_olduser_order_info_recent2order_period2overdue_v2
        ,local_olduser_order_info_recent2order_period2maxoverduedays_v2
        ,local_olduser_order_info_recent2order_period3overdue_v2
        ,local_olduser_order_info_recent2order_period3maxoverduedays_v2
        ,local_olduser_order_info_recent2order_period4overdue_v2
        ,local_olduser_order_info_recent2order_period4maxoverduedays_v2
        ,local_olduser_order_info_recent2order_firstoverduedayrank_v2
        ,local_olduser_order_info_recent3order_loanhouravg_v2
        ,local_olduser_order_info_recent3ordercurrentorder_loanhourgapavg_v2
        ,local_olduser_order_info_recent3order_nightcnt_v2
        ,local_olduser_order_info_recent3order_morning_v2
        ,local_olduser_order_info_recent3order_noon_v2
        ,local_olduser_order_info_recent3order_afternoon_v2
        ,local_olduser_order_info_recent3order_evening_v2
        ,local_olduser_order_info_recent3order_maxoverduedays_v2
        ,local_olduser_order_info_recent3order_minoverduedays_v2
        ,local_olduser_order_info_recent3order_sumoverduedays_v2
        ,local_olduser_order_info_recent3order_avgoverduedays_v2
        ,local_olduser_order_info_recent3order_maxprepaydays_v2
        ,local_olduser_order_info_recent3order_minprepaydays_v2
        ,local_olduser_order_info_recent3order_sumprepaydays_v2
        ,local_olduser_order_info_recent3order_avgprepaydays_v2
        ,local_olduser_order_info_recent3order_ovedueloannocnt_v2
        ,local_olduser_order_info_recent3order_ovedueidcnt_v2
        ,local_olduser_order_info_recent3order_prepayloannocnt_v2
        ,local_olduser_order_info_recent3order_prepayidcnt_v2
        ,local_olduser_order_info_recent3order_loandaysuseratio_v2
        ,local_olduser_order_info_recent3order_currentloandays_v2
        ,local_olduser_order_info_recent3order_loanamount_v2
        ,local_olduser_order_info_recent3order_period1overdue_v2
        ,local_olduser_order_info_recent3order_period1maxoverduedays_v2
        ,local_olduser_order_info_recent3order_period2overdue_v2
        ,local_olduser_order_info_recent3order_period2maxoverduedays_v2
        ,local_olduser_order_info_recent3order_period3overdue_v2
        ,local_olduser_order_info_recent3order_period3maxoverduedays_v2
        ,local_olduser_order_info_recent3order_period4overdue_v2
        ,local_olduser_order_info_recent3order_period4maxoverduedays_v2
        ,local_olduser_order_info_recent3order_firstoverduedayrank_v2
        ,local_olduser_order_info_payofforder_maxoverduedays_v2
        ,local_olduser_order_info_payofforder_minoverduedays_v2
        ,local_olduser_order_info_payofforder_sumoverduedays_v2
        ,local_olduser_order_info_payofforder_avgoverduedays_v2
        ,local_olduser_order_info_payofforder_maxprepaydays_v2
        ,local_olduser_order_info_payofforder_minprepaydays_v2
        ,local_olduser_order_info_payofforder_sumprepaydays_v2
        ,local_olduser_order_info_payofforder_avgprepaydays_v2
        ,local_olduser_order_info_recent1payofforder_currentorder_createsecondgap_v2
        ,local_olduser_order_info_recent1payofforder_currentorder_createdaygap_v2
        ,local_olduser_order_info_recent1payofforder_currentorder_periodgap_v2
        ,local_olduser_order_info_recent1payofforder_currentorder_amountratio_v2
        ,local_olduser_order_info_recent1payofforder_applyhour_v2
        ,local_olduser_order_info_recent1payofforder_currentorder_applyhourgap_v2
        ,local_olduser_order_info_recent1payofforder_night_v2
        ,local_olduser_order_info_recent1payofforder_morning_v2
        ,local_olduser_order_info_recent1payofforder_noon_v2
        ,local_olduser_order_info_recent1payofforder_afternoon_v2
        ,local_olduser_order_info_recent1payofforder_evening_v2
        ,local_olduser_order_info_recent1payofforder_maxoverduedays_v2
        ,local_olduser_order_info_recent1payofforder_minoverduedays_v2
        ,local_olduser_order_info_recent1payofforder_sumoverduedays_v2
        ,local_olduser_order_info_recent1payofforder_sumprepaydays_v2
        ,local_olduser_order_info_recent1payofforder_maxprepaydays_v2
        ,local_olduser_order_info_recent1payofforder_minprepaydays_v2
        ,local_olduser_order_info_recent1payofforder_countidoverduedays_v2
        ,local_olduser_order_info_recent1payofforder_countidprepaydays_v2
        ,local_olduser_order_info_recent1payofforder_payperiods_v2
        ,local_olduser_order_info_recent1payoffordercurrentday_payperiods_v2
        ,local_olduser_order_info_recent1payofforder_loanamount_v2
        ,local_olduser_order_info_recent1payofforder_repayperiods_v2
        ,local_olduser_order_info_recent1payofforder_period1overdue_v2
        ,local_olduser_order_info_recent1payofforder_period1overduedays_v2
        ,local_olduser_order_info_recent1payofforder_period2overdue_v2
        ,local_olduser_order_info_recent1payofforder_period2overduedays_v2
        ,local_olduser_order_info_recent1payofforder_period3overdue_v2
        ,local_olduser_order_info_recent1payofforder_period3overduedays_v2
        ,local_olduser_order_info_recent1payofforder_period4overdue_v2
        ,local_olduser_order_info_recent1payofforder_period4overduedays_v2    
from (
    -- 修改点2：使用最新分区20260106，并取近三个月数据
    select cust_no,use_credit_apply_id,use_create_time,substr(use_create_time,1,10) as use_credit_apply_date
    from hive_idc.oversea.dws_trd_credit_apply_use_loan_df
    where pt = '20260106'  -- 使用最新分区
    and substr(use_create_time,1,10) >= '2025-10-01'  -- 近三个月：2025-10-01到2026-01-06
    ) as t1
left join (
    -- 修改点3：为了获取用户首次贷款时间，这里使用最新分区，但不限制时间范围（获取历史所有数据）
    select cust_no
          ,min(create_time) as first_laon_time
    from hive_idc.oversea.ods_mx_ast_asset_loan_info_df
    where loan_status <>'4' and pt = '20260106'  -- 使用最新分区（假设最新分区包含全量历史数据）
    group by cust_no
) as t2 on t1.cust_no = t2.cust_no
left join (
    ---这样写是考虑到申请的用户都是注册用户
    select create_time,cust_no
    from hive_idc.oversea.ods_mx_cust_cust_account_info_df
    where pt = '20260106'  -- 使用最新分区
) as t3 on t1.cust_no = t3.cust_no
left join (
select cust_no
      ,use_credit_apply_id
      ,use_create_time
      ,use_credit_apply_date
      ,max(if(rank=1, (unix_timestamp(use_create_time) - unix_timestamp(create_time)),null)) as local_olduser_order_info_recent1order_currentorder_createsecondgap_v2
      ,max(if(rank=1, datediff(to_date(use_create_time), to_date(create_time)),null)) as local_olduser_order_info_recent1order_currentorder_createdaygap_v2
      ,max(if(rank=1,use_period - loan_period, null)) as local_olduser_order_info_recent1order_currentorder_periodgap_v2
      ,round(max(if(rank=1,use_amount/real_loan_amt, null)),6) as local_olduser_order_info_recent1order_currentorder_amountratio_v2
      ,max(if(rank =1,cast(substr(create_time,12,2) as bigint),null)) as local_olduser_order_info_recent1order_applyhour_v2
      ,max(if(rank =1,cast(substr(use_create_time,12,2) as bigint),null)) as local_olduser_order_info_currentorder_applyhour_v2
      ,max(if(rank =1,cast(substr(use_create_time,12,2) as bigint) -cast(substr(create_time,12,2) as bigint),null)) as local_olduser_order_info_recent1order_currentorder_applyhourgap_v2
      ,max(if(rank =1 and (cast(substr(create_time,12,2) as bigint)>=23 or cast(substr(create_time,12,2) as bigint)<5),1,0)) as local_olduser_order_info_recent1order_night_v2
      ,max(if(rank =1 and (cast(substr(create_time,12,2) as bigint)>=5 and cast(substr(create_time,12,2) as bigint)<11),1,0)) as local_olduser_order_info_recent1order_morning_v2
      ,max(if(rank =1 and (cast(substr(create_time,12,2) as bigint)>=11 and cast(substr(create_time,12,2) as bigint)<13),1,0)) as local_olduser_order_info_recent1order_noon_v2
      ,max(if(rank =1 and (cast(substr(create_time,12,2) as bigint)>=13 and cast(substr(create_time,12,2) as bigint)<18),1,0)) as local_olduser_order_info_recent1order_afternoon_v2
      ,max(if(rank =1 and (cast(substr(create_time,12,2) as bigint)>=18 and cast(substr(create_time,12,2) as bigint)<23),1,0)) as local_olduser_order_info_recent1order_evening_v2
      ,max(if(rank =1 and overduedays>=0,overduedays,null)) as local_olduser_order_info_recent1order_maxoverduedays_v2
      ,min(if(rank =1 and overduedays>=0,overduedays,null)) as local_olduser_order_info_recent1order_minoverduedays_v2
      ,sum(if(rank =1 and overduedays>=0,overduedays,0)) as local_olduser_order_info_recent1order_sumoverduedays_v2
      ,sum(if(rank=1 and prepaydays>=0,prepaydays,0)) as local_olduser_order_info_recent1order_sumprepaydays_v2
      ,max(if(rank=1,prepaydays,null)) as local_olduser_order_info_recent1order_maxprepaydays_v2
      ,min(if(rank=1,prepaydays,null)) as local_olduser_order_info_recent1order_minprepaydays_v2
      ,count(if(rank =1 and overduedays>0,id,null)) as local_olduser_order_info_recent1order_countidoverduedays_v2
      ,count(if(rank=1 and prepaydays>0,id,null)) as local_olduser_order_info_recent1order_countidprepaydays_v2
      ,count(if(rank=1 and settled_time is not null and settled_time<use_create_time,id,null)) as local_olduser_order_info_recent1order_payperiods_v2
      ,count(if(rank=1 and settled_time<use_create_time and to_date(settled_time) = to_date(use_create_time),id,null)) as local_olduser_order_info_recent1ordercurrentday_payperiods_v2
      ,max(if(rank=1 and periods=1,real_loan_amt,null)) as local_olduser_order_info_recent1order_loanamount_v2
      ,count(if(rank=1 and prepaydays>0, id, null ))/max(if(rank=1, loan_period, null)) as local_olduser_order_info_recent1order_repayperiods_v2
      ,max(if(rank=1 and periods=1 and overduedays>0,1,0)) as local_olduser_order_info_recent1order_period1overdue_v2
      ,max(if(rank=1 and periods=1 and overduedays>0,overduedays,null)) as local_olduser_order_info_recent1order_period1overduedays_v2
      ,max(if(rank=1 and periods=2 and overduedays>0,1,0)) as local_olduser_order_info_recent1order_period2overdue_v2
      ,max(if(rank=1 and periods=2 and overduedays>0,overduedays,null)) as local_olduser_order_info_recent1order_period2overduedays_v2
      ,max(if(rank=1 and periods=3 and overduedays>0,1,0)) as local_olduser_order_info_recent1order_period3overdue_v2
      ,max(if(rank=1 and periods=3 and overduedays>0,overduedays,null)) as local_olduser_order_info_recent1order_period3overduedays_v2
      ,max(if(rank=1 and periods=4 and overduedays>0,1,0)) as local_olduser_order_info_recent1order_period4overdue_v2
      ,max(if(rank=1 and periods=4 and overduedays>0,overduedays,null)) as local_olduser_order_info_recent1order_period4overduedays_v2
      ,sum(if(rank<=2 and periods=1,cast(substr(create_time,12,2) as bigint),0))/count(if(rank<=2 and periods=1,loan_no,null)) as local_olduser_order_info_recent2order_loanhouravg_v2
      ,(cast(substr(use_create_time,12,2) as bigint) - (sum(if(rank<=2 and periods=1,cast(substr(create_time,12,2) as bigint),0))/count(if(rank<=2 and periods=1,loan_no,null)))) as local_olduser_order_info_recent2ordercurrentorder_loanhourgapavg_v2
      ,count(if(rank <=2 and periods=1 and (cast(substr(create_time,12,2) as bigint)>=23 or cast(substr(create_time,12,2) as bigint)<5),loan_no,null)) as local_olduser_order_info_recent2order_nightcnt_v2
      ,sum(if(rank <=2 and periods=1 and (cast(substr(create_time,12,2) as bigint)>=5 and cast(substr(create_time,12,2) as bigint)<11),1,0)) as local_olduser_order_info_recent2order_morning_v2
      ,sum(if(rank <=2 and periods=1 and (cast(substr(create_time,12,2) as bigint)>=11 and cast(substr(create_time,12,2) as bigint)<13),1,0)) as local_olduser_order_info_recent2order_noon_v2
      ,sum(if(rank <=2 and periods=1 and (cast(substr(create_time,12,2) as bigint)>=13 and cast(substr(create_time,12,2) as bigint)<18),1,0)) as local_olduser_order_info_recent2order_afternoon_v2
      ,sum(if(rank <=2 and periods=1 and (cast(substr(create_time,12,2) as bigint)>=18 and cast(substr(create_time,12,2) as bigint)<23),1,0)) as local_olduser_order_info_recent2order_evening_v2
      ,max(if(rank <=2 and overduedays>=0,overduedays,null)) as local_olduser_order_info_recent2order_maxoverduedays_v2
      ,min(if(rank <=2 and overduedays>=0,overduedays,null)) as local_olduser_order_info_recent2order_minoverduedays_v2
      ,sum(if(rank <=2 and overduedays>=0,overduedays,0)) as local_olduser_order_info_recent2order_sumoverduedays_v2
      ,round(avg(if(rank <=2 and overduedays>=0,overduedays,null)),6) as local_olduser_order_info_recent2order_avgoverduedays_v2
      ,max(if(rank <=2 ,prepaydays,null)) as local_olduser_order_info_recent2order_maxprepaydays_v2
      ,min(if(rank <=2 ,prepaydays,null)) as local_olduser_order_info_recent2order_minprepaydays_v2
      ,sum(if(rank <=2 and prepaydays>=0,prepaydays,0)) as local_olduser_order_info_recent2order_sumprepaydays_v2
      ,round(avg(if(rank <=2 ,prepaydays,null)),6) as local_olduser_order_info_recent2order_avgprepaydays_v2
      ,count(distinct if(rank <=2 and overduedays>0, loan_no,null)) as local_olduser_order_info_recent2order_ovedueloannocnt_v2
      ,count(if(rank <=2 and overduedays>0, id,null)) as local_olduser_order_info_recent2order_ovedueidcnt_v2
      ,count(distinct if(rank <=2 and prepaydays>0, loan_no,null)) as local_olduser_order_info_recent2order_prepayloannocnt_v2
      ,count(if(rank <=2 and prepaydays>0, id,null)) as local_olduser_order_info_recent2order_prepayidcnt_v2
      ,round(sum(if(rank <=2 and periods=1, applyinterval,0))/sum(if(rank <=2 and periods=1, loan_day,0)),6) as local_olduser_order_info_recent2order_loandaysuseratio_v2
      ,sum(if(rank <=2 and periods=1, applyinterval,0)) as local_olduser_order_info_recent2order_currentloandays_v2
      ,sum(if(rank<=2 and periods=1,real_loan_amt,null)) as local_olduser_order_info_recent2order_loanamount_v2
      ,max(if(rank<=2 and periods=1 and overduedays>0,1,0 )) as local_olduser_order_info_recent2order_period1overdue_v2
      ,max(if(rank<=2 and periods=1 and overduedays>0,overduedays,null )) as local_olduser_order_info_recent2order_period1maxoverduedays_v2
      ,max(if(rank<=2 and periods=2 and overduedays>0,1,0 )) as local_olduser_order_info_recent2order_period2overdue_v2
      ,max(if(rank<=2 and periods=2 and overduedays>0,overduedays,null )) as local_olduser_order_info_recent2order_period2maxoverduedays_v2
      ,max(if(rank<=2 and periods=3 and overduedays>0,1,0 )) as local_olduser_order_info_recent2order_period3overdue_v2
      ,max(if(rank<=2 and periods=3 and overduedays>0,overduedays,null )) as local_olduser_order_info_recent2order_period3maxoverduedays_v2
      ,max(if(rank<=2 and periods=4 and overduedays>0,1,0 )) as local_olduser_order_info_recent2order_period4overdue_v2
      ,max(if(rank<=2 and periods=4 and overduedays>0,overduedays,null )) as local_olduser_order_info_recent2order_period4maxoverduedays_v2
      ,min(if(rank<=2 and overduedays>0,rank,null )) as local_olduser_order_info_recent2order_firstoverduedayrank_v2
      ,round(sum(if(rank<=3 and periods=1,cast(substr(create_time,12,2) as bigint),0))/count(if(rank<=3 and periods=1,loan_no,null)),6) as local_olduser_order_info_recent3order_loanhouravg_v2
      ,round((cast(substr(use_create_time,12,2) as bigint) - (sum(if(rank<=3 and periods=1,cast(substr(create_time,12,2) as bigint),0))/count(if(rank<=3 and periods=1,loan_no,null)))),6) as local_olduser_order_info_recent3ordercurrentorder_loanhourgapavg_v2
      ,count(if(rank <=3 and periods=1 and (cast(substr(create_time,12,2) as bigint)>=23 or cast(substr(create_time,12,2) as bigint)<5),loan_no,null)) as local_olduser_order_info_recent3order_nightcnt_v2
      ,sum(if(rank <=3 and periods=1 and (cast(substr(create_time,12,2) as bigint)>=5 and cast(substr(create_time,12,2) as bigint)<11),1,0)) as local_olduser_order_info_recent3order_morning_v2
      ,sum(if(rank <=3 and periods=1 and (cast(substr(create_time,12,2) as bigint)>=11 and cast(substr(create_time,12,2) as bigint)<13),1,0)) as local_olduser_order_info_recent3order_noon_v2
      ,sum(if(rank <=3 and periods=1 and (cast(substr(create_time,12,2) as bigint)>=13 and cast(substr(create_time,12,2) as bigint)<18),1,0)) as local_olduser_order_info_recent3order_afternoon_v2
      ,sum(if(rank <=3 and periods=1 and (cast(substr(create_time,12,2) as bigint)>=18 and cast(substr(create_time,12,2) as bigint)<23),1,0)) as local_olduser_order_info_recent3order_evening_v2
      ,max(if(rank <=3 and overduedays>=0,overduedays,null)) as local_olduser_order_info_recent3order_maxoverduedays_v2
      ,min(if(rank <=3 and overduedays>=0,overduedays,null)) as local_olduser_order_info_recent3order_minoverduedays_v2
      ,sum(if(rank <=3 and overduedays>=0,overduedays,0)) as local_olduser_order_info_recent3order_sumoverduedays_v2
      ,round(avg(if(rank <=3 and overduedays>=0,overduedays,null)),6) as local_olduser_order_info_recent3order_avgoverduedays_v2
      ,max(if(rank <=3 ,prepaydays,null)) as local_olduser_order_info_recent3order_maxprepaydays_v2
      ,min(if(rank <=3 and prepaydays>=0,prepaydays,null)) as local_olduser_order_info_recent3order_minprepaydays_v2
      ,sum(if(rank <=3 and prepaydays>=0,prepaydays,0)) as local_olduser_order_info_recent3order_sumprepaydays_v2
      ,round(avg(if(rank <=3 ,prepaydays,null)),6) as local_olduser_order_info_recent3order_avgprepaydays_v2
      ,count(distinct if(rank <=3 and overduedays>0, loan_no,null)) as local_olduser_order_info_recent3order_ovedueloannocnt_v2
      ,count(if(rank <=3 and overduedays>0, id,null)) as local_olduser_order_info_recent3order_ovedueidcnt_v2
      ,count(distinct if(rank <=3 and prepaydays>0, loan_no,null)) as local_olduser_order_info_recent3order_prepayloannocnt_v2
      ,count(if(rank <=3 and prepaydays>0, id,null)) as local_olduser_order_info_recent3order_prepayidcnt_v2
      ,round(sum(if(rank <=3 and periods=1, applyinterval,0))/sum(if(rank <=3 and periods=1, loan_day,0)),6) as local_olduser_order_info_recent3order_loandaysuseratio_v2
      ,sum(if(rank <=3 and periods=1, applyinterval,0)) as local_olduser_order_info_recent3order_currentloandays_v2
      ,sum(if(rank<=3 and periods=1,real_loan_amt,null)) as local_olduser_order_info_recent3order_loanamount_v2
      ,max(if(rank<=3 and periods=1 and overduedays>0,1,0 )) as local_olduser_order_info_recent3order_period1overdue_v2
      ,max(if(rank<=3 and periods=1 and overduedays>0,overduedays,null )) as local_olduser_order_info_recent3order_period1maxoverduedays_v2
      ,max(if(rank<=3 and periods=2 and overduedays>0,1,0 )) as local_olduser_order_info_recent3order_period2overdue_v2
      ,max(if(rank<=3 and periods=2 and overduedays>0,overduedays,null )) as local_olduser_order_info_recent3order_period2maxoverduedays_v2
      ,max(if(rank<=3 and periods=3 and overduedays>0,1,0 )) as local_olduser_order_info_recent3order_period3overdue_v2
      ,max(if(rank<=3 and periods=3 and overduedays>0,overduedays,null )) as local_olduser_order_info_recent3order_period3maxoverduedays_v2
      ,max(if(rank<=3 and periods=4 and overduedays>0,1,0 )) as local_olduser_order_info_recent3order_period4overdue_v2
      ,max(if(rank<=3 and periods=4 and overduedays>0,overduedays,null )) as local_olduser_order_info_recent3order_period4maxoverduedays_v2
      ,min(if(rank<=3 and overduedays>0,rank,null )) as local_olduser_order_info_recent3order_firstoverduedayrank_v2
      from mid_table
    group by cust_no,use_credit_apply_id,use_create_time,use_credit_apply_date
) as t4 on t1.use_credit_apply_id = t4.use_credit_apply_id
left join (
    select cust_no
          ,use_credit_apply_id
          ,use_create_time
          ,use_credit_apply_date
          ,max(if(overduedays>=0,overduedays,null)) as local_olduser_order_info_payofforder_maxoverduedays_v2
          ,min(if(overduedays>=0,overduedays,null)) as local_olduser_order_info_payofforder_minoverduedays_v2
          ,sum(if(overduedays>=0,overduedays,0)) as local_olduser_order_info_payofforder_sumoverduedays_v2
          ,round(avg(if(overduedays>=0,overduedays,null)),6) as local_olduser_order_info_payofforder_avgoverduedays_v2
          ,max(prepaydays) as local_olduser_order_info_payofforder_maxprepaydays_v2
          ,min(prepaydays) as local_olduser_order_info_payofforder_minprepaydays_v2
          ,sum(prepaydays) as local_olduser_order_info_payofforder_sumprepaydays_v2
          ,round(avg(prepaydays),6) as local_olduser_order_info_payofforder_avgprepaydays_v2
          ,max(if(rank_=1, (unix_timestamp(use_create_time) - unix_timestamp(create_time)),null)) as local_olduser_order_info_recent1payofforder_currentorder_createsecondgap_v2
          ,max(if(rank_=1, datediff(to_date(use_create_time), to_date(create_time)),null)) as local_olduser_order_info_recent1payofforder_currentorder_createdaygap_v2
          ,max(if(rank_=1,use_period - loan_period, null)) as local_olduser_order_info_recent1payofforder_currentorder_periodgap_v2
          ,round(max(if(rank_=1,use_amount/real_loan_amt, null)),6) as local_olduser_order_info_recent1payofforder_currentorder_amountratio_v2
          ,max(if(rank_ =1,cast(substr(create_time,12,2) as bigint),null)) as local_olduser_order_info_recent1payofforder_applyhour_v2
          ,max(if(rank_ =1,cast(substr(use_create_time,12,2) as bigint) -cast(substr(create_time,12,2) as bigint),null)) as local_olduser_order_info_recent1payofforder_currentorder_applyhourgap_v2
          ,max(if(rank_ =1 and (cast(substr(create_time,12,2) as bigint)>=23 or cast(substr(create_time,12,2) as bigint)<5),1,0)) as local_olduser_order_info_recent1payofforder_night_v2
          ,max(if(rank_ =1 and (cast(substr(create_time,12,2) as bigint)>=5 and cast(substr(create_time,12,2) as bigint)<11),1,0)) as local_olduser_order_info_recent1payofforder_morning_v2
          ,max(if(rank_ =1 and (cast(substr(create_time,12,2) as bigint)>=11 and cast(substr(create_time,12,2) as bigint)<13),1,0)) as local_olduser_order_info_recent1payofforder_noon_v2
          ,max(if(rank_ =1 and (cast(substr(create_time,12,2) as bigint)>=13 and cast(substr(create_time,12,2) as bigint)<18),1,0)) as local_olduser_order_info_recent1payofforder_afternoon_v2
          ,max(if(rank_ =1 and (cast(substr(create_time,12,2) as bigint)>=18 and cast(substr(create_time,12,2) as bigint)<23),1,0)) as local_olduser_order_info_recent1payofforder_evening_v2
          ,max(if(rank_ =1 and overduedays>=0,overduedays,null)) as local_olduser_order_info_recent1payofforder_maxoverduedays_v2
          ,min(if(rank_ =1 and overduedays>=0,overduedays,null)) as local_olduser_order_info_recent1payofforder_minoverduedays_v2
          ,sum(if(rank_ =1 and overduedays>=0,overduedays,0)) as local_olduser_order_info_recent1payofforder_sumoverduedays_v2
          ,sum(if(rank_=1 and prepaydays>=0, prepaydays,0)) as local_olduser_order_info_recent1payofforder_sumprepaydays_v2
          ,max(if(rank_=1,prepaydays,null)) as local_olduser_order_info_recent1payofforder_maxprepaydays_v2
          ,min(if(rank_=1,prepaydays,null)) as local_olduser_order_info_recent1payofforder_minprepaydays_v2
          ,count(if(rank_ =1 and overduedays>=0,id,null)) as local_olduser_order_info_recent1payofforder_countidoverduedays_v2
          ,count(if(rank_=1 and prepaydays>0,id,null)) as local_olduser_order_info_recent1payofforder_countidprepaydays_v2
          ,count(if(rank_=1 and settled_time is not null,id,null)) as local_olduser_order_info_recent1payofforder_payperiods_v2
          ,count(if(rank_=1 and to_date(settled_time) = to_date(use_create_time),id,null)) as local_olduser_order_info_recent1payoffordercurrentday_payperiods_v2
          ,max(if(rank_=1 and periods=1,real_loan_amt,null)) as local_olduser_order_info_recent1payofforder_loanamount_v2
          ,count(if(rank_=1 and prepaydays>0, id, null ))/max(if(rank_=1, loan_period, null)) as local_olduser_order_info_recent1payofforder_repayperiods_v2
          ,max(if(rank_=1 and periods=1 and overduedays>0,1,0)) as local_olduser_order_info_recent1payofforder_period1overdue_v2
          ,max(if(rank_=1 and periods=1 and overduedays>0,overduedays,null)) as local_olduser_order_info_recent1payofforder_period1overduedays_v2
          ,max(if(rank_=1 and periods=2 and overduedays>0,1,0)) as local_olduser_order_info_recent1payofforder_period2overdue_v2
          ,max(if(rank_=1 and periods=2 and overduedays>0,overduedays,null)) as local_olduser_order_info_recent1payofforder_period2overduedays_v2
          ,max(if(rank_=1 and periods=3 and overduedays>0,1,0)) as local_olduser_order_info_recent1payofforder_period3overdue_v2
          ,max(if(rank_=1 and periods=3 and overduedays>0,overduedays,null)) as local_olduser_order_info_recent1payofforder_period3overduedays_v2
          ,max(if(rank_=1 and periods=4 and overduedays>0,1,0)) as local_olduser_order_info_recent1payofforder_period4overdue_v2
          ,max(if(rank_=1 and periods=4 and overduedays>0,overduedays,null)) as local_olduser_order_info_recent1payofforder_period4overduedays_v2
    from
    (
    select p1.*
          ,dense_rank()over(partition by p1.cust_no,p1.use_credit_apply_id order by p1.create_time desc) as rank_
    from mid_table as p1
    inner join mid_table_payofftags as p2
    on p1.loan_no = p2.loan_no
    and p1.cust_no = p2.cust_no
    and p1.use_credit_apply_id = p2.use_credit_apply_id
    ) as p3
    group by cust_no,use_credit_apply_id,use_create_time,use_credit_apply_date
) as t5 on t1.use_credit_apply_id = t5.use_credit_apply_id
-- 修改点4：按时间倒序排序
order by t1.use_create_time desc) t order by use_create_time desc;