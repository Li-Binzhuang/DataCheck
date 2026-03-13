#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
线上灰度落数对比路由
"""

import os
import sys
import json
import importlib.util
from datetime import datetime
from threading import Thread
from queue import Queue

from flask import Blueprint, request, jsonify, Response, stream_with_context
from werkzeug.utils import secure_filename

from web.config import (
    SCRIPT_DIR, JOB_DIR, ONLINE_JOB_DIR, DATA_COMPARISON_JOB_DIR, COMMON_DIR,
    API_OUTPUT_DIR, ONLINE_OUTPUT_DIR, COMPARE_OUTPUT_DIR,
    API_INPUT_DIR, ONLINE_INPUT_DIR, COMPARE_INPUT_DIR, ONLINE_COMPARISON_DIR
)
from web.utils import OutputCapture, TaskOutputCapture

online_bp = Blueprint('online_routes', __name__)

# 为了兼容性，创建小写别名
online_input_dir = ONLINE_INPUT_DIR
online_output_dir = ONLINE_OUTPUT_DIR
online_comparison_dir = ONLINE_COMPARISON_DIR
online_job_dir = ONLINE_JOB_DIR
script_dir = SCRIPT_DIR

# 动态导入线上灰度落数对比模块
json_parser_path = os.path.join(ONLINE_JOB_DIR, "json_parser.py")
spec_parser = importlib.util.spec_from_file_location("json_parser", json_parser_path)
json_parser_module = importlib.util.module_from_spec(spec_parser)
spec_parser.loader.exec_module(json_parser_module)
parse_json_to_csv = json_parser_module.parse_json_to_csv

data_comparator_path = os.path.join(ONLINE_JOB_DIR, "data_comparator.py")
spec_comparator = importlib.util.spec_from_file_location("data_comparator", data_comparator_path)
data_comparator_module = importlib.util.module_from_spec(spec_comparator)
spec_comparator.loader.exec_module(data_comparator_module)
compare_csv_files = data_comparator_module.compare_csv_files

report_generator_path = os.path.join(ONLINE_JOB_DIR, "report_generator.py")
spec_report = importlib.util.spec_from_file_location("report_generator", report_generator_path)
report_generator_module = importlib.util.module_from_spec(spec_report)
spec_report.loader.exec_module(report_generator_module)
generate_reports = report_generator_module.generate_reports


def execute_online_parse_only(config_json_str: str, output_queue: Queue, task_id: str = None):
    """
    只执行JSON解析（不执行对比）
    
    Args:
        config_json_str: JSON配置字符串
        output_queue: 输出队列
        task_id: 任务ID（用于日志持久化）
    """
    from common.task_manager import TaskManager
    capture = TaskOutputCapture(output_queue, task_id)
    
    try:
        if task_id:
            TaskManager.update_task(task_id, status="running", current_step="开始解析")
        
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
        
        # 获取用户标识
        user_id = config_data.get('user_id', '')
        user_suffix = f"_{user_id}" if user_id and user_id != 'anonymous' else ""
        
        # 构建文件路径（从inputdata目录读取）
        online_file_path = os.path.join(online_input_dir, online_file)
        offline_file_path = os.path.join(online_input_dir, offline_file) if offline_file else None
        
        # 生成输出文件路径（保存到outputdata目录，包含用户标识）
        prefix_part = f"{output_prefix}_" if output_prefix else ""
        parsed_online_csv = os.path.join(online_output_dir, f"{prefix_part}{timestamp_suffix}{user_suffix}_解析后.csv")
        
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
        if task_id:
            TaskManager.update_task(task_id, status="failed", error_message=str(e))
            TaskManager.cleanup_completed_task_logs(task_id, keep_summary=False)
    except Exception as e:
        print(f"❌ 执行错误: {str(e)}")
        import traceback
        traceback.print_exc()
        if task_id:
            TaskManager.update_task(task_id, status="failed", error_message=str(e))
            TaskManager.cleanup_completed_task_logs(task_id, keep_summary=False)
    else:
        if task_id:
            TaskManager.update_task(task_id, status="completed", current_step="✅ 解析完成")
            TaskManager.cleanup_completed_task_logs(task_id, keep_summary=False)
    finally:
        # 恢复原始输出
        sys.stdout = capture.original_stdout
        sys.stderr = capture.original_stderr
        # 发送结束标记
        output_queue.put(None)  # None表示结束




def execute_online_comparison_flow(config_json_str: str, output_queue: Queue, task_id: str = None):
    """
    执行线上灰度落数对比流程（在单独线程中运行）
    
    Args:
        config_json_str: JSON配置字符串
        output_queue: 输出队列
        task_id: 任务ID（用于日志持久化）
    """
    import time
    start_time = time.time()
    
    from common.task_manager import TaskManager
    capture = TaskOutputCapture(output_queue, task_id)
    
    try:
        if task_id:
            TaskManager.update_task(task_id, status="running", current_step="开始执行")
        
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
        enable_tolerance = config_data.get("enable_tolerance", False)
        tolerance_value = config_data.get("tolerance_value", 0.000001)
        compare_common_features_only = config_data.get("compare_common_features_only", False)
        
        # 生成时间戳后缀
        now = datetime.now()
        timestamp_suffix = now.strftime("%m%d%H%M")
        
        # 获取用户标识
        user_id = config_data.get('user_id', '')
        user_suffix = f"_{user_id}" if user_id and user_id != 'anonymous' else ""
        
        # 构建文件路径（从inputdata目录读取）
        online_file_path = os.path.join(online_input_dir, online_file)
        offline_file_path = os.path.join(online_input_dir, offline_file)
        
        # 生成输出文件路径（保存到outputdata目录，包含用户标识）
        prefix_part = f"{output_prefix}_" if output_prefix else ""
        output_base_path = os.path.join(online_output_dir, f"{prefix_part}{timestamp_suffix}{user_suffix}_对比结果")
        
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
        print(f"启用容错对比: {enable_tolerance}")
        if enable_tolerance:
            print(f"容错值: {tolerance_value}")
        print(f"仅对比共有特征: {compare_common_features_only}")
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
            original_online_file_path=online_file_path,  # 传递原始线上文件路径
            enable_tolerance=enable_tolerance,
            tolerance_value=tolerance_value,
            compare_common_features_only=compare_common_features_only
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
        
        # 计算执行时长
        end_time = time.time()
        elapsed_time = end_time - start_time
        if elapsed_time >= 60:
            minutes = int(elapsed_time // 60)
            seconds = elapsed_time % 60
            time_str = f"{minutes}分{seconds:.1f}秒"
        else:
            time_str = f"{elapsed_time:.1f}秒"
        
        print(f"⏱️ 本次执行耗时: {time_str}")
        print(f"{'='*80}")
        
        if task_id:
            TaskManager.update_task(task_id, status="completed", current_step="✅ 执行完成")
            TaskManager.cleanup_completed_task_logs(task_id, keep_summary=False)
        
    except json.JSONDecodeError as e:
        print(f"❌ JSON解析错误: {str(e)}")
        if task_id:
            TaskManager.update_task(task_id, status="failed", error_message=str(e))
            TaskManager.cleanup_completed_task_logs(task_id, keep_summary=False)
    except Exception as e:
        print(f"❌ 执行错误: {str(e)}")
        import traceback
        traceback.print_exc()
        if task_id:
            TaskManager.update_task(task_id, status="failed", error_message=str(e))
            TaskManager.cleanup_completed_task_logs(task_id, keep_summary=False)
    finally:
        # 恢复原始输出
        sys.stdout = capture.original_stdout
        sys.stderr = capture.original_stderr
        # 发送结束标记
        output_queue.put(None)  # None表示结束




def execute_online_multi_scenario_flow(config_data: dict, output_queue: Queue, task_id: str = None):
    """
    执行线上灰度落数对比多场景流程（在单独线程中运行）
    
    Args:
        config_data: 配置字典（包含scenarios数组）
        output_queue: 输出队列
        task_id: 任务ID（用于日志持久化）
    """
    import time
    start_time = time.time()
    
    from common.task_manager import TaskManager
    capture = TaskOutputCapture(output_queue, task_id)
    
    try:
        if task_id:
            TaskManager.update_task(task_id, status="running", current_step="开始执行")
        
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
        
        # 获取用户标识
        user_id = config_data.get('user_id', '')
        user_suffix = f"_{user_id}" if user_id and user_id != 'anonymous' else ""
        
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
                enable_tolerance = scenario.get("enable_tolerance", False)
                tolerance_value = scenario.get("tolerance_value", 0.000001)
                compare_common_features_only = scenario.get("compare_common_features_only", False)
                
                # 构建文件路径（从inputdata目录读取）
                online_file_path = os.path.join(online_input_dir, online_file)
                offline_file_path = os.path.join(online_input_dir, offline_file)
                
                # 生成输出文件路径（保存到outputdata目录，包含用户标识）
                prefix_part = f"{output_prefix}_" if output_prefix else ""
                output_base_path = os.path.join(online_output_dir, f"{prefix_part}{timestamp_suffix}{user_suffix}_对比结果")
                
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
                    original_online_file_path=online_file_path,  # 传递原始线上文件路径
                    enable_tolerance=enable_tolerance,
                    tolerance_value=tolerance_value,
                    compare_common_features_only=compare_common_features_only
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
        
        # 计算执行时长
        end_time = time.time()
        elapsed_time = end_time - start_time
        if elapsed_time >= 60:
            minutes = int(elapsed_time // 60)
            seconds = elapsed_time % 60
            time_str = f"{minutes}分{seconds:.1f}秒"
        else:
            time_str = f"{elapsed_time:.1f}秒"
        
        print(f"⏱️ 本次执行耗时: {time_str}")
        print("="*60)
        
        if task_id:
            TaskManager.update_task(task_id, status="completed", current_step="✅ 执行完成")
            TaskManager.cleanup_completed_task_logs(task_id, keep_summary=False)
        
    except Exception as e:
        print(f"❌ 执行错误: {str(e)}")
        import traceback
        traceback.print_exc()
        if task_id:
            TaskManager.update_task(task_id, status="failed", error_message=str(e))
            TaskManager.cleanup_completed_task_logs(task_id, keep_summary=False)
    finally:
        # 恢复原始输出
        sys.stdout = capture.original_stdout
        sys.stderr = capture.original_stderr
        # 发送结束标记
        output_queue.put(None)  # None表示结束




@online_bp.route('/api/config/online/load', methods=['GET'])
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




@online_bp.route('/api/config/online/save', methods=['POST'])
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




@online_bp.route('/api/upload/online', methods=['POST'])
def upload_online_file():
    """上传CSV、XLSX或PKL文件（线上灰度落数对比）"""
    try:
        if 'file' not in request.files:
            return jsonify({'success': False, 'error': '没有文件'})
        
        file = request.files['file']
        if file.filename == '':
            return jsonify({'success': False, 'error': '文件名为空'})
        
        # 支持CSV、XLSX和PKL文件
        allowed_extensions = ['.csv', '.xlsx', '.xls', '.pkl']
        file_ext = os.path.splitext(file.filename)[1].lower()
        
        if file and file_ext in allowed_extensions:
            # 确保文件名安全
            filename = secure_filename(file.filename)
            file_path = os.path.join(online_input_dir, filename)
            
            # 保存文件
            file.save(file_path)
            
            # 如果是pkl文件，自动转换为csv
            if filename.endswith('.pkl'):
                from common.pkl_converter import convert_pkl_to_csv
                success, message, csv_path = convert_pkl_to_csv(file_path)
                if success:
                    csv_filename = os.path.basename(csv_path)
                    return jsonify({
                        'success': True,
                        'filename': csv_filename,
                        'original_filename': filename,
                        'converted': True,
                        'message': f'PKL文件已转换为CSV: {csv_filename}'
                    })
                else:
                    return jsonify({
                        'success': False,
                        'error': f'PKL文件转换失败: {message}'
                    })
            # 如果是xlsx文件，自动转换为csv
            elif filename.endswith('.xlsx') or filename.endswith('.xls'):
                from common.csv_tool import convert_xlsx_to_csv
                success, message, csv_path = convert_xlsx_to_csv(file_path)
                if success:
                    csv_filename = os.path.basename(csv_path)
                    return jsonify({
                        'success': True,
                        'filename': csv_filename,
                        'original_filename': filename,
                        'converted': True,
                        'message': f'XLSX文件已转换为CSV: {csv_filename}'
                    })
                else:
                    return jsonify({
                        'success': False,
                        'error': f'XLSX文件转换失败: {message}'
                    })
            else:
                return jsonify({
                    'success': True,
                    'filename': filename,
                    'converted': False,
                    'message': f'文件上传成功: {filename}'
                })
        else:
            return jsonify({'success': False, 'error': '只支持CSV、XLSX和PKL文件'})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})




@online_bp.route('/api/parse/online', methods=['POST'])
def parse_online():
    """只执行JSON解析（不执行对比）"""
    try:
        from common.task_manager import TaskManager
        
        config_data = request.json.get('config')
        user_id = request.json.get('user_id', 'anonymous')  # 获取用户标识
        
        if not config_data:
            return jsonify({'success': False, 'error': '配置数据为空'})

        # 如果是字典，转换为JSON字符串；如果已经是字符串，验证JSON格式
        if isinstance(config_data, dict):
            config_data['user_id'] = user_id
            config_json_str = json.dumps(config_data)
        else:
            # 验证JSON格式并注入用户标识
            parsed = json.loads(config_data)
            parsed['user_id'] = user_id
            config_json_str = json.dumps(parsed)

        task_id = TaskManager.create_task("线上JSON解析", "online_comparison", user_id=user_id)
        output_queue = Queue()

        thread = Thread(target=execute_online_parse_only, args=(config_json_str, output_queue, task_id))
        thread.daemon = True
        thread.start()
        
        def generate():
            """生成流式输出"""
            yield f"data: {json.dumps({'type': 'start', 'message': '开始解析JSON...', 'task_id': task_id})}\n\n"
            
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
            
            yield f"data: {json.dumps({'type': 'end', 'message': '解析完成', 'task_id': task_id})}\n\n"
        
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




@online_bp.route('/api/execute/online', methods=['POST'])
def execute_online():
    """执行线上灰度落数对比流程（支持单场景或多场景）"""
    try:
        from common.task_manager import TaskManager
        
        config_data = request.json.get('config')
        user_id = request.json.get('user_id', 'anonymous')  # 获取用户标识
        
        if not config_data:
            return jsonify({'success': False, 'error': '配置数据为空'})
        
        print(f"[DEBUG] 收到配置数据类型: {type(config_data)}")
        
        # 如果是字符串，先解析为字典
        if isinstance(config_data, str):
            try:
                config_data = json.loads(config_data)
                print(f"[DEBUG] 解析后配置数据类型: {type(config_data)}")
                print(f"[DEBUG] 配置数据keys: {config_data.keys() if isinstance(config_data, dict) else 'N/A'}")
            except json.JSONDecodeError as e:
                return jsonify({'success': False, 'error': f'配置JSON解析错误: {str(e)}'})
        
        # 注入用户标识
        if isinstance(config_data, dict):
            config_data['user_id'] = user_id
        
        # 判断是单场景还是多场景配置
        if isinstance(config_data, dict):
            if 'scenarios' in config_data:
                # 多场景模式
                scenarios = config_data.get('scenarios', [])
                enabled_scenarios = [s for s in scenarios if s.get('enabled', True)]
                
                print(f"[DEBUG] 多场景模式，启用场景数: {len(enabled_scenarios)}")
                
                if not enabled_scenarios:
                    return jsonify({'success': False, 'error': '没有启用的场景'})
                
                task_name = f"线上灰度落数对比 ({len(enabled_scenarios)}个场景)"
                task_id = TaskManager.create_task(task_name, "online_comparison", user_id=user_id)
                output_queue = Queue()
                
                thread = Thread(target=execute_online_multi_scenario_flow, args=(config_data, output_queue, task_id))
                thread.daemon = True
                thread.start()
            else:
                # 单场景模式（兼容旧格式）
                print(f"[DEBUG] 单场景模式")
                task_id = TaskManager.create_task("线上灰度落数对比", "online_comparison", user_id=user_id)
                config_json_str = json.dumps(config_data)
                output_queue = Queue()
                thread = Thread(target=execute_online_comparison_flow, args=(config_json_str, output_queue, task_id))
                thread.daemon = True
                thread.start()
        else:
            return jsonify({'success': False, 'error': '配置格式错误'})
        
        # 生成流式输出
        def generate():
            """生成流式输出"""
            yield f"data: {json.dumps({'type': 'start', 'message': '开始执行...', 'task_id': task_id})}\n\n"
            
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
            
            yield f"data: {json.dumps({'type': 'end', 'message': '执行完成', 'task_id': task_id})}\n\n"
        
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



