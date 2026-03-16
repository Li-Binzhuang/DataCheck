#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
JSON解析器模块
功能：解析CSV文件中指定列的JSON字符串，输出为特征CSV文件
"""

import json
import os
import sys
from typing import Any, Dict, List

# 添加公共工具目录到路径
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../../common'))
from csv_tool import read_csv_with_encoding, write_csv_file


def _convert_string_to_number(value: Any) -> Any:
    """
    将字符串转换为数值类型
    
    Args:
        value: 要转换的值
        
    Returns:
        转换后的数值，如果无法转换则返回原值
    """
    if value is None:
        return None
    
    if isinstance(value, (int, float)):
        return value
    
    if isinstance(value, str):
        value = value.strip()
        
        # 处理空值
        if value == "" or value.lower() in ["null", "none", "nan"]:
            return None
        
        # 尝试转换为整数
        try:
            # 移除可能的千分位分隔符
            value_clean = value.replace(",", "").replace(" ", "")
            if "." in value_clean:
                return float(value_clean)
            else:
                return int(value_clean)
        except (ValueError, TypeError):
            # 无法转换为数字，返回原值
            return value
    
    return value


def extract_features_from_data(d: Dict[str, Any]) -> Dict[str, Any]:
    """
    从data字典中提取特征数据
    
    如果data中包含features字段，则解析features；否则直接返回data
    
    Args:
        d: 数据字典（可能是直接的特征，也可能包含features子字段）
    
    Returns:
        特征字典
    """
    if d is None or not isinstance(d, dict):
        return {}
    
    # 检查是否存在features字段
    if 'features' in d:
        features = d['features']
        if isinstance(features, dict):
            return features
        elif isinstance(features, list):
            # 如果features是列表，尝试合并所有字典
            merged = {}
            for item in features:
                if isinstance(item, dict):
                    merged.update(item)
            return merged
        else:
            # features不是字典或列表，返回原始data（排除features字段）
            return {k: v for k, v in d.items() if k != 'features'}
    
    # 没有features字段，直接返回data
    return d


def flatten_dict(d: Dict[str, Any], convert_to_number: bool = False) -> Dict[str, Any]:
    """
    打平嵌套字典
    
    Args:
        d: 嵌套字典
        convert_to_number: 是否将字符串值转换为数值
    """
    if d is None or not isinstance(d, dict):
        return {}
    
    items = []
    for k, v in d.items():
        clean_key = k
        
        if isinstance(v, dict):
            # 如果值是字典，递归打平
            flattened = flatten_dict(v, convert_to_number)
            if flattened:
                items.extend(flattened.items())
            else:
                items.append((clean_key, v))
        else:
            # 如果需要转换字符串为数值
            if convert_to_number and isinstance(v, str):
                v = _convert_string_to_number(v)
            items.append((clean_key, v))
    
    return dict(items)


def parse_json_to_csv(
    input_csv_path: str,
    output_csv_path: str,
    json_column: str,
    key_column_index = 0,
    convert_string_to_number: bool = False
):
    """
    解析CSV文件中指定列的JSON字符串，输出为特征CSV文件
    
    Args:
        input_csv_path: 输入CSV文件路径
        output_csv_path: 输出CSV文件路径
        json_column: JSON列名
        key_column_index: 主键列索引（支持 int 或 list[int]，用于标识每一行）
        convert_string_to_number: 是否将JSON中的字符串值转换为数值
    
    Returns:
        输出文件路径
    """
    # 统一转换为列表格式
    if isinstance(key_column_index, list):
        key_indices = key_column_index
    else:
        key_indices = [key_column_index]
    
    print(f"步骤1: 开始解析JSON数据")
    print(f"输入文件: {input_csv_path}")
    print(f"输出文件: {output_csv_path}")
    print(f"JSON列: {json_column}")
    print(f"主键列索引: {key_indices} ({'组合主键' if len(key_indices) > 1 else '单主键'})")
    print(f"字符串转数值: {convert_string_to_number}")
    
    # 读取CSV文件
    base_headers, rows = read_csv_with_encoding(input_csv_path)
    
    print(f"读取完成，共 {len(rows)} 行数据")
    print(f"基础列: {base_headers}")
    
    # 找到JSON列的索引
    json_column_index = None
    
    for i, header in enumerate(base_headers):
        if header == json_column:
            json_column_index = i
            break
    
    if json_column_index is None:
        raise ValueError(f"未找到JSON列: {json_column}")
    
    # 验证主键列索引是否有效
    for idx in key_indices:
        if idx < 0 or idx >= len(base_headers):
            raise ValueError(f"主键列索引无效: {idx}，文件共有 {len(base_headers)} 列")
    
    key_column_names = [base_headers[idx] for idx in key_indices]
    print(f"JSON列索引: {json_column_index} ({json_column})")
    print(f"主键列: {', '.join([f'索引{idx}({name})' for idx, name in zip(key_indices, key_column_names)])}")
    
    # 解析JSON并收集所有特征字段
    all_feature_keys = set()
    parsed_data = {}  # {apply_id: {基础字段和特征字段}}
    
    print(f"\n开始解析JSON字段...")
    for row_index, row in enumerate(rows):
        if row_index % 1000 == 0:
            print(f"已处理: {row_index}/{len(rows)}")
        
        # 构建组合主键值（支持多列）
        key_parts = []
        for idx in key_indices:
            if idx >= len(row):
                key_parts.append("")
            else:
                key_parts.append(row[idx].strip() if row[idx] else "")
        apply_id = "|".join(key_parts)
        
        # 如果所有主键列都为空，跳过
        if all(p == "" for p in key_parts):
            continue
        
        # 获取基础信息（除了JSON列）
        base_data = {}
        for i, header in enumerate(base_headers):
            if i != json_column_index:
                value = row[i] if i < len(row) else ""
                base_data[header] = value
        
        # 解析JSON字段
        json_str = row[json_column_index] if json_column_index < len(row) else ""
        
        # 如果JSON字段为空或null，跳过该行
        if not json_str or not json_str.strip() or json_str.strip().lower() in ["null", "none"]:
            continue
        
        try:
            # 解析JSON字符串
            json_obj = json.loads(json_str)
            
            # 检查json_obj是否为None或不是字典类型
            if json_obj is None or not isinstance(json_obj, dict):
                if json_obj is not None:
                    # 获取前三列数据和字段名
                    first_three_cols = []
                    for i in range(min(3, len(base_headers))):
                        col_name = base_headers[i]
                        col_value = row[i] if i < len(row) else ""
                        first_three_cols.append(f"{col_name}={col_value}")
                    cols_info = ", ".join(first_three_cols)
                    print(f"警告: 第 {row_index + 2} 行JSON解析结果不是字典类型: {type(json_obj)}，跳过该行 [{cols_info}]")
                continue
            
            # 从data中提取特征（如果存在features字段则解析features，否则直接使用data）
            feature_data = extract_features_from_data(json_obj)
            
            # 打平嵌套字典
            flattened = flatten_dict(feature_data, convert_string_to_number)
            
            # 收集所有特征字段
            all_feature_keys.update(flattened.keys())
            
            # 合并基础信息和特征
            merged_data = {**base_data, **flattened}
            parsed_data[apply_id] = merged_data
            
        except json.JSONDecodeError as e:
            # 获取前三列数据和字段名
            first_three_cols = []
            for i in range(min(3, len(base_headers))):
                col_name = base_headers[i]
                col_value = row[i] if i < len(row) else ""
                first_three_cols.append(f"{col_name}={col_value}")
            cols_info = ", ".join(first_three_cols)
            print(f"警告: 第 {row_index + 2} 行JSON解析失败: {str(e)}，跳过该行 [{cols_info}]")
            continue
        except Exception as e:
            # 获取前三列数据和字段名
            first_three_cols = []
            for i in range(min(3, len(base_headers))):
                col_name = base_headers[i]
                col_value = row[i] if i < len(row) else ""
                first_three_cols.append(f"{col_name}={col_value}")
            cols_info = ", ".join(first_three_cols)
            print(f"警告: 第 {row_index + 2} 行处理JSON时发生错误: {str(e)}，跳过该行 [{cols_info}]")
            continue
    
    print(f"\n解析完成，共发现 {len(all_feature_keys)} 个特征字段，共 {len(parsed_data)} 行数据")
    
    # 构建完整的表头（基础列 + 特征列，按字母顺序排序）
    feature_keys_sorted = sorted(all_feature_keys)
    all_headers = []
    
    # 先添加基础列（排除JSON列）
    for header in base_headers:
        if header != json_column:
            all_headers.append(header)
    
    # 再添加特征列
    all_headers.extend(feature_keys_sorted)
    
    print(f"总列数: {len(all_headers)} (基础列: {len(base_headers) - 1}, 特征列: {len(feature_keys_sorted)})")
    
    # 准备写入数据（按apply_id排序）
    output_rows = []
    sorted_apply_ids = sorted(parsed_data.keys())
    
    for apply_id in sorted_apply_ids:
        parsed_row = parsed_data[apply_id]
        row_data = []
        for header in all_headers:
            value = parsed_row.get(header, "")
            # 将None转换为空字符串
            if value is None:
                value = ""
            row_data.append(str(value))
        output_rows.append(row_data)
    
    # 写入新的CSV文件
    print(f"\n开始写入输出文件: {output_csv_path}")
    write_csv_file(output_csv_path, all_headers, output_rows)
    
    print(f"JSON解析完成: {output_csv_path}")
    print(f"共写入 {len(output_rows)} 行数据")
    
    return output_csv_path
