#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
数据对比器模块
功能：对比两个CSV文件，以离线文件为基准
"""

import os
import sys
from typing import Any, Dict, List, Tuple

# 添加公共工具目录到路径
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../../common'))
from csv_tool import read_csv_with_encoding
from value_comparator import compare_values


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
    
    # 去除字符串两端的双引号（单引号也一并处理）
    # 例如: "8" -> 8, '"8"' -> 8, "'8'" -> 8, "abc" -> abc
    if len(str_value) >= 2:
        # 去除外层的双引号或单引号
        if (str_value[0] == '"' and str_value[-1] == '"') or \
           (str_value[0] == "'" and str_value[-1] == "'"):
            str_value = str_value[1:-1].strip()
    
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


def compare_csv_files(
    online_file_path: str,
    offline_file_path: str,
    online_key_column_index: int,
    offline_key_column_index: int,
    online_feature_start_column: int = 3,
    offline_feature_start_column: int = 3,
    original_online_file_path: str = None,
    convert_feature_to_number: bool = False,
    enable_tolerance: bool = False,
    tolerance_value: float = 0.000001,
    compare_common_features_only: bool = False
):
    """
    对比两个CSV文件，以离线文件为基准
    
    Args:
        online_file_path: 在线文件路径（第一步生成的CSV）
        offline_file_path: 离线文件路径
        online_key_column_index: 在线文件的主键列索引（从0开始，A列=0，B列=1）
        offline_key_column_index: 离线文件的主键列索引（从0开始，A列=0，B列=1）
        online_feature_start_column: 在线文件特征列起始索引（从0开始）
        offline_feature_start_column: 离线文件特征列起始索引（从0开始）
        original_online_file_path: 原始线上文件路径（用于获取时间字段原值，可选）
        convert_feature_to_number: 是否转换特征值为数值类型（默认False）
        enable_tolerance: 是否启用容错对比（默认False）
        tolerance_value: 容错值（默认0.000001）
        compare_common_features_only: 是否仅对比共有特征（默认False，保持现有逻辑）
    
    Returns:
        (differences_dict, matches_dict, all_features, feature_stats, matched_count,
         unmatched_count, unmatched_rows, headers_online, headers_offline,
         total_comparisons, match_count, diff_count, match_ratio,
         online_only_rows, online_only_count, rows_online, rows_offline)
    """
    print(f"\n步骤2: 开始对比两个CSV文件")
    print(f"在线文件: {online_file_path}")
    print(f"离线文件: {offline_file_path}")
    if original_online_file_path:
        print(f"原始线上文件: {original_online_file_path}")
    print(f"在线文件主键列索引: {online_key_column_index}")
    print(f"离线文件主键列索引: {offline_key_column_index}")
    print(f"在线文件特征列起始索引: {online_feature_start_column}")
    print(f"离线文件特征列起始索引: {offline_feature_start_column}")
    print(f"转换特征值为数值: {convert_feature_to_number}")
    print(f"启用容错对比: {enable_tolerance}")
    if enable_tolerance:
        print(f"容错值: {tolerance_value}")
    print(f"仅对比共有特征: {compare_common_features_only}")
    
    # 读取两个文件
    headers_online, rows_online = read_csv_with_encoding(online_file_path)
    headers_offline, rows_offline = read_csv_with_encoding(offline_file_path)
    
    # 如果提供了原始线上文件路径，读取原始文件用于获取时间字段
    original_online_rows_map = {}  # {key_value: original_row}
    original_online_headers = []
    original_time_idx = None
    
    if original_online_file_path and os.path.exists(original_online_file_path):
        print(f"\n读取原始线上文件以获取时间字段原值...")
        original_online_headers, original_online_rows = read_csv_with_encoding(original_online_file_path)
        
        # 查找原始文件中的时间列
        for i, header in enumerate(original_online_headers):
            header_lower = header.lower()
            if original_time_idx is None and ("time" in header_lower or "date" in header_lower):
                if ("create" in header_lower or "apply" in header_lower or "use_create" in header_lower or 
                    header_lower.endswith("_time") or header_lower.endswith("time")):
                    original_time_idx = i
                    print(f"找到原始线上文件时间列: 索引{original_time_idx} ({header})")
                    break
        
        # 构建主键到原始行的映射
        for row in original_online_rows:
            if online_key_column_index < len(row) and row[online_key_column_index] is not None:
                key_value = str(row[online_key_column_index]).strip()
                if key_value:
                    original_online_rows_map[key_value] = row
    
    # 验证主键列索引是否有效
    if online_key_column_index < 0 or online_key_column_index >= len(headers_online):
        raise ValueError(f"在线文件主键列索引无效: {online_key_column_index}，文件共有 {len(headers_online)} 列")
    
    if offline_key_column_index < 0 or offline_key_column_index >= len(headers_offline):
        raise ValueError(f"离线文件主键列索引无效: {offline_key_column_index}，文件共有 {len(headers_offline)} 列")
    
    online_key_idx = online_key_column_index
    offline_key_idx = offline_key_column_index
    
    online_key_name = headers_online[online_key_idx]
    offline_key_name = headers_offline[offline_key_idx]
    
    print(f"\n在线文件主键列: 索引{online_key_idx} ({online_key_name})")
    print(f"离线文件主键列: 索引{offline_key_idx} ({offline_key_name})")
    
    # 获取特征列（分别使用不同的起始索引）
    feature_cols_online = headers_online[online_feature_start_column:] if len(headers_online) > online_feature_start_column else []
    feature_cols_offline = headers_offline[offline_feature_start_column:] if len(headers_offline) > offline_feature_start_column else []
    
    # 排除time_now列（time_now不是特征，不进行对比，但会输出到CSV）
    feature_cols_online = [h for h in feature_cols_online if h.lower() != "time_now"]
    feature_cols_offline = [h for h in feature_cols_offline if h.lower() != "time_now"]
    
    print(f"在线文件特征列数: {len(feature_cols_online)}")
    print(f"离线文件特征列数: {len(feature_cols_offline)}")
    
    # 构建离线文件的索引字典（以离线文件为基准）
    offline_index = {}  # {key_value: (row_idx, row)}
    
    for row_idx, row in enumerate(rows_offline):
        if offline_key_idx < len(row) and row[offline_key_idx] is not None:
            key_value = str(row[offline_key_idx]).strip()
            if key_value:
                offline_index[key_value] = (row_idx, row)
    
    print(f"离线文件索引构建完成，共 {len(offline_index)} 条记录")
    
    # 构建特征名映射：以离线文件为基准
    feature_mapping = {}  # {feature_name: (offline_idx, online_idx)}
    all_features = []
    
    # 先处理离线文件的特征（作为基准）
    for idx, feature_offline in enumerate(feature_cols_offline):
        actual_offline_idx = offline_feature_start_column + idx
        actual_online_idx = None
        
        # 在在线文件中查找对应的特征
        for idx_online, feature_online in enumerate(feature_cols_online):
            if feature_offline == feature_online:
                actual_online_idx = online_feature_start_column + idx_online
                break
        
        feature_mapping[feature_offline] = (actual_offline_idx, actual_online_idx)
        if feature_offline not in all_features:
            all_features.append(feature_offline)
    
    all_features = sorted(all_features)
    
    print(f"实际对比的特征数: {len(all_features)}")
    
    # 找到cust_no和时间列的索引（用于输出）
    cust_no_idx_offline = None
    cust_no_idx_online = None  # 新增：也在在线文件中查找cust_no
    time_idx_offline = None
    time_idx_online = None
    # 找到time_now列的索引（用于输出到差异数据明细）
    time_now_idx_online = None
    
    # 尝试查找离线文件的cust_no列和时间列
    for i, header in enumerate(headers_offline):
        header_lower = header.lower()
        if cust_no_idx_offline is None and ("cust_no" in header_lower or "customer_no" in header_lower or "custno" in header_lower):
            cust_no_idx_offline = i
        # 查找时间列：包含time或date，并且（包含create/apply/use_create，或者列名以_time结尾）
        if time_idx_offline is None and ("time" in header_lower or "date" in header_lower):
            if ("create" in header_lower or "apply" in header_lower or "use_create" in header_lower or 
                header_lower.endswith("_time") or header_lower.endswith("time")):
                time_idx_offline = i
    
    # 尝试查找在线文件的cust_no列和时间列
    for i, header in enumerate(headers_online):
        header_lower = header.lower()
        # 查找cust_no列
        if cust_no_idx_online is None and ("cust_no" in header_lower or "customer_no" in header_lower or "custno" in header_lower):
            cust_no_idx_online = i
        # 查找time_now列
        if time_now_idx_online is None and header_lower == "time_now":
            time_now_idx_online = i
        # 查找时间列：包含time或date，并且（包含create/apply/use_create，或者列名以_time结尾）
        if time_idx_online is None and ("time" in header_lower or "date" in header_lower):
            if ("create" in header_lower or "apply" in header_lower or "use_create" in header_lower or 
                header_lower.endswith("_time") or header_lower.endswith("time")):
                time_idx_online = i
    
    # 输出找到的列信息
    if cust_no_idx_offline is not None:
        print(f"找到离线文件cust_no列: 索引{cust_no_idx_offline} ({headers_offline[cust_no_idx_offline]})")
    else:
        print(f"提示: 离线文件中未找到cust_no列")
    
    if cust_no_idx_online is not None:
        print(f"找到在线文件cust_no列: 索引{cust_no_idx_online} ({headers_online[cust_no_idx_online]})")
    else:
        print(f"提示: 在线文件中未找到cust_no列")
    
    if time_idx_offline is not None:
        print(f"找到离线文件时间列: 索引{time_idx_offline} ({headers_offline[time_idx_offline]})")
    else:
        print(f"警告: 未找到离线文件时间列")
        # 输出所有包含time或date的列名，帮助调试
        time_candidates = [h for h in headers_offline if "time" in h.lower() or "date" in h.lower()]
        if time_candidates:
            print(f"  提示: 离线文件中包含time或date的列: {time_candidates}")
    
    if time_idx_online is not None:
        print(f"找到在线文件时间列: 索引{time_idx_online} ({headers_online[time_idx_online]})")
    else:
        print(f"警告: 未找到在线文件时间列")
        # 输出所有包含time或date的列名，帮助调试
        time_candidates = [h for h in headers_online if "time" in h.lower() or "date" in h.lower()]
        if time_candidates:
            print(f"  提示: 在线文件中包含time或date的列: {time_candidates}")
    
    if time_now_idx_online is not None:
        print(f"找到在线文件time_now列: 索引{time_now_idx_online} ({headers_online[time_now_idx_online]})")
    else:
        print(f"提示: 未找到在线文件time_now列（如果JSON数据中包含time_now字段，会被解析为CSV列）")
    
        # 对比数据：遍历离线文件的每一行（以离线文件为基准）
    print(f"\n开始对比数据...")
    differences_dict = {}  # {(key_value, feature_name): (offline_value, online_value, cust_no, offline_time, online_time, time_now)}
    matches_dict = {}  # {(key_value, feature_name): value}
    matched_count = 0
    unmatched_count = 0
    unmatched_rows = []
    
    # 记录匹配的key值，用于后续找出仅在在线文件中的数据
    matched_keys = set()
    
    for row_idx_offline, row_offline in enumerate(rows_offline):
        if row_idx_offline % 500 == 0:
            print(f"已处理: {row_idx_offline}/{len(rows_offline)}")
        
        if offline_key_idx >= len(row_offline):
            continue
        
        key_value_offline = str(row_offline[offline_key_idx]).strip() if row_offline[offline_key_idx] is not None else ""
        
        if not key_value_offline:
            unmatched_count += 1
            unmatched_rows.append(row_offline)
            continue
        
        # 在在线文件中查找匹配的记录
        if key_value_offline not in offline_index:
            # 这种情况不应该发生，因为我们在遍历离线文件
            continue
        
        # 查找在线文件中对应的记录
        online_row = None
        for row_online in rows_online:
            if online_key_idx < len(row_online) and str(row_online[online_key_idx]).strip() == key_value_offline:
                online_row = row_online
                break
        
        if online_row is None:
            unmatched_count += 1
            unmatched_rows.append(row_offline)
            continue
        
        matched_count += 1
        matched_keys.add(key_value_offline)  # 记录匹配的key值
        
        # 获取主键值：优先从在线文件（Sql文件）获取，如果没有则从离线文件（接口文件）获取
        key_value = ""
        if online_row and online_key_idx < len(online_row) and online_row[online_key_idx] is not None:
            key_value = str(online_row[online_key_idx]).strip()
        
        # 如果在线文件中没有主键值，使用离线文件的主键值
        if not key_value:
            key_value = key_value_offline
        
        # 获取cust_no（优先从在线文件/Sql文件获取，如果没有则从离线文件/接口文件获取）
        cust_no = ""
        if cust_no_idx_online is not None and online_row and cust_no_idx_online < len(online_row):
            cust_no = str(online_row[cust_no_idx_online]).strip() if online_row[cust_no_idx_online] is not None else ""
        
        # 如果在线文件中没有找到cust_no，尝试从离线文件获取
        if not cust_no and cust_no_idx_offline is not None and cust_no_idx_offline < len(row_offline):
            cust_no = str(row_offline[cust_no_idx_offline]).strip() if row_offline[cust_no_idx_offline] is not None else ""
        
        # 获取离线文件的时间字段（保留原始格式，包括秒和毫秒，不做任何格式化或截断）
        offline_time_value = ""
        if time_idx_offline is not None and time_idx_offline < len(row_offline):
            raw_time = row_offline[time_idx_offline]
            if raw_time is not None:
                # 直接转换为字符串，只去除首尾空格，保留所有时间信息（秒和毫秒）
                offline_time_value = str(raw_time).strip()
            else:
                offline_time_value = ""
        
        # 获取在线文件的时间字段（优先从原始线上文件获取，保留原始格式）
        online_time_value = ""
        # 如果存在原始线上文件映射，优先从原始文件获取时间字段
        if original_online_rows_map and key_value in original_online_rows_map:
            original_row = original_online_rows_map[key_value]
            if original_time_idx is not None and original_time_idx < len(original_row):
                raw_time = original_row[original_time_idx]
                if raw_time is not None:
                    # 直接转换为字符串，只去除首尾空格，保留所有时间信息（秒和毫秒）
                    online_time_value = str(raw_time).strip()
        # 如果原始文件中没有找到，则从解析后的文件中获取
        if not online_time_value and time_idx_online is not None and online_row and time_idx_online < len(online_row):
            raw_time = online_row[time_idx_online]
            if raw_time is not None:
                # 直接转换为字符串，只去除首尾空格，保留所有时间信息（秒和毫秒）
                online_time_value = str(raw_time).strip()
            else:
                online_time_value = ""
        
        # 获取在线文件的time_now字段（用于输出到差异数据明细）
        time_now_value = ""
        if time_now_idx_online is not None and online_row and time_now_idx_online < len(online_row):
            raw_time_now = online_row[time_now_idx_online]
            if raw_time_now is not None:
                time_now_value = str(raw_time_now).strip()
            else:
                time_now_value = ""
        
        # 对比所有特征
        for feature_name in all_features:
            offline_idx, online_idx = feature_mapping.get(feature_name, (None, None))
            
            # 获取离线文件的值（基准值）
            offline_value = ""
            if offline_idx is not None and offline_idx < len(row_offline):
                offline_value = str(row_offline[offline_idx]).strip() if row_offline[offline_idx] is not None else ""
            
            # 获取在线文件的值
            online_value = ""
            if online_idx is not None and online_row and online_idx < len(online_row):
                online_value = str(online_row[online_idx]).strip() if online_row[online_idx] is not None else ""
            
            # 如果启用了特征值转换，尝试将字符串转换为数值
            if convert_feature_to_number:
                offline_value = _convert_string_to_number(offline_value)
                online_value = _convert_string_to_number(online_value)
            
            # 判断是否有差异
            has_diff = False
            is_match = False
            
            if offline_idx is not None and online_idx is not None:
                # 特征在两个文件中都存在，比较值
                if enable_tolerance:
                    # 启用容错对比
                    is_match = compare_values(offline_value, online_value, feature_name, False, False, True, tolerance_value)
                else:
                    # 精确对比（使用默认参数，保持之前的行为）
                    is_match = compare_values(offline_value, online_value, feature_name)
                
                if is_match:
                    # 值一致，不记录差异
                    pass
                else:
                    has_diff = True
            elif offline_idx is not None and online_idx is None:
                # 特征在离线文件中存在但在在线文件中不存在
                if not compare_common_features_only:
                    # 仅当未启用"仅对比共有特征"时，才记录为差异
                    has_diff = True
            elif offline_idx is None and online_idx is not None:
                # 特征在在线文件中存在但在离线文件中不存在
                if not compare_common_features_only:
                    # 仅当未启用"仅对比共有特征"时，才记录为差异
                    has_diff = True
            
            # 如果一致，记录到一致字典中
            if is_match:
                matches_dict[(key_value, feature_name)] = offline_value
            
            # 如果有差异，记录到差异字典中（包含cust_no、离线时间、在线时间和time_now）
            if has_diff:
                differences_dict[(key_value, feature_name)] = (offline_value, online_value, cust_no, offline_time_value, online_time_value, time_now_value)
    
    # 找出仅在在线文件中的数据
    online_only_rows = []
    online_only_count = 0
    
    # 遍历在线文件，找出在离线文件中不存在的记录
    # 如果key不在matched_keys中，说明在离线文件中没有找到匹配的记录
    # 但还需要检查是否在offline_index中（因为可能主键为空或其他原因未匹配）
    for row_online in rows_online:
        if online_key_idx >= len(row_online):
            continue
        
        key_value_online = str(row_online[online_key_idx]).strip() if row_online[online_key_idx] is not None else ""
        
        if not key_value_online:
            continue
        
        # 如果这个key在离线文件的索引中不存在，则记录为仅在在线文件中的数据
        if key_value_online not in offline_index:
            online_only_count += 1
            online_only_rows.append(row_online)
    
    print(f"\n对比完成:")
    print(f"  匹配记录数: {matched_count}")
    print(f"  仅在离线表中的记录数: {unmatched_count}")
    print(f"  仅在线上文件中的记录数: {online_only_count}")
    print(f"  有差异的特征值数量: {len(differences_dict)}")
    
    # 统计每个特征的差异情况
    feature_stats = {}
    for feature in all_features:
        feature_stats[feature] = {"total": 0, "diff_count": 0}
    
    for (key_value, feature), diff_data in differences_dict.items():
        if feature in feature_stats:
            feature_stats[feature]["diff_count"] += 1
    
    # 统计所有特征的对比次数
    for feature in all_features:
        if feature in feature_stats:
            feature_stats[feature]["total"] = matched_count
    
    # 计算总体统计
    total_comparisons = matched_count * len(all_features)
    diff_count = len(differences_dict)
    match_count = total_comparisons - diff_count
    match_ratio = match_count / total_comparisons * 100 if total_comparisons > 0 else 0
    
    # 显示对比结果统计
    print(f"\n{'='*80}")
    print(f"特征值对比结果统计")
    print(f"\n总体统计:")
    print(f"  总对比次数: {total_comparisons}")
    print(f"  一致数量: {match_count}")
    print(f"  差异数量: {diff_count}")
    print(f"  一致率: {match_ratio:.2f}%")
    
    # 统计无差异和有差异的特征
    no_diff_features = [f for f, s in feature_stats.items() if s["diff_count"] == 0]
    diff_features = [f for f, s in feature_stats.items() if s["diff_count"] > 0]
    
    print(f"\n特征统计:")
    print(f"  无差异特征数量: {len(no_diff_features)}")
    print(f"  有差异特征数量: {len(diff_features)}")
    
    if len(diff_features) > 0:
        print(f"\n有差异特征详情（按差异数量降序）:")
        print(f"  {'特征名':<80} {'差异数量':<10} {'差异占比':<10}")
        print(f"  {'-'*80} {'-'*10} {'-'*10}")
        
        sorted_features = sorted([(f, feature_stats[f]) for f in diff_features], 
                                key=lambda x: x[1]["diff_count"], reverse=True)
        for feature, stats in sorted_features:
            diff_ratio = stats["diff_count"] / matched_count * 100 if matched_count > 0 else 0
            print(f"  {feature:<80} {stats['diff_count']:<10} {diff_ratio:.2f}%")
    
    print(f"\n{'='*80}\n")
    
    return (differences_dict, matches_dict, all_features, feature_stats, matched_count,
            unmatched_count, unmatched_rows, headers_online, headers_offline,
            total_comparisons, match_count, diff_count, match_ratio,
            online_only_rows, online_only_count, rows_online, rows_offline)
