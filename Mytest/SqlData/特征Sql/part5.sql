with mid as (
    select t1.cust_no, t1.id, t1.use_amount, t2.create_time,
           row_number() over (partition by t1.cust_no, t1.id order by t2.create_time desc) as row_num
    from (
        select cust_no, id, create_time, use_amount
        from hive_idc.oversea.ods_mx_aprv_approve_use_credit_apply_df
        where pt = replace('${bdp.system.bizdate2}','-','')
          and substr(create_time,1,10) > date_sub('${bdp.system.bizdate2}', 60)
    ) as t1
    inner join (
        select cust_no, create_time, update_time, after_available_limit
        from hive_idc.oversea.ods_mx_aprv_cust_credit_limit_record_df 
        where pt = replace('${bdp.system.bizdate2}','-','')
          and is_delete = 0
          and type = 6
    ) as t2 on t1.cust_no = t2.cust_no
    where t1.create_time > t2.create_time
)

select * from (
select 
    t5.cust_no,
    t5.id,
    t5.create_time,
    
    -- ==================== Part 1: 时间与节假日特征 (15个) ====================
    -- 提现时间与未来最近一个【周六日】的间隔天数
    if(dayofweek(t5.create_time) in (1, 7), 0, 7 - dayofweek(t5.create_time)) as local_olduser_withdraw_feature_currentorder_daysbetweenwithdrawandlatestweekend_v2,
    
    -- 提现时间与未来最近一个【元旦】的间隔天数
    datediff(cast(concat(year(t5.create_time) + 1, '-01-01') as date), date(t5.create_time)) as local_olduser_withdraw_feature_currentorder_daysbetweenwithdrawandlatestnewyear_v2,
    
    -- 提现时间与未来最近一个【劳动节】的间隔天数
    case when date(t5.create_time) < concat(year(t5.create_time), '-05-01') 
         then datediff(cast(concat(year(t5.create_time), '-05-01') as date), date(t5.create_time))
         else datediff(cast(concat(year(t5.create_time) + 1, '-05-01') as date), date(t5.create_time)) 
    end as local_olduser_withdraw_feature_currentorder_daysbetweenwithdrawandlatestlabor_v2,
    
    -- 提现时间与未来最近一个【独立日】的间隔天数
    case when date(t5.create_time) < concat(year(t5.create_time), '-09-16') 
         then datediff(cast(concat(year(t5.create_time), '-09-16') as date), date(t5.create_time))
         else datediff(cast(concat(year(t5.create_time) + 1, '-09-16') as date), date(t5.create_time)) 
    end as local_olduser_withdraw_feature_currentorder_daysbetweenwithdrawandlatestindependence_v2,
    
    -- 提现时间与未来最近一个【亡灵节第一天】的间隔天数
    case when date(t5.create_time) < concat(year(t5.create_time), '-11-01') 
         then datediff(cast(concat(year(t5.create_time), '-11-01') as date), date(t5.create_time))
         else datediff(cast(concat(year(t5.create_time) + 1, '-11-01') as date), date(t5.create_time)) 
    end as local_olduser_withdraw_feature_currentorder_daysbetweenwithdrawandlatestdead_v2,
    
    -- 提现时间与未来最近一个【年终奖金日（12月20日）】的间隔天数
    case when date(t5.create_time) < concat(year(t5.create_time), '-12-20') 
         then datediff(cast(concat(year(t5.create_time), '-12-20') as date), date(t5.create_time))
         else datediff(cast(concat(year(t5.create_time) + 1, '-12-20') as date), date(t5.create_time)) 
    end as local_olduser_withdraw_feature_currentorder_daysbetweenwithdrawandlatestbonus_v2,
    
    -- 提现时间与未来最近一个【圣诞节】的间隔天数
    case when date(t5.create_time) < concat(year(t5.create_time), '-12-25') 
         then datediff(cast(concat(year(t5.create_time), '-12-25') as date), date(t5.create_time))
         else datediff(cast(concat(year(t5.create_time) + 1, '-12-25') as date), date(t5.create_time)) 
    end as local_olduser_withdraw_feature_currentorder_daysbetweenwithdrawandlatestchristmas_v2,
    
    -- 提现时间与未来最近一个【发薪日 - 每月15日】的间隔天数
    case when date(t5.create_time) < concat(year(t5.create_time), '-', lpad(month(t5.create_time), 2, '0'), '-15') 
         then datediff(cast(concat(year(t5.create_time), '-', lpad(month(t5.create_time), 2, '0'), '-15') as date), date(t5.create_time))
         when month(t5.create_time) < 12 
         then datediff(cast(concat(year(t5.create_time), '-', lpad(month(t5.create_time) + 1, 2, '0'), '-15') as date), date(t5.create_time)) 
         else datediff(cast(concat(year(t5.create_time) + 1, '-01-15') as date), date(t5.create_time)) 
    end as local_olduser_withdraw_feature_currentorder_daysbetweenwithdrawandlatest15payday_v2,
    
    -- 提现时间与未来最近一个【发薪日 - 每月最后一天】的间隔天数
    case when date(t5.create_time) < last_day(date(t5.create_time)) 
         then datediff(cast(last_day(date(t5.create_time)) as date), date(t5.create_time))
         when month(t5.create_time) < 12 
         then datediff(cast(last_day(date_add(date(t5.create_time), interval 1 month)) as date), date(t5.create_time)) 
         else datediff(cast(last_day(concat(year(t5.create_time) + 1, '-01-01')) as date), date(t5.create_time)) 
    end as local_olduser_withdraw_feature_currentorder_daysbetweenwithdrawandlatest30payday_v2,
    
    -- 当前提现提现时间所在的小时
    hour(t5.create_time) as local_olduser_withdraw_feature_currentorder_hour_v2,
    
    -- 当前提现订单信息_本笔订单下单日期([1-31])
    day(t5.create_time) as local_olduser_withdraw_feature_currentorder_day_v2,
    
    -- 当前提现订单信息_本笔订单期数
    t5.period as local_olduser_withdraw_feature_currentorder_period_v2,
    
    -- 当前提现订单信息_订单本金金额
    t5.use_amount as local_olduser_withdraw_feature_currentorder_useamount_v2,
    
    -- 当前提现订单信息_订单利息率
    t5.interest_rate as local_olduser_withdraw_feature_currentorder_interestrate_v2,
    
    -- 当前提现订单信息_本笔订单还款周期
    t5.loan_days as local_olduser_withdraw_feature_currentorder_loandays_v2,
    
    -- ==================== Part 2: 历史行为间隔特征 (10个) ====================
    -- 提现时间与最近一次授信申请时间的间隔天数
    local_olduser_withdraw_feature_currentorder_daysbetweenlastcreditapplydate_v2,
    -- 提现时间与最远一次授信申请时间的间隔天数
    local_olduser_withdraw_feature_currentorder_daysbetweenfirstcreditapplydate_v2,
    -- 提现时间与最近一次还款时间的间隔天数
    local_olduser_withdraw_feature_currentorder_daysbetweenlastsettletime_v2,
    -- 提现时间与最远一次还款时间的间隔天数
    local_olduser_withdraw_feature_currentorder_daysbetweenfirstsettletime_v2,
    -- 提现时间与最近一次活体检测时间的间隔天数
    local_olduser_withdraw_feature_currentorder_daysbetweenlastlivedetect_v2,
    -- 提现时间与最远一次活体检测时间的间隔天数
    local_olduser_withdraw_feature_currentorder_daysbetweenfirstlivedetect_v2,
    -- 提现时间与最近一次授信申请时间的间隔秒数
    if(max_credit_apply_time is null, null, (unix_timestamp(t5.create_time) - unix_timestamp(max_credit_apply_time))) as local_olduser_withdraw_feature_currentorder_secondsbetweenlastcreditapply_v2,
    -- 提现时间与最近一次还款时间的间隔秒数
    if(max_settletime is null, null, (unix_timestamp(t5.create_time) - unix_timestamp(max_settletime))) as local_olduser_withdraw_feature_currentorder_secondsbetweenlastsettletime_v2,
    -- 提现时间与最近一次活体检测时间的间隔秒数
    if(max_livedetecttime is null, null, (unix_timestamp(t5.create_time) - unix_timestamp(max_livedetecttime))) as local_olduser_withdraw_feature_currentorder_secondsbetweenlastlivedetect_v2,
    -- 提现时间与最近一次提额时间的间隔秒数
    if(increase_time is null, null, (unix_timestamp(t5.create_time) - unix_timestamp(increase_time))) as local_olduser_withdraw_feature_currentorder_secondsbetweenlastincrease_v2

from (
    select 
        t1.cust_no,
        t1.id,
        t1.create_time,
        t1.use_amount,
        t1.period,          -- 新增：Part 1 需要
        t1.interest_rate,   -- 新增：Part 1 需要
        t1.loan_days,       -- 新增：Part 1 需要
        min(if(t2.cust_no is not null and t2.create_time < t1.create_time, datediff(date(t1.create_time), date(t2.create_time)), null)) as local_olduser_withdraw_feature_currentorder_daysbetweenlastcreditapplydate_v2,
        max(if(t2.cust_no is not null and t2.create_time < t1.create_time, datediff(date(t1.create_time), date(t2.create_time)), null)) as local_olduser_withdraw_feature_currentorder_daysbetweenfirstcreditapplydate_v2,
        min(if(t3.cust_no is not null and t3.settled_time < t1.create_time, datediff(date(t1.create_time), date(t3.settled_time)), null)) as local_olduser_withdraw_feature_currentorder_daysbetweenlastsettletime_v2,
        max(if(t3.cust_no is not null and t3.settled_time < t1.create_time, datediff(date(t1.create_time), date(t3.settled_time)), null)) as local_olduser_withdraw_feature_currentorder_daysbetweenfirstsettletime_v2,
        min(if(t4.cust_no is not null and t4.create_time < t1.create_time, datediff(date(t1.create_time), date(t4.create_time)), null)) as local_olduser_withdraw_feature_currentorder_daysbetweenlastlivedetect_v2,
        max(if(t4.cust_no is not null and t4.create_time < t1.create_time, datediff(date(t1.create_time), date(t4.create_time)), null)) as local_olduser_withdraw_feature_currentorder_daysbetweenfirstlivedetect_v2,
        max(if(t2.cust_no is not null and t2.create_time < t1.create_time, t2.create_time, null)) as max_credit_apply_time,
        max(if(t3.cust_no is not null and t3.settled_time < t1.create_time, t3.settled_time, null)) as max_settletime,
        max(if(t4.cust_no is not null and t4.create_time < t1.create_time, t4.create_time, null)) as max_livedetecttime
    from (
        select cust_no, id, create_time, use_amount, period, interest_rate, loan_days  -- 新增字段
        from hive_idc.oversea.ods_mx_aprv_approve_use_credit_apply_df
        where pt = replace('${bdp.system.bizdate2}','-','')
          and substr(create_time,1,10) > date_sub('${bdp.system.bizdate2}', 60)
    ) as t1
    left join (
        select cust_no, create_time
        from hive_idc.oversea.ods_mx_aprv_approve_credit_apply_df
        where pt = replace('${bdp.system.bizdate2}','-','')
    ) as t2 on t1.cust_no = t2.cust_no
    left join (
        select cust_no, create_time, settled_time
        from hive_idc.oversea.ods_mx_ast_asset_repay_plan_df
        where pt = replace('${bdp.system.bizdate2}','-','')
    ) as t3 on t1.cust_no = t3.cust_no
    left join (
        select cust_no, create_time
        from hive_idc.oversea.ods_mx_cust_cust_live_detect_df
        where pt = replace('${bdp.system.bizdate2}','-','')
          and status = 400
    ) as t4 on t1.cust_no = t4.cust_no
    group by t1.cust_no, t1.id, t1.create_time, t1.use_amount, t1.period, t1.interest_rate, t1.loan_days
) as t5
left join (
    select cust_no, id, create_time as increase_time 
    from mid 
    where row_num = 1
) as t6 on t5.cust_no = t6.cust_no and t5.id = t6.id) t where create_time>='2026-01-12 08:33:00' and cust_no='800001259596'order by create_time desc limit 100000;