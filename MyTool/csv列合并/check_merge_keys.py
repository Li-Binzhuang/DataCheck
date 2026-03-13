#!/usr/bin/env python3
import pandas as pd
import sys

files = sys.argv[1:] if len(sys.argv) > 1 else ['data/044937d5-696c-4b77-b050-22b218ae6af2-1.csv', 'data/04824c7a-c0df-4275-8efe-ee068e2d6b52-1.csv']

for f in files[:2]:
    print(f"\n文件: {f}")
    df = pd.read_csv(f, low_memory=True)
    print(f"行数: {len(df)}")
    
    for col in ['apply_id', 'create_time', 'cust_no']:
        if col in df.columns:
            print(f"  {col}: dtype={df[col].dtype}, null={df[col].isna().sum()}, 示例={df[col].iloc[0]}")
        else:
            print(f"  {col}: 不存在")

# 测试合并
print("\n" + "="*60)
print("测试合并:")
df1 = pd.read_csv(files[0], low_memory=True)
df2 = pd.read_csv(files[1], low_memory=True)

merge_keys = ['apply_id', 'create_time', 'cust_no']
print(f"文件1: {len(df1)} 行")
print(f"文件2: {len(df2)} 行")

result = df1.merge(df2, on=merge_keys, how='inner', suffixes=('', '_dup'))
print(f"合并后: {len(result)} 行")

if len(result) > len(df1):
    print(f"⚠️ 行数增加了 {len(result) - len(df1)} 行!")
    print("\n检查是否有重复匹配...")
    
    # 检查哪些键匹配了多次
    df1['key'] = df1['apply_id'].astype(str) + '_' + df1['create_time'].astype(str) + '_' + df1['cust_no'].astype(str)
    df2['key'] = df2['apply_id'].astype(str) + '_' + df2['create_time'].astype(str) + '_' + df2['cust_no'].astype(str)
    
    common_keys = set(df1['key']) & set(df2['key'])
    print(f"共同的组合键数量: {len(common_keys)}")
    
    # 检查是否有 NULL 值导致的问题
    for col in merge_keys:
        null1 = df1[col].isna().sum()
        null2 = df2[col].isna().sum()
        if null1 > 0 or null2 > 0:
            print(f"  {col}: 文件1有{null1}个NULL, 文件2有{null2}个NULL")
