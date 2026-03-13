#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""检查 CSV 文件中是否有重复的 apply_id"""

import pandas as pd
import sys
import os

def check_duplicates(file_path):
    """检查文件中的重复 apply_id"""
    print(f"\n检查文件: {os.path.basename(file_path)}")
    print("="*60)
    
    df = pd.read_csv(file_path, low_memory=True)
    
    print(f"总行数: {len(df)}")
    
    if 'apply_id' not in df.columns:
        print("❌ 文件中没有 apply_id 列")
        return
    
    # 检查重复
    duplicates = df['apply_id'].duplicated()
    dup_count = duplicates.sum()
    unique_count = df['apply_id'].nunique()
    
    print(f"唯一 apply_id 数量: {unique_count}")
    print(f"重复 apply_id 数量: {dup_count}")
    
    if dup_count > 0:
        print(f"\n⚠️  发现 {dup_count} 个重复的 apply_id!")
        
        # 显示重复的 apply_id
        dup_ids = df[df['apply_id'].duplicated(keep=False)]['apply_id'].unique()
        print(f"\n重复的 apply_id 示例 (前10个):")
        for i, aid in enumerate(dup_ids[:10], 1):
            count = (df['apply_id'] == aid).sum()
            print(f"  {i}. {aid} - 出现 {count} 次")
    else:
        print("\n✅ 没有重复的 apply_id")

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("用法: python check_duplicate_ids.py <csv文件路径>")
        print("或: python check_duplicate_ids.py data/*.csv")
        sys.exit(1)
    
    for file_path in sys.argv[1:]:
        if os.path.exists(file_path):
            check_duplicates(file_path)
        else:
            print(f"❌ 文件不存在: {file_path}")
