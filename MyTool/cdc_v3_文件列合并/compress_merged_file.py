#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
合并文件压缩优化脚本
将 1.32G 的 CSV 文件压缩为更高效的格式
"""

import pandas as pd
import os
from pathlib import Path
import time

# 定义路径
script_dir = Path(__file__).parent
merged_file = script_dir / "sms_v3_merged" / "sms_v3_all_merged_0302_v1.csv"
output_dir = script_dir / "sms_v3_merged"

def get_file_size_mb(filepath):
    """获取文件大小（MB）"""
    return os.path.getsize(filepath) / (1024 * 1024)

def compress_to_parquet():
    """方案1：转换为 Parquet 格式（推荐）"""
    print("\n" + "="*80)
    print("方案1: 转换为 Parquet 格式（推荐）")
    print("="*80)
    
    output_file = output_dir / "sms_v3_all_merged_0302_v1.parquet"
    
    if output_file.exists():
        print(f"✓ 文件已存在: {output_file.name}")
        size = get_file_size_mb(output_file)
        print(f"  文件大小: {size:.2f} MB")
        return
    
    print(f"读取 CSV 文件...")
    start = time.time()
    df = pd.read_csv(merged_file)
    print(f"✓ 读取完成 ({time.time()-start:.1f}s)")
    print(f"  数据形状: {df.shape[0]} 行 × {df.shape[1]} 列")
    
    print(f"转换为 Parquet...")
    start = time.time()
    df.to_parquet(output_file, compression='snappy', index=False)
    print(f"✓ 转换完成 ({time.time()-start:.1f}s)")
    
    original_size = get_file_size_mb(merged_file)
    compressed_size = get_file_size_mb(output_file)
    ratio = (1 - compressed_size/original_size) * 100
    
    print(f"  原始大小: {original_size:.2f} MB")
    print(f"  压缩后: {compressed_size:.2f} MB")
    print(f"  压缩率: {ratio:.1f}%")

def compress_to_csv_gz():
    """方案2：压缩为 CSV.GZ 格式"""
    print("\n" + "="*80)
    print("方案2: 压缩为 CSV.GZ 格式")
    print("="*80)
    
    output_file = output_dir / "sms_v3_all_merged_0302_v1.csv.gz"
    
    if output_file.exists():
        print(f"✓ 文件已存在: {output_file.name}")
        size = get_file_size_mb(output_file)
        print(f"  文件大小: {size:.2f} MB")
        return
    
    print(f"读取 CSV 文件...")
    start = time.time()
    df = pd.read_csv(merged_file)
    print(f"✓ 读取完成 ({time.time()-start:.1f}s)")
    
    print(f"压缩为 CSV.GZ...")
    start = time.time()
    df.to_csv(output_file, compression='gzip', index=False)
    print(f"✓ 压缩完成 ({time.time()-start:.1f}s)")
    
    original_size = get_file_size_mb(merged_file)
    compressed_size = get_file_size_mb(output_file)
    ratio = (1 - compressed_size/original_size) * 100
    
    print(f"  原始大小: {original_size:.2f} MB")
    print(f"  压缩后: {compressed_size:.2f} MB")
    print(f"  压缩率: {ratio:.1f}%")

def compress_to_feather():
    """方案3：转换为 Feather 格式（快速读写）"""
    print("\n" + "="*80)
    print("方案3: 转换为 Feather 格式（快速读写）")
    print("="*80)
    
    output_file = output_dir / "sms_v3_all_merged_0302_v1.feather"
    
    if output_file.exists():
        print(f"✓ 文件已存在: {output_file.name}")
        size = get_file_size_mb(output_file)
        print(f"  文件大小: {size:.2f} MB")
        return
    
    print(f"读取 CSV 文件...")
    start = time.time()
    df = pd.read_csv(merged_file)
    print(f"✓ 读取完成 ({time.time()-start:.1f}s)")
    
    print(f"转换为 Feather...")
    start = time.time()
    df.to_feather(output_file)
    print(f"✓ 转换完成 ({time.time()-start:.1f}s)")
    
    original_size = get_file_size_mb(merged_file)
    compressed_size = get_file_size_mb(output_file)
    ratio = (1 - compressed_size/original_size) * 100
    
    print(f"  原始大小: {original_size:.2f} MB")
    print(f"  压缩后: {compressed_size:.2f} MB")
    print(f"  压缩率: {ratio:.1f}%")

def show_comparison():
    """显示各格式对比"""
    print("\n" + "="*80)
    print("格式对比总结")
    print("="*80)
    
    formats = {
        "Parquet (snappy)": ("parquet", "✓ 最佳压缩率 | ✓ 快速读写 | ✓ 支持列式查询"),
        "CSV.GZ": ("csv.gz", "✓ 通用格式 | ✓ 可文本查看 | ✗ 读写较慢"),
        "Feather": ("feather", "✓ 快速读写 | ✓ 列式存储 | ✗ 压缩率一般"),
    }
    
    for fmt, (ext, desc) in formats.items():
        file_path = output_dir / f"sms_v3_all_merged_0302_v1.{ext}"
        if file_path.exists():
            size = get_file_size_mb(file_path)
            print(f"\n{fmt}")
            print(f"  文件: {file_path.name}")
            print(f"  大小: {size:.2f} MB")
            print(f"  特点: {desc}")

if __name__ == "__main__":
    print(f"CSV 文件压缩工具")
    print(f"原始文件: {merged_file.name}")
    print(f"原始大小: {get_file_size_mb(merged_file):.2f} MB")
    
    # 执行所有压缩方案
    compress_to_parquet()
    compress_to_csv_gz()
    compress_to_feather()
    
    # 显示对比
    show_comparison()
    
    print("\n" + "="*80)
    print("✓ 压缩完成！")
    print("="*80)
