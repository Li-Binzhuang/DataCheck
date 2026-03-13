#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
分批合并 CSV 文件（解决内存不足问题）
先两两合并，再合并结果
"""

import pandas as pd
import os
from datetime import datetime
import glob
import gc


def merge_two_files(file1, file2, columns_to_drop, merge_keys):
    """合并两个文件"""
    print(f"\n合并: {os.path.basename(file1)} + {os.path.basename(file2)}")
    
    # 读取第一个文件
    df1 = pd.read_csv(file1, low_memory=True)
    print(f"  文件1: {len(df1)} 行, {len(df1.columns)} 列")
    
    # 删除指定列
    cols_to_drop = [col for col in columns_to_drop if col in df1.columns]
    if cols_to_drop:
        df1 = df1.drop(columns=cols_to_drop)
    
    # 读取第二个文件
    df2 = pd.read_csv(file2, low_memory=True)
    print(f"  文件2: {len(df2)} 行, {len(df2.columns)} 列")
    
    # 删除指定列
    cols_to_drop = [col for col in columns_to_drop if col in df2.columns]
    if cols_to_drop:
        df2 = df2.drop(columns=cols_to_drop)
    
    # 检查合并键是否存在
    missing_keys_1 = [k for k in merge_keys if k not in df1.columns]
    missing_keys_2 = [k for k in merge_keys if k not in df2.columns]
    
    if missing_keys_1 or missing_keys_2:
        print(f"  ⚠️  警告: 缺少合并键")
        if missing_keys_1:
            print(f"    文件1缺少: {', '.join(missing_keys_1)}")
        if missing_keys_2:
            print(f"    文件2缺少: {', '.join(missing_keys_2)}")
        return None
    
    # 按组合主键合并
    result = df1.merge(df2, on=merge_keys, how='inner', suffixes=('', '_dup'))
    print(f"  合并: {len(result)} 行, {len(result.columns)} 列")
    
    # 立即删除 _dup 后缀的列，避免下一轮合并时出错
    dup_cols = [col for col in result.columns if col.endswith('_dup')]
    if dup_cols:
        result = result.drop(columns=dup_cols)
        print(f"  删除 {len(dup_cols)} 个重复列")
        print(f"  最终: {len(result)} 行, {len(result.columns)} 列")
    
    # 清理内存
    del df1, df2
    gc.collect()
    
    return result


def merge_csv_batch(input_folder=None):
    """分批合并 CSV 文件"""
    
    # 定义输入文件夹
    if input_folder is None:
        input_folder = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'data')
    
    if not os.path.exists(input_folder):
        print(f"❌ 错误：文件夹 '{input_folder}' 不存在")
        return
    
    # 获取所有 CSV 文件
    csv_files = sorted(glob.glob(os.path.join(input_folder, '*.csv')))
    
    if not csv_files:
        print(f"⚠️  提示：文件夹中没有找到任何 CSV 文件")
        return
    
    print(f"找到 {len(csv_files)} 个 CSV 文件")
    for i, file in enumerate(csv_files, 1):
        size = os.path.getsize(file) / (1024 * 1024)
        print(f"  {i}. {os.path.basename(file)} - {size:.2f} MB")
    
    # 配置
    columns_to_drop = ['user_type', 'rule_type', 'business_type', 'if_reoffer']
    merge_keys = ['apply_id', 'create_time', 'cust_no']  # 组合主键
    
    print(f"\n合并主键: {', '.join(merge_keys)}")
    
    # 创建临时文件夹
    temp_folder = 'temp_merge'
    os.makedirs(temp_folder, exist_ok=True)
    
    print(f"\n开始分批合并...")
    round_num = 1
    current_files = csv_files.copy()
    
    while len(current_files) > 1:
        print(f"\n{'='*60}")
        print(f"第 {round_num} 轮合并 (剩余 {len(current_files)} 个文件)")
        print(f"{'='*60}")
        
        next_files = []
        
        # 两两合并
        for i in range(0, len(current_files), 2):
            if i + 1 < len(current_files):
                # 合并两个文件
                merged = merge_two_files(
                    current_files[i], 
                    current_files[i+1],
                    columns_to_drop,
                    merge_keys
                )
                
                if merged is not None:
                    # 保存临时文件
                    temp_file = os.path.join(temp_folder, f'temp_round{round_num}_part{i//2}.csv')
                    print(f"  保存临时文件: {os.path.basename(temp_file)}")
                    
                    # 快速保存
                    try:
                        merged.to_csv(temp_file, index=False, engine='pyarrow')
                    except (ImportError, TypeError):
                        merged.to_csv(temp_file, index=False)
                    
                    next_files.append(temp_file)
                    
                    del merged
                    gc.collect()
                else:
                    print(f"  ⚠️  合并失败，跳过")
                    continue
            else:
                # 奇数个文件，最后一个直接保留
                next_files.append(current_files[i])
        
        current_files = next_files
        round_num += 1
    
    # 最终文件
    final_file = current_files[0]
    output_file = 'merged_0302new.csv'
    
    print(f"\n{'='*60}")
    print(f"保存最终文件...")
    print(f"{'='*60}")
    
    # 读取最终文件
    df_final = pd.read_csv(final_file, low_memory=True)
    print(f"最终结果: {len(df_final)} 行, {len(df_final.columns)} 列")
    
    # 再次检查是否有遗漏的 _dup 列
    dup_cols = [col for col in df_final.columns if col.endswith('_dup')]
    if dup_cols:
        df_final = df_final.drop(columns=dup_cols)
        print(f"删除遗漏的重复列: {len(dup_cols)} 个")
    
    # 保存最终文件
    print(f"\n保存到 {output_file}...")
    try:
        df_final.to_csv(output_file, index=False, engine='pyarrow')
        print(f"  使用 pyarrow 引擎加速")
    except (ImportError, TypeError):
        df_final.to_csv(output_file, index=False)
        print(f"  使用标准方式")
    
    print(f"\n{'='*60}")
    print(f"合并完成！")
    print(f"{'='*60}")
    
    # 清理临时文件
    print(f"\n清理临时文件...")
    import shutil
    if os.path.exists(temp_folder):
        shutil.rmtree(temp_folder)
    if final_file != output_file and os.path.exists(final_file):
        os.remove(final_file)
    
    # 输出信息
    output_size = os.path.getsize(output_file) / (1024 * 1024)
    print(f"\n输出文件: {output_file}")
    print(f"文件大小: {output_size:.2f} MB")
    print(f"总行数: {len(df_final):,}")
    print(f"总列数: {len(df_final.columns)}")
    
    # 显示列信息
    print(f"\n列名: {', '.join(df_final.columns[:10])}", end='')
    if len(df_final.columns) > 10:
        print(f" ... (共 {len(df_final.columns)} 列)")
    else:
        print()
    
    del df_final
    gc.collect()
    
    return output_file


if __name__ == '__main__':
    import sys
    
    print("="*60)
    print("CSV文件分批合并工具 (内存优化)")
    print("="*60)
    print()
    
    script_dir = os.path.dirname(os.path.abspath(__file__))
    os.chdir(script_dir)
    print(f"工作目录: {os.getcwd()}\n")
    
    folder = sys.argv[1] if len(sys.argv) > 1 else None
    merge_csv_batch(folder)
