#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
接口数据对比路由
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
    API_INPUT_DIR, ONLINE_INPUT_DIR, COMPARE_INPUT_DIR
)
from web.utils import OutputCapture

api_bp = Blueprint('api_routes', __name__)

# 为了兼容性，创建小写别名
script_dir = os.path.join(SCRIPT_DIR, "api_comparison")  # 指向api_comparison目录
api_input_dir = API_INPUT_DIR
api_output_dir = API_OUTPUT_DIR

# 动态导入配置管理模块
config_module_path = os.path.join(JOB_DIR, "config_manager.py")
spec_config = importlib.util.spec_from_file_location("config_manager", config_module_path)
config_module = importlib.util.module_from_spec(spec_config)
spec_config.loader.exec_module(config_module)
cleanup_column_config = config_module.cleanup_column_config

# 动态导入流程执行器模块
executor_module_path = os.path.join(JOB_DIR, "process_executor.py")
spec_executor = importlib.util.spec_from_file_location("process_executor", executor_module_path)
executor_module = importlib.util.module_from_spec(spec_executor)
spec_executor.loader.exec_module(executor_module)
execute_single_scenario = executor_module.execute_single_scenario


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
            
            if execute_single_scenario(scenario, global_config, script_dir, timestamp_suffix, api_output_dir, api_input_dir, config_data):
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




@api_bp.route('/api/config/load', methods=['GET'])
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




@api_bp.route('/api/config/save', methods=['POST'])
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




@api_bp.route('/api/upload', methods=['POST'])
def upload_file():
    """上传CSV或PKL文件（接口数据对比）"""
    try:
        if 'file' not in request.files:
            return jsonify({'success': False, 'error': '没有文件'})
        
        file = request.files['file']
        if file.filename == '':
            return jsonify({'success': False, 'error': '文件名为空'})
        
        # 检查文件大小（500MB限制）
        file.seek(0, os.SEEK_END)
        file_size = file.tell()
        file.seek(0)  # 重置文件指针
        
        max_size = 1024 * 1024 * 1024  # 1GB
        if file_size > max_size:
            return jsonify({
                'success': False, 
                'error': f'文件过大: {file_size / 1024 / 1024:.2f} MB，最大支持 1 GB'
            })
        
        # 支持CSV和PKL文件
        if file and (file.filename.endswith('.csv') or file.filename.endswith('.pkl')):
            # 确保文件名安全
            filename = secure_filename(file.filename)
            file_path = os.path.join(api_input_dir, filename)
            
            # 保存文件（显示进度）
            try:
                file.save(file_path)
            except Exception as e:
                return jsonify({
                    'success': False, 
                    'error': f'文件保存失败: {str(e)}'
                })
            
            # 如果是pkl文件，自动转换为csv
            if filename.endswith('.pkl'):
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
            else:
                return jsonify({
                    'success': True,
                    'filename': filename,
                    'converted': False,
                    'message': f'文件上传成功: {filename}'
                })
        else:
            return jsonify({'success': False, 'error': '只支持CSV和PKL文件'})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})




@api_bp.route('/api/execute', methods=['POST'])
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



