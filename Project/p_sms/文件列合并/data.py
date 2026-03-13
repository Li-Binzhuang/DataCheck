#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
合并 sms_v3 文件夹下的 32 个 CSV 文件
1. 使用 apply_id + cust_no + create_time 作为唯一key进行merge
2. 合并所有特征到一个 CSV 文件
3. 提取前 100 条数据生成测试文件
"""

import pandas as pd
from pathlib import Path

# 定义路径（相对于脚本文件位置）
script_dir = Path(__file__).parent
input_dir = script_dir / "sms_v3/0311"
output_dir = script_dir / "sms_v3_merged"
output_dir.mkdir(parents=True, exist_ok=True)

# 唯一key列
merge_keys = ['cust_no', 'apply_id', 'create_time']
# 所有关键列（不作为特征的列）
key_columns = ['cust_no', 'apply_id', 'create_time', 'user_type', 'rule_type', 'business_type', 'if_reoffer']

# 获取所有 CSV 文件
csv_files = sorted([f for f in input_dir.glob("*.csv")])
print(f"找到 {len(csv_files)} 个 CSV 文件")

# 检查是否找到文件
if len(csv_files) == 0:
    print(f"错误: 在 {input_dir.absolute()} 目录下没有找到 CSV 文件")
    exit(1)

# 读取第一个文件作为基础
print(f"读取基础文件: {csv_files[0].name}")
merged_df = pd.read_csv(csv_files[0])
print(f"  行数: {len(merged_df)}, 列数: {len(merged_df.columns)}")

# 逐个文件用 merge_keys 做 left join
for csv_file in csv_files[1:]:
    print(f"合并: {csv_file.name}")
    df = pd.read_csv(csv_file)
    # 只取 merge_keys + 新特征列
    feature_columns = [col for col in df.columns if col not in key_columns]
    # 过滤掉已存在的列，避免重复
    new_features = [col for col in feature_columns if col not in merged_df.columns]
    if new_features:
        merged_df = merged_df.merge(df[merge_keys + new_features], on=merge_keys, how='left')
        print(f"  新增 {len(new_features)} 列, 当前总列数: {len(merged_df.columns)}")
    else:
        print(f"  无新增列，跳过")

print(f"\n合并后总列数: {len(merged_df.columns)}")
print(f"合并后总行数: {len(merged_df)}")

# 保存合并后的文件
output_file = output_dir / "sms_v3_all_merged_0311_v1.csv"
merged_df.to_csv(output_file, index=False)
print(f"已保存合并文件: {output_file}")


print(f"\n=== 统计信息 ===")
print(f"总特征数: {len(merged_df.columns) - len(key_columns)}")
print(f"合并key: {merge_keys}")
print(f"总样本数: {len(merged_df)}")