#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
测试批次大小配置的保存和加载
"""

import json
import os
import sys

# 添加父目录到路径
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))


def test_batch_size_config():
    """测试批次大小配置"""
    
    config_path = os.path.join(os.path.dirname(__file__), '..', 'api_comparison', 'config.json')
    
    print("=" * 80)
    print("测试批次大小配置")
    print("=" * 80)
    
    # 1. 读取当前配置
    print("\n1. 读取当前配置...")
    if os.path.exists(config_path):
        with open(config_path, 'r', encoding='utf-8') as f:
            config = json.load(f)
        
        print(f"   配置文件: {config_path}")
        print(f"   global_config.default_batch_size: {config.get('global_config', {}).get('default_batch_size', '未设置')}")
        
        if 'scenarios' in config:
            for i, scenario in enumerate(config['scenarios']):
                print(f"   场景{i+1} ({scenario.get('name', '未命名')}).batch_size: {scenario.get('batch_size', '未设置')}")
    else:
        print(f"   ❌ 配置文件不存在: {config_path}")
        return False
    
    # 2. 测试配置结构
    print("\n2. 测试配置结构...")
    
    # 检查全局配置
    if 'global_config' not in config:
        print("   ❌ 缺少 global_config")
        return False
    
    global_config = config['global_config']
    
    # 检查批次大小配置
    if 'default_batch_size' in global_config:
        batch_size = global_config['default_batch_size']
        print(f"   ✅ 全局批次大小: {batch_size}")
        
        # 验证批次大小范围
        if not isinstance(batch_size, int):
            print(f"   ❌ 批次大小类型错误: {type(batch_size)}")
            return False
        
        if batch_size < 1 or batch_size > 1000:
            print(f"   ⚠️  批次大小超出建议范围 (1-1000): {batch_size}")
        elif batch_size < 50 or batch_size > 200:
            print(f"   ⚠️  批次大小超出推荐范围 (50-200): {batch_size}")
        else:
            print(f"   ✅ 批次大小在推荐范围内")
    else:
        print("   ⚠️  未设置 default_batch_size，将使用默认值 50")
    
    # 检查场景配置
    if 'scenarios' in config:
        print(f"\n3. 检查场景配置 ({len(config['scenarios'])} 个场景)...")
        
        for i, scenario in enumerate(config['scenarios']):
            scenario_name = scenario.get('name', f'场景{i+1}')
            
            if 'batch_size' in scenario:
                batch_size = scenario['batch_size']
                print(f"   ✅ {scenario_name}: batch_size = {batch_size}")
                
                # 验证批次大小
                if not isinstance(batch_size, int):
                    print(f"      ❌ 批次大小类型错误: {type(batch_size)}")
                    return False
                
                if batch_size < 1 or batch_size > 1000:
                    print(f"      ⚠️  批次大小超出建议范围: {batch_size}")
            else:
                print(f"   ⚠️  {scenario_name}: 未设置 batch_size，将使用全局配置")
    
    # 4. 测试配置的完整性
    print("\n4. 测试配置完整性...")
    
    required_fields = ['scenarios', 'global_config']
    missing_fields = [field for field in required_fields if field not in config]
    
    if missing_fields:
        print(f"   ❌ 缺少必需字段: {', '.join(missing_fields)}")
        return False
    else:
        print("   ✅ 配置结构完整")
    
    print("\n" + "=" * 80)
    print("✅ 批次大小配置测试通过")
    print("=" * 80)
    
    return True


def test_streaming_comparator_batch_size():
    """测试流式对比器的批次大小参数"""
    
    print("\n" + "=" * 80)
    print("测试流式对比器批次大小参数")
    print("=" * 80)
    
    try:
        from api_comparison.job.streaming_comparator import StreamingComparator
        
        # 测试默认批次大小
        print("\n1. 测试默认批次大小...")
        comparator = StreamingComparator(
            api_url="http://example.com/api",
            param1_column=0,
            param2_column=2,
            feature_start_column=3
        )
        
        print(f"   默认批次大小: {comparator.batch_size}")
        
        if comparator.batch_size == 50:
            print("   ✅ 默认批次大小正确 (50)")
        else:
            print(f"   ❌ 默认批次大小错误，期望 50，实际 {comparator.batch_size}")
            return False
        
        # 测试自定义批次大小
        print("\n2. 测试自定义批次大小...")
        test_sizes = [1, 50, 100, 200, 1000]
        
        for size in test_sizes:
            comparator = StreamingComparator(
                api_url="http://example.com/api",
                param1_column=0,
                param2_column=2,
                feature_start_column=3,
                batch_size=size
            )
            
            if comparator.batch_size == size:
                print(f"   ✅ 批次大小 {size}: 正确")
            else:
                print(f"   ❌ 批次大小 {size}: 错误，实际 {comparator.batch_size}")
                return False
        
        print("\n" + "=" * 80)
        print("✅ 流式对比器批次大小参数测试通过")
        print("=" * 80)
        
        return True
        
    except Exception as e:
        print(f"\n❌ 测试失败: {str(e)}")
        import traceback
        traceback.print_exc()
        return False


if __name__ == '__main__':
    print("\n开始测试批次大小配置...\n")
    
    # 测试配置文件
    test1_passed = test_batch_size_config()
    
    # 测试流式对比器
    test2_passed = test_streaming_comparator_batch_size()
    
    # 总结
    print("\n" + "=" * 80)
    print("测试总结")
    print("=" * 80)
    print(f"配置文件测试: {'✅ 通过' if test1_passed else '❌ 失败'}")
    print(f"流式对比器测试: {'✅ 通过' if test2_passed else '❌ 失败'}")
    
    if test1_passed and test2_passed:
        print("\n🎉 所有测试通过！")
        sys.exit(0)
    else:
        print("\n❌ 部分测试失败")
        sys.exit(1)
