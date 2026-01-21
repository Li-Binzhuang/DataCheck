#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
数据对比 - Web界面
功能：提供Web界面用于输入配置和执行对比流程（接口数据对比 + 线上灰度落数对比）
"""

import os
import sys
import json
import importlib.util
import signal
from datetime import datetime
from threading import Thread
from queue import Queue

from flask import Flask, render_template, request, jsonify, Response, stream_with_context
from werkzeug.utils import secure_filename

# 添加父目录到路径，以便导入公共工具模块
sys.path.insert(0, os.path.dirname(__file__))

# 动态导入job模块中的功能模块
script_dir = os.path.dirname(os.path.abspath(__file__))  # 数据校对目录
job_dir = os.path.join(script_dir, "api_comparison", "job")

# 线上灰度落数对比目录
online_comparison_dir = os.path.join(script_dir, "online_comparison")
online_job_dir = os.path.join(online_comparison_dir, "job")

# 输出数据目录
data_dir = script_dir  # 数据校对目录
output_data_dir = os.path.join(data_dir, "outputdata")
api_output_dir = os.path.join(output_data_dir, "api_comparison")
online_output_dir = os.path.join(output_data_dir, "online_comparison")

# 输入数据目录
input_data_dir = os.path.join(data_dir, "inputdata")
api_input_dir = os.path.join(input_data_dir, "api_comparison")
online_input_dir = os.path.join(input_data_dir, "online_comparison")

# 确保输出和输入目录存在
os.makedirs(api_output_dir, exist_ok=True)
os.makedirs(online_output_dir, exist_ok=True)
os.makedirs(api_input_dir, exist_ok=True)
os.makedirs(online_input_dir, exist_ok=True)

# 动态导入配置管理模块
config_module_path = os.path.join(job_dir, "config_manager.py")
spec_config = importlib.util.spec_from_file_location("config_manager", config_module_path)
config_module = importlib.util.module_from_spec(spec_config)
spec_config.loader.exec_module(config_module)
cleanup_column_config = config_module.cleanup_column_config

# 动态导入流程执行器模块
executor_module_path = os.path.join(job_dir, "process_executor.py")
spec_executor = importlib.util.spec_from_file_location("process_executor", executor_module_path)
executor_module = importlib.util.module_from_spec(spec_executor)
spec_executor.loader.exec_module(executor_module)
execute_single_scenario = executor_module.execute_single_scenario

# 动态导入线上灰度落数对比模块
if os.path.exists(online_job_dir):
    json_parser_path = os.path.join(online_job_dir, "json_parser.py")
    spec_parser = importlib.util.spec_from_file_location("json_parser", json_parser_path)
    json_parser_module = importlib.util.module_from_spec(spec_parser)
    spec_parser.loader.exec_module(json_parser_module)
    parse_json_to_csv = json_parser_module.parse_json_to_csv

    data_comparator_path = os.path.join(online_job_dir, "data_comparator.py")
    spec_comparator = importlib.util.spec_from_file_location("data_comparator", data_comparator_path)
    data_comparator_module = importlib.util.module_from_spec(spec_comparator)
    spec_comparator.loader.exec_module(data_comparator_module)
    compare_csv_files = data_comparator_module.compare_csv_files

    report_generator_path = os.path.join(online_job_dir, "report_generator.py")
    spec_report = importlib.util.spec_from_file_location("report_generator", report_generator_path)
    report_generator_module = importlib.util.module_from_spec(spec_report)
    spec_report.loader.exec_module(report_generator_module)
    generate_reports = report_generator_module.generate_reports

app = Flask(__name__)


class OutputCapture:
    """捕获print输出"""
    def __init__(self, output_queue):
        self.output_queue = output_queue
        self.original_stdout = sys.stdout
        self.original_stderr = sys.stderr
        self.buffer = ""
    
    def write(self, text):
        # 保存到原始输出
        self.original_stdout.write(text)
        self.original_stdout.flush()
        
        # 添加到缓冲区
        self.buffer += text
        
        # 如果遇到换行符，发送完整行
        if '\n' in self.buffer:
            lines = self.buffer.split('\n')
            # 保留最后不完整的行在缓冲区
            self.buffer = lines[-1]
            # 发送完整的行
            for line in lines[:-1]:
                self.output_queue.put(line)
    
    def flush(self):
        self.original_stdout.flush()
        # 发送缓冲区中剩余的内容
        if self.buffer:
            self.output_queue.put(self.buffer)
            self.buffer = ""


def execute_comparison_flow(config_json_str: str, output_queue: Queue):
    """
    执行对比流程（在单独线程中运行）
    
    Args:
        config_json_str: JSON配置字符串
        output_queue: 输出队列
    """
    # 设置输出捕获
    capture = OutputCapture(output_queue)
    
    try:
        # 重定向stdout和stderr
        sys.stdout = capture
        sys.stderr = capture
        
        # 解析配置
        config_data = json.loads(config_json_str)
        
        # 生成时间戳后缀
        now = datetime.now()
        timestamp_suffix = now.strftime("%m%d%H%M")
        
        # 使用JSON配置，支持多场景
        scenarios = config_data.get('scenarios', [])
        global_config = config_data.get('global_config', {})
        
        if not scenarios:
            print("❌ 错误: 配置文件中没有找到场景配置")
            return
        
        # 过滤出启用的场景
        enabled_scenarios = [s for s in scenarios if s.get('enabled', True)]
        
        if not enabled_scenarios:
            print("⚠️  警告: 没有启用的场景")
            return
        
        print(f"找到 {len(enabled_scenarios)} 个启用的场景")
        print("")
        
        # 清理列索引配置文件中不再存在的场景
        all_scenario_names = [s.get('name') for s in scenarios if s.get('name')]
        column_config_path = os.path.join(script_dir, "json", "column_index_config.json")
        cleanup_column_config(column_config_path, all_scenario_names)
        
        # 执行每个场景
        success_count = 0
        fail_count = 0
        
        for i, scenario in enumerate(enabled_scenarios, 1):
            print(f"[{i}/{len(enabled_scenarios)}] ", end="")
            
            if execute_single_scenario(scenario, global_config, script_dir, timestamp_suffix, api_output_dir, api_input_dir):
                success_count += 1
                print("✅ 成功")
            else:
                fail_count += 1
                print("❌ 失败")
        
        # 总结
        print("")
        print("="*60)
        print(f"执行完成: 成功 {success_count} 个, 失败 {fail_count} 个")
        print("="*60)
        
    except json.JSONDecodeError as e:
        print(f"❌ JSON解析错误: {str(e)}")
    except Exception as e:
        print(f"❌ 执行错误: {str(e)}")
        import traceback
        traceback.print_exc()
    finally:
        # 恢复原始输出
        sys.stdout = capture.original_stdout
        sys.stderr = capture.original_stderr
        # 发送结束标记
        output_queue.put(None)  # None表示结束


def execute_online_parse_only(config_json_str: str, output_queue: Queue):
    """
    只执行JSON解析（不执行对比）
    
    Args:
        config_json_str: JSON配置字符串
        output_queue: 输出队列
    """
    # 设置输出捕获
    capture = OutputCapture(output_queue)
    
    try:
        # 重定向stdout和stderr
        sys.stdout = capture
        sys.stderr = capture
        
        # 检查并动态加载模块
        if not os.path.exists(online_job_dir):
            raise FileNotFoundError(f"线上灰度落数对比模块目录不存在: {online_job_dir}")
        
        # 动态导入JSON解析模块
        json_parser_path = os.path.join(online_job_dir, "json_parser.py")
        spec_parser = importlib.util.spec_from_file_location("json_parser", json_parser_path)
        json_parser_module = importlib.util.module_from_spec(spec_parser)
        spec_parser.loader.exec_module(json_parser_module)
        parse_json_to_csv_func = json_parser_module.parse_json_to_csv
        
        # 解析配置
        config_data = json.loads(config_json_str)
        
        online_file = config_data.get("online_file")
        offline_file = config_data.get("offline_file")  # 添加离线文件配置
        json_column = config_data.get("json_column")
        online_key_column_index = config_data.get("online_key_column", 0)
        convert_string_to_number = config_data.get("convert_string_to_number", False)
        output_prefix = config_data.get("output_prefix", "")
        
        # 生成时间戳后缀
        now = datetime.now()
        timestamp_suffix = now.strftime("%m%d%H%M")
        
        # 构建文件路径（从inputdata目录读取）
        online_file_path = os.path.join(online_input_dir, online_file)
        offline_file_path = os.path.join(online_input_dir, offline_file) if offline_file else None
        
        # 生成输出文件路径（保存到outputdata目录）
        prefix_part = f"{output_prefix}_" if output_prefix else ""
        parsed_online_csv = os.path.join(online_output_dir, f"{prefix_part}{timestamp_suffix}_解析后.csv")
        
        print(f"\n开始解析JSON数据...")
        print(f"线上文件: {online_file_path}")
        if offline_file_path and os.path.exists(offline_file_path):
            print(f"离线文件: {offline_file_path}")
        
        # 检查outputdata目录下是否已存在解析文件（选择最新的）
        existing_parsed_file = None
        if os.path.exists(online_output_dir):
            pattern_start = f"{prefix_part}" if prefix_part else ""
            pattern_end = "_解析后.csv"
            matching_files = []
            for filename in os.listdir(online_output_dir):
                if filename.startswith(pattern_start) and filename.endswith(pattern_end):
                    file_path = os.path.join(online_output_dir, filename)
                    if os.path.isfile(file_path):
                        # 获取文件修改时间，用于排序
                        mtime = os.path.getmtime(file_path)
                        matching_files.append((file_path, mtime))
            
            if matching_files:
                # 按修改时间排序，使用最新的文件
                matching_files.sort(key=lambda x: x[1], reverse=True)
                existing_parsed_file = matching_files[0][0]
        
        if existing_parsed_file:
            print(f"\n找到已存在的解析文件: {existing_parsed_file}")
            print(f"文件修改时间: {datetime.fromtimestamp(matching_files[0][1]).strftime('%Y-%m-%d %H:%M:%S')}")
            print(f"将使用此文件进行列名显示")
            parsed_file = existing_parsed_file
        else:
            # 执行解析
            parsed_file = parse_json_to_csv_func(
                online_file_path,
                parsed_online_csv,
                json_column,
                online_key_column_index,
                convert_string_to_number
            )
            print(f"\n解析完成，文件保存至: {parsed_file}")
        
        # 读取CSV工具模块
        csv_tool_path = os.path.join(script_dir, "common", "csv_tool.py")
        spec_csv = importlib.util.spec_from_file_location("csv_tool", csv_tool_path)
        csv_tool_module = importlib.util.module_from_spec(spec_csv)
        spec_csv.loader.exec_module(csv_tool_module)
        read_csv_with_encoding = csv_tool_module.read_csv_with_encoding
        
        # 读取解析后的CSV文件列名并显示
        parsed_headers, _ = read_csv_with_encoding(parsed_file)
        print(f"\n解析后的文件列名（共 {len(parsed_headers)} 列，显示前5列）:")
        display_cols = parsed_headers[:5]
        col_info = "、".join(display_cols)
        print(col_info)
        if len(parsed_headers) > 5:
            print(f"... 还有 {len(parsed_headers) - 5} 列未显示")
        
        # 读取离线文件列名（如果存在）
        if offline_file_path and os.path.exists(offline_file_path):
            offline_headers, _ = read_csv_with_encoding(offline_file_path)
            print(f"\n离线文件列名（共 {len(offline_headers)} 列，显示前5列）:")
            display_cols = offline_headers[:5]
            col_info = "、".join(display_cols)
            print(col_info)
            if len(offline_headers) > 5:
                print(f"... 还有 {len(offline_headers) - 5} 列未显示")
        
        print(f"\nJSON列: {json_column}")
        print(f"在线文件主键列索引: {online_key_column_index}")
        print(f"字符串转数值: {convert_string_to_number}")
        print(f"输出文件前缀: {output_prefix}")
        print(f"时间戳后缀: {timestamp_suffix}")
        
        # 检查输入文件是否存在
        if not os.path.exists(online_file_path):
            raise FileNotFoundError(f"线上文件不存在: {online_file_path}")
        
        # 解析JSON数据
        parsed_file = parse_json_to_csv_func(
            online_file_path,
            parsed_online_csv,
            json_column,
            online_key_column_index,
            convert_string_to_number
        )
        
        # 读取解析后的CSV文件列名
        parsed_headers, _ = read_csv_with_encoding(parsed_file)
        print(f"\n解析后的文件列名（共 {len(parsed_headers)} 列，显示前5列）:")
        # 只显示前5列，用顿号分隔
        display_cols = parsed_headers[:5]
        col_info = "、".join(display_cols)
        print(col_info)
        if len(parsed_headers) > 5:
            print(f"... 还有 {len(parsed_headers) - 5} 列未显示")
        print(f"\n✅ JSON解析完成: {parsed_file}")
        print(f"共写入 {len(parsed_headers)} 列数据")
        
    except json.JSONDecodeError as e:
        print(f"❌ JSON解析错误: {str(e)}")
    except Exception as e:
        print(f"❌ 执行错误: {str(e)}")
        import traceback
        traceback.print_exc()
    finally:
        # 恢复原始输出
        sys.stdout = capture.original_stdout
        sys.stderr = capture.original_stderr
        # 发送结束标记
        output_queue.put(None)  # None表示结束


def execute_online_comparison_flow(config_json_str: str, output_queue: Queue):
    """
    执行线上灰度落数对比流程（在单独线程中运行）
    
    Args:
        config_json_str: JSON配置字符串
        output_queue: 输出队列
    """
    # 设置输出捕获
    capture = OutputCapture(output_queue)
    
    try:
        # 重定向stdout和stderr
        sys.stdout = capture
        sys.stderr = capture
        
        # 检查并动态加载模块
        if not os.path.exists(online_job_dir):
            raise FileNotFoundError(f"线上灰度落数对比模块目录不存在: {online_job_dir}")
        
        # 动态导入模块（在函数内部加载，避免全局变量问题）
        json_parser_path = os.path.join(online_job_dir, "json_parser.py")
        spec_parser = importlib.util.spec_from_file_location("json_parser", json_parser_path)
        json_parser_module = importlib.util.module_from_spec(spec_parser)
        spec_parser.loader.exec_module(json_parser_module)
        parse_json_to_csv_func = json_parser_module.parse_json_to_csv

        data_comparator_path = os.path.join(online_job_dir, "data_comparator.py")
        spec_comparator = importlib.util.spec_from_file_location("data_comparator", data_comparator_path)
        data_comparator_module = importlib.util.module_from_spec(spec_comparator)
        spec_comparator.loader.exec_module(data_comparator_module)
        compare_csv_files_func = data_comparator_module.compare_csv_files

        report_generator_path = os.path.join(online_job_dir, "report_generator.py")
        spec_report = importlib.util.spec_from_file_location("report_generator", report_generator_path)
        report_generator_module = importlib.util.module_from_spec(spec_report)
        spec_report.loader.exec_module(report_generator_module)
        generate_reports_func = report_generator_module.generate_reports
        
        # 解析配置
        config_data = json.loads(config_json_str)
        
        online_file = config_data.get("online_file")
        offline_file = config_data.get("offline_file")
        json_column = config_data.get("json_column")
        online_key_column_index = config_data.get("online_key_column", 0)
        offline_key_column_index = config_data.get("offline_key_column", 1)
        # 支持分别设置两个文件的特征起始列索引
        online_feature_start_column = config_data.get("online_feature_start_column")
        offline_feature_start_column = config_data.get("offline_feature_start_column")
        # 兼容旧配置：如果新配置不存在，使用旧的feature_start_column
        if online_feature_start_column is None:
            online_feature_start_column = config_data.get("feature_start_column", 3)
        if offline_feature_start_column is None:
            offline_feature_start_column = config_data.get("feature_start_column", 3)
        convert_string_to_number = config_data.get("convert_string_to_number", False)
        output_prefix = config_data.get("output_prefix", "")
        
        # 生成时间戳后缀
        now = datetime.now()
        timestamp_suffix = now.strftime("%m%d%H%M")
        
        # 构建文件路径（从inputdata目录读取）
        online_file_path = os.path.join(online_input_dir, online_file)
        offline_file_path = os.path.join(online_input_dir, offline_file)
        
        # 生成输出文件路径（保存到outputdata目录）
        prefix_part = f"{output_prefix}_" if output_prefix else ""
        output_base_path = os.path.join(online_output_dir, f"{prefix_part}{timestamp_suffix}_对比结果")
        
        print(f"\n开始执行线上灰度落数对比流程...")
        print(f"配置文件: {os.path.join(online_comparison_dir, 'config.json')}")
        print(f"线上文件: {online_file_path}")
        print(f"离线文件: {offline_file_path}")
        print(f"JSON列: {json_column}")
        print(f"在线文件主键列索引: {online_key_column_index}")
        print(f"离线文件主键列索引: {offline_key_column_index}")
        print(f"在线文件特征列起始索引: {online_feature_start_column}")
        print(f"离线文件特征列起始索引: {offline_feature_start_column}")
        print(f"字符串转数值: {convert_string_to_number}")
        print(f"输出文件前缀: {output_prefix}")
        print(f"时间戳后缀: {timestamp_suffix}")
        
        # 检查输入文件是否存在
        if not os.path.exists(online_file_path):
            raise FileNotFoundError(f"线上文件不存在: {online_file_path}")
        
        if not os.path.exists(offline_file_path):
            raise FileNotFoundError(f"离线文件不存在: {offline_file_path}")
        
        # 读取离线文件列名（在执行对比前先显示）
        csv_tool_path = os.path.join(script_dir, "common", "csv_tool.py")
        spec_csv = importlib.util.spec_from_file_location("csv_tool", csv_tool_path)
        csv_tool_module = importlib.util.module_from_spec(spec_csv)
        spec_csv.loader.exec_module(csv_tool_module)
        read_csv_with_encoding = csv_tool_module.read_csv_with_encoding
        
        offline_headers, _ = read_csv_with_encoding(offline_file_path)
        print(f"\n离线文件列名（共 {len(offline_headers)} 列，显示前5列）:")
        # 只显示前5列，用顿号分隔
        display_cols = offline_headers[:5]
        col_info = "、".join(display_cols)
        print(col_info)
        if len(offline_headers) > 5:
            print(f"... 还有 {len(offline_headers) - 5} 列未显示")
        
        # 步骤1：查找或解析JSON数据
        # 先在outputdata目录下查找已存在的解析文件（匹配前缀，选择最新的）
        parsed_file = None
        if os.path.exists(online_output_dir):
            # 查找匹配的解析文件
            pattern_start = f"{prefix_part}" if prefix_part else ""
            pattern_end = "_解析后.csv"
            matching_files = []
            for filename in os.listdir(online_output_dir):
                if filename.startswith(pattern_start) and filename.endswith(pattern_end):
                    file_path = os.path.join(online_output_dir, filename)
                    if os.path.isfile(file_path):
                        # 获取文件修改时间，用于排序
                        mtime = os.path.getmtime(file_path)
                        matching_files.append((file_path, mtime))
            
            if matching_files:
                # 按修改时间排序，使用最新的文件
                matching_files.sort(key=lambda x: x[1], reverse=True)
                parsed_file = matching_files[0][0]
                print(f"\n找到已存在的解析文件: {parsed_file}")
                print(f"文件修改时间: {datetime.fromtimestamp(matching_files[0][1]).strftime('%Y-%m-%d %H:%M:%S')}")
        
        # 如果没有找到已存在的解析文件，则进行解析
        if parsed_file is None:
            parsed_online_csv = os.path.join(online_output_dir, f"{prefix_part}{timestamp_suffix}_解析后.csv")
            print(f"\n未找到已存在的解析文件，开始解析JSON数据...")
            parsed_file = parse_json_to_csv_func(
                online_file_path,
                parsed_online_csv,
                json_column,
                online_key_column_index,
                convert_string_to_number
            )
            print(f"解析完成，文件保存至: {parsed_file}")
        
        # 读取解析后的CSV文件列名
        parsed_headers, _ = read_csv_with_encoding(parsed_file)
        print(f"\n解析后的文件列名（共 {len(parsed_headers)} 列，显示前5列）:")
        # 只显示前5列，用顿号分隔
        display_cols = parsed_headers[:5]
        col_info = "、".join(display_cols)
        print(col_info)
        if len(parsed_headers) > 5:
            print(f"... 还有 {len(parsed_headers) - 5} 列未显示")
        
        # 步骤2：执行数据对比
        (differences_dict, matches_dict, all_features, feature_stats, matched_count,
         unmatched_count, unmatched_rows, headers_online, headers_offline,
         total_comparisons, match_count, diff_count, match_ratio,
         online_only_rows, online_only_count, rows_online, rows_offline) = compare_csv_files_func(
            parsed_file,
            offline_file_path,
            online_key_column_index,
            offline_key_column_index,
            online_feature_start_column,
            offline_feature_start_column,
            original_online_file_path=online_file_path  # 传递原始线上文件路径
        )
        
        # 步骤3：生成报告
        print(f"\n开始生成报告...")
        generate_reports_func(
            output_base_path,
            differences_dict,
            all_features,
            feature_stats,
            matched_count,
            total_comparisons,
            match_count,
            diff_count,
            match_ratio,
            unmatched_rows,
            online_only_rows,
            headers_offline,
            headers_online,
            rows_offline,
            rows_online,
            offline_key_column_index,
            online_key_column_index,
            offline_feature_start_column,
            online_feature_start_column
        )
        
        print(f"\n{'='*80}")
        print(f"完整流程执行完成！")
        print(f"{'='*80}")
        print(f"生成的文件:")
        print(f"  1. 解析后的在线数据: {parsed_file}")
        print(f"  2. 差异特征汇总: {output_base_path}_差异特征汇总.csv")
        print(f"  3. 差异数据明细: {output_base_path}_差异数据明细.csv")
        print(f"  4. 特征统计: {output_base_path}_特征统计.csv")
        print(f"  5. 全量数据合并: {output_base_path}_全量数据合并.csv")
        
        if unmatched_count > 0:
            print(f"  6. 仅在离线表中的数据: {output_base_path}_仅在离线表中的数据.csv (共 {unmatched_count} 条)")
        
        if online_only_count > 0:
            print(f"  7. 仅在线上文件中的数据: {output_base_path}_仅在线上文件中的数据.csv (共 {online_only_count} 条)")
        
        print(f"{'='*80}")
        
    except json.JSONDecodeError as e:
        print(f"❌ JSON解析错误: {str(e)}")
    except Exception as e:
        print(f"❌ 执行错误: {str(e)}")
        import traceback
        traceback.print_exc()
    finally:
        # 恢复原始输出
        sys.stdout = capture.original_stdout
        sys.stderr = capture.original_stderr
        # 发送结束标记
        output_queue.put(None)  # None表示结束


def execute_online_multi_scenario_flow(config_data: dict, output_queue: Queue):
    """
    执行线上灰度落数对比多场景流程（在单独线程中运行）
    
    Args:
        config_data: 配置字典（包含scenarios数组）
        output_queue: 输出队列
    """
    # 设置输出捕获
    capture = OutputCapture(output_queue)
    
    try:
        # 重定向stdout和stderr
        sys.stdout = capture
        sys.stderr = capture
        
        # 解析配置
        scenarios = config_data.get('scenarios', [])
        
        if not scenarios:
            print("❌ 错误: 配置文件中没有找到场景配置")
            return
        
        # 过滤出启用的场景
        enabled_scenarios = [s for s in scenarios if s.get('enabled', True)]
        
        if not enabled_scenarios:
            print("⚠️  警告: 没有启用的场景")
            return
        
        print(f"找到 {len(enabled_scenarios)} 个启用的场景")
        print("")
        
        # 生成时间戳后缀
        now = datetime.now()
        timestamp_suffix = now.strftime("%m%d%H%M")
        
        # 检查并动态加载模块
        if not os.path.exists(online_job_dir):
            raise FileNotFoundError(f"线上灰度落数对比模块目录不存在: {online_job_dir}")
        
        # 动态导入模块
        json_parser_path = os.path.join(online_job_dir, "json_parser.py")
        spec_parser = importlib.util.spec_from_file_location("json_parser", json_parser_path)
        json_parser_module = importlib.util.module_from_spec(spec_parser)
        spec_parser.loader.exec_module(json_parser_module)
        parse_json_to_csv_func = json_parser_module.parse_json_to_csv

        data_comparator_path = os.path.join(online_job_dir, "data_comparator.py")
        spec_comparator = importlib.util.spec_from_file_location("data_comparator", data_comparator_path)
        data_comparator_module = importlib.util.module_from_spec(spec_comparator)
        spec_comparator.loader.exec_module(data_comparator_module)
        compare_csv_files_func = data_comparator_module.compare_csv_files

        report_generator_path = os.path.join(online_job_dir, "report_generator.py")
        spec_report = importlib.util.spec_from_file_location("report_generator", report_generator_path)
        report_generator_module = importlib.util.module_from_spec(spec_report)
        spec_report.loader.exec_module(report_generator_module)
        generate_reports_func = report_generator_module.generate_reports
        
        csv_tool_path = os.path.join(script_dir, "common", "csv_tool.py")
        spec_csv = importlib.util.spec_from_file_location("csv_tool", csv_tool_path)
        csv_tool_module = importlib.util.module_from_spec(spec_csv)
        spec_csv.loader.exec_module(csv_tool_module)
        read_csv_with_encoding = csv_tool_module.read_csv_with_encoding
        
        # 执行每个场景
        success_count = 0
        fail_count = 0
        
        for i, scenario in enumerate(enabled_scenarios, 1):
            print(f"[{i}/{len(enabled_scenarios)}] 执行场景: {scenario.get('name', f'场景{i}')}")
            print("")
            
            try:
                online_file = scenario.get("online_file")
                offline_file = scenario.get("offline_file")
                json_column = scenario.get("json_column")
                online_key_column_index = scenario.get("online_key_column", 0)
                offline_key_column_index = scenario.get("offline_key_column", 1)
                online_feature_start_column = scenario.get("online_feature_start_column")
                offline_feature_start_column = scenario.get("offline_feature_start_column")
                # 兼容旧配置
                if online_feature_start_column is None:
                    online_feature_start_column = scenario.get("feature_start_column", 3)
                if offline_feature_start_column is None:
                    offline_feature_start_column = scenario.get("feature_start_column", 3)
                convert_string_to_number = scenario.get("convert_string_to_number", False)
                output_prefix = scenario.get("output_prefix", "")
                
                # 构建文件路径（从inputdata目录读取）
                online_file_path = os.path.join(online_input_dir, online_file)
                offline_file_path = os.path.join(online_input_dir, offline_file)
                
                # 生成输出文件路径（保存到outputdata目录）
                prefix_part = f"{output_prefix}_" if output_prefix else ""
                output_base_path = os.path.join(online_output_dir, f"{prefix_part}{timestamp_suffix}_对比结果")
                
                # 检查输入文件是否存在
                if not os.path.exists(online_file_path):
                    raise FileNotFoundError(f"线上文件不存在: {online_file_path}")
                if not os.path.exists(offline_file_path):
                    raise FileNotFoundError(f"离线文件不存在: {offline_file_path}")
                
                # 步骤1：查找或解析JSON数据
                # 先在outputdata目录下查找已存在的解析文件（匹配前缀，选择最新的）
                parsed_file = None
                if os.path.exists(online_output_dir):
                    # 查找匹配的解析文件
                    pattern_start = f"{prefix_part}" if prefix_part else ""
                    pattern_end = "_解析后.csv"
                    matching_files = []
                    for filename in os.listdir(online_output_dir):
                        if filename.startswith(pattern_start) and filename.endswith(pattern_end):
                            file_path = os.path.join(online_output_dir, filename)
                            if os.path.isfile(file_path):
                                # 获取文件修改时间，用于排序
                                mtime = os.path.getmtime(file_path)
                                matching_files.append((file_path, mtime))
                    
                    if matching_files:
                        # 按修改时间排序，使用最新的文件
                        matching_files.sort(key=lambda x: x[1], reverse=True)
                        parsed_file = matching_files[0][0]
                        print(f"找到已存在的解析文件: {parsed_file}")
                        print(f"文件修改时间: {datetime.fromtimestamp(matching_files[0][1]).strftime('%Y-%m-%d %H:%M:%S')}")
                
                # 如果没有找到已存在的解析文件，则进行解析
                if parsed_file is None:
                    parsed_online_csv = os.path.join(online_output_dir, f"{prefix_part}{timestamp_suffix}_解析后.csv")
                    print(f"未找到已存在的解析文件，开始解析JSON数据...")
                    parsed_file = parse_json_to_csv_func(
                        online_file_path,
                        parsed_online_csv,
                        json_column,
                        online_key_column_index,
                        convert_string_to_number
                    )
                    print(f"解析完成，文件保存至: {parsed_file}")
                
                # 步骤2：执行数据对比
                (differences_dict, matches_dict, all_features, feature_stats, matched_count,
                 unmatched_count, unmatched_rows, headers_online, headers_offline,
                 total_comparisons, match_count, diff_count, match_ratio,
                 online_only_rows, online_only_count, rows_online, rows_offline) = compare_csv_files_func(
                    parsed_file,
                    offline_file_path,
                    online_key_column_index,
                    offline_key_column_index,
                    online_feature_start_column,
                    offline_feature_start_column,
                    original_online_file_path=online_file_path  # 传递原始线上文件路径
                )
                
                # 步骤3：生成报告
                generate_reports_func(
                    output_base_path,
                    differences_dict,
                    all_features,
                    feature_stats,
                    matched_count,
                    total_comparisons,
                    match_count,
                    diff_count,
                    match_ratio,
                    unmatched_rows,
                    online_only_rows,
                    headers_offline,
                    headers_online,
                    rows_offline,
                    rows_online,
                    offline_key_column_index,
                    online_key_column_index,
                    offline_feature_start_column,
                    online_feature_start_column
                )
                
                print(f"✅ 场景 {scenario.get('name', f'场景{i}')} 执行成功")
                success_count += 1
            except Exception as e:
                print(f"❌ 场景 {scenario.get('name', f'场景{i}')} 执行失败: {str(e)}")
                import traceback
                traceback.print_exc()
                fail_count += 1
            
            print("")
        
        # 总结
        print("="*60)
        print(f"执行完成: 成功 {success_count} 个, 失败 {fail_count} 个")
        print("="*60)
        
    except Exception as e:
        print(f"❌ 执行错误: {str(e)}")
        import traceback
        traceback.print_exc()
    finally:
        # 恢复原始输出
        sys.stdout = capture.original_stdout
        sys.stderr = capture.original_stderr
        # 发送结束标记
        output_queue.put(None)  # None表示结束


@app.route('/')
def index():
    """首页"""
    return render_template('index.html')


@app.route('/api/config/load', methods=['GET'])
def load_config():
    """加载默认配置（接口数据对比）"""
    config_file_path = os.path.join(script_dir, "config.json")
    try:
        if os.path.exists(config_file_path):
            with open(config_file_path, 'r', encoding='utf-8') as f:
                config_data = json.load(f)
            return jsonify({
                'success': True,
                'config': config_data
            })
        else:
            return jsonify({
                'success': False,
                'error': '配置文件不存在'
            })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        })


@app.route('/api/config/online/load', methods=['GET'])
def load_online_config():
    """加载线上灰度落数对比配置（支持多场景）"""
    config_file_path = os.path.join(online_comparison_dir, "config.json")
    try:
        if os.path.exists(config_file_path):
            with open(config_file_path, 'r', encoding='utf-8') as f:
                config_data = json.load(f)
            
            # 如果配置中没有scenarios字段，说明是旧格式，转换为新格式
            if 'scenarios' not in config_data:
                # 单场景格式，转换为scenarios格式
                single_scenario = {
                    'name': '场景1',
                    'enabled': True,
                    'description': '',
                    **config_data
                }
                config_data = {'scenarios': [single_scenario]}
            
            return jsonify({
                'success': True,
                'config': config_data
            })
        else:
            # 如果没有配置文件，返回空配置（前端会创建默认场景）
            return jsonify({
                'success': True,
                'config': {}
            })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        })


@app.route('/api/config/save', methods=['POST'])
def save_config():
    """保存配置到文件（接口数据对比）"""
    try:
        config_data = request.json.get('config')
        if not config_data:
            return jsonify({'success': False, 'error': '配置数据为空'})
        
        # 验证JSON格式
        json.dumps(config_data)
        
        config_file_path = os.path.join(script_dir, "config.json")
        with open(config_file_path, 'w', encoding='utf-8') as f:
            json.dump(config_data, f, ensure_ascii=False, indent=2)
        
        return jsonify({'success': True})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})


@app.route('/api/config/online/save', methods=['POST'])
def save_online_config():
    """保存线上灰度落数对比配置到文件（支持多场景）"""
    try:
        config_data = request.json.get('config')
        if not config_data:
            return jsonify({'success': False, 'error': '配置数据为空'})

        # 验证JSON格式
        json.dumps(config_data)
        
        # 如果前端发送的是scenarios格式，直接保存
        # 如果是单场景格式，转换为scenarios格式（向后兼容）
        if 'scenarios' not in config_data:
            # 单场景格式，转换为scenarios格式
            single_scenario = {
                'name': '场景1',
                'enabled': True,
                'description': '',
                **config_data
            }
            config_data = {'scenarios': [single_scenario]}

        config_file_path = os.path.join(online_comparison_dir, "config.json")
        with open(config_file_path, 'w', encoding='utf-8') as f:
            json.dump(config_data, f, ensure_ascii=False, indent=2)

        return jsonify({'success': True})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})


@app.route('/api/upload', methods=['POST'])
def upload_file():
    """上传CSV文件（接口数据对比）"""
    try:
        if 'file' not in request.files:
            return jsonify({'success': False, 'error': '没有文件'})
        
        file = request.files['file']
        if file.filename == '':
            return jsonify({'success': False, 'error': '文件名为空'})
        
        if file and file.filename.endswith('.csv'):
            # 确保文件名安全
            filename = secure_filename(file.filename)
            file_path = os.path.join(api_input_dir, filename)
            
            # 保存文件
            file.save(file_path)
            
            return jsonify({
                'success': True,
                'filename': filename,
                'message': f'文件上传成功: {filename}'
            })
        else:
            return jsonify({'success': False, 'error': '只支持CSV文件'})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})


@app.route('/api/upload/online', methods=['POST'])
def upload_online_file():
    """上传CSV文件（线上灰度落数对比）"""
    try:
        if 'file' not in request.files:
            return jsonify({'success': False, 'error': '没有文件'})
        
        file = request.files['file']
        if file.filename == '':
            return jsonify({'success': False, 'error': '文件名为空'})
        
        if file and file.filename.endswith('.csv'):
            # 确保文件名安全
            filename = secure_filename(file.filename)
            file_path = os.path.join(online_input_dir, filename)
            
            # 保存文件
            file.save(file_path)
            
            return jsonify({
                'success': True,
                'filename': filename,
                'message': f'文件上传成功: {filename}'
            })
        else:
            return jsonify({'success': False, 'error': '只支持CSV文件'})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})


@app.route('/api/execute', methods=['POST'])
def execute():
    """执行对比流程（接口数据对比）"""
    try:
        config_json_str = request.json.get('config')
        if not config_json_str:
            return jsonify({'success': False, 'error': '配置数据为空'})

        # 验证JSON格式
        json.loads(config_json_str)

        # 创建输出队列
        output_queue = Queue()

        # 在单独线程中执行
        thread = Thread(target=execute_comparison_flow, args=(config_json_str, output_queue))
        thread.daemon = True
        thread.start()
        
        def generate():
            """生成流式输出"""
            yield f"data: {json.dumps({'type': 'start', 'message': '开始执行...'})}\n\n"
            
            # 实时读取输出队列
            while True:
                try:
                    # 从队列获取输出（阻塞等待，最多1秒）
                    try:
                        line = output_queue.get(timeout=1)
                    except:
                        # 检查线程是否还在运行
                        if not thread.is_alive():
                            # 线程已结束，读取剩余输出
                            remaining = []
                            while not output_queue.empty():
                                try:
                                    remaining.append(output_queue.get_nowait())
                                except:
                                    break
                            for item in remaining:
                                if item is None:
                                    break
                                yield f"data: {json.dumps({'type': 'output', 'message': str(item)})}\n\n"
                            break
                        continue
                    
                    # None表示结束
                    if line is None:
                        break
                    
                    # 发送输出
                    yield f"data: {json.dumps({'type': 'output', 'message': str(line)})}\n\n"
                except Exception as e:
                    yield f"data: {json.dumps({'type': 'error', 'message': f'输出错误: {str(e)}'})}\n\n"
                    break
            
            yield f"data: {json.dumps({'type': 'end', 'message': '执行完成'})}\n\n"
        
        return Response(
            stream_with_context(generate()),
            mimetype='text/event-stream',
            headers={
                'Cache-Control': 'no-cache',
                'X-Accel-Buffering': 'no'
            }
        )
        
    except json.JSONDecodeError as e:
        return jsonify({'success': False, 'error': f'JSON格式错误: {str(e)}'})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})


@app.route('/api/parse/online', methods=['POST'])
def parse_online():
    """只执行JSON解析（不执行对比）"""
    try:
        config_json_str = request.json.get('config')
        if not config_json_str:
            return jsonify({'success': False, 'error': '配置数据为空'})

        # 验证JSON格式
        json.loads(config_json_str)

        # 创建输出队列
        output_queue = Queue()

        # 在单独线程中执行
        thread = Thread(target=execute_online_parse_only, args=(config_json_str, output_queue))
        thread.daemon = True
        thread.start()
        
        def generate():
            """生成流式输出"""
            yield f"data: {json.dumps({'type': 'start', 'message': '开始解析JSON...'})}\n\n"
            
            # 实时读取输出队列
            while True:
                try:
                    # 从队列获取输出（阻塞等待，最多1秒）
                    try:
                        line = output_queue.get(timeout=1)
                    except:
                        # 检查线程是否还在运行
                        if not thread.is_alive():
                            # 线程已结束，读取剩余输出
                            remaining = []
                            while not output_queue.empty():
                                try:
                                    remaining.append(output_queue.get_nowait())
                                except:
                                    break
                            for item in remaining:
                                if item is None:
                                    break
                                yield f"data: {json.dumps({'type': 'output', 'message': str(item)})}\n\n"
                            break
                        continue
                    
                    # None表示结束
                    if line is None:
                        break
                    
                    # 发送输出
                    yield f"data: {json.dumps({'type': 'output', 'message': str(line)})}\n\n"
                except Exception as e:
                    yield f"data: {json.dumps({'type': 'error', 'message': f'输出错误: {str(e)}'})}\n\n"
                    break
            
            yield f"data: {json.dumps({'type': 'end', 'message': '解析完成'})}\n\n"
        
        return Response(
            stream_with_context(generate()),
            mimetype='text/event-stream',
            headers={
                'Cache-Control': 'no-cache',
                'X-Accel-Buffering': 'no'
            }
        )
        
    except json.JSONDecodeError as e:
        return jsonify({'success': False, 'error': f'JSON格式错误: {str(e)}'})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})


@app.route('/api/execute/online', methods=['POST'])
def execute_online():
    """执行线上灰度落数对比流程（支持单场景或多场景）"""
    try:
        config_data = request.json.get('config')
        if not config_data:
            return jsonify({'success': False, 'error': '配置数据为空'})
        
        # 判断是单场景还是多场景配置
        if isinstance(config_data, str):
            # 旧格式：JSON字符串（单场景）
            config_json_str = config_data
            output_queue = Queue()
            thread = Thread(target=execute_online_comparison_flow, args=(config_json_str, output_queue))
            thread.daemon = True
            thread.start()
        elif isinstance(config_data, dict):
            # 新格式：字典（可能是单场景或多场景）
            if 'scenarios' in config_data:
                # 多场景模式
                scenarios = config_data.get('scenarios', [])
                enabled_scenarios = [s for s in scenarios if s.get('enabled', True)]
                
                if not enabled_scenarios:
                    return jsonify({'success': False, 'error': '没有启用的场景'})
                
                # 创建输出队列
                output_queue = Queue()
                
                # 在单独线程中执行多场景流程
                thread = Thread(target=execute_online_multi_scenario_flow, args=(config_data, output_queue))
                thread.daemon = True
                thread.start()
            else:
                # 单场景模式（兼容旧格式）
                config_json_str = json.dumps(config_data)
                output_queue = Queue()
                thread = Thread(target=execute_online_comparison_flow, args=(config_json_str, output_queue))
                thread.daemon = True
                thread.start()
        else:
            return jsonify({'success': False, 'error': '配置格式错误'})
        
        # 生成流式输出
        def generate():
            """生成流式输出"""
            yield f"data: {json.dumps({'type': 'start', 'message': '开始执行...'})}\n\n"
            
            # 实时读取输出队列
            while True:
                try:
                    # 从队列获取输出（阻塞等待，最多1秒）
                    try:
                        line = output_queue.get(timeout=1)
                    except:
                        # 检查线程是否还在运行
                        if not thread.is_alive():
                            # 线程已结束，读取剩余输出
                            remaining = []
                            while not output_queue.empty():
                                try:
                                    remaining.append(output_queue.get_nowait())
                                except:
                                    break
                            for item in remaining:
                                if item is None:
                                    break
                                yield f"data: {json.dumps({'type': 'output', 'message': str(item)})}\n\n"
                            break
                        continue
                    
                    # None表示结束
                    if line is None:
                        break
                    
                    # 发送输出
                    yield f"data: {json.dumps({'type': 'output', 'message': str(line)})}\n\n"
                except Exception as e:
                    yield f"data: {json.dumps({'type': 'error', 'message': f'输出错误: {str(e)}'})}\n\n"
                    break
            
            yield f"data: {json.dumps({'type': 'end', 'message': '执行完成'})}\n\n"
        
        return Response(
            stream_with_context(generate()),
            mimetype='text/event-stream',
            headers={
                'Cache-Control': 'no-cache',
                'X-Accel-Buffering': 'no'
            }
        )
        
    except json.JSONDecodeError as e:
        return jsonify({'success': False, 'error': f'JSON格式错误: {str(e)}'})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})


def signal_handler(sig, frame):
    """处理Ctrl+C信号"""
    print("\n\n正在停止服务...")
    sys.exit(0)


if __name__ == '__main__':
    # 注册信号处理器
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    # 确保templates目录存在
    templates_dir = os.path.join(script_dir, 'templates')
    if not os.path.exists(templates_dir):
        os.makedirs(templates_dir)
    
    # 默认端口5001（避免macOS上AirPlay Receiver占用5000端口）
    import argparse
    parser = argparse.ArgumentParser(description='场景1：接口数据对比 - Web界面')
    parser.add_argument('--port', type=int, default=5001, help='服务端口（默认: 5001）')
    parser.add_argument('--host', type=str, default='0.0.0.0', help='服务地址（默认: 0.0.0.0）')
    args = parser.parse_args()
    
    print("="*60)
    print("数据对比 - Web界面")
    print("功能：接口数据对比 + 线上灰度落数对比")
    print("="*60)
    print(f"\n访问地址: http://localhost:{args.port}")
    print(f"按 Ctrl+C 停止服务")
    print(f"或使用停止脚本: ./stop_web.sh\n")
    
    try:
        app.run(host=args.host, port=args.port, debug=False, threaded=True, use_reloader=False)
    except KeyboardInterrupt:
        print("\n\n服务已停止")
        sys.exit(0)
