#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
流程执行器模块
功能：执行接口数据获取和对比的各个步骤
"""

import os
import sys
from typing import Dict

# 添加父目录到路径，以便导入公共工具模块
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../..'))

# 动态导入job模块中的其他功能模块
import importlib.util

# job_dir就是当前文件所在目录（job文件夹）
job_dir = os.path.dirname(os.path.abspath(__file__))

# 动态导入获取接口数据模块
fetch_module_path = os.path.join(job_dir, "fetch_api_data.py")
spec_fetch = importlib.util.spec_from_file_location("fetch_api_data", fetch_module_path)
fetch_module = importlib.util.module_from_spec(spec_fetch)
spec_fetch.loader.exec_module(fetch_module)
ApiDataFetcher = fetch_module.ApiDataFetcher

# 动态导入对比接口数据模块
compare_module_path = os.path.join(job_dir, "compare_api_data.py")
spec_compare = importlib.util.spec_from_file_location("compare_data", compare_module_path)
compare_module = importlib.util.module_from_spec(spec_compare)
spec_compare.loader.exec_module(compare_module)
DataComparator = compare_module.DataComparator


def fetch_api_data_step(csv_file_path: str, output_file_path: str, api_url: str, 
                        cust_no_column: int, use_create_time_column: int,
                        thread_count: int, timeout: int, convert_feature_to_number: bool = True,
                        feature_start_column: int = 3, add_one_second: bool = False,
                        api_params: list = None):
    """
    获取接口数据（支持动态参数配置）
    
    Args:
        csv_file_path: 输入CSV文件路径
        output_file_path: 输出CSV文件路径
        api_url: 接口URL
        cust_no_column: cust_no所在列（兼容旧配置）
        use_create_time_column: use_create_time所在列（兼容旧配置）
        thread_count: 线程数
        timeout: 超时时间
        convert_feature_to_number: 是否将特征值转换为数值类型
        feature_start_column: 特征开始列
        add_one_second: 是否在请求接口时加1秒
        api_params: 接口参数配置列表（新增）
    """
    print(f"步骤1: 获取接口数据", end=" ... ")
    if add_one_second:
        print(f"(时间加1秒)", end=" ... ")
    
    # 创建数据获取器
    fetcher = ApiDataFetcher(
        api_url=api_url,
        param1_column=cust_no_column,
        param2_column=use_create_time_column,
        thread_count=thread_count,
        timeout=timeout,
        convert_feature_to_number=convert_feature_to_number,
        feature_start_column=feature_start_column,
        add_one_second=add_one_second,
        api_params=api_params  # 传递新的参数配置
    )
    
    # 执行数据获取
    fetcher.fetch_api_data(csv_file_path, output_file_path)
    print(f"完成")


def compare_data_step(original_csv_path: str, api_data_csv_path: str, output_csv_path: str,
                      cust_no_column: int, use_create_time_column: int, feature_start_column: int,
                      add_one_second: bool = False):
    """
    对比数据
    
    Args:
        original_csv_path: 原始CSV文件路径
        api_data_csv_path: 接口数据CSV文件路径
        output_csv_path: 输出CSV文件路径
        cust_no_column: cust_no所在列
        use_create_time_column: use_create_time所在列
        feature_start_column: 特征开始列
        add_one_second: 是否在请求接口时加1秒
    """
    print(f"步骤2: 对比数据", end=" ... ")
    
    # 创建对比器
    comparator = DataComparator(
        cust_no_column, use_create_time_column, feature_start_column, add_one_second
    )
    
    # 执行对比
    comparator.compare_files(original_csv_path, api_data_csv_path, output_csv_path)
    print(f"完成")


def execute_single_scenario(scenario_config: Dict, global_config: Dict, script_dir: str, timestamp_suffix: str, output_dir: str = None, input_dir: str = None):
    """
    执行单个场景的对比流程
    
    Args:
        scenario_config: 场景配置字典
        global_config: 全局配置字典
        script_dir: 脚本目录
        timestamp_suffix: 时间戳后缀
        output_dir: 输出目录（可选，默认使用script_dir）
        input_dir: 输入目录（可选，默认使用script_dir）
    
    Returns:
        bool: 执行是否成功
    """
    # 如果没有指定输出目录，使用脚本目录
    if output_dir is None:
        output_dir = script_dir
    # 如果没有指定输入目录，使用脚本目录（向后兼容）
    if input_dir is None:
        input_dir = script_dir
    # 从场景配置中获取参数，如果不存在则使用全局配置或默认值
    scenario_name = scenario_config.get('name', '未命名场景')
    input_csv_file = scenario_config.get('input_csv_file')
    output_file_prefix = scenario_config.get('output_file_prefix', '')
    api_url = scenario_config.get('api_url')
    thread_count = scenario_config.get('thread_count', global_config.get('default_thread_count', 150))
    timeout = scenario_config.get('timeout', global_config.get('default_timeout', 60))
    convert_feature_to_number = scenario_config.get('convert_feature_to_number', 
                                                     global_config.get('default_convert_feature_to_number', True))
    add_one_second = scenario_config.get('add_one_second', global_config.get('default_add_one_second', True))
    column_config = scenario_config.get('column_config', {})
    
    # 获取接口参数配置（新增）
    api_params = scenario_config.get('api_params')
    
    print(f"\n执行场景: {scenario_name}")
    
    # 构建文件路径（从inputdata目录读取）
    input_csv_path = os.path.join(input_dir, input_csv_file)
    
    # 检查输入文件是否存在
    if not os.path.exists(input_csv_path):
        print(f"  ❌ 错误: 输入文件不存在: {input_csv_path}")
        return False
    
    # 构建文件名前缀部分（如果配置了前缀）
    prefix_part = f"{output_file_prefix}_" if output_file_prefix else ""
    
    # 自动生成输出文件名（保存到outputdata目录）
    api_data_output_file = f"{prefix_part}{timestamp_suffix}_api_data.csv"
    compare_output_file = f"{prefix_part}{timestamp_suffix}_compare.csv"
    
    api_data_output_path = os.path.join(output_dir, api_data_output_file)
    compare_output_path = os.path.join(output_dir, compare_output_file)
    # 使用统一的多场景列索引配置文件
    config_file_path = os.path.join(script_dir, "json", "column_index_config.json")
    
    print(f"  输入文件: {input_csv_file}")
    print(f"  接口URL: {api_url}")
    print(f"  输出前缀: {output_file_prefix if output_file_prefix else '(无)'}")
    
    # 处理列索引配置（兼容新旧配置）
    if api_params:
        # 使用新的参数配置
        print(f"  接口参数配置:")
        for param in api_params:
            param_name = param.get('param_name')
            column_index = param.get('column_index')
            is_time_field = param.get('is_time_field', False)
            time_flag = " (时间字段)" if is_time_field else ""
            print(f"    - {param_name}: 列{column_index}{time_flag}")
        
        # 为了兼容对比步骤，从api_params中提取cust_no和时间字段的列索引
        cust_no_column = None
        use_create_time_column = None
        for param in api_params:
            if param.get('param_name') == 'custNo':
                cust_no_column = param.get('column_index')
            if param.get('is_time_field'):
                use_create_time_column = param.get('column_index')
        
        feature_start_column = column_config.get('feature_start_column', 4)
    else:
        # 使用旧的列配置（向后兼容）
        cust_no_column = column_config.get('cust_no_column')
        use_create_time_column = column_config.get('use_create_time_column')
        feature_start_column = column_config.get('feature_start_column', 4)
        
        # 检查列索引是否有效（必须手动配置）
        if cust_no_column is None or use_create_time_column is None:
            print(f"  ❌ 错误: 列索引配置无效或缺失")
            print(f"    请在配置文件的 column_config 中手动指定:")
            print(f"    - cust_no_column: cust_no所在列索引")
            print(f"    - use_create_time_column: 时间字段所在列索引")
            print(f"    - feature_start_column: 特征开始列索引（可选，默认4）")
            return False
        
        print(f"  列配置: cust_no=列{cust_no_column}, 时间字段=列{use_create_time_column}, 特征开始=列{feature_start_column}")
    
    if add_one_second:
        print(f"  时间处理: 请求接口时加1秒")
    
    try:
        # 步骤1: 获取接口数据
        fetch_api_data_step(
            input_csv_path,
            api_data_output_path,
            api_url,
            cust_no_column if cust_no_column is not None else 0,
            use_create_time_column if use_create_time_column is not None else 0,
            thread_count,
            timeout,
            convert_feature_to_number,
            feature_start_column,
            add_one_second,
            api_params  # 传递新的参数配置
        )
        
        # 步骤2: 对比数据
        compare_data_step(
            input_csv_path,
            api_data_output_path,
            compare_output_path,
            cust_no_column if cust_no_column is not None else 0,
            use_create_time_column if use_create_time_column is not None else 0,
            feature_start_column,
            add_one_second
        )
        
        # 完成
        print(f"  ✅ 场景执行成功")
        print(f"  输出文件:")
        print(f"    - {api_data_output_file}")
        print(f"    - {compare_output_file}")
        
        return True
        
    except Exception as e:
        print(f"  ❌ 执行失败: {str(e)}")
        import traceback
        traceback.print_exc()
        return False
