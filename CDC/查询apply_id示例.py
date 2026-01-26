#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
查询 apply_id 的正确写法示例
"""

import pandas as pd

# 读取数据
print("正在读取数据...")
df_raw = pd.read_pickle('cdc_pickle_pass_fpd7.pkl')

# 检查 apply_id 的数据类型
print("\n" + "="*70)
print("数据类型检查")
print("="*70)
print(f"apply_id 数据类型: {df_raw['apply_id'].dtype}")
print(f"apply_id 示例值: {df_raw['apply_id'].iloc[0]}")
print(f"apply_id 示例值类型: {type(df_raw['apply_id'].iloc[0])}")

# 问题说明
print("\n" + "="*70)
print("问题说明")
print("="*70)
print("❌ 错误写法:")
print("   df_raw[df_raw['apply_id']=='1065991091661283329']")
print("   问题: apply_id 是整数类型，但用字符串查询")
print("   结果: 返回空 DataFrame")

# 错误写法演示
result_wrong = df_raw[df_raw['apply_id']=='1065991091661283329'][['apply_id','apply_time','response_body']]
print(f"\n   实际结果行数: {len(result_wrong)}")

# 正确写法
print("\n" + "="*70)
print("正确写法")
print("="*70)

# 方法1：直接使用整数
print("\n✅ 方法1：直接使用整数（推荐）")
print("   df_raw[df_raw['apply_id']==1065991091661283329]")
result1 = df_raw[df_raw['apply_id']==1065991091661283329][['apply_id','apply_time','response_body']]
print(f"   结果行数: {len(result1)}")
if len(result1) > 0:
    print(f"   apply_id: {result1['apply_id'].iloc[0]}")
    print(f"   apply_time: {result1['apply_time'].iloc[0]}")
    print(f"   response_body 长度: {len(str(result1['response_body'].iloc[0]))} 字符")

# 方法2：字符串转整数
print("\n✅ 方法2：字符串转整数")
print("   df_raw[df_raw['apply_id']==int('1065991091661283329')]")
result2 = df_raw[df_raw['apply_id']==int('1065991091661283329')][['apply_id','apply_time','response_body']]
print(f"   结果行数: {len(result2)}")

# 方法3：使用 isin（适合查询多个 ID）
print("\n✅ 方法3：使用 isin（适合查询多个 ID）")
print("   df_raw[df_raw['apply_id'].isin([1065991091661283329])]")
result3 = df_raw[df_raw['apply_id'].isin([1065991091661283329])][['apply_id','apply_time','response_body']]
print(f"   结果行数: {len(result3)}")

# 方法4：使用 query（更简洁）
print("\n✅ 方法4：使用 query（更简洁）")
print("   df_raw.query('apply_id == 1065991091661283329')")
result4 = df_raw.query('apply_id == 1065991091661283329')[['apply_id','apply_time','response_body']]
print(f"   结果行数: {len(result4)}")

# 查询多个 ID 的示例
print("\n" + "="*70)
print("查询多个 ID 的示例")
print("="*70)

# 获取前3个 apply_id
sample_ids = df_raw['apply_id'].head(3).tolist()
print(f"\n示例 ID 列表: {sample_ids}")

print("\n✅ 使用 isin 查询多个 ID:")
print(f"   df_raw[df_raw['apply_id'].isin({sample_ids})]")
result_multi = df_raw[df_raw['apply_id'].isin(sample_ids)][['apply_id','apply_time']]
print(f"   结果行数: {len(result_multi)}")
print("\n   结果:")
print(result_multi.to_string(index=False))

# 总结
print("\n" + "="*70)
print("总结")
print("="*70)
print("1. apply_id 是整数类型，不要用字符串查询")
print("2. 推荐使用: df_raw[df_raw['apply_id']==1065991091661283329]")
print("3. 查询多个 ID 用: df_raw[df_raw['apply_id'].isin([id1, id2, id3])]")
print("4. 简洁写法用: df_raw.query('apply_id == 1065991091661283329')")
print("="*70)
