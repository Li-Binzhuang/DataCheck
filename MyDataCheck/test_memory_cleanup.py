#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
测试内存清理功能
验证任务完成后内存是否正确释放
"""

import os
import sys
import time

# 添加路径
sys.path.insert(0, os.path.dirname(__file__))

from common.memory_manager import MemoryMonitor, MemoryManager, cleanup_large_objects


def test_memory_cleanup():
    """测试内存清理功能"""
    print("="*80)
    print("测试内存清理功能")
    print("="*80)
    
    # 初始内存
    mem_initial = MemoryManager.get_memory_usage()
    print(f"\n初始内存: {mem_initial:.2f} MB")
    
    # 模拟创建大对象
    print("\n创建大对象...")
    large_list = [i for i in range(1000000)]  # 约8MB
    large_dict = {i: str(i) * 100 for i in range(10000)}  # 约10MB
    
    mem_after_create = MemoryManager.get_memory_usage()
    print(f"创建后内存: {mem_after_create:.2f} MB")
    print(f"内存增长: {mem_after_create - mem_initial:.2f} MB")
    
    # 清理大对象
    print("\n清理大对象...")
    cleanup_large_objects(large_list, large_dict)
    
    mem_after_cleanup = MemoryManager.get_memory_usage()
    print(f"清理后内存: {mem_after_cleanup:.2f} MB")
    print(f"释放内存: {mem_after_create - mem_after_cleanup:.2f} MB")
    
    # 验证内存是否接近初始值
    mem_diff = mem_after_cleanup - mem_initial
    if mem_diff < 2.0:  # 允许2MB的误差
        print(f"\n✅ 内存清理成功！内存恢复到初始水平（差异: {mem_diff:.2f} MB）")
        return True
    else:
        print(f"\n⚠️  内存未完全释放（差异: {mem_diff:.2f} MB）")
        return False


def test_memory_monitor():
    """测试内存监控器"""
    print("\n" + "="*80)
    print("测试内存监控器")
    print("="*80)
    
    with MemoryMonitor("测试任务", verbose=True) as monitor:
        # 模拟任务
        print("\n执行任务...")
        data = [i * 2 for i in range(500000)]
        
        monitor.checkpoint("数据创建完成")
        
        # 处理数据
        result = sum(data)
        print(f"计算结果: {result}")
        
        monitor.checkpoint("数据处理完成")
    
    # 监控器退出时会自动清理
    print("\n✅ 内存监控器测试完成")


def test_task_simulation():
    """模拟实际任务的内存使用"""
    print("\n" + "="*80)
    print("模拟实际任务")
    print("="*80)
    
    mem_start = MemoryManager.get_memory_usage()
    print(f"\n任务开始前内存: {mem_start:.2f} MB")
    
    # 模拟读取CSV文件
    print("\n步骤1: 读取数据...")
    headers = ["col" + str(i) for i in range(100)]
    rows = [[j for j in range(100)] for i in range(5000)]
    
    mem_after_read = MemoryManager.get_memory_usage()
    print(f"读取后内存: {mem_after_read:.2f} MB (增长: {mem_after_read - mem_start:.2f} MB)")
    
    # 模拟处理数据
    print("\n步骤2: 处理数据...")
    processed = []
    for row in rows:
        processed.append([x * 2 for x in row])
    
    mem_after_process = MemoryManager.get_memory_usage()
    print(f"处理后内存: {mem_after_process:.2f} MB (增长: {mem_after_process - mem_start:.2f} MB)")
    
    # 清理中间数据
    print("\n步骤3: 清理中间数据...")
    cleanup_large_objects(rows, processed)
    
    mem_after_cleanup = MemoryManager.get_memory_usage()
    print(f"清理后内存: {mem_after_cleanup:.2f} MB")
    print(f"释放内存: {mem_after_process - mem_after_cleanup:.2f} MB")
    
    # 最终清理
    print("\n步骤4: 最终清理...")
    cleanup_large_objects(headers)
    MemoryManager.force_gc()
    
    mem_final = MemoryManager.get_memory_usage()
    print(f"最终内存: {mem_final:.2f} MB")
    print(f"总内存增长: {mem_final - mem_start:.2f} MB")
    
    if mem_final - mem_start < 5.0:
        print(f"\n✅ 任务完成，内存正常释放")
        return True
    else:
        print(f"\n⚠️  任务完成，但内存未完全释放")
        return False


if __name__ == "__main__":
    print("\n" + "="*80)
    print("MyDataCheck 内存清理测试")
    print("="*80 + "\n")
    
    results = []
    
    # 测试1: 基本清理功能
    results.append(("基本清理", test_memory_cleanup()))
    
    # 等待一下
    time.sleep(1)
    
    # 测试2: 内存监控器
    test_memory_monitor()
    results.append(("监控器", True))
    
    # 等待一下
    time.sleep(1)
    
    # 测试3: 任务模拟
    results.append(("任务模拟", test_task_simulation()))
    
    # 总结
    print("\n" + "="*80)
    print("测试总结")
    print("="*80)
    
    for test_name, passed in results:
        status = "✅ 通过" if passed else "❌ 失败"
        print(f"  {test_name}: {status}")
    
    all_passed = all(result[1] for result in results)
    
    if all_passed:
        print(f"\n✅ 所有测试通过！内存清理功能正常")
    else:
        print(f"\n⚠️  部分测试未通过，请检查")
    
    print("\n" + "="*80 + "\n")
