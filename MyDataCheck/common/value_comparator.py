#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
值比较模块
功能：提供数据值比较逻辑
"""

from typing import Any


def _normalize_scientific_notation(value: Any) -> Any:
    """
    标准化科学计数法表示的极小值
    将类似 0E-8, 0.0E-10 等形式的 0 统一转换为 0
    
    Args:
        value: 输入值
    
    Returns:
        标准化后的值
    """
    if value is None:
        return value
    
    try:
        # 先转换为字符串检查格式
        value_str = str(value).strip().upper()
        
        # 检查是否是 0E-x 或 0.0E-x 格式
        if 'E' in value_str:
            # 尝试转换为浮点数
            num = float(value_str)
            # 如果数值为 0（或非常接近 0），则返回 0
            if abs(num) < 1e-15:
                return 0.0
            return num
        else:
            # 不是科学计数法，直接转换
            num = float(value_str)
            return num
    except (ValueError, TypeError):
        # 无法转换为数字，返回原值
        return value


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

    # 标准化科学计数法表示的极小值（如 0E-8 -> 0）
    csv_value_normalized = _normalize_scientific_notation(csv_value)
    api_value_normalized = _normalize_scientific_notation(api_value)

    # 如果api_value已经是数字类型，直接进行数值比较
    if isinstance(api_value_normalized, (int, float)):
        # api_value已经是数字，尝试将csv_value也转换为数字进行比较
        try:
            csv_num = float(str(csv_value_normalized).strip()) if not isinstance(csv_value_normalized, (int, float)) else csv_value_normalized
            # 使用小的误差范围来处理浮点数精度问题
            if abs(csv_num - api_value_normalized) < 1e-10:
                return True
            # 如果两个数都是整数（或可以表示为整数），进行整数比较
            if csv_num == int(csv_num) and api_value_normalized == int(api_value_normalized):
                return int(csv_num) == int(api_value_normalized)
            # 对于浮点数，直接比较
            return csv_num == api_value_normalized
        except (ValueError, TypeError):
            # csv_value无法转换为数字，则不一致
            return False
    
    # 如果api_value不是数字类型，按字符串比较
    csv_str = str(csv_value_normalized).strip()
    api_str = str(api_value_normalized).strip()

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
