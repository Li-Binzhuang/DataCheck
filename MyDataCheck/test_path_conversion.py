#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
测试PKL文件路径转换逻辑
"""

def test_path_conversion():
    """测试路径转换逻辑"""
    
    test_cases = [
        {
            'input': 'MyDataCheck/inputdata/api_comparison/test.pkl',
            'expected': 'MyDataCheck/outputdata/api_comparison/test.csv',
            'description': '接口对比PKL文件'
        },
        {
            'input': 'MyDataCheck/inputdata/online_comparison/data.pkl',
            'expected': 'MyDataCheck/outputdata/online_comparison/data.csv',
            'description': '线上对比PKL文件'
        },
        {
            'input': '/tmp/test.pkl',
            'expected': '/tmp/test.csv',
            'description': '无inputdata路径的文件'
        },
        {
            'input': 'data/inputdata/test.pkl',
            'expected': 'data/outputdata/test.csv',
            'description': '包含inputdata的其他路径'
        }
    ]
    
    print("="*80)
    print("PKL文件路径转换逻辑测试")
    print("="*80)
    
    all_passed = True
    
    for i, case in enumerate(test_cases, 1):
        pkl_path = case['input']
        expected = case['expected']
        
        # 模拟转换逻辑
        if 'inputdata' in pkl_path:
            result = pkl_path.replace('inputdata', 'outputdata').rsplit('.', 1)[0] + '.csv'
        else:
            result = pkl_path.rsplit('.', 1)[0] + '.csv'
        
        passed = result == expected
        all_passed = all_passed and passed
        
        status = "✅ 通过" if passed else "❌ 失败"
        print(f"\n测试 {i}: {case['description']}")
        print(f"  输入: {pkl_path}")
        print(f"  期望: {expected}")
        print(f"  结果: {result}")
        print(f"  状态: {status}")
    
    print("\n" + "="*80)
    if all_passed:
        print("✅ 所有测试通过!")
    else:
        print("❌ 部分测试失败!")
    print("="*80)
    
    return all_passed


if __name__ == '__main__':
    test_path_conversion()
