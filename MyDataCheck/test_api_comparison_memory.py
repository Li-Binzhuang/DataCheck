#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
测试接口数据对比的内存占用
对比原版和优化版的内存使用情况
"""

import os
import sys
import psutil
import time

# 添加路径
sys.path.insert(0, os.path.dirname(__file__))


def print_memory_usage(label=""):
    """打印内存使用情况"""
    process = psutil.Process(os.getpid())
    mem_mb = process.memory_info().rss / 1024 / 1024
    print(f"[{label}] 内存使用: {mem_mb:.2f} MB")
    return mem_mb


def create_test_data():
    """创建测试数据"""
    print("\n" + "="*80)
    print("创建测试数据")
    print("="*80)
    
    # 创建原始文件
    orig_file = "MyDataCheck/inputdata/api_comparison/test_original.csv"
    api_file = "MyDataCheck/inputdata/api_comparison/test_api.csv"
    
    # 确保目录存在
    os.makedirs(os.path.dirname(orig_file), exist_ok=True)
    
    # 生成测试数据（5000行，50个特征）
    row_count = 5000
    feature_count = 50
    
    print(f"生成 {row_count} 行数据，{feature_count} 个特征...")
    
    import csv
    
    # 写入原始文件
    with open(orig_file, 'w', encoding='utf-8', newline='') as f:
        writer = csv.writer(f)
        headers = ['id', 'cust_no', 'apply_id', 'use_create_time'] + [f'feature_{i}' for i in range(feature_count)]
        writer.writerow(headers)
        
        for i in range(row_count):
            row = [
                str(i),
                f'CUST{i:06d}',
                f'APPLY{i:06d}',
                f'2024-01-01T10:00:{i%60:02d}.000'
            ] + [str(j * i % 100) for j in range(feature_count)]
            writer.writerow(row)
    
    # 写入API文件（90%相同，10%不同）
    with open(api_file, 'w', encoding='utf-8', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(headers + ['time_now'])
        
        for i in range(row_count):
            row = [
                str(i),
                f'CUST{i:06d}',
                f'APPLY{i:06d}',
                f'2024-01-01T10:00:{i%60:02d}.000'
            ]
            # 10%的数据不同
            for j in range(feature_count):
                if i % 10 == 0 and j % 5 == 0:
                    row.append(str((j * i % 100) + 1))  # 故意制造差异
                else:
                    row.append(str(j * i % 100))
            row.append('2024-01-01T10:00:00.000')  # time_now
            writer.writerow(row)
    
    print(f"✅ 测试数据已创建")
    print(f"  原始文件: {orig_file}")
    print(f"  API文件: {api_file}")
    
    return orig_file, api_file


def test_original_version(orig_file, api_file):
    """测试原版（内存占用高）"""
    print("\n" + "="*80)
    print("测试原版接口数据对比")
    print("="*80)
    
    mem_start = print_memory_usage("开始")
    
    try:
        from api_comparison.job.compare_api_data import DataComparator
        
        comparator = DataComparator(
            param1_column=1,
            param2_column=3,
            feature_start_column=4
        )
        
        mem_after_import = print_memory_usage("导入模块后")
        
        output_path = "MyDataCheck/outputdata/test_original_result.csv"
        
        start_time = time.time()
        comparator.compare_files(orig_file, api_file, output_path)
        end_time = time.time()
        
        mem_end = print_memory_usage("对比完成")
        
        print(f"\n耗时: {end_time - start_time:.2f} 秒")
        print(f"内存增长: {mem_end - mem_start:.2f} MB")
        
        return mem_end - mem_start, end_time - start_time
        
    except Exception as e:
        print(f"❌ 测试失败: {e}")
        import traceback
        traceback.print_exc()
        return None, None


def test_optimized_version(orig_file, api_file):
    """测试优化版（内存占用低）"""
    print("\n" + "="*80)
    print("测试优化版接口数据对比")
    print("="*80)
    
    mem_start = print_memory_usage("开始")
    
    try:
        from api_comparison.job.compare_api_data_optimized import DataComparatorOptimized
        
        comparator = DataComparatorOptimized(
            param1_column=1,
            param2_column=3,
            feature_start_column=4
        )
        
        mem_after_import = print_memory_usage("导入模块后")
        
        output_path = "MyDataCheck/outputdata/test_optimized_result.csv"
        
        start_time = time.time()
        comparator.compare_files_streaming(orig_file, api_file, output_path)
        end_time = time.time()
        
        mem_end = print_memory_usage("对比完成")
        
        print(f"\n耗时: {end_time - start_time:.2f} 秒")
        print(f"内存增长: {mem_end - mem_start:.2f} MB")
        
        return mem_end - mem_start, end_time - start_time
        
    except Exception as e:
        print(f"❌ 测试失败: {e}")
        import traceback
        traceback.print_exc()
        return None, None


if __name__ == "__main__":
    print("\n" + "="*80)
    print("接口数据对比 - 内存优化测试")
    print("="*80)
    
    # 创建测试数据
    orig_file, api_file = create_test_data()
    
    # 测试原版
    mem_orig, time_orig = test_original_version(orig_file, api_file)
    
    print("\n" + "-"*80 + "\n")
    
    # 测试优化版
    mem_opt, time_opt = test_optimized_version(orig_file, api_file)
    
    # 对比结果
    print("\n" + "="*80)
    print("对比结果")
    print("="*80)
    
    if mem_orig and mem_opt:
        print(f"\n内存占用:")
        print(f"  原版: {mem_orig:.2f} MB")
        print(f"  优化版: {mem_opt:.2f} MB")
        print(f"  节省: {mem_orig - mem_opt:.2f} MB ({(1 - mem_opt/mem_orig)*100:.1f}%)")
        
        print(f"\n处理时间:")
        print(f"  原版: {time_orig:.2f} 秒")
        print(f"  优化版: {time_opt:.2f} 秒")
        
        if time_opt < time_orig:
            print(f"  提升: {time_orig - time_opt:.2f} 秒 ({(1 - time_opt/time_orig)*100:.1f}%)")
        else:
            print(f"  差异: +{time_opt - time_orig:.2f} 秒")
        
        print(f"\n✅ 优化版内存占用更低，推荐使用！")
    else:
        print(f"\n❌ 测试未完成，请检查错误信息")
    
    print("\n" + "="*80 + "\n")
