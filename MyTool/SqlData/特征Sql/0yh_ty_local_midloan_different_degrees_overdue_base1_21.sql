-- show create table hello_da.midloan_repayment_settlement_feature_123;
-- DROP TABLE IF EXISTS hello_da.midloan_repayment_settlement_feature_123;
-- DROP TABLE hello_da.midloan_repayment_settlement_feature_123;
-- CREATE TABLE IF NOT EXISTS hello_da.midloan_repayment_settlement_feature_123(
--     `ua_id` BIGINT,
--     `cust_no` STRING,
--     `ua_time` STRING,
--     `ua_date` DATE,
--     `principal_uatime_add_7d_no_settled` DECIMAL(38,8) ,
--     `principal_uatime_add_15d_no_settled` DECIMAL(38,8) ,
--     `principal_uatime_add_30d_no_settled` DECIMAL(38,8) ,
--     `principal_uatime_add_45d_no_settled` DECIMAL(38,8) ,
--     `principal_uatime_add_7d` DECIMAL(38,8),
--     `principal_uatime_add_15d` DECIMAL(38,8),
--     `principal_uatime_add_30d` DECIMAL(38,8),
--     `principal_uatime_add_45d` DECIMAL(38,8),
--     `last_7d_total_cnt` BIGINT,
--     `last_7d_overdue_0d_cnt` BIGINT,
--     `last_7d_overdue_1d_cnt` BIGINT,
--     `last_7d_overdue_2d_cnt` BIGINT,
--     `last_7d_overdue_3d_cnt` BIGINT,
--     `last_7d_overdue_cnt` BIGINT,
--     `last_15d_total_cnt` BIGINT,
--     `last_15d_overdue_0d_cnt` BIGINT,
--     `last_15d_overdue_1d_cnt` BIGINT,
--     `last_15d_overdue_2d_cnt` BIGINT,
--     `last_15d_overdue_3d_cnt` BIGINT,
--     `last_15d_overdue_cnt` BIGINT,
--     `last_30d_total_cnt` BIGINT,
--     `last_30d_overdue_0d_cnt` BIGINT,
--     `last_30d_overdue_1d_cnt` BIGINT,
--     `last_30d_overdue_2d_cnt` BIGINT,
--     `last_30d_overdue_3d_cnt` BIGINT,
--     `last_30d_overdue_cnt` BIGINT,
--     `last_45d_total_cnt` BIGINT,
--     `last_45d_overdue_0d_cnt` BIGINT,
--     `last_45d_overdue_1d_cnt` BIGINT,
--     `last_45d_overdue_2d_cnt` BIGINT,
--     `last_45d_overdue_3d_cnt` BIGINT,
--     `last_45d_overdue_cnt` BIGINT,
--     `last_60d_total_cnt` BIGINT,
--     `last_60d_overdue_0d_cnt` BIGINT,
--     `last_60d_overdue_1d_cnt` BIGINT,
--     `last_60d_overdue_2d_cnt` BIGINT,
--     `last_60d_overdue_3d_cnt` BIGINT,
--     `last_60d_overdue_cnt` BIGINT,
--     `last_75d_total_cnt` BIGINT,
--     `last_75d_overdue_0d_cnt` BIGINT,
--     `last_75d_overdue_1d_cnt` BIGINT,
--     `last_75d_overdue_2d_cnt` BIGINT,
--     `last_75d_overdue_3d_cnt` BIGINT,
--     `last_75d_overdue_cnt` BIGINT,
--     `last_90d_total_cnt` BIGINT,
--     `last_90d_overdue_0d_cnt` BIGINT,
--     `last_90d_overdue_1d_cnt` BIGINT,
--     `last_90d_overdue_2d_cnt` BIGINT,
--     `last_90d_overdue_3d_cnt` BIGINT,
--     `last_90d_overdue_cnt` BIGINT,
--     `last_180d_total_cnt` BIGINT,
--     `last_180d_overdue_0d_cnt` BIGINT,
--     `last_180d_overdue_1d_cnt` BIGINT,
--     `last_180d_overdue_2d_cnt` BIGINT,
--     `last_180d_overdue_3d_cnt` BIGINT,
--     `last_180d_overdue_cnt` BIGINT,
--     `last_7d_overdue_0d_ratio` DOUBLE,
--     `last_7d_overdue_1d_ratio` DOUBLE,
--     `last_7d_overdue_2d_ratio` DOUBLE,
--     `last_7d_overdue_3d_ratio` DOUBLE,
--     `last_7d_overdue_ratio` DOUBLE,
--     `last_15d_overdue_0d_ratio` DOUBLE,
--     `last_15d_overdue_1d_ratio` DOUBLE,
--     `last_15d_overdue_2d_ratio` DOUBLE,
--     `last_15d_overdue_3d_ratio` DOUBLE,
--     `last_15d_overdue_ratio` DOUBLE,
--     `last_30d_overdue_0d_ratio` DOUBLE,
--     `last_30d_overdue_1d_ratio` DOUBLE,
--     `last_30d_overdue_2d_ratio` DOUBLE,
--     `last_30d_overdue_3d_ratio` DOUBLE,
--     `last_30d_overdue_ratio` DOUBLE,
--     `last_45d_overdue_0d_ratio` DOUBLE,
--     `last_45d_overdue_1d_ratio` DOUBLE,
--     `last_45d_overdue_2d_ratio` DOUBLE,
--     `last_45d_overdue_3d_ratio` DOUBLE,
--     `last_45d_overdue_ratio` DOUBLE,
--     `last_60d_overdue_0d_ratio` DOUBLE,
--     `last_60d_overdue_1d_ratio` DOUBLE,
--     `last_60d_overdue_2d_ratio` DOUBLE,
--     `last_60d_overdue_3d_ratio` DOUBLE,
--     `last_60d_overdue_ratio` DOUBLE,
--     `last_75d_overdue_0d_ratio` DOUBLE,
--     `last_75d_overdue_1d_ratio` DOUBLE,
--     `last_75d_overdue_2d_ratio` DOUBLE,
--     `last_75d_overdue_3d_ratio` DOUBLE,
--     `last_75d_overdue_ratio` DOUBLE,
--     `last_90d_overdue_0d_ratio` DOUBLE,
--     `last_90d_overdue_1d_ratio` DOUBLE,
--     `last_90d_overdue_2d_ratio` DOUBLE,
--     `last_90d_overdue_3d_ratio` DOUBLE,
--     `last_90d_overdue_ratio` DOUBLE,
--     `last_180d_overdue_0d_ratio` DOUBLE,
--     `last_180d_overdue_1d_ratio` DOUBLE,
--     `last_180d_overdue_2d_ratio` DOUBLE,
--     `last_180d_overdue_3d_ratio` DOUBLE,
--     `last_180d_overdue_ratio` DOUBLE
--  )partitioned by (pt string comment '未还金额以及结清相关贷中特征')
-- stored as orc lifecycle 365;

