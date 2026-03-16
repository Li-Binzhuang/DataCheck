#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
调试脚本 - 测试合并功能
"""

import sys
import os

# 添加项目路径
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from web.routes.merge_csv_routes import vertical_merge, horizontal_merge
import pandas as pd

def test_vertical_merge():
    """测试纵向合并"""
    print("=" * 60)
    print("测试纵向合并...")
    print("=" * 60)
    
    # 检查测试文件是否存在
    files = ['vertical_test1.csv', 'vertical_test2.csv']
    for f in files:
        if not os.path.exists(f):
            print(f"❌ 文件不存在: {f}")
            print("请先运行: python test_merge_new.py")
            return
    
    try:
        # 执行合并
        output_path = 'debug_vertical_output.csv'
        total_rows, total_columns = vertical_merge(files, output_path)
        
        print(f"✅ 合并成功！")
        print(f"   总行数: {total_rows}")
        print(f"   总列数: {total_columns}")
        print(f"   输出文件: {output_path}")
        
        # 验证结果
        df = pd.read_csv(output_path)
        print(f"\n验证结果:")
        print(f"   实际行数: {len(df)}")
        print(f"   实际列数: {len(df.columns)}")
        print(f"   列名: {', '.join(df.columns)}")
        print(f"   前3行:")
        print(df.head(3))
        
    except Exception as e:
        print(f"❌ 合并失败: {e}")
        import traceback
        traceback.print_exc()


def test_horizontal_merge():
    """测试横向合并"""
    print("\n" + "=" * 60)
    print("测试横向合并...")
    print("=" * 60)
    
    # 检查测试文件是否存在
    files = ['horizontal_test1.csv', 'horizontal_test2.csv', 'horizontal_test3.csv']
    for f in files:
        if not os.path.exists(f):
            print(f"❌ 文件不存在: {f}")
            print("请先运行: python test_merge_new.py")
            return
    
    try:
        # 执行合并
        output_path = 'debug_horizontal_output.csv'
        key_columns = ['user_id']
        total_rows, total_columns, removed_columns = horizontal_merge(files, output_path, key_columns)
        
        print(f"✅ 合并成功！")
        print(f"   总行数: {total_rows}")
        print(f"   总列数: {total_columns}")
        print(f"   移除的列: {removed_columns}")
        print(f"   输出文件: {output_path}")
        
        # 验证结果
        df = pd.read_csv(output_path)
        print(f"\n验证结果:")
        print(f"   实际行数: {len(df)}")
        print(f"   实际列数: {len(df.columns)}")
        print(f"   列名: {', '.join(df.columns)}")
        print(f"   前3行:")
        print(df.head(3))
        
    except Exception as e:
        print(f"❌ 合并失败: {e}")
        import traceback
        traceback.print_exc()


if __name__ == '__main__':
    if len(sys.argv) > 1 and sys.argv[1] == 'horizontal':
        test_horizontal_merge()
    elif len(sys.argv) > 1 and sys.argv[1] == 'vertical':
        test_vertical_merge()
    else:
        test_vertical_merge()
        test_horizontal_merge()
