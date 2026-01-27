#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
数据对比执行脚本
功能：读取配置文件并执行数据对比
"""

import os
import sys
import json
from datetime import datetime

# 添加父目录到路径
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from data_comparison.job.data_comparator import compare_two_files
from data_comparison.job.report_generator import generate_comparison_reports


def execute_comparison_from_config(config_path: str = None):
    """
    从配置文件执行数据对比
    
    Args:
        config_path: 配置文件路径，默认为当前目录下的config.json
    """
    # 确定配置文件路径
    if config_path is None:
        script_dir = os.path.dirname(os.path.abspath(__file__))
        config_path = os.path.join(script_dir, "config.json")
    
    # 读取配置文件
    print(f"读取配置文件: {config_path}")
    with open(config_path, 'r', encoding='utf-8') as f:
        config = json.load(f)
    
    scenarios = config.get('scenarios', [])
    global_config = config.get('global_config', {})
    
    if not scenarios:
        print("❌ 错误: 配置文件中没有找到场景配置")
        return
    
    # 过滤出启用的场景
    enabled_scenarios = [s for s in scenarios if s.get('enabled', True)]
    
    if not enabled_scenarios:
        print("⚠️  警告: 没有启用的场景")
        return
    
    print(f"找到 {len(enabled_scenarios)} 个启用的场景\n")
    
    # 生成时间戳后缀
    now = datetime.now()
    timestamp_suffix = now.strftime("%m%d%H%M")
    
    # 获取目录路径
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_dir = os.path.dirname(script_dir)
    input_dir = os.path.join(project_dir, "inputdata", "data_comparison")
    output_dir = os.path.join(project_dir, "outputdata", "data_comparison")
    
    # 确保输出目录存在
    os.makedirs(output_dir, exist_ok=True)
    
    # 执行每个场景
    success_count = 0
    fail_count = 0
    
    for i, scenario in enumerate(enabled_scenarios, 1):
        print(f"{'='*80}")
        print(f"[{i}/{len(enabled_scenarios)}] 执行场景: {scenario.get('name', f'场景{i}')}")
        print(f"{'='*80}")
        
        try:
            # 获取配置参数
            sql_file = scenario.get('sql_file')
            api_file = scenario.get('api_file')
            sql_key_column = scenario.get('sql_key_column', global_config.get('default_sql_key_column', 0))
            api_key_column = scenario.get('api_key_column', global_config.get('default_api_key_column', 0))
            sql_feature_start = scenario.get('sql_feature_start', global_config.get('default_sql_feature_start', 1))
            api_feature_start = scenario.get('api_feature_start', global_config.get('default_api_feature_start', 1))
            convert_feature_to_number = scenario.get('convert_feature_to_number', 
                                                     global_config.get('default_convert_feature_to_number', True))
            output_prefix = scenario.get('output_prefix', 'compare')
            
            # 构建文件路径
            sql_file_path = os.path.join(input_dir, sql_file)
            api_file_path = os.path.join(input_dir, api_file)
            
            # 检查文件是否存在
            if not os.path.exists(sql_file_path):
                raise FileNotFoundError(f"Sql文件不存在: {sql_file_path}")
            
            if not os.path.exists(api_file_path):
                raise FileNotFoundError(f"接口文件不存在: {api_file_path}")
            
            # 执行对比
            print(f"\n配置信息:")
            print(f"  Sql文件: {sql_file}")
            print(f"  接口文件: {api_file}")
            print(f"  Sql文件主键列: {sql_key_column}")
            print(f"  接口文件主键列: {api_key_column}")
            print(f"  Sql文件特征起始列: {sql_feature_start}")
            print(f"  接口文件特征起始列: {api_feature_start}")
            print(f"  转换特征值为数值: {convert_feature_to_number}")
            print(f"  输出前缀: {output_prefix}")
            
            comparison_results = compare_two_files(
                sql_file_path,
                api_file_path,
                sql_key_column,
                api_key_column,
                sql_feature_start,
                api_feature_start,
                convert_feature_to_number
            )
            
            # 生成报告
            output_base_path = os.path.join(output_dir, f"{output_prefix}_{timestamp_suffix}")
            generate_comparison_reports(output_base_path, comparison_results)
            
            success_count += 1
            print(f"\n✅ 场景 '{scenario.get('name')}' 执行成功")
            
        except Exception as e:
            fail_count += 1
            print(f"\n❌ 场景 '{scenario.get('name')}' 执行失败: {str(e)}")
            import traceback
            traceback.print_exc()
        
        print("")
    
    # 总结
    print(f"{'='*80}")
    print(f"执行完成: 成功 {success_count} 个, 失败 {fail_count} 个")
    print(f"{'='*80}")


if __name__ == "__main__":
    execute_comparison_from_config()