insert overwrite table hello_da.midloan_repayment_settlement_feature_123
partition (pt = '${bdp.system.bizdate2}')
SELECT
        ua_id,
        cust_no,
        ua_time,
        ua_date,
        --*** """NAME1""" ***--
        principal_uatime_add_7d_no_settled,
        principal_uatime_add_15d_no_settled,
        principal_uatime_add_30d_no_settled,
        principal_uatime_add_45d_no_settled,
        principal_uatime_add_7d,
        principal_uatime_add_15d,
        principal_uatime_add_30d,
        principal_uatime_add_45d,
        --*** """NAME2""" ***--
        last_7d_total_cnt,
        last_7d_overdue_0d_cnt,
        last_7d_overdue_1d_cnt,
        last_7d_overdue_2d_cnt,
        last_7d_overdue_3d_cnt,
        last_7d_overdue_cnt,
        last_15d_total_cnt,
        last_15d_overdue_0d_cnt,
        last_15d_overdue_1d_cnt,
        last_15d_overdue_2d_cnt,
        last_15d_overdue_3d_cnt,
        last_15d_overdue_cnt,
        last_30d_total_cnt,
        last_30d_overdue_0d_cnt,
        last_30d_overdue_1d_cnt,
        last_30d_overdue_2d_cnt,
        last_30d_overdue_3d_cnt,
        last_30d_overdue_cnt,
        last_45d_total_cnt,
        last_45d_overdue_0d_cnt,
        last_45d_overdue_1d_cnt,
        last_45d_overdue_2d_cnt,
        last_45d_overdue_3d_cnt,
        last_45d_overdue_cnt,
        last_60d_total_cnt,
        last_60d_overdue_0d_cnt,
        last_60d_overdue_1d_cnt,
        last_60d_overdue_2d_cnt,
        last_60d_overdue_3d_cnt,
        last_60d_overdue_cnt,
        last_75d_total_cnt,
        last_75d_overdue_0d_cnt,
        last_75d_overdue_1d_cnt,
        last_75d_overdue_2d_cnt,
        last_75d_overdue_3d_cnt,
        last_75d_overdue_cnt,
        last_90d_total_cnt,
        last_90d_overdue_0d_cnt,
        last_90d_overdue_1d_cnt,
        last_90d_overdue_2d_cnt,
        last_90d_overdue_3d_cnt,
        last_90d_overdue_cnt,
        last_180d_total_cnt,
        last_180d_overdue_0d_cnt,
        last_180d_overdue_1d_cnt,
        last_180d_overdue_2d_cnt,
        last_180d_overdue_3d_cnt,
        last_180d_overdue_cnt,
        -- *** """NAME3:最近{window}天逾期{days}天内结清占比,最近{window}天总逾期结清占比最近{window}天总结清比例"""
        -- 7天窗口占比特征
        CASE WHEN last_7d_total_cnt>0 THEN ROUND(last_7d_overdue_0d_cnt/last_7d_total_cnt,4) ELSE 0 END AS last_7d_overdue_0d_ratio,
        CASE WHEN last_7d_total_cnt>0 THEN ROUND(last_7d_overdue_1d_cnt/last_7d_total_cnt,4) ELSE 0 END AS last_7d_overdue_1d_ratio,
        CASE WHEN last_7d_total_cnt>0 THEN ROUND(last_7d_overdue_2d_cnt/last_7d_total_cnt,4) ELSE 0 END AS last_7d_overdue_2d_ratio,
        CASE WHEN last_7d_total_cnt>0 THEN ROUND(last_7d_overdue_3d_cnt/last_7d_total_cnt,4) ELSE 0 END AS last_7d_overdue_3d_ratio,
        CASE WHEN last_7d_total_cnt>0 THEN ROUND(last_7d_overdue_cnt/last_7d_total_cnt,4) ELSE 0 END AS last_7d_overdue_ratio,
        -- 15天窗口占比特征
        CASE WHEN last_15d_total_cnt>0 THEN ROUND(last_15d_overdue_0d_cnt/last_15d_total_cnt,4) ELSE 0 END AS last_15d_overdue_0d_ratio,
        CASE WHEN last_15d_total_cnt>0 THEN ROUND(last_15d_overdue_1d_cnt/last_15d_total_cnt,4) ELSE 0 END AS last_15d_overdue_1d_ratio,
        CASE WHEN last_15d_total_cnt>0 THEN ROUND(last_15d_overdue_2d_cnt/last_15d_total_cnt,4) ELSE 0 END AS last_15d_overdue_2d_ratio,
        CASE WHEN last_15d_total_cnt>0 THEN ROUND(last_15d_overdue_3d_cnt/last_15d_total_cnt,4) ELSE 0 END AS last_15d_overdue_3d_ratio,
        CASE WHEN last_15d_total_cnt>0 THEN ROUND(last_15d_overdue_cnt/last_15d_total_cnt,4) ELSE 0 END AS last_15d_overdue_ratio,
        -- 30天窗口占比特征
        CASE WHEN last_30d_total_cnt>0 THEN ROUND(last_30d_overdue_0d_cnt/last_30d_total_cnt,4) ELSE 0 END AS last_30d_overdue_0d_ratio,
        CASE WHEN last_30d_total_cnt>0 THEN ROUND(last_30d_overdue_1d_cnt/last_30d_total_cnt,4) ELSE 0 END AS last_30d_overdue_1d_ratio,
        CASE WHEN last_30d_total_cnt>0 THEN ROUND(last_30d_overdue_2d_cnt/last_30d_total_cnt,4) ELSE 0 END AS last_30d_overdue_2d_ratio,
        CASE WHEN last_30d_total_cnt>0 THEN ROUND(last_30d_overdue_3d_cnt/last_30d_total_cnt,4) ELSE 0 END AS last_30d_overdue_3d_ratio,
        CASE WHEN last_30d_total_cnt>0 THEN ROUND(last_30d_overdue_cnt/last_30d_total_cnt,4) ELSE 0 END AS last_30d_overdue_ratio,
        -- 45天窗口占比特征
        CASE WHEN last_45d_total_cnt>0 THEN ROUND(last_45d_overdue_0d_cnt/last_45d_total_cnt,4) ELSE 0 END AS last_45d_overdue_0d_ratio,
        CASE WHEN last_45d_total_cnt>0 THEN ROUND(last_45d_overdue_1d_cnt/last_45d_total_cnt,4) ELSE 0 END AS last_45d_overdue_1d_ratio,
        CASE WHEN last_45d_total_cnt>0 THEN ROUND(last_45d_overdue_2d_cnt/last_45d_total_cnt,4) ELSE 0 END AS last_45d_overdue_2d_ratio,
        CASE WHEN last_45d_total_cnt>0 THEN ROUND(last_45d_overdue_3d_cnt/last_45d_total_cnt,4) ELSE 0 END AS last_45d_overdue_3d_ratio,
        CASE WHEN last_45d_total_cnt>0 THEN ROUND(last_45d_overdue_cnt/last_45d_total_cnt,4) ELSE 0 END AS last_45d_overdue_ratio,	
        -- 60天窗口占比特征
        CASE WHEN last_60d_total_cnt>0 THEN ROUND(last_60d_overdue_0d_cnt/last_60d_total_cnt,4) ELSE 0 END AS last_60d_overdue_0d_ratio,
        CASE WHEN last_60d_total_cnt>0 THEN ROUND(last_60d_overdue_1d_cnt/last_60d_total_cnt,4) ELSE 0 END AS last_60d_overdue_1d_ratio,
        CASE WHEN last_60d_total_cnt>0 THEN ROUND(last_60d_overdue_2d_cnt/last_60d_total_cnt,4) ELSE 0 END AS last_60d_overdue_2d_ratio,
        CASE WHEN last_60d_total_cnt>0 THEN ROUND(last_60d_overdue_3d_cnt/last_60d_total_cnt,4) ELSE 0 END AS last_60d_overdue_3d_ratio,
        CASE WHEN last_60d_total_cnt>0 THEN ROUND(last_60d_overdue_cnt/last_60d_total_cnt,4) ELSE 0 END AS last_60d_overdue_ratio,
        -- 75天窗口占比特征
        CASE WHEN last_75d_total_cnt>0 THEN ROUND(last_75d_overdue_0d_cnt/last_75d_total_cnt,4) ELSE 0 END AS last_75d_overdue_0d_ratio,
        CASE WHEN last_75d_total_cnt>0 THEN ROUND(last_75d_overdue_1d_cnt/last_75d_total_cnt,4) ELSE 0 END AS last_75d_overdue_1d_ratio,
        CASE WHEN last_75d_total_cnt>0 THEN ROUND(last_75d_overdue_2d_cnt/last_75d_total_cnt,4) ELSE 0 END AS last_75d_overdue_2d_ratio,
        CASE WHEN last_75d_total_cnt>0 THEN ROUND(last_75d_overdue_3d_cnt/last_75d_total_cnt,4) ELSE 0 END AS last_75d_overdue_3d_ratio,
        CASE WHEN last_75d_total_cnt>0 THEN ROUND(last_75d_overdue_cnt/last_75d_total_cnt,4) ELSE 0 END AS last_75d_overdue_ratio,	
        -- 90天窗口占比特征
        CASE WHEN last_90d_total_cnt>0 THEN ROUND(last_90d_overdue_0d_cnt/last_90d_total_cnt,4) ELSE 0 END AS last_90d_overdue_0d_ratio,
        CASE WHEN last_90d_total_cnt>0 THEN ROUND(last_90d_overdue_1d_cnt/last_90d_total_cnt,4) ELSE 0 END AS last_90d_overdue_1d_ratio,
        CASE WHEN last_90d_total_cnt>0 THEN ROUND(last_90d_overdue_2d_cnt/last_90d_total_cnt,4) ELSE 0 END AS last_90d_overdue_2d_ratio,
        CASE WHEN last_90d_total_cnt>0 THEN ROUND(last_90d_overdue_3d_cnt/last_90d_total_cnt,4) ELSE 0 END AS last_90d_overdue_3d_ratio,
        CASE WHEN last_90d_total_cnt>0 THEN ROUND(last_90d_overdue_cnt/last_90d_total_cnt,4) ELSE 0 END AS last_90d_overdue_ratio,
        -- 180天窗口占比特征
        CASE WHEN last_180d_total_cnt>0 THEN ROUND(last_180d_overdue_0d_cnt/last_180d_total_cnt,4) ELSE 0 END AS last_180d_overdue_0d_ratio,
        CASE WHEN last_180d_total_cnt>0 THEN ROUND(last_180d_overdue_1d_cnt/last_180d_total_cnt,4) ELSE 0 END AS last_180d_overdue_1d_ratio,
        CASE WHEN last_180d_total_cnt>0 THEN ROUND(last_180d_overdue_2d_cnt/last_180d_total_cnt,4) ELSE 0 END AS last_180d_overdue_2d_ratio,
        CASE WHEN last_180d_total_cnt>0 THEN ROUND(last_180d_overdue_3d_cnt/last_180d_total_cnt,4) ELSE 0 END AS last_180d_overdue_3d_ratio,
        CASE WHEN last_180d_total_cnt>0 THEN ROUND(last_180d_overdue_cnt/last_180d_total_cnt,4) ELSE 0 END AS last_180d_overdue_ratio

