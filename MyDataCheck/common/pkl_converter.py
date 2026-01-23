#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
PKL文件转换工具
功能：将.pkl文件转换为.csv文件
"""

import pickle
import os
import json

try:
    import pandas as pd
    HAS_PANDAS = True
except ImportError:
    HAS_PANDAS = False


def convert_pkl_to_csv(pkl_file_path, csv_file_path=None, output_to_outputdata=True):
    """
    将pkl文件转换为csv文件
    
    参数:
        pkl_file_path: pkl文件路径
        csv_file_path: csv文件输出路径（可选，默认根据output_to_outputdata参数决定）
        output_to_outputdata: 是否输出到outputdata目录（默认True）
    
    返回:
        tuple: (success, message, csv_path)
    """
    if not HAS_PANDAS:
        error_msg = "需要安装pandas库"
        error_detail = "pandas库未安装，请执行以下命令安装：\n1. 激活虚拟环境: source .venv/bin/activate\n2. 安装依赖: pip install pandas numpy\n或者直接安装所有依赖: pip install -r requirements.txt"
        return False, error_msg, None
    
    try:
        # 如果没有指定csv路径，根据参数决定输出位置
        if csv_file_path is None:
            if output_to_outputdata:
                # 将inputdata替换为outputdata
                if 'inputdata' in pkl_file_path:
                    csv_file_path = pkl_file_path.replace('inputdata', 'outputdata').rsplit('.', 1)[0] + '.csv'
                else:
                    # 如果路径中没有inputdata，则在同目录生成
                    csv_file_path = pkl_file_path.rsplit('.', 1)[0] + '.csv'
            else:
                # 使用pkl文件同目录同名
                csv_file_path = pkl_file_path.rsplit('.', 1)[0] + '.csv'
        
        # 读取pkl文件
        with open(pkl_file_path, 'rb') as f:
            data = pickle.load(f)
        
        # 判断数据类型并转换（保持原始结构和列的顺序）
        if isinstance(data, pd.DataFrame):
            # 如果是DataFrame，直接保存，保持列的顺序
            df = data.copy()
        elif isinstance(data, list):
            # 如果是列表，转换为DataFrame（保持顺序）
            if len(data) > 0:
                if isinstance(data[0], dict):
                    # 列表中的字典，转换为DataFrame
                    # 收集所有可能的键（保持第一次出现的顺序）
                    all_keys = []
                    seen_keys = set()
                    for item in data:
                        if isinstance(item, dict):
                            # 按照字典中的键顺序添加
                            for key in item.keys():
                                if key not in seen_keys:
                                    all_keys.append(key)
                                    seen_keys.add(key)
                    
                    # 构建DataFrame，确保列顺序与第一次出现的顺序一致
                    df_data = []
                    for item in data:
                        row = {}
                        for key in all_keys:
                            row[key] = item.get(key) if isinstance(item, dict) else None
                        df_data.append(row)
                    df = pd.DataFrame(df_data)
                else:
                    df = pd.DataFrame(data)
            else:
                df = pd.DataFrame()
        elif isinstance(data, dict):
            # 如果是字典，尝试转换为DataFrame（保持键的顺序）
            df = pd.DataFrame([data])
        else:
            # 其他类型，尝试直接转换
            df = pd.DataFrame([data])
        
        # 保存为CSV（保持列的顺序）
        df.to_csv(csv_file_path, index=False, encoding='utf-8')
        
        return True, f"成功转换: {os.path.basename(csv_file_path)}", csv_file_path
        
    except Exception as e:
        return False, f"转换失败: {str(e)}", None


def get_pkl_info(pkl_file_path):
    """
    获取pkl文件的基本信息
    
    参数:
        pkl_file_path: pkl文件路径
    
    返回:
        dict: 包含数据类型、形状等信息
    """
    if not HAS_PANDAS:
        return {
            'success': False,
            'error': '需要安装pandas库',
            'error_detail': 'pandas库未安装，请执行以下命令安装：\n1. 激活虚拟环境: source .venv/bin/activate\n2. 安装依赖: pip install pandas numpy\n或者直接安装所有依赖: pip install -r requirements.txt',
            'install_command': 'pip install pandas numpy'
        }
    
    try:
        with open(pkl_file_path, 'rb') as f:
            data = pickle.load(f)
        
        info = {
            'type': type(data).__name__,
            'success': True
        }
        
        if isinstance(data, pd.DataFrame):
            info['shape'] = data.shape
            info['columns'] = list(data.columns)
            info['rows'] = len(data)
            info['cols'] = len(data.columns)
        elif isinstance(data, dict):
            info['keys'] = list(data.keys())
            info['length'] = len(data)
        elif isinstance(data, list):
            info['length'] = len(data)
        
        return info
        
    except Exception as e:
        return {
            'success': False,
            'error': str(e)
        }


def parse_pkl_file(pkl_file_path, preview_rows=10):
    """
    解析PKL文件并返回详细内容和预览数据
    
    参数:
        pkl_file_path: pkl文件路径
        preview_rows: 预览行数（默认10行）
    
    返回:
        dict: 包含文件内容、预览数据等信息
    """
    if not HAS_PANDAS:
        return {
            'success': False,
            'error': '需要安装pandas库',
            'error_detail': 'pandas库未安装，请执行以下命令安装：\n1. 激活虚拟环境: source .venv/bin/activate\n2. 安装依赖: pip install pandas numpy\n或者直接安装所有依赖: pip install -r requirements.txt',
            'install_command': 'pip install pandas numpy'
        }
    
    try:
        with open(pkl_file_path, 'rb') as f:
            data = pickle.load(f)
        
        result = {
            'success': True,
            'data_type': type(data).__name__,
            'file_path': pkl_file_path,
            'file_name': os.path.basename(pkl_file_path)
        }
        
        # 根据数据类型处理
        if isinstance(data, pd.DataFrame):
            result['type'] = 'DataFrame'
            result['shape'] = data.shape
            result['rows'] = len(data)
            result['cols'] = len(data.columns)
            result['columns'] = list(data.columns)
            result['dtypes'] = {col: str(dtype) for col, dtype in data.dtypes.items()}
            
            # 预览数据（转换为字典列表，便于JSON序列化）
            # 处理NaN值，确保JSON序列化正确
            preview_df = data.head(preview_rows)
            # 使用fillna将所有NaN/NaT/NA替换为None
            preview_df = preview_df.fillna(None)
            # 转换为字典，并手动处理剩余的NaN值
            preview_data = []
            for _, row in preview_df.iterrows():
                row_dict = {}
                for col, val in row.items():
                    # 检查是否为NaN（包括numpy.nan, pandas.NA等）
                    if pd.isna(val) or (isinstance(val, float) and str(val) == 'nan'):
                        row_dict[col] = None
                    else:
                        row_dict[col] = val
                preview_data.append(row_dict)
            result['preview'] = preview_data
            
            # 基本统计信息
            try:
                stats_df = data.describe()
                # 处理NaN值，确保JSON序列化正确
                stats_df = stats_df.fillna(None)
                stats_dict = {}
                for col in stats_df.columns:
                    col_dict = {}
                    for idx, val in stats_df[col].items():
                        if pd.isna(val) or (isinstance(val, float) and str(val) == 'nan'):
                            col_dict[idx] = None
                        else:
                            col_dict[idx] = val
                    stats_dict[col] = col_dict
                result['statistics'] = stats_dict
            except:
                result['statistics'] = {}
            
            # 缺失值统计
            null_counts = data.isnull().sum().to_dict()
            # 确保所有值都是Python原生类型（不是numpy类型）
            result['null_counts'] = {k: int(v) if pd.notnull(v) else 0 for k, v in null_counts.items()}
            
        elif isinstance(data, dict):
            result['type'] = 'dict'
            result['keys'] = list(data.keys())
            result['length'] = len(data)
            
            # 检查字典中是否有DataFrame
            dfs_in_dict = {}
            for key, value in data.items():
                if isinstance(value, pd.DataFrame):
                    # 处理NaN值，确保JSON序列化正确
                    preview_df = value.head(preview_rows).fillna(None)
                    preview_data = []
                    for _, row in preview_df.iterrows():
                        row_dict = {}
                        for col, val in row.items():
                            if pd.isna(val) or (isinstance(val, float) and str(val) == 'nan'):
                                row_dict[col] = None
                            else:
                                row_dict[col] = val
                        preview_data.append(row_dict)
                    dfs_in_dict[key] = {
                        'shape': value.shape,
                        'columns': list(value.columns),
                        'preview': preview_data
                    }
            
            if dfs_in_dict:
                result['dataframes'] = dfs_in_dict
            
            # 预览字典内容（限制大小）
            preview_dict = {}
            for key, value in list(data.items())[:10]:
                if isinstance(value, pd.DataFrame):
                    preview_dict[key] = f"DataFrame({value.shape[0]}行, {value.shape[1]}列)"
                elif isinstance(value, (dict, list)):
                    preview_dict[key] = f"{type(value).__name__}(长度: {len(value)})"
                else:
                    preview_dict[key] = str(value)[:100]  # 限制长度
            result['preview'] = preview_dict
            
        elif isinstance(data, list):
            result['type'] = 'list'
            result['length'] = len(data)
            
            if len(data) > 0:
                result['first_item_type'] = type(data[0]).__name__
                
                # 如果列表中是字典，尝试转换为DataFrame预览
                if isinstance(data[0], dict):
                    try:
                        df_preview = pd.DataFrame(data[:preview_rows])
                        # 处理NaN值，确保JSON序列化正确
                        df_preview = df_preview.fillna(None)
                        preview_data = []
                        for _, row in df_preview.iterrows():
                            row_dict = {}
                            for col, val in row.items():
                                if pd.isna(val) or (isinstance(val, float) and str(val) == 'nan'):
                                    row_dict[col] = None
                                else:
                                    row_dict[col] = val
                            preview_data.append(row_dict)
                        result['preview'] = preview_data
                        result['can_convert_to_dataframe'] = True
                    except:
                        result['preview'] = data[:preview_rows]
                        result['can_convert_to_dataframe'] = False
                else:
                    result['preview'] = data[:preview_rows]
        else:
            result['type'] = 'other'
            result['preview'] = str(data)[:500]  # 限制预览长度
        
        return result
        
    except Exception as e:
        import traceback
        return {
            'success': False,
            'error': str(e),
            'traceback': traceback.format_exc()
        }


def convert_pkl_to_csv_with_preview(pkl_file_path, csv_file_path=None, output_dir=None):
    """
    将pkl文件转换为csv文件（增强版，返回详细信息）
    
    参数:
        pkl_file_path: pkl文件路径
        csv_file_path: csv文件输出路径（可选）
        output_dir: 输出目录（如果csv_file_path为None且需要输出到特定目录）
    
    返回:
        tuple: (success, message, csv_path, info_dict)
    """
    if not HAS_PANDAS:
        error_msg = "需要安装pandas库"
        error_detail = "pandas库未安装，请执行以下命令安装：\n1. 激活虚拟环境: source .venv/bin/activate\n2. 安装依赖: pip install pandas numpy\n或者直接安装所有依赖: pip install -r requirements.txt"
        return False, error_msg, None, {
            'error': error_msg,
            'error_detail': error_detail,
            'install_command': 'pip install pandas numpy'
        }
    
    try:
        # 先解析文件获取信息
        parse_info = parse_pkl_file(pkl_file_path, preview_rows=5)
        if not parse_info.get('success'):
            return False, f"解析PKL文件失败: {parse_info.get('error')}", None, None
        
        # 如果没有指定csv路径，根据参数决定输出位置
        if csv_file_path is None:
            if output_dir:
                # 使用指定的输出目录
                base_name = os.path.basename(pkl_file_path).rsplit('.', 1)[0]
                csv_file_path = os.path.join(output_dir, f"{base_name}.csv")
            else:
                # 将inputdata替换为outputdata
                if 'inputdata' in pkl_file_path:
                    csv_file_path = pkl_file_path.replace('inputdata', 'outputdata').rsplit('.', 1)[0] + '.csv'
                else:
                    # 如果路径中没有inputdata，则在同目录生成
                    csv_file_path = pkl_file_path.rsplit('.', 1)[0] + '.csv'
        
        # 确保输出目录存在
        output_dir_path = os.path.dirname(csv_file_path)
        if output_dir_path:
            os.makedirs(output_dir_path, exist_ok=True)
        
        # 读取pkl文件
        with open(pkl_file_path, 'rb') as f:
            data = pickle.load(f)
        
        df = None
        
        # 判断数据类型并转换
        if isinstance(data, pd.DataFrame):
            # 如果是DataFrame，直接使用，保持列的顺序
            df = data.copy()
        elif isinstance(data, list):
            # 如果是列表，转换为DataFrame（保持顺序）
            if len(data) > 0:
                if isinstance(data[0], dict):
                    # 列表中的字典，转换为DataFrame
                    # 收集所有可能的键（保持第一次出现的顺序）
                    all_keys = []
                    seen_keys = set()
                    for item in data:
                        if isinstance(item, dict):
                            for key in item.keys():
                                if key not in seen_keys:
                                    all_keys.append(key)
                                    seen_keys.add(key)
                    
                    # 构建DataFrame，确保列顺序
                    df_data = []
                    for item in data:
                        row = {}
                        for key in all_keys:
                            row[key] = item.get(key) if isinstance(item, dict) else None
                        df_data.append(row)
                    df = pd.DataFrame(df_data)
                else:
                    df = pd.DataFrame(data)
            else:
                df = pd.DataFrame()
        elif isinstance(data, dict):
            # 如果是字典
            dfs = [v for v in data.values() if isinstance(v, pd.DataFrame)]
            if dfs:
                # 如果字典中有DataFrame，优先使用第一个
                df = dfs[0].copy()
            else:
                # 尝试将字典本身转换为DataFrame
                # 保持键的顺序
                try:
                    df = pd.DataFrame([data])
                except:
                    df = pd.DataFrame([data])
        else:
            df = pd.DataFrame([data])
        
        # 保存为CSV（保持列的顺序）
        df.to_csv(csv_file_path, index=False, encoding='utf-8-sig')
        
        # 返回详细信息
        info = {
            'input_file': pkl_file_path,
            'output_file': csv_file_path,
            'rows': len(df),
            'columns': len(df.columns),
            'column_names': list(df.columns)
        }
        
        return True, f"成功转换: {os.path.basename(csv_file_path)}", csv_file_path, info
        
    except Exception as e:
        import traceback
        return False, f"转换失败: {str(e)}", None, {'error': str(e), 'traceback': traceback.format_exc()}


def flatten_dict(d, parent_key='', sep='.'):
    """
    打平嵌套字典，将嵌套的键用点号连接
    提取所有叶子节点作为特征
    
    参数:
        d: 嵌套字典
        parent_key: 父键名
        sep: 分隔符
    
    返回:
        打平后的字典
    """
    if d is None:
        return {}
    
    if not isinstance(d, dict):
        # 如果不是字典，直接返回
        return {parent_key: d} if parent_key else {}
    
    items = []
    for k, v in d.items():
        new_key = f"{parent_key}{sep}{k}" if parent_key else k
        
        if isinstance(v, dict) and v:
            # 如果值是字典且非空，递归打平
            flattened = flatten_dict(v, new_key, sep)
            items.extend(flattened.items())
        elif isinstance(v, list):
            # 如果是列表
            if len(v) == 0:
                # 空列表
                items.append((new_key, None))
            elif isinstance(v[0], dict):
                # 列表中的元素是字典，需要特殊处理
                # 收集所有可能的键
                all_keys = set()
                for item in v:
                    if isinstance(item, dict):
                        flat_item = flatten_dict(item, '', sep)
                        all_keys.update(flat_item.keys())
                
                # 为每个键创建值
                for key in all_keys:
                    values = []
                    for item in v:
                        if isinstance(item, dict):
                            flat_item = flatten_dict(item, '', sep)
                            if key in flat_item:
                                val = flat_item[key]
                                if val is not None:
                                    values.append(str(val))
                    
                    # 合并值（去重后连接）
                    if values:
                        unique_values = list(dict.fromkeys(values))  # 保持顺序的去重
                        if len(unique_values) == 1:
                            items.append((f"{new_key}{sep}{key}", unique_values[0]))
                        else:
                            items.append((f"{new_key}{sep}{key}", '|'.join(unique_values)))
                    else:
                        items.append((f"{new_key}{sep}{key}", None))
            else:
                # 列表中的非字典值，转换为字符串（用|分隔）
                non_none_values = [str(item) for item in v if item is not None]
                if non_none_values:
                    items.append((new_key, '|'.join(non_none_values)))
                else:
                    items.append((new_key, None))
        else:
            # 叶子节点（非字典、非列表）
            items.append((new_key, v))
    
    return dict(items)


def convert_pkl_to_cdcv2_csv(pkl_file_path, output_dir=None):
    """
    将PKL文件转换为cdcV2核心CSV文件
    保留 apply_id, apply_time，并从 response_body 中解析特征
    
    参数:
        pkl_file_path: pkl文件路径
        output_dir: 输出目录
    
    返回:
        tuple: (success, message, csv_path, info_dict)
    """
    if not HAS_PANDAS:
        error_msg = "需要安装pandas库"
        error_detail = "pandas库未安装，请执行以下命令安装：\n1. 激活虚拟环境: source .venv/bin/activate\n2. 安装依赖: pip install pandas numpy\n或者直接安装所有依赖: pip install -r requirements.txt"
        return False, error_msg, None, {
            'error': error_msg,
            'error_detail': error_detail,
            'install_command': 'pip install pandas numpy'
        }
    
    try:
        from datetime import datetime
        
        # 读取PKL文件
        with open(pkl_file_path, 'rb') as f:
            data = pickle.load(f)
        
        # 转换为DataFrame
        if isinstance(data, pd.DataFrame):
            df = data.copy()
        elif isinstance(data, list):
            df = pd.DataFrame(data)
        elif isinstance(data, dict):
            # 如果字典中有DataFrame，优先使用第一个
            dfs = [v for v in data.values() if isinstance(v, pd.DataFrame)]
            if dfs:
                df = dfs[0].copy()
            else:
                df = pd.DataFrame([data])
        else:
            df = pd.DataFrame([data])
        
        # 检查必需的列
        if 'apply_id' not in df.columns:
            return False, "数据中缺少 apply_id 列", None, {'error': '缺少 apply_id 列'}
        
        if 'apply_time' not in df.columns:
            return False, "数据中缺少 apply_time 列", None, {'error': '缺少 apply_time 列'}
        
        if 'response_body' not in df.columns:
            return False, "数据中缺少 response_body 列", None, {'error': '缺少 response_body 列'}
        
        print(f"开始处理 {len(df)} 行数据...")
        
        # 收集所有特征字段
        all_feature_keys = set()
        result_rows = []
        
        for idx, row in df.iterrows():
            if idx % 1000 == 0:
                print(f"已处理: {idx}/{len(df)} 行")
            
            apply_id = row['apply_id']
            apply_time = row['apply_time']
            response_body = row['response_body']
            
            # 初始化结果行
            result_row = {
                'apply_id': apply_id,
                'apply_time': apply_time
            }
            
            # 解析 response_body
            if pd.isna(response_body) or response_body is None or response_body == '':
                # response_body 为空，跳过特征解析
                result_rows.append(result_row)
                continue
            
            try:
                # 解析JSON字符串
                if isinstance(response_body, str):
                    json_obj = json.loads(response_body)
                else:
                    json_obj = response_body
                
                # 打平嵌套字典，提取所有特征
                flattened_features = flatten_dict(json_obj)
                
                # 收集特征字段
                all_feature_keys.update(flattened_features.keys())
                
                # 添加到结果行
                result_row.update(flattened_features)
                
            except json.JSONDecodeError as e:
                print(f"警告: 第 {idx + 1} 行 response_body JSON解析失败: {str(e)}")
                # JSON解析失败，仍然保留基础字段
            except Exception as e:
                print(f"警告: 第 {idx + 1} 行处理 response_body 时发生错误: {str(e)}")
            
            result_rows.append(result_row)
        
        print(f"解析完成，共发现 {len(all_feature_keys)} 个特征字段")
        
        # 构建完整的DataFrame
        # 确保所有行都有所有特征列
        for row in result_rows:
            for key in all_feature_keys:
                if key not in row:
                    row[key] = None
        
        # 创建结果DataFrame
        result_df = pd.DataFrame(result_rows)
        
        # 列顺序：apply_id, apply_time, 然后按字母顺序排列特征列
        feature_columns = sorted([col for col in all_feature_keys])
        column_order = ['apply_id', 'apply_time'] + feature_columns
        result_df = result_df[column_order]
        
        # 生成输出文件名（添加 _cdc_当前时间 后缀）
        base_name = os.path.basename(pkl_file_path).rsplit('.', 1)[0]
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        
        if output_dir:
            csv_file_path = os.path.join(output_dir, f"{base_name}_cdc_{timestamp}.csv")
        else:
            # 默认输出到outputdata目录
            if 'inputdata' in pkl_file_path:
                output_dir_path = pkl_file_path.replace('inputdata', 'outputdata').rsplit(os.sep, 1)[0]
            else:
                output_dir_path = os.path.dirname(pkl_file_path)
            os.makedirs(output_dir_path, exist_ok=True)
            csv_file_path = os.path.join(output_dir_path, f"{base_name}_cdc_{timestamp}.csv")
        
        # 保存CSV文件
        result_df.to_csv(csv_file_path, index=False, encoding='utf-8-sig')
        
        # 返回详细信息
        info = {
            'input_file': pkl_file_path,
            'output_file': csv_file_path,
            'rows': len(result_df),
            'columns': len(result_df.columns),
            'base_columns': 2,  # apply_id, apply_time
            'feature_columns': len(feature_columns),
            'column_names': list(result_df.columns)
        }
        
        return True, f"成功生成cdcV2核心CSV: {os.path.basename(csv_file_path)}", csv_file_path, info
        
    except Exception as e:
        import traceback
        return False, f"转换失败: {str(e)}", None, {
            'error': str(e),
            'traceback': traceback.format_exc()
        }
