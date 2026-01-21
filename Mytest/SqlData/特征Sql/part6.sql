with base_data as (
    select
        ua.id as ua_id,                                  -- 用信申请记录ID
        ua.create_time as ua_time,                       -- 用信申请时间（订单创建时间）
        ua.cust_no,                                      -- 客户号
        la.loan_amt,                                     -- 订单金额
        
        li.loan_no,                                      -- 放款订单号
        rp.id as plan_id,                                -- 期次唯一ID
        rp.settled_time,                                 -- 成功还款入账时间（仅成功）
        rp.repaid_principal,                             -- 本次（事件）成功已还本金金额
        rp.principal,                                    -- 当前剩余未还本金金额
        hour(ua.create_time) as created_hour,            -- 订单创建小时（0-23）
        dayofweek(ua.create_time) as created_dow,        -- 订单创建星期（1=周日,7=周六）
        cast(rp.loan_end_date as date) as loan_end_date, -- 期次到期日（DATE）
        rp.create_time as rp_create_time                 -- 期次创建时间（出账/计划生成）
    from fintech.dwd_rsk_approve_use_credit_apply_rt ua
    left join fintech.dwd_rsk_approve_credit_apply_rt ca
      on ca.id = cast(ua.credit_apply_id as string)
      
      
      
    left join fintech.dwd_rsk_asset_loan_apply_rt la
      on la.seq_no = ua.asset_id
    left join fintech.dwd_trd_ast_loan_info_rt li
    
    
      on li.loan_apply_no = la.loan_apply_no and li.loan_status != 4 AND (li.optype <> 'DELETE' OR li.optype IS NULL)
    left join fintech.dwd_trd_ast_repay_plan_rt rp
      on rp.loan_no = li.loan_no and rp.repay_plan_status != 4 AND (rp.optype <> 'DELETE' OR rp.optype IS NULL)
      
      
    where rp.id is not null
      --and timestampdiff(day, cast(rp.loan_end_date as date), cast('2025-12-20' as date)) > 7
      and ua.cust_no in (
        select distinct cust_no
        from fintech.dwd_rsk_approve_use_credit_apply_rt
        where create_time >= '2025-11-01'
      )
),

/* 订单层聚合（只用于拿到每笔订单的创建时间/星期/小时） */
order_agg as (
    select
        bd.cust_no,
        bd.loan_no,
        max(bd.ua_id) as ua_id,
        max(bd.ua_time) as ua_time,           -- 订单创建时间
        max(bd.loan_amt) as loan_amt,         -- 订单金额
        max(bd.created_hour) as created_hour, -- 订单创建小时
        max(bd.created_dow) as created_dow    -- 订单创建星期
    from base_data bd
    group by bd.cust_no, bd.loan_no
),

/* 当前笔：每位客户按 ua_time 取最新一单（作为卡口基准） */
latest_order as (
    select *
    from (
        select
            oa.*,
            row_number() over (partition by oa.cust_no order by oa.ua_time desc) as rn_desc
        from order_agg oa
    ) t
    where t.rn_desc = 1
),

/* 历史订单（不含当前）：供续借/创建小时统计 */
hist_orders as (
    select
        cur.cust_no,
        cur.loan_no        as cur_loan_no,      -- 当前订单号
        cur.ua_time        as cur_ua_time,      -- 当前订单创建时间（卡口时间）
        hist.loan_no       as hist_loan_no,     -- 历史订单号
        hist.ua_time       as hist_ua_time,     -- 历史订单创建时间
        hist.created_hour  as hist_created_hour,-- 历史订单创建小时
        hist.created_dow   as hist_created_dow  -- 历史订单创建星期
    from latest_order cur
    join order_agg hist
      on hist.cust_no = cur.cust_no
     and hist.ua_time < cur.ua_time
),

/* 历史期次聚合（按期次汇总应还/已还-卡口控制） */
hist_plans as (
    select
        h.cust_no,
        h.cur_loan_no,
        h.cur_ua_time,
        h.hist_loan_no,
        b.plan_id,
        max(b.loan_end_date) as plan_due_date,  -- 期次到期日
        max(coalesce(b.repaid_principal,0) + coalesce(b.principal,0)) as plan_due_amt, -- 期次应还（本金口径）
        sum(case when b.settled_time is not null and b.settled_time < h.cur_ua_time
                 then coalesce(b.repaid_principal,0) else 0 end) as plan_paid_by_cutoff -- 截至卡口累计已还
    from hist_orders h
    join base_data b
      on b.cust_no = h.cust_no
     and b.loan_no = h.hist_loan_no
     and b.rp_create_time < h.cur_ua_time
    group by h.cust_no, h.cur_loan_no, h.cur_ua_time, h.hist_loan_no, b.plan_id
),

