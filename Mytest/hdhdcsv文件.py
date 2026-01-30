#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
合并 hd21.csv 至 hd28.csv 文件
将8个CSV文件合并为一个文件输出
"""

import pandas as pd
import os
from datetime import datetime

def merge_hd_files():
    """合并 hd21.csv 到 hd28.csv 的8个文件"""
    
    # 定义输入文件列表
    input_files = [f'hd{i}.csv' for i in range(21, 29)]
    
    # 检查文件是否存在
    print("检查文件...")
    missing_files = []
    for file in input_files:
        if not os.path.exists(file):
            missing_files.append(file)
            print(f"  ❌ {file} - 不存在")
        else:
            file_size = os.path.getsize(file) / (1024 * 1024)  # MB
            print(f"  ✓ {file} - {file_size:.2f} MB")
    
    if missing_files:
        print(f"\n错误：缺少 {len(missing_files)} 个文件")
        return
    
    # 读取并合并文件
    print("\n开始合并文件...")
    dfs = []
    
    for i, file in enumerate(input_files, 1):
        print(f"  [{i}/8] 读取 {file}...", end=' ')
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
    output_file = f'hd21_to_hd28_merged_{timestamp}.csv'
    
    # 保存合并后的文件
    print(f"保存到 {output_file}...")
    merged_df.to_csv(output_file, index=False)
    
    # 输出统计信息
    output_size = os.path.getsize(output_file) / (1024 * 1024)  # MB
    print("\n" + "="*60)
    print("合并完成！")
    print("="*60)
    print(f"输入文件数: {len(input_files)}")
    print(f"总行数: {len(merged_df):,}")
    print(f"总列数: {len(merged_df.columns)}")
    print(f"输出文件: {output_file}")
    print(f"文件大小: {output_size:.2f} MB")
    print("="*60)
    
    # 显示每个文件的行数统计
    print("\n各文件行数统计:")
    for i, (file, df) in enumerate(zip(input_files, dfs), 1):
        print(f"  {i}. {file}: {len(df):,} 行")
    
    return output_file

if __name__ == '__main__':
    print("="*60)
    print("合并 hd21.csv 至 hd28.csv 文件")
    print("="*60)
    print()
    
    # 切换到脚本所在目录
    script_dir = os.path.dirname(os.path.abspath(__file__))
    os.chdir(script_dir)
    print(f"工作目录: {os.getcwd()}\n")
    
    # 执行合并
    merge_hd_files()
