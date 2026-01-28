#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
原数据文件和接口输出的文件进行校对（内存优化版）
功能：使用流式处理减少内存占用
"""

import os
import sys
from datetime import datetime, timedelta
from typing import Dict, List

# 添加父目录到路径
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../..'))

# 导入公共工具模块
from common.csv_tool import read_csv_with_encoding, CSVStreamWriter
from common.value_comparator import compare_values


class DataComparatorOptimized:
    """数据对比器（内存优化版）"""

    def __init__(
        self,
        param1_column: int = 1,
        param2_column: int = 3,
        feature_start_column: int = 4,
        add_one_second: bool = False,
    ):
        self.param1_column = param1_column
        self.param2_column = param2_column
        self.feature_start_column = feature_start_column
        self.add_one_second = add_one_second
    
    def _normalize_timestamp(self, time_str: str) -> str:
        """标准化时间戳格式"""
        if not time_str or not time_str.strip():
            return time_str
            
        time_str = time_str.strip()
        
        if 'T' in time_str:
            if '.' not in time_str:
                return time_str + ".000"
            else:
                parts = time_str.split('.')
                if len(parts) == 2:
                    milliseconds = parts[1][:3].ljust(3, '0')
                    return f"{parts[0]}.{milliseconds}"
                return time_str
        else:
            if len(time_str) >= 19:
                base_part = time_str[0:10] + "T" + time_str[11:19]
                
                if '.' in time_str and len(time_str) > 19:
                    milliseconds = time_str[20:23].ljust(3, '0')
                    return f"{base_part}.{milliseconds}"
                else:
                    return f"{base_part}.000"
            else:
                return time_str
    
    def _add_one_second(self, time_str: str) -> str:
        """将时间字符串加1秒"""
        if not time_str or not time_str.strip():
            return time_str
        
        try:
            time_str_clean = time_str.strip().replace('T', ' ')
            
            if '.' in time_str_clean:
                dt = datetime.strptime(time_str_clean, "%Y-%m-%d %H:%M:%S.%f")
            else:
                dt = datetime.strptime(time_str_clean, "%Y-%m-%d %H:%M:%S")
            
            dt_plus_one = dt + timedelta(seconds=1)
            return dt_plus_one.strftime("%Y-%m-%dT%H:%M:%S.%f")[:23]
        except (ValueError, TypeError):
            return time_str
    
    def _calculate_request_time(self, time_value: str) -> str:
        """计算请求接口时使用的时间"""
        if not time_value:
            return ""
        
        time_value_cleaned = time_value.strip()
        if 'a' in time_value_cleaned or 'A' in time_value_cleaned:
            time_value_cleaned = time_value_cleaned.replace('a', '').replace('A', '')
        
        base_time = self._normalize_timestamp(time_value_cleaned)
        
        if self.add_one_second:
            request_time = self._add_one_second(base_time)
        else:
            request_time = base_time
        
        return request_time
    
    def _find_apply_id_field(self, headers: List[str], row: List[str]) -> str:
        """查找apply_id相关字段"""
        field_names = ['use_credit_id', 'apply_id', 'use_credit_apply_id', 'loan_no', 'ua_id', 'ua_no']
        
        for field_name in field_names:
            for i, header in enumerate(headers):
                if header.lower() == field_name.lower():
                    if i < len(row) and row[i] is not None:
                        value = str(row[i]).strip()
                        if value:
                            return value
        
        return ""

    def compare_files_streaming(
        self,
        original_csv_path: str,
        api_data_csv_path: str,
        output_path: str,
    ):
        """
        对比两个CSV文件（流式处理版本）
        
        优化策略：
        1. 只构建轻量级索引（不存储完整行数据）
        2. 流式写入结果（不在内存中累积）
        3. 及时释放不需要的数据
        """
        print(f"\n[内存优化版] 开始对比文件")
        print(f"原始文件: {original_csv_path}")
        print(f"接口数据文件: {api_data_csv_path}")
        
        # 第一步：读取表头和基本信息
        original_headers, original_rows = read_csv_with_encoding(original_csv_path)
        api_headers, api_rows = read_csv_with_encoding(api_data_csv_path)
        
        print(f"\n原始文件: {len(original_rows)} 行, {len(original_headers)} 列")
        print(f"接口数据文件: {len(api_rows)} 行, {len(api_headers)} 列")
        
        # 第二步：构建轻量级索引（只存储必要的特征值，不存储整行）
        print(f"\n构建轻量级索引...")
        api_data_index = self._build_lightweight_index(
            api_rows, api_headers,
            self.param1_column, self.param2_column,
            self.feature_start_column
        )
        print(f"索引构建完成，共 {len(api_data_index)} 条记录")
        
        # 第三步：流式对比并输出
        print(f"\n开始流式对比...")
        self._compare_and_write_streaming(
            original_headers, original_rows,
            api_headers, api_data_index,
            output_path
        )
        
        print(f"\n✅ 对比完成！")
    
    def _build_lightweight_index(
        self,
        rows: List[List[str]],
        headers: List[str],
        key_col1: int,
        key_col2: int,
        feature_start: int
    ) -> Dict:
        """
        构建轻量级索引
        只存储：主键 -> {特征名: 特征值}
        不存储完整行数据，大幅减少内存占用
        """
        index = {}
        feature_headers = headers[feature_start:] if len(headers) > feature_start else []
        
        # 查找time_now列
        time_now_idx = None
        for i, header in enumerate(headers):
            if header.lower() == "time_now":
                time_now_idx = i
                break
        
        for i, row in enumerate(rows):
            if i % 1000 == 0 and i > 0:
                print(f"  已索引: {i}/{len(rows)}")
            
            if key_col1 >= len(row) or key_col2 >= len(row):
                continue
            
            key1 = row[key_col1].strip() if row[key_col1] else ""
            key2 = row[key_col2].strip() if row[key_col2] else ""
            
            if not key1 or not key2:
                continue
            
            key = (key1, key2)
            
            # 只存储特征值，不存储整行
            features = {}
            for j, feat_header in enumerate(feature_headers):
                feat_idx = feature_start + j
                if feat_idx < len(row):
                    features[feat_header] = row[feat_idx]
            
            # 存储time_now（如果存在）
            time_now = ""
            if time_now_idx is not None and time_now_idx < len(row):
                time_now = str(row[time_now_idx]).strip() if row[time_now_idx] else ""
            
            index[key] = {
                "features": features,
                "time_now": time_now
            }
        
        return index
    
    def _compare_and_write_streaming(
        self,
        orig_headers: List[str],
        orig_rows: List[List[str]],
        api_headers: List[str],
        api_index: Dict,
        output_path: str
    ):
        """
        流式对比并写入结果
        边对比边写入，不在内存中累积结果
        """
        # 准备输出文件
        base_path = output_path.replace(".csv", "")
        analysis_path = f"{base_path}_analysis_report.csv"
        feature_stats_path = f"{base_path}_feature_stats.csv"
        
        # 获取特征列
        original_feature_headers = orig_headers[self.feature_start_column:] if len(orig_headers) > self.feature_start_column else []
        original_feature_headers = [h for h in original_feature_headers if h.lower() not in ["pt", "time_now"]]
        
        # 初始化特征统计
        feature_stats = {}
        for header in original_feature_headers:
            feature_stats[header] = {"total": 0, "match": 0, "mismatch": 0}
        
        # 检查是否有time_now字段
        has_time_now = any(v.get("time_now") for v in api_index.values())
        
        # 准备输出表头
        if has_time_now:
            output_headers = ["特征名", "cust_no", "use_credit_apply_id", "use_create_time", "CSV值", "API值", "time_now"]
        else:
            output_headers = ["特征名", "cust_no", "use_credit_apply_id", "use_create_time", "CSV值", "API值"]
        
        # 流式写入分析报告
        matched_count = 0
        unmatched_count = 0
        
        with CSVStreamWriter(analysis_path, output_headers) as writer:
            for i, orig_row in enumerate(orig_rows):
                if i % 1000 == 0:
                    print(f"  已对比: {i}/{len(orig_rows)}")
                
                # 获取主键
                if self.param1_column >= len(orig_row) or self.param2_column >= len(orig_row):
                    unmatched_count += 1
                    continue
                
                cust_no = orig_row[self.param1_column].strip() if orig_row[self.param1_column] else ""
                use_create_time = orig_row[self.param2_column].strip() if orig_row[self.param2_column] else ""
                
                if not cust_no or not use_create_time:
                    unmatched_count += 1
                    continue
                
                request_time = self._calculate_request_time(use_create_time)
                apply_id_value = self._find_apply_id_field(orig_headers, orig_row)
                
                key = (cust_no, use_create_time)
                
                # 在索引中查找
                if key not in api_index:
                    unmatched_count += 1
                    continue
                
                matched_count += 1
                api_data = api_index[key]
                api_features = api_data["features"]
                time_now_value = api_data.get("time_now", "")
                
                # 对比特征
                for j, header in enumerate(original_feature_headers):
                    orig_col_idx = self.feature_start_column + j
                    if orig_col_idx >= len(orig_row):
                        continue
                    
                    csv_value = orig_row[orig_col_idx] if orig_col_idx < len(orig_row) else ""
                    api_value = api_features.get(header)
                    
                    is_match = compare_values(csv_value, api_value, header)
                    
                    # 更新统计
                    feature_stats[header]["total"] += 1
                    if is_match:
                        feature_stats[header]["match"] += 1
                    else:
                        feature_stats[header]["mismatch"] += 1
                        
                        # 立即写入差异记录
                        api_value_str = "null" if api_value is None else str(api_value)
                        if has_time_now:
                            writer.write_row([header, cust_no, apply_id_value, request_time, csv_value, api_value_str, time_now_value])
                        else:
                            writer.write_row([header, cust_no, apply_id_value, request_time, csv_value, api_value_str])
        
        print(f"\n对比完成: 匹配 {matched_count} 条, 未匹配 {unmatched_count} 条")
        
        # 写入特征统计
        self._write_feature_stats_streaming(feature_stats_path, feature_stats, matched_count)
    
    def _write_feature_stats_streaming(self, output_path: str, feature_stats: Dict, matched_count: int):
        """流式写入特征统计"""
        no_anomaly_count = sum(1 for stats in feature_stats.values() if stats["mismatch"] == 0)
        has_anomaly_count = sum(1 for stats in feature_stats.values() if stats["mismatch"] > 0)
        
        output_headers = ["特征名", "是否有异常", "比对数据条数", "匹配数量", "异常数量", "匹配率(%)", "异常率(%)"]
        
        with CSVStreamWriter(output_path, output_headers) as writer:
            # 写入汇总
            writer.write_row(["特征统计", "", "", "", "", "", ""])
            writer.write_row(["无异常特征总数", str(no_anomaly_count), "", "", "", "", ""])
            writer.write_row(["有异常特征总数", str(has_anomaly_count), "", "", "", "", ""])
            writer.write_row(["", "", "", "", "", "", ""])
            
            # 先写无异常的
            for feature_name, stats in sorted(feature_stats.items()):
                if stats["mismatch"] == 0:
                    match_ratio = stats["match"] / stats["total"] * 100 if stats["total"] > 0 else 0
                    writer.write_row([
                        feature_name, "无异常",
                        str(stats["total"]), str(stats["match"]), "0",
                        f"{match_ratio:.2f}", "0.00"
                    ])
            
            # 再写有异常的（按异常率降序）
            anomaly_features = [(name, stats) for name, stats in feature_stats.items() if stats["mismatch"] > 0]
            anomaly_features.sort(key=lambda x: x[1]["mismatch"] / x[1]["total"] if x[1]["total"] > 0 else 0, reverse=True)
            
            for feature_name, stats in anomaly_features:
                match_ratio = stats["match"] / stats["total"] * 100 if stats["total"] > 0 else 0
                mismatch_ratio = stats["mismatch"] / stats["total"] * 100 if stats["total"] > 0 else 0
                writer.write_row([
                    feature_name, "有异常",
                    str(stats["total"]), str(stats["match"]), str(stats["mismatch"]),
                    f"{match_ratio:.2f}", f"{mismatch_ratio:.2f}"
                ])
        
        print(f"✅ 特征统计已写入: {output_path}")
