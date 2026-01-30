#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
测试科学计数法极小值处理
"""

import sys
import os

# 添加项目根目录到路径
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from common.value_comparator import compare_values, _normalize_scientific_notation


def test_normalize_scientific_notation():
    """测试科学计数法标准化函数"""
    print("=" * 60)
    print("测试科学计数法标准化函数")
    print("=" * 60)
    
    test_cases = [
        ("0E-8", 0.0, "0E-8 应该转换为 0"),
        ("0.0E-10", 0.0, "0.0E-10 应该转换为 0"),
        ("1E-20", 0.0, "1E-20 (极小值) 应该转换为 0"),
        ("1E-5", 1e-5, "1E-5 应该保持原值"),
        ("0.00000001", 1e-8, "0.00000001 (小数格式) 应该保持原值"),
        ("0.0000000001", 1e-10, "0.0000000001 (小数格式) 应该保持原值"),
        ("0.00001", 0.00001, "0.00001 (1E-5) 应该保持原值"),
        ("123.456", 123.456, "正常数值应该保持原值"),
        ("0", 0.0, "0 应该保持为 0"),
        ("0.0", 0.0, "0.0 应该保持为 0"),
        ("1e-8", 1e-8, "1e-8 (小写科学计数法) 应该保持原值"),
        ("0e-8", 0.0, "0e-8 (小写) 应该转换为 0"),
    ]
    
    passed = 0
    failed = 0
    
    for input_val, expected, description in test_cases:
        result = _normalize_scientific_notation(input_val)
        if abs(result - expected) < 1e-15:
            print(f"✅ PASS: {description}")
            print(f"   输入: {input_val} -> 输出: {result}")
            passed += 1
        else:
            print(f"❌ FAIL: {description}")
            print(f"   输入: {input_val} -> 期望: {expected}, 实际: {result}")
            failed += 1
    
    print(f"\n总计: {passed} 通过, {failed} 失败\n")
    return failed == 0


def test_compare_values_with_scientific_notation():
    """测试带科学计数法的值比较"""
    print("=" * 60)
    print("测试带科学计数法的值比较")
    print("=" * 60)
    
    test_cases = [
        # (csv_value, api_value, expected_result, description)
        ("0E-8", 0, True, "CSV中的0E-8应该等于接口的0"),
        ("0E-8", 0.0, True, "CSV中的0E-8应该等于接口的0.0"),
        ("0.0E-10", 0, True, "CSV中的0.0E-10应该等于接口的0"),
        ("1E-20", 0, True, "CSV中的1E-20(极小值)应该等于接口的0"),
        ("0.00000001", 0, False, "CSV中的0.00000001(小数格式)不应该等于接口的0"),
        ("0E-8", None, False, "CSV中的0E-8不应该等于接口的null"),
        ("0E-8", "null", False, "CSV中的0E-8不应该等于接口的'null'字符串"),
        ("123.456", 123.456, True, "正常数值应该相等"),
        ("0", 0, True, "0应该等于0"),
        ("0.0", 0, True, "0.0应该等于0"),
        ("1E-5", 0.00001, True, "1E-5应该等于0.00001"),
        ("1E-5", 0, False, "1E-5不应该等于0（不够小）"),
        ("0e-8", 0, True, "CSV中的0e-8(小写)应该等于接口的0"),
        ("0.0e-10", 0, True, "CSV中的0.0e-10(小写)应该等于接口的0"),
    ]
    
    passed = 0
    failed = 0
    
    for csv_val, api_val, expected, description in test_cases:
        result = compare_values(csv_val, api_val)
        if result == expected:
            print(f"✅ PASS: {description}")
            print(f"   CSV: {csv_val}, API: {api_val} -> 结果: {result}")
            passed += 1
        else:
            print(f"❌ FAIL: {description}")
            print(f"   CSV: {csv_val}, API: {api_val} -> 期望: {expected}, 实际: {result}")
            failed += 1
    
    print(f"\n总计: {passed} 通过, {failed} 失败\n")
    return failed == 0


def main():
    """运行所有测试"""
    print("\n" + "=" * 60)
    print("开始测试科学计数法极小值处理功能")
    print("=" * 60 + "\n")
    
    test1_passed = test_normalize_scientific_notation()
    test2_passed = test_compare_values_with_scientific_notation()
    
    print("=" * 60)
    if test1_passed and test2_passed:
        print("✅ 所有测试通过！")
    else:
        print("❌ 部分测试失败，请检查")
    print("=" * 60)


if __name__ == "__main__":
    main()
