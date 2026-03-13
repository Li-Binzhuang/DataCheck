#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
CSV合并功能测试脚本 - 新版本
"""

import pandas as pd
import os

def create_vertical_test_files():
    """创建纵向合并测试文件（列相同）"""
    print("=" * 60)
    print("创建纵向合并测试文件...")
    print("=" * 60)
    
    # 文件1: 100行，4列
    df1 = pd.DataFrame({
        'user_id': range(1, 101),
        'name': [f'User_{i}' for i in range(1, 101)],
        'age': [20 + i % 50 for i in range(1, 101)],
        'city': ['Beijing', 'Shanghai', 'Guangzhou', 'Shenzhen'] * 25
    })
    df1.to_csv('vertical_test1.csv', index=False, encoding='utf-8-sig')
    print(f"✓ 创建 vertical_test1.csv ({len(df1)} 行, {len(df1.columns)} 列)")
    print(f"  列名: {', '.join(df1.columns)}")
    
    # 文件2: 100行，4列（列名相同）
    df2 = pd.DataFrame({
        'user_id': range(101, 201),
        'name': [f'User_{i}' for i in range(101, 201)],
        'age': [20 + i % 50 for i in range(101, 201)],
        'city': ['Beijing', 'Shanghai', 'Guangzhou', 'Shenzhen'] * 25
    })
    df2.to_csv('vertical_test2.csv', index=False, encoding='utf-8-sig')
    print(f"✓ 创建 vertical_test2.csv ({len(df2)} 行, {len(df2.columns)} 列)")
    print(f"  列名: {', '.join(df2.columns)}")
    
    print("\n预期结果：")
    print("  - 纵向合并后：200行，4列")
    print("  - 列名：user_id, name, age, city（只保留一次）")
    print("  - 第一个文件的列名作为表头")
    print("  - 后续文件从第二行开始追加")


def create_horizontal_test_files():
    """创建横向合并测试文件（行数相同，按主键合并）"""
    print("\n" + "=" * 60)
    print("创建横向合并测试文件...")
    print("=" * 60)
    
    # 文件1: 100行，基础信息
    df1 = pd.DataFrame({
        'user_id': range(1, 101),
        'name': [f'User_{i}' for i in range(1, 101)],
        'age': [20 + i % 50 for i in range(1, 101)]
    })
    df1.to_csv('horizontal_test1.csv', index=False, encoding='utf-8-sig')
    print(f"✓ 创建 horizontal_test1.csv ({len(df1)} 行, {len(df1.columns)} 列)")
    print(f"  列名: {', '.join(df1.columns)}")
    
    # 文件2: 100行，订单信息（有重复列user_id）
    df2 = pd.DataFrame({
        'user_id': range(1, 101),
        'order_count': [i % 20 for i in range(1, 101)],
        'total_amount': [100 + i * 10 for i in range(1, 101)]
    })
    df2.to_csv('horizontal_test2.csv', index=False, encoding='utf-8-sig')
    print(f"✓ 创建 horizontal_test2.csv ({len(df2)} 行, {len(df2.columns)} 列)")
    print(f"  列名: {', '.join(df2.columns)}")
    
    # 文件3: 100行，积分信息（有重复列user_id）
    df3 = pd.DataFrame({
        'user_id': range(1, 101),
        'points': [i * 5 for i in range(1, 101)],
        'level': [f'Level_{i%5}' for i in range(1, 101)]
    })
    df3.to_csv('horizontal_test3.csv', index=False, encoding='utf-8-sig')
    print(f"✓ 创建 horizontal_test3.csv ({len(df3)} 行, {len(df3.columns)} 列)")
    print(f"  列名: {', '.join(df3.columns)}")
    
    print("\n预期结果：")
    print("  - 横向合并后：100行，7列")
    print("  - 主键列：user_id")
    print("  - 合并后列名：user_id, name, age, order_count, total_amount, points, level")
    print("  - 重复的user_id列会被自动移除（只保留第一个文件的）")


def create_large_vertical_test():
    """创建大文件纵向合并测试（20万行）"""
    print("\n" + "=" * 60)
    print("创建大文件纵向合并测试...")
    print("=" * 60)
    
    # 文件1: 10万行
    df1 = pd.DataFrame({
        'id': range(1, 100001),
        'name': [f'User_{i}' for i in range(1, 100001)],
        'value': [i * 1.5 for i in range(1, 100001)],
        'category': ['A', 'B', 'C', 'D'] * 25000
    })
    df1.to_csv('large_vertical1.csv', index=False, encoding='utf-8-sig')
    size1 = os.path.getsize('large_vertical1.csv') / 1024 / 1024
    print(f"✓ 创建 large_vertical1.csv ({len(df1):,} 行, {len(df1.columns)} 列, {size1:.2f} MB)")
    
    # 文件2: 10万行
    df2 = pd.DataFrame({
        'id': range(100001, 200001),
        'name': [f'User_{i}' for i in range(100001, 200001)],
        'value': [i * 1.5 for i in range(100001, 200001)],
        'category': ['A', 'B', 'C', 'D'] * 25000
    })
    df2.to_csv('large_vertical2.csv', index=False, encoding='utf-8-sig')
    size2 = os.path.getsize('large_vertical2.csv') / 1024 / 1024
    print(f"✓ 创建 large_vertical2.csv ({len(df2):,} 行, {len(df2.columns)} 列, {size2:.2f} MB)")
    
    print("\n预期结果：")
    print("  - 纵向合并后：200,000行，4列")
    print("  - 应该看到实时进度更新")
    print("  - 处理时间：约10-20秒")


if __name__ == '__main__':
    import sys
    
    if len(sys.argv) > 1 and sys.argv[1] == 'large':
        create_large_vertical_test()
    elif len(sys.argv) > 1 and sys.argv[1] == 'horizontal':
        create_horizontal_test_files()
    elif len(sys.argv) > 1 and sys.argv[1] == 'vertical':
        create_vertical_test_files()
    else:
        # 默认创建所有测试文件
        create_vertical_test_files()
        create_horizontal_test_files()
        
        print("\n" + "=" * 60)
        print("测试文件创建完成！")
        print("=" * 60)
        print("\n测试步骤：")
        print("\n1. 纵向合并测试：")
        print("   - 选择文件：vertical_test1.csv, vertical_test2.csv")
        print("   - 选择：纵向合并（追加行）")
        print("   - 预期：200行，4列")
        
        print("\n2. 横向合并测试：")
        print("   - 选择文件：horizontal_test1.csv, horizontal_test2.csv, horizontal_test3.csv")
        print("   - 选择：横向合并（追加列）")
        print("   - 主键列：user_id")
        print("   - 预期：100行，7列（user_id只保留一次）")
        
        print("\n3. 大文件测试：")
        print("   - 运行：python test_merge_new.py large")
        print("   - 选择生成的large_vertical1.csv和large_vertical2.csv")
        print("   - 预期：200,000行，实时进度更新")
        
        print("\n其他命令：")
        print("  python test_merge_new.py vertical    # 只创建纵向测试文件")
        print("  python test_merge_new.py horizontal  # 只创建横向测试文件")
        print("  python test_merge_new.py large       # 创建大文件测试")
