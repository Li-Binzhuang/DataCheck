#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
报告生成器模块
功能：生成差异特征汇总和差异数据明细文件
"""

import csv
import os
import sys
import re
from datetime import datetime
from typing import Any, Dict, List

# 添加公共工具目录到路径
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../../common'))
from csv_tool import write_csv_file

# 导入报告生成函数（避免循环导入）


def format_time_to_standard(value: Any) -> str:
    """
    将时间值格式化为标准格式 yyyy-mm-dd hh:mm:ss.000
    
    支持的时间格式：
    - ISO格式: "2024-01-01T12:00:00" 或 "2024-01-01T12:00:00.123"
    - 标准格式: "2024-01-01 12:00:00" 或 "2024-01-01 12:00:00.123"
    - 时间戳（毫秒）: 1704067200000
    - 其他常见格式
    
    Args:
        value: 时间值（可能是字符串、数字或datetime对象）
    
    Returns:
        格式化后的时间字符串，格式为 yyyy-mm-dd hh:mm:ss.000
        如果无法解析，返回原值的字符串形式
    """
    if value is None or value == "":
        return ""
    
    # 如果是数字（可能是时间戳）
    if isinstance(value, (int, float)):
        try:
            # 判断是秒级还是毫秒级时间戳
            if value > 1e10:  # 毫秒级时间戳（13位数字）
                dt = datetime.fromtimestamp(value / 1000)
            else:  # 秒级时间戳（10位数字）
                dt = datetime.fromtimestamp(value)
            return dt.strftime("%Y-%m-%d %H:%M:%S.000")
        except (ValueError, OSError):
            return str(value)
    
    # 如果是datetime对象
    if isinstance(value, datetime):
        return value.strftime("%Y-%m-%d %H:%M:%S.000")
    
    # 如果是字符串
    if isinstance(value, str):
        value = value.strip()
        if not value or value.lower() in ["null", "none", "nan", ""]:
            return ""
        
        # 处理T分隔符格式，转换为空格
        if 'T' in value:
            value = value.replace('T', ' ')
        
        # 尝试解析各种时间格式
        time_formats = [
            "%Y-%m-%d %H:%M:%S.%f",  # 2024-01-01 12:00:00.123456
            "%Y-%m-%d %H:%M:%S",      # 2024-01-01 12:00:00
            "%Y/%m/%d %H:%M:%S.%f",  # 2024/01/01 12:00:00.123456
            "%Y/%m/%d %H:%M:%S",     # 2024/01/01 12:00:00
        ]
        
        for fmt in time_formats:
            try:
                dt = datetime.strptime(value, fmt)
                # 格式化为标准格式，保留毫秒（3位）
                formatted = dt.strftime("%Y-%m-%d %H:%M:%S.%f")
                # 截取到毫秒部分（.000），总长度23个字符
                return formatted[:23]
            except ValueError:
                continue
        
        # 如果所有格式都不匹配，尝试使用正则表达式提取时间部分
        # 匹配格式：yyyy-mm-dd hh:mm:ss 或 yyyy-mm-dd hh:mm:ss.xxx
        time_pattern = r'(\d{4}-\d{2}-\d{2})\s+(\d{2}:\d{2}:\d{2})(?:\.(\d+))?'
        match = re.search(time_pattern, value)
        if match:
            date_part = match.group(1)
            time_part = match.group(2)
            milliseconds = match.group(3) if match.group(3) else "000"
            # 确保毫秒是3位：如果超过3位则截取，如果不足3位则补0
            if len(milliseconds) > 3:
                milliseconds = milliseconds[:3]
            else:
                milliseconds = milliseconds.ljust(3, '0')
            return f"{date_part} {time_part}.{milliseconds}"
        
        # 如果无法解析，返回原值
        return value
    
    # 其他类型，转换为字符串
    return str(value)


def format_number_value(value: Any) -> str:
    """
    格式化数值，保留完整的小数位数，避免精度丢失
    
    Args:
        value: 要格式化的值（可能是整数、浮点数或其他类型）
        
    Returns:
        格式化后的字符串，保留完整精度
    """
    if value is None:
        return ""
    
    # 如果是浮点数，保留完整精度
    if isinstance(value, float):
        # 如果值是整数（如 1.0），显示为整数格式
        if value == int(value):
            return str(int(value))
        
        # 使用 repr() 可以保留浮点数的完整精度
        value_str = repr(value)
        
        # 如果 repr() 返回科学计数法，使用格式化字符串保留更多小数位
        if 'e' in value_str.lower() or 'E' in value_str:
            # 使用足够的小数位数（17位）来保留精度
            formatted = f"{value:.17f}"
            # 去掉末尾的0，但保留小数点（如果有小数部分）
            formatted = formatted.rstrip('0')
            if formatted.endswith('.'):
                formatted = formatted[:-1]
            return formatted
        
        # 如果 repr() 返回普通格式，直接使用
        return value_str
    
    # 如果是整数，直接转换为字符串
    if isinstance(value, int):
        return str(value)
    
    # 其他类型，转换为字符串
    return str(value)


def generate_reports(
    output_path: str,
    differences_dict: Dict,
    all_features: List[str],
    feature_stats: Dict,
    matched_count: int,
    total_comparisons: int,
    match_count: int,
    diff_count: int,
    match_ratio: float,
    unmatched_rows: List = None,
    online_only_rows: List = None,
    headers_offline: List = None,
    headers_online: List = None,
    rows_offline: List = None,
    rows_online: List = None,
    offline_key_column_index: int = None,
    online_key_column_index: int = None,
    offline_feature_start_column: int = None,
    online_feature_start_column: int = None,
):
    """
    生成差异特征汇总和差异数据明细文件（CSV格式）
    
    Args:
        output_path: 输出文件基础路径
        differences_dict: 差异数据字典 {(key_value, feature_name): (offline_value, online_value, cust_no, offline_time, online_time)}
        all_features: 所有特征列表
        feature_stats: 特征统计字典
        matched_count: 匹配记录数
        total_comparisons: 总对比次数
        match_count: 一致数量
        diff_count: 差异数量
        match_ratio: 一致率
        unmatched_rows: 仅在离线表中的数据行列表
        online_only_rows: 仅在线上文件中的数据行列表
        headers_offline: 离线文件的表头
        headers_online: 在线文件的表头
    """
    base_path = output_path.replace('.csv', '').replace('.xlsx', '')
    
    # 获取有差异的特征列表
    diff_features = [f for f, s in feature_stats.items() if s["diff_count"] > 0]
    diff_features_sorted = sorted(diff_features, key=lambda f: feature_stats[f]["diff_count"], reverse=True)
    
    # 统计差异客户数
    diff_keys = set()
    for (key_value, feature) in differences_dict.keys():
        diff_keys.add(key_value)
    diff_key_count = len(diff_keys)
    
    # 使用CSV格式
    write_csv_reports(
        base_path, differences_dict, all_features, feature_stats,
        matched_count, total_comparisons, match_count, diff_count, match_ratio,
        diff_key_count, diff_features_sorted
    )
    
    # 生成特征统计文件
    write_feature_statistics(
        base_path, all_features, feature_stats, matched_count
    )
    
    # 生成仅在离线表中的数据文件
    if unmatched_rows and headers_offline:
        write_offline_only_data(base_path, unmatched_rows, headers_offline)
    
    # 生成仅在线上文件中的数据文件
    if online_only_rows and headers_online:
        write_online_only_data(base_path, online_only_rows, headers_online)
    
    # 生成全量数据合并文件
    if (rows_offline and rows_online and headers_offline and headers_online and
        offline_key_column_index is not None and online_key_column_index is not None):
        merged_data_path = f"{base_path}_全量数据合并.csv"
        write_merged_data_csv_online(
            merged_data_path,
            headers_offline,
            rows_offline,
            headers_online,
            rows_online,
            offline_key_column_index,
            online_key_column_index,
            suffix1="_离线",
            suffix2="_在线",
            feature_start_column1=offline_feature_start_column,
            feature_start_column2=online_feature_start_column,
        )


def write_csv_reports(
    base_path: str,
    differences_dict: Dict,
    all_features: List[str],
    feature_stats: Dict,
    matched_count: int,
    total_comparisons: int,
    match_count: int,
    diff_count: int,
    match_ratio: float,
    diff_key_count: int,
    diff_features_sorted: List[str],
):
    """写入CSV格式的报告"""
    
    # 1. 差异特征汇总
    summary_path = f"{base_path}_差异特征汇总.csv"
    with open(summary_path, "w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["特征名", "总数", "差异数", "差异占比"])
        
        for feature in diff_features_sorted:
            stats = feature_stats[feature]
            diff_ratio = stats["diff_count"] / matched_count * 100 if matched_count > 0 else 0
            writer.writerow([feature, matched_count, stats["diff_count"], f"{diff_ratio:.2f}%"])
    
    print(f"差异特征汇总文件写入完成: {summary_path}")
    
    # 2. 差异数据明细（包含cust_no、离线时间、在线时间，如果存在time_now字段则也包含）
    detail_path = f"{base_path}_差异数据明细.csv"
    
    # 检查是否有time_now字段（检查差异数据中是否有6个元素，且第6个元素不为空）
    has_time_now = False
    for diff_data in differences_dict.values():
        if len(diff_data) >= 6:
            time_now_value = diff_data[5]
            if time_now_value is not None and str(time_now_value).strip() != "":
                has_time_now = True
                break
    
    with open(detail_path, "w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f)
        
        # 根据是否有time_now字段动态构建表头
        if has_time_now:
            writer.writerow(["主键值", "cust_no", "Sql特征时间", "json落数时间", "特征名", "Sql值", "json值", "请求时间"])
        else:
            writer.writerow(["主键值", "cust_no", "Sql特征时间", "json落数时间", "特征名", "Sql值", "json值"])
        
        # 对差异记录进行排序
        sorted_diff_items = []
        for (key_value, feature), diff_data in differences_dict.items():
            # diff_data格式: (offline_value, online_value, cust_no, offline_time, online_time, time_now)
            if len(diff_data) >= 6:
                offline_value, online_value, cust_no, offline_time_value, online_time_value, time_now_value = diff_data
            elif len(diff_data) >= 5:
                # 兼容旧格式（如果只有5个元素，可能是旧格式：offline_value, online_value, cust_no, offline_time, online_time）
                offline_value, online_value, cust_no, offline_time_value, online_time_value = diff_data
                time_now_value = ""
            elif len(diff_data) >= 4:
                # 兼容更旧的格式（如果只有4个元素，可能是旧格式：offline_value, online_value, cust_no, time）
                offline_value, online_value, cust_no, time_value = diff_data
                offline_time_value, online_time_value, time_now_value = time_value, "", ""
            else:
                # 兼容更旧的格式（如果没有cust_no和time）
                offline_value, online_value = diff_data[0], diff_data[1]
                cust_no, offline_time_value, online_time_value, time_now_value = "", "", "", ""
            sorted_diff_items.append((key_value, cust_no, offline_time_value, online_time_value, feature, offline_value, online_value, time_now_value))
        
        sorted_diff_items.sort(key=lambda x: (x[4], x[0]))  # 按特征名、主键值排序
        
        rows_written = 0
        for key_value, cust_no, offline_time_value, online_time_value, feature, offline_value, online_value, time_now_value in sorted_diff_items:
            # 格式化数值
            offline_str = format_number_value(offline_value) if isinstance(offline_value, (int, float)) else str(offline_value).strip()
            online_str = format_number_value(online_value) if isinstance(online_value, (int, float)) else str(online_value).strip()
            
            # 离线时间保留原始格式
            offline_time_str = str(offline_time_value) if offline_time_value is not None and offline_time_value != "" else ""
            
            # 在线时间保留原始格式（从原始线上文件获取的时间字段原值，不做格式化）
            online_time_str = str(online_time_value) if online_time_value is not None and online_time_value != "" else ""
            
            # 根据是否有time_now字段动态构建数据行
            if has_time_now:
                # time_now字段保留原始格式
                time_now_str = str(time_now_value) if time_now_value is not None and time_now_value != "" else ""
                writer.writerow([key_value, cust_no, offline_time_str, online_time_str, feature, offline_str, online_str, time_now_str])
            else:
                writer.writerow([key_value, cust_no, offline_time_str, online_time_str, feature, offline_str, online_str])
            rows_written += 1
    
    print(f"差异数据明细文件写入完成: {detail_path}，共 {rows_written} 行数据")


def write_feature_statistics(
    base_path: str,
    all_features: List[str],
    feature_stats: Dict,
    matched_count: int,
):
    """
    写入特征统计文件（汇总到一个表格，去除冗余）
    
    Args:
        base_path: 输出文件基础路径
        all_features: 所有特征列表
        feature_stats: 特征统计字典
        matched_count: 匹配记录数
    """
    stats_path = f"{base_path}_特征统计.csv"
    
    with open(stats_path, "w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f)
        
        # 表头
        writer.writerow(["特征名", "是否有异常", "比对数据", "匹配数量", "异常数量", "匹配率(%)", "异常率(%)"])
        
        # 将所有特征汇总到一个表格中，按特征名排序
        for feature in sorted(all_features):
            stats = feature_stats.get(feature, {"diff_count": 0})
            diff_count = stats["diff_count"]
            has_diff = diff_count > 0
            
            match_count = matched_count - diff_count
            match_rate = match_count / matched_count * 100 if matched_count > 0 else 0
            diff_rate = diff_count / matched_count * 100 if matched_count > 0 else 0
            
            writer.writerow([
                feature,
                "是" if has_diff else "否",
                matched_count,
                match_count,
                diff_count,
                f"{match_rate:.2f}",
                f"{diff_rate:.2f}"
            ])
    
    print(f"特征统计文件写入完成: {stats_path}，共 {len(all_features)} 个特征")


def write_offline_only_data(
    base_path: str,
    offline_only_rows: List,
    headers_offline: List,
):
    """
    写入仅在离线表中的数据文件
    
    Args:
        base_path: 输出文件基础路径
        offline_only_rows: 仅在离线表中的数据行列表
        headers_offline: 离线文件的表头
    """
    if not offline_only_rows:
        print(f"仅在离线表中的数据: 0条记录，跳过文件生成")
        return
    
    offline_only_path = f"{base_path}_仅在离线表中的数据.csv"
    
    with open(offline_only_path, "w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f)
        # 写入表头
        writer.writerow(headers_offline)
        
        # 写入数据行
        for row in offline_only_rows:
            # 确保行的长度与表头一致，不足的用空字符串填充
            row_data = list(row) if len(row) >= len(headers_offline) else list(row) + [''] * (len(headers_offline) - len(row))
            writer.writerow(row_data[:len(headers_offline)])
    
    print(f"仅在离线表中的数据文件写入完成: {offline_only_path}，共 {len(offline_only_rows)} 行数据")


def write_online_only_data(
    base_path: str,
    online_only_rows: List,
    headers_online: List,
):
    """
    写入仅在线上文件中的数据文件
    
    Args:
        base_path: 输出文件基础路径
        online_only_rows: 仅在线上文件中的数据行列表
        headers_online: 在线文件的表头
    """
    if not online_only_rows:
        print(f"仅在线上文件中的数据: 0条记录，跳过文件生成")
        return
    
    online_only_path = f"{base_path}_仅在线上文件中的数据.csv"
    
    with open(online_only_path, "w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f)
        # 写入表头
        writer.writerow(headers_online)
        
        # 写入数据行
        for row in online_only_rows:
            # 确保行的长度与表头一致，不足的用空字符串填充
            row_data = list(row) if len(row) >= len(headers_online) else list(row) + [''] * (len(headers_online) - len(row))
            writer.writerow(row_data[:len(headers_online)])
    
    print(f"仅在线上文件中的数据文件写入完成: {online_only_path}，共 {len(online_only_rows)} 行数据")


def _normalize_key_column_index(key_column_index):
    """将主键列索引统一转换为列表格式"""
    if isinstance(key_column_index, list):
        return key_column_index
    return [key_column_index]


def _build_composite_key(row, key_indices):
    """根据多列索引构建组合主键值，多列用 | 拼接"""
    parts = []
    for idx in key_indices:
        if idx < len(row) and row[idx] is not None:
            parts.append(str(row[idx]).strip())
        else:
            parts.append("")
    return "|".join(parts)


def write_merged_data_csv_online(
    output_path: str,
    headers1: List[str],
    rows1: List[List[str]],
    headers2: List[str],
    rows2: List[List[str]],
    key_column1,
    key_column2,
    suffix1: str = "_离线",
    suffix2: str = "_在线",
    feature_start_column1: int = None,
    feature_start_column2: int = None,
):
    """
    写入合并的全量数据文件（CSV格式）- 线上灰度落数对比专用
    将两个文件的数据根据主键合并，列名加后缀区分
    非特征列只显示第一个文件的，特征列按特征名分组，相同特征名的列挨着
    
    Args:
        output_path: 输出文件路径
        headers1: 第一个文件的表头（离线文件）
        rows1: 第一个文件的数据行（离线文件）
        headers2: 第二个文件的表头（在线文件）
        rows2: 第二个文件的数据行（在线文件）
        key_column1: 第一个文件的主键列索引
        key_column2: 第二个文件的主键列索引
        suffix1: 第一个文件列名的后缀（默认：_离线）
        suffix2: 第二个文件列名的后缀（默认：_在线）
        feature_start_column1: 第一个文件特征列起始索引（可选）
        feature_start_column2: 第二个文件特征列起始索引（可选）
    """
    # 确保输出目录存在
    output_dir = os.path.dirname(output_path)
    if output_dir and not os.path.exists(output_dir):
        try:
            os.makedirs(output_dir, exist_ok=True)
        except Exception as e:
            print(f"创建目录失败: {output_dir}, 错误: {e}")
    
    # 统一转换为列表格式，兼容单列和多列
    key_indices1 = _normalize_key_column_index(key_column1)
    key_indices2 = _normalize_key_column_index(key_column2)
    
    # 构建第二个文件的索引（以组合主键为key）
    file2_index = {}
    for i, row in enumerate(rows2):
        key_value = _build_composite_key(row, key_indices2)
        empty_key = "|".join([""] * len(key_indices2))
        if key_value and key_value != empty_key:
            file2_index[key_value] = row
    
    # 确定特征列起始位置
    if feature_start_column1 is None:
        feature_start_column1 = max(key_indices1) + 1
    if feature_start_column2 is None:
        feature_start_column2 = max(key_indices2) + 1
    
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
        if feat1.lower() != "time_now":  # 排除time_now列（time_now不作为特征对比）
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
        if feat1.lower() != "time_now" and feat1 not in feature_mapping:
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
                key_value = _build_composite_key(row1, key_indices1)
                empty_key = "|".join([""] * len(key_indices1))
                
                if not key_value or key_value == empty_key:
                    # 如果主键为空，构建合并行
                    merged_row = []
                    for source_file, source_idx in merged_column_mapping:
                        if source_file == 1 and source_idx is not None and source_idx < len(row1):
                            merged_row.append(row1[source_idx] if row1[source_idx] is not None else '')
                        else:
                            merged_row.append('')
                    writer.writerow(merged_row)
                    continue
                
                # 查找第二个文件中匹配的行
                row2 = file2_index.get(key_value)
                
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
                key_value = _build_composite_key(row1, key_indices1)
                empty_key = "|".join([""] * len(key_indices1))
                if key_value and key_value != empty_key:
                    file1_keys.add(key_value)
            
            for row2 in rows2:
                key_value = _build_composite_key(row2, key_indices2)
                empty_key = "|".join([""] * len(key_indices2))
                if key_value and key_value != empty_key and key_value not in file1_keys:
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