from (
    SELECT 
        kb.ua_id,
        kb.cust_no,
        kb.ua_time,
        kb.ua_date,
        --*** """NAME1:近N天应还总额principal_uatime_add_{day}d_no_settled，计算用信节点时间往后推的应该要还的本金"""
        SUM(CASE 
            WHEN rp.create_time < kb.ua_time 
                 AND DATEDIFF(rp.loan_end_date, kb.ua_date) BETWEEN 1 AND 7 --在0到7天内，不包含0天和包含7天
            THEN (rp.principal + rp.repaid_principal)
            ELSE 0 
        END) as principal_uatime_add_7d_no_settled,
        
        SUM(CASE 
            WHEN rp.create_time < kb.ua_time 
                 AND DATEDIFF(rp.loan_end_date, kb.ua_date) BETWEEN 1 AND 15 --在1到15天内
            THEN (rp.principal + rp.repaid_principal) 
            ELSE 0 
        END) as principal_uatime_add_15d_no_settled,
        
        SUM(CASE 
            WHEN rp.create_time < kb.ua_time 
                 AND DATEDIFF(rp.loan_end_date, kb.ua_date) BETWEEN 1 AND 30 --在1到30天内
            THEN (rp.principal + rp.repaid_principal) 
            ELSE 0 
        END) as principal_uatime_add_30d_no_settled,
        
        SUM(CASE 
            WHEN rp.create_time < kb.ua_time 
                 AND DATEDIFF(rp.loan_end_date, kb.ua_date) BETWEEN 1 AND 45 --在1到45天内
            THEN (rp.principal + rp.repaid_principal) 
            ELSE 0 
        END) as principal_uatime_add_45d_no_settled,
        -- *** """NAME1_1:近N天应还总额principal_uatime_add_{day}d，计算用信节点时间往后推的待还本金,提前结清就不计算在内了，主要是用于bcard_v3"""
        SUM(CASE 
            WHEN rp.create_time < kb.ua_time 
                 AND (rp.settled_time >= kb.ua_time OR rp.settled_time IS NULL)
                 AND DATEDIFF(rp.loan_end_date, kb.ua_date) <= 7 
            THEN (rp.principal + rp.repaid_principal)
            ELSE 0 
        END) as principal_uatime_add_7d,

        SUM(CASE 
            WHEN rp.create_time < kb.ua_time 
                 AND (rp.settled_time >= kb.ua_time OR rp.settled_time IS NULL)
                 AND DATEDIFF(rp.loan_end_date, kb.ua_date) <= 15 
            THEN (rp.principal + rp.repaid_principal)
            ELSE 0 
        END) as principal_uatime_add_15d,

        SUM(CASE 
            WHEN rp.create_time < kb.ua_time 
                 AND (rp.settled_time >= kb.ua_time OR rp.settled_time IS NULL)
                 AND DATEDIFF(rp.loan_end_date, kb.ua_date) <= 30 
            THEN (rp.principal + rp.repaid_principal)
            ELSE 0 
        END) as principal_uatime_add_30d,

        SUM(CASE 
            WHEN rp.create_time < kb.ua_time 
                 AND (rp.settled_time >= kb.ua_time OR rp.settled_time IS NULL)
                 AND DATEDIFF(rp.loan_end_date, kb.ua_date) <= 45 
            THEN (rp.principal + rp.repaid_principal)
            ELSE 0 
        END) as principal_uatime_add_45d,

        -- *** """NAME2:最近{窗口}天总结清次数(总结清次数/到期的期数), 最近{window}天逾期{days}天内结清次数""" 
        -- 7天窗口的特征
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 7) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date THEN 1 END) AS last_7d_total_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 7) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) = 0 THEN 1 END) AS last_7d_overdue_0d_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 7) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) > 0 AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) <= 1 THEN 1 END) AS last_7d_overdue_1d_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 7) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) > 0 AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) <= 2 THEN 1 END) AS last_7d_overdue_2d_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 7) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) > 0 AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) <= 3 THEN 1 END) AS last_7d_overdue_3d_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 7) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) > 0 THEN 1 END) AS last_7d_overdue_cnt,
        -- 15天窗口的特征
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 15) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date THEN 1 END) AS last_15d_total_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 15) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) = 0 THEN 1 END) AS last_15d_overdue_0d_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 15) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) > 0 AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) <= 1 THEN 1 END) AS last_15d_overdue_1d_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 15) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) > 0 AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) <= 2 THEN 1 END) AS last_15d_overdue_2d_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 15) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) > 0 AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) <= 3 THEN 1 END) AS last_15d_overdue_3d_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 15) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) > 0 THEN 1 END) AS last_15d_overdue_cnt,
        -- 30天窗口的特征
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 30) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date THEN 1 END) AS last_30d_total_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 30) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) = 0 THEN 1 END) AS last_30d_overdue_0d_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 30) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) > 0 AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) <= 1 THEN 1 END) AS last_30d_overdue_1d_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 30) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) > 0 AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) <= 2 THEN 1 END) AS last_30d_overdue_2d_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 30) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) > 0 AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) <= 3 THEN 1 END) AS last_30d_overdue_3d_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 30) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) > 0 THEN 1 END) AS last_30d_overdue_cnt,
        -- 45天窗口的特征
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 45) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date THEN 1 END) AS last_45d_total_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 45) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) = 0 THEN 1 END) AS last_45d_overdue_0d_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 45) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) > 0 AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) <= 1 THEN 1 END) AS last_45d_overdue_1d_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 45) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) > 0 AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) <= 2 THEN 1 END) AS last_45d_overdue_2d_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 45) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) > 0 AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) <= 3 THEN 1 END) AS last_45d_overdue_3d_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 45) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) > 0 THEN 1 END) AS last_45d_overdue_cnt,
        -- 60天窗口的特征
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 60) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date THEN 1 END) AS last_60d_total_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 60) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) = 0 THEN 1 END) AS last_60d_overdue_0d_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 60) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) > 0 AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) <= 1 THEN 1 END) AS last_60d_overdue_1d_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 60) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) > 0 AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) <= 2 THEN 1 END) AS last_60d_overdue_2d_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 60) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) > 0 AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) <= 3 THEN 1 END) AS last_60d_overdue_3d_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 60) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) > 0 THEN 1 END) AS last_60d_overdue_cnt,
        -- 75天窗口的特征
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 75) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date THEN 1 END) AS last_75d_total_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 75) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) = 0 THEN 1 END) AS last_75d_overdue_0d_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 75) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) > 0 AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) <= 1 THEN 1 END) AS last_75d_overdue_1d_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 75) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) > 0 AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) <= 2 THEN 1 END) AS last_75d_overdue_2d_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 75) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) > 0 AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) <= 3 THEN 1 END) AS last_75d_overdue_3d_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 75) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) > 0 THEN 1 END) AS last_75d_overdue_cnt,
        -- 90天窗口的特征
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 90) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date THEN 1 END) AS last_90d_total_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 90) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) = 0 THEN 1 END) AS last_90d_overdue_0d_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 90) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) > 0 AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) <= 1 THEN 1 END) AS last_90d_overdue_1d_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 90) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) > 0 AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) <= 2 THEN 1 END) AS last_90d_overdue_2d_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 90) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) > 0 AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) <= 3 THEN 1 END) AS last_90d_overdue_3d_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 90) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) > 0 THEN 1 END) AS last_90d_overdue_cnt,
        -- 180天窗口的特征
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 180) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date THEN 1 END) AS last_180d_total_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 180) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) = 0 THEN 1 END) AS last_180d_overdue_0d_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 180) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) > 0 AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) <= 1 THEN 1 END) AS last_180d_overdue_1d_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 180) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) > 0 AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) <= 2 THEN 1 END) AS last_180d_overdue_2d_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 180) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) > 0 AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) <= 3 THEN 1 END) AS last_180d_overdue_3d_cnt,
        COUNT(CASE WHEN rp.settled_time >= date_sub(kb.ua_time, 180) AND rp.settled_time < kb.ua_time AND rp.create_time < kb.ua_time AND rp.loan_end_date <= kb.ua_date AND DATEDIFF(date(rp.settled_time), rp.loan_end_date) > 0 THEN 1 END) AS last_180d_overdue_cnt

    FROM (SELECT DISTINCT
        ua_id,
        cust_no,
        ua_time,
        TO_DATE(ua_time) as ua_date
        FROM hello_da.dty_kb_features_hive where pt = '${bdp.system.bizdate2}') kb
    LEFT JOIN (SELECT * FROM hello_prd.ods_mx_ast_asset_repay_plan_df where pt = '${bdp.system.bizdate2}' and repay_plan_status != 4) rp 
        ON kb.cust_no = rp.cust_no
    GROUP BY kb.ua_id, kb.cust_no, kb.ua_time, kb.ua_date) total;