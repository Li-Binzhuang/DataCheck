#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
跑数核心模块

功能：读取CSV表格，逐行调用接口，将原始数据和接口返回的特征值合并输出
"""

import csv
import json
import os
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional
import requests

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../..'))
from common.csv_tool import read_csv_with_encoding


class BatchRunner:
    """批量跑数处理器"""

    def __init__(
        self,
        api_url: str,
        thread_count: int = 50,
        timeout: int = 30,
        api_params: Optional[List[Dict[str, Any]]] = None,
        keep_columns: Optional[List[int]] = None,
    ):
        """
        初始化跑数处理器
        
        Args:
            api_url: 接口URL
            thread_count: 并发线程数
            timeout: 请求超时时间(秒)
            api_params: 接口参数配置列表，如 [{"param_name": "custNo", "column_index": 1, "is_time_field": False}]
            keep_columns: 要保留的原始列索引列表，如 [0, 1, 2] 表示保留前3列。None表示保留所有列
        """
        self.api_url = api_url
        self.thread_count = thread_count
        self.timeout = timeout
        self.api_params = api_params or []
        self.keep_columns = keep_columns

    def normalize_timestamp(self, time_str: str, use_t_separator: bool = False) -> str:
        """标准化时间戳格式
        
        Args:
            time_str: 原始时间字符串
            use_t_separator: 是否使用T分隔符，默认False使用空格
        """
        if not time_str or not time_str.strip():
            return time_str
        time_str = time_str.strip()
        
        separator = 'T' if use_t_separator else ' '
        
        # 统一处理，先提取日期和时间部分
        date_part = None
        time_part = None
        
        if 'T' in time_str:
            parts = time_str.split('T')
            date_part = parts[0]
            time_part = parts[1] if len(parts) > 1 else None
        elif ' ' in time_str:
            parts = time_str.split(' ')
            date_part = parts[0]
            time_part = parts[1] if len(parts) > 1 else None
        else:
            return time_str
        
        if not time_part:
            return time_str
        
        # 处理毫秒
        if '.' in time_part:
            time_parts = time_part.split('.')
            ms = time_parts[1][:3].ljust(3, '0') if len(time_parts) > 1 else '000'
            return f"{date_part}{separator}{time_parts[0]}.{ms}"
        else:
            return f"{date_part}{separator}{time_part}.000"

    def send_request(self, params: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """发送接口请求"""
        try:
            response = requests.post(
                self.api_url,
                json=params,
                headers={"Content-Type": "application/json"},
                timeout=self.timeout,
            )
            response.raise_for_status()
            return response.json()
        except Exception as e:
            return {"_error": str(e)}

    def extract_features(self, api_response: Dict[str, Any]) -> Dict[str, Any]:
        """从接口响应中提取特征值（data字段中的所有字段）"""
        if not api_response or "_error" in api_response:
            return {}
        
        data = api_response.get("data", {})
        if isinstance(data, dict):
            return data
        return {}

    def process_row(self, row_index: int, row: List[str], headers: List[str]) -> Dict[str, Any]:
        """处理单行数据"""
        # 构建请求参数
        request_params = {}
        for param_config in self.api_params:
            param_name = param_config.get("param_name")
            column_index = param_config.get("column_index")
            is_time_field = param_config.get("is_time_field", False)
            use_t_separator = param_config.get("use_t_separator", False)
            
            if column_index is None or column_index < 0 or column_index >= len(row):
                continue
            
            param_value = row[column_index].strip() if row[column_index] else ""
            if not param_value:
                continue
            
            # 时间字段处理
            if is_time_field:
                param_value = self.normalize_timestamp(param_value, use_t_separator)
            
            request_params[param_name] = param_value
        
        if not request_params:
            return {"row_index": row_index, "error": "无有效参数", "features": {}}
        
        # 发送请求
        api_response = self.send_request(request_params)
        features = self.extract_features(api_response)
        
        # 检查是否有错误 - 只有请求异常才算失败
        error = None
        if api_response and "_error" in api_response:
            error = api_response["_error"]
        
        return {
            "row_index": row_index,
            "error": error,
            "features": features,
            "request_params": request_params,
            "response": api_response  # 保留原始响应用于调试
        }

    def run(self, input_csv_path: str, output_csv_path: str) -> Dict[str, Any]:
        """
        执行跑数任务
        
        Args:
            input_csv_path: 输入CSV文件路径
            output_csv_path: 输出CSV文件路径
            
        Returns:
            执行结果统计
        """
        if not os.path.exists(input_csv_path):
            raise FileNotFoundError(f"输入文件不存在: {input_csv_path}")
        
        # 读取CSV
        headers, rows = read_csv_with_encoding(input_csv_path)
        total_rows = len(rows)
        
        print(f"读取到 {total_rows} 行数据")
        print(f"表头: {headers}")
        print(f"接口地址: {self.api_url}")
        print(f"并发线程: {self.thread_count}")
        print(f"入参配置: {json.dumps(self.api_params, ensure_ascii=False)}")
        print()
        
        # 打印第一行数据用于调试
        if rows:
            print(f"第一行数据: {rows[0]}")
            # 测试第一条请求
            print("\n" + "=" * 60)
            print("📋 测试第一条请求")
            print("=" * 60)
            test_params = {}
            for param_config in self.api_params:
                param_name = param_config.get("param_name")
                column_index = param_config.get("column_index")
                is_time_field = param_config.get("is_time_field", False)
                use_t_separator = param_config.get("use_t_separator", False)
                if column_index is not None and 0 <= column_index < len(rows[0]):
                    val = rows[0][column_index].strip() if rows[0][column_index] else ""
                    original_val = val
                    if is_time_field:
                        val = self.normalize_timestamp(val, use_t_separator)
                    test_params[param_name] = val
                    time_info = f" (时间字段, T分隔={use_t_separator})" if is_time_field else ""
                    print(f"  {param_name}: 列{column_index}{time_info} = '{original_val}' -> '{val}'")
            
            print(f"\n📤 请求入参:")
            print(json.dumps(test_params, ensure_ascii=False, indent=2))
            
            test_response = self.send_request(test_params)
            
            print(f"\n📥 响应出参:")
            if test_response:
                print(f"  retCode: {test_response.get('retCode')}")
                print(f"  retMsg: {test_response.get('retMsg')}")
                data = test_response.get('data', {})
                if isinstance(data, dict):
                    print(f"  data字段数: {len(data)}")
                    # 显示前5个特征
                    feature_items = list(data.items())[:5]
                    for k, v in feature_items:
                        print(f"    {k}: {v}")
                    if len(data) > 5:
                        print(f"    ... 还有 {len(data) - 5} 个特征")
                else:
                    print(f"  data: {data}")
            else:
                print("  响应为空")
            print("=" * 60 + "\n")
        
        # 确定要保留的原始列
        if self.keep_columns is not None:
            keep_cols = [i for i in self.keep_columns if 0 <= i < len(headers)]
        else:
            keep_cols = list(range(len(headers)))
        
        kept_headers = [headers[i] for i in keep_cols]
        print(f"保留原始列: {kept_headers}")
        
        # 并发处理
        results = {}
        errors_count = 0
        all_feature_names = set()
        
        print(f"\n开始并发请求，线程数: {self.thread_count}")
        start_time = time.time()
        
        with ThreadPoolExecutor(max_workers=self.thread_count) as executor:
            futures = {
                executor.submit(self.process_row, i, row, headers): i
                for i, row in enumerate(rows)
            }
            
            completed = 0
            for future in as_completed(futures):
                completed += 1
                if completed % 100 == 0 or completed == total_rows:
                    print(f"进度: {completed}/{total_rows}")
                
                try:
                    result = future.result()
                    row_index = result["row_index"]
                    results[row_index] = result
                    
                    if result.get("error"):
                        errors_count += 1
                    
                    # 收集所有特征名
                    all_feature_names.update(result.get("features", {}).keys())
                except Exception as e:
                    row_index = futures[future]
                    results[row_index] = {"row_index": row_index, "error": str(e), "features": {}}
                    errors_count += 1
        
        elapsed = time.time() - start_time
        print(f"\n请求完成，耗时: {elapsed:.2f}秒")
        print(f"成功: {total_rows - errors_count}, 失败: {errors_count}")
        print(f"特征数量: {len(all_feature_names)}")
        
        # 排序特征名
        sorted_features = sorted(all_feature_names)
        
        # 写入输出CSV
        print(f"\n写入输出文件: {output_csv_path}")
        output_headers = kept_headers + sorted_features
        
        with open(output_csv_path, 'w', newline='', encoding='utf-8-sig') as f:
            writer = csv.writer(f)
            writer.writerow(output_headers)
            
            for i in range(total_rows):
                row = rows[i]
                result = results.get(i, {"features": {}})
                features = result.get("features", {})
                
                # 原始列数据
                output_row = [row[j] if j < len(row) else "" for j in keep_cols]
                
                # 特征值数据
                for feat_name in sorted_features:
                    val = features.get(feat_name, "")
                    if val is None:
                        val = ""
                    output_row.append(val)
                
                writer.writerow(output_row)
        
        print(f"✅ 输出完成，共 {total_rows} 行，{len(output_headers)} 列")
        
        return {
            "total": total_rows,
            "success": total_rows - errors_count,
            "errors": errors_count,
            "features_count": len(sorted_features),
            "output_file": output_csv_path
        }
