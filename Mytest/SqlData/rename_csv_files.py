#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
按照表依赖关系重新编号CSV文件
"""

import os
import shutil

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(SCRIPT_DIR, "data")

# 按照依赖关系定义新的编号顺序
# 格式: (旧文件名模式, 新编号, 新文件名)
RENAME_MAP = [
    # 基础表
    ("01账户标签表cust_cust_account_tag.csv", "01", "01_账户标签表_cust_cust_account_tag.csv"),
    
    # 授信流程
    ("03授信申请表aprv_approve_credit_apply.csv", "02", "02_授信申请表_aprv_approve_credit_apply.csv"),
    ("04授信产品表aprv_approve_credit_apply_product.csv", "03", "03_授信产品表_aprv_approve_credit_apply_product.csv"),
    ("规则执行记录表aprv_approve_rule_record.csv", "04", "04_规则执行记录表_aprv_approve_rule_record.csv"),
    ("09额度记录表aprv_cust_credit_limit_record.csv", "05", "05_额度记录表_aprv_cust_credit_limit_record.csv"),
    
    # 用信流程
    ("05用信申请表aprv_approve_use_credit_apply.csv", "06", "06_用信申请表_aprv_approve_use_credit_apply.csv"),
    ("07资产申请进件表ast_asset_loan_apply.csv", "07", "07_资产申请进件表_ast_asset_loan_apply.csv"),
    
    # 放款流程
    ("11借据信息表ast_asset_loan_info.csv", "08", "08_借据信息表_ast_asset_loan_info.csv"),
    ("13三方放款流水表ast_asset_pay_founder_loan_flow.csv", "09", "09_三方放款流水表_ast_asset_pay_founder_loan_flow.csv"),
    ("15还款计划表ast_asset_repay_plan.csv", "10", "10_还款计划表_ast_asset_repay_plan.csv"),
    
    # 辅助表
    ("业务数据存储表增量表allinone_t_kepler_scene_metric_data.csv", "11", "11_业务数据存储表增量表_allinone_t_kepler_scene_metric_data.csv"),
    ("17客户活体认证结果表ods_mx_cust_cust_live_detect_df.csv", "12", "12_客户活体认证结果表_ods_mx_cust_cust_live_detect_df.csv"),
    ("19用户额度表ods_mx_aprv_cust_credit_limit_df.csv", "13", "13_用户额度表_ods_mx_aprv_cust_credit_limit_df.csv"),
    ("19用户额度表ods_mx_aprv_cust_credit_limit_df (1).csv", "13", "13_用户额度表_ods_mx_aprv_cust_credit_limit_df_备份.csv"),
    
    # 汇总表
    ("31授用信借款信息明细表dws_trd_credit_apply_use_loan_df.csv", "14", "14_授用信借款信息明细表_dws_trd_credit_apply_use_loan_df.csv"),
    ("Base表dws_trd_credit_apply_use_loan_df.csv", "14", "14_授用信借款信息明细表_dws_trd_credit_apply_use_loan_df_Base.csv"),
    
    # 其他表（无编号）
    ("客户账号信息表ods_mx_cust_cust_account_info_df.csv", "99", "客户账号信息表_ods_mx_cust_cust_account_info_df.csv"),
]

# 不需要重命名的文件
SKIP_FILES = [
    "base.sql",
    "Untitled",
]


def rename_csv_files():
    """重命名CSV文件"""
    if not os.path.exists(DATA_DIR):
        print(f"数据目录不存在: {DATA_DIR}")
        return
    
    print("="*60)
    print("按依赖关系重新编号CSV文件")
    print("="*60)
    print()
    
    # 记录已处理的文件
    processed = set()
    renamed_count = 0
    
    # 先处理重命名
    for old_name, new_num, new_name in RENAME_MAP:
        old_path = os.path.join(DATA_DIR, old_name)
        new_path = os.path.join(DATA_DIR, new_name)
        
        if not os.path.exists(old_path):
            continue
        
        if old_path in processed:
            continue
        
        # 如果新旧文件名相同，跳过
        if old_name == new_name:
            print(f"✓ 保持不变: {old_name}")
            processed.add(old_path)
            continue
        
        # 如果目标文件已存在且不是同一个文件，添加时间戳
        if os.path.exists(new_path) and old_path != new_path:
            import time
            timestamp = time.strftime("%Y%m%d_%H%M%S")
            base, ext = os.path.splitext(new_name)
            new_name = f"{base}_{timestamp}{ext}"
            new_path = os.path.join(DATA_DIR, new_name)
        
        # 重命名
        try:
            shutil.move(old_path, new_path)
            print(f"✓ {old_name}")
            print(f"  → {new_name}")
            processed.add(old_path)
            renamed_count += 1
        except Exception as e:
            print(f"✗ 重命名失败 {old_name}: {e}")
    
    print()
    print("="*60)
    print(f"完成！共重命名 {renamed_count} 个文件")
    print("="*60)
    print()
    
    # 显示最终的文件列表
    print("最终文件列表（按编号排序）:")
    print("-"*60)
    
    files = sorted([f for f in os.listdir(DATA_DIR) if f.endswith('.csv')])
    for f in files:
        print(f"  {f}")
    
    print()
    
    # 显示其他文件
    other_files = [f for f in os.listdir(DATA_DIR) if not f.endswith('.csv') and not f.startswith('.')]
    if other_files:
        print("其他文件:")
        print("-"*60)
        for f in sorted(other_files):
            print(f"  {f}")
        print()


if __name__ == "__main__":
    rename_csv_files()
