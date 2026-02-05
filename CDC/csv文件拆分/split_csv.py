#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""拆分大CSV文件为多个小文件，每个文件约100万行"""

import os

input_file = "cdc2_v6_1_02041301_差异数据明细.csv"
output_prefix = "cdc2_all_"
rows_per_file = 1000000  # 每个文件100万行

with open(input_file, 'r', encoding='utf-8') as f:
    header = f.readline()
    
    file_num = 1
    row_count = 0
    out_file = None
    
    for line in f:
        if row_count % rows_per_file == 0:
            if out_file:
                out_file.close()
                print(f"完成: {output_prefix}_part{file_num-1}.csv ({rows_per_file}行)")
            out_file = open(f"{output_prefix}_part{file_num}.csv", 'w', encoding='utf-8')
            out_file.write(header)
            file_num += 1
        
        out_file.write(line)
        row_count += 1
    
    if out_file:
        out_file.close()
        remaining = row_count % rows_per_file or rows_per_file
        print(f"完成: {output_prefix}_part{file_num-1}.csv ({remaining}行)")

print(f"\n总共拆分为 {file_num-1} 个文件，共 {row_count} 行数据")
