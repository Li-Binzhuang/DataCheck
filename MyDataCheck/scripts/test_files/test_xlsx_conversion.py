#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
测试XLSX转CSV功能
"""

import os
import sys

# 添加当前目录到路径
sys.path.insert(0, os.path.dirname(__file__))

from common.csv_tool import convert_xlsx_to_csv


def test_xlsx_conversion():
    """测试XLSX转CSV转换功能"""
    print("=" * 60)
    print("测试XLSX转CSV转换功能")
    print("=" * 60)
    
    # 测试文件路径（需要手动创建一个测试XLSX文件）
    test_xlsx = "inputdata/api_comparison/test.xlsx"
    
    if not os.path.exists(test_xlsx):
        print(f"\n❌ 测试文件不存在: {test_xlsx}")
        print("请创建一个测试XLSX文件后再运行此测试")
        return
    
    print(f"\n测试文件: {test_xlsx}")
    
    # 测试转换
    success, message, csv_path = convert_xlsx_to_csv(test_xlsx)
    
    if success:
        print(f"\n✅ 转换成功!")
        print(f"   消息: {message}")
        print(f"   输出文件: {csv_path}")
        
        # 检查文件是否存在
        if os.path.exists(csv_path):
            print(f"   文件大小: {os.path.getsize(csv_path)} 字节")
        else:
            print(f"   ⚠️  输出文件不存在")
    else:
        print(f"\n❌ 转换失败!")
        print(f"   错误: {message}")


if __name__ == '__main__':
    test_xlsx_conversion()