/* 历史订单“未完成”判断：所有期次未还额之和>0 视为未完成（非逾期概念） */
hist_orders_status as (
    select
        hp.cust_no,
        hp.cur_loan_no,
        hp.cur_ua_time,
        hp.hist_loan_no,
        sum(greatest(hp.plan_due_amt - least(hp.plan_paid_by_cutoff, hp.plan_due_amt), 0)) as loan_outstanding_by_cutoff
    from hist_plans hp
    group by hp.cust_no, hp.cur_loan_no, hp.cur_ua_time, hp.hist_loan_no
),

/* 历史订单合并创建信息与完成状态 */
hist_orders_enriched as (
    select
        h.*,
        case when s.loan_outstanding_by_cutoff > 0 then 1 else 0 end as is_uncompleted -- 1=未完成
    from hist_orders h
    left join hist_orders_status s
      on s.cust_no = h.cust_no
     and s.cur_loan_no = h.cur_loan_no
     and s.cur_ua_time = h.cur_ua_time
     and s.hist_loan_no = h.hist_loan_no
),

/* 60/180 天窗口（未来）：以“当前笔”的自然日为起点，统计 (s0, s60] / (s0, s180] 到期 */
cutoff as (
    select
        lo.cust_no,
        lo.loan_no as cur_loan_no,
        lo.ua_time as cur_ua_time,
        cast(lo.ua_time as date) as s0,                              -- 当天
        date_add(cast(lo.ua_time as date), interval  60 day) as s60, -- 未来60天（含上界）
        date_add(cast(lo.ua_time as date), interval 180 day) as s180  -- 未来180天（含上界）
    from latest_order lo
),

/* 用于快照的期次素材：应还、已还封顶、以及窗口边界 */
snap_plans as (
    select
        hp.cust_no,
        hp.cur_loan_no,
        hp.cur_ua_time,
        hp.plan_due_date,
        hp.plan_due_amt,
        least(hp.plan_paid_by_cutoff, hp.plan_due_amt) as paid_capped,
        c.s0,
        c.s60,
        c.s180
    from hist_plans hp
    join cutoff c
      on c.cust_no = hp.cust_no
     and c.cur_loan_no = hp.cur_loan_no
     and c.cur_ua_time = hp.cur_ua_time
),

/* 60 天“未来窗口”聚合：到期日 ∈ (s0, s60] */
snap_60 as (
    select
        sp.cust_no,
        sp.cur_loan_no,
        sp.cur_ua_time,
        sum(case when sp.plan_due_date > sp.s0 and sp.plan_due_date <= sp.s60 then 1 else 0 end) as instalment_cnt_60,                -- 未来60天内将到期的账单数
        sum(case when sp.plan_due_date > sp.s0 and sp.plan_due_date <= sp.s60 and sp.paid_capped >= sp.plan_due_amt then 1 else 0 end) as instalment_completed_cnt_60,  -- 未来60天到期且已还
        sum(case when sp.plan_due_date > sp.s0 and sp.plan_due_date <= sp.s60 and sp.paid_capped <  sp.plan_due_amt then 1 else 0 end) as instalment_uncompleted_cnt_60,-- 未来60天到期且未还
        sum(case when sp.plan_due_date > sp.s0 and sp.plan_due_date <= sp.s60 then sp.plan_due_amt else 0 end) as total_amt_60,       -- 未来60天内总应还
        sum(case when sp.plan_due_date > sp.s0 and sp.plan_due_date <= sp.s60 then sp.paid_capped  else 0 end) as paid_amt_60         -- 未来60天内总已还（封顶后）
    from snap_plans sp
    group by sp.cust_no, sp.cur_loan_no, sp.cur_ua_time
),

