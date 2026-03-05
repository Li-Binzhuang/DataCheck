#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
数据对比器模块（大文件性能优化版）
功能：对比两个CSV/XLSX文件的数据差异

优化点：
1. 使用字典索引替代嵌套循环查找（O(1) vs O(n)）
2. 预先构建特征映射，避免重复查找
3. 批量处理进度输出，减少I/O开销
4. 针对大文件优化内存使用
"""

import os
import sys
from typing import Any, Dict, List, Tuple

# 添加公共工具目录到路径
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../../common'))
from csv_tool import read_csv_with_encoding
from value_comparator import compare_values


def _convert_string_to_number_fast(value: Any) -> Any:
    """
    快速将字符串转换为数值类型（优化版）
    """
    if value is None or value == "":
        return value
    
    if isinstance(value, (int, float)):
        return value
    
    str_value = str(value).strip()
    if not str_value:
        return value
    
    # 快速去除引号
    if str_value[0] in ('"', "'") and str_value[-1] in ('"', "'"):
        str_value = str_value[1:-1]
    
    if not str_value:
        return value
    
    try:
        float_value = float(str_value)
        if float_value == int(float_value):
            return int(float_value)
        return float_value
    except (ValueError, TypeError):
        return str_value


def compare_two_files(
    sql_file_path: str,
    api_file_path: str,
    sql_key_column,
    api_key_column,
    sql_feature_start: int = 1,
    api_feature_start: int = 1,
    convert_feature_to_number: bool = True,
    ignore_default_fill: bool = False
):
    """
    对比两个CSV/XLSX文件（性能优化版）
    
    优化说明：
    - 使用字典索引替代嵌套循环，时间复杂度从O(n²)降到O(n)
    - 预先构建所有映射关系，避免重复计算
    - 批量输出进度信息，减少I/O开销
    - 支持多列主键组合
    
    Args:
        sql_file_path: Sql文件路径
        api_file_path: 接口文件路径
        sql_key_column: Sql文件的主键列索引（从0开始），支持单列(int)或多列(list)
        api_key_column: 接口文件的主键列索引（从0开始），支持单列(int)或多列(list)
        sql_feature_start: Sql文件特征列起始索引（从0开始）
        api_feature_start: 接口文件特征列起始索引（从0开始）
        convert_feature_to_number: 是否转换特征值为数值类型（默认True）
        ignore_default_fill: 是否忽略默认填充值（-999和null视为一致，默认False）
    
    Returns:
        包含对比结果的字典
    """
    # 标准化主键列为列表格式
    sql_key_columns = sql_key_column if isinstance(sql_key_column, list) else [sql_key_column]
    api_key_columns = api_key_column if isinstance(api_key_column, list) else [api_key_column]
    
    print(f"\n[优化版] 开始对比两个文件")
    print(f"Sql文件: {sql_file_path}")
    print(f"接口文件: {api_file_path}")
    print(f"Sql文件主键列索引: {sql_key_columns}")
    print(f"接口文件主键列索引: {api_key_columns}")
    print(f"Sql文件特征列起始索引: {sql_feature_start}")
    print(f"接口文件特征列起始索引: {api_feature_start}")
    print(f"转换特征值为数值: {convert_feature_to_number}")
    print(f"忽略默认填充值: {ignore_default_fill}")
    
    # 读取两个文件
    print("\n[1/5] 读取文件...")
    headers_sql, rows_sql = read_csv_with_encoding(sql_file_path)
    headers_api, rows_api = read_csv_with_encoding(api_file_path)
    
    # 验证主键列索引
    for idx in sql_key_columns:
        if idx < 0 or idx >= len(headers_sql):
            raise ValueError(f"Sql文件主键列索引无效: {idx}，文件共有 {len(headers_sql)} 列")
    
    for idx in api_key_columns:
        if idx < 0 or idx >= len(headers_api):
            raise ValueError(f"接口文件主键列索引无效: {idx}，文件共有 {len(headers_api)} 列")
    
    sql_key_name = "+".join([headers_sql[idx] for idx in sql_key_columns])
    api_key_name = "+".join([headers_api[idx] for idx in api_key_columns])
    
    print(f"Sql文件: {len(rows_sql)} 行, {len(headers_sql)} 列, 主键: {sql_key_name}")
    print(f"接口文件: {len(rows_api)} 行, {len(headers_api)} 列, 主键: {api_key_name}")
    
    # 获取特征列
    feature_cols_sql = headers_sql[sql_feature_start:] if len(headers_sql) > sql_feature_start else []
    feature_cols_api = headers_api[api_feature_start:] if len(headers_api) > api_feature_start else []
    
    print(f"Sql文件特征列数: {len(feature_cols_sql)}")
    print(f"接口文件特征列数: {len(feature_cols_api)}")
    
    # [优化1] 构建Sql文件的索引字典 - O(n)时间复杂度
    print("\n[2/5] 构建索引...")
    sql_index = {}  # {key_value: row}
    for row in rows_sql:
        # 构建组合主键
        key_parts = []
        valid_key = True
        for idx in sql_key_columns:
            if idx < len(row) and row[idx] is not None:
                key_parts.append(str(row[idx]).strip())
            else:
                valid_key = False
                break
        
        if valid_key and all(key_parts):
            key_value = "||".join(key_parts)  # 使用||作为分隔符
            sql_index[key_value] = row
    
    print(f"Sql文件索引: {len(sql_index)} 条记录")
    
    # 构建接口文件的索引字典
    api_index = {}  # {key_value: row}
    for row in rows_api:
        # 构建组合主键
        key_parts = []
        valid_key = True
        for idx in api_key_columns:
            if idx < len(row) and row[idx] is not None:
                key_parts.append(str(row[idx]).strip())
            else:
                valid_key = False
                break
        
        if valid_key and all(key_parts):
            key_value = "||".join(key_parts)  # 使用||作为分隔符
            api_index[key_value] = row
    
    print(f"接口文件索引: {len(api_index)} 条记录")
    
    # [优化2] 预先构建特征映射
    print("\n[3/5] 构建特征映射...")
    feature_mapping = {}  # {feature_name: (api_idx, sql_idx)}
    all_features = []
    
    # 预先构建接口文件特征名到索引的映射（避免重复使用list.index()）
    api_feature_index = {feature: api_feature_start + idx for idx, feature in enumerate(feature_cols_api)}
    
    # 以Sql文件（第一个文件）为基准
    # 只对比Sql文件中存在的特征，忽略只在接口文件中存在的特征
    for idx, feature_sql in enumerate(feature_cols_sql):
        actual_sql_idx = sql_feature_start + idx
        actual_api_idx = api_feature_index.get(feature_sql)  # O(1) 查找
        
        feature_mapping[feature_sql] = (actual_api_idx, actual_sql_idx)
        all_features.append(feature_sql)
    
    all_features = sorted(all_features)
    print(f"Sql文件特征数: {len(feature_cols_sql)}")
    print(f"接口文件特征数: {len(feature_cols_api)}")
    print(f"实际对比的特征数: {len(all_features)} (以Sql文件为基准)")
    
    # 查找cust_no列
    cust_no_idx_api = None
    cust_no_idx_sql = None
    
    for i, header in enumerate(headers_api):
        if "cust_no" in header.lower() or "customer_no" in header.lower() or "custno" in header.lower():
            cust_no_idx_api = i
            break
    
    for i, header in enumerate(headers_sql):
        if "cust_no" in header.lower() or "customer_no" in header.lower() or "custno" in header.lower():
            cust_no_idx_sql = i
            break
    
    if cust_no_idx_api is not None:
        print(f"接口文件cust_no列: 索引{cust_no_idx_api} ({headers_api[cust_no_idx_api]})")
    if cust_no_idx_sql is not None:
        print(f"Sql文件cust_no列: 索引{cust_no_idx_sql} ({headers_sql[cust_no_idx_sql]})")
    
    # 查找时间列（用于差异明细输出）
    time_idx_api = None
    time_idx_sql = None
    
    for i, header in enumerate(headers_api):
        if "time" in header.lower() or "date" in header.lower():
            time_idx_api = i
            break
    # 如果没找到，默认使用主键列后面一列
    if time_idx_api is None and api_key_column + 1 < len(headers_api):
        time_idx_api = api_key_column + 1
    
    for i, header in enumerate(headers_sql):
        if "time" in header.lower() or "date" in header.lower():
            time_idx_sql = i
            break
    if time_idx_sql is None and sql_key_column + 1 < len(headers_sql):
        time_idx_sql = sql_key_column + 1
    
    if time_idx_api is not None:
        print(f"接口文件时间列: 索引{time_idx_api} ({headers_api[time_idx_api]})")
    if time_idx_sql is not None:
        print(f"Sql文件时间列: 索引{time_idx_sql} ({headers_sql[time_idx_sql]})")
    
    # [优化3] 对比数据 - 使用字典查找替代嵌套循环
    print(f"\n[4/5] 对比数据...")
    differences_dict = {}
    matched_count = 0
    unmatched_count = 0
    unmatched_rows = []
    matched_keys = set()
    
    # 批量进度输出间隔
    progress_interval = max(100, len(rows_api) // 20)  # 每5%输出一次
    
    for row_idx_api, row_api in enumerate(rows_api):
        # [优化4] 批量输出进度，减少I/O
        if row_idx_api % progress_interval == 0 and row_idx_api > 0:
            progress = (row_idx_api / len(rows_api)) * 100
            print(f"  进度: {row_idx_api}/{len(rows_api)} ({progress:.1f}%)")
        
        # 构建组合主键
        key_parts = []
        valid_key = True
        for idx in api_key_columns:
            if idx < len(row_api) and row_api[idx] is not None:
                key_parts.append(str(row_api[idx]).strip())
            else:
                valid_key = False
                break
        
        if not valid_key or not all(key_parts):
            unmatched_count += 1
            unmatched_rows.append(row_api)
            continue
        
        key_value_api = "||".join(key_parts)
        
        # [优化5] 使用字典查找 - O(1)时间复杂度
        sql_row = sql_index.get(key_value_api)
        
        if sql_row is None:
            unmatched_count += 1
            unmatched_rows.append(row_api)
            continue
        
        matched_count += 1
        matched_keys.add(key_value_api)
        
        # 获取主键值和cust_no
        key_value = key_value_api
        cust_no = ""
        
        if cust_no_idx_sql is not None and cust_no_idx_sql < len(sql_row):
            cust_no = str(sql_row[cust_no_idx_sql]).strip() if sql_row[cust_no_idx_sql] is not None else ""
        
        if not cust_no and cust_no_idx_api is not None and cust_no_idx_api < len(row_api):
            cust_no = str(row_api[cust_no_idx_api]).strip() if row_api[cust_no_idx_api] is not None else ""
        
        # 获取时间值（优先从接口文件获取）
        time_value = ""
        if time_idx_api is not None and time_idx_api < len(row_api):
            time_value = str(row_api[time_idx_api]).strip() if row_api[time_idx_api] is not None else ""
        if not time_value and time_idx_sql is not None and time_idx_sql < len(sql_row):
            time_value = str(sql_row[time_idx_sql]).strip() if sql_row[time_idx_sql] is not None else ""
        
        # 对比所有特征
        for feature_name in all_features:
            api_idx, sql_idx = feature_mapping[feature_name]
            
            # 获取值（优化：减少函数调用）
            api_value = row_api[api_idx] if api_idx is not None and api_idx < len(row_api) else ""
            sql_value = sql_row[sql_idx] if sql_idx is not None and sql_idx < len(sql_row) else ""
            
            # 转换为数值
            if convert_feature_to_number:
                api_value = _convert_string_to_number_fast(api_value)
                sql_value = _convert_string_to_number_fast(sql_value)
            
            # 判断差异（以Sql文件为基准）
            if sql_idx is not None and api_idx is not None:
                # 特征在两个文件中都存在，比较值
                if not compare_values(api_value, sql_value, feature_name, ignore_default_fill):
                    differences_dict[(key_value, feature_name)] = (api_value, sql_value, cust_no, time_value)
            elif sql_idx is not None:
                # 特征在Sql文件中存在，在接口文件中不存在
                differences_dict[(key_value, feature_name)] = (api_value, sql_value, cust_no, time_value)
    
    print(f"  进度: {len(rows_api)}/{len(rows_api)} (100.0%)")
    
    # 找出仅在Sql文件中的数据
    print("\n[5/5] 统计结果...")
    sql_only_rows = []
    sql_only_count = 0
    
    for key_value_sql, row_sql in sql_index.items():
        if key_value_sql not in api_index:
            sql_only_count += 1
            sql_only_rows.append(row_sql)
    
    print(f"\n对比完成:")
    print(f"  匹配记录数: {matched_count}")
    print(f"  仅在接口文件中的记录数: {unmatched_count}")
    print(f"  仅在Sql文件中的记录数: {sql_only_count}")
    print(f"  有差异的特征值数量: {len(differences_dict)}")
    
    # 统计每个特征的差异情况
    feature_stats = {}
    for feature in all_features:
        feature_stats[feature] = {"total": matched_count, "diff_count": 0}
    
    for (key_value, feature), diff_data in differences_dict.items():
        if feature in feature_stats:
            feature_stats[feature]["diff_count"] += 1
    
    # 计算总体统计
    total_comparisons = matched_count * len(all_features)
    diff_count = len(differences_dict)
    match_count = total_comparisons - diff_count
    match_ratio = match_count / total_comparisons * 100 if total_comparisons > 0 else 0
    
    # 显示对比结果统计
    print(f"\n{'='*80}")
    print(f"特征值对比结果统计")
    print(f"\n总体统计:")
    print(f"  总对比次数: {total_comparisons:,}")
    print(f"  一致数量: {match_count:,}")
    print(f"  差异数量: {diff_count:,}")
    print(f"  一致率: {match_ratio:.2f}%")
    
    # 统计特征
    no_diff_features = [f for f, s in feature_stats.items() if s["diff_count"] == 0]
    diff_features = [f for f, s in feature_stats.items() if s["diff_count"] > 0]
    
    print(f"\n特征统计:")
    print(f"  无差异特征数量: {len(no_diff_features)}")
    print(f"  有差异特征数量: {len(diff_features)}")
    
    if len(diff_features) > 0:
        print(f"\n有差异特征详情（按差异数量降序，仅显示前20个）:")
        print(f"  {'特征名':<80} {'差异数量':<10} {'差异占比':<10}")
        print(f"  {'-'*80} {'-'*10} {'-'*10}")
        
        sorted_features = sorted([(f, feature_stats[f]) for f in diff_features], 
                                key=lambda x: x[1]["diff_count"], reverse=True)
        
        # 只显示前20个
        for feature, stats in sorted_features[:20]:
            diff_ratio = stats["diff_count"] / matched_count * 100 if matched_count > 0 else 0
            print(f"  {feature:<80} {stats['diff_count']:<10} {diff_ratio:.2f}%")
        
        if len(sorted_features) > 20:
            print(f"  ... 还有 {len(sorted_features) - 20} 个特征未显示")
    
    print(f"\n{'='*80}\n")
    
    return {
        "differences_dict": differences_dict,
        "matches_dict": {},  # 不再收集一致数据，节省内存
        "all_features": all_features,
        "feature_stats": feature_stats,
        "matched_count": matched_count,
        "unmatched_count": unmatched_count,
        "unmatched_rows": unmatched_rows,
        "headers_sql": headers_sql,
        "headers_api": headers_api,
        "total_comparisons": total_comparisons,
        "match_count": match_count,
        "diff_count": diff_count,
        "match_ratio": match_ratio,
        "sql_only_rows": sql_only_rows,
        "sql_only_count": sql_only_count,
        "rows_sql": rows_sql,
        "rows_api": rows_api,
        "sql_key_column": sql_key_columns,
        "api_key_column": api_key_columns,
        "sql_feature_start": sql_feature_start,
        "api_feature_start": api_feature_start,
        "key_column_name": api_key_name,
        "time_column_name": headers_api[time_idx_api] if time_idx_api is not None and time_idx_api < len(headers_api) else "时间"
    }
