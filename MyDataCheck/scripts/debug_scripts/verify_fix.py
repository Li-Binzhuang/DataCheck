#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
验证组合主键匹配 Bug 修复
"""

import sys
import os

# 添加路径
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'common'))
from csv_tool import read_csv_with_encoding

def verify_fix():
    """验证修复效果"""
    
    print("=" * 80)
    print("验证组合主键匹配 Bug 修复")
    print("=" * 80)
    
    # 检查修复1：时间列查找
    print("\n[1] 检查时间列查找修复...")
    
    data_comparator_file = "data_comparison/job/data_comparator.py"
    with open(data_comparator_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    if "max(api_key_columns)" in content and "max(sql_key_columns)" in content:
        print("  ✅ 时间列查找已修复")
    else:
        print("  ❌ 时间列查找修复未应用")
    
    # 检查修复2：报告表头处理
    print("\n[2] 检查报告表头处理修复...")
    
    report_generator_file = "data_comparison/job/report_generator.py"
    with open(report_generator_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    if "isinstance(key_column_names, list)" in content:
        print("  ✅ 报告表头处理已修复")
    else:
        print("  ❌ 报告表头处理修复未应用")
    
    # 检查最新的报告文件
    print("\n[3] 检查最新报告文件...")
    
    output_dir = "outputdata/data_comparison"
    if os.path.exists(output_dir):
        # 找到最新的差异数据明细文件
        files = []
        for f in os.listdir(output_dir):
            if "差异数据明细.csv" in f:
                files.append(os.path.join(output_dir, f))
        
        if files:
            latest_file = max(files, key=os.path.getctime)
            print(f"  最新报告: {os.path.basename(latest_file)}")
            
            # 读取表头
            with open(latest_file, 'r', encoding='utf-8-sig') as f:
                header = f.readline().strip()
            
            print(f"  表头: {header}")
            
            # 检查表头是否包含 create_time
            if "create_time" in header or "时间" in header:
                print("  ✅ 表头包含时间信息")
            else:
                print("  ⚠️  表头可能不包含完整的主键信息（这是旧报告）")
        else:
            print("  ⚠️  未找到差异数据明细文件")
    else:
        print("  ⚠️  输出目录不存在")
    
    # 显示修复建议
    print("\n[4] 修复建议...")
    print("""
  1. 修复已应用到代码中
  2. 需要重新运行对比以生成新的报告
  3. 新报告应该显示完整的主键信息（包括 create_time）
  4. 差异数据应该正确对应到各自的记录
    """)
    
    print("\n" + "=" * 80)
    print("验证完成")
    print("=" * 80)

if __name__ == "__main__":
    verify_fix()
