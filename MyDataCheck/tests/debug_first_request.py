#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
接口数据对比模块 - 调试脚本
功能：打印第一条数据的接口请求和接口返回值，用于调试
"""

import os
import sys
import json
import importlib.util
from datetime import datetime

# 添加父目录到路径，以便导入公共工具模块
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

# 动态导入job模块中的功能模块
script_dir = os.path.dirname(os.path.abspath(__file__))
job_dir = os.path.join(script_dir, "job")

# 动态导入配置管理模块
config_module_path = os.path.join(job_dir, "config_manager.py")
spec_config = importlib.util.spec_from_file_location("config_manager", config_module_path)
config_module = importlib.util.module_from_spec(spec_config)
spec_config.loader.exec_module(config_module)
load_config_from_json = config_module.load_config_from_json

# 动态导入CSV工具模块
csv_tool_path = os.path.join(script_dir, "..", "common", "csv_tool.py")
spec_csv = importlib.util.spec_from_file_location("csv_tool", csv_tool_path)
csv_tool_module = importlib.util.module_from_spec(spec_csv)
spec_csv.loader.exec_module(csv_tool_module)
read_csv_with_encoding = csv_tool_module.read_csv_with_encoding

# 动态导入fetch_api_data模块
fetch_api_data_path = os.path.join(job_dir, "fetch_api_data.py")
spec_fetch = importlib.util.spec_from_file_location("fetch_api_data", fetch_api_data_path)
fetch_api_data_module = importlib.util.module_from_spec(spec_fetch)
spec_fetch.loader.exec_module(fetch_api_data_module)
ApiDataFetcher = fetch_api_data_module.ApiDataFetcher

# 配置文件路径
CONFIG_JSON_FILE = "config.json"


def debug_first_request():
    """调试第一条数据的接口请求"""
    print("="*80)
    print("接口数据对比模块 - 调试脚本")
    print("功能：打印第一条数据的接口请求和接口返回值")
    print("="*80)
    print()
    
    # 加载配置
    config_file_path = os.path.join(script_dir, CONFIG_JSON_FILE)
    if not os.path.exists(config_file_path):
        print(f"❌ 错误: 配置文件不存在: {config_file_path}")
        return
    
    json_config = load_config_from_json(config_file_path)
    if not json_config:
        print(f"❌ 错误: 无法加载配置文件")
        return
    
    # 获取第一个启用的场景
    scenarios = json_config.get('scenarios', [])
    global_config = json_config.get('global_config', {})
    
    enabled_scenarios = [s for s in scenarios if s.get('enabled', True)]
    if not enabled_scenarios:
        print("❌ 错误: 没有启用的场景")
        return
    
    scenario = enabled_scenarios[0]
    scenario_name = scenario.get('name', '未命名场景')
    
    print(f"使用场景: {scenario_name}")
    print()
    
    # 获取配置参数
    input_csv_file = scenario.get('input_csv_file', '')
    api_url = scenario.get('api_url', '')
    thread_count = scenario.get('thread_count', global_config.get('default_thread_count', 150))
    timeout = scenario.get('timeout', global_config.get('default_timeout', 60))
    convert_feature_to_number = scenario.get('convert_feature_to_number', 
                                             global_config.get('default_convert_feature_to_number', True))
    add_one_second = scenario.get('add_one_second', global_config.get('default_add_one_second', True))
    column_config = scenario.get('column_config', {})
    
    cust_no_column = column_config.get('cust_no_column', 0)
    use_create_time_column = column_config.get('use_create_time_column', 2)
    feature_start_column = column_config.get('feature_start_column', 3)
    
    # 构建输入文件路径
    input_data_dir = os.path.join(script_dir, "..", "inputdata", "api_comparison")
    input_csv_path = os.path.join(input_data_dir, input_csv_file)
    
    if not os.path.exists(input_csv_path):
        print(f"❌ 错误: 输入文件不存在: {input_csv_path}")
        return
    
    print(f"输入文件: {input_csv_path}")
    print(f"接口URL: {api_url}")
    print(f"列配置: cust_no=列{cust_no_column}, 时间字段=列{use_create_time_column}, 特征开始=列{feature_start_column}")
    print(f"时间处理: {'请求接口时加1秒' if add_one_second else '不加1秒'}")
    print()
    
    # 读取CSV文件
    print("读取CSV文件...")
    headers, rows = read_csv_with_encoding(input_csv_path)
    
    if not rows:
        print("❌ 错误: CSV文件中没有数据行")
        return
    
    print(f"CSV文件: {len(rows)} 行数据, {len(headers)} 列")
    print(f"表头: {headers[:5]}..." if len(headers) > 5 else f"表头: {headers}")
    print()
    
    # 获取第一条数据
    first_row = rows[0]
    print("="*80)
    print("第一条数据:")
    print("="*80)
    
    # 检查列索引
    if cust_no_column >= len(first_row) or use_create_time_column >= len(first_row):
        print(f"❌ 错误: 列索引超出范围")
        print(f"  行长度: {len(first_row)}")
        print(f"  cust_no列索引: {cust_no_column}")
        print(f"  时间列索引: {use_create_time_column}")
        return
    
    # 获取主键值
    cust_no = first_row[cust_no_column].strip() if cust_no_column < len(first_row) and first_row[cust_no_column] else ""
    time_value = first_row[use_create_time_column].strip() if use_create_time_column < len(first_row) and first_row[use_create_time_column] else ""
    
    print(f"cust_no列 ({headers[cust_no_column] if cust_no_column < len(headers) else 'N/A'}): {cust_no}")
    print(f"时间列 ({headers[use_create_time_column] if use_create_time_column < len(headers) else 'N/A'}): {time_value}")
    print()
    
    if not cust_no:
        print("❌ 错误: cust_no为空")
        return
    
    if not time_value:
        print("❌ 错误: 时间字段为空")
        return
    
    # 创建ApiDataFetcher实例
    fetcher = ApiDataFetcher(
        api_url=api_url,
        param1_column=cust_no_column,
        param2_column=use_create_time_column,
        thread_count=thread_count,
        timeout=timeout,
        convert_feature_to_number=convert_feature_to_number,
        feature_start_column=feature_start_column,
        add_one_second=add_one_second
    )
    
    # 处理时间字段（模拟process_row中的处理逻辑）
    print("="*80)
    print("时间字段处理:")
    print("="*80)
    print(f"原始时间值: {time_value}")
    
    # 去除字母'a'
    original_time = time_value.strip()
    if 'a' in original_time or 'A' in original_time:
        time_value_cleaned = original_time.replace('a', '').replace('A', '')
        print(f"去除字母'a'后: {time_value_cleaned}")
    else:
        time_value_cleaned = original_time
        print("时间字段不包含字母'a'")
    
    # 标准化时间格式
    base_time = fetcher.normalize_timestamp(time_value_cleaned)
    print(f"标准化后: {base_time}")
    
    # 根据配置决定是否加1秒
    if add_one_second:
        request_time = fetcher._add_one_second(base_time)
        print(f"加1秒后: {request_time}")
    else:
        request_time = base_time
        print("未启用加1秒功能")
    
    print()
    
    # 打印请求信息
    print("="*80)
    print("接口请求信息:")
    print("="*80)
    print(f"请求URL: {api_url}")
    print(f"请求参数:")
    print(f"  cust_no: {cust_no}")
    print(f"  use_create_time: {request_time}")
    print()
    
    # 发送请求
    print("="*80)
    print("发送接口请求...")
    print("="*80)
    
    try:
        api_response = fetcher.send_request(cust_no, request_time)
        
        if api_response is None:
            print("❌ 接口请求失败")
            return
        
        # 打印响应信息
        print("="*80)
        print("接口响应信息:")
        print("="*80)
        print(f"响应状态: 成功")
        print(f"响应数据类型: {type(api_response).__name__}")
        print()
        
        # 格式化打印JSON响应
        print("响应内容:")
        print("-"*80)
        if isinstance(api_response, dict):
            print(json.dumps(api_response, ensure_ascii=False, indent=2))
        else:
            print(str(api_response))
        print("-"*80)
        print()
        
        # 统计响应字段
        if isinstance(api_response, dict):
            print(f"响应字段数量: {len(api_response)}")
            print(f"响应字段列表: {list(api_response.keys())[:10]}{'...' if len(api_response) > 10 else ''}")
        
        print("="*80)
        print("调试完成")
        print("="*80)
        
    except Exception as e:
        print(f"❌ 请求异常: {str(e)}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    debug_first_request()
