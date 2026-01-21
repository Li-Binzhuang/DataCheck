#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
配置管理模块
功能：处理JSON配置文件的加载和单场景配置的构建
"""

import os
import json
from typing import Optional, Dict


def load_config_from_json(config_file_path: str) -> Optional[Dict]:
    """
    从JSON文件加载配置
    
    Args:
        config_file_path: JSON配置文件路径
    
    Returns:
        配置字典，如果文件不存在或格式错误则返回None
    """
    if not os.path.exists(config_file_path):
        return None
    
    try:
        with open(config_file_path, 'r', encoding='utf-8') as f:
            config = json.load(f)
        return config
    except Exception as e:
        print(f"❌ 加载配置文件失败: {str(e)}")
        import traceback
        traceback.print_exc()
        return None


def build_single_scenario_config(
    input_csv_file: str,
    output_file_prefix: str,
    api_url: str,
    thread_count: int,
    timeout: int,
    cust_no_column: int,
    use_create_time_column: int,
    feature_start_column: int
) -> Dict:
    """
    构建单场景配置字典
    
    Args:
        input_csv_file: 输入CSV文件名
        output_file_prefix: 输出文件前缀
        api_url: 接口URL
        thread_count: 线程数
        timeout: 超时时间
        cust_no_column: cust_no列索引（必须手动配置）
        use_create_time_column: 时间字段列索引（必须手动配置）
        feature_start_column: 特征开始列索引
    
    Returns:
        场景配置字典
    """
    return {
        'name': '单场景模式',
        'input_csv_file': input_csv_file,
        'output_file_prefix': output_file_prefix,
        'api_url': api_url,
        'thread_count': thread_count,
        'timeout': timeout,
        'column_config': {
            'cust_no_column': cust_no_column,
            'use_create_time_column': use_create_time_column,
            'feature_start_column': feature_start_column
        }
    }


def build_global_config(
    thread_count: int,
    timeout: int
) -> Dict:
    """
    构建全局配置字典
    
    Args:
        thread_count: 默认线程数
        timeout: 默认超时时间
    
    Returns:
        全局配置字典
    """
    return {
        'default_thread_count': thread_count,
        'default_timeout': timeout
    }


def cleanup_column_config(config_file_path: str, valid_scenario_names: list):
    """
    清理列索引配置文件中不再存在的场景
    
    Args:
        config_file_path: 列索引配置文件路径
        valid_scenario_names: 有效的场景名称列表（来自执行配置.json）
    """
    if not os.path.exists(config_file_path):
        return
    
    try:
        with open(config_file_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        # 检查是否为多场景格式
        if isinstance(data, dict) and 'scenarios' in data:
            scenarios = data.get('scenarios', {})
            original_count = len(scenarios)
            
            # 只保留有效的场景
            valid_scenarios = {
                name: config for name, config in scenarios.items() 
                if name in valid_scenario_names
            }
            
            removed_count = original_count - len(valid_scenarios)
            
            if removed_count > 0:
                # 更新配置
                data['scenarios'] = valid_scenarios
                
                # 保存回文件
                with open(config_file_path, 'w', encoding='utf-8') as f:
                    json.dump(data, f, indent=2, ensure_ascii=False)
    except Exception as e:
        # 清理失败不影响主流程
        pass
