#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
检测CSV文件中cust_no和use_create_time所在的列索引
功能：自动检测CSV文件表头，找到cust_no和use_create_time所在的列位置
"""

import os
import sys
import json
from typing import Dict, Optional, Tuple

# 添加父目录到路径，以便导入公共工具模块
# job文件夹在场景1_接口数据对比下，公共工具在上一级目录
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../..'))

# 导入公共工具模块
from common.csv_tool import read_csv_with_encoding


def detect_column_indices(csv_path: str) -> Dict[str, Optional[int]]:
    """
    检测CSV文件中cust_no和use_create_time所在的列索引
    
    Args:
        csv_path: CSV文件路径
    
    Returns:
        包含列索引的字典: {
            'cust_no_column': int or None,
            'use_create_time_column': int or None,
            'feature_start_column': int (默认4)
        }
    """
    # 读取CSV文件表头
    try:
        headers, _ = read_csv_with_encoding(csv_path)
    except Exception as e:
        print(f"❌ 读取CSV文件失败: {str(e)}")
        return {
            'cust_no_column': None,
            'use_create_time_column': None,
            'feature_start_column': 4
        }
    
    # 检测cust_no所在列
    cust_no_column = None
    cust_no_variants = ['cust_no', 'custNo', 'CUST_NO', 'customer_no', 'customerNo']
    
    for i, header in enumerate(headers):
        header_lower = header.lower().strip()
        if header_lower in [v.lower() for v in cust_no_variants]:
            cust_no_column = i
            print(f"  ✅ cust_no: 列 {i} ({header})")
            break
    
    if cust_no_column is None:
        print(f"  ⚠️  未找到 cust_no 列")
    
    # 检测时间字段所在列（支持多种时间字段名）
    use_create_time_column = None
    time_variants = [
        'use_create_time', 'useCreateTime', 'USE_CREATE_TIME',
        'create_time', 'createTime', 'CREATE_TIME',
        'ua_time', 'uaTime', 'UA_TIME',
        'use_credit_create_time', 'useCreditCreateTime'
    ]
    
    for i, header in enumerate(headers):
        header_lower = header.lower().strip()
        if header_lower in [v.lower() for v in time_variants]:
            use_create_time_column = i
            print(f"  ✅ 时间字段: 列 {i} ({header})")
            break
    
    if use_create_time_column is None:
        print(f"  ⚠️  未找到时间字段列")
    
    # 确定特征开始列（默认在cust_no和use_create_time之后）
    feature_start_column = 4  # 默认值
    if cust_no_column is not None and use_create_time_column is not None:
        # 特征列从这两个列的最大索引+1开始
        feature_start_column = max(cust_no_column, use_create_time_column) + 1
    elif cust_no_column is not None:
        feature_start_column = cust_no_column + 1
    elif use_create_time_column is not None:
        feature_start_column = use_create_time_column + 1
    
    result = {
        'cust_no_column': cust_no_column,
        'use_create_time_column': use_create_time_column,
        'feature_start_column': feature_start_column,
        'headers': headers  # 保存表头信息用于参考
    }
    
    return result


def save_config(config: Dict, output_path: str, scenario_name: str = None, input_file: str = None):
    """
    保存配置到JSON文件（支持多场景格式）
    
    Args:
        config: 配置字典
        output_path: 输出文件路径
        scenario_name: 场景名称（如果提供，则保存为多场景格式）
        input_file: 输入文件名（可选，用于记录）
    """
    from datetime import datetime
    
    # 只保存列索引，不保存headers
    config_to_save = {
        'cust_no_column': config['cust_no_column'],
        'use_create_time_column': config['use_create_time_column'],
        'feature_start_column': config['feature_start_column']
    }
    
    # 如果提供了场景名，使用多场景格式
    if scenario_name:
        # 读取现有配置（如果文件存在）
        all_configs = {}
        if os.path.exists(output_path):
            try:
                with open(output_path, 'r', encoding='utf-8') as f:
                    existing_data = json.load(f)
                    if isinstance(existing_data, dict) and 'scenarios' in existing_data:
                        all_configs = existing_data.get('scenarios', {})
            except:
                all_configs = {}
        
        # 更新当前场景的配置
        scenario_config = {
            'cust_no_column': config_to_save['cust_no_column'],
            'use_create_time_column': config_to_save['use_create_time_column'],
            'feature_start_column': config_to_save['feature_start_column'],
            'last_updated': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        }
        if input_file:
            scenario_config['input_file'] = input_file
        
        all_configs[scenario_name] = scenario_config
        
        # 保存为多场景格式
        final_config = {
            '说明': {
                '文件用途': '存储所有场景的列索引配置（自动检测结果）',
                '使用方式': '此文件由系统自动生成和维护，通常不需要手动编辑',
                '文件格式': '按场景名称组织，每个场景包含其检测到的列索引信息',
                '更新时机': '当 auto_detect_columns=true 时，每次执行会自动更新对应场景的配置'
            },
            'scenarios': all_configs
        }
        
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(final_config, f, indent=2, ensure_ascii=False)
    else:
        # 单场景格式（向后兼容）
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(config_to_save, f, indent=2, ensure_ascii=False)


def load_config(config_path: str, scenario_name: str = None) -> Dict:
    """
    从JSON文件加载配置（支持多场景格式）
    
    Args:
        config_path: 配置文件路径
        scenario_name: 场景名称（如果提供，则从多场景格式中读取特定场景）
    
    Returns:
        配置字典
    """
    try:
        with open(config_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        # 如果是多场景格式
        if isinstance(data, dict) and 'scenarios' in data:
            if scenario_name:
                scenarios = data.get('scenarios', {})
                if scenario_name in scenarios:
                    scenario_config = scenarios[scenario_name]
                    config = {
                        'cust_no_column': scenario_config.get('cust_no_column'),
                        'use_create_time_column': scenario_config.get('use_create_time_column'),
                        'feature_start_column': scenario_config.get('feature_start_column', 4)
                    }
                    return config
                else:
                    return {
                        'cust_no_column': None,
                        'use_create_time_column': None,
                        'feature_start_column': 4
                    }
            else:
                # 如果没有指定场景名，返回第一个场景的配置（向后兼容）
                scenarios = data.get('scenarios', {})
                if scenarios:
                    first_scenario = list(scenarios.values())[0]
                    config = {
                        'cust_no_column': first_scenario.get('cust_no_column'),
                        'use_create_time_column': first_scenario.get('use_create_time_column'),
                        'feature_start_column': first_scenario.get('feature_start_column', 4)
                    }
                    return config
        
        # 单场景格式（向后兼容）
        return data
        
    except Exception as e:
        print(f"❌ 加载配置失败: {str(e)}")
        return {
            'cust_no_column': None,
            'use_create_time_column': None,
            'feature_start_column': 4
        }


def print_config_summary(config: Dict):
    """
    打印配置摘要
    
    Args:
        config: 配置字典
    """
    print(f"\n{'='*60}")
    print(f"列索引配置摘要")
    print(f"{'='*60}")
    print(f"cust_no 所在列: {config['cust_no_column']}")
    print(f"use_create_time 所在列: {config['use_create_time_column']}")
    print(f"特征开始列: {config['feature_start_column']}")
    print(f"{'='*60}\n")


def main():
    """主函数"""
    print("="*60)
    print("CSV文件列索引检测工具")
    print("="*60)
    
    # 获取脚本所在目录
    script_dir = os.path.dirname(os.path.abspath(__file__))
    
    # 默认输入文件路径（可以根据实际情况修改）
    csv_file = os.path.join(script_dir, "0106_data_qx_6_lx.csv")
    
    # 配置文件路径
    config_file = os.path.join(script_dir, "column_index_config.json")
    
    # 检查是否提供了命令行参数
    if len(sys.argv) > 1:
        csv_file = sys.argv[1]
    
    if len(sys.argv) > 2:
        config_file = sys.argv[2]
    
    # 检查文件是否存在
    if not os.path.exists(csv_file):
        print(f"\n❌ CSV文件不存在: {csv_file}")
        print(f"\n使用方法:")
        print(f"  python detect_column_index.py [CSV文件路径] [配置文件路径]")
        print(f"\n示例:")
        print(f"  python detect_column_index.py 0106_data_qx_6_lx.csv column_index_config.json")
        return
    
    # 检测列索引
    config = detect_column_indices(csv_file)
    
    # 打印配置摘要
    print_config_summary(config)
    
    # 检查是否成功检测到所有必需的列
    if config['cust_no_column'] is None:
        print("⚠️  警告: 未检测到 cust_no 列，请手动检查文件表头")
    
    if config['use_create_time_column'] is None:
        print("⚠️  警告: 未检测到 use_create_time 列，请手动检查文件表头")
    
    # 保存配置
    if config['cust_no_column'] is not None and config['use_create_time_column'] is not None:
        save_config(config, config_file)
        print(f"\n💡 提示: 可以在其他脚本中使用此配置文件")
        print(f"   配置文件路径: {config_file}")
    else:
        print(f"\n⚠️  由于未检测到所有必需的列，未保存配置文件")
        print(f"   请手动检查CSV文件表头，确认列名是否正确")


if __name__ == "__main__":
    main()
