#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
CSV文件合并路由模块

功能：
1. 纵向合并（追加行）：列相同，多个文件上下拼接
2. 横向合并（追加列）：按主键列匹配合并，去除重复列
"""

import os
import pandas as pd
from flask import Blueprint, request, jsonify, Response, stream_with_context
from datetime import datetime
import json
import tempfile
import traceback

# 创建蓝图
merge_csv_bp = Blueprint('merge_csv', __name__, url_prefix='/merge-csv')

# 输出目录
OUTPUT_DIR = os.path.join('outputdata', 'merge_csv')

# 分块大小（行数）
CHUNK_SIZE = 50000


def ensure_output_dir():
    """确保输出目录存在"""
    os.makedirs(OUTPUT_DIR, exist_ok=True)


@merge_csv_bp.route('/test', methods=['GET'])
def test_endpoint():
    """测试端点，验证路由是否正常工作"""
    return jsonify({
        'status': 'ok',
        'message': 'CSV合并服务正常运行',
        'output_dir': OUTPUT_DIR,
        'chunk_size': CHUNK_SIZE
    })


def vertical_merge(temp_files, output_path, progress_callback=None):
    """
    纵向合并（追加行）
    
    规则：
    - 列结构相同
    - 只保留第一个文件的列名（第一行）
    - 后续文件从第二行开始追加（跳过列名）
    - 生成的新文件列名不重复
    
    Args:
        temp_files: 临时文件路径列表
        output_path: 输出文件路径
        progress_callback: 进度回调函数
    
    Returns:
        (total_rows, total_columns): 总行数和总列数
    """
    total_rows = 0
    total_columns = 0
    first_file = True
    
    for file_idx, temp_file in enumerate(temp_files):
        if progress_callback:
            progress_callback(f'正在处理第 {file_idx+1}/{len(temp_files)} 个文件...', 
                            20 + file_idx * 60 // len(temp_files))
        
        # 分块读取
        for chunk_idx, chunk in enumerate(pd.read_csv(temp_file, chunksize=CHUNK_SIZE, 
                                                       encoding='utf-8-sig', low_memory=False)):
            if first_file:
                # 第一个文件：写入表头和数据
                chunk.to_csv(output_path, mode='w', index=False, encoding='utf-8-sig')
                first_file = False
                total_columns = len(chunk.columns)
            else:
                # 后续文件：只追加数据，不写表头
                chunk.to_csv(output_path, mode='a', index=False, header=False, encoding='utf-8-sig')
            
            total_rows += len(chunk)
            
            # 每5个块更新一次进度
            if chunk_idx % 5 == 0 and progress_callback:
                progress_callback(f'已处理 {total_rows:,} 行...', 
                                20 + file_idx * 60 // len(temp_files))
    
    return total_rows, total_columns


def horizontal_merge(temp_files, output_path, key_columns, progress_callback=None):
    """
    横向合并（追加列）
    
    规则：
    - 行数相同
    - 按指定的主键列进行匹配合并
    - 先合并完成后再去掉重复的列
    - 重复的列只保留第一份
    
    Args:
        temp_files: 临时文件路径列表
        output_path: 输出文件路径
        key_columns: 主键列名列表（用于匹配）
        progress_callback: 进度回调函数
    
    Returns:
        (total_rows, total_columns, removed_columns): 总行数、总列数、移除的列名列表
    """
    dataframes = []
    removed_columns = []
    
    # 1. 读取所有文件
    for file_idx, temp_file in enumerate(temp_files):
        if progress_callback:
            progress_callback(f'正在读取第 {file_idx+1}/{len(temp_files)} 个文件...', 
                            20 + file_idx * 30 // len(temp_files))
        
        df = pd.read_csv(temp_file, encoding='utf-8-sig', low_memory=False)
        dataframes.append(df)
    
    if progress_callback:
        progress_callback('正在执行横向合并...', 60)
    
    # 2. 按主键列进行合并
    if key_columns:
        # 有主键：使用merge进行匹配合并
        merged_df = dataframes[0]
        
        for i in range(1, len(dataframes)):
            if progress_callback:
                progress_callback(f'正在合并第 {i+1}/{len(dataframes)} 个文件...', 
                                60 + i * 15 // len(dataframes))
            
            # 使用主键列进行合并
            merged_df = pd.merge(merged_df, dataframes[i], on=key_columns, how='outer', 
                               suffixes=('', f'_dup{i}'))
    else:
        # 无主键：直接按列拼接（要求行数相同）
        if progress_callback:
            progress_callback('按列直接拼接...', 70)
        merged_df = pd.concat(dataframes, axis=1)
    
    if progress_callback:
        progress_callback('正在移除重复列...', 80)
    
    # 3. 移除重复列（保留第一次出现的列）
    seen_columns = set()
    columns_to_keep = []
    
    for col in merged_df.columns:
        # 处理带后缀的重复列名
        base_col = col.split('_dup')[0] if '_dup' in col else col
        
        if base_col not in seen_columns:
            seen_columns.add(base_col)
            columns_to_keep.append(col)
        else:
            removed_columns.append(col)
    
    # 只保留不重复的列
    merged_df = merged_df[columns_to_keep]
    
    if progress_callback:
        progress_callback('正在保存合并结果...', 90)
    
    # 4. 保存结果
    merged_df.to_csv(output_path, index=False, encoding='utf-8-sig')
    
    return len(merged_df), len(merged_df.columns), removed_columns


@merge_csv_bp.route('/execute', methods=['POST'])
def execute_merge():
    """
    执行CSV文件合并
    
    请求参数：
        files: 多个CSV文件
        merge_mode: 合并方式（vertical=纵向, horizontal=横向）
        output_filename: 输出文件名
        key_columns: 主键列名（横向合并时使用，逗号分隔）
    
    返回：
        SSE流，实时推送进度和结果
    """
    def generate():
        temp_files = []
        try:
            # 获取上传的文件
            files = request.files.getlist('files')
            if len(files) < 2:
                yield f"data: {json.dumps({'type': 'error', 'message': '请至少上传2个CSV文件'}, ensure_ascii=False)}\n\n"
                return
            
            # 获取参数
            merge_mode = request.form.get('merge_mode', 'vertical')
            output_filename = request.form.get('output_filename', 'merged')
            key_columns_str = request.form.get('key_columns', '').strip()
            
            # 解析主键列
            key_columns = [col.strip() for col in key_columns_str.split(',') if col.strip()] if key_columns_str else []
            
            # 确保输出目录存在
            ensure_output_dir()
            
            yield f"data: {json.dumps({'type': 'progress', 'message': f'开始处理 {len(files)} 个文件...', 'percent': 5}, ensure_ascii=False)}\n\n"
            
            # 保存上传的文件到临时目录
            for i, file in enumerate(files):
                temp_file = tempfile.NamedTemporaryFile(mode='w+b', delete=False, suffix='.csv')
                file.save(temp_file.name)
                temp_file.close()
                temp_files.append(temp_file.name)
                progress = 5 + (i + 1) * 10 // len(files)
                yield f"data: {json.dumps({'type': 'progress', 'message': f'已保存文件 {i+1}/{len(files)}: {file.filename}', 'percent': progress}, ensure_ascii=False)}\n\n"
            
            # 生成输出文件名
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            output_file = f"{output_filename}_{timestamp}.csv"
            output_path = os.path.join(OUTPUT_DIR, output_file)
            
            # 进度回调函数
            def progress_callback(message, percent):
                yield f"data: {json.dumps({'type': 'progress', 'message': message, 'percent': percent}, ensure_ascii=False)}\n\n"
            
            if merge_mode == 'vertical':
                # 纵向合并（追加行）
                yield f"data: {json.dumps({'type': 'progress', 'message': '开始纵向合并（追加行）...', 'percent': 20}, ensure_ascii=False)}\n\n"
                
                # 执行纵向合并（直接在这里推送进度）
                total_rows = 0
                total_columns = 0
                first_file = True
                
                for file_idx, temp_file in enumerate(temp_files):
                    yield f"data: {json.dumps({'type': 'progress', 'message': f'正在处理第 {file_idx+1}/{len(temp_files)} 个文件...', 'percent': 20 + file_idx * 60 // len(temp_files)}, ensure_ascii=False)}\n\n"
                    
                    # 分块读取并写入
                    for chunk_idx, chunk in enumerate(pd.read_csv(temp_file, chunksize=CHUNK_SIZE, encoding='utf-8-sig', low_memory=False)):
                        if first_file:
                            # 第一个块，写入表头
                            chunk.to_csv(output_path, mode='w', index=False, encoding='utf-8-sig')
                            first_file = False
                            total_columns = len(chunk.columns)
                        else:
                            # 后续块，追加数据（不写表头）
                            chunk.to_csv(output_path, mode='a', index=False, header=False, encoding='utf-8-sig')
                        
                        total_rows += len(chunk)
                        
                        # 每5个块更新一次进度
                        if chunk_idx % 5 == 0:
                            yield f"data: {json.dumps({'type': 'progress', 'message': f'已处理 {total_rows:,} 行...', 'percent': 20 + file_idx * 60 // len(temp_files)}, ensure_ascii=False)}\n\n"
                
                yield f"data: {json.dumps({'type': 'progress', 'message': '合并完成，正在生成结果...', 'percent': 90}, ensure_ascii=False)}\n\n"
                
                yield f"data: {json.dumps({'type': 'success', 'output_file': output_file, 'total_rows': total_rows, 'total_columns': total_columns, 'download_url': f'/download/merge_csv/{output_file}', 'percent': 100}, ensure_ascii=False)}\n\n"
                
            else:
                # 横向合并（追加列）
                yield f"data: {json.dumps({'type': 'progress', 'message': '开始横向合并（追加列）...', 'percent': 20}, ensure_ascii=False)}\n\n"
                
                if key_columns:
                    yield f"data: {json.dumps({'type': 'progress', 'message': f'使用主键列: {', '.join(key_columns)}', 'percent': 25}, ensure_ascii=False)}\n\n"
                else:
                    yield f"data: {json.dumps({'type': 'progress', 'message': '未指定主键，将按列直接拼接', 'percent': 25}, ensure_ascii=False)}\n\n"
                
                # 执行横向合并
                total_rows, total_columns, removed_columns = horizontal_merge(temp_files, output_path, key_columns)
                
                yield f"data: {json.dumps({'type': 'progress', 'message': '合并完成，正在生成结果...', 'percent': 95}, ensure_ascii=False)}\n\n"
                
                result = {
                    'type': 'success',
                    'output_file': output_file,
                    'total_rows': total_rows,
                    'total_columns': total_columns,
                    'download_url': f'/download/merge_csv/{output_file}',
                    'percent': 100
                }
                
                if removed_columns:
                    result['removed_columns'] = removed_columns
                    result['removed_count'] = len(removed_columns)
                
                yield f"data: {json.dumps(result, ensure_ascii=False)}\n\n"
                
        except Exception as e:
            error_msg = f"{str(e)}\n{traceback.format_exc()}"
            yield f"data: {json.dumps({'type': 'error', 'message': error_msg}, ensure_ascii=False)}\n\n"
        finally:
            # 清理临时文件
            for temp_file in temp_files:
                try:
                    if os.path.exists(temp_file):
                        os.unlink(temp_file)
                except Exception as e:
                    print(f"清理临时文件失败: {temp_file}, 错误: {e}")
    
    return Response(stream_with_context(generate()), mimetype='text/event-stream')
