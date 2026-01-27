#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
测试流式对比功能
验证内存占用和性能改进
"""

import os
import sys
import time
import tracemalloc

# 添加父目录到路径
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from api_comparison.job.streaming_comparator import StreamingComparator


def format_memory(bytes_value):
    """格式化内存大小"""
    if bytes_value < 1024:
        return f"{bytes_value} B"
    elif bytes_value < 1024 * 1024:
        return f"{bytes_value / 1024:.2f} KB"
    else:
        return f"{bytes_value / (1024 * 1024):.2f} MB"


def test_streaming_comparison():
    """测试流式对比"""
    print("="*80)
    print("流式对比功能测试")
    print("="*80)
    
    # 配置参数
    input_csv_path = "inputdata/api_comparison/test_api.csv"
    output_csv_path = "outputdata/test_streaming_compare.csv"
    api_url = "http://your-api-url.com/api"  # 替换为实际的API URL
    
    # 检查输入文件是否存在
    if not os.path.exists(input_csv_path):
        print(f"❌ 输入文件不存在: {input_csv_path}")
        print(f"请先准备测试数据文件")
        return
    
    # 开始内存监控
    tracemalloc.start()
    start_memory = tracemalloc.get_traced_memory()[0]
    start_time = time.time()
    
    try:
        # 创建流式对比器
        comparator = StreamingComparator(
            api_url=api_url,
            param1_column=1,  # cust_no列
            param2_column=3,  # use_create_time列
            feature_start_column=4,  # 特征开始列
            thread_count=50,  # 测试用较小的线程数
            timeout=60,
            add_one_second=False,
            batch_size=100  # 测试用较小的批次
        )
        
        # 执行流式对比
        comparator.streaming_compare(input_csv_path, output_csv_path)
        
        # 结束监控
        end_time = time.time()
        current_memory, peak_memory = tracemalloc.get_traced_memory()
        tracemalloc.stop()
        
        # 计算统计数据
        memory_increase = current_memory - start_memory
        elapsed_time = end_time - start_time
        
        # 打印结果
        print(f"\n{'='*80}")
        print(f"测试结果")
        print(f"{'='*80}")
        print(f"执行时间: {elapsed_time:.2f} 秒")
        print(f"内存增长: {format_memory(memory_increase)}")
        print(f"峰值内存: {format_memory(peak_memory)}")
        print(f"{'='*80}")
        
        print(f"\n✅ 流式对比测试完成")
        
    except Exception as e:
        print(f"\n❌ 测试失败: {str(e)}")
        import traceback
        traceback.print_exc()
    finally:
        if tracemalloc.is_tracing():
            tracemalloc.stop()


def compare_with_memory_mode():
    """对比流式模式和内存模式的性能"""
    print("="*80)
    print("流式模式 vs 内存模式 性能对比")
    print("="*80)
    
    # TODO: 实现对比测试
    print("\n提示: 此功能需要实际的API接口和测试数据")
    print("预期结果:")
    print("  • 流式模式内存占用降低 80-90%")
    print("  • 流式模式速度提升 20-30%")
    print("  • 流式模式支持更大的数据文件")


if __name__ == "__main__":
    print("\n选择测试模式:")
    print("1. 测试流式对比功能")
    print("2. 对比流式模式和内存模式")
    
    choice = input("\n请输入选项 (1/2): ").strip()
    
    if choice == "1":
        test_streaming_comparison()
    elif choice == "2":
        compare_with_memory_mode()
    else:
        print("无效的选项")
