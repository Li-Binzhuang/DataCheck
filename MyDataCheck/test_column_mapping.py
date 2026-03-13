#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
测试特征名称映射功能
"""

import sys
import os

# 添加项目路径
sys.path.insert(0, os.path.dirname(__file__))

def test_column_mapping():
    """测试特征名称映射功能"""
    
    print("="*80)
    print("测试特征名称映射功能")
    print("="*80)
    
    # 模拟特征列
    feature_cols_sql = ['age', 'income', 'score', 'balance']
    feature_cols_api = ['age', 'income', 'score', 'balance']
    
    print(f"\n原始特征列:")
    print(f"  file1 (Sql): {feature_cols_sql}")
    print(f"  file2 (Api): {feature_cols_api}")
    
    # 测试1：为file1添加前缀
    print(f"\n{'='*80}")
    print("测试1：为file1添加前缀 'model_'")
    print(f"{'='*80}")
    
    enable_column_mapping = True
    mapping_file = 'file1'
    mapping_prefix = 'model_'
    mapping_suffix = ''
    
    if enable_column_mapping and mapping_file:
        if mapping_file == 'file1':
            original_feature_cols_sql = feature_cols_sql.copy()
            feature_cols_sql_mapped = [f"{mapping_prefix}{col}{mapping_suffix}" for col in feature_cols_sql]
            print(f"  映射后的file1特征列: {feature_cols_sql_mapped}")
            print(f"  示例: '{original_feature_cols_sql[0]}' -> '{feature_cols_sql_mapped[0]}'")
        elif mapping_file == 'file2':
            original_feature_cols_api = feature_cols_api.copy()
            feature_cols_api_mapped = [f"{mapping_prefix}{col}{mapping_suffix}" for col in feature_cols_api]
            print(f"  映射后的file2特征列: {feature_cols_api_mapped}")
            print(f"  示例: '{original_feature_cols_api[0]}' -> '{feature_cols_api_mapped[0]}'")
    
    # 测试2：为file2添加后缀
    print(f"\n{'='*80}")
    print("测试2：为file2添加后缀 '_api'")
    print(f"{'='*80}")
    
    feature_cols_sql = ['age', 'income', 'score', 'balance']
    feature_cols_api = ['age', 'income', 'score', 'balance']
    
    enable_column_mapping = True
    mapping_file = 'file2'
    mapping_prefix = ''
    mapping_suffix = '_api'
    
    if enable_column_mapping and mapping_file:
        if mapping_file == 'file1':
            original_feature_cols_sql = feature_cols_sql.copy()
            feature_cols_sql_mapped = [f"{mapping_prefix}{col}{mapping_suffix}" for col in feature_cols_sql]
            print(f"  映射后的file1特征列: {feature_cols_sql_mapped}")
            print(f"  示例: '{original_feature_cols_sql[0]}' -> '{feature_cols_sql_mapped[0]}'")
        elif mapping_file == 'file2':
            original_feature_cols_api = feature_cols_api.copy()
            feature_cols_api_mapped = [f"{mapping_prefix}{col}{mapping_suffix}" for col in feature_cols_api]
            print(f"  映射后的file2特征列: {feature_cols_api_mapped}")
            print(f"  示例: '{original_feature_cols_api[0]}' -> '{feature_cols_api_mapped[0]}'")
    
    # 测试3：同时添加前缀和后缀
    print(f"\n{'='*80}")
    print("测试3：为file1同时添加前缀 'v2_' 和后缀 '_new'")
    print(f"{'='*80}")
    
    feature_cols_sql = ['age', 'income', 'score', 'balance']
    feature_cols_api = ['age', 'income', 'score', 'balance']
    
    enable_column_mapping = True
    mapping_file = 'file1'
    mapping_prefix = 'v2_'
    mapping_suffix = '_new'
    
    if enable_column_mapping and mapping_file:
        if mapping_file == 'file1':
            original_feature_cols_sql = feature_cols_sql.copy()
            feature_cols_sql_mapped = [f"{mapping_prefix}{col}{mapping_suffix}" for col in feature_cols_sql]
            print(f"  映射后的file1特征列: {feature_cols_sql_mapped}")
            print(f"  示例: '{original_feature_cols_sql[0]}' -> '{feature_cols_sql_mapped[0]}'")
        elif mapping_file == 'file2':
            original_feature_cols_api = feature_cols_api.copy()
            feature_cols_api_mapped = [f"{mapping_prefix}{col}{mapping_suffix}" for col in feature_cols_api]
            print(f"  映射后的file2特征列: {feature_cols_api_mapped}")
            print(f"  示例: '{original_feature_cols_api[0]}' -> '{feature_cols_api_mapped[0]}'")
    
    # 测试4：不启用映射
    print(f"\n{'='*80}")
    print("测试4：不启用映射（默认行为）")
    print(f"{'='*80}")
    
    feature_cols_sql = ['age', 'income', 'score', 'balance']
    feature_cols_api = ['age', 'income', 'score', 'balance']
    
    enable_column_mapping = False
    mapping_file = 'file1'
    mapping_prefix = 'model_'
    mapping_suffix = '_v1'
    
    if enable_column_mapping and mapping_file:
        print("  映射已启用")
    else:
        print("  映射未启用，保持原始列名")
        print(f"  file1特征列: {feature_cols_sql}")
        print(f"  file2特征列: {feature_cols_api}")
    
    print(f"\n{'='*80}")
    print("✅ 所有测试完成！")
    print(f"{'='*80}\n")


if __name__ == '__main__':
    test_column_mapping()
