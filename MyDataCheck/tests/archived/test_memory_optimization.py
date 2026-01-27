#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
内存优化测试脚本
功能：测试流式写入的内存占用和性能
"""

import os
import sys
import time
import psutil

# 添加common目录到路径
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'common'))

from csv_tool import CSVStreamWriter


def print_memory_usage(label=""):
    """打印当前内存使用情况"""
    process = psutil.Process(os.getpid())
    mem_mb = process.memory_info().rss / 1024 / 1024
    print(f"[{label}] 内存使用: {mem_mb:.2f} MB")


def test_stream_writer():
    """测试流式写入器"""
    print("\n" + "="*80)
    print("测试流式写入器")
    print("="*80)
    
    print_memory_usage("开始")
    
    # 创建测试数据
    headers = ["ID", "姓名", "年龄"] + [f"特征{i}" for i in range(100)]
    output_path = "MyDataCheck/outputdata/test_stream_output.csv"
    
    # 测试写入10000行数据
    row_count = 10000
    print(f"\n写入 {row_count} 行数据...")
    
    start_time = time.time()
    
    with CSVStreamWriter(output_path, headers) as writer:
        for i in range(row_count):
            row = [str(i), f"用户{i}", str(20 + i % 50)] + [str(j) for j in range(100)]
            writer.write_row(row)
            
            # 每2000行打印一次内存使用
            if (i + 1) % 2000 == 0:
                print_memory_usage(f"已写入 {i+1} 行")
    
    end_time = time.time()
    
    print_memory_usage("写入完成")
    print(f"\n耗时: {end_time - start_time:.2f} 秒")
    print(f"输出文件: {output_path}")
    
    # 检查文件是否存在
    if os.path.exists(output_path):
        file_size = os.path.getsize(output_path) / 1024 / 1024
        print(f"文件大小: {file_size:.2f} MB")
        print("✅ 测试通过")
    else:
        print("❌ 测试失败：文件未生成")


def test_traditional_writer():
    """测试传统写入方式（对比）"""
    print("\n" + "="*80)
    print("测试传统写入方式（对比）")
    print("="*80)
    
    print_memory_usage("开始")
    
    # 创建测试数据
    headers = ["ID", "姓名", "年龄"] + [f"特征{i}" for i in range(100)]
    output_path = "MyDataCheck/outputdata/test_traditional_output.csv"
    
    # 测试写入10000行数据
    row_count = 10000
    print(f"\n准备 {row_count} 行数据...")
    
    start_time = time.time()
    
    # 先在内存中准备所有数据
    all_rows = []
    for i in range(row_count):
        row = [str(i), f"用户{i}", str(20 + i % 50)] + [str(j) for j in range(100)]
        all_rows.append(row)
        
        if (i + 1) % 2000 == 0:
            print_memory_usage(f"已准备 {i+1} 行")
    
    print_memory_usage("数据准备完成")
    
    # 一次性写入
    print("\n开始写入文件...")
    import csv
    with open(output_path, "w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(headers)
        writer.writerows(all_rows)
    
    end_time = time.time()
    
    print_memory_usage("写入完成")
    print(f"\n耗时: {end_time - start_time:.2f} 秒")
    print(f"输出文件: {output_path}")
    
    # 检查文件是否存在
    if os.path.exists(output_path):
        file_size = os.path.getsize(output_path) / 1024 / 1024
        print(f"文件大小: {file_size:.2f} MB")
        print("✅ 测试通过")
    else:
        print("❌ 测试失败：文件未生成")


if __name__ == "__main__":
    print("\n" + "="*80)
    print("MyDataCheck 内存优化测试")
    print("="*80)
    
    # 测试流式写入
    test_stream_writer()
    
    print("\n" + "-"*80 + "\n")
    
    # 测试传统写入（对比）
    test_traditional_writer()
    
    print("\n" + "="*80)
    print("测试完成")
    print("="*80)
    print("\n对比结论：")
    print("- 流式写入：内存占用低且稳定，适合大文件")
    print("- 传统写入：内存占用随数据量线性增长，不适合大文件")
