#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
数据对比路由
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
    API_INPUT_DIR, ONLINE_INPUT_DIR, COMPARE_INPUT_DIR, DATA_COMPARISON_DIR
)
from web.utils import OutputCapture, TaskOutputCapture

compare_bp = Blueprint('compare_routes', __name__)

# 为了兼容性，创建小写别名
data_comparison_dir = DATA_COMPARISON_DIR
data_comparison_job_dir = DATA_COMPARISON_JOB_DIR
compare_input_dir = COMPARE_INPUT_DIR
compare_output_dir = COMPARE_OUTPUT_DIR


def execute_compare_flow(config: dict, output_queue: Queue, task_id: str = None):
    """
    执行数据对比流程（在单独线程中运行）
    
    Args:
        config: 配置字典
        output_queue: 输出队列
        task_id: 任务ID（用于日志持久化，支持刷新页面加载日志）
    """
    import time
    start_time = time.time()
    
    from common.task_manager import TaskManager
    
    # 设置输出捕获（同时保存到TaskManager支持刷新加载日志）
    capture = TaskOutputCapture(output_queue, task_id)
    
    try:
        if task_id:
            TaskManager.update_task(task_id, status="running", current_step="开始执行")
        
        # 重定向stdout和stderr
        sys.stdout = capture
        sys.stderr = capture
        
        print("[INFO] 开始执行数据对比...")
        print(f"[INFO] 模型特征表: {config['file1']}")
        print(f"[INFO] 接口/灰度/从库特征表: {config['file2']}")
        print(f"[INFO] 模型特征表主键列: {config['key_column_1']}")
        print(f"[INFO] 接口/灰度/从库特征表主键列: {config['key_column_2']}")
        print(f"[INFO] 模型特征表特征起始列: {config['feature_start_1']}")
        print(f"[INFO] 接口/灰度/从库特征表特征起始列: {config['feature_start_2']}")
        print(f"[INFO] 转换特征值为数值: {config.get('convert_feature_to_number', False)}")
        print(f"[INFO] 输出全量数据: {config.get('output_full_data', False)}")
        
        # 构建文件路径 - 支持直接路径模式
        file1 = config['file1']
        file2 = config['file2']
        
        if file1.startswith('PATH:'):
            # 直接使用服务器路径
            file1_path = file1[5:]  # 去掉 'PATH:' 前缀
            if not os.path.isabs(file1_path):
                # 相对路径，相对于 compare_input_dir
                file1_path = os.path.join(compare_input_dir, file1_path)
        else:
            file1_path = os.path.join(compare_input_dir, file1)
        
        if file2.startswith('PATH:'):
            file2_path = file2[5:]
            if not os.path.isabs(file2_path):
                file2_path = os.path.join(compare_input_dir, file2_path)
        else:
            file2_path = os.path.join(compare_input_dir, file2)
        
        # 检查文件是否存在
        if not os.path.exists(file1_path):
            raise FileNotFoundError(f"模型特征表不存在: {file1_path}")
        if not os.path.exists(file2_path):
            raise FileNotFoundError(f"接口/灰度/从库特征表不存在: {file2_path}")
        
        print(f"[INFO] 实际文件路径1: {file1_path}")
        print(f"[INFO] 实际文件路径2: {file2_path}")
        
        # 动态导入数据对比模块
        data_comparator_path = os.path.join(data_comparison_job_dir, "data_comparator.py")
        spec_comparator = importlib.util.spec_from_file_location("data_comparator", data_comparator_path)
        data_comparator_module = importlib.util.module_from_spec(spec_comparator)
        spec_comparator.loader.exec_module(data_comparator_module)
        compare_two_files_func = data_comparator_module.compare_two_files
        
        # 执行对比
        comparison_results = compare_two_files_func(
            file1_path,
            file2_path,
            config['key_column_1'],
            config['key_column_2'],
            config['feature_start_1'],
            config['feature_start_2'],
            config.get('convert_feature_to_number', True)
        )
        
        # 生成报告
        print("\n[INFO] 正在生成报告...")
        
        # 动态导入报告生成模块
        report_generator_path = os.path.join(data_comparison_job_dir, "report_generator.py")
        spec_report = importlib.util.spec_from_file_location("report_generator", report_generator_path)
        report_generator_module = importlib.util.module_from_spec(spec_report)
        spec_report.loader.exec_module(report_generator_module)
        generate_comparison_reports_func = report_generator_module.generate_comparison_reports
        
        # 生成时间戳后缀
        now = datetime.now()
        timestamp_suffix = now.strftime("%m%d%H%M")
        
        # 获取用户标识
        user_id = config.get('user_id', '')
        user_suffix = f"_{user_id}" if user_id and user_id != 'anonymous' else ""
        
        # 生成输出文件路径（包含用户标识）
        output_prefix = config.get('output_prefix', 'compare')
        output_base_path = os.path.join(compare_output_dir, f"{output_prefix}_{timestamp_suffix}{user_suffix}")
        
        # 传递输出全量数据的配置
        output_full_data = config.get('output_full_data', False)
        generate_comparison_reports_func(output_base_path, comparison_results, output_full_data)
        
        # 计算执行时长
        end_time = time.time()
        elapsed_time = end_time - start_time
        if elapsed_time >= 60:
            minutes = int(elapsed_time // 60)
            seconds = elapsed_time % 60
            time_str = f"{minutes}分{seconds:.1f}秒"
        else:
            time_str = f"{elapsed_time:.1f}秒"
        
        print(f"\n✅ 数据对比执行成功！")
        print(f"⏱️ 本次执行耗时: {time_str}")
        
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
        output_queue.put(None)




@compare_bp.route('/api/compare/upload', methods=['POST'])
def upload_compare_file():
    """上传数据对比文件（CSV或XLSX）"""
    try:
        if 'file' not in request.files:
            return jsonify({'success': False, 'error': '没有文件'})
        
        file = request.files['file']
        file_num = request.form.get('file_num', '1')
        
        if file.filename == '':
            return jsonify({'success': False, 'error': '文件名为空'})
        
        # 支持CSV和XLSX文件
        if file and (file.filename.endswith('.csv') or file.filename.endswith('.xlsx')):
            # 确保文件名安全
            filename = secure_filename(file.filename)
            # 添加文件编号前缀
            filename = f"file{file_num}_{filename}"
            file_path = os.path.join(compare_input_dir, filename)
            
            # 保存文件
            file.save(file_path)
            
            return jsonify({
                'success': True,
                'filename': filename,
                'message': f'文件上传成功: {filename}'
            })
        else:
            return jsonify({'success': False, 'error': '只支持CSV和XLSX文件'})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})




