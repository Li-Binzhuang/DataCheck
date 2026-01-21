#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
线上灰度落数对比 - 主执行脚本c
功能：协调各个模块，执行完整的JSON解析和数据对比流程
"""

import os
import sys
import json
import importlib.util
from datetime import datetime

# 添加job目录到路径
script_dir = os.path.dirname(os.path.abspath(__file__))
job_dir = os.path.join(script_dir, "job")
sys.path.insert(0, job_dir)

# 动态导入job模块
json_parser_path = os.path.join(job_dir, "JSON解析器.py")
spec_parser = importlib.util.spec_from_file_location("json_parser", json_parser_path)
json_parser_module = importlib.util.module_from_spec(spec_parser)
spec_parser.loader.exec_module(json_parser_module)
parse_json_to_csv = json_parser_module.parse_json_to_csv

data_comparator_path = os.path.join(job_dir, "数据对比器.py")
spec_comparator = importlib.util.spec_from_file_location("data_comparator", data_comparator_path)
data_comparator_module = importlib.util.module_from_spec(spec_comparator)
spec_comparator.loader.exec_module(data_comparator_module)
compare_csv_files = data_comparator_module.compare_csv_files

report_generator_path = os.path.join(job_dir, "报告生成器.py")
spec_report = importlib.util.spec_from_file_location("report_generator", report_generator_path)
report_generator_module = importlib.util.module_from_spec(spec_report)
spec_report.loader.exec_module(report_generator_module)
generate_reports = report_generator_module.generate_reports


def load_config(config_path: str = None) -> dict:
    """加载配置文件"""
    if config_path is None:
        script_dir = os.path.dirname(os.path.abspath(__file__))
        config_path = os.path.join(script_dir, "config.json")
    
    if not os.path.exists(config_path):
        raise FileNotFoundError(f"配置文件不存在: {config_path}")
    
    with open(config_path, 'r', encoding='utf-8') as f:
        config = json.load(f)
    
    return config


def main():
    """主函数"""
    print("="*80)
    print("线上灰度落数对比 - 完整流程")
    print("="*80)
    
    # 获取脚本所在目录
    script_dir = os.path.dirname(os.path.abspath(__file__))
    
    try:
        # 加载配置
        config = load_config()
        
        online_file = config.get("online_file")
        offline_file = config.get("offline_file")
        json_column = config.get("json_column")
        online_key_column_index = config.get("online_key_column", 0)  # A列=0，B列=1
        offline_key_column_index = config.get("offline_key_column", 1)  # A列=0，B列=1
        # 支持分别设置两个文件的特征起始列索引
        online_feature_start_column = config.get("online_feature_start_column")
        offline_feature_start_column = config.get("offline_feature_start_column")
        # 兼容旧配置：如果新配置不存在，使用旧的feature_start_column
        if online_feature_start_column is None:
            online_feature_start_column = config.get("feature_start_column", 3)
        if offline_feature_start_column is None:
            offline_feature_start_column = config.get("feature_start_column", 3)
        convert_string_to_number = config.get("convert_string_to_number", False)
        output_prefix = config.get("output_prefix", "")
        
        # 生成时间戳后缀（格式：MMDDHHmm，例如：10081950 表示10月8日19:50）
        now = datetime.now()
        timestamp_suffix = now.strftime("%m%d%H%M")  # 月日时分，例如：10081950
        
        # 构建文件路径
        online_file_path = os.path.join(script_dir, online_file)
        offline_file_path = os.path.join(script_dir, offline_file)
        
        # 生成输出文件路径（带前缀和时间戳）
        prefix_part = f"{output_prefix}_" if output_prefix else ""
        parsed_online_csv = os.path.join(script_dir, f"{prefix_part}{timestamp_suffix}_解析后.csv")
        output_base_path = os.path.join(script_dir, f"{prefix_part}{timestamp_suffix}_对比结果")
        
        print(f"\n开始执行完整流程...")
        print(f"配置文件: {os.path.join(script_dir, 'config.json')}")
        print(f"线上文件: {online_file_path}")
        print(f"离线文件: {offline_file_path}")
        print(f"JSON列: {json_column}")
        print(f"在线文件主键列索引: {online_key_column_index} (A列=0, B列=1)")
        print(f"离线文件主键列索引: {offline_key_column_index} (A列=0, B列=1)")
        print(f"在线文件特征列起始索引: {online_feature_start_column}")
        print(f"离线文件特征列起始索引: {offline_feature_start_column}")
        print(f"字符串转数值: {convert_string_to_number}")
        print(f"输出文件前缀: {output_prefix}")
        print(f"时间戳后缀: {timestamp_suffix}")
        
        # 检查输入文件是否存在
        if not os.path.exists(online_file_path):
            raise FileNotFoundError(f"线上文件不存在: {online_file_path}")
        
        if not os.path.exists(offline_file_path):
            raise FileNotFoundError(f"离线文件不存在: {offline_file_path}")
        
        # 步骤1：解析JSON数据
        parsed_file = parse_json_to_csv(
            online_file_path,
            parsed_online_csv,
            json_column,
            online_key_column_index,
            convert_string_to_number
        )
        
        # 步骤2：执行数据对比
        (differences_dict, matches_dict, all_features, feature_stats, matched_count,
         unmatched_count, unmatched_rows, headers_online, headers_offline,
         total_comparisons, match_count, diff_count, match_ratio,
         online_only_rows, online_only_count, rows_online, rows_offline) = compare_csv_files(
            parsed_file,
            offline_file_path,
            online_key_column_index,
            offline_key_column_index,
            online_feature_start_column,
            offline_feature_start_column,
            original_online_file_path=online_file_path  # 传递原始线上文件路径
        )
        
        # 步骤3：生成报告
        print(f"\n开始生成报告...")
        generate_reports(
            output_base_path,
            differences_dict,
            all_features,
            feature_stats,
            matched_count,
            total_comparisons,
            match_count,
            diff_count,
            match_ratio,
            unmatched_rows,
            online_only_rows,
            headers_offline,
            headers_online,
            rows_offline,
            rows_online,
            offline_key_column_index,
            online_key_column_index,
            offline_feature_start_column,
            online_feature_start_column
        )
        
        print(f"\n{'='*80}")
        print(f"完整流程执行完成！")
        print(f"{'='*80}")
        print(f"生成的文件:")
        print(f"  1. 解析后的在线数据: {parsed_file}")
        
        # 显示生成的文件
        print(f"  2. 差异特征汇总: {output_base_path}_差异特征汇总.csv")
        print(f"  3. 差异数据明细: {output_base_path}_差异数据明细.csv")
        print(f"  4. 特征统计: {output_base_path}_特征统计.csv")
        print(f"  5. 全量数据合并: {output_base_path}_全量数据合并.csv")
        
        if unmatched_count > 0:
            print(f"  6. 仅在离线表中的数据: {output_base_path}_仅在离线表中的数据.csv (共 {unmatched_count} 条)")
        
        if online_only_count > 0:
            print(f"  7. 仅在线上文件中的数据: {output_base_path}_仅在线上文件中的数据.csv (共 {online_only_count} 条)")
        
        print(f"{'='*80}")
        
    except Exception as e:
        print(f"\n执行失败: {str(e)}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    main()
