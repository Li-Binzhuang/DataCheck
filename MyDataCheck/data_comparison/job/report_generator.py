#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
报告生成器模块
功能：生成数据对比报告
"""

import os
import sys
import csv
import subprocess
import platform

# 添加公共工具目录到路径
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../../common'))


def _open_output_folder(folder_path: str):
    """
    自动打开输出文件夹
    
    Args:
        folder_path: 文件夹路径
    """
    try:
        if platform.system() == "Darwin":  # macOS
            subprocess.run(["open", folder_path], check=True)
        elif platform.system() == "Windows":
            subprocess.run(["explorer", folder_path], check=True)
        else:  # Linux
            subprocess.run(["xdg-open", folder_path], check=True)
        print(f"📂 已打开输出文件夹: {folder_path}")
    except Exception as e:
        print(f"⚠️ 无法自动打开文件夹: {e}")


def generate_comparison_reports(
    output_base_path: str,
    comparison_results: dict,
    output_full_data: bool = False
):
    """
    生成数据对比报告
    
    Args:
        output_base_path: 输出文件基础路径（不含扩展名）
        comparison_results: 对比结果字典
        output_full_data: 是否输出全量数据合并文件
    """
    differences_dict = comparison_results["differences_dict"]
    all_features = comparison_results["all_features"]
    feature_stats = comparison_results["feature_stats"]
    matched_count = comparison_results["matched_count"]
    total_comparisons = comparison_results["total_comparisons"]
    match_count = comparison_results["match_count"]
    diff_count = comparison_results["diff_count"]
    match_ratio = comparison_results["match_ratio"]
    unmatched_rows = comparison_results["unmatched_rows"]
    sql_only_rows = comparison_results["sql_only_rows"]
    headers_sql = comparison_results["headers_sql"]
    headers_api = comparison_results["headers_api"]
    rows_sql = comparison_results["rows_sql"]
    rows_api = comparison_results["rows_api"]
    sql_key_column = comparison_results["sql_key_column"]
    api_key_column = comparison_results["api_key_column"]
    sql_feature_start = comparison_results["sql_feature_start"]
    api_feature_start = comparison_results["api_feature_start"]
    key_column_name = comparison_results.get("key_column_name", "主键值")
    time_column_name = comparison_results.get("time_column_name", "时间")
    
    print(f"\n开始生成报告...")
    
    # 1. 生成差异特征汇总
    summary_file = f"{output_base_path}_差异特征汇总.csv"
    with open(summary_file, 'w', newline='', encoding='utf-8-sig') as f:
        writer = csv.writer(f)
        writer.writerow(['特征名', '差异数量', '总对比次数', '差异占比(%)'])
        
        # 按差异数量降序排序
        sorted_features = sorted(
            [(feature, stats) for feature, stats in feature_stats.items() if stats["diff_count"] > 0],
            key=lambda x: x[1]["diff_count"],
            reverse=True
        )
        
        for feature, stats in sorted_features:
            diff_ratio = stats["diff_count"] / matched_count * 100 if matched_count > 0 else 0
            writer.writerow([feature, stats["diff_count"], stats["total"], f"{diff_ratio:.2f}"])
    
    print(f"✅ 差异特征汇总已保存: {summary_file}")
    
    # 2. 生成差异数据明细
    detail_file = f"{output_base_path}_差异数据明细.csv"
    with open(detail_file, 'w', newline='', encoding='utf-8-sig') as f:
        writer = csv.writer(f)
        writer.writerow([key_column_name, time_column_name, 'cust_no', '特征名', '接口/灰度/从库值', '模型特征样本值'])
        
        # 按主键值和特征名排序
        sorted_diffs = sorted(differences_dict.items(), key=lambda x: (x[0][0], x[0][1]))
        
        for (key_value, feature), diff_data in sorted_diffs:
            # 兼容旧格式(3个值)和新格式(4个值)
            if len(diff_data) == 4:
                api_value, sql_value, cust_no, time_value = diff_data
            else:
                api_value, sql_value, cust_no = diff_data
                time_value = ""
            writer.writerow([key_value, time_value, cust_no, feature, api_value, sql_value])
    
    print(f"✅ 差异数据明细已保存: {detail_file}")
    
    # 3. 生成特征统计
    stats_file = f"{output_base_path}_特征统计.csv"
    with open(stats_file, 'w', newline='', encoding='utf-8-sig') as f:
        writer = csv.writer(f)
        writer.writerow(['特征名', '总对比次数', '一致数量', '差异数量', '一致率(%)'])
        
        for feature in sorted(all_features):
            stats = feature_stats.get(feature, {"total": 0, "diff_count": 0})
            match_count_feature = stats["total"] - stats["diff_count"]
            match_ratio_feature = match_count_feature / stats["total"] * 100 if stats["total"] > 0 else 0
            writer.writerow([
                feature,
                stats["total"],
                match_count_feature,
                stats["diff_count"],
                f"{match_ratio_feature:.2f}"
            ])
    
    print(f"✅ 特征统计已保存: {stats_file}")
    
    # 4. 生成全量数据合并（包含对比结果标记）- 仅在配置开启时生成
    if output_full_data:
        merged_file = f"{output_base_path}_全量数据合并.csv"
        with open(merged_file, 'w', newline='', encoding='utf-8-sig') as f:
            writer = csv.writer(f)
            
            # 构建表头
            header = ['主键值', '数据来源', '对比结果']
            # 添加所有特征列
            header.extend(all_features)
            writer.writerow(header)
            
            # 写入接口/灰度/从库特征表数据
            for row in rows_api:
                if api_key_column >= len(row):
                    continue
                
                key_value = str(row[api_key_column]).strip() if row[api_key_column] is not None else ""
                if not key_value:
                    continue
                
                # 判断对比结果
                has_diff = any((key_value, feature) in differences_dict for feature in all_features)
                result = "有差异" if has_diff else "一致"
                
                row_data = [key_value, "接口/灰度/从库", result]
                
                # 添加特征值
                for feature in all_features:
                    api_idx = api_feature_start + headers_api[api_feature_start:].index(feature) if feature in headers_api[api_feature_start:] else None
                    if api_idx is not None and api_idx < len(row):
                        row_data.append(row[api_idx] if row[api_idx] is not None else "")
                    else:
                        row_data.append("")
                
                writer.writerow(row_data)
            
            # 写入模型特征表数据
            for row in rows_sql:
                if sql_key_column >= len(row):
                    continue
                
                key_value = str(row[sql_key_column]).strip() if row[sql_key_column] is not None else ""
                if not key_value:
                    continue
                
                # 判断对比结果
                has_diff = any((key_value, feature) in differences_dict for feature in all_features)
                result = "有差异" if has_diff else "一致"
                
                row_data = [key_value, "模型特征表", result]
                
                # 添加特征值
                for feature in all_features:
                    sql_idx = sql_feature_start + headers_sql[sql_feature_start:].index(feature) if feature in headers_sql[sql_feature_start:] else None
                    if sql_idx is not None and sql_idx < len(row):
                        row_data.append(row[sql_idx] if row[sql_idx] is not None else "")
                    else:
                        row_data.append("")
                
                writer.writerow(row_data)
        
        print(f"✅ 全量数据合并已保存: {merged_file}")
    else:
        print(f"[INFO] 跳过全量数据合并文件生成（未勾选输出选项）")
    
    # 5. 生成仅在接口/灰度/从库特征表中的数据
    if len(unmatched_rows) > 0:
        api_only_file = f"{output_base_path}_仅在接口灰度从库中的数据.csv"
        with open(api_only_file, 'w', newline='', encoding='utf-8-sig') as f:
            writer = csv.writer(f)
            writer.writerow(headers_api)
            writer.writerows(unmatched_rows)
        print(f"✅ 仅在接口/灰度/从库中的数据已保存: {api_only_file} (共 {len(unmatched_rows)} 条)")
    
    # 6. 生成仅在模型特征表中的数据
    if len(sql_only_rows) > 0:
        sql_only_file = f"{output_base_path}_仅在模型特征表中的数据.csv"
        with open(sql_only_file, 'w', newline='', encoding='utf-8-sig') as f:
            writer = csv.writer(f)
            writer.writerow(headers_sql)
            writer.writerows(sql_only_rows)
        print(f"✅ 仅在模型特征表中的数据已保存: {sql_only_file} (共 {len(sql_only_rows)} 条)")
    
    print(f"\n{'='*80}")
    print(f"报告生成完成！")
    print(f"{'='*80}")
    print(f"生成的文件:")
    print(f"  1. 差异特征汇总: {summary_file}")
    print(f"  2. 差异数据明细: {detail_file}")
    print(f"  3. 特征统计: {stats_file}")
    if output_full_data:
        print(f"  4. 全量数据合并: {merged_file}")
    if len(unmatched_rows) > 0:
        print(f"  5. 仅在接口/灰度/从库中的数据: {api_only_file} (共 {len(unmatched_rows)} 条)")
    if len(sql_only_rows) > 0:
        print(f"  6. 仅在模型特征表中的数据: {sql_only_file} (共 {len(sql_only_rows)} 条)")
    print(f"{'='*80}")
    
    # 自动打开输出文件夹
    output_dir = os.path.dirname(output_base_path)
    _open_output_folder(output_dir)
