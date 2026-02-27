#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
按照表依赖关系重新编号报告文件
"""

import os
import shutil

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPORT_DIR = os.path.join(SCRIPT_DIR, "reports")

# 按照依赖关系定义新的编号顺序
# 格式: (旧文件名, 新编号, 表名描述)
RENAME_MAP = [
    # 基础表
    ("01_账户标签表分析报告.md", "01", "账户标签表分析报告"),
    
    # 授信流程
    ("02_授信申请表分析报告.md", "02", "授信申请表分析报告"),
    ("授信申请表分析报告.md", "02", "授信申请表分析报告"),  # 重复的
    ("03_授信产品表分析报告.md", "03", "授信产品表分析报告"),
    ("授信产品表分析报告.md", "03", "授信产品表分析报告"),  # 重复的
    ("10_规则执行记录表分析报告.md", "04", "规则执行记录表分析报告"),
    ("09_额度记录表分析报告.md", "05", "额度记录表分析报告"),
    
    # 用信流程
    ("04_用信申请表分析报告.md", "06", "用信申请表分析报告"),
    ("05_资产申请进件表分析报告.md", "07", "资产申请进件表分析报告"),
    
    # 放款流程
    ("06_借据信息表分析报告.md", "08", "借据信息表分析报告"),
    ("07_三方放款流水表分析报告.md", "09", "三方放款流水表分析报告"),
    ("08_还款计划表分析报告.md", "10", "还款计划表分析报告"),
    
    # 辅助表
    ("11_业务数据存储表增量表分析报告.md", "11", "业务数据存储表增量表分析报告"),
    ("17_客户活体认证结果表分析报告.md", "12", "客户活体认证结果表分析报告"),
    ("19_用户额度表分析报告.md", "13", "用户额度表分析报告"),
    
    # 汇总表
    ("31_授用信借款信息明细表分析报告.md", "14", "授用信借款信息明细表分析报告"),
]

# 不需要编号的文件（保持原样）
KEEP_AS_IS = [
    "00_表关联关系总览.md",
    "表关联关系分析报告.txt",
    "数据库表结构汇总.md",
    "数据库表字段汇总.md",
    "所有表综合分析报告.md",
    "所有表综合分析报告.txt",
    "local_midloan_order_info_stat90d_calccreditgapmean_v2特征解析.md",
]


def rename_reports():
    """重命名报告文件"""
    if not os.path.exists(REPORT_DIR):
        print(f"报告目录不存在: {REPORT_DIR}")
        return
    
    print("="*60)
    print("按依赖关系重新编号报告文件")
    print("="*60)
    print()
    
    # 记录已处理的文件
    processed = set()
    renamed_count = 0
    
    # 先处理重命名
    for old_name, new_num, desc in RENAME_MAP:
        old_path = os.path.join(REPORT_DIR, old_name)
        new_name = f"{new_num}_{desc}.md"
        new_path = os.path.join(REPORT_DIR, new_name)
        
        if not os.path.exists(old_path):
            continue
        
        if old_path in processed:
            continue
        
        # 如果新旧文件名相同，跳过
        if old_name == new_name:
            print(f"✓ 保持不变: {old_name}")
            processed.add(old_path)
            continue
        
        # 如果目标文件已存在且不是同一个文件，先删除
        if os.path.exists(new_path) and old_path != new_path:
            print(f"  删除重复文件: {new_name}")
            os.remove(new_path)
        
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
    
    files = sorted([f for f in os.listdir(REPORT_DIR) if f.endswith('.md')])
    for f in files:
        print(f"  {f}")
    
    print()


if __name__ == "__main__":
    rename_reports()
