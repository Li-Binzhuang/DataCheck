#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
数据去重加引号脚本
功能：读取data.txt，去重，给每个数据加单引号，用英文逗号隔开，输出到新文件
"""

def process_data(input_file='data.txt', output_file='data_processed.txt'):
    """
    处理数据文件：去重、加引号、逗号分隔
    
    Args:
        input_file: 输入文件名
        output_file: 输出文件名
    """
    # 读取数据
    with open(input_file, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    # 去重并去除空行和空白字符
    unique_data = []
    seen = set()
    
    for line in lines:
        data = line.strip()
        if data and data not in seen:
            unique_data.append(data)
            seen.add(data)
    
    # 给每个数据加单引号
    quoted_data = [f"'{item}'" for item in unique_data]
    
    # 用英文逗号连接
    result = ','.join(quoted_data)
    
    # 输出到新文件
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(result)
    
    # 打印统计信息
    print(f"处理完成！")
    print(f"原始数据行数: {len(lines)}")
    print(f"去重后数据条数: {len(unique_data)}")
    print(f"输出文件: {output_file}")
    print(f"\n前10条数据预览:")
    print(','.join(quoted_data[:10]))

if __name__ == '__main__':
    process_data()
