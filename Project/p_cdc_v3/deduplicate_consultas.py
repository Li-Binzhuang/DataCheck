#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
CDC Consultas 数据去重脚本
功能：按 cust_no 去重，保留 create_time 最新的一条记录
"""

import pandas as pd
import os


def main():
    """主函数"""
    # 获取脚本所在目录
    script_dir = os.path.dirname(os.path.abspath(__file__))
    
    # 定义输入输出文件
    input_file = os.path.join(script_dir, 'consultas_features_cdc_v3_up.csv')
    output_file = os.path.join(script_dir, 'consultas_features_cdc_v3_up_dedup.csv')
    
    print("=" * 60)
    print("CDC Consultas 数据去重工具")
    print("=" * 60)
    
    # 检查文件是否存在
    if not os.path.exists(input_file):
        print(f"错误: 文件不存在 - {input_file}")
        return
    
    print(f"\n读取文件: {input_file}")
    
    # 读取CSV文件
    df = pd.read_csv(input_file)
    print(f"原始数据行数: {len(df)}")
    
    # 确保 create_time 是日期时间格式
    df['create_time'] = pd.to_datetime(df['create_time'])
    
    # 按 cust_no 分组，保留 create_time 最新的一条
    df_sorted = df.sort_values('create_time', ascending=False)
    df_dedup = df_sorted.drop_duplicates(subset=['cust_no'], keep='first')
    
    print(f"去重后数据行数: {len(df_dedup)}")
    print(f"删除重复记录数: {len(df) - len(df_dedup)}")
    
    # 保存到新文件
    df_dedup.to_csv(output_file, index=False)
    print(f"\n已保存到: {output_file}")
    
    print("=" * 60)
    print("处理完成")
    print("=" * 60)


if __name__ == "__main__":
    main()
