#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
测试值比较器的基本功能（不依赖外部模块）
"""

import sys
import os

# 添加项目根目录到路径
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from common.value_comparator import compare_values


def test_basic_comparisons():
    """测试基本的值比较功能"""
    print("=" * 60)
    print("测试基本值比较功能")
    print("=" * 60)
    
    test_cases = [
        # (csv_value, api_value, expected, description)
        (123, 123, True, "整数相等"),
        (123.456, 123.456, True, "浮点数相等"),
        ("123", 123, True, "字符串数字与整数相等"),
        ("123.456", 123.456, True, "字符串数字与浮点数相等"),
        (8, 8.0, True, "整数与浮点数相等"),
        ("8", "8.0", True, "字符串整数与字符串浮点数相等"),
        (None, None, True, "null与null相等"),
        ("null", None, True, "字符串null与None相等"),
        ("", None, True, "空字符串与None相等"),
        (123, 456, False, "不同整数不相等"),
        (123, None, False, "数字与null不相等"),
        ("abc", "def", False, "不同字符串不相等"),
    ]
    
    passed = 0
    failed = 0
    
    for csv_val, api_val, expected, description in test_cases:
        result = compare_values(csv_val, api_val)
        if result == expected:
            print(f"✅ PASS: {description}")
            passed += 1
        else:
            print(f"❌ FAIL: {description}")
            print(f"   CSV: {csv_val}, API: {api_val}")
            print(f"   期望: {expected}, 实际: {result}")
            failed += 1
    
    print(f"\n总计: {passed} 通过, {failed} 失败\n")
    return failed == 0


def test_scientific_notation_basic():
    """测试科学计数法基本功能"""
    print("=" * 60)
    print("测试科学计数法基本功能")
    print("=" * 60)
    
    test_cases = [
        ("0E-8", 0, True, "0E-8 等于 0"),
        ("1E-5", 0.00001, True, "1E-5 等于 0.00001"),
        ("1.23E2", 123, True, "1.23E2 等于 123"),
    ]
    
    passed = 0
    failed = 0
    
    for csv_val, api_val, expected, description in test_cases:
        result = compare_values(csv_val, api_val)
        if result == expected:
            print(f"✅ PASS: {description}")
            passed += 1
        else:
            print(f"❌ FAIL: {description}")
            print(f"   CSV: {csv_val}, API: {api_val}")
            print(f"   期望: {expected}, 实际: {result}")
            failed += 1
    
    print(f"\n总计: {passed} 通过, {failed} 失败\n")
    return failed == 0


def main():
    """运行所有测试"""
    print("\n" + "=" * 60)
    print("开始测试值比较器基本功能")
    print("=" * 60 + "\n")
    
    test1_passed = test_basic_comparisons()
    test2_passed = test_scientific_notation_basic()
    
    print("=" * 60)
    if test1_passed and test2_passed:
        print("✅ 所有测试通过！")
        return 0
    else:
        print("❌ 部分测试失败")
        return 1
    print("=" * 60)


if __name__ == "__main__":
    exit(main())