@compare_bp.route('/api/compare/execute', methods=['POST'])
def execute_compare():
    """执行数据对比"""
    try:
        from common.task_manager import TaskManager
        
        config = request.json.get('config')
        user_id = request.json.get('user_id', 'anonymous')  # 获取用户标识
        
        if not config:
            return jsonify({'success': False, 'error': '配置数据为空'})
        
        # 将用户标识注入配置
        config['user_id'] = user_id
        
        # 创建任务（支持刷新页面加载日志）
        task_name = "数据对比"
        if config.get('output_prefix'):
            task_name = f"数据对比 ({config['output_prefix']})"
        task_id = TaskManager.create_task(task_name, "data_comparison", user_id=user_id)
        
        # 创建输出队列
        output_queue = Queue()
        
        # 在单独线程中执行
        thread = Thread(target=execute_compare_flow, args=(config, output_queue, task_id))
        thread.daemon = True
        thread.start()
        
        def generate():
            """生成流式输出"""
            yield f"data: {json.dumps({'type': 'start', 'message': '开始执行数据对比...', 'task_id': task_id})}\n\n"
            
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
        
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})




@compare_bp.route('/api/compare/config/save', methods=['POST'])
def save_compare_config():
    """保存数据对比配置"""
    try:
        print("[DEBUG] 收到保存配置请求")
        
        config_data = request.json
        if not config_data:
            print("[ERROR] 配置数据为空")
            return jsonify({'success': False, 'error': '配置数据为空'})
        
        print(f"[DEBUG] 配置数据: {json.dumps(config_data, ensure_ascii=False, indent=2)}")
        
        # 配置文件路径
        config_path = os.path.join(data_comparison_dir, "config.json")
        print(f"[DEBUG] 配置文件路径: {config_path}")
        
        # 动态导入配置管理模块
        config_manager_path = os.path.join(data_comparison_job_dir, "config_manager.py")
        print(f"[DEBUG] 配置管理模块路径: {config_manager_path}")
        
        spec_config = importlib.util.spec_from_file_location("config_manager", config_manager_path)
        config_manager_module = importlib.util.module_from_spec(spec_config)
        spec_config.loader.exec_module(config_manager_module)
        save_config_func = config_manager_module.save_config
        
        # 保存配置
        scenarios = config_data.get('scenarios', [])
        global_config = config_data.get('global_config', {})
        
        print(f"[DEBUG] 场景数量: {len(scenarios)}")
        print(f"[DEBUG] 全局配置: {global_config}")
        
        save_config_func(config_path, scenarios, global_config)
        
        print("[SUCCESS] 配置保存成功")
        return jsonify({'success': True, 'message': '✅ 配置保存成功'})
    except Exception as e:
        print(f"[ERROR] 配置保存失败: {str(e)}")
        import traceback
        traceback.print_exc()
        return jsonify({'success': False, 'error': str(e)})




