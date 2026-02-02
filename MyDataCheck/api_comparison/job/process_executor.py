#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
流程执行器模块
功能：执行接口数据获取和对比的各个步骤（内存优化版）
"""

import os
import sys
import gc
from typing import Dict

# 添加父目录到路径，以便导入公共工具模块
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../..'))

# 导入内存管理工具
from common.memory_manager import MemoryMonitor, cleanup_large_objects

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

# 动态导入流式对比模块
streaming_module_path = os.path.join(job_dir, "streaming_comparator.py")
spec_streaming = importlib.util.spec_from_file_location("streaming_comparator", streaming_module_path)
streaming_module = importlib.util.module_from_spec(spec_streaming)
spec_streaming.loader.exec_module(streaming_module)
StreamingComparator = streaming_module.StreamingComparator


def fetch_api_data_step(csv_file_path: str, output_file_path: str, api_url: str, 
                        cust_no_column: int, use_create_time_column: int,
                        thread_count: int, timeout: int, convert_feature_to_number: bool = True,
                        feature_start_column: int = 3, add_one_second: bool = False,
                        api_params: list = None, output_error_records: bool = True):
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
        output_error_records: 是否输出请求失败的记录到单独的CSV文件（默认True）
    """
    print(f"\n{'='*80}")
    print(f"步骤1: 获取接口数据")
    print(f"{'='*80}")
    if add_one_second:
        print(f"  时间处理: 请求接口时加1秒")
    print(f"  线程数: {thread_count}")
    print(f"  超时时间: {timeout}秒")
    print(f"  输入文件: {os.path.basename(csv_file_path)}")
    print(f"  输出文件: {os.path.basename(output_file_path)}")
    if output_error_records:
        print(f"  错误记录: 将输出到单独的CSV文件")
    print(f"{'='*80}")
    
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
    fetcher.fetch_api_data(csv_file_path, output_file_path, output_error_records=output_error_records)
    print(f"\n✅ 步骤1完成: 接口数据获取成功")
    print(f"{'='*80}\n")


