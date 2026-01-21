#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
测试列索引为空时不传参的功能
"""

import json

# 测试配置
test_configs = [
    {
        "name": "测试1: 两个参数都有列索引",
        "api_params": [
            {"param_name": "custNo", "column_index": 0, "is_time_field": False},
            {"param_name": "baseTime", "column_index": 2, "is_time_field": True}
        ],
        "expected_params": ["custNo", "baseTime"]
    },
    {
        "name": "测试2: 只有一个参数有列索引",
        "api_params": [
            {"param_name": "custNo", "column_index": 0, "is_time_field": False},
            {"param_name": "baseTime", "column_index": None, "is_time_field": True}
        ],
        "expected_params": ["custNo"]
    },
    {
        "name": "测试3: 列索引为空字符串",
        "api_params": [
            {"param_name": "applyId", "column_index": 1, "is_time_field": False},
            {"param_name": "baseTime", "column_index": "", "is_time_field": True}
        ],
        "expected_params": ["applyId"]
    },
    {
        "name": "测试4: 三个参数，中间一个为空",
        "api_params": [
            {"param_name": "custNo", "column_index": 0, "is_time_field": False},
            {"param_name": "applyId", "column_index": None, "is_time_field": False},
            {"param_name": "baseTime", "column_index": 3, "is_time_field": True}
        ],
        "expected_params": ["custNo", "baseTime"]
    }
]

def simulate_param_collection(api_params):
    """模拟参数收集逻辑"""
    request_params = []
    
    for param_config in api_params:
        param_name = param_config.get("param_name")
        column_index = param_config.get("column_index")
        is_time_field = param_config.get("is_time_field", False)
        
        # 如果列索引为 None 或空字符串，跳过该参数
        if column_index is None or column_index == "":
            print(f"  ⏭️  跳过参数 '{param_name}' (列索引为空)")
            continue
        
        # 检查列索引是否有效
        if not isinstance(column_index, int) or column_index < 0:
            print(f"  ❌ 参数 '{param_name}' 的列索引无效: {column_index}")
            continue
        
        time_flag = " (时间字段)" if is_time_field else ""
        print(f"  ✅ 添加参数 '{param_name}': 列{column_index}{time_flag}")
        request_params.append(param_name)
    
    return request_params

def test_config(config):
    """测试配置"""
    print(f"\n{'='*60}")
    print(f"{config['name']}")
    print(f"{'='*60}")
    
    api_params = config['api_params']
    expected_params = config['expected_params']
    
    print("配置的参数:")
    for param in api_params:
        param_name = param.get('param_name')
        column_index = param.get('column_index')
        is_time_field = param.get('is_time_field', False)
        time_flag = " (时间字段)" if is_time_field else ""
        col_display = f"列{column_index}" if column_index is not None and column_index != "" else "(空)"
        print(f"  - {param_name}: {col_display}{time_flag}")
    
    print("\n处理结果:")
    actual_params = simulate_param_collection(api_params)
    
    print(f"\n预期传递的参数: {expected_params}")
    print(f"实际传递的参数: {actual_params}")
    
    if actual_params == expected_params:
        print("✅ 测试通过!")
    else:
        print("❌ 测试失败!")
    
    return actual_params == expected_params

if __name__ == "__main__":
    print("="*60)
    print("测试列索引为空时不传参的功能")
    print("="*60)
    
    passed = 0
    failed = 0
    
    for config in test_configs:
        if test_config(config):
            passed += 1
        else:
            failed += 1
    
    print(f"\n{'='*60}")
    print(f"测试结果: 通过 {passed}/{len(test_configs)}, 失败 {failed}/{len(test_configs)}")
    print("="*60)
    
    if failed == 0:
        print("\n✅ 所有测试通过!")
        print("\n功能说明:")
        print("1. ✅ 列索引为 None 时，该参数不作为入参传递")
        print("2. ✅ 列索引为空字符串时，该参数不作为入参传递")
        print("3. ✅ 只有有效的列索引才会被添加到请求参数中")
        print("4. ✅ 支持灵活配置，可以选择性传递参数")
    else:
        print(f"\n❌ 有 {failed} 个测试失败")
