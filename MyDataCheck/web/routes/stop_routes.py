#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
停止控制路由模块

功能说明:
    - 提供停止任务的API接口
    - 查询任务状态
    - 管理运行中的任务

API端点:
    POST /api/stop/task/<task_id> - 停止指定任务
    GET  /api/stop/tasks - 获取所有任务状态
    POST /api/stop/clear - 清理所有已完成的任务

作者: MyDataCheck Team
创建时间: 2026-01-29
"""

import sys
import os

# 添加项目根目录到路径
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../..'))

from flask import Blueprint, request, jsonify
from common.stop_controller import StopController

stop_bp = Blueprint('stop_routes', __name__)


@stop_bp.route('/api/stop/task/<task_id>', methods=['POST'])
def stop_task(task_id):
    """
    停止指定任务
    
    Args:
        task_id: 任务ID（URL参数）
    
    Returns:
        JSON: {
            'success': bool,
            'message': str,
            'task_id': str
        }
    
    示例:
        POST /api/stop/task/a1b2c3d4-e5f6-7890-abcd-ef1234567890
        
        Response:
        {
            "success": true,
            "message": "停止信号已发送",
            "task_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
        }
    """
    try:
        success = StopController.stop_task(task_id)
        
        if success:
            return jsonify({
                'success': True,
                'message': '停止信号已发送，任务将在下一个检查点停止',
                'task_id': task_id
            })
        else:
            return jsonify({
                'success': False,
                'message': '任务不存在或已完成',
                'task_id': task_id
            }), 404
    
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'停止任务失败: {str(e)}',
            'task_id': task_id
        }), 500


@stop_bp.route('/api/stop/tasks', methods=['GET'])
def get_all_tasks():
    """
    获取所有任务的状态
    
    Returns:
        JSON: {
            'success': bool,
            'tasks': [
                {
                    'task_id': str,
                    'status': str,  # 'running' 或 'stopped'
                    'short_id': str  # 前8位ID
                }
            ],
            'count': int
        }
    
    示例:
        GET /api/stop/tasks
        
        Response:
        {
            "success": true,
            "tasks": [
                {
                    "task_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
                    "status": "running",
                    "short_id": "a1b2c3d4"
                }
            ],
            "count": 1
        }
    """
    try:
        all_tasks = StopController.get_all_tasks()
        
        tasks_list = []
        for task_id, stopped in all_tasks.items():
            tasks_list.append({
                'task_id': task_id,
                'status': 'stopped' if stopped else 'running',
                'short_id': task_id[:8]
            })
        
        return jsonify({
            'success': True,
            'tasks': tasks_list,
            'count': len(tasks_list)
        })
    
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'获取任务列表失败: {str(e)}',
            'tasks': [],
            'count': 0
        }), 500


@stop_bp.route('/api/stop/clear', methods=['POST'])
def clear_completed_tasks():
    """
    清理所有已完成的任务
    
    Returns:
        JSON: {
            'success': bool,
            'message': str,
            'cleared_count': int
        }
    
    示例:
        POST /api/stop/clear
        
        Response:
        {
            "success": true,
            "message": "已清理2个已完成的任务",
            "cleared_count": 2
        }
    """
    try:
        # 获取所有任务
        all_tasks = StopController.get_all_tasks()
        
        # 清理已停止的任务
        cleared_count = 0
        for task_id, stopped in list(all_tasks.items()):
            if stopped:
                StopController.unregister_task(task_id)
                cleared_count += 1
        
        return jsonify({
            'success': True,
            'message': f'已清理{cleared_count}个已完成的任务',
            'cleared_count': cleared_count
        })
    
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'清理任务失败: {str(e)}',
            'cleared_count': 0
        }), 500


@stop_bp.route('/api/stop/task/<task_id>/status', methods=['GET'])
def get_task_status(task_id):
    """
    获取指定任务的状态
    
    Args:
        task_id: 任务ID（URL参数）
    
    Returns:
        JSON: {
            'success': bool,
            'task_id': str,
            'status': str,  # 'running', 'stopped', 或 'not_found'
            'should_stop': bool
        }
    
    示例:
        GET /api/stop/task/a1b2c3d4-e5f6-7890-abcd-ef1234567890/status
        
        Response:
        {
            "success": true,
            "task_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
            "status": "running",
            "should_stop": false
        }
    """
    try:
        all_tasks = StopController.get_all_tasks()
        
        if task_id not in all_tasks:
            return jsonify({
                'success': True,
                'task_id': task_id,
                'status': 'not_found',
                'should_stop': False
            }), 404
        
        stopped = all_tasks[task_id]
        
        return jsonify({
            'success': True,
            'task_id': task_id,
            'status': 'stopped' if stopped else 'running',
            'should_stop': stopped
        })
    
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'获取任务状态失败: {str(e)}',
            'task_id': task_id
        }), 500
