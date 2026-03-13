#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
CSV合并功能测试脚本
"""

import pandas as pd
import os

# 创建测试数据
def create_test_files():
    """创建测试CSV文件"""
    print("创建测试文件...")
    
    # 文件1: 100行数据
    df1 = pd.DataFrame({
        'id': range(1, 101),
        'name': [f'User_{i}' for i in range(1, 101)],
        'age': [20 + i % 50 for i in range(1, 101)],
        'city': ['Beijing', 'Shanghai', 'Guangzhou', 'Shenzhen'] * 25
    })
    df1.to_csv('test_file1.csv', index=False, encoding='utf-8-sig')
    print(f"✓ 创建 test_file1.csv ({len(df1)} 行)")
    
    # 文件2: 100行数据
    df2 = pd.DataFrame({
        'id': range(101, 201),
        'name': [f'User_{i}' for i in range(101, 201)],
        'age': [20 + i % 50 for i in range(101, 201)],
        'city': ['Beijing', 'Shanghai', 'Guangzhou', 'Shenzhen'] * 25
    })
    df2.to_csv('test_file2.csv', index=False, encoding='utf-8-sig')
    print(f"✓ 创建 test_file2.csv ({len(df2)} 行)")
    
    print("\n测试文件创建完成！")
    print("请在浏览器中选择这两个文件进行测试：")
    print("  - test_file1.csv")
    print("  - test_file2.csv")
    print("\n预期结果：")
    print("  - 纵向合并：200行，4列")
    print("  - 横向合并：100行，8列（或4列如果移除重复列）")


def create_large_test_files():
    """创建大文件测试（20万行）"""
    print("创建大文件测试数据...")
    
    # 文件1: 10万行
    df1 = pd.DataFrame({
        'id': range(1, 100001),
        'name': [f'User_{i}' for i in range(1, 100001)],
        'age': [20 + i % 50 for i in range(1, 100001)],
        'city': ['Beijing', 'Shanghai', 'Guangzhou', 'Shenzhen'] * 25000,
        'score': [60 + i % 40 for i in range(1, 100001)]
    })
    df1.to_csv('test_large1.csv', index=False, encoding='utf-8-sig')
    print(f"✓ 创建 test_large1.csv ({len(df1):,} 行)")
    
    # 文件2: 10万行
    df2 = pd.DataFrame({
        'id': range(100001, 200001),
        'name': [f'User_{i}' for i in range(100001, 200001)],
        'age': [20 + i % 50 for i in range(100001, 200001)],
        'city': ['Beijing', 'Shanghai', 'Guangzhou', 'Shenzhen'] * 25000,
        'score': [60 + i % 40 for i in range(100001, 200001)]
    })
    df2.to_csv('test_large2.csv', index=False, encoding='utf-8-sig')
    print(f"✓ 创建 test_large2.csv ({len(df2):,} 行)")
    
    print("\n大文件测试数据创建完成！")
    print("文件大小：")
    print(f"  - test_large1.csv: {os.path.getsize('test_large1.csv') / 1024 / 1024:.2f} MB")
    print(f"  - test_large2.csv: {os.path.getsize('test_large2.csv') / 1024 / 1024:.2f} MB")
    print("\n预期结果：")
    print("  - 纵向合并：200,000行，5列")
    print("  - 应该看到实时进度更新")


if __name__ == '__main__':
    import sys
    
    if len(sys.argv) > 1 and sys.argv[1] == 'large':
        create_large_test_files()
    else:
        create_test_files()
        print("\n提示：运行 'python test_merge_csv.py large' 创建20万行测试数据")
