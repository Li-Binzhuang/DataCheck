#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
检查 CSV 文件的数据情况
- 检查 apply_id 是否有重复
- 检查不同文件的 apply_id 是否一致
- 检查行数变化原因
"""

import pandas as pd
import os
import glob


def check_csv_files(input_folder=None):
    """检查 CSV 文件"""
    
    if input_folder is None:
        input_folder = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'data')
    
    csv_files = sorted(glob.glob(os.path.join(input_folder, '*.csv')))
    
    if not csv_files:
        print("没有找到 CSV 文件")
        return
    
    print(f"找到 {len(csv_files)} 个文件\n")
    print("="*80)
    
    all_apply_ids = []
    
    for i, file in enumerate(csv_files, 1):
        file_name = os.path.basename(file)
        print(f"\n[{i}] {file_name}")
        print("-"*80)
        
        # 读取文件
        df = pd.read_csv(file)
        
        print(f"总行数: {len(df)}")
        print(f"总列数: {len(df.columns)}")
        
        # 检查是否有 apply_id
        if 'apply_id' not in df.columns:
            print("⚠️  警告: 没有 apply_id 列！")
            print(f"列名: {', '.join(df.columns[:10])}")
            continue
        
        # 检查 apply_id 重复
        apply_ids = df['apply_id']
        unique_count = apply_ids.nunique()
        duplicate_count = len(apply_ids) - unique_count
        
        print(f"唯一 apply_id 数: {unique_count}")
        
        if duplicate_count > 0:
            print(f"⚠️  警告: 有 {duplicate_count} 个重复的 apply_id！")
            # 显示重复的 apply_id
            duplicates = apply_ids[apply_ids.duplicated()].unique()
            print(f"重复的 apply_id 示例: {list(duplicates[:5])}")
        else:
            print("✓ 没有重复的 apply_id")
        
        # 检查空值
        null_count = apply_ids.isnull().sum()
        if null_count > 0:
            print(f"⚠️  警告: 有 {null_count} 个空的 apply_id")
        
        # 保存 apply_id 集合
        all_apply_ids.append({
            'file': file_name,
            'apply_ids': set(apply_ids.dropna())
        })
    
    # 检查不同文件的 apply_id 交集
    print("\n" + "="*80)
    print("文件间 apply_id 对比")
    print("="*80)
    
    if len(all_apply_ids) >= 2:
        base_set = all_apply_ids[0]['apply_ids']
        base_name = all_apply_ids[0]['file']
        
        print(f"\n基准文件: {base_name}")
        print(f"apply_id 数量: {len(base_set)}")
        
        for item in all_apply_ids[1:]:
            current_set = item['apply_ids']
            current_name = item['file']
            
            # 交集
            intersection = base_set & current_set
            # 只在基准文件中
            only_in_base = base_set - current_set
            # 只在当前文件中
            only_in_current = current_set - base_set
            
            print(f"\n与 {current_name} 对比:")
            print(f"  当前文件 apply_id 数: {len(current_set)}")
            print(f"  共同的 apply_id: {len(intersection)}")
            print(f"  只在基准文件: {len(only_in_base)}")
            print(f"  只在当前文件: {len(only_in_current)}")
            
            if only_in_base:
                print(f"  ⚠️  基准文件中有 {len(only_in_base)} 个 apply_id 在当前文件中不存在")
            if only_in_current:
                print(f"  ⚠️  当前文件中有 {len(only_in_current)} 个 apply_id 在基准文件中不存在")
    
    # 建议
    print("\n" + "="*80)
    print("合并建议")
    print("="*80)
    
    has_duplicates = any(
        pd.read_csv(f)['apply_id'].duplicated().any() 
        for f in csv_files 
        if 'apply_id' in pd.read_csv(f, nrows=0).columns
    )
    
    if has_duplicates:
        print("\n⚠️  发现重复的 apply_id！")
        print("建议:")
        print("  1. 使用 'inner' join (只保留共同的 apply_id)")
        print("  2. 或者先去重再合并")
    else:
        print("\n✓ 没有发现重复的 apply_id")
        
        # 检查 apply_id 是否完全一致
        if len(all_apply_ids) >= 2:
            all_same = all(
                item['apply_ids'] == all_apply_ids[0]['apply_ids']
                for item in all_apply_ids[1:]
            )
            
            if all_same:
                print("✓ 所有文件的 apply_id 完全一致")
                print("建议: 使用 'inner' 或 'left' join")
            else:
                print("⚠️  不同文件的 apply_id 不完全一致")
                print("建议:")
                print("  - 使用 'inner' join: 只保留所有文件都有的 apply_id")
                print("  - 使用 'outer' join: 保留所有 apply_id (行数会增加)")
                print("  - 使用 'left' join: 以第一个文件为准")


if __name__ == '__main__':
    import sys
    
    print("="*80)
    print("CSV 数据检查工具")
    print("="*80)
    print()
    
    script_dir = os.path.dirname(os.path.abspath(__file__))
    os.chdir(script_dir)
    
    folder = sys.argv[1] if len(sys.argv) > 1 else None
    check_csv_files(folder)
