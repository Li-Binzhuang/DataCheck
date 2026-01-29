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
from web.utils import OutputCapture

compare_bp = Blueprint('compare_routes', __name__)

# 为了兼容性，创建小写别名
data_comparison_dir = DATA_COMPARISON_DIR
data_comparison_job_dir = DATA_COMPARISON_JOB_DIR
compare_input_dir = COMPARE_INPUT_DIR
compare_output_dir = COMPARE_OUTPUT_DIR


def execute_compare_flow(config: dict, output_queue: Queue):
    """
    执行数据对比流程（在单独线程中运行）
    
    Args:
        config: 配置字典
        output_queue: 输出队列
    """
    # 设置输出捕获
    capture = OutputCapture(output_queue)
    
    try:
        # 重定向stdout和stderr
        sys.stdout = capture
        sys.stderr = capture
        
        print("[INFO] 开始执行数据对比...")
        print(f"[INFO] sql data: {config['file1']}")
        print(f"[INFO] 从库/灰度/线上文件: {config['file2']}")
        print(f"[INFO] sql data主键列: {config['key_column_1']}")
        print(f"[INFO] 从库/灰度/线上文件主键列: {config['key_column_2']}")
        print(f"[INFO] sql data特征起始列: {config['feature_start_1']}")
        print(f"[INFO] 从库/灰度/线上文件特征起始列: {config['feature_start_2']}")
        print(f"[INFO] 转换特征值为数值: {config.get('convert_feature_to_number', False)}")
        
        # 构建文件路径
        file1_path = os.path.join(compare_input_dir, config['file1'])
        file2_path = os.path.join(compare_input_dir, config['file2'])
        
        # 检查文件是否存在
        if not os.path.exists(file1_path):
            raise FileNotFoundError(f"sql data不存在: {file1_path}")
        if not os.path.exists(file2_path):
            raise FileNotFoundError(f"从库/灰度/线上文件不存在: {file2_path}")
        
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
        
        # 生成输出文件路径
        output_prefix = config.get('output_prefix', 'compare')
        output_base_path = os.path.join(compare_output_dir, f"{output_prefix}_{timestamp_suffix}")
        
        generate_comparison_reports_func(output_base_path, comparison_results)
        
        print(f"\n✅ 数据对比执行成功！")
        
    except Exception as e:
        print(f"❌ 执行错误: {str(e)}")
        import traceback
        traceback.print_exc()
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
        config = request.json.get('config')
        if not config:
            return jsonify({'success': False, 'error': '配置数据为空'})
        
        # 创建输出队列
        output_queue = Queue()
        
        # 在单独线程中执行
        thread = Thread(target=execute_compare_flow, args=(config, output_queue))
        thread.daemon = True
        thread.start()
        
        def generate():
            """生成流式输出"""
            yield f"data: {json.dumps({'type': 'start', 'message': '开始执行数据对比...'})}\n\n"
            
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



