#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
数据格式化模块
功能：提供数据值格式化功能，特别是时间字段的格式化
"""

import re


def format_value_for_excel(value: str, header: str) -> str:
    """
    格式化值以便在Excel/WPS中正确显示
    对于时间字段，添加制表符前缀以防止被识别为时间类型
    
    Args:
        value: 要格式化的值
        header: 字段名
        
    Returns:
        格式化后的值
    """
    if not value or value == "null":
        return value
    
    # 检测是否是时间字段（字段名包含time或date）
    header_lower = header.lower()
    is_time_field = "time" in header_lower or "date" in header_lower
    
    # 检测值是否是时间格式（YYYY-MM-DD HH:MM:SS或类似格式）
    is_time_format = False
    if isinstance(value, str) and len(value) >= 10:
        # 检查是否匹配时间格式：YYYY-MM-DD 或 YYYY-MM-DD HH:MM:SS
        time_pattern = r'^\d{4}-\d{2}-\d{2}(\s+\d{2}:\d{2}:\d{2}(\.\d+)?)?'
        if re.match(time_pattern, value.strip()):
            is_time_format = True
    
    # 如果是时间字段或时间格式，添加制表符前缀（强制Excel/WPS识别为文本）
    if is_time_field or is_time_format:
        return "\t" + str(value)
    
    return str(value)
