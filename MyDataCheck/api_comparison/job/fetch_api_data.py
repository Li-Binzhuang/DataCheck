#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
根据文件请求接口，输出接口全部数据文档
功能：读取CSV文件，对每一行发送接口请求，将接口返回的所有数据写入CSV文件
"""

import csv
import json
import os
import re
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional

import requests

# 添加父目录到路径，以便导入公共工具模块
# job文件夹在场景1_接口数据对比下，公共工具在上一级目录
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../..'))

# 导入公共工具模块
from common.csv_tool import read_csv_with_encoding as read_csv_with_encoding_tool


class ApiDataFetcher:
    """接口数据获取器"""

    def __init__(
        self,
        api_url: str,
        param1_column: int = 1,  # cust_no所在列（兼容旧配置）
        param2_column: int = 3,  # use_create_time所在列（兼容旧配置）
        thread_count: int = 150,  # 线程数
        timeout: int = 60,
        convert_feature_to_number: bool = True,  # 是否将特征值转换为数值类型
        feature_start_column: int = 3,  # 特征开始列
        add_one_second: bool = False,  # 是否在请求接口时加1秒
        api_params: Optional[List[Dict[str, Any]]] = None,  # 新增：接口参数配置列表
    ):
        self.api_url = api_url
        self.thread_count = thread_count
        self.timeout = timeout
        self.convert_feature_to_number = convert_feature_to_number
        self.feature_start_column = feature_start_column
        self.add_one_second = add_one_second
        self.field_path_mapping = {}  # 字段路径映射，用于访问嵌套数据
        
        # 处理接口参数配置（新逻辑）
        if api_params:
            # 使用新的参数配置
            self.api_params = api_params
        else:
            # 兼容旧配置：使用默认的 custNo 和 baseTime
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
        
        # 为了兼容性，保留旧的属性
        self.param1_column = param1_column
        self.param2_column = param2_column

    def _convert_string_to_number(self, value: Any) -> Any:
        """
        将字符串值转换为数值类型（保留小数）
        
        Args:
            value: 要转换的值（可能是字符串、数字或其他类型）
        
        Returns:
            如果可以转换为数字，返回数字（float），否则返回原始值
        """
        if value is None:
            return None
        
        # 如果已经是数字类型，直接返回
        if isinstance(value, (int, float)):
            return float(value)
        
        # 如果是字符串，尝试转换为数字
        if isinstance(value, str):
            value_str = value.strip()
            
            # 处理空值和null字符串
            if not value_str or value_str.lower() in ["null", "none", "nan", "undefined", ""]:
                return None
            
            # 移除千位分隔符（逗号）
            value_str = value_str.replace(",", "")
            
            # 移除所有空白字符（包括换行符、制表符等）
            value_str = "".join(value_str.split())
            
            # 尝试转换为浮点数（支持科学计数法，保留小数）
            try:
                num_value = float(value_str)
                # 检查是否是有效的数字（不是 inf 或 nan）
                if isinstance(num_value, float) and not (num_value != num_value or num_value == float('inf') or num_value == float('-inf')):
                    return num_value
            except (ValueError, TypeError, OverflowError):
                pass
        
        # 无法转换为数字，返回原始值
        return value

    def _find_feature_value_in_api_response(self, api_data: Dict[str, Any], csv_header: str) -> Any:
        """
        在API响应中查找特征值（支持多种查找策略，兼容不同的data结构）
        
        支持的接口返回结构：
        1. 特征字段在顶层: {"field": "value", ...}
        2. 特征字段在data中: {"data": {"field": "value"}, ...}
        3. 特征字段在data的嵌套结构中: {"data": {"result": {"field": "value"}}, ...}
        4. data字段为空: {"data": {}, ...} - 会在顶层查找
        
        Args:
            api_data: API响应数据
            csv_header: CSV表头（特征名）
            
        Returns:
            特征值，如果未找到返回None
        """
        api_value_raw = None
        
        # 辅助函数：递归搜索字典中的字段
        def _recursive_search(data: Any, target_key: str, case_sensitive: bool = True) -> Any:
            """递归搜索字典中的字段"""
            if not isinstance(data, dict):
                return None
            
            target_key_lower = target_key.lower() if not case_sensitive else None
            
            for key, value in data.items():
                # 精确匹配
                if case_sensitive and key == target_key:
                    # 如果值是叶子节点（非字典或空字典），直接返回
                    if not isinstance(value, dict) or not value:
                        return value
                    # 如果值是字典，继续递归搜索（兼容嵌套结构）
                    nested_result = _recursive_search(value, target_key, case_sensitive)
                    if nested_result is not None:
                        return nested_result
                # 大小写不敏感匹配
                elif not case_sensitive and key.lower() == target_key_lower:
                    if not isinstance(value, dict) or not value:
                        return value
                    nested_result = _recursive_search(value, target_key, case_sensitive)
                    if nested_result is not None:
                        return nested_result
                
                # 递归搜索嵌套字典
                if isinstance(value, dict) and value:
                    nested_result = _recursive_search(value, target_key, case_sensitive)
                    if nested_result is not None:
                        return nested_result
            
            return None
        
        # 策略1: 优先在data字段中查找（如果data字段存在且非空）
        if "data" in api_data and isinstance(api_data["data"], dict):
            data_field = api_data["data"]
            # 如果data字段非空，优先在data中查找
            if data_field:
                # 优先在 data.features 中查找（新结构：data.features 包含特征字段）
                if "features" in data_field and isinstance(data_field["features"], dict):
                    features_field = data_field["features"]
                    # 精确匹配
                    if csv_header in features_field:
                        api_value_raw = features_field[csv_header]
                    # 大小写不敏感匹配
                    if api_value_raw is None:
                        csv_header_lower = csv_header.lower()
                        for key, value in features_field.items():
                            if key.lower() == csv_header_lower:
                                api_value_raw = value
                                break
                
                # 如果 features 中未找到，在 data 中递归查找（兼容旧结构和嵌套结构）
                if api_value_raw is None:
                    # 精确匹配
                    api_value_raw = _recursive_search(data_field, csv_header, case_sensitive=True)
                    # 大小写不敏感匹配
                    if api_value_raw is None:
                        api_value_raw = _recursive_search(data_field, csv_header, case_sensitive=False)
        
        # 策略2: 如果data字段为空或未找到，在顶层查找
        if api_value_raw is None:
            # 精确匹配
            if csv_header in api_data:
                value = api_data[csv_header]
                # 跳过系统字段（retCode, retMsg, success, timestamp等）
                if csv_header not in ["retCode", "retMsg", "success", "timestamp", "data"]:
                    if not isinstance(value, dict) or not value:
                        api_value_raw = value
            
            # 大小写不敏感匹配
            if api_value_raw is None:
                csv_header_lower = csv_header.lower()
                for key, value in api_data.items():
                    # 跳过系统字段
                    if key.lower() in ["retcode", "retmsg", "success", "timestamp", "data"]:
                        continue
                    if key.lower() == csv_header_lower:
                        if not isinstance(value, dict) or not value:
                            api_value_raw = value
                            break
        
        # 策略3: 递归搜索整个响应（包括顶层和data字段）
        if api_value_raw is None:
            api_value_raw = _recursive_search(api_data, csv_header, case_sensitive=True)
            if api_value_raw is None:
                api_value_raw = _recursive_search(api_data, csv_header, case_sensitive=False)
        
        # 策略4: 尝试使用点号分隔的嵌套路径
        if api_value_raw is None:
            api_value_raw = self._get_nested_value(api_data, csv_header)
        
        return api_value_raw

    def _get_nested_value(self, data: Dict[str, Any], path: str) -> Any:
        """
        根据路径获取嵌套字典中的值
        
        Args:
            data: 嵌套字典
            path: 字段路径，支持点号分隔（如 "data.stat90D.calcCreditGapMean"）
        
        Returns:
            找到的值，如果不存在返回None
        """
        if not path:
            return None
        
        keys = path.split('.')
        current = data
        
        for key in keys:
            if isinstance(current, dict) and key in current:
                current = current[key]
            else:
                return None
        
        return current

    def normalize_timestamp(self, time_str: str, add_t_separator: bool = True, convert_date_to_time: bool = True) -> str:
        """
        标准化时间戳格式，确保毫秒精度一致
        
        如果输入是日期格式（只有日期，没有时间部分），且 convert_date_to_time=True，则自动添加 00:00:00.000
        
        Args:
            time_str: 原始时间字符串
            add_t_separator: 是否在日期和时间之间加 T 分隔符（默认True）
            convert_date_to_time: 是否将日期格式转换为时间格式（默认True）
            
        Returns:
            标准化后的时间字符串 
            - 如果 add_t_separator=True: YYYY-MM-DDTHH:MM:SS.SSS
            - 如果 add_t_separator=False: YYYY-MM-DD HH:MM:SS.SSS
        """
        if not time_str or not time_str.strip():
            return time_str
            
        time_str = time_str.strip()
        
        # 确定分隔符
        separator = "T" if add_t_separator else " "
        
        # 检测是否为纯日期格式（只有日期，没有时间部分）
        # 支持的日期格式：YYYY-MM-DD, YYYY/MM/DD, YYYYMMDD
        date_patterns = [
            r'^\d{4}-\d{2}-\d{2}$',  # YYYY-MM-DD
            r'^\d{4}/\d{2}/\d{2}$',  # YYYY/MM/DD
            r'^\d{8}$',               # YYYYMMDD
        ]
        
        is_date_only = False
        normalized_date = None
        
        for pattern in date_patterns:
            if re.match(pattern, time_str):
                is_date_only = True
                # 统一转换为 YYYY-MM-DD 格式
                if '/' in time_str:
                    normalized_date = time_str.replace('/', '-')
                elif len(time_str) == 8:
                    # YYYYMMDD -> YYYY-MM-DD
                    normalized_date = f"{time_str[0:4]}-{time_str[4:6]}-{time_str[6:8]}"
                else:
                    normalized_date = time_str
                break
        
        # 如果是纯日期格式，且启用了日期转换功能，添加时间部分 00:00:00.000
        if is_date_only and convert_date_to_time:
            return f"{normalized_date}{separator}00:00:00.000"
        
        # 如果是纯日期格式，但未启用日期转换功能，直接返回原值
        if is_date_only and not convert_date_to_time:
            return time_str
        
        # 如果已经包含T或空格，处理现有格式
        if 'T' in time_str or ' ' in time_str:
            # 统一处理，先转换为标准格式
            if 'T' in time_str:
                time_str_normalized = time_str.replace('T', separator)
            else:
                time_str_normalized = time_str.replace(' ', separator)
            
            if '.' not in time_str_normalized:
                # 没有毫秒，添加.000
                return time_str_normalized + ".000"
            else:
                # 有毫秒，标准化为3位
                parts = time_str_normalized.split('.')
                if len(parts) == 2:
                    milliseconds = parts[1][:3].ljust(3, '0')  # 取前3位，不足补0
                    return f"{parts[0]}.{milliseconds}"
                return time_str_normalized
        else:
            # 空格分隔格式，转换为指定格式
            if len(time_str) >= 19:
                base_part = time_str[0:10] + separator + time_str[11:19]  # YYYY-MM-DD[T/ ]HH:MM:SS
                
                if '.' in time_str and len(time_str) > 19:
                    # 有毫秒部分
                    milliseconds = time_str[20:23].ljust(3, '0')  # 取毫秒部分，标准化为3位
                    return f"{base_part}.{milliseconds}"
                else:
                    # 没有毫秒部分，添加.000
                    return f"{base_part}.000"
            else:
                return time_str
    
    def _add_one_second(self, time_str: str) -> str:
        """
        将时间字符串加1秒
        
        Args:
            time_str: 时间字符串（格式：YYYY-MM-DDTHH:MM:SS.SSS）
            
        Returns:
            加1秒后的时间字符串（格式：YYYY-MM-DDTHH:MM:SS.SSS）
        """
        if not time_str or not time_str.strip():
            return time_str
        
        try:
            # 解析时间字符串
            # 支持格式：YYYY-MM-DDTHH:MM:SS.SSS 或 YYYY-MM-DD HH:MM:SS.SSS
            time_str_clean = time_str.strip().replace('T', ' ')
            
            # 尝试解析带毫秒的格式
            if '.' in time_str_clean:
                dt = datetime.strptime(time_str_clean, "%Y-%m-%d %H:%M:%S.%f")
            else:
                dt = datetime.strptime(time_str_clean, "%Y-%m-%d %H:%M:%S")
            
            # 加1秒
            dt_plus_one = dt + timedelta(seconds=1)
            
            # 格式化为标准格式 YYYY-MM-DDTHH:MM:SS.SSS
            return dt_plus_one.strftime("%Y-%m-%dT%H:%M:%S.%f")[:23]  # 保留3位毫秒
            
        except (ValueError, TypeError) as e:
            # 如果解析失败，返回原值
            print(f"警告: 时间解析失败，无法加1秒: {time_str}, 错误: {str(e)}")
            return time_str

    def send_request(self, params: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """
        发送接口请求（支持动态参数）
        
        Args:
            params: 接口请求参数字典
            
        Returns:
            接口返回的JSON数据，如果请求失败返回None
        """
        try:
            response = requests.post(
                self.api_url,
                json=params,
                headers={"Content-Type": "application/json"},
                timeout=self.timeout,
            )

            response.raise_for_status()
            return response.json()

        except requests.exceptions.RequestException as e:
            print(f"请求失败 - params={params}, 错误: {str(e)}")
            return None
        except json.JSONDecodeError as e:
            print(f"JSON解析失败 - params={params}, 错误: {str(e)}")
            return None

    def process_row(
        self, row_index: int, row: List[str], headers: List[str]
    ) -> Dict[str, Any]:
        """
        处理单行数据，请求接口并返回结果（支持动态参数）
        
        Args:
            row_index: 行索引（从0开始，不包括表头）
            row: CSV行数据
            headers: CSV表头
            
        Returns:
            处理结果字典
        """
        # 构建接口请求参数
        request_params = {}
        original_values = {}  # 保存原始值用于记录
        
        for param_config in self.api_params:
            param_name = param_config.get("param_name")
            column_index = param_config.get("column_index")
            is_time_field = param_config.get("is_time_field", False)
            
            # 如果列索引为 None 或空，跳过该参数（不作为入参）
            if column_index is None:
                continue
            
            # 检查列索引是否有效
            if column_index < 0 or column_index >= len(row):
                return {
                    "row_index": row_index,
                    "error": f"参数 '{param_name}' 的列索引无效: column_index={column_index}, 行长度={len(row)}",
                }
            
            # 获取参数值
            param_value = row[column_index].strip() if row[column_index] else ""
            
            # 检查必要字段是否为空
            if not param_value:
                return {
                    "row_index": row_index,
                    "error": f"参数 '{param_name}' 为空: 行 {row_index + 2}, 列 {column_index}",
                }
            
            # 保存原始值
            original_values[param_name] = param_value
            
            # 如果是时间字段，进行时间格式处理
            if is_time_field:
                # 去除可能的字母'a'
                if 'a' in param_value or 'A' in param_value:
                    param_value = param_value.replace('a', '').replace('A', '')
                
                # 获取是否加T分隔符的配置（默认True，保持向后兼容）
                add_t_separator = param_config.get("add_t_separator", True)
                
                # 获取是否将日期转换为时间格式的配置（默认True，保持向后兼容）
                convert_date_to_time = param_config.get("convert_date_to_time", True)
                
                # 标准化时间格式
                param_value = self.normalize_timestamp(param_value, add_t_separator=add_t_separator, convert_date_to_time=convert_date_to_time)
                
                # 根据配置决定是否加1秒
                if self.add_one_second:
                    param_value = self._add_one_second(param_value)
            
            # 添加到请求参数
            request_params[param_name] = param_value

        # 如果没有任何参数，返回错误
        if not request_params:
            return {
                "row_index": row_index,
                "error": "没有有效的接口参数配置",
            }

        # 发送请求
        api_response = self.send_request(request_params)

        if api_response is None:
            return {
                "row_index": row_index,
                "error": f"接口请求失败: params={request_params}",
            }

        # 构建结果
        result = {
            "row_index": row_index,
            "original_values": original_values,  # 保存所有原始值
            "request_params": request_params,  # 保存请求参数
            "api_data": api_response,  # 使用原始接口返回数据
        }
        
        # 为了兼容旧代码，保留旧的字段名
        if "custNo" in original_values:
            result["cust_no"] = original_values["custNo"]
        if "baseTime" in original_values:
            result["use_create_time"] = original_values["baseTime"]
            result["request_time"] = request_params.get("baseTime", "")
            
        return result

    def fetch_api_data(self, input_csv_path: str, output_csv_path: str):
        """
        从CSV文件读取数据，请求接口，输出接口全部数据
        
        Args:
            input_csv_path: 输入CSV文件路径
            output_csv_path: 输出CSV文件路径
        """
        # 读取CSV文件（使用公共工具模块）
        if not os.path.exists(input_csv_path):
            raise FileNotFoundError(f"CSV文件不存在: {input_csv_path}")
        
        headers, rows = read_csv_with_encoding_tool(input_csv_path)

        # 准备结果数据
        results = {}
        errors = {}

        print(f"\n开始并发请求接口，线程数: {self.thread_count}")
        start_time = time.time()

        # 先处理第一条数据，打印入参和出参（用于调试）
        if rows:
            print(f"\n{'='*80}")
            print("第一条请求调试信息:")
            print(f"{'='*80}")
            first_row = rows[0]
            
            # 构建第一条数据的请求参数
            first_request_params = {}
            first_original_values = {}
            params_valid = True
            
            for param_config in self.api_params:
                param_name = param_config.get("param_name")
                column_index = param_config.get("column_index")
                is_time_field = param_config.get("is_time_field", False)
                
                # 如果列索引为 None，跳过该参数
                if column_index is None:
                    print(f"参数 '{param_name}' 的列索引为空，跳过该参数")
                    continue
                
                if column_index < 0 or column_index >= len(first_row):
                    print(f"参数 '{param_name}' 的列索引无效，跳过调试信息打印")
                    params_valid = False
                    break
                
                param_value = first_row[column_index].strip() if first_row[column_index] else ""
                
                if not param_value:
                    print(f"参数 '{param_name}' 为空，跳过调试信息打印")
                    params_valid = False
                    break
                
                first_original_values[param_name] = param_value
                
                # 如果是时间字段，进行时间格式处理
                if is_time_field:
                    if 'a' in param_value or 'A' in param_value:
                        param_value = param_value.replace('a', '').replace('A', '')
                    # 获取是否加T分隔符的配置（默认True，保持向后兼容）
                    add_t_separator = param_config.get("add_t_separator", True)
                    # 获取是否将日期转换为时间格式的配置（默认True，保持向后兼容）
                    convert_date_to_time = param_config.get("convert_date_to_time", True)
                    param_value = self.normalize_timestamp(param_value, add_t_separator=add_t_separator, convert_date_to_time=convert_date_to_time)
                    if self.add_one_second:
                        param_value = self._add_one_second(param_value)
                
                first_request_params[param_name] = param_value
            
            if params_valid and first_request_params:
                # 打印请求入参
                print(f"请求入参:")
                for param_name, original_value in first_original_values.items():
                    print(f"  {param_name} (原始): {original_value}")
                for param_name, request_value in first_request_params.items():
                    if param_name in first_original_values and first_original_values[param_name] != request_value:
                        print(f"  {param_name} (处理后): {request_value}")
                print()
                
                # 发送请求并打印出参
                print(f"发送请求...")
                api_response = self.send_request(first_request_params)
                
                if api_response is not None:
                    print(f"请求成功，响应数据:")
                    print(f"{'-'*80}")
                    print(json.dumps(api_response, ensure_ascii=False, indent=2))
                    print(f"{'-'*80}")
                    if isinstance(api_response, dict):
                        print(f"响应字段数量: {len(api_response)}")
                        print(f"响应字段列表: {list(api_response.keys())[:10]}{'...' if len(api_response) > 10 else ''}")
                else:
                    print(f"请求失败")
                print(f"{'='*80}\n")
            else:
                if not first_request_params:
                    print(f"没有有效的接口参数配置")
                print(f"{'='*80}\n")

        # 使用线程池并发处理
        with ThreadPoolExecutor(max_workers=self.thread_count) as executor:
            # 提交所有任务
            future_to_row = {
                executor.submit(self.process_row, i, row, headers): i
                for i, row in enumerate(rows)
            }

            # 收集结果
            completed = 0
            for future in as_completed(future_to_row):
                completed += 1
                if completed % 1000 == 0:
                    print(f"已完成: {completed}/{len(rows)}")

                try:
                    result = future.result()
                    row_index = result["row_index"]

                    if "error" in result:
                        errors[row_index] = result["error"]
                    else:
                        results[row_index] = result

                except Exception as e:
                    row_index = future_to_row[future]
                    errors[row_index] = f"处理异常: {str(e)}"

        elapsed_time = time.time() - start_time
        print(f"\n所有请求完成，耗时: {elapsed_time:.2f}秒")
        print(f"成功: {len(results)}, 失败: {len(errors)}")

        # 递归收集所有接口返回的原始字段名（只收集叶子节点，使用原始字段名，不添加路径前缀）
        def collect_leaf_field_names(data: Any, skip_system_fields: bool = True) -> set:
            """
            递归收集所有叶子节点的字段名，保持接口返回的原始字段名
            如果接口返回的是扁平结构，直接使用字段名
            如果接口返回的是嵌套结构，只使用叶子节点的字段名，不添加路径前缀
            
            兼容不同的接口返回结构：
            1. 特征字段在顶层: {"field": "value", ...}
            2. 特征字段在data中: {"data": {"field": "value"}, ...}
            3. 特征字段在data的嵌套结构中: {"data": {"result": {"field": "value"}}, ...}
            4. 特征字段在data.features中: {"data": {"features": {"field": "value"}, ...}}  # 新结构
            
            Args:
                data: 要收集字段的数据
                skip_system_fields: 是否跳过系统字段（retCode, retMsg, success, timestamp等）
            """
            fields = set()
            if isinstance(data, dict):
                # 系统字段列表（不收集这些字段作为特征字段）
                system_fields = {"retCode", "retMsg", "success", "timestamp", "data"} if skip_system_fields else set()
                
                for key, value in data.items():
                    # 跳过系统字段，但如果data字段非空，需要递归收集data内部的字段
                    if skip_system_fields and key in system_fields:
                        if key == "data" and isinstance(value, dict) and value:
                            # data字段非空，优先从 data.features 中收集特征字段（新结构）
                            if "features" in value and isinstance(value["features"], dict):
                                # 优先收集 features 中的字段
                                features_fields = collect_leaf_field_names(value["features"], skip_system_fields=False)
                                fields.update(features_fields)
                                # 同时也要收集 data 中其他字段（兼容混合结构：data中既有features又有其他字段）
                                # 但是要排除 features 字段本身，避免重复
                                for k, v in value.items():
                                    if k != "features":
                                        if isinstance(v, dict) and v:
                                            # 递归收集其他嵌套字段
                                            nested_fields = collect_leaf_field_names(v, skip_system_fields=False)
                                            fields.update(nested_fields)
                                        else:
                                            # 叶子节点，直接添加
                                            fields.add(k)
                            else:
                                # 如果没有 features，递归收集 data 内部的字段（兼容旧结构）
                                nested_fields = collect_leaf_field_names(value, skip_system_fields=False)
                                fields.update(nested_fields)
                        continue
                    
                    if isinstance(value, dict) and value:
                        # 如果值是字典且非空，递归收集
                        nested_fields = collect_leaf_field_names(value, skip_system_fields=False)
                        fields.update(nested_fields)
                    else:
                        # 叶子节点，直接使用原始字段名（不添加路径前缀）
                        fields.add(key)
            return fields
        
        # 收集所有字段名和路径映射（用于数据访问）
        def collect_field_paths(data: Any, path: str = "", skip_system_fields: bool = True) -> Dict[str, str]:
            """
            收集字段名和访问路径的映射
            
            兼容不同的接口返回结构，正确处理data字段的嵌套结构
            优先处理 data.features 结构（新结构）
            
            Args:
                data: 要收集路径的数据
                path: 当前路径前缀
                skip_system_fields: 是否跳过系统字段（retCode, retMsg, success, timestamp等）
            """
            field_paths = {}
            if isinstance(data, dict):
                # 系统字段列表
                system_fields = {"retCode", "retMsg", "success", "timestamp", "data"} if skip_system_fields else set()
                
                for key, value in data.items():
                    # 跳过系统字段，但如果data字段非空，需要递归收集data内部的字段路径
                    if skip_system_fields and key in system_fields:
                        if key == "data" and isinstance(value, dict) and value:
                            # data字段非空，优先从 data.features 中收集特征字段路径（新结构）
                            if "features" in value and isinstance(value["features"], dict):
                                # 优先收集 features 中的字段路径
                                features_paths = collect_field_paths(value["features"], "data.features", skip_system_fields=False)
                                field_paths.update(features_paths)
                                # 同时也要收集 data 中其他字段的路径（兼容混合结构：data中既有features又有其他字段）
                                # 但是要排除 features 字段本身，避免重复
                                for k, v in value.items():
                                    if k != "features":
                                        current_path = f"data.{k}"
                                        if isinstance(v, dict) and v:
                                            # 递归收集其他嵌套字段路径
                                            nested_paths = collect_field_paths(v, current_path, skip_system_fields=False)
                                            field_paths.update(nested_paths)
                                        else:
                                            # 叶子节点，使用原始字段名作为key
                                            if k not in field_paths:
                                                field_paths[k] = current_path
                                            else:
                                                # 字段名冲突，使用完整路径
                                                field_paths[current_path] = current_path
                            else:
                                # 如果没有 features，递归收集 data 内部的字段路径（兼容旧结构）
                                nested_paths = collect_field_paths(value, "data", skip_system_fields=False)
                                field_paths.update(nested_paths)
                        continue
                    
                    current_path = f"{path}.{key}" if path else key
                    if isinstance(value, dict) and value:
                        nested_paths = collect_field_paths(value, current_path, skip_system_fields=False)
                        field_paths.update(nested_paths)
                    else:
                        # 叶子节点，使用原始字段名作为key
                        if key not in field_paths:
                            field_paths[key] = current_path
                        else:
                            # 字段名冲突，使用完整路径
                            field_paths[current_path] = current_path
            return field_paths
        
        # 收集所有叶子节点的字段名（用于CSV列名）
        all_api_fields = set()
        # 收集字段路径映射（用于数据访问）
        all_field_paths = {}
        
        for result in results.values():
            api_data = result.get("api_data", {})
            if isinstance(api_data, dict):
                # 收集叶子节点的字段名（用于CSV列名）
                fields = collect_leaf_field_names(api_data, skip_system_fields=True)
                all_api_fields.update(fields)
                
                # 收集字段路径映射（用于数据访问）
                field_paths = collect_field_paths(api_data, skip_system_fields=True)
                for field_name, path in field_paths.items():
                    if field_name in all_field_paths and all_field_paths[field_name] != path:
                        # 字段名冲突，使用完整路径
                        all_field_paths[path] = path
                    else:
                        all_field_paths[field_name] = path
        
        # 排序字段名
        all_api_fields_sorted = sorted(all_api_fields)
        
        print(f"\n接口返回的字段总数: {len(all_api_fields_sorted)}")
        # print(f"字段名列表（前10个）: {list(all_api_fields_sorted[:10])}")
        
        # 保存字段路径映射，用于后续数据访问
        self.field_path_mapping = all_field_paths

        # 构建输出表头：原始列 + 接口返回的字段
        output_headers = headers.copy()
        output_headers.extend(all_api_fields_sorted)
        
        # 记录原始列数
        original_header_count = len(headers)

        # 写入输出文件
        print(f"\n开始写入接口数据文件: {output_csv_path}")
        self._write_api_data_csv(output_csv_path, output_headers, headers, rows, results, errors, all_api_fields_sorted, original_header_count)
        print(f"✅ 接口数据文件写入完成: {output_csv_path}")

    def _write_api_data_csv(
        self,
        output_path: str,
        output_headers: List[str],
        original_headers: List[str],
        rows: List[List[str]],
        results: Dict[int, Dict],
        errors: Dict[int, str],
        api_fields: List[str],
        original_header_count: int,
    ):
        """
        写入接口数据文件（CSV格式）
        
        Args:
            output_path: 输出文件路径
            output_headers: 输出表头
            rows: 原始行数据
            results: 处理结果
            errors: 错误信息
            api_fields: 接口返回的字段列表
        """
        # 确保输出目录存在
        output_dir = os.path.dirname(output_path)
        if output_dir and not os.path.exists(output_dir):
            try:
                os.makedirs(output_dir, exist_ok=True)
            except Exception as e:
                print(f"创建目录失败: {output_dir}, 错误: {e}")
        
        try:
            total_rows = len(rows)
            with open(output_path, "w", encoding="utf-8", newline="") as f:
                writer = csv.writer(f)
                
                # 写入表头
                writer.writerow(output_headers)

                # 写入每一行的数据
                for i in range(len(rows)):
                    # 显示进度（每100行或最后一行）
                    if (i + 1) % 100 == 0 or (i + 1) == total_rows:
                        print(f"  写入进度: {i + 1}/{total_rows} 行 ({(i + 1) / total_rows * 100:.1f}%)", end='\r')
                    
                    row_data = [""] * len(output_headers)

                    if i in errors:
                        # 错误行：只填充原始数据
                        for j in range(min(len(rows[i]), len(output_headers))):
                            row_data[j] = rows[i][j] if j < len(rows[i]) else ""
                    elif i in results:
                        # 正常结果行
                        result = results[i]
                        api_data = result.get("api_data", {})
                        
                        # 填充原始列
                        for j in range(min(len(rows[i]), len(output_headers))):
                            row_data[j] = rows[i][j] if j < len(rows[i]) else ""

                        # 用API返回的值覆盖原始特征列（从feature_start_column开始）
                        # 与check_ttt.py的逻辑一致：用API值覆盖原始特征值
                        if original_header_count > self.feature_start_column:
                            # 获取原始CSV的特征列名
                            original_feature_headers = original_headers[self.feature_start_column:] if len(original_headers) > self.feature_start_column else []
                            
                            for j, header in enumerate(original_feature_headers):
                                col_idx = self.feature_start_column + j
                                if col_idx >= len(output_headers):
                                    break
                                
                                # 跳过pt列
                                if header.lower() == "pt":
                                    continue
                                
                                # 在API响应中查找特征值（支持多种查找策略，与check_ttt.py一致）
                                api_value_raw = self._find_feature_value_in_api_response(api_data, header)
                                
                                if api_value_raw is None:
                                    row_data[col_idx] = "null"
                                elif isinstance(api_value_raw, (dict, list)):
                                    # 嵌套结构转换为JSON字符串
                                    row_data[col_idx] = json.dumps(api_value_raw, ensure_ascii=False)
                                else:
                                    # 如果启用了特征值转换，将字符串转换为数值
                                    api_value = api_value_raw
                                    if self.convert_feature_to_number:
                                        converted_value = self._convert_string_to_number(api_value_raw)
                                        # 如果成功转换为数字，使用转换后的值
                                        if isinstance(converted_value, (int, float)):
                                            api_value = converted_value
                                    
                                    # 转换为字符串写入CSV
                                    row_data[col_idx] = str(api_value)
                        
                        # 填充接口返回的其他数据（追加在原始列之后，仅用于记录）
                        # 使用接口返回的原始字段名，不打平，不修改
                        for j, field in enumerate(api_fields):
                            col_index = original_header_count + j
                            if col_index < len(output_headers):
                                # 根据字段路径映射获取值
                                field_path = self.field_path_mapping.get(field, field)
                                # 解析路径并获取值
                                api_value = self._get_nested_value(api_data, field_path)
                                
                                if api_value is None:
                                    row_data[col_index] = "null"
                                elif isinstance(api_value, (dict, list)):
                                    # 嵌套结构转换为JSON字符串，但列名保持接口返回的原始字段名
                                    row_data[col_index] = json.dumps(api_value, ensure_ascii=False)
                                else:
                                    # 如果启用了特征值转换，将字符串转换为数值
                                    if self.convert_feature_to_number:
                                        converted_value = self._convert_string_to_number(api_value)
                                        # 如果成功转换为数字，使用转换后的值
                                        if isinstance(converted_value, (int, float)):
                                            api_value = converted_value
                                    
                                    # 转换为字符串写入CSV
                                    row_data[col_index] = str(api_value)
                    else:
                        # 未处理的行：只填充原始数据
                        for j in range(min(len(rows[i]), len(output_headers))):
                            row_data[j] = rows[i][j] if j < len(rows[i]) else ""

                    # 写入行数据
                    writer.writerow(row_data)
                
                # 换行，确保进度显示完整
                print()
        except Exception as e:
            print(f"写入文件失败: {output_path}")
            print(f"错误详情: {e}")
            import traceback
            traceback.print_exc()


