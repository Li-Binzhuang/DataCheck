#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
原数据文件和接口输出的文件进行校对
功能：读取原始CSV文件和接口输出的CSV文件，对比特征值，输出差异报告
"""

import os
import sys
from datetime import datetime, timedelta
from typing import Dict, List

# 添加父目录到路径，以便导入公共工具模块
# job文件夹在场景1_接口数据对比下，公共工具在上一级目录
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../..'))

# 导入公共工具模块
from common.csv_tool import read_csv_with_encoding
from common.value_comparator import compare_values
from common.report_generator import write_analysis_record_csv, write_feature_stats_csv, write_merged_data_csv


class DataComparator:
    """数据对比器"""

    def __init__(
        self,
        param1_column: int = 1,  # cust_no所在列
        param2_column: int = 3,  # use_create_time所在列
        feature_start_column: int = 4,  # 特征开始列（E列，索引4）
        add_one_second: bool = False,  # 是否在请求接口时加1秒
    ):
        self.param1_column = param1_column
        self.param2_column = param2_column
        self.feature_start_column = feature_start_column
        self.add_one_second = add_one_second
    
    def _normalize_timestamp(self, time_str: str) -> str:
        """标准化时间戳格式，确保毫秒精度一致"""
        if not time_str or not time_str.strip():
            return time_str
            
        time_str = time_str.strip()
        
        # 如果已经包含T，处理现有格式
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
            # 空格分隔格式，转换为T格式
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
        """计算请求接口时使用的时间（baseTime）"""
        if not time_value:
            return ""
        
        # 去除字母'a'
        time_value_cleaned = time_value.strip()
        if 'a' in time_value_cleaned or 'A' in time_value_cleaned:
            time_value_cleaned = time_value_cleaned.replace('a', '').replace('A', '')
        
        # 标准化时间格式
        base_time = self._normalize_timestamp(time_value_cleaned)
        
        # 根据配置决定是否加1秒
        if self.add_one_second:
            request_time = self._add_one_second(base_time)
        else:
            request_time = base_time
        
        return request_time
    
    def _find_apply_id_field(self, headers: List[str], row: List[str]) -> str:
        """从输入文件中查找use_credit_id、apply_id、use_credit_apply_id、loan_no、ua_id或ua_no字段"""
        # 优先查找use_credit_id字段
        field_names = ['use_credit_id', 'apply_id', 'use_credit_apply_id', 'loan_no', 'ua_id', 'ua_no']
        
        for field_name in field_names:
            for i, header in enumerate(headers):
                if header.lower() == field_name.lower():
                    if i < len(row) and row[i] is not None:
                        value = str(row[i]).strip()
                        if value:
                            return value
        
        return ""

    def compare_files(
        self,
        original_csv_path: str,
        api_data_csv_path: str,
        output_path: str,
        output_merged_data: bool = True,
    ):
        """
        对比两个CSV文件
        
        Args:
            original_csv_path: 原始CSV文件路径
            api_data_csv_path: 接口数据CSV文件路径
            output_path: 输出文件路径
            output_merged_data: 是否输出全量数据合并文件
        """
        print(f"\n开始对比文件")
        print(f"原始文件: {original_csv_path}")
        print(f"接口数据文件: {api_data_csv_path}")
        
        # 读取两个文件
        original_headers, original_rows = read_csv_with_encoding(original_csv_path)
        api_headers, api_rows = read_csv_with_encoding(api_data_csv_path)
        
        print(f"\n原始文件: {len(original_rows)} 行, {len(original_headers)} 列")
        print(f"接口数据文件: {len(api_rows)} 行, {len(api_headers)} 列")
        
        # 检查行数是否一致
        if len(original_rows) != len(api_rows):
            print(f"警告: 两个文件的行数不一致！原始文件: {len(original_rows)}, 接口数据文件: {len(api_rows)}")
        
        # 找到主键列的索引
        cust_no_idx_orig = self.param1_column if self.param1_column < len(original_headers) else None
        use_create_time_idx_orig = self.param2_column if self.param2_column < len(original_headers) else None
        
        cust_no_idx_api = self.param1_column if self.param1_column < len(api_headers) else None
        use_create_time_idx_api = self.param2_column if self.param2_column < len(api_headers) else None
        
        # 打印列索引信息（用于调试）
        print(f"\n列索引配置:")
        print(f"  原始文件: cust_no列={cust_no_idx_orig} ({original_headers[cust_no_idx_orig] if cust_no_idx_orig is not None and cust_no_idx_orig < len(original_headers) else 'N/A'}), "
              f"use_create_time列={use_create_time_idx_orig} ({original_headers[use_create_time_idx_orig] if use_create_time_idx_orig is not None and use_create_time_idx_orig < len(original_headers) else 'N/A'})")
        print(f"  接口数据文件: cust_no列={cust_no_idx_api} ({api_headers[cust_no_idx_api] if cust_no_idx_api is not None and cust_no_idx_api < len(api_headers) else 'N/A'}), "
              f"use_create_time列={use_create_time_idx_api} ({api_headers[use_create_time_idx_api] if use_create_time_idx_api is not None and use_create_time_idx_api < len(api_headers) else 'N/A'})")
        
        # 打印前几行的主键值示例（用于调试）
        if len(original_rows) > 0:
            print(f"\n原始文件前3行主键值示例:")
            for i in range(min(3, len(original_rows))):
                if cust_no_idx_orig is not None and use_create_time_idx_orig is not None:
                    if cust_no_idx_orig < len(original_rows[i]) and use_create_time_idx_orig < len(original_rows[i]):
                        cust_no = original_rows[i][cust_no_idx_orig].strip() if original_rows[i][cust_no_idx_orig] else ""
                        use_create_time = original_rows[i][use_create_time_idx_orig].strip() if original_rows[i][use_create_time_idx_orig] else ""
                        print(f"  行{i}: cust_no={cust_no}, use_create_time={use_create_time}")
        
        if len(api_rows) > 0:
            print(f"\n接口数据文件前3行主键值示例:")
            for i in range(min(3, len(api_rows))):
                if cust_no_idx_api is not None and use_create_time_idx_api is not None:
                    if cust_no_idx_api < len(api_rows[i]) and use_create_time_idx_api < len(api_rows[i]):
                        cust_no = api_rows[i][cust_no_idx_api].strip() if api_rows[i][cust_no_idx_api] else ""
                        use_create_time = api_rows[i][use_create_time_idx_api].strip() if api_rows[i][use_create_time_idx_api] else ""
                        print(f"  行{i}: cust_no={cust_no}, use_create_time={use_create_time}")
        
        # 构建接口数据文件的索引（使用cust_no和use_create_time作为主键）
        api_data_index = {}
        skipped_api_rows = 0
        for i, row in enumerate(api_rows):
            if cust_no_idx_api is not None and use_create_time_idx_api is not None:
                if cust_no_idx_api < len(row) and use_create_time_idx_api < len(row):
                    cust_no = row[cust_no_idx_api].strip() if row[cust_no_idx_api] else ""
                    use_create_time = row[use_create_time_idx_api].strip() if row[use_create_time_idx_api] else ""
                    if cust_no and use_create_time:
                        key = (cust_no, use_create_time)
                        api_data_index[key] = (i, row)
                    else:
                        skipped_api_rows += 1
                        if skipped_api_rows <= 5:
                            print(f"  跳过接口数据行 {i}: cust_no={cust_no}, use_create_time={use_create_time}")
                else:
                    skipped_api_rows += 1
            else:
                skipped_api_rows += 1
        
        print(f"接口数据索引构建完成，共 {len(api_data_index)} 条记录")
        if skipped_api_rows > 0:
            print(f"  跳过 {skipped_api_rows} 条接口数据行（主键为空或列索引无效）")
        
        # 检查接口数据文件中是否有time_now字段
        time_now_idx_api = None
        for i, header in enumerate(api_headers):
            if header.lower() == "time_now":
                time_now_idx_api = i
                break
        
        if time_now_idx_api is not None:
            print(f"找到接口数据文件time_now列: 索引{time_now_idx_api}")
        else:
            print(f"提示: 接口数据文件中未找到time_now列")
        
        # 获取原始文件的特征列（从feature_start_column开始）
        original_feature_headers = original_headers[self.feature_start_column:] if len(original_headers) > self.feature_start_column else []
        # 排除pt列和time_now列（time_now不是特征，不进行对比，但会输出到CSV）
        original_feature_headers = [h for h in original_feature_headers if h.lower() not in ["pt", "time_now"]]
        
        # 获取接口数据文件的特征列（从feature_start_column开始，以及之后新增的接口字段）
        api_feature_headers = []
        # 先添加原始特征列（如果存在）
        if len(api_headers) > self.feature_start_column:
            api_feature_headers.extend(api_headers[self.feature_start_column:])
        
        # 对比数据
        results = {}
        errors = {}
        feature_stats = {}
        
        # 初始化特征统计
        for header in original_feature_headers:
            feature_stats[header] = {"total": 0, "match": 0, "mismatch": 0}
        
        print(f"\n开始对比数据...")
        for i, orig_row in enumerate(original_rows):
            if i % 1000 == 0:
                print(f"已处理: {i}/{len(original_rows)}")
            
            # 获取主键
            if cust_no_idx_orig is None or use_create_time_idx_orig is None:
                errors[i] = "主键列索引无效"
                continue
            
            if cust_no_idx_orig >= len(orig_row) or use_create_time_idx_orig >= len(orig_row):
                errors[i] = "主键列超出范围"
                continue
            
            cust_no = orig_row[cust_no_idx_orig].strip() if orig_row[cust_no_idx_orig] else ""
            use_create_time = orig_row[use_create_time_idx_orig].strip() if orig_row[use_create_time_idx_orig] else ""
            
            if not cust_no or not use_create_time:
                errors[i] = "主键值为空"
                continue
            
            # 计算请求接口时使用的时间（baseTime）
            request_time = self._calculate_request_time(use_create_time)
            
            # 查找apply_id相关字段
            apply_id_value = self._find_apply_id_field(original_headers, orig_row)
            
            key = (cust_no, use_create_time)
            
            # 在接口数据文件中查找匹配的记录
            if key not in api_data_index:
                # 尝试查找相似的主键（用于调试）
                similar_keys = []
                for api_key in list(api_data_index.keys())[:10]:  # 只检查前10个
                    if api_key[0] == cust_no:  # cust_no相同但时间不同
                        similar_keys.append(api_key)
                
                error_msg = f"在接口数据文件中未找到匹配记录: cust_no={cust_no}, use_create_time={use_create_time}"
                if similar_keys:
                    error_msg += f"\n  提示: 找到相同cust_no但时间不同的记录: {similar_keys[:3]}"
                errors[i] = error_msg
                
                # 打印前几个未匹配的示例
                if len(errors) <= 5:
                    print(f"  未匹配示例 {len(errors)}: cust_no={cust_no}, use_create_time={use_create_time}")
                continue
            
            api_row_idx, api_row = api_data_index[key]
            
            # 获取time_now字段的值（如果存在）
            time_now_value = ""
            if time_now_idx_api is not None and time_now_idx_api < len(api_row):
                raw_time_now = api_row[time_now_idx_api]
                if raw_time_now is not None:
                    time_now_value = str(raw_time_now).strip()
            
            # 对比特征值
            comparison_results = {}
            
            for j, header in enumerate(original_feature_headers):
                orig_col_idx = self.feature_start_column + j
                if orig_col_idx >= len(orig_row):
                    continue
                
                csv_value = orig_row[orig_col_idx] if orig_col_idx < len(orig_row) else ""
                
                # 在接口数据文件中查找对应的字段
                api_value = None
                if header in api_headers:
                    api_col_idx = api_headers.index(header)
                    if api_col_idx < len(api_row):
                        api_value = api_row[api_col_idx]
                
                # 比较值
                is_match = compare_values(csv_value, api_value, header)
                
                # 保存比较结果
                comparison_results[header] = {
                    "csv_value": csv_value,
                    "api_value": api_value,
                    "is_match": is_match,
                }
                
                # 统计
                feature_stats[header]["total"] += 1
                if is_match:
                    feature_stats[header]["match"] += 1
                else:
                    feature_stats[header]["mismatch"] += 1
            
            results[i] = {
                "row_index": i,
                "cust_no": cust_no,
                "use_create_time": request_time,  # 使用请求接口时的baseTime值
                "use_credit_apply_id": apply_id_value,  # 从输入文件中查找的apply_id相关字段
                "time_now": time_now_value,  # 接口返回的time_now字段值（如果存在）
                "comparison_results": comparison_results,
            }
        
        print(f"\n对比完成: 成功 {len(results)} 条, 失败 {len(errors)} 条")
        
        # 统计信息
        total_features = 0
        match_features = 0
        mismatch_features = 0
        
        for result in results.values():
            comparison_results = result.get("comparison_results", {})
            for feature_result in comparison_results.values():
                total_features += 1
                if feature_result.get("is_match", False):
                    match_features += 1
                else:
                    mismatch_features += 1
        
        # 统计无异常特征数量和有异常特征数量
        all_match_feature_count = 0
        anomaly_feature_count = 0
        anomaly_features_list = []
        
        for feature_name, stats in feature_stats.items():
            if stats["mismatch"] == 0:
                all_match_feature_count += 1
            else:
                anomaly_feature_count += 1
                match_ratio = stats["match"] / stats["total"] * 100 if stats["total"] > 0 else 0
                mismatch_ratio = stats["mismatch"] / stats["total"] * 100 if stats["total"] > 0 else 0
                anomaly_features_list.append({
                    "feature_name": feature_name,
                    "total": stats["total"],
                    "match": stats["match"],
                    "mismatch": stats["mismatch"],
                    "match_ratio": match_ratio,
                    "mismatch_ratio": mismatch_ratio,
                })
        
        # 按异常占比排序
        anomaly_features_list.sort(key=lambda x: x["mismatch_ratio"], reverse=True)
        
        # 计算总体匹配率
        overall_match_ratio = match_features / total_features * 100 if total_features > 0 else 0

        # ========== 显示特征值校验结果统计 ==========
        print(f"\n{'='*80}")
        print(f"特征值校验结果统计")
        print(f"\n总体统计:")
        print(f"  总特征值数量: {total_features}")
        print(f"  匹配数量: {match_features}")
        print(f"  不匹配数量: {mismatch_features}")
        
        print(f"\n特征统计:")
        print(f"  无异常特征数量: {all_match_feature_count}")
        print(f"  有异常特征数量: {anomaly_feature_count}")
        
        if anomaly_feature_count > 0:
            print(f"\n有异常特征详情（按异常占比降序）:")
            print(f"  {'特征名':<90} {'总数量':<10} {'异常数量':<10} {'异常占比':<10}")
            print(f"  {'-'*90} {'-'*10} {'-'*10} {'-'*10}")
            for feature in anomaly_features_list:
                print(f"  {feature['feature_name']:<90} {feature['total']:<10} {feature['mismatch']:<10} {feature['mismatch_ratio']:.2f}%")
        
        print(f"\n{'='*90}\n")

        # 写入结果文件
        base_path = output_path.replace(".csv", "")
        
        # 定义要生成的文件路径
        analysis_path = f"{base_path}_analysis_report.csv"
        feature_stats_path = f"{base_path}_feature_stats.csv"
        merged_data_path = f"{base_path}_全量数据合并.csv"
        
        print(f"开始写入结果文件...")
        print(f"1. 分析报告文件: {analysis_path}")
        print(f"2. 特征比对数据表: {feature_stats_path}")
        print(f"3. 全量数据合并文件: {merged_data_path}")
        
        # 1. 写入分析记录文件
        write_analysis_record_csv(
            analysis_path, 
            original_headers, 
            original_rows, 
            results, 
            self.feature_start_column,
            has_time_now=(time_now_idx_api is not None)  # 传递是否有time_now字段的信息
        )
        print(f"✅ 分析报告文件写入完成")
        
        # 2. 写入特征比对数据表
        write_feature_stats_csv(
            feature_stats_path, 
            feature_stats,
            total_features=total_features,
            match_features=match_features,
            mismatch_features=mismatch_features,
            overall_match_ratio=overall_match_ratio,
            all_match_feature_count=all_match_feature_count,
            anomaly_feature_count=anomaly_feature_count
        )
        print(f"✅ 特征比对数据表写入完成")
        
        # 3. 写入全量数据合并文件（根据配置决定是否输出）
        if output_merged_data:
            write_merged_data_csv(
                merged_data_path,
                original_headers,
                original_rows,
                api_headers,
                api_rows,
                self.param1_column,  # cust_no列
                self.param1_column,  # api文件中的cust_no列
                suffix1="_原始",
                suffix2="_接口",
                key_column1_secondary=self.param2_column,  # use_create_time列
                key_column2_secondary=self.param2_column,  # api文件中的use_create_time列
                feature_start_column1=self.feature_start_column,
                feature_start_column2=self.feature_start_column,
            )
            print(f"✅ 全量数据合并文件写入完成")
        else:
            print(f"⏭️  全量数据合并文件已跳过（已禁用输出）")



    def compare_in_memory(self, original_csv_path: str, api_results: Dict, output_csv_path: str):
        """
        直接在内存中对比数据，不读取中间文件
        用于内存对比模式，只输出对比报告，不输出中间文件
        
        Args:
            original_csv_path: 原始CSV文件路径
            api_results: 接口返回的内存数据（来自fetch_api_data_in_memory）
            output_csv_path: 输出文件路径前缀
        """
        print(f"\n开始内存对比")
        print(f"原始文件: {original_csv_path}")
        
        # 从api_results中提取数据
        original_headers = api_results['headers']
        original_rows = api_results['rows']
        api_data_results = api_results['results']
        api_errors = api_results['errors']
        api_fields = api_results['api_fields']
        field_path_mapping = api_results['field_path_mapping']
        
        print(f"\n原始文件: {len(original_rows)} 行, {len(original_headers)} 列")
        print(f"接口数据: 成功 {len(api_data_results)} 条, 失败 {len(api_errors)} 条")
        
        # 打印列索引信息（用于调试）
        print(f"\n列索引配置:")
        print(f"  cust_no列={self.param1_column} ({original_headers[self.param1_column] if self.param1_column < len(original_headers) else 'N/A'})")
        print(f"  use_create_time列={self.param2_column} ({original_headers[self.param2_column] if self.param2_column < len(original_headers) else 'N/A'})")
        print(f"  特征开始列={self.feature_start_column}")
        
        # 构建接口数据索引（使用cust_no和use_create_time作为主键）
        api_data_index = {}
        for row_idx, result in api_data_results.items():
            if row_idx < len(original_rows):
                row = original_rows[row_idx]
                if self.param1_column < len(row) and self.param2_column < len(row):
                    cust_no = row[self.param1_column].strip() if row[self.param1_column] else ""
                    use_create_time = row[self.param2_column].strip() if row[self.param2_column] else ""
                    if cust_no and use_create_time:
                        key = (cust_no, use_create_time)
                        api_data_index[key] = result.get("api_data", {})
        
        print(f"接口数据索引构建完成，共 {len(api_data_index)} 条记录")
        
        # 获取原始文件的特征列
        original_feature_headers = original_headers[self.feature_start_column:] if len(original_headers) > self.feature_start_column else []
        original_feature_headers = [h for h in original_feature_headers if h.lower() not in ["pt", "time_now"]]
        
        # 对比数据
        results = {}
        errors = {}
        feature_stats = {}
        
        # 初始化特征统计
        for header in original_feature_headers:
            feature_stats[header] = {"total": 0, "match": 0, "mismatch": 0}
        
        print(f"\n开始对比数据...")
        for i, orig_row in enumerate(original_rows):
            if i % 1000 == 0:
                print(f"已处理: {i}/{len(original_rows)}")
            
            # 获取主键
            if self.param1_column >= len(orig_row) or self.param2_column >= len(orig_row):
                errors[i] = "主键列超出范围"
                continue
            
            cust_no = orig_row[self.param1_column].strip() if orig_row[self.param1_column] else ""
            use_create_time = orig_row[self.param2_column].strip() if orig_row[self.param2_column] else ""
            
            if not cust_no or not use_create_time:
                errors[i] = "主键值为空"
                continue
            
            # 计算请求接口时使用的时间（baseTime）
            request_time = self._calculate_request_time(use_create_time)
            
            # 查找apply_id相关字段
            apply_id_value = self._find_apply_id_field(original_headers, orig_row)
            
            key = (cust_no, use_create_time)
            
            # 在接口数据中查找匹配的记录
            if key not in api_data_index:
                errors[i] = f"在接口数据中未找到匹配记录: cust_no={cust_no}, use_create_time={use_create_time}"
                continue
            
            api_data = api_data_index[key]
            
            # 对比特征值
            comparison_results = {}
            
            for j, header in enumerate(original_feature_headers):
                orig_col_idx = self.feature_start_column + j
                if orig_col_idx >= len(orig_row):
                    continue
                
                csv_value = orig_row[orig_col_idx] if orig_col_idx < len(orig_row) else ""
                
                # 从接口数据中获取对应的字段值
                api_value = None
                if header in api_data:
                    api_value = api_data[header]
                elif header in field_path_mapping:
                    # 使用路径映射获取嵌套值
                    path = field_path_mapping[header]
                    api_value = self._get_nested_value_from_path(api_data, path)
                
                # 比较值
                is_match = compare_values(csv_value, api_value, header)
                
                # 保存比较结果
                comparison_results[header] = {
                    "csv_value": csv_value,
                    "api_value": api_value,
                    "is_match": is_match,
                }
                
                # 统计
                feature_stats[header]["total"] += 1
                if is_match:
                    feature_stats[header]["match"] += 1
                else:
                    feature_stats[header]["mismatch"] += 1
            
            results[i] = {
                "row_index": i,
                "cust_no": cust_no,
                "use_create_time": request_time,
                "use_credit_apply_id": apply_id_value,
                "time_now": "",  # 内存模式下没有time_now
                "comparison_results": comparison_results,
            }
        
        print(f"\n对比完成: 成功 {len(results)} 条, 失败 {len(errors)} 条")
        
        # 统计信息
        total_features = 0
        match_features = 0
        mismatch_features = 0
        
        for result in results.values():
            comparison_results = result.get("comparison_results", {})
            for feature_result in comparison_results.values():
                total_features += 1
                if feature_result.get("is_match", False):
                    match_features += 1
                else:
                    mismatch_features += 1
        
        # 统计无异常特征数量和有异常特征数量
        all_match_feature_count = 0
        anomaly_feature_count = 0
        anomaly_features_list = []
        
        for feature_name, stats in feature_stats.items():
            if stats["mismatch"] == 0:
                all_match_feature_count += 1
            else:
                anomaly_feature_count += 1
                match_ratio = stats["match"] / stats["total"] * 100 if stats["total"] > 0 else 0
                mismatch_ratio = stats["mismatch"] / stats["total"] * 100 if stats["total"] > 0 else 0
                anomaly_features_list.append({
                    "feature_name": feature_name,
                    "total": stats["total"],
                    "match": stats["match"],
                    "mismatch": stats["mismatch"],
                    "match_ratio": match_ratio,
                    "mismatch_ratio": mismatch_ratio,
                })
        
        # 按异常占比排序
        anomaly_features_list.sort(key=lambda x: x["mismatch_ratio"], reverse=True)
        
        # 计算总体匹配率
        overall_match_ratio = match_features / total_features * 100 if total_features > 0 else 0
        
        # ========== 显示特征值校验结果统计 ==========
        print(f"\n{'='*80}")
        print(f"特征值校验结果统计")
        print(f"\n总体统计:")
        print(f"  总特征值数量: {total_features}")
        print(f"  匹配数量: {match_features}")
        print(f"  不匹配数量: {mismatch_features}")
        
        print(f"\n特征统计:")
        print(f"  无异常特征数量: {all_match_feature_count}")
        print(f"  有异常特征数量: {anomaly_feature_count}")
        
        if anomaly_feature_count > 0:
            print(f"\n有异常特征详情（按异常占比降序）:")
            print(f"  {'特征名':<90} {'总数量':<10} {'异常数量':<10} {'异常占比':<10}")
            print(f"  {'-'*90} {'-'*10} {'-'*10} {'-'*10}")
            for feature in anomaly_features_list[:10]:  # 只显示前10个
                print(f"  {feature['feature_name']:<90} {feature['total']:<10} {feature['mismatch']:<10} {feature['mismatch_ratio']:.2f}%")
        
        print(f"\n{'='*80}\n")
        
        # 写入结果文件（仅报告，不写入中间文件）
        base_path = output_csv_path.replace(".csv", "")
        
        analysis_path = f"{base_path}_analysis_report.csv"
        feature_stats_path = f"{base_path}_feature_stats.csv"
        
        print(f"开始写入结果文件...")
        print(f"1. 分析报告文件: {analysis_path}")
        print(f"2. 特征比对数据表: {feature_stats_path}")
        
        # 1. 写入分析记录文件
        write_analysis_record_csv(
            analysis_path,
            original_headers,
            original_rows,
            results,
            self.feature_start_column,
            has_time_now=False  # 内存模式下没有time_now
        )
        print(f"✅ 分析报告文件写入完成")
        
        # 2. 写入特征比对数据表
        write_feature_stats_csv(
            feature_stats_path,
            feature_stats,
            total_features=total_features,
            match_features=match_features,
            mismatch_features=mismatch_features,
            overall_match_ratio=overall_match_ratio,
            all_match_feature_count=all_match_feature_count,
            anomaly_feature_count=anomaly_feature_count
        )
        print(f"✅ 特征比对数据表写入完成")
        
        print(f"\n⏭️  中间文件已跳过（内存对比模式）")
    
    def _get_nested_value_from_path(self, data: dict, path: str):
        """从路径获取嵌套值"""
        if not path or not data:
            return None
        
        parts = path.split('.')
        current = data
        
        for part in parts:
            if isinstance(current, dict) and part in current:
                current = current[part]
            else:
                return None
        
        return current
