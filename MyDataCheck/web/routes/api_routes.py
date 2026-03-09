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
from web.utils import OutputCapture, TaskOutputCapture

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


def execute_comparison_flow(config_json_str: str, output_queue: Queue, task_id: str = None):
    """
    执行对比流程（在单独线程中运行）
    
    Args:
        config_json_str: JSON配置字符串
        output_queue: 输出队列
        task_id: 任务ID（用于停止控制和状态管理）
    """
    import time
    start_time = time.time()
    
    # 导入停止控制器和任务管理器
    from common.stop_controller import StopController
    from common.task_manager import TaskManager
    
    # 设置输出捕获（同时发送到队列和任务管理器）
    capture = TaskOutputCapture(output_queue, task_id)
    
    try:
        # 更新任务状态为运行中
        if task_id:
            TaskManager.update_task(task_id, status="running", current_step="开始执行")
        
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
            # 更新任务进度
            if task_id:
                TaskManager.update_task(
                    task_id, 
                    progress=i-1, 
                    total=len(enabled_scenarios),
                    current_step=f"执行场景 {i}/{len(enabled_scenarios)}: {scenario.get('name', '未命名')}"
                )
            
            # 检查是否应该停止
            if task_id and StopController.should_stop(task_id):
                print(f"\n⚠️  任务被用户停止 (场景 {i}/{len(enabled_scenarios)})")
                print(f"已完成: {success_count} 个成功, {fail_count} 个失败")
                if task_id:
                    TaskManager.update_task(task_id, status="stopped", progress=i-1)
                break
            
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
        
        # 计算执行时长
        end_time = time.time()
        elapsed_time = end_time - start_time
        if elapsed_time >= 60:
            minutes = int(elapsed_time // 60)
            seconds = elapsed_time % 60
            time_str = f"{minutes}分{seconds:.1f}秒"
        else:
            time_str = f"{elapsed_time:.1f}秒"
        
        print("")
        print("🎉 ✅ 任务执行完成！")
        print(f"📊 执行结果: 成功 {success_count} 个场景, 失败 {fail_count} 个场景")
        print(f"📁 输出目录: {api_output_dir}")
        print(f"⏱️ 本次执行耗时: {time_str}")
        print("")
        
        # 更新任务状态为完成
        if task_id:
            TaskManager.update_task(
                task_id, 
                status="completed", 
                progress=len(enabled_scenarios),
                current_step="✅ 执行完成"
            )
            # 执行结束后清除日志记录
            TaskManager.cleanup_completed_task_logs(task_id, keep_summary=False)
        
    except json.JSONDecodeError as e:
        print(f"❌ JSON解析错误: {str(e)}")
        if task_id:
            TaskManager.update_task(task_id, status="failed", error_message=f"JSON解析错误: {str(e)}")
    except Exception as e:
        print(f"❌ 执行错误: {str(e)}")
        import traceback
        traceback.print_exc()
        if task_id:
            TaskManager.update_task(task_id, status="failed", error_message=str(e))
    finally:
        # 清理任务
        if task_id:
            StopController.unregister_task(task_id)
        
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








@api_bp.route('/api/tasks', methods=['GET'])
def get_tasks():
    """获取所有任务列表"""
    try:
        from common.task_manager import TaskManager
        
        status = request.args.get('status')  # 可选：过滤状态
        user_id = request.args.get('user_id')  # 可选：用户标识
        tasks = TaskManager.get_all_tasks(status=status, user_id=user_id)
        
        return jsonify({
            'success': True,
            'tasks': tasks
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        })


@api_bp.route('/api/tasks/<task_id>', methods=['GET'])
def get_task(task_id):
    """获取指定任务的详细信息"""
    try:
        from common.task_manager import TaskManager
        
        task = TaskManager.get_task(task_id)
        if task is None:
            return jsonify({
                'success': False,
                'error': '任务不存在'
            })
        
        return jsonify({
            'success': True,
            'task': task
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        })


@api_bp.route('/api/tasks/<task_id>/logs', methods=['GET'])
def get_task_logs(task_id):
    """获取指定任务的日志"""
    try:
        from common.task_manager import TaskManager
        
        # 获取参数
        last_n = request.args.get('last_n', type=int)
        from_file = request.args.get('from_file', 'false').lower() == 'true'
        
        logs = TaskManager.get_logs(task_id, last_n=last_n, from_file=from_file)
        
        return jsonify({
            'success': True,
            'logs': logs,
            'count': len(logs)
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        })


@api_bp.route('/api/tasks/<task_id>/cleanup', methods=['POST'])
def cleanup_task_logs(task_id):
    """清理指定任务的日志"""
    try:
        from common.task_manager import TaskManager
        
        # 获取参数
        keep_summary = request.json.get('keep_summary', True) if request.json else True
        
        success = TaskManager.cleanup_completed_task_logs(task_id, keep_summary=keep_summary)
        
        if success:
            return jsonify({
                'success': True,
                'message': f'任务日志已清理 (保留摘要: {keep_summary})'
            })
        else:
            return jsonify({
                'success': False,
                'error': '任务未完成或不存在'
            })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        })


