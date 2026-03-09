#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
CSV文件合并路由模块

功能：
- 上传多个CSV文件
- 纵向合并（追加行）
- 横向合并（追加列）
- 输出合并后的CSV文件
"""

import os
import pandas as pd
from flask import Blueprint, request, jsonify, send_file
from datetime import datetime

# 创建蓝图
merge_csv_bp = Blueprint('merge_csv', __name__, url_prefix='/merge-csv')

# 输出目录
OUTPUT_DIR = os.path.join('outputdata', 'merge_csv')


def ensure_output_dir():
    """确保输出目录存在"""
    os.makedirs(OUTPUT_DIR, exist_ok=True)


@merge_csv_bp.route('/execute', methods=['POST'])
def execute_merge():
    """
    执行CSV文件合并
    
    请求参数：
        files: 多个CSV文件
        merge_mode: 合并方式（vertical=纵向, horizontal=横向）
        output_filename: 输出文件名
    
    返回：
        JSON响应，包含合并结果和下载链接
    """
    try:
        # 获取上传的文件
        files = request.files.getlist('files')
        if len(files) < 2:
            return jsonify({
                'success': False,
                'error': '请至少上传2个CSV文件'
            })
        
        # 获取参数
        merge_mode = request.form.get('merge_mode', 'vertical')
        output_filename = request.form.get('output_filename', 'merged')
        
        # 确保输出目录存在
        ensure_output_dir()
        
        # 读取所有CSV文件
        dataframes = []
        for file in files:
            try:
                df = pd.read_csv(file)
                dataframes.append(df)
            except Exception as e:
                return jsonify({
                    'success': False,
                    'error': f'读取文件 {file.filename} 失败: {str(e)}'
                })
        
        # 执行合并
        if merge_mode == 'vertical':
            # 纵向合并（追加行）
            merged_df = pd.concat(dataframes, axis=0, ignore_index=True)
        else:
            # 横向合并（追加列）
            merged_df = pd.concat(dataframes, axis=1)
        
        # 生成输出文件名
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        output_file = f"{output_filename}_{timestamp}.csv"
        output_path = os.path.join(OUTPUT_DIR, output_file)
        
        # 保存合并结果
        merged_df.to_csv(output_path, index=False, encoding='utf-8-sig')
        
        return jsonify({
            'success': True,
            'output_file': output_file,
            'total_rows': len(merged_df),
            'total_columns': len(merged_df.columns),
            'download_url': f'/download/merge_csv/{output_file}'
        })
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        })