@compare_bp.route('/api/compare/config/load', methods=['GET'])
def load_compare_config():
    """加载数据对比配置"""
    try:
        # 配置文件路径
        config_path = os.path.join(data_comparison_dir, "config.json")
        
        # 动态导入配置管理模块
        config_manager_path = os.path.join(data_comparison_job_dir, "config_manager.py")
        spec_config = importlib.util.spec_from_file_location("config_manager", config_manager_path)
        config_manager_module = importlib.util.module_from_spec(spec_config)
        spec_config.loader.exec_module(config_manager_module)
        load_config_func = config_manager_module.load_config
        
        # 加载配置
        config = load_config_func(config_path)
        
        return jsonify({'success': True, 'config': config})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})


# ========== 小数位数处理相关路由 ==========

@compare_bp.route('/api/compare/decimal/upload', methods=['POST'])
def upload_decimal_file():
    """上传差异明细文件"""
    try:
        if 'file' not in request.files:
            return jsonify({'success': False, 'error': '没有文件'})
        
        file = request.files['file']
        
        if file.filename == '':
            return jsonify({'success': False, 'error': '文件名为空'})
        
        if file and file.filename.endswith('.csv'):
            filename = secure_filename(file.filename)
            filename = f"decimal_{filename}"
            file_path = os.path.join(compare_input_dir, filename)
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


def get_decimal_places(value):
    """
    获取数值的小数位数
    
    Args:
        value: 数值（可以是字符串或数字）
    
    Returns:
        int: 小数位数
    """
    try:
        str_val = str(value).strip()
        if '.' in str_val:
            # 去除末尾的0
            decimal_part = str_val.split('.')[1].rstrip('0')
            return len(decimal_part) if decimal_part else 0
        return 0
    except:
        return 0


def process_decimal_value(api_value, model_value, method='round'):
    """
    根据模型特征值的小数位数处理接口值
    
    Args:
        api_value: 接口/灰度/从库值
        model_value: 模型特征值
        method: 处理方式 ('none' 不处理, 'round' 四舍五入, 'double_round' 双精度四舍五入, 'truncate' 截取, 'ceil' 向上取整)
    
    Returns:
        处理后的值
    """
    import math
    
    try:
        api_float = float(api_value)
        
        if method == 'none':
            # 不处理小数，直接返回原值
            return api_float
        
        model_float = float(model_value)
        
        # 获取模型特征值的小数位数
        decimal_places = get_decimal_places(model_value)
        
        if method == 'round':
            # 四舍五入
            return round(api_float, decimal_places)
        elif method == 'double_round':
            # 双精度四舍五入：先多保留一位小数四舍五入，再按目标位数四舍五入
            # 这样可以减少浮点精度误差
            first_round = round(api_float, decimal_places + 1)
            return round(first_round, decimal_places)
        elif method == 'truncate':
            # 截取
            if decimal_places == 0:
                return math.trunc(api_float)
            else:
                factor = 10 ** decimal_places
                return math.trunc(api_float * factor) / factor
        elif method == 'ceil':
            # 向上取整
            if decimal_places == 0:
                return math.ceil(api_float)
            else:
                factor = 10 ** decimal_places
                return math.ceil(api_float * factor) / factor
        else:
            return api_float
    except (ValueError, TypeError):
        return api_value


def is_diff_ignorable(model_value, diff_value, compare_mode='exact', tolerance=0.01):
    """
    判断差异是否可忽略
    
    Args:
        model_value: 模型特征值（用于获取小数位数）
        diff_value: 差异值
        compare_mode: 对比方式 ('exact' 精确对比, 'tolerance' 容差对比, 'last_digit' 最后一位差1不计异常, 'last_digit_2' 最后一位差2不计异常)
        tolerance: 容差值，差异绝对值在此范围内的不计为差异
    
    Returns:
        bool: True表示差异可忽略（不计为差异）
    """
    try:
        if diff_value is None:
            return False
        
        diff_float = float(diff_value)
        
        if compare_mode == 'exact':
            # 精确对比：差异为0才可忽略
            return diff_float == 0
        elif compare_mode == 'tolerance':
            # 容差对比：差异绝对值在容差范围内可忽略
            return abs(diff_float) <= tolerance
        elif compare_mode == 'last_digit':
            # 最后一位差1不计异常：根据模型特征值的小数位数，最后一位允许±1误差
            if diff_float == 0:
                return True
            
            decimal_places = get_decimal_places(model_value)
            if decimal_places == 0:
                # 整数情况，允许±1
                return abs(diff_float) <= 1
            else:
                # 小数情况，最后一位允许±1
                last_digit_tolerance = 1 / (10 ** decimal_places)
                return abs(diff_float) <= last_digit_tolerance + 1e-10
        elif compare_mode == 'last_digit_2':
            # 最后一位差2不计异常：根据模型特征值的小数位数，最后一位允许±2误差
            if diff_float == 0:
                return True
            
            decimal_places = get_decimal_places(model_value)
            if decimal_places == 0:
                # 整数情况，允许±2
                return abs(diff_float) <= 2
            else:
                # 小数情况，最后一位允许±2
                last_digit_tolerance = 2 / (10 ** decimal_places)
                return abs(diff_float) <= last_digit_tolerance + 1e-10
        else:
            return diff_float == 0
    except (ValueError, TypeError):
        return False