@api_bp.route('/api/tasks/cleanup-old', methods=['POST'])
def cleanup_old_tasks():
    """清理旧任务"""
    try:
        from common.task_manager import TaskManager
        
        # 获取参数
        days = request.json.get('days', 7) if request.json else 7
        status_filter = request.json.get('status_filter') if request.json else ['completed', 'failed', 'stopped']
        
        count = TaskManager.cleanup_old_tasks(days=days, status_filter=status_filter)
        
        return jsonify({
            'success': True,
            'message': f'已清理 {count} 个 {days} 天前的任务',
            'count': count
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        })


@api_bp.route('/api/upload', methods=['POST'])
def upload_file():
    """上传CSV、XLSX或PKL文件（接口数据对比）"""
    try:
        if 'file' not in request.files:
            return jsonify({'success': False, 'error': '没有文件'})
        
        file = request.files['file']
        if file.filename == '':
            return jsonify({'success': False, 'error': '文件名为空'})
        
        # 检查文件大小（1GB限制）
        file.seek(0, os.SEEK_END)
        file_size = file.tell()
        file.seek(0)  # 重置文件指针
        
        max_size = 1024 * 1024 * 1024  # 1GB
        if file_size > max_size:
            return jsonify({
                'success': False, 
                'error': f'文件过大: {file_size / 1024 / 1024:.2f} MB，最大支持 1 GB'
            })
        
        # 支持CSV、XLSX和PKL文件
        allowed_extensions = ['.csv', '.xlsx', '.xls', '.pkl']
        file_ext = os.path.splitext(file.filename)[1].lower()
        
        if file and file_ext in allowed_extensions:
            # 确保文件名安全
            filename = secure_filename(file.filename)
            file_path = os.path.join(api_input_dir, filename)
            
            # 保存文件
            try:
                file.save(file_path)
            except Exception as e:
                return jsonify({
                    'success': False, 
                    'error': f'文件保存失败: {str(e)}'
                })
            
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




@api_bp.route('/api/execute', methods=['POST'])
def execute():
    """执行对比流程（接口数据对比）"""
    try:
        # 导入停止控制器和任务管理器
        from common.stop_controller import StopController
        from common.task_manager import TaskManager
        
        config_json_str = request.json.get('config')
        user_id = request.json.get('user_id', 'anonymous')  # 获取用户标识
        
        if not config_json_str:
            return jsonify({'success': False, 'error': '配置数据为空'})

        # 验证JSON格式
        config_data = json.loads(config_json_str)
        
        # 将用户标识注入配置中，供后续流程使用
        config_data['user_id'] = user_id
        config_json_str = json.dumps(config_data)
        
        # 创建任务
        task_name = "接口数据对比"
        if config_data.get('scenarios'):
            enabled = [s for s in config_data['scenarios'] if s.get('enabled', True)]
            if enabled:
                task_name = f"接口数据对比 ({len(enabled)}个场景)"
        
        task_id = TaskManager.create_task(task_name, "api_comparison", user_id=user_id)
        
        # 注册停止控制
        StopController.register_task(task_name)

        # 创建输出队列
        output_queue = Queue()

        # 在单独线程中执行（传递task_id）
        thread = Thread(target=execute_comparison_flow, args=(config_json_str, output_queue, task_id))
        thread.daemon = True
        thread.start()
        
        def generate():
            """生成流式输出"""
            # 发送开始消息（包含task_id）
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



