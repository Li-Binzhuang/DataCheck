#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
PKL文件处理工具路由
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

pkl_bp = Blueprint('pkl_routes', __name__)

# 为了兼容性，创建小写别名
api_input_dir = API_INPUT_DIR
api_output_dir = API_OUTPUT_DIR
online_input_dir = ONLINE_INPUT_DIR

# 动态导入PKL转换模块
pkl_converter_path = os.path.join(COMMON_DIR, "pkl_converter.py")
spec_pkl = importlib.util.spec_from_file_location("pkl_converter", pkl_converter_path)
pkl_converter_module = importlib.util.module_from_spec(spec_pkl)
spec_pkl.loader.exec_module(pkl_converter_module)
convert_pkl_to_csv_with_preview = pkl_converter_module.convert_pkl_to_csv_with_preview
parse_pkl_file = pkl_converter_module.parse_pkl_file
get_pkl_info = pkl_converter_module.get_pkl_info
convert_pkl_to_cdcv2_csv = pkl_converter_module.convert_pkl_to_cdcv2_csv


@pkl_bp.route('/api/pkl/parse', methods=['POST'])
def parse_pkl():
    """解析PKL文件并返回内容预览（接口数据对比）"""
    try:
        data = request.json
        filename = data.get('filename')
        
        if not filename:
            return jsonify({'success': False, 'error': '文件名不能为空'})
        
        # 构建文件路径
        file_path = os.path.join(api_input_dir, filename)
        
        if not os.path.exists(file_path):
            return jsonify({'success': False, 'error': f'文件不存在: {filename}'})
        
        if not file_path.endswith('.pkl'):
            return jsonify({'success': False, 'error': '只支持PKL文件'})
        
        # 解析PKL文件
        preview_rows = data.get('preview_rows', 10)
        parse_result = parse_pkl_file(file_path, preview_rows=preview_rows)
        
        if parse_result.get('success'):
            return jsonify({
                'success': True,
                'data': parse_result
            })
        else:
            return jsonify({
                'success': False,
                'error': parse_result.get('error', '解析失败'),
                'error_detail': parse_result.get('error_detail', ''),
                'install_command': parse_result.get('install_command', '')
            })
            
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})




@pkl_bp.route('/api/pkl/convert', methods=['POST'])
def convert_pkl_api():
    """将PKL文件转换为CSV（接口数据对比）"""
    try:
        data = request.json
        filename = data.get('filename')
        
        if not filename:
            return jsonify({'success': False, 'error': '文件名不能为空'})
        
        # 构建文件路径
        pkl_file_path = os.path.join(api_input_dir, filename)
        
        if not os.path.exists(pkl_file_path):
            return jsonify({'success': False, 'error': f'文件不存在: {filename}'})
        
        if not pkl_file_path.endswith('.pkl'):
            return jsonify({'success': False, 'error': '只支持PKL文件'})
        
        # 转换为CSV
        success, message, csv_path, info = convert_pkl_to_csv_with_preview(
            pkl_file_path, 
            output_dir=api_output_dir
        )
        
        if success:
            csv_filename = os.path.basename(csv_path)
            return jsonify({
                'success': True,
                'message': message,
                'csv_filename': csv_filename,
                'csv_path': csv_path,
                'info': info
            })
        else:
            return jsonify({
                'success': False,
                'error': message,
                'info': info,
                'error_detail': info.get('error_detail', '') if info else '',
                'install_command': info.get('install_command', '') if info else ''
            })
            
    except Exception as e:
        import traceback
        return jsonify({
            'success': False, 
            'error': str(e),
            'traceback': traceback.format_exc()
        })




@pkl_bp.route('/api/pkl/info', methods=['POST'])
def get_pkl_file_info():
    """获取PKL文件信息"""
    try:
        data = request.json
        filename = data.get('filename')
        file_type = data.get('type', 'api')  # api 或 online
        
        if not filename:
            return jsonify({'success': False, 'error': '文件名为空'})
        
        # 确定文件路径
        if file_type == 'online':
            file_path = os.path.join(online_input_dir, filename)
        else:
            file_path = os.path.join(api_input_dir, filename)
        
        if not os.path.exists(file_path):
            return jsonify({'success': False, 'error': '文件不存在'})
        
        # 获取pkl文件信息
        info = get_pkl_info(file_path)
        
        if info.get('success'):
            return jsonify({
                'success': True,
                'info': info
            })
        else:
            return jsonify({
                'success': False,
                'error': info.get('error', '获取文件信息失败')
            })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})




@pkl_bp.route('/api/pkl/convert-cdcv2', methods=['POST'])
def convert_pkl_to_cdcv2_api():
    """将PKL文件转换为cdcV2核心CSV（接口数据对比）"""
    try:
        data = request.json
        filename = data.get('filename')
        
        if not filename:
            return jsonify({'success': False, 'error': '文件名不能为空'})
        
        # 构建文件路径
        pkl_file_path = os.path.join(api_input_dir, filename)
        
        if not os.path.exists(pkl_file_path):
            return jsonify({'success': False, 'error': f'文件不存在: {filename}'})
        
        if not pkl_file_path.endswith('.pkl'):
            return jsonify({'success': False, 'error': '只支持PKL文件'})
        
        # 转换为cdcV2核心CSV
        success, message, csv_path, info = convert_pkl_to_cdcv2_csv(
            pkl_file_path, 
            output_dir=api_output_dir
        )
        
        if success:
            csv_filename = os.path.basename(csv_path)
            return jsonify({
                'success': True,
                'message': message,
                'csv_filename': csv_filename,
                'csv_path': csv_path,
                'info': info
            })
        else:
            return jsonify({
                'success': False,
                'error': message,
                'info': info,
                'error_detail': info.get('error_detail', '') if info else '',
                'install_command': info.get('install_command', '') if info else ''
            })
            
    except Exception as e:
        import traceback
        return jsonify({
            'success': False, 
            'error': str(e),
            'traceback': traceback.format_exc()
        })