/* 180 天“未来窗口”聚合：到期日 ∈ (s0, s180] */
snap_180 as (
    select
        sp.cust_no,
        sp.cur_loan_no,
        sp.cur_ua_time,
        sum(case when sp.plan_due_date > sp.s0 and sp.plan_due_date <= sp.s180 then 1 else 0 end) as instalment_cnt_180,
        sum(case when sp.plan_due_date > sp.s0 and sp.plan_due_date <= sp.s180 and sp.paid_capped >= sp.plan_due_amt then 1 else 0 end) as instalment_completed_cnt_180,
        sum(case when sp.plan_due_date > sp.s0 and sp.plan_due_date <= sp.s180 and sp.paid_capped <  sp.plan_due_amt then 1 else 0 end) as instalment_uncompleted_cnt_180,
        sum(case when sp.plan_due_date > sp.s0 and sp.plan_due_date <= sp.s180 then sp.plan_due_amt else 0 end) as total_amt_180,
        sum(case when sp.plan_due_date > sp.s0 and sp.plan_due_date <= sp.s180 then sp.paid_capped  else 0 end) as paid_amt_180
    from snap_plans sp
    group by sp.cust_no, sp.cur_loan_no, sp.cur_ua_time
),

/* 历史订单层统计（未完成、星期日计数、创建小时分布）
   续借口径：历史订单数>0 则续借数=历史订单数-1；占比=续借数/历史订单数
*/
hist_orders_agg as (
    select
        h.cust_no,
        h.cur_loan_no,
        h.cur_ua_time,
        count(*) as hist_order_cnt,                                       -- 历史订单数
        sum(case when h.is_uncompleted = 1 then 1 else 0 end) as uncompleted_order_cnt,          -- 未完成订单数（非逾期）
        sum(case when h.is_uncompleted = 1 and h.hist_created_dow = 1 then 1 else 0 end) as uncompletedsundayordercnt, -- 周日未完成订单数
        min(h.hist_created_hour) as min_created_hour,                     -- 最小创建小时
        avg(h.hist_created_hour) as avg_created_hour,                     -- 平均创建小时
        max(h.hist_created_hour) as max_created_hour                      -- 最大创建小时
    from hist_orders_enriched h
    group by h.cust_no, h.cur_loan_no, h.cur_ua_time
)

