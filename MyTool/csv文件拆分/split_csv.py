#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
CSV文件拆分工具
将大CSV文件拆分为多个小文件

用法: python split_csv.py <输入文件> [每个文件行数]
示例: python split_csv.py data.csv 100000
"""

import os
import sys

def split_csv(input_file, rows_per_file=1000000):
    """拆分CSV文件"""
    
    if not os.path.exists(input_file):
        print(f"❌ 文件不存在: {input_file}")
        return
    
    # 生成输出文件前缀
    base_name = os.path.splitext(os.path.basename(input_file))[0]
    output_dir = os.path.dirname(input_file) or '.'
    output_prefix = os.path.join(output_dir, f"{base_name}_part")
    
    print(f"输入文件: {input_file}")
    print(f"每个文件: {rows_per_file} 行")
    print()
    
    with open(input_file, 'r', encoding='utf-8') as f:
        header = f.readline()
        
        file_num = 1
        row_count = 0
        out_file = None
        
        for line in f:
            if row_count % rows_per_file == 0:
                if out_file:
                    out_file.close()
                    print(f"✓ {output_prefix}{file_num-1}.csv ({rows_per_file} 行)")
                out_file = open(f"{output_prefix}{file_num}.csv", 'w', encoding='utf-8')
                out_file.write(header)
                file_num += 1
            
            out_file.write(line)
            row_count += 1
        
        if out_file:
            out_file.close()
            remaining = row_count % rows_per_file or rows_per_file
            print(f"✓ {output_prefix}{file_num-1}.csv ({remaining} 行)")
    
    print()
    print(f"完成！共拆分为 {file_num-1} 个文件，总计 {row_count} 行数据")

if __name__ == '__main__':
    # ============ 配置区域 ============
    # 在这里指定要拆分的文件路径
    INPUT_FILE = "input.csv"  # 修改为你的文件路径
    ROWS_PER_FILE = 1000000   # 每个文件的行数，默认100万行
    # =================================
    
    # 命令行参数优先
    if len(sys.argv) >= 2:
        input_file = sys.argv[1]
        rows_per_file = int(sys.argv[2]) if len(sys.argv) > 2 else ROWS_PER_FILE
    else:
        input_file = INPUT_FILE
        rows_per_file = ROWS_PER_FILE
    
    split_csv(input_file, rows_per_file)
