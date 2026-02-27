#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
合并 '合并前单独文件' 文件夹下所有 CSV 文件
自动扫描文件夹中的所有 CSV 文件并合并为一个文件
"""

import pandas as pd
import os
from datetime import datetime
import glob

def merge_csv_files(input_folder=None):
    """合并指定文件夹下的所有 CSV 文件"""
    
    # 定义输入文件夹
    if input_folder is None:
        input_folder = os.path.join(os.path.dirname(os.path.abspath(__file__)), '合并前单独文件')
    
    # 检查文件夹是否存在
    if not os.path.exists(input_folder):
        print(f"❌ 错误：文件夹 '{input_folder}' 不存在")
        return
    
    # 获取文件夹中所有 CSV 文件
    csv_pattern = os.path.join(input_folder, '*.csv')
    csv_files = glob.glob(csv_pattern)
    
    # 检查是否有 CSV 文件
    if not csv_files:
        print(f"⚠️  提示：文件夹 '{input_folder}' 中没有找到任何 CSV 文件")
        return
    
    # 按文件名排序
    csv_files.sort()
    
    print(f"找到 {len(csv_files)} 个 CSV 文件:")
    for file in csv_files:
        file_size = os.path.getsize(file) / (1024 * 1024)  # MB
        file_name = os.path.basename(file)
        print(f"  ✓ {file_name} - {file_size:.2f} MB")
    
    # 读取并合并文件
    print("\n开始合并文件...")
    dfs = []
    
    for i, file in enumerate(csv_files, 1):
        file_name = os.path.basename(file)
        print(f"  [{i}/{len(csv_files)}] 读取 {file_name}...", end=' ')
        try:
            df = pd.read_csv(file)
            rows = len(df)
            cols = len(df.columns)
            dfs.append(df)
            print(f"✓ ({rows} 行, {cols} 列)")
        except Exception as e:
            print(f"❌ 错误: {e}")
            return
    
    # 合并所有数据
    print("\n合并数据...")
    merged_df = pd.concat(dfs, ignore_index=True)
    
    # 生成输出文件名（带时间戳）
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    output_file = f'hdpart2_all_{timestamp}.csv'
    
    # 保存合并后的文件
    print(f"保存到 {output_file}...")
    merged_df.to_csv(output_file, index=False)
    
    # 输出统计信息
    output_size = os.path.getsize(output_file) / (1024 * 1024)  # MB
    print("\n" + "="*60)
    print("合并完成！")
    print("="*60)
    print(f"输入文件数: {len(csv_files)}")
    print(f"总行数: {len(merged_df):,}")
    print(f"总列数: {len(merged_df.columns)}")
    print(f"输出文件: {output_file}")
    print(f"文件大小: {output_size:.2f} MB")
    print("="*60)
    
    # 显示每个文件的行数统计
    print("\n各文件行数统计:")
    for i, (file, df) in enumerate(zip(csv_files, dfs), 1):
        file_name = os.path.basename(file)
        print(f"  {i}. {file_name}: {len(df):,} 行")
    
    return output_file

if __name__ == '__main__':
    import sys
    
    print("="*60)
    print("CSV文件合并工具")
    print("="*60)
    print()
    
    # 切换到脚本所在目录
    script_dir = os.path.dirname(os.path.abspath(__file__))
    os.chdir(script_dir)
    print(f"工作目录: {os.getcwd()}\n")
    
    # 支持命令行指定文件夹
    if len(sys.argv) > 1:
        folder = sys.argv[1]
    else:
        folder = None
    
    # 执行合并
    merge_csv_files(folder)
