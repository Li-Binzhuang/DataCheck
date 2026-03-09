#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
文件下载路由

功能：提供CSV文件下载接口，支持自动下载任务输出文件
"""

import os
import glob
from datetime import datetime
from flask import Blueprint, request, jsonify, send_file, abort

from web.config import API_OUTPUT_DIR, ONLINE_OUTPUT_DIR, COMPARE_OUTPUT_DIR

download_bp = Blueprint('download_routes', __name__)

# 获取项目根目录
SCRIPT_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BATCH_RUN_OUTPUT_DIR = os.path.join(SCRIPT_DIR, "outputdata", "batch_run")
MERGE_CSV_OUTPUT_DIR = os.path.join(SCRIPT_DIR, "outputdata", "merge_csv")

# 输出目录映射
OUTPUT_DIRS = {
    'api_comparison': API_OUTPUT_DIR,
    'online_comparison': ONLINE_OUTPUT_DIR,
    'data_comparison': COMPARE_OUTPUT_DIR,
    'batch_run': BATCH_RUN_OUTPUT_DIR,
    'merge_csv': MERGE_CSV_OUTPUT_DIR,
}


@download_bp.route('/api/download/<path:filename>')
def download_file(filename):
    """
    下载指定文件
    
    Args:
        filename: 文件名（相对于outputdata目录）
    
    Query params:
        module: 模块名 (api_comparison, online_comparison, data_comparison, batch_run)
    """
    try:
        module = request.args.get('module', '')
        
        # 安全检查：防止路径遍历攻击
        safe_filename = os.path.basename(filename)
        
        # 如果指定了模块，在该模块目录查找
        if module and module in OUTPUT_DIRS:
            output_dir = OUTPUT_DIRS[module]
            file_path = os.path.join(output_dir, safe_filename)
            if os.path.exists(file_path):
                return send_file(
                    file_path,
                    as_attachment=True,
                    download_name=safe_filename
                )
        
        # 如果没指定模块或文件不存在，在所有输出目录中查找
        for dir_name, output_dir in OUTPUT_DIRS.items():
            file_path = os.path.join(output_dir, safe_filename)
            if os.path.exists(file_path):
                # 检查文件是否在允许的目录内
                real_path = os.path.realpath(file_path)
                real_output_dir = os.path.realpath(output_dir)
                if real_path.startswith(real_output_dir):
                    return send_file(
                        file_path,
                        as_attachment=True,
                        download_name=safe_filename
                    )
        
        return jsonify({'success': False, 'error': '文件不存在'}), 404
        
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


# 添加简单的下载路由（兼容前端直接下载）
@download_bp.route('/download/<path:filename>')
def simple_download_file(filename):
    """简单下载路由，自动在所有输出目录中查找文件"""
    try:
        safe_filename = os.path.basename(filename)
        
        # 在所有输出目录中查找
        for dir_name, output_dir in OUTPUT_DIRS.items():
            file_path = os.path.join(output_dir, safe_filename)
            if os.path.exists(file_path):
                real_path = os.path.realpath(file_path)
                real_output_dir = os.path.realpath(output_dir)
                if real_path.startswith(real_output_dir):
                    return send_file(
                        file_path,
                        as_attachment=True,
                        download_name=safe_filename
                    )
        
        return jsonify({'success': False, 'error': '文件不存在'}), 404
        
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


@download_bp.route('/api/list-output-files', methods=['POST'])
def list_output_files():
    """
    列出指定模块的输出文件
    
    Request body:
        module: 模块名
        prefix: 文件前缀（可选）
        timestamp: 时间戳后缀（可选，格式：MMDDHHMM）
    """
    try:
        data = request.json or {}
        module = data.get('module', 'api_comparison')
        prefix = data.get('prefix', '')
        timestamp = data.get('timestamp', '')
        
        output_dir = OUTPUT_DIRS.get(module, API_OUTPUT_DIR)
        
        if not os.path.exists(output_dir):
            return jsonify({'success': True, 'files': []})
        
        # 构建搜索模式
        if prefix and timestamp:
            pattern = f"{prefix}*{timestamp}*.csv"
        elif prefix:
            pattern = f"{prefix}*.csv"
        elif timestamp:
            pattern = f"*{timestamp}*.csv"
        else:
            pattern = "*.csv"
        
        # 搜索文件
        files = glob.glob(os.path.join(output_dir, pattern))
        
        # 按修改时间排序（最新的在前）
        files.sort(key=os.path.getmtime, reverse=True)
        
        # 返回文件信息
        file_list = []
        for f in files[:20]:  # 最多返回20个文件
            stat = os.stat(f)
            file_list.append({
                'filename': os.path.basename(f),
                'size': stat.st_size,
                'size_human': format_size(stat.st_size),
                'mtime': datetime.fromtimestamp(stat.st_mtime).strftime('%Y-%m-%d %H:%M:%S')
            })
        
        return jsonify({
            'success': True,
            'files': file_list,
            'module': module
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})


@download_bp.route('/api/latest-output-files', methods=['POST'])
def get_latest_output_files():
    """
    获取最近生成的输出文件（用于任务完成后自动下载）
    
    Request body:
        module: 模块名
        minutes: 最近多少分钟内的文件（默认5分钟）
        task_id: 任务ID（可选，用于精确匹配）
    """
    try:
        data = request.json or {}
        module = data.get('module', 'api_comparison')
        minutes = data.get('minutes', 5)
        
        output_dir = OUTPUT_DIRS.get(module, API_OUTPUT_DIR)
        
        if not os.path.exists(output_dir):
            return jsonify({'success': True, 'files': []})
        
        # 获取所有CSV文件
        all_files = glob.glob(os.path.join(output_dir, "*.csv"))
        
        # 过滤最近N分钟内修改的文件
        now = datetime.now()
        recent_files = []
        for f in all_files:
            mtime = datetime.fromtimestamp(os.path.getmtime(f))
            diff_minutes = (now - mtime).total_seconds() / 60
            if diff_minutes <= minutes:
                stat = os.stat(f)
                recent_files.append({
                    'filename': os.path.basename(f),
                    'size': stat.st_size,
                    'size_human': format_size(stat.st_size),
                    'mtime': mtime.strftime('%Y-%m-%d %H:%M:%S'),
                    'age_minutes': round(diff_minutes, 1)
                })
        
        # 按修改时间排序（最新的在前）
        recent_files.sort(key=lambda x: x['age_minutes'])
        
        return jsonify({
            'success': True,
            'files': recent_files,
            'module': module
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})


def format_size(size_bytes):
    """格式化文件大小"""
    if size_bytes < 1024:
        return f"{size_bytes} B"
    elif size_bytes < 1024 * 1024:
        return f"{size_bytes / 1024:.1f} KB"
    elif size_bytes < 1024 * 1024 * 1024:
        return f"{size_bytes / (1024 * 1024):.1f} MB"
    else:
        return f"{size_bytes / (1024 * 1024 * 1024):.2f} GB"


@download_bp.route('/api/task/<task_id>/files', methods=['GET'])
def get_task_files(task_id):
    """
    获取指定任务的输出文件
    
    Args:
        task_id: 任务ID
    
    Returns:
        任务相关的输出文件列表
    """
    try:
        from common.task_manager import TaskManager
        
        # 获取任务信息
        task = TaskManager.get_task(task_id)
        if not task:
            return jsonify({'success': False, 'error': '任务不存在'})
        
        # 获取任务类型对应的输出目录
        task_type = task.get('task_type', 'api_comparison')
        output_dir = OUTPUT_DIRS.get(task_type, API_OUTPUT_DIR)
        
        # 如果任务有记录输出文件，直接返回
        if task.get('output_files'):
            files = []
            for f in task['output_files']:
                file_path = os.path.join(output_dir, f) if not os.path.isabs(f) else f
                if os.path.exists(file_path):
                    stat = os.stat(file_path)
                    files.append({
                        'filename': os.path.basename(file_path),
                        'path': os.path.basename(file_path),
                        'size': stat.st_size,
                        'size_human': format_size(stat.st_size),
                        'module': task_type
                    })
            return jsonify({'success': True, 'files': files, 'task_id': task_id})
        
        # 否则，根据任务创建时间查找文件
        created_at = task.get('created_at')
        user_id = task.get('user_id', '')
        
        if not created_at:
            return jsonify({'success': True, 'files': [], 'task_id': task_id})
        
        # 解析创建时间
        try:
            task_time = datetime.fromisoformat(created_at)
            # 生成时间戳模式（与文件命名规则匹配）
            timestamp_pattern = task_time.strftime("%m%d%H%M")
        except:
            return jsonify({'success': True, 'files': [], 'task_id': task_id})
        
        # 搜索匹配的文件
        if not os.path.exists(output_dir):
            return jsonify({'success': True, 'files': [], 'task_id': task_id})
        
        # 构建搜索模式
        if user_id and user_id != 'anonymous':
            # 优先匹配带用户标识的文件
            pattern = f"*{timestamp_pattern}*{user_id}*.csv"
        else:
            pattern = f"*{timestamp_pattern}*.csv"
        
        matched_files = glob.glob(os.path.join(output_dir, pattern))
        
        # 如果没找到带用户标识的，尝试不带用户标识的
        if not matched_files and user_id:
            pattern = f"*{timestamp_pattern}*.csv"
            matched_files = glob.glob(os.path.join(output_dir, pattern))
        
        files = []
        for f in matched_files:
            stat = os.stat(f)
            files.append({
                'filename': os.path.basename(f),
                'path': os.path.basename(f),
                'size': stat.st_size,
                'size_human': format_size(stat.st_size),
                'module': task_type
            })
        
        # 按文件名排序
        files.sort(key=lambda x: x['filename'])
        
        return jsonify({
            'success': True,
            'files': files,
            'task_id': task_id
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})
