PART 1：临时表构建
1. target_user
目的：获取每天发起用信申请的用户样本

create_time：用信申请时间

cust_no：客户编号

用于回溯测试和上线验证

2. target_user_credit_loan_repay_info
目的：整合用户的授信、借款、还款信息

核心字段含义：
字段	含义	计算逻辑
order_asc_rank	在贷订单升序排名	对未结清订单按创建时间升序排序（1为最远一笔）
order_desc_rank	在贷订单降序排名	对未结清订单按创建时间降序排序（1为最近一笔）
is_tqjq	是否提前结清	结清时间 < 用信时间 且 结清日期 < 贷款结束日期
is_tqjq_15d/7d/3d	提前结清时间范围	在提前结清基础上，限制提前天数
is_overdue	是否逾期	贷款结束日期 < 用信日期 且 未结清或结清时间晚于到期日
is_unclear_tag	是否在贷订单	未结清或结清时间 > 用信时间
creditlimit_use_ratio	额度使用率	after_pre_use_limit/(before_available_limit+before_pre_use_limit)
available_limit	剩余可用额度	after_total_limit - after_use_limit
