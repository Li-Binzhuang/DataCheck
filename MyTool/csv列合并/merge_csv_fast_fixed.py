#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
高性能 CSV 合并工具（修复版）
- 使用组合主键 (apply_id + create_time + cust_no)
- 设置索引加速合并
- 每次合并后立即删除重复列
"""

import pandas as pd
import os
import glob
import gc
import time


def merge_csv_fast(input_folder=None):
    """高性能合并 CSV 文件"""
    
    if input_folder is None:
        input_folder = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'data')
    
    if not os.path.exists(input_folder):
        print(f"❌ 错误：文件夹 '{input_folder}' 不存在")
        return
    
    csv_files = sorted(glob.glob(os.path.join(input_folder, '*.csv')))
    
    if not csv_files:
        print(f"⚠️  没有找到 CSV 文件")
        return
    
    print(f"找到 {len(csv_files)} 个文件")
    total_size = sum(os.path.getsize(f) for f in csv_files) / (1024 * 1024)
    print(f"总大小: {total_size:.2f} MB\n")
    
    # 配置
    columns_to_drop = ['user_type', 'rule_type', 'business_type', 'if_reoffer']
    merge_keys = ['apply_id', 'create_time', 'cust_no']
    
    print(f"合并主键: {', '.join(merge_keys)}\n")
    print("开始处理...")
    
    # 读取第一个文件
    print(f"\n[1/{len(csv_files)}] 读取基础文件: {os.path.basename(csv_files[0])}")
    start_time = time.time()
    
    merged_df = pd.read_csv(csv_files[0], low_memory=True)
    
    # 删除不需要的列
    cols_to_drop = [col for col in columns_to_drop if col in merged_df.columns]
    if cols_to_drop:
        merged_df = merged_df.drop(columns=cols_to_drop)
    
    print(f"  {len(merged_df)} 行, {len(merged_df.columns)} 列")
    print(f"  耗时: {time.time() - start_time:.2f}秒")
    
    # 设置组合索引以加速合并
    if all(k in merged_df.columns for k in merge_keys):
        merged_df = merged_df.set_index(merge_keys)
        print(f"  已设置组合索引")
    else:
        print(f"  ⚠️  缺少合并键，无法设置索引")
        return
    
    # 逐个合并其他文件
    for i, file in enumerate(csv_files[1:], 2):
        print(f"\n[{i}/{len(csv_files)}] 处理: {os.path.basename(file)}")
        start_time = time.time()
        
        try:
            # 读取文件
            df = pd.read_csv(file, low_memory=True)
            
            # 删除不需要的列
            cols_to_drop = [col for col in columns_to_drop if col in df.columns]
            if cols_to_drop:
                df = df.drop(columns=cols_to_drop)
            
            print(f"  读取: {len(df)} 行, {len(df.columns)} 列")
            
            # 检查合并键
            if not all(k in df.columns for k in merge_keys):
                print(f"  ⚠️  缺少合并键，跳过")
                continue
            
            # 设置索引
            df = df.set_index(merge_keys)
            
            # 使用 join 代替 merge（更快）
            print(f"  合并中...")
            before_cols = len(merged_df.columns)
            merged_df = merged_df.join(df, how='inner', rsuffix='_dup')
            after_cols = len(merged_df.columns)
            
            print(f"  合并后: {len(merged_df)} 行, {after_cols} 列 (新增 {after_cols - before_cols} 列)")
            
            # 立即删除 _dup 列
            dup_cols = [col for col in merged_df.columns if col.endswith('_dup')]
            if dup_cols:
                merged_df = merged_df.drop(columns=dup_cols)
                print(f"  删除 {len(dup_cols)} 个重复列")
            
            print(f"  耗时: {time.time() - start_time:.2f}秒")
            
            del df
            gc.collect()
            
        except MemoryError:
            print(f"  ❌ 内存不足！")
            break
        except Exception as e:
            print(f"  ❌ 错误: {e}")
            continue
    
    # 重置索引
    print(f"\n重置索引...")
    merged_df = merged_df.reset_index()
    
    # 保存
    output_file = 'merged_0302new.csv'
    print(f"\n保存到 {output_file}...")
    start_time = time.time()
    
    # 尝试使用更快的保存方法
    try:
        # 方法1: 使用 pyarrow 引擎（最快，需要安装 pyarrow）
        merged_df.to_csv(output_file, index=False, engine='pyarrow')
        print(f"  使用 pyarrow 引擎加速")
    except (ImportError, TypeError):
        try:
            # 方法2: 使用 chunksize 分块写入（减少内存峰值）
            merged_df.to_csv(output_file, index=False, chunksize=50000)
            print(f"  使用分块写入")
        except TypeError:
            # 方法3: 标准方式
            merged_df.to_csv(output_file, index=False)
            print(f"  使用标准方式")
    
    size = os.path.getsize(output_file) / (1024 * 1024)
    print(f"保存耗时: {time.time() - start_time:.2f}秒")
    
    print(f"\n{'='*60}")
    print(f"合并完成！")
    print(f"{'='*60}")
    print(f"输出文件: {output_file}")
    print(f"文件大小: {size:.2f} MB")
    print(f"总行数: {len(merged_df):,}")
    print(f"总列数: {len(merged_df.columns)}")
    print(f"{'='*60}")
    
    del merged_df
    gc.collect()
    
    return output_file


if __name__ == '__main__':
    import sys
    
    print("="*60)
    print("CSV 高性能合并工具（修复版）")
    print("="*60)
    print()
    
    script_dir = os.path.dirname(os.path.abspath(__file__))
    os.chdir(script_dir)
    print(f"工作目录: {os.getcwd()}\n")
    
    folder = sys.argv[1] if len(sys.argv) > 1 else None
    
    total_start = time.time()
    result = merge_csv_fast(folder)
    total_elapsed = time.time() - total_start
    
    if result:
        print(f"\n总耗时: {total_elapsed:.2f} 秒 ({total_elapsed/60:.1f} 分钟)")
