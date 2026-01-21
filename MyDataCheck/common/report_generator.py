#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
报告生成模块
功能：生成和写入对比分析报告
"""

import csv
import os
from typing import Dict, List


def write_analysis_record_csv(
    output_path: str,
    headers: List[str],
    rows: List[List[str]],
    results: Dict[int, Dict],
    feature_start_column: int,
    has_time_now: bool = False,
):
    """
    写入分析记录文件（CSV格式）
    
    Args:
        output_path: 输出文件路径
        headers: CSV表头
        rows: CSV数据行
        results: 对比结果字典
        feature_start_column: 特征开始列索引
        has_time_now: 接口数据中是否包含time_now字段
    """
    # 收集所有异常数据
    anomaly_records = []

    for i in range(len(rows)):
        if i in results:
            result = results[i]
            comparison_results = result.get("comparison_results", {})
            cust_no = result.get("cust_no", "")
            use_create_time = result.get("use_create_time", "")  # 使用请求接口时的baseTime值
            # 从results中获取use_credit_apply_id（从输入文件中查找的apply_id相关字段）
            use_credit_apply_id = result.get("use_credit_apply_id", "")
            # 从results中获取time_now字段值（如果存在）
            time_now_value = result.get("time_now", "")

            for j in range(feature_start_column, len(headers)):
                header = headers[j]
                # 跳过pt列和time_now列（time_now不是特征，不进行对比）
                if header.lower() in ["pt", "time_now"]:
                    continue
                feature_result = comparison_results.get(header, {})
                is_match = feature_result.get("is_match", False)

                if not is_match:
                    csv_value = feature_result.get("csv_value", "")
                    api_value = feature_result.get("api_value", None)
                    api_value_str = "null" if api_value is None else str(api_value)
                    record = {
                        "feature_name": header,
                        "cust_no": cust_no,
                        "use_credit_apply_id": use_credit_apply_id,
                        "use_create_time": use_create_time,
                        "csv_value": csv_value,
                        "api_value": api_value_str,
                    }
                    # 如果接口数据中有time_now字段，添加到记录中
                    if has_time_now:
                        record["time_now"] = time_now_value
                    anomaly_records.append(record)

    # 对异常记录进行排序
    anomaly_records.sort(key=lambda x: (x["cust_no"], x["use_create_time"]))

    # 确保输出目录存在
    output_dir = os.path.dirname(output_path)
    if output_dir and not os.path.exists(output_dir):
        try:
            os.makedirs(output_dir, exist_ok=True)
        except Exception as e:
            print(f"创建目录失败: {output_dir}, 错误: {e}")

    # 写入CSV文件
    with open(output_path, "w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f)
        
        # 根据是否有time_now字段动态构建表头
        if has_time_now:
            writer.writerow(["特征名", "cust_no", "use_credit_apply_id", "use_create_time", "CSV值", "API值", "time_now"])
        else:
            writer.writerow(["特征名", "cust_no", "use_credit_apply_id", "use_create_time", "CSV值", "API值"])
        
        # 写入异常记录明细
        for record in anomaly_records:
            if has_time_now:
                writer.writerow([
                    record["feature_name"],
                    record["cust_no"],
                    record["use_credit_apply_id"],
                    record["use_create_time"],
                    record["csv_value"],
                    record["api_value"],
                    record.get("time_now", ""),
                ])
            else:
                writer.writerow([
                    record["feature_name"],
                    record["cust_no"],
                    record["use_credit_apply_id"],
                    record["use_create_time"],
                    record["csv_value"],
                    record["api_value"],
                ])


def write_feature_stats_csv(
    output_path: str,
    feature_stats: Dict[str, Dict[str, int]],
    total_features: int = 0,
    match_features: int = 0,
    mismatch_features: int = 0,
    overall_match_ratio: float = 0.0,
    all_match_feature_count: int = 0,
    anomaly_feature_count: int = 0,
):
    """
    写入特征比对数据表（CSV格式）
    
    Args:
        output_path: 输出文件路径
        feature_stats: 特征统计字典
        total_features: 总特征值数量
        match_features: 匹配特征值数量
        mismatch_features: 不匹配特征值数量
        overall_match_ratio: 总体匹配率
        all_match_feature_count: 无异常特征数量
        anomaly_feature_count: 有异常特征数量
    """
    # 确保输出目录存在
    output_dir = os.path.dirname(output_path)
    if output_dir and not os.path.exists(output_dir):
        try:
            os.makedirs(output_dir, exist_ok=True)
        except Exception as e:
            print(f"创建目录失败: {output_dir}, 错误: {e}")
    
    # 准备所有特征数据
    all_features_list = []
    
    for feature_name, stats in feature_stats.items():
        has_anomaly = "有异常" if stats["mismatch"] > 0 else "无异常"
        match_ratio = stats["match"] / stats["total"] * 100 if stats["total"] > 0 else 0
        mismatch_ratio = stats["mismatch"] / stats["total"] * 100 if stats["total"] > 0 else 0
        
        all_features_list.append({
            "feature_name": feature_name,
            "has_anomaly": has_anomaly,
            "total_count": stats["total"],
            "match_count": stats["match"],
            "mismatch_count": stats["mismatch"],
            "match_ratio": match_ratio,
            "mismatch_ratio": mismatch_ratio,
        })
    
    # 按是否有异常排序，然后按异常数量降序排序
    all_features_list.sort(key=lambda x: (x["has_anomaly"] == "无异常", -x["mismatch_count"]))
    
    # 统计无异常特征总数和有异常特征总数
    no_anomaly_count = sum(1 for feature in all_features_list if feature["has_anomaly"] == "无异常")
    has_anomaly_count = sum(1 for feature in all_features_list if feature["has_anomaly"] == "有异常")
    
    # 写入CSV文件
    try:
        with open(output_path, "w", encoding="utf-8", newline="") as f:
            writer = csv.writer(f)
            
            # 写入汇总信息（两行）
            writer.writerow(["特征统计"])
            writer.writerow(["无异常特征总数", no_anomaly_count])
            writer.writerow(["有异常特征总数", has_anomaly_count])
            
            # 写入空行分隔
            writer.writerow([])
            
            # 写入表头
            writer.writerow([
                "特征名",
                "是否有异常",
                "比对数据条数",
                "匹配数量",
                "异常数量",
                "匹配率(%)",
                "异常率(%)"
            ])
            
            # 写入特征数据
            for feature in all_features_list:
                writer.writerow([
                    feature["feature_name"],
                    feature["has_anomaly"],
                    feature["total_count"],
                    feature["match_count"],
                    feature["mismatch_count"],
                    f"{feature['match_ratio']:.2f}",
                    f"{feature['mismatch_ratio']:.2f}",
                ])
    except Exception as e:
        print(f"写入特征比对数据表失败: {output_path}")
        print(f"错误详情: {e}")
        import traceback
        traceback.print_exc()


def write_merged_data_csv(
    output_path: str,
    headers1: List[str],
    rows1: List[List[str]],
    headers2: List[str],
    rows2: List[List[str]],
    key_column1: int,
    key_column2: int,
    suffix1: str = "_原始",
    suffix2: str = "_接口",
    key_column1_secondary: int = None,
    key_column2_secondary: int = None,
    feature_start_column1: int = None,
    feature_start_column2: int = None,
):
    """
    写入合并的全量数据文件（CSV格式）
    将两个文件的数据根据主键合并，列名加后缀区分
    非特征列只显示第一个文件的，特征列按特征名分组，相同特征名的列挨着
    
    Args:
        output_path: 输出文件路径
        headers1: 第一个文件的表头
        rows1: 第一个文件的数据行
        headers2: 第二个文件的表头
        rows2: 第二个文件的数据行
        key_column1: 第一个文件的主键列索引（或第一个主键列）
        key_column2: 第二个文件的主键列索引（或第一个主键列）
        suffix1: 第一个文件列名的后缀（默认：_原始）
        suffix2: 第二个文件列名的后缀（默认：_接口）
        key_column1_secondary: 第一个文件的第二个主键列索引（用于复合主键，可选）
        key_column2_secondary: 第二个文件的第二个主键列索引（用于复合主键，可选）
        feature_start_column1: 第一个文件特征列起始索引（可选，默认为主键列之后）
        feature_start_column2: 第二个文件特征列起始索引（可选，默认为主键列之后）
    """
    # 确保输出目录存在
    output_dir = os.path.dirname(output_path)
    if output_dir and not os.path.exists(output_dir):
        try:
            os.makedirs(output_dir, exist_ok=True)
        except Exception as e:
            print(f"创建目录失败: {output_dir}, 错误: {e}")
    
    # 判断是否使用复合主键
    use_composite_key = key_column1_secondary is not None and key_column2_secondary is not None
    
    # 构建第二个文件的索引
    file2_index = {}
    for i, row in enumerate(rows2):
        if use_composite_key:
            # 使用复合主键
            if (key_column2 < len(row) and row[key_column2] is not None and
                key_column2_secondary < len(row) and row[key_column2_secondary] is not None):
                key1_value = str(row[key_column2]).strip()
                key2_value = str(row[key_column2_secondary]).strip()
                if key1_value and key2_value:
                    key_value = (key1_value, key2_value)
                    file2_index[key_value] = row
        else:
            # 使用单一主键
            if key_column2 < len(row) and row[key_column2] is not None:
                key_value = str(row[key_column2]).strip()
                if key_value:
                    file2_index[key_value] = row
    
    # 确定特征列起始位置
    if feature_start_column1 is None:
        # 如果没有指定，假设主键列之后就是特征列
        feature_start_column1 = max(key_column1, key_column1_secondary if key_column1_secondary is not None else -1) + 1
    if feature_start_column2 is None:
        feature_start_column2 = max(key_column2, key_column2_secondary if key_column2_secondary is not None else -1) + 1
    
    # 分离非特征列和特征列
    non_feature_headers1 = headers1[:feature_start_column1]
    feature_headers1 = headers1[feature_start_column1:]
    feature_headers2 = headers2[feature_start_column2:]
    
    # 构建特征名映射（找到相同名称的特征）
    feature_mapping = {}  # {feature_name: (idx1, idx2)}
    # 记录time_now字段的位置（需要包含在输出中，但不作为特征对比）
    time_now_indices = {}  # {file_num: idx} 记录time_now在哪个文件的哪个位置
    for idx1, feat1 in enumerate(feature_headers1):
        if feat1.lower() == "time_now":
            time_now_indices[1] = idx1
        if feat1.lower() not in ["pt", "time_now"]:  # 排除pt列和time_now列（time_now不作为特征对比）
            # 在第二个文件中查找相同名称的特征
            for idx2, feat2 in enumerate(feature_headers2):
                if feat1 == feat2:
                    feature_mapping[feat1] = (idx1, idx2)
                    break
    # 检查第二个文件中的time_now
    for idx2, feat2 in enumerate(feature_headers2):
        if feat2.lower() == "time_now":
            time_now_indices[2] = idx2
    
    # 构建合并后的表头：非特征列（只显示第一个文件的）+ 特征列（按特征名分组，相同特征名的挨着）
    merged_headers = []
    merged_column_mapping = []  # [(source_file, source_idx), ...] 用于数据提取
    
    # 1. 添加非特征列（只显示第一个文件的）
    for idx in range(len(non_feature_headers1)):
        merged_headers.append(non_feature_headers1[idx])
        merged_column_mapping.append((1, idx))
    
    # 2. 添加特征列（按特征名分组）
    # 先添加在第一个文件中存在且在第二个文件中也有匹配的特征
    for feat_name in sorted(feature_mapping.keys()):
        idx1, idx2 = feature_mapping[feat_name]
        merged_headers.append(f"{feat_name}{suffix1}")
        merged_column_mapping.append((1, feature_start_column1 + idx1))
        merged_headers.append(f"{feat_name}{suffix2}")
        merged_column_mapping.append((2, feature_start_column2 + idx2))
    
    # 3. 添加只在第一个文件中存在的特征（排除time_now，单独处理）
    for idx1, feat1 in enumerate(feature_headers1):
        if feat1.lower() not in ["pt", "time_now"] and feat1 not in feature_mapping:
            merged_headers.append(f"{feat1}{suffix1}")
            merged_column_mapping.append((1, feature_start_column1 + idx1))
            merged_headers.append(f"{feat1}{suffix2}")  # 第二个文件用空值
            merged_column_mapping.append((None, None))
    
    # 4. 添加只在第二个文件中存在的特征（排除time_now，单独处理）
    for idx2, feat2 in enumerate(feature_headers2):
        if feat2.lower() == "time_now":
            continue  # time_now单独处理
        found = False
        for feat1 in feature_headers1:
            if feat1 == feat2:
                found = True
                break
        if not found:
            merged_headers.append(f"{feat2}{suffix1}")  # 第一个文件用空值
            merged_column_mapping.append((None, None))
            merged_headers.append(f"{feat2}{suffix2}")
            merged_column_mapping.append((2, feature_start_column2 + idx2))
    
    # 5. 添加time_now字段（如果存在，需要包含在输出中，但不作为特征对比）
    if 1 in time_now_indices or 2 in time_now_indices:
        # 第一个文件的time_now
        if 1 in time_now_indices:
            merged_headers.append(f"time_now{suffix1}")
            merged_column_mapping.append((1, feature_start_column1 + time_now_indices[1]))
        else:
            merged_headers.append(f"time_now{suffix1}")
            merged_column_mapping.append((None, None))
        # 第二个文件的time_now
        if 2 in time_now_indices:
            merged_headers.append(f"time_now{suffix2}")
            merged_column_mapping.append((2, feature_start_column2 + time_now_indices[2]))
        else:
            merged_headers.append(f"time_now{suffix2}")
            merged_column_mapping.append((None, None))
    
    # 写入CSV文件
    try:
        with open(output_path, "w", encoding="utf-8", newline="") as f:
            writer = csv.writer(f)
            
            # 写入表头
            writer.writerow(merged_headers)
            
            # 遍历第一个文件的所有行
            for row1 in rows1:
                # 获取主键值
                if use_composite_key:
                    if (key_column1 >= len(row1) or row1[key_column1] is None or
                        key_column1_secondary >= len(row1) or row1[key_column1_secondary] is None):
                        # 构建合并行
                        merged_row = []
                        for source_file, source_idx in merged_column_mapping:
                            if source_file == 1 and source_idx is not None and source_idx < len(row1):
                                merged_row.append(row1[source_idx] if row1[source_idx] is not None else '')
                            else:
                                merged_row.append('')
                        writer.writerow(merged_row)
                        continue
                    key1_value = str(row1[key_column1]).strip()
                    key2_value = str(row1[key_column1_secondary]).strip()
                    if not key1_value or not key2_value:
                        merged_row = []
                        for source_file, source_idx in merged_column_mapping:
                            if source_file == 1 and source_idx is not None and source_idx < len(row1):
                                merged_row.append(row1[source_idx] if row1[source_idx] is not None else '')
                            else:
                                merged_row.append('')
                        writer.writerow(merged_row)
                        continue
                    key_value = (key1_value, key2_value)
                else:
                    if key_column1 >= len(row1) or row1[key_column1] is None:
                        merged_row = []
                        for source_file, source_idx in merged_column_mapping:
                            if source_file == 1 and source_idx is not None and source_idx < len(row1):
                                merged_row.append(row1[source_idx] if row1[source_idx] is not None else '')
                            else:
                                merged_row.append('')
                        writer.writerow(merged_row)
                        continue
                    key_value = str(row1[key_column1]).strip()
                    if not key_value:
                        merged_row = []
                        for source_file, source_idx in merged_column_mapping:
                            if source_file == 1 and source_idx is not None and source_idx < len(row1):
                                merged_row.append(row1[source_idx] if row1[source_idx] is not None else '')
                            else:
                                merged_row.append('')
                        writer.writerow(merged_row)
                        continue
                
                # 查找第二个文件中匹配的行
                row2 = None
                if key_value in file2_index:
                    row2 = file2_index[key_value]
                
                # 根据列映射构建合并行
                merged_row = []
                for source_file, source_idx in merged_column_mapping:
                    if source_file == 1 and source_idx is not None:
                        if source_idx < len(row1):
                            merged_row.append(row1[source_idx] if row1[source_idx] is not None else '')
                        else:
                            merged_row.append('')
                    elif source_file == 2 and source_idx is not None:
                        if row2 and source_idx < len(row2):
                            merged_row.append(row2[source_idx] if row2[source_idx] is not None else '')
                        else:
                            merged_row.append('')
                    else:
                        merged_row.append('')
                
                writer.writerow(merged_row)
            
            # 处理第二个文件中独有的记录（在第一个文件中不存在的）
            file1_keys = set()
            for row1 in rows1:
                if use_composite_key:
                    if (key_column1 < len(row1) and row1[key_column1] is not None and
                        key_column1_secondary < len(row1) and row1[key_column1_secondary] is not None):
                        key1_value = str(row1[key_column1]).strip()
                        key2_value = str(row1[key_column1_secondary]).strip()
                        if key1_value and key2_value:
                            file1_keys.add((key1_value, key2_value))
                else:
                    if key_column1 < len(row1) and row1[key_column1] is not None:
                        key_value = str(row1[key_column1]).strip()
                        if key_value:
                            file1_keys.add(key_value)
            
            for row2 in rows2:
                if use_composite_key:
                    if (key_column2 < len(row2) and row2[key_column2] is not None and
                        key_column2_secondary < len(row2) and row2[key_column2_secondary] is not None):
                        key1_value = str(row2[key_column2]).strip()
                        key2_value = str(row2[key_column2_secondary]).strip()
                        if key1_value and key2_value:
                            key_value = (key1_value, key2_value)
                            if key_value not in file1_keys:
                                # 构建合并行（第一个文件的数据用空值）
                                merged_row = []
                                for source_file, source_idx in merged_column_mapping:
                                    if source_file == 2 and source_idx is not None:
                                        if source_idx < len(row2):
                                            merged_row.append(row2[source_idx] if row2[source_idx] is not None else '')
                                        else:
                                            merged_row.append('')
                                    else:
                                        merged_row.append('')
                                writer.writerow(merged_row)
                else:
                    if key_column2 < len(row2) and row2[key_column2] is not None:
                        key_value = str(row2[key_column2]).strip()
                        if key_value and key_value not in file1_keys:
                            # 构建合并行（第一个文件的数据用空值）
                            merged_row = []
                            for source_file, source_idx in merged_column_mapping:
                                if source_file == 2 and source_idx is not None:
                                    if source_idx < len(row2):
                                        merged_row.append(row2[source_idx] if row2[source_idx] is not None else '')
                                    else:
                                        merged_row.append('')
                                else:
                                    merged_row.append('')
                            writer.writerow(merged_row)
        
        print(f"✅ 全量数据合并文件写入完成: {output_path}")
    except Exception as e:
        print(f"写入全量数据合并文件失败: {output_path}")
        print(f"错误详情: {e}")
        import traceback
        traceback.print_exc()
