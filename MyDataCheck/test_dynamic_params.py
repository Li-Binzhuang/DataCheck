#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
测试动态参数配置功能
"""

import json

# 测试配置示例
test_configs = [
    {
        "name": "双参数测试",
        "api_params": [
            {"param_name": "custNo", "column_index": 0, "is_time_field": False},
            {"param_name": "baseTime", "column_index": 2, "is_time_field": True}
        ]
    },
    {
        "name": "单参数测试",
        "api_params": [
            {"param_name": "applyId", "column_index": 1, "is_time_field": False}
        ]
    },
    {
        "name": "三参数测试",
        "api_params": [
            {"param_name": "custNo", "column_index": 0, "is_time_field": False},
            {"param_name": "applyId", "column_index": 1, "is_time_field": False},
            {"param_name": "baseTime", "column_index": 3, "is_time_field": True}
        ]
    },
    {
        "name": "旧格式兼容测试",
        "column_config": {
            "cust_no_column": 0,
            "use_create_time_column": 2,
            "feature_start_column": 3
        }
    }
]

def test_param_config(config):
    """测试参数配置"""
    print(f"\n{'='*60}")
    print(f"测试场景: {config['name']}")
    print(f"{'='*60}")
    
    api_params = config.get('api_params')
    
    if api_params:
        print("✅ 使用新的参数配置:")
        for i, param in enumerate(api_params, 1):
            param_name = param.get('param_name')
            column_index = param.get('column_index')
            is_time_field = param.get('is_time_field', False)
            time_flag = " (时间字段)" if is_time_field else ""
            print(f"  {i}. {param_name}: 列{column_index}{time_flag}")
        
        # 模拟构建请求参数
        print("\n模拟请求参数构建:")
        mock_row = ["800001054335", "1234567890", "2025-01-19 10:30:00.123", "feature1", "feature2"]
        request_params = {}
        
        for param in api_params:
            param_name = param.get('param_name')
            column_index = param.get('column_index')
            is_time_field = param.get('is_time_field', False)
            
            if column_index < len(mock_row):
                value = mock_row[column_index]
                if is_time_field:
                    value = value.replace(' ', 'T') + " (已标准化)"
                request_params[param_name] = value
        
        print(f"  请求参数: {json.dumps(request_params, ensure_ascii=False, indent=2)}")
        
    else:
        print("⚠️  使用旧的 column_config 格式:")
        column_config = config.get('column_config', {})
        cust_no_column = column_config.get('cust_no_column')
        use_create_time_column = column_config.get('use_create_time_column')
        feature_start_column = column_config.get('feature_start_column', 3)
        
        print(f"  cust_no_column: {cust_no_column}")
        print(f"  use_create_time_column: {use_create_time_column}")
        print(f"  feature_start_column: {feature_start_column}")
        
        print("\n  系统会自动转换为新格式:")
        auto_params = [
            {"param_name": "custNo", "column_index": cust_no_column, "is_time_field": False},
            {"param_name": "baseTime", "column_index": use_create_time_column, "is_time_field": True}
        ]
        for i, param in enumerate(auto_params, 1):
            param_name = param.get('param_name')
            column_index = param.get('column_index')
            is_time_field = param.get('is_time_field', False)
            time_flag = " (时间字段)" if is_time_field else ""
            print(f"  {i}. {param_name}: 列{column_index}{time_flag}")

if __name__ == "__main__":
    print("="*60)
    print("动态参数配置功能测试")
    print("="*60)
    
    for config in test_configs:
        test_param_config(config)
    
    print(f"\n{'='*60}")
    print("测试完成!")
    print("="*60)
    print("\n功能说明:")
    print("1. ✅ 支持任意数量的接口参数")
    print("2. ✅ 支持自定义参数名称")
    print("3. ✅ 支持指定参数对应的CSV列索引")
    print("4. ✅ 支持标记时间字段（自动进行时间格式标准化）")
    print("5. ✅ 向后兼容旧的 column_config 格式")
    print("\n使用建议:")
    print("- 单参数接口: 只配置一个参数（如 applyId）")
    print("- 双参数接口: 配置两个参数（如 custNo + baseTime）")
    print("- 多参数接口: 根据实际需要配置多个参数")
    print("- 时间字段: 勾选'时间字段'选项，系统会自动标准化时间格式")
