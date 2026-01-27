#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
测试引号去除功能
"""

from typing import Any


def _convert_string_to_number(value: Any) -> Any:
    """
    尝试将字符串转换为数值类型，并去除多余的引号
    
    Args:
        value: 输入值
    
    Returns:
        如果可以转换为数值，返回数值；否则返回去除引号后的字符串
    """
    if value is None or value == "":
        return value
    
    # 如果已经是数值类型，直接返回
    if isinstance(value, (int, float)):
        return value
    
    # 转换为字符串并去除空格
    str_value = str(value).strip()
    
    # 处理空字符串
    if not str_value:
        return value
    
    # 循环去除字符串两端的所有双引号和单引号
    # 例如: "8" -> 8, '8' -> 8, ""8"" -> 8, 65450"" -> 65450
    while len(str_value) >= 2:
        # 检查并去除两端的引号
        if (str_value[0] == '"' and str_value[-1] == '"') or \
           (str_value[0] == "'" and str_value[-1] == "'"):
            str_value = str_value[1:-1].strip()
        # 检查并去除末尾的多余引号（如 65450""）
        elif str_value.endswith('"') or str_value.endswith("'"):
            str_value = str_value[:-1].strip()
        # 检查并去除开头的多余引号
        elif str_value.startswith('"') or str_value.startswith("'"):
            str_value = str_value[1:].strip()
        else:
            # 没有引号了，退出循环
            break
    
    # 再次检查是否为空
    if not str_value:
        return value
    
    # 尝试转换为数值
    try:
        # 先尝试转换为浮点数
        float_value = float(str_value)
        # 如果浮点数等于其整数形式，返回整数
        if float_value == int(float_value):
            return int(float_value)
        # 否则返回浮点数
        return float_value
    except (ValueError, TypeError):
        # 无法转换为数值，返回去除引号后的字符串
        return str_value


# 测试用例
test_cases = [
    # (输入值, 期望输出, 描述)
    ("8", 8, "普通字符串数字"),
    ('"8"', 8, "带双引号的字符串数字"),
    ("'8'", 8, "带单引号的字符串数字"),
    ('65450""', 65450, "末尾有两个双引号的数字"),
    ('""65450', 65450, "开头有两个双引号的数字"),
    ('""65450""', 65450, "两端都有两个双引号的数字"),
    ('"65450"', 65450, "带一对双引号的数字"),
    ('65450"', 65450, "末尾有一个双引号的数字"),
    ('"65450', 65450, "开头有一个双引号的数字"),
    ('"""8"""', 8, "三层引号的数字"),
    ("8.5", 8.5, "字符串浮点数"),
    ('"8.5""', 8.5, "带多余引号的浮点数"),
    ("", "", "空字符串"),
    (None, None, "None值"),
    ("abc", "abc", "非数字字符串"),
    ('"abc"', "abc", "带双引号的非数字字符串"),
    ('abc""', "abc", "末尾有双引号的非数字字符串"),
    ("  8  ", 8, "带空格的字符串数字"),
    ('"  8  ""', 8, "带双引号、空格和多余引号的数字"),
    (8, 8, "整数"),
    (8.0, 8.0, "浮点数"),
]

print("=" * 80)
print("引号去除功能测试")
print("=" * 80)

all_passed = True
failed_cases = []

for i, (input_val, expected, description) in enumerate(test_cases, 1):
    result = _convert_string_to_number(input_val)
    passed = result == expected
    all_passed = all_passed and passed
    
    status = "✅ 通过" if passed else "❌ 失败"
    
    if not passed:
        failed_cases.append((i, description, input_val, expected, result))
    
    print(f"\n测试 {i}: {description}")
    print(f"  输入: {repr(input_val)}")
    print(f"  期望: {repr(expected)} (类型: {type(expected).__name__})")
    print(f"  结果: {repr(result)} (类型: {type(result).__name__})")
    print(f"  {status}")

print("\n" + "=" * 80)
if all_passed:
    print("✅ 所有测试通过！")
else:
    print(f"❌ {len(failed_cases)} 个测试失败！")
    print("\n失败的测试：")
    for test_num, desc, input_val, expected, result in failed_cases:
        print(f"  测试 {test_num}: {desc}")
        print(f"    输入: {repr(input_val)}")
        print(f"    期望: {repr(expected)}, 实际: {repr(result)}")
print("=" * 80)

# 特别测试：你提到的具体案例
print("\n" + "=" * 80)
print("特别测试：实际案例")
print("=" * 80)

actual_case = '65450""'
result = _convert_string_to_number(actual_case)
print(f"\n输入: {repr(actual_case)}")
print(f"输出: {repr(result)} (类型: {type(result).__name__})")
print(f"是否为数字: {isinstance(result, (int, float))}")
print(f"是否等于65450: {result == 65450}")

if result == 65450:
    print("\n✅ 实际案例测试通过！")
else:
    print(f"\n❌ 实际案例测试失败！期望 65450，得到 {repr(result)}")

print("=" * 80)
