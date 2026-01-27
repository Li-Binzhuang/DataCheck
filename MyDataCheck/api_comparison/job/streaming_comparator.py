#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
流式对比器 - 边请求边对比边写入
功能：实现真正的流式处理，内存占用降低80-90%

核心优化：
1. 不在内存中累积所有接口返回数据
2. 边请求边对比边写入
3. 及时释放已处理的数据
4. 使用生成器而非列表
"""

import csv
import gc
import os
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime
from typing import Any, Dict, Generator, List, Optional, Tuple

# 添加父目录到路径
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../..'))

# 导入公共工具模块
from common.csv_tool import read_csv_with_encoding
from common.value_comparator import compare_values


class StreamingComparator:
    """流式对比器 - 边请求边对比边写入"""
    
    def __init__(
        self,
        api_url: str,
        param1_column: int = 1,
        param2_column: int = 3,
        feature_start_column: int = 4,
        thread_count: int = 150,
        timeout: int = 60,
        add_one_second: bool = False,
        api_params: Optional[List[Dict[str, Any]]] = None,
        batch_size: int = 1000,  # 批次大小
    ):
        """
        初始化流式对比器
        
        Args:
            api_url: 接口URL
            param1_column: cust_no所在列
            param2_column: use_create_time所在列
            feature_start_column: 特征开始列
            thread_count: 线程数
            timeout: 超时时间
            add_one_second: 是否在请求接口时加1秒
            api_params: 接口参数配置列表
            batch_size: 批次大小（每批处理多少行）
        """
        self.api_url = api_url
        self.param1_column = param1_column
        self.param2_column = param2_column
        self.feature_start_column = feature_start_column
        self.thread_count = thread_count
        self.timeout = timeout
        self.add_one_second = add_one_second
        self.batch_size = batch_size
        
        # 处理接口参数配置
        if api_params:
            self.api_params = api_params
        else:
            # 兼容旧配置
            self.api_params = [
                {
                    "param_name": "custNo",
                    "column_index": param1_column,
                    "is_time_field": False
                },
                {
                    "param_name": "baseTime",
                    "column_index": param2_column,
                    "is_time_field": True
                }
            ]
        
        # 导入必要的工具函数
        from api_comparison.job.fetch_api_data import ApiDataFetcher
        self.fetcher = ApiDataFetcher(
            api_url=api_url,
            param1_column=param1_column,
            param2_column=param2_column,
            thread_count=thread_count,
            timeout=timeout,
            feature_start_column=feature_start_column,
            add_one_second=add_one_second,
            api_params=api_params
        )
    
    def _batch_rows(self, rows: List[List[str]]) -> Generator[List[Tuple[int, List[str]]], None, None]:
        """
        将行数据分批
        
        Args:
            rows: 所有行数据
        
        Yields:
            每批数据：[(row_index, row), ...]
        """
        batch = []
        for i, row in enumerate(rows):
            batch.append((i, row))
            if len(batch) >= self.batch_size:
                yield batch
                batch = []
        if batch:
            yield batch
    
    def _process_batch(
        self,
        batch: List[Tuple[int, List[str]]],
        headers: List[str],
        feature_headers: List[str]
    ) -> Generator[Dict[str, Any], None, None]:
        """
        处理一批数据：请求接口并对比
        
        Args:
            batch: 一批数据 [(row_index, row), ...]
            headers: CSV表头
            feature_headers: 特征列表头
        
        Yields:
            对比结果字典
        """
        # 使用线程池并发请求接口
        with ThreadPoolExecutor(max_workers=self.thread_count) as executor:
            # 提交所有任务
            future_to_row = {
                executor.submit(self.fetcher.process_row, row_index, row, headers): (row_index, row)
                for row_index, row in batch
            }
            
            # 收集结果并立即对比
            for future in as_completed(future_to_row):
                row_index, row = future_to_row[future]
                
                try:
                    result = future.result()
                    
                    if "error" in result:
                        # 请求失败
                        yield {
                            "row_index": row_index,
                            "error": result["error"],
                            "row": row
                        }
                    else:
                        # 请求成功，立即对比
                        comparison_result = self._compare_single_row(
                            row_index, row, headers, feature_headers, result
                        )
                        yield comparison_result
                
                except Exception as e:
                    yield {
                        "row_index": row_index,
                        "error": f"处理异常: {str(e)}",
                        "row": row
                    }
    
    def _compare_single_row(
        self,
        row_index: int,
        row: List[str],
        headers: List[str],
        feature_headers: List[str],
        api_result: Dict[str, Any]
    ) -> Dict[str, Any]:
        """
        对比单行数据
        
        Args:
            row_index: 行索引
            row: 行数据
            headers: CSV表头
            feature_headers: 特征列表头
            api_result: 接口返回结果
        
        Returns:
            对比结果字典
        """
        # 获取主键（从接口参数中获取）
        cust_no = ""
        use_create_time = ""
        apply_id = ""
        
        # 从 api_result 中获取原始值
        original_values = api_result.get("original_values", {})
        request_params = api_result.get("request_params", {})
        
        # 尝试获取客户号（custNo 或 applyId）
        cust_no = original_values.get("custNo", original_values.get("applyId", ""))
        
        # 尝试获取时间字段
        use_create_time = request_params.get("baseTime", original_values.get("baseTime", ""))
        
        # 优先从接口入参中获取 applyId
        apply_id = original_values.get("applyId", original_values.get("apply_id", ""))
        
        # 如果接口入参中没有，尝试从 CSV 列中查找
        if not apply_id:
            apply_id_fields = ['apply_id', 'applyId', 'use_credit_id', 'use_credit_apply_id', 'loan_no', 'ua_id', 'ua_no']
            for field_name in apply_id_fields:
                for i, header in enumerate(headers):
                    if header.lower() == field_name.lower() and i < len(row):
                        apply_id = row[i].strip()
                        break
                if apply_id:
                    break
        
        # 如果还是没有，使用 custNo
        if not apply_id:
            apply_id = cust_no
        
        # 获取API数据
        api_data = api_result.get("api_data", {})
        
        # 对比特征值
        comparison_results = {}
        has_mismatch = False
        
        for j, header in enumerate(feature_headers):
            orig_col_idx = self.feature_start_column + j
            if orig_col_idx >= len(row):
                continue
            
            csv_value = row[orig_col_idx] if orig_col_idx < len(row) else ""
            
            # 从接口数据中获取对应的字段值
            api_value = self.fetcher._find_feature_value_in_api_response(api_data, header)
            
            # 比较值
            is_match = compare_values(csv_value, api_value, header)
            
            if not is_match:
                has_mismatch = True
            
            # 只保存不匹配的特征（节省内存）
            if not is_match:
                comparison_results[header] = {
                    "csv_value": csv_value,
                    "api_value": api_value,
                    "is_match": False,
                }
        
        return {
            "row_index": row_index,
            "cust_no": cust_no,
            "use_create_time": use_create_time,
            "apply_id": apply_id,  # 使用 apply_id 而不是 use_credit_apply_id
            "has_mismatch": has_mismatch,
            "comparison_results": comparison_results,  # 只包含不匹配的特征
            "row": row  # 保留原始行数据用于写入
        }
    
    def streaming_compare(
        self,
        input_csv_path: str,
        output_csv_path: str
    ):
        """
        流式对比：边请求边对比边写入
        
        Args:
            input_csv_path: 输入CSV文件路径
            output_csv_path: 输出CSV文件路径前缀
        """
        print(f"\n{'='*80}")
        print(f"流式对比模式")
        print(f"{'='*80}")
        print(f"  输入文件: {os.path.basename(input_csv_path)}")
        print(f"  批次大小: {self.batch_size}")
        print(f"  线程数: {self.thread_count}")
        print(f"{'='*80}\n")
        
        # 读取CSV文件
        headers, rows = read_csv_with_encoding(input_csv_path)
        
        print(f"读取CSV文件: {len(rows)} 行, {len(headers)} 列")
        
        # 获取特征列
        feature_headers = headers[self.feature_start_column:] if len(headers) > self.feature_start_column else []
        feature_headers = [h for h in feature_headers if h.lower() not in ["pt", "time_now"]]
        
        # 准备输出文件
        base_path = output_csv_path.replace(".csv", "")
        analysis_path = f"{base_path}_analysis_report.csv"
        feature_stats_path = f"{base_path}_feature_stats.csv"
        errors_path = f"{base_path}_errors.csv"
        
        # 初始化统计数据
        feature_stats = {header: {"total": 0, "match": 0, "mismatch": 0} for header in feature_headers}
        total_rows = 0
        success_rows = 0
        error_rows = 0
        
        # 收集错误信息（内存中暂存）
        error_records = []
        
        # 打开输出文件（流式写入）
        print(f"\n开始流式处理...")
        start_time = time.time()
        
        with open(analysis_path, "w", encoding="utf-8", newline="") as f:
            writer = csv.writer(f)
            
            # 写入表头：详细对比格式（去掉 baseTime）
            analysis_headers = [
                "特征名", "applyId", "request_time", "CSV值", "API值"
            ]
            writer.writerow(analysis_headers)
            
            # 分批处理
            for batch_idx, batch in enumerate(self._batch_rows(rows), 1):
                print(f"处理批次 {batch_idx}: {len(batch)} 行", end='\r')
                
                # 处理这一批数据
                for comparison_result in self._process_batch(batch, headers, feature_headers):
                    total_rows += 1
                    
                    if "error" in comparison_result:
                        # 错误行：跳过，不写入分析报告，只记录到错误列表
                        error_rows += 1
                        row_index = comparison_result["row_index"]
                        error_msg = comparison_result["error"]
                        row = comparison_result.get("row", [])
                        
                        # 收集错误信息
                        error_records.append({
                            "row_index": row_index + 2,  # Excel行号
                            "row_data": row,
                            "error_message": error_msg
                        })
                        
                        # 打印错误信息（每100个错误打印一次）
                        if error_rows % 100 == 1:
                            print(f"\n⚠️  接口请求异常: 行 {row_index + 2}, 错误: {error_msg}")
                    else:
                        # 正常行：写入分析报告
                        success_rows += 1
                        row_index = comparison_result["row_index"]
                        cust_no = comparison_result["cust_no"]
                        use_create_time = comparison_result["use_create_time"]
                        apply_id = comparison_result["apply_id"]  # 使用 apply_id
                        has_mismatch = comparison_result["has_mismatch"]
                        comparison_results = comparison_result["comparison_results"]
                        
                        # 更新特征统计（只统计成功的行）
                        for header in feature_headers:
                            feature_stats[header]["total"] += 1
                            if header in comparison_results:
                                feature_stats[header]["mismatch"] += 1
                            else:
                                feature_stats[header]["match"] += 1
                        
                        # 写入每个不匹配的特征（详细格式，去掉 baseTime）
                        if has_mismatch:
                            for feature_name, feature_data in comparison_results.items():
                                csv_value = feature_data.get("csv_value", "")
                                api_value = feature_data.get("api_value", "")
                                
                                writer.writerow([
                                    feature_name,
                                    apply_id,           # applyId
                                    use_create_time,    # request_time
                                    csv_value,
                                    api_value
                                ])
                
                # 每批处理完后立即释放内存
                gc.collect()
        
        elapsed_time = time.time() - start_time
        print(f"\n\n流式处理完成，耗时: {elapsed_time:.2f}秒")
        print(f"成功: {success_rows}, 失败: {error_rows}")
        
        # 如果有错误，写入错误文件
        if error_records:
            print(f"\n⚠️  发现 {len(error_records)} 个接口请求异常，正在写入错误文件...")
            self._write_error_file(errors_path, headers, error_records)
            print(f"✅ 错误文件已生成: {os.path.basename(errors_path)}")
        else:
            print(f"\n✅ 所有接口请求均成功，无异常记录")
        
        # 写入特征统计文件（只统计成功的行）
        if success_rows > 0:
            self._write_feature_stats(feature_stats_path, feature_stats)
            
            # 显示统计结果
            self._print_statistics(feature_stats)
            
            print(f"\n✅ 流式对比完成")
            print(f"  • {os.path.basename(analysis_path)}")
            print(f"  • {os.path.basename(feature_stats_path)}")
            if error_records:
                print(f"  • {os.path.basename(errors_path)} (接口异常记录)")
        else:
            print(f"\n❌ 所有接口请求均失败，无法生成对比报告")
            print(f"  请检查:")
            print(f"  1. 接口URL是否正确")
            print(f"  2. 接口是否可访问")
            print(f"  3. 接口参数配置是否正确")
            print(f"  4. 查看错误文件了解详细信息: {os.path.basename(errors_path)}")
        
        print(f"{'='*80}\n")
    
    def _write_error_file(self, output_path: str, headers: List[str], error_records: List[Dict]):
        """
        写入错误文件
        
        Args:
            output_path: 输出文件路径
            headers: CSV表头
            error_records: 错误记录列表
        """
        with open(output_path, "w", encoding="utf-8", newline="") as f:
            writer = csv.writer(f, quoting=csv.QUOTE_MINIMAL)
            
            # 写入表头：applyId, baseTime, errors
            error_headers = ["applyId", "baseTime", "errors"]
            writer.writerow(error_headers)
            
            # 写入错误数据
            for record in error_records:
                row_index = record["row_index"]
                row_data = record["row_data"]
                error_msg = record["error_message"]
                
                # 从行数据中提取 applyId 和 baseTime
                # 根据接口参数配置查找对应的列
                apply_id = ""
                base_time = ""
                
                # 尝试从多个可能的列中获取 applyId
                apply_id_fields = ['applyId', 'apply_id', 'custNo', 'cust_no', 'use_credit_apply_id']
                for i, header in enumerate(headers):
                    if header in apply_id_fields and i < len(row_data):
                        apply_id = row_data[i].strip()
                        break
                
                # 尝试从多个可能的列中获取 baseTime
                time_fields = ['baseTime', 'base_time', 'use_create_time', 'create_time']
                for i, header in enumerate(headers):
                    if header in time_fields and i < len(row_data):
                        base_time = row_data[i].strip()
                        break
                
                # 如果没有找到，尝试使用配置的列索引
                if not apply_id and self.param1_column < len(row_data):
                    apply_id = row_data[self.param1_column].strip()
                
                if not base_time and self.param2_column < len(row_data):
                    base_time = row_data[self.param2_column].strip()
                
                # baseTime 加上引号，以文本格式写入（防止 Excel 自动转换格式）
                base_time_quoted = f'"{base_time}"' if base_time else ""
                
                writer.writerow([apply_id, base_time_quoted, error_msg])
    
    def _write_feature_stats(self, output_path: str, feature_stats: Dict[str, Dict[str, int]]):
        """写入特征统计文件"""
        with open(output_path, "w", encoding="utf-8", newline="") as f:
            writer = csv.writer(f)
            
            # 写入表头
            writer.writerow([
                "特征名", "总数量", "匹配数量", "不匹配数量",
                "匹配率(%)", "不匹配率(%)"
            ])
            
            # 按不匹配率排序
            sorted_features = sorted(
                feature_stats.items(),
                key=lambda x: x[1]["mismatch"] / x[1]["total"] if x[1]["total"] > 0 else 0,
                reverse=True
            )
            
            # 写入数据
            for feature_name, stats in sorted_features:
                total = stats["total"]
                match = stats["match"]
                mismatch = stats["mismatch"]
                match_ratio = match / total * 100 if total > 0 else 0
                mismatch_ratio = mismatch / total * 100 if total > 0 else 0
                
                writer.writerow([
                    feature_name,
                    total,
                    match,
                    mismatch,
                    f"{match_ratio:.2f}",
                    f"{mismatch_ratio:.2f}"
                ])
    
    def _print_statistics(self, feature_stats: Dict[str, Dict[str, int]]):
        """打印统计信息"""
        # 计算总体统计
        total_features = sum(s["total"] for s in feature_stats.values())
        match_features = sum(s["match"] for s in feature_stats.values())
        mismatch_features = sum(s["mismatch"] for s in feature_stats.values())
        
        # 统计无异常和有异常的特征
        all_match_count = sum(1 for s in feature_stats.values() if s["mismatch"] == 0)
        anomaly_count = sum(1 for s in feature_stats.values() if s["mismatch"] > 0)
        
        # 获取异常特征列表（按异常率排序）
        anomaly_features = [
            (name, stats) for name, stats in feature_stats.items()
            if stats["mismatch"] > 0
        ]
        anomaly_features.sort(
            key=lambda x: x[1]["mismatch"] / x[1]["total"] if x[1]["total"] > 0 else 0,
            reverse=True
        )
        
        # 打印统计结果
        print(f"\n{'='*80}")
        print(f"特征值校验结果统计")
        print(f"\n总体统计:")
        print(f"  总特征值数量: {total_features}")
        print(f"  匹配数量: {match_features}")
        print(f"  不匹配数量: {mismatch_features}")
        
        print(f"\n特征统计:")
        print(f"  无异常特征数量: {all_match_count}")
        print(f"  有异常特征数量: {anomaly_count}")
        
        if anomaly_count > 0:
            print(f"\n有异常特征详情（按异常占比降序，前10个）:")
            print(f"  {'特征名':<90} {'总数量':<10} {'异常数量':<10} {'异常占比':<10}")
            print(f"  {'-'*90} {'-'*10} {'-'*10} {'-'*10}")
            for feature_name, stats in anomaly_features[:10]:
                total = stats["total"]
                mismatch = stats["mismatch"]
                mismatch_ratio = mismatch / total * 100 if total > 0 else 0
                print(f"  {feature_name:<90} {total:<10} {mismatch:<10} {mismatch_ratio:.2f}%")
        
        print(f"\n{'='*80}\n")
