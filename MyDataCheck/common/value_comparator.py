#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
值比较模块
功能：提供数据值比较逻辑
"""

from typing import Any


def compare_values(csv_value: Any, api_value: Any, header: str = "") -> bool:
    """
    比较CSV值和接口值是否一致

    Args:
        csv_value: CSV中的值
        api_value: 接口返回的值
        header: 字段名（用于特殊处理）

    Returns:
        如果一致返回True，否则返回False
    """
    # 处理空值和null值
    csv_str_check = str(csv_value).strip().lower() if csv_value is not None else ""
    csv_null = csv_value is None or csv_str_check in ["null", "none", ""]

    api_str_check = str(api_value).strip().lower() if api_value is not None else ""
    api_null = api_value is None or api_str_check in ["null", "none", ""]

    # 如果CSV值为null且API值也为null，则认为一致
    if csv_null and api_null:
        return True

    # 如果其中一个为null，另一个不为null，则认为不一致
    if csv_null or api_null:
        return False

    # 如果api_value已经是数字类型，直接进行数值比较
    if isinstance(api_value, (int, float)):
        # api_value已经是数字，尝试将csv_value也转换为数字进行比较
        try:
            csv_num = float(str(csv_value).strip())
            # 使用小的误差范围来处理浮点数精度问题
            if abs(csv_num - api_value) < 1e-10:
                return True
            # 如果两个数都是整数（或可以表示为整数），进行整数比较
            if csv_num == int(csv_num) and api_value == int(api_value):
                return int(csv_num) == int(api_value)
            # 对于浮点数，直接比较
            return csv_num == api_value
        except (ValueError, TypeError):
            # csv_value无法转换为数字，则不一致
            return False
    
    # 如果api_value不是数字类型，按字符串比较
    csv_str = str(csv_value).strip()
    api_str = str(api_value).strip()

    # 先尝试将两个值转换为数字进行比较
    try:
        csv_num = float(csv_str)
        api_num = float(api_str)
        
        # 优化数值比较：处理整数和浮点数表示相同数值的情况（如 8 和 8.0）
        # 使用小的误差范围来处理浮点数精度问题
        if abs(csv_num - api_num) < 1e-10:
            return True
        
        # 如果两个数都是整数（或可以表示为整数），进行整数比较
        if csv_num == int(csv_num) and api_num == int(api_num):
            return int(csv_num) == int(api_num)
        
        # 对于浮点数，直接比较
        return csv_num == api_num
    except (ValueError, TypeError):
        # 如果无法转换为数字，则按字符串比较
        return csv_str == api_str