/* 最终输出（字段名全小写，下划线分隔） */
select * from (
select
    lo.ua_id,
    lo.cust_no,                  -- 客户号
    --lo.loan_no,                  -- 当前订单号
    --lo.ua_time,                  -- 当前订单创建时间（卡口时间）
    concat(lo.ua_time, 'a') as ua_time,                 -- 当前订单创建时间（卡口时间）

    --创建小时三值（历史订单）
    hoa.min_created_hour                                   as local_olduser_uncompleted_mincreatedhour_v2,
    cast(hoa.avg_created_hour as decimal(18,6))           as local_olduser_uncompleted_avgcreatedhour_v2,
    hoa.max_created_hour                                   as local_olduser_uncompleted_maxcreatedhour_v2,

    -- 未完成订单统计（历史订单）
    coalesce(hoa.uncompleted_order_cnt, 0)                as local_olduser_uncompleted_uncompletedordercnt_v2,       -- 历史未完成订单数（非逾期概念）
    coalesce(hoa.uncompletedsundayordercnt, 0)            as local_olduser_uncompleted_uncompletedsundayordercnt_v2, -- 星期日未完成订单数

    -- 续借订单数与占比（历史数>0时：续借数=历史数-1）
    greatest(coalesce(hoa.hist_order_cnt,0) - 1, 0)       as local_olduser_uncompleted_uncompletedmultiordercnt_v2,
    case when hoa.hist_order_cnt is null or hoa.hist_order_cnt = 0 then null
         else cast(round((hoa.hist_order_cnt - 1) / hoa.hist_order_cnt, 6) as decimal(18,6)) end
    as local_olduser_uncompleted_uncompletedmultiorderratio_v2,

    -- 未来60天窗口（到期 ∈ (date(ua_time), date(ua_time)+60]）
    coalesce(s60.instalment_cnt_60, 0)                    as local_olduser_uncompleted_riskvo60d_instalmentcnt_v2,           -- 未来60天将到期的账单数
    coalesce(s60.instalment_completed_cnt_60, 0)          as local_olduser_uncompleted_riskvo60d_instalmentcompletedcnt_v2,   -- 未来60天将到期且已还
    coalesce(s60.instalment_uncompleted_cnt_60, 0)        as local_olduser_uncompleted_riskvo60d_instalmentuncompletedcnt_v2, -- 未来60天将到期且未还
    case when s60.total_amt_60 = 0 then null
         else cast(round(s60.paid_amt_60 / s60.total_amt_60, 6) as decimal(18,6)) end
    as local_olduser_uncompleted_riskvo60d_ratiocompletedandtotalamount_v2,                                               -- 未来60天：已还金额/总应还金额
    case when s60.total_amt_60 = 0 then null
         else cast(round((s60.total_amt_60 - s60.paid_amt_60) / s60.total_amt_60, 6) as decimal(18,6)) end
    as local_olduser_uncompleted_riskvo60d_ratiouncompletedandtotalamount_v2,                                             -- 未来60天：未还金额/总应还金额
    case when s60.instalment_cnt_60 = 0 then null
         else cast(round(s60.instalment_uncompleted_cnt_60 / s60.instalment_cnt_60, 6) as decimal(18,6)) end
    as local_olduser_uncompleted_riskvo60d_ratiouncompletedandtotalcnt_v2,                                                -- 未来60天：未还数/全部数
    case when s60.total_amt_60 = 0 then null
         else cast(round(((s60.total_amt_60 - 2*s60.paid_amt_60) / s60.total_amt_60), 6) as decimal(18,6)) end
    as local_olduser_uncompleted_riskvo60d_diffratiouncompletedandcompletedamount_v2,                                     -- 未来60天：未还比例-已还比例
    case when s60.instalment_completed_cnt_60 = 0 then null
         else cast(round(s60.instalment_uncompleted_cnt_60 / s60.instalment_completed_cnt_60, 6) as decimal(18,6)) end
    as local_olduser_uncompleted_riskvo60d_ratiouncompletedandcompletedcnt_v2,                                            -- 未来60天：未还数/已还数

    -- 未来180天窗口（到期 ∈ (date(ua_time), date(ua_time)+180]）
    coalesce(s180.instalment_cnt_180, 0)                  as local_olduser_uncompleted_riskvo180d_instalmentcnt_v2,
    coalesce(s180.instalment_completed_cnt_180, 0)        as local_olduser_uncompleted_riskvo180d_instalmentcompletedcnt_v2,
    coalesce(s180.instalment_uncompleted_cnt_180, 0)      as local_olduser_uncompleted_riskvo180d_instalmentuncompletedcnt_v2,
    case when s180.total_amt_180 = 0 then null
         else cast(round(s180.paid_amt_180 / s180.total_amt_180, 6) as decimal(18,6)) end
    as local_olduser_uncompleted_riskvo180d_ratiocompletedandtotalamount_v2,
    case when s180.total_amt_180 = 0 then null
         else cast(round((s180.total_amt_180 - s180.paid_amt_180) / s180.total_amt_180, 6) as decimal(18,6)) end
    as local_olduser_uncompleted_riskvo180d_ratiouncompletedandtotalamount_v2,
    case when s180.instalment_cnt_180 = 0 then null
         else cast(round(s180.instalment_uncompleted_cnt_180 / s180.instalment_cnt_180, 6) as decimal(18,6)) end
    as local_olduser_uncompleted_riskvo180d_ratiouncompletedandtotalcnt_v2,
    case when s180.total_amt_180 = 0 then null
         else cast(round(((s180.total_amt_180 - 2*s180.paid_amt_180) / s180.total_amt_180), 6) as decimal(18,6)) end
    as local_olduser_uncompleted_riskvo180d_diffratiouncompletedandcompletedamount_v2,
    case when s180.instalment_completed_cnt_180 = 0 then null
         else cast(round(s180.instalment_uncompleted_cnt_180 / s180.instalment_completed_cnt_180, 6) as decimal(18,6)) end
    as local_olduser_uncompleted_riskvo180d_ratiouncompletedandcompletedcnt_v2

from latest_order lo
left join hist_orders_agg hoa
  on hoa.cust_no = lo.cust_no
 and hoa.cur_loan_no = lo.loan_no
 and hoa.cur_ua_time = lo.ua_time
left join snap_60 s60
  on s60.cust_no = lo.cust_no
 and s60.cur_loan_no = lo.loan_no
 and s60.cur_ua_time = lo.ua_time
left join snap_180 s180
  on s180.cust_no = lo.cust_no
 and s180.cur_loan_no = lo.loan_no
 and s180.cur_ua_time = lo.ua_time) t
 where ua_time>='2026-01-16 05:37:00' order by ua_time desc;
