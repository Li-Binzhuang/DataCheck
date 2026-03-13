#!/usr/bin/env python3
"""
为灰度验证数据添加缺失的列，使其能够在 CDC特征衍生 notebook 中运行
"""
import pandas as pd
import pickle

# 读取灰度验证数据
print("正在读取灰度验证数据...")
df_hd = pd.read_pickle('cdc_hd.pkl')
print(f"原始数据形状: {df_hd.shape}")
print(f"原始列名: {df_hd.columns.tolist()}")

# 将 create_time 重命名为 apply_time（因为 notebook 需要 apply_time）
if 'create_time' in df_hd.columns and 'apply_time' not in df_hd.columns:
    df_hd = df_hd.rename(columns={'create_time': 'apply_time'})
    print("已将 create_time 重命名为 apply_time")

# 添加缺失的业务字段（使用默认值或 -999）
missing_cols = {
    'approve_state': 'UNKNOWN',  # 审批状态未知
    'credit_limit_amount': -999.0,  # 授信额度
    'use_amount': -999.0,  # 使用额度
    'principal_amount_borrowed': -999.0,  # 借款本金
    'fpd7': -999,  # FPD7 标签
    'spd7': -999,  # SPD7 标签
    'credit_apply_cnt': -999,  # 申请次数
    'blind_lend': None  # 盲贷标识
}

for col, default_val in missing_cols.items():
    if col not in df_hd.columns:
        df_hd[col] = default_val
        print(f"已添加列 {col}，默认值: {default_val}")

# 调整列顺序，使其与训练数据一致
expected_cols = [
    'apply_id',
    'response_body',
    'apply_time',
    'approve_state',
    'credit_limit_amount',
    'use_amount',
    'principal_amount_borrowed',
    'fpd7',
    'spd7',
    'credit_apply_cnt',
    'blind_lend'
]

df_hd = df_hd[expected_cols]

print(f"\n处理后数据形状: {df_hd.shape}")
print(f"处理后列名: {df_hd.columns.tolist()}")

# 保存为新的 pkl 文件
output_file = 'cdc_hd_prepared.pkl'
with open(output_file, 'wb') as f:
    pickle.dump(df_hd, f)

print(f"\n✓ 数据已保存为: {output_file}")
print(f"✓ 现在可以在 notebook 中使用此文件进行特征衍生")
print(f"\n提示: 在 notebook 的第一个 cell 中，将 pkl_path 设置为 '{output_file}'")
