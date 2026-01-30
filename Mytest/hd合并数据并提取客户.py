#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
合并多个分析报告文件，提取异常特征
策略：按特征名去重，优先选择异常最多的客户+时间组合
"""

import pandas as pd
import glob
import os
from collections import defaultdict


def merge_analysis_reports(input_pattern: str, output_file: str):
    """
    合并多个分析报告文件
    
    Args:
        input_pattern: 输入文件匹配模式（如 "*_analysis_report.csv"）
        output_file: 输出文件路径
    """
    print("=" * 80)
    print("合并分析报告文件")
    print("=" * 80)
    
    # 查找所有匹配的文件
    files = glob.glob(input_pattern)
    if not files:
        print(f"❌ 未找到匹配的文件: {input_pattern}")
        return
    
    print(f"\n找到 {len(files)} 个文件:")
    for f in files:
        print(f"  • {os.path.basename(f)}")
    
    # 读取所有文件并合并
    print(f"\n正在读取文件...")
    all_data = []
    
    for file in files:
        try:
            df = pd.read_csv(file, encoding='utf-8')
            print(f"  ✅ {os.path.basename(file)}: {len(df)} 行")
            all_data.append(df)
        except Exception as e:
            print(f"  ❌ {os.path.basename(file)}: 读取失败 - {str(e)}")
    
    if not all_data:
        print(f"\n❌ 没有成功读取任何文件")
        return
    
    # 合并所有数据
    merged_df = pd.concat(all_data, ignore_index=True)
    print(f"\n合并后总行数: {len(merged_df)}")
    
    # 检查列名
    print(f"\n列名: {list(merged_df.columns)}")
    
    # 统计每个客户+时间组合的异常特征数量
    print(f"\n正在统计每个客户+时间组合的异常特征数量...")
    
    # 创建客户+时间的唯一标识
    merged_df['customer_time_key'] = merged_df['cust_no'].astype(str) + '_' + merged_df['use_create_time'].astype(str)
    
    # 统计每个客户+时间组合的异常特征数量
    customer_time_stats = merged_df.groupby('customer_time_key').agg({
        'cust_no': 'first',
        'use_create_time': 'first',
        '特征名': 'count'  # 统计异常特征数量
    }).rename(columns={'特征名': 'anomaly_count'})
    
    # 按异常数量降序排序
    customer_time_stats = customer_time_stats.sort_values('anomaly_count', ascending=False)
    
    print(f"\n客户+时间组合统计（前10个）:")
    print(f"  {'客户号':<20} {'时间':<30} {'异常特征数':<10}")
    print(f"  {'-'*20} {'-'*30} {'-'*10}")
    for idx, row in customer_time_stats.head(10).iterrows():
        print(f"  {row['cust_no']:<20} {row['use_create_time']:<30} {row['anomaly_count']:<10}")
    
    # 找出异常最多的客户+时间组合
    top_customer_time = customer_time_stats.index[0]
    top_cust_no = customer_time_stats.iloc[0]['cust_no']
    top_time = customer_time_stats.iloc[0]['use_create_time']
    top_count = customer_time_stats.iloc[0]['anomaly_count']
    
    print(f"\n✨ 异常最多的客户+时间组合:")
    print(f"  客户号: {top_cust_no}")
    print(f"  时间: {top_time}")
    print(f"  异常特征数: {top_count}")
    
    # 提取该客户+时间组合的所有异常特征
    print(f"\n正在提取该客户的异常特征...")
    top_customer_data = merged_df[merged_df['customer_time_key'] == top_customer_time].copy()
    
    # 按特征名去重（保留第一条）
    result_df = top_customer_data.drop_duplicates(subset=['特征名'], keep='first')
    
    # 删除辅助列
    result_df = result_df.drop(columns=['customer_time_key'])
    
    # 按特征名排序
    result_df = result_df.sort_values('特征名')
    
    print(f"\n去重后的异常特征数: {len(result_df)}")
    
    # 保存结果
    result_df.to_csv(output_file, index=False, encoding='utf-8')
    print(f"\n✅ 结果已保存到: {output_file}")
    
    # 显示统计信息
    print(f"\n" + "=" * 80)
    print(f"统计信息")
    print(f"=" * 80)
    print(f"  原始总行数: {len(merged_df)}")
    print(f"  去重后行数: {len(result_df)}")
    print(f"  唯一特征数: {result_df['特征名'].nunique()}")
    print(f"  客户号: {top_cust_no}")
    print(f"  时间: {top_time}")
    print(f"=" * 80)
    
    # 显示前10个异常特征
    print(f"\n前10个异常特征:")
    print(result_df[['特征名', 'CSV值', 'API值']].head(10).to_string(index=False))
    
    return result_df


def main():
    """主函数"""
    # 输入文件匹配模式
    input_pattern = "Mytest/*_analysis_report.csv"
    
    # 输出文件
    output_file = "Mytest/merged_analysis_report_top_customer.csv"
    
    # 执行合并
    result = merge_analysis_reports(input_pattern, output_file)
    
    if result is not None:
        print(f"\n✅ 处理完成！")
        print(f"📁 输出文件: {output_file}")


if __name__ == "__main__":
    main()
