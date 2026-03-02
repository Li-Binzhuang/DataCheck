#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
跑数模块路由
"""

import os
import sys
import json
from datetime import datetime
from threading import Thread
from queue import Queue

from flask import Blueprint, request, jsonify, Response, stream_with_context
from werkzeug.utils import secure_filename

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

from web.config import SCRIPT_DIR
from web.utils import OutputCapture, TaskOutputCapture

batch_run_bp = Blueprint('batch_run_routes', __name__)

# 目录配置
BATCH_RUN_DIR = os.path.join(SCRIPT_DIR, "batch_run")
BATCH_RUN_INPUT_DIR = os.path.join(SCRIPT_DIR, "inputdata", "batch_run")
BATCH_RUN_OUTPUT_DIR = os.path.join(SCRIPT_DIR, "outputdata", "batch_run")

# 确保目录存在
os.makedirs(BATCH_RUN_INPUT_DIR, exist_ok=True)
os.makedirs(BATCH_RUN_OUTPUT_DIR, exist_ok=True)


def execute_batch_run(config: dict, output_queue: Queue, task_id: str = None):
    """执行跑数任务"""
    import time
    start_time = time.time()
    
    from common.task_manager import TaskManager
    capture = TaskOutputCapture(output_queue, task_id)
    
    try:
        if task_id:
            TaskManager.update_task(task_id, status="running", current_step="开始执行")
        
        sys.stdout = capture
        sys.stderr = capture
        
        from batch_run.job.batch_runner import BatchRunner
        
        api_url = config.get("api_url", "")
        input_file = config.get("input_csv_file", "")
        output_prefix = config.get("output_file_prefix", "batch_run")
        thread_count = config.get("thread_count", 50)
        timeout = config.get("timeout", 30)
        api_params = config.get("api_params", [])
        keep_columns = config.get("keep_columns")  # None表示保留所有列
        
        if not api_url:
            print("❌ 错误: 接口URL不能为空")
            return
        
        if not input_file:
            print("❌ 错误: 输入文件不能为空")
            return
        
        # 构建文件路径
        input_path = os.path.join(BATCH_RUN_INPUT_DIR, input_file)
        if not os.path.exists(input_path):
            print(f"❌ 错误: 输入文件不存在: {input_file}")
            return
        
        # 获取用户标识
        user_id = config.get('user_id', '')
        user_suffix = f"_{user_id}" if user_id and user_id != 'anonymous' else ""
        
        timestamp = datetime.now().strftime("%m%d%H%M")
        output_file = f"{output_prefix}_{timestamp}{user_suffix}.csv"
        output_path = os.path.join(BATCH_RUN_OUTPUT_DIR, output_file)
        
        print("=" * 60)
        print("🚀 开始跑数任务")
        print("=" * 60)
        
        runner = BatchRunner(
            api_url=api_url,
            thread_count=thread_count,
            timeout=timeout,
            api_params=api_params,
            keep_columns=keep_columns
        )
        
        result = runner.run(input_path, output_path)
        
        print()
        print("=" * 60)
        print("🎉 ✅ 跑数任务完成！")
        print(f"📊 结果: 成功 {result['success']} 条, 失败 {result['errors']} 条")
        print(f"📋 特征数量: {result['features_count']}")
        print(f"📁 输出文件: {output_file}")
        
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
        print("=" * 60)
        
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


@batch_run_bp.route('/api/batch-run/config/load', methods=['GET'])
def load_batch_run_config():
    """加载跑数配置"""
    config_path = os.path.join(BATCH_RUN_DIR, "config.json")
    try:
        if os.path.exists(config_path):
            with open(config_path, 'r', encoding='utf-8') as f:
                config = json.load(f)
            return jsonify({'success': True, 'config': config})
        return jsonify({'success': True, 'config': {}})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})


@batch_run_bp.route('/api/batch-run/config/save', methods=['POST'])
def save_batch_run_config():
    """保存跑数配置"""
    try:
        config = request.json.get('config', {})
        config_path = os.path.join(BATCH_RUN_DIR, "config.json")
        
        with open(config_path, 'w', encoding='utf-8') as f:
            json.dump(config, f, ensure_ascii=False, indent=2)
        
        return jsonify({'success': True})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})


@batch_run_bp.route('/api/batch-run/upload', methods=['POST'])
def upload_batch_run_file():
    """上传CSV文件"""
    try:
        if 'file' not in request.files:
            return jsonify({'success': False, 'error': '没有文件'})
        
        file = request.files['file']
        if file.filename == '':
            return jsonify({'success': False, 'error': '文件名为空'})
        
        if file and file.filename.endswith('.csv'):
            filename = secure_filename(file.filename)
            file_path = os.path.join(BATCH_RUN_INPUT_DIR, filename)
            file.save(file_path)
            return jsonify({'success': True, 'filename': filename})
        
        return jsonify({'success': False, 'error': '只支持CSV文件'})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})


@batch_run_bp.route('/api/batch-run/execute', methods=['POST'])
def execute_batch_run_api():
    """执行跑数任务"""
    try:
        from common.task_manager import TaskManager
        
        config = request.json.get('config', {})
        user_id = request.json.get('user_id', 'anonymous')  # 获取用户标识
        
        if not config:
            return jsonify({'success': False, 'error': '配置为空'})
        
        # 将用户标识注入配置
        config['user_id'] = user_id
        
        task_id = TaskManager.create_task("跑数任务", "batch_run", user_id=user_id)
        output_queue = Queue()
        thread = Thread(target=execute_batch_run, args=(config, output_queue, task_id))
        thread.daemon = True
        thread.start()
        
        def generate():
            try:
                yield f"data: {json.dumps({'type': 'start', 'message': '开始执行...', 'task_id': task_id})}\n\n"
                
                while True:
                    try:
                        line = output_queue.get(timeout=0.5)
                        if line is None:
                            break
                        yield f"data: {json.dumps({'type': 'output', 'message': str(line)})}\n\n"
                    except Exception:
                        # 队列超时，检查线程状态
                        if not thread.is_alive():
                            # 线程结束，读取剩余输出
                            while True:
                                try:
                                    item = output_queue.get_nowait()
                                    if item is None:
                                        break
                                    yield f"data: {json.dumps({'type': 'output', 'message': str(item)})}\n\n"
                                except Exception:
                                    break
                            break
                
                yield f"data: {json.dumps({'type': 'end', 'message': '执行完成', 'task_id': task_id})}\n\n"
            except GeneratorExit:
                # 客户端断开连接，正常退出
                pass
            except Exception as e:
                yield f"data: {json.dumps({'type': 'error', 'message': str(e)})}\n\n"
        
        return Response(
            stream_with_context(generate()),
            mimetype='text/event-stream',
            headers={
                'Cache-Control': 'no-cache',
                'X-Accel-Buffering': 'no',
                'Connection': 'keep-alive'
            }
        )
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})


@batch_run_bp.route('/api/batch-run/files', methods=['GET'])
def list_batch_run_files():
    """列出输入目录中的CSV文件"""
    try:
        files = []
        if os.path.exists(BATCH_RUN_INPUT_DIR):
            for f in os.listdir(BATCH_RUN_INPUT_DIR):
                if f.endswith('.csv'):
                    path = os.path.join(BATCH_RUN_INPUT_DIR, f)
                    size = os.path.getsize(path)
                    files.append({'name': f, 'size': size})
        return jsonify({'success': True, 'files': files})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})
