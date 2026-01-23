#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
CSV文件编码转换工具
将 UTF-8（无BOM）转换为 UTF-8-SIG（有BOM），确保在WPS和Excel中正确显示
"""

import os
import sys

def convert_csv_to_utf8_sig(input_file, output_file=None):
    """
    将CSV文件从UTF-8转换为UTF-8-SIG（带BOM）
    
    参数:
        input_file: 输入文件路径
        output_file: 输出文件路径（如果为None，则覆盖原文件）
    """
    if not os.path.exists(input_file):
        print(f"❌ 文件不存在: {input_file}")
        return False
    
    if output_file is None:
        output_file = input_file + '.utf8sig'
    
    try:
        # 读取UTF-8文件
        with open(input_file, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # 写入UTF-8-SIG文件
        with open(output_file, 'w', encoding='utf-8-sig') as f:
            f.write(content)
        
        input_size = os.path.getsize(input_file)
        output_size = os.path.getsize(output_file)
        
        print(f"✅ 转换成功!")
        print(f"   输入文件: {input_file}")
        print(f"   输出文件: {output_file}")
        print(f"   输入大小: {input_size / (1024*1024):.2f} MB")
        print(f"   输出大小: {output_size / (1024*1024):.2f} MB")
        print(f"\n💡 提示: 现在可以在WPS中正确打开 {output_file} 文件了")
        
        return True
        
    except Exception as e:
        print(f"❌ 转换失败: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("用法: python convert_csv_encoding.py <CSV文件路径> [输出文件路径]")
        print("\n示例:")
        print("  python convert_csv_encoding.py file.csv")
        print("  python convert_csv_encoding.py file.csv file_utf8sig.csv")
        sys.exit(1)
    
    input_file = sys.argv[1]
    output_file = sys.argv[2] if len(sys.argv) > 2 else None
    
    convert_csv_to_utf8_sig(input_file, output_file)
