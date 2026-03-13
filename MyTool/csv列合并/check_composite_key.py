#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import pandas as pd
import sys
import os

file_path = sys.argv[1] if len(sys.argv) > 1 else 'data/044937d5-696c-4b77-b050-22b218ae6af2-1.csv'

print(f"检查文件: {os.path.basename(file_path)}")
df = pd.read_csv(file_path, low_memory=True)
print(f"总行数: {len(df)}")

required_cols = ['apply_id', 'create_time', 'cust_no']
missing = [c for c in required_cols if c not in df.columns]
if missing:
    print(f"缺少列: {missing}")
    print(f"可用列: {list(df.columns[:10])}")
    sys.exit(1)

# 组合主键
df['key'] = df['apply_id'].astype(str) + '_' + df['create_time'].astype(str) + '_' + df['cust_no'].astype(str)
unique = df['key'].nunique()
dup = len(df) - unique

print(f"唯一组合主键: {unique}")
print(f"重复行数: {dup}")

if dup > 0:
    print(f"\n⚠️ 有 {dup} 行重复!")
    dup_df = df[df['key'].duplicated(keep=False)]
    print("\n重复示例:")
    for i, (k, g) in enumerate(dup_df.groupby('key')):
        if i >= 3:
            break
        print(f"  {i+1}. 出现 {len(g)} 次 - apply_id: {g.iloc[0]['apply_id']}")
else:
    print("✅ 无重复")
