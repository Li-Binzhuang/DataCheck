#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
测试PKL转换功能
"""

import os
import sys
import pandas as pd
import pickle

# 添加common目录到路径
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'common'))

from pkl_converter import convert_pkl_to_csv, get_pkl_info

def test_pkl_converter():
    """测试PKL转换功能"""
    print("="*60)
    print("测试PKL转换功能")
    print("="*60)
    print()
    
    # 创建测试数据
    test_data = pd.DataFrame({
        'cust_no': ['800001054335', '800001054336', '800001054337'],
        'name': ['张三', '李四', '王五'],
        'amount': [1000.0, 2000.0, 3000.0],
        'status': ['ACTIVE', 'ACTIVE', 'INACTIVE']
    })
    
    # 保存为PKL文件
    test_pkl_path = 'test_data.pkl'
    test_csv_path = 'test_data.csv'
    
    print("步骤1: 创建测试PKL文件...")
    with open(test_pkl_path, 'wb') as f:
        pickle.dump(test_data, f)
    print(f"✓ 已创建: {test_pkl_path}")
    print()
    
    # 获取PKL文件信息
    print("步骤2: 获取PKL文件信息...")
    info = get_pkl_info(test_pkl_path)
    if info.get('success'):
        print(f"✓ 文件类型: {info.get('type')}")
        print(f"✓ 数据形状: {info.get('shape')}")
        print(f"✓ 行数: {info.get('rows')}")
        print(f"✓ 列数: {info.get('cols')}")
        print(f"✓ 列名: {info.get('columns')}")
    else:
        print(f"✗ 获取信息失败: {info.get('error')}")
    print()
    
    # 转换为CSV
    print("步骤3: 转换PKL为CSV...")
    success, message, csv_path = convert_pkl_to_csv(test_pkl_path, test_csv_path)
    if success:
        print(f"✓ {message}")
        print(f"✓ CSV文件路径: {csv_path}")
    else:
        print(f"✗ 转换失败: {message}")
    print()
    
    # 验证CSV文件
    if os.path.exists(test_csv_path):
        print("步骤4: 验证CSV文件...")
        df_csv = pd.read_csv(test_csv_path)
        print(f"✓ CSV文件行数: {len(df_csv)}")
        print(f"✓ CSV文件列数: {len(df_csv.columns)}")
        print(f"✓ CSV文件列名: {list(df_csv.columns)}")
        print()
        print("CSV文件内容预览:")
        print(df_csv)
        print()
    
    # 清理测试文件
    print("步骤5: 清理测试文件...")
    if os.path.exists(test_pkl_path):
        os.remove(test_pkl_path)
        print(f"✓ 已删除: {test_pkl_path}")
    if os.path.exists(test_csv_path):
        os.remove(test_csv_path)
        print(f"✓ 已删除: {test_csv_path}")
    print()
    
    print("="*60)
    print("测试完成！")
    print("="*60)


if __name__ == "__main__":
    test_pkl_converter()