def compare_data_step(original_csv_path: str, api_data_csv_path: str, output_csv_path: str,
                      cust_no_column: int, use_create_time_column: int, feature_start_column: int,
                      add_one_second: bool = False, output_merged_data: bool = True,
                      calculate_difference: bool = False):
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
        output_merged_data: 是否输出全量数据合并文件
        calculate_difference: 是否计算差值
    """
    print(f"\n{'='*80}")
    print(f"步骤2: 数据对比")
    print(f"{'='*80}")
    print(f"  原始文件: {os.path.basename(original_csv_path)}")
    print(f"  接口数据文件: {os.path.basename(api_data_csv_path)}")
    print(f"  输出文件前缀: {os.path.basename(output_csv_path).replace('.csv', '')}")
    print(f"  输出全量合并: {'是' if output_merged_data else '否'}")
    print(f"  计算差值: {'是' if calculate_difference else '否'}")
    print(f"{'='*80}")
    
    # 创建对比器
    comparator = DataComparator(
        cust_no_column, use_create_time_column, feature_start_column, add_one_second, calculate_difference
    )
    
    # 执行对比
    comparator.compare_files(original_csv_path, api_data_csv_path, output_csv_path, output_merged_data=output_merged_data)
    print(f"\n✅ 步骤2完成: 数据对比成功")
    print(f"{'='*80}\n")


def compare_data_in_memory_step(original_csv_path: str, output_csv_path: str, api_url: str,
                                cust_no_column: int, use_create_time_column: int,
                                thread_count: int, timeout: int, convert_feature_to_number: bool,
                                feature_start_column: int, add_one_second: bool, api_params: list):
    """
    直接在内存中对比数据，不写入中间文件
    
    Args:
        original_csv_path: 原始CSV文件路径
        output_csv_path: 输出CSV文件路径前缀
        api_url: 接口URL
        cust_no_column: cust_no所在列
        use_create_time_column: use_create_time所在列
        thread_count: 线程数
        timeout: 超时时间
        convert_feature_to_number: 是否将特征值转换为数值类型
        feature_start_column: 特征开始列
        add_one_second: 是否在请求接口时加1秒
        api_params: 接口参数配置列表
    """
    print(f"\n{'='*80}")
    print(f"内存对比模式: 获取接口数据并直接对比")
    print(f"{'='*80}")
    print(f"  线程数: {thread_count}")
    print(f"  超时时间: {timeout}秒")
    print(f"  输入文件: {os.path.basename(original_csv_path)}")
    print(f"{'='*80}")
    
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
        api_params=api_params
    )
    
    # 获取接口数据（返回内存中的数据，不写入文件）
    api_results = fetcher.fetch_api_data_in_memory(original_csv_path)
    
    print(f"\n✅ 接口数据获取完成，开始对比...")
    print(f"{'='*80}\n")
    
    # 创建对比器
    comparator = DataComparator(
        cust_no_column, use_create_time_column, feature_start_column, add_one_second
    )
    
    # 直接在内存中对比
    comparator.compare_in_memory(original_csv_path, api_results, output_csv_path)
    
    print(f"\n✅ 内存对比完成")
    print(f"{'='*80}\n")


def streaming_compare_step(original_csv_path: str, output_csv_path: str, api_url: str,
                           cust_no_column: int, use_create_time_column: int,
                           thread_count: int, timeout: int,
                           feature_start_column: int, add_one_second: bool, api_params: list,
                           batch_size: int = 50, calculate_difference: bool = False):
    """
    流式对比：边请求边对比边写入（最优方案，内存占用降低80-90%）
    
    Args:
        original_csv_path: 原始CSV文件路径
        output_csv_path: 输出CSV文件路径前缀
        api_url: 接口URL
        cust_no_column: cust_no所在列
        use_create_time_column: use_create_time所在列
        thread_count: 线程数
        timeout: 超时时间
        feature_start_column: 特征开始列
        add_one_second: 是否在请求接口时加1秒
        api_params: 接口参数配置列表
        batch_size: 批次大小
        calculate_difference: 是否计算差值
    """
    print(f"\n{'='*80}")
    print(f"流式对比模式: 边请求边对比边写入")
    print(f"{'='*80}")
    print(f"  线程数: {thread_count}")
    print(f"  超时时间: {timeout}秒")
    print(f"  批次大小: {batch_size}")
    print(f"  输入文件: {os.path.basename(original_csv_path)}")
    print(f"  计算差值: {'是' if calculate_difference else '否'}")
    print(f"{'='*80}")
    
    # 创建流式对比器
    comparator = StreamingComparator(
        api_url=api_url,
        param1_column=cust_no_column,
        param2_column=use_create_time_column,
        feature_start_column=feature_start_column,
        thread_count=thread_count,
        timeout=timeout,
        add_one_second=add_one_second,
        api_params=api_params,
        batch_size=batch_size,
        calculate_difference=calculate_difference
    )
    
    # 执行流式对比
    comparator.streaming_compare(original_csv_path, output_csv_path)
    
    print(f"\n✅ 流式对比完成")
    print(f"{'='*80}\n")


def execute_single_scenario(scenario_config: Dict, global_config: Dict, script_dir: str, timestamp_suffix: str, output_dir: str = None, input_dir: str = None, json_config: Dict = None):
    """
    执行单个场景的对比流程（内存优化版）
    
    Args:
        scenario_config: 场景配置字典
        global_config: 全局配置字典
        script_dir: 脚本目录
        timestamp_suffix: 时间戳后缀
        output_dir: 输出目录（可选，默认使用script_dir）
        input_dir: 输入目录（可选，默认使用script_dir）
        json_config: 完整的JSON配置（可选，用于读取顶层配置）
    
    Returns:
        bool: 执行是否成功
    """
    # 使用内存监控器
    with MemoryMonitor(f"场景执行", verbose=False) as monitor:
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
        batch_size = scenario_config.get('batch_size', global_config.get('default_batch_size', 50))
        convert_feature_to_number = scenario_config.get('convert_feature_to_number', 
                                                         global_config.get('default_convert_feature_to_number', True))
        add_one_second = scenario_config.get('add_one_second', global_config.get('default_add_one_second', True))
        calculate_difference = scenario_config.get('calculate_difference', False)  # 默认不计算差值
        column_config = scenario_config.get('column_config', {})
        
        # 获取接口参数配置（新增）
        api_params = scenario_config.get('api_params')
        
        # 获取输出控制配置（支持两种配置方式）
        # 优先从 global_config.output_config 读取，如果不存在则从顶层 json_config.output_config 读取
        output_config = global_config.get('output_config', {})
        if not output_config and json_config:
            output_config = json_config.get('output_config', {})
        output_intermediate_files = output_config.get('output_intermediate_files', True)  # 默认输出中间文件
        output_error_records = output_config.get('output_error_records', True)  # 默认输出错误记录
        
        print(f"\n{'='*80}")
        print(f"执行场景: {scenario_name}")
        print(f"{'='*80}")
        
        # 构建文件路径（从inputdata目录读取）
        input_csv_path = os.path.join(input_dir, input_csv_file)
        
        # 检查输入文件是否存在
        if not os.path.exists(input_csv_path):
            print(f"❌ 错误: 输入文件不存在: {input_csv_path}")
            print(f"{'='*80}\n")
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
        
        print(f"📋 场景配置信息:")
        print(f"  输入文件: {input_csv_file}")
        print(f"  接口URL: {api_url}")
        print(f"  输出前缀: {output_file_prefix if output_file_prefix else '(无)'}")
        print(f"  输出模式: {'完整输出（含中间文件）' if output_intermediate_files else '仅输出对比报告'}")
        print(f"  错误记录: {'输出到单独CSV文件' if output_error_records else '不输出'}")
        print(f"  计算差值: {'是' if calculate_difference else '否'}")
        print(f"  线程数: {thread_count}, 超时: {timeout}秒")
        
        # 处理列索引配置（兼容新旧配置）
        if api_params:
            # 使用新的参数配置
            print(f"\n📌 接口参数配置:")
            for param in api_params:
                param_name = param.get('param_name')
                column_index = param.get('column_index')
                is_time_field = param.get('is_time_field', False)
                time_flag = " (时间字段)" if is_time_field else ""
                print(f"  • {param_name}: 列{column_index}{time_flag}")
            
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
                print(f"\n❌ 错误: 列索引配置无效或缺失")
                print(f"  请在配置文件的 column_config 中手动指定:")
                print(f"  • cust_no_column: cust_no所在列索引")
                print(f"  • use_create_time_column: 时间字段所在列索引")
                print(f"  • feature_start_column: 特征开始列索引（可选，默认4）")
                print(f"{'='*80}\n")
                return False
            
            print(f"\n📌 列配置: cust_no=列{cust_no_column}, 时间字段=列{use_create_time_column}, 特征开始=列{feature_start_column}")
        
        if add_one_second:
            print(f"⏰ 时间处理: 请求接口时加1秒")
        
        print(f"{'='*80}")
        
        try:
            if output_intermediate_files:
                # 模式1: 完整输出模式 - 输出所有中间文件
                print(f"\n💾 使用完整输出模式")
                
                # 步骤1: 获取接口数据并写入文件
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
                    api_params,
                    output_error_records  # 传递错误记录输出配置
                )
                gc.collect()
                
                # 步骤2: 对比数据并输出所有文件
                compare_data_step(
                    input_csv_path,
                    api_data_output_path,
                    compare_output_path,
                    cust_no_column if cust_no_column is not None else 0,
                    use_create_time_column if use_create_time_column is not None else 0,
                    feature_start_column,
                    add_one_second,
                    output_merged_data=True,  # 完整模式输出全量合并
                    calculate_difference=calculate_difference  # 传递差值计算配置
                )
                gc.collect()
                
            else:
                # 模式2: 仅报告模式 - 流式对比，边请求边对比边写入
                print(f"\n⚡ 使用仅报告模式（流式对比）")
                
                # 流式对比：边请求边对比边写入，内存占用降低80-90%
                streaming_compare_step(
                    input_csv_path,
                    compare_output_path,
                    api_url,
                    cust_no_column if cust_no_column is not None else 0,
                    use_create_time_column if use_create_time_column is not None else 0,
                    thread_count,
                    timeout,
                    feature_start_column,
                    add_one_second,
                    api_params,
                    batch_size=batch_size,  # 使用配置的批次大小
                    calculate_difference=calculate_difference  # 传递差值计算配置
                )
                gc.collect()
            
            # 完成
            print(f"\n{'='*80}")
            print(f"✅ 场景执行成功: {scenario_name}")
            print(f"{'='*80}")
            print(f"📁 输出文件:")
            if output_intermediate_files:
                print(f"  • {api_data_output_file}")
                print(f"  • {compare_output_file.replace('.csv', '_全量数据合并.csv')}")
            print(f"  • {compare_output_file.replace('.csv', '_analysis_report.csv')}")
            print(f"  • {compare_output_file.replace('.csv', '_feature_stats.csv')}")
            print(f"{'='*80}\n")
            
            return True
            
        except Exception as e:
            print(f"\n{'='*80}")
            print(f"❌ 场景执行失败: {scenario_name}")
            print(f"{'='*80}")
            print(f"错误信息: {str(e)}")
            print(f"{'='*80}\n")
            import traceback
            traceback.print_exc()
            return False
        finally:
            # 确保在任何情况下都执行内存清理
            gc.collect()