def execute_decimal_process_flow(config: dict, output_queue: Queue, task_id: str = None):
    """
    执行小数位数处理流程
    
    Args:
        config: 配置字典
        output_queue: 输出队列
        task_id: 任务ID（用于日志持久化）
    """
    import pandas as pd
    import time
    start_time = time.time()
    
    from common.task_manager import TaskManager
    capture = TaskOutputCapture(output_queue, task_id)
    
    try:
        if task_id:
            TaskManager.update_task(task_id, status="running", current_step="开始执行")
        
        sys.stdout = capture
        sys.stderr = capture
        
        print("[INFO] 开始执行小数位数处理...")
        print(f"[INFO] 差异明细文件: {config['file']}")
        print(f"[INFO] 小数处理方式: {'不处理小数' if config['method'] == 'none' else '四舍五入' if config['method'] == 'round' else '双精度四舍五入' if config['method'] == 'double_round' else '截取' if config['method'] == 'truncate' else '向上取整'}")
        compare_mode = config.get('compare_mode', 'exact')
        tolerance = config.get('tolerance', 0.01)
        if compare_mode == 'exact':
            print(f"[INFO] 对比方式: 精确对比")
        elif compare_mode == 'tolerance':
            print(f"[INFO] 对比方式: 容差对比 (容差值: {tolerance})")
        elif compare_mode == 'last_digit':
            print(f"[INFO] 对比方式: 最后一位差1不计异常")
        else:
            print(f"[INFO] 对比方式: 最后一位差2不计异常")
        
        # 构建文件路径 - 支持直接路径模式
        file_input = config['file']
        if file_input.startswith('PATH:'):
            # 直接使用服务器路径
            file_path = file_input[5:]  # 去掉 'PATH:' 前缀
            if not os.path.isabs(file_path):
                # 相对路径，相对于 compare_input_dir
                file_path = os.path.join(compare_input_dir, file_path)
        else:
            file_path = os.path.join(compare_input_dir, file_input)
        
        print(f"[INFO] 实际文件路径: {file_path}")
        
        if not os.path.exists(file_path):
            raise FileNotFoundError(f"文件不存在: {file_path}")
        
        # 读取CSV文件
        print("[INFO] 正在读取文件...")
        df = pd.read_csv(file_path)
        print(f"[INFO] 读取到 {len(df)} 条记录")
        
        # 查找必要的列
        # 列名可能为：模型特征表值 或 模型特征样本值、接口/灰度/从库值
        model_col = None
        api_col = None
        
        for col in df.columns:
            if ('模型特征' in col) and ('值' in col) and ('处理' not in col) and ('差异' not in col):
                model_col = col
            elif ('接口' in col or '灰度' in col or '从库' in col) and '值' in col and '处理' not in col and '差异' not in col:
                api_col = col
        
        if model_col is None:
            raise ValueError("未找到'模型特征样本值'或'模型特征表值'列，请确认文件格式")
        if api_col is None:
            raise ValueError("未找到'接口/灰度/从库值'列，请确认文件格式")
        
        print(f"[INFO] 模型特征值列: {model_col}")
        print(f"[INFO] 接口值列: {api_col}")
        
        # 新增列名
        processed_col = f"{api_col}-处理小数"
        diff_col = "差异值"
        
        # 处理每一行
        print("[INFO] 正在处理小数位数...")
        processed_values = []
        diff_values = []
        
        for idx, row in df.iterrows():
            model_val = row[model_col]
            api_val = row[api_col]
            
            # 处理接口值
            processed_val = process_decimal_value(api_val, model_val, config['method'])
            processed_values.append(processed_val)
            
            # 计算差异值
            try:
                diff = float(model_val) - float(processed_val)
                # 保留合理的小数位数，避免浮点数精度问题
                diff = round(diff, 10)
                diff_values.append(diff)
            except (ValueError, TypeError):
                diff_values.append(None)
            
            if (idx + 1) % 1000 == 0:
                print(f"[INFO] 已处理 {idx + 1} 条记录...")
        
        # 添加新列
        df[processed_col] = processed_values
        df[diff_col] = diff_values
        
        print(f"[INFO] 处理完成，共 {len(df)} 条记录")
        
        # 根据对比方式筛选差异记录
        if compare_mode == 'exact':
            # 精确对比：差异不为0的记录
            df_diff = df[df[diff_col] != 0].copy()
            print(f"[INFO] 精确对比 - 差异不为0的记录: {len(df_diff)} 条")
        else:
            # 容差对比或最后一位差1不计异常
            diff_mask = []
            for idx, row in df.iterrows():
                model_val = row[model_col]
                diff_val = row[diff_col]
                is_ignorable = is_diff_ignorable(model_val, diff_val, compare_mode, tolerance)
                diff_mask.append(not is_ignorable)
            
            df_diff = df[diff_mask].copy()
            if compare_mode == 'tolerance':
                print(f"[INFO] 容差对比 (容差={tolerance}) - 仍有差异的记录: {len(df_diff)} 条")
            elif compare_mode == 'last_digit':
                print(f"[INFO] 最后一位差1不计异常 - 仍有差异的记录: {len(df_diff)} 条")
            else:
                print(f"[INFO] 最后一位差2不计异常 - 仍有差异的记录: {len(df_diff)} 条")
        
        # 生成输出文件
        now = datetime.now()
        timestamp_suffix = now.strftime("%m%d%H%M")
        output_prefix = config.get('output_prefix', 'decimal_processed')
        output_full_data = config.get('output_full_data', False)
        
        # 获取用户标识
        user_id = config.get('user_id', '')
        user_suffix = f"_{user_id}" if user_id and user_id != 'anonymous' else ""
        
        # 输出完整处理结果（仅在配置开启时）
        if output_full_data:
            full_output_path = os.path.join(compare_output_dir, f"{output_prefix}_full_{timestamp_suffix}{user_suffix}.csv")
            df.to_csv(full_output_path, index=False, encoding='utf-8-sig')
            print(f"✅ 完整处理结果已保存: {full_output_path}")
        else:
            print(f"[INFO] 跳过全量处理结果文件生成（未勾选输出选项）")
        
        # 输出差异记录
        if len(df_diff) > 0:
            diff_output_path = os.path.join(compare_output_dir, f"{output_prefix}_diff_{timestamp_suffix}{user_suffix}.csv")
            df_diff.to_csv(diff_output_path, index=False, encoding='utf-8-sig')
            print(f"✅ 差异记录已保存: {diff_output_path}")
        else:
            print("✅ 没有差异记录")
        
        # 计算执行时长
        end_time = time.time()
        elapsed_time = end_time - start_time
        if elapsed_time >= 60:
            minutes = int(elapsed_time // 60)
            seconds = elapsed_time % 60
            time_str = f"{minutes}分{seconds:.1f}秒"
        else:
            time_str = f"{elapsed_time:.1f}秒"
        
        print(f"\n✅ 小数位数处理完成！")
        print(f"⏱️ 本次执行耗时: {time_str}")
        
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
        sys.stdout = capture.original_stdout
        sys.stderr = capture.original_stderr
        output_queue.put(None)


@compare_bp.route('/api/compare/decimal/execute', methods=['POST'])
def execute_decimal_process():
    """执行小数位数处理"""
    try:
        from common.task_manager import TaskManager
        
        config = request.json.get('config')
        user_id = request.json.get('user_id', 'anonymous')  # 获取用户标识
        
        if not config:
            return jsonify({'success': False, 'error': '配置数据为空'})
        
        # 将用户标识注入配置
        config['user_id'] = user_id
        
        task_id = TaskManager.create_task("小数位数处理", "decimal_process", user_id=user_id)
        output_queue = Queue()
        
        thread = Thread(target=execute_decimal_process_flow, args=(config, output_queue, task_id))
        thread.daemon = True
        thread.start()
        
        def generate():
            yield f"data: {json.dumps({'type': 'start', 'message': '开始执行小数位数处理...', 'task_id': task_id})}\n\n"
            
            while True:
                try:
                    try:
                        line = output_queue.get(timeout=1)
                    except:
                        if not thread.is_alive():
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
                    
                    if line is None:
                        break
                    
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
        
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})
