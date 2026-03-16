#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
CSV文件诊断工具 - 检查文件编码和格式问题
"""

import csv
import os
import sys

# 增加CSV字段大小限制，支持大JSON字段
csv.field_size_limit(sys.maxsize)

def diagnose_csv_file(file_path):
    """诊断CSV文件的编码和格式问题"""
    
    print(f"=" * 80)
    print(f"诊断文件: {file_path}")
    print(f"=" * 80)
    
    # 检查文件是否存在
    if not os.path.exists(file_path):
        print(f"❌ 文件不存在: {file_path}")
        return
    
    # 获取文件大小
    file_size = os.path.getsize(file_path)
    print(f"文件大小: {file_size:,} 字节 ({file_size / 1024 / 1024:.2f} MB)")
    
    # 尝试不同的编码
    encodings = ["utf-8", "gbk", "gb2312", "latin-1", "cp1252", "utf-8-sig"]
    
    print(f"\n{'='*80}")
    print("测试不同编码:")
    print(f"{'='*80}")
    
    for encoding in encodings:
        print(f"\n尝试编码: {encoding}")
        try:
            with open(file_path, "r", encoding=encoding) as f:
                # 尝试读取前几行
                line_count = 0
                for i, line in enumerate(f):
                    line_count += 1
                    if i == 0:
                        print(f"  ✓ 第1行读取成功 (长度: {len(line)} 字符)")
                    if i >= 5:
                        break
                
                # 尝试用CSV reader解析
                f.seek(0)
                reader = csv.reader(f)
                
                try:
                    headers = next(reader)
                    print(f"  ✓ CSV表头解析成功 (列数: {len(headers)})")
                    print(f"  前5列: {headers[:5]}")
                    
                    # 尝试读取所有行
                    row_count = 0
                    error_rows = []
                    for row_idx, row in enumerate(reader, start=2):
                        row_count += 1
                        # 检查列数是否一致
                        if len(row) != len(headers):
                            error_rows.append((row_idx, len(row)))
                            if len(error_rows) <= 3:
                                print(f"  ⚠️  第{row_idx}行列数不匹配: 期望{len(headers)}列，实际{len(row)}列")
                    
                    print(f"  ✓ 成功读取 {row_count} 行数据")
                    if error_rows:
                        print(f"  ⚠️  发现 {len(error_rows)} 行列数不匹配")
                    else:
                        print(f"  ✅ 所有行列数一致")
                    
                    print(f"\n✅ 编码 {encoding} 可以成功读取文件！")
                    return encoding
                    
                except Exception as e:
                    print(f"  ❌ CSV解析失败: {str(e)}")
                    import traceback
                    print(f"  详细错误:\n{traceback.format_exc()}")
                    
        except UnicodeDecodeError as e:
            print(f"  ❌ 编码错误: {str(e)}")
        except Exception as e:
            print(f"  ❌ 读取失败: {str(e)}")
            import traceback
            print(f"  详细错误:\n{traceback.format_exc()}")
    
    print(f"\n{'='*80}")
    print("❌ 所有编码都无法成功读取文件")
    print(f"{'='*80}")
    return None


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("用法: python diagnose_csv.py <csv文件路径>")
        print("示例: python diagnose_csv.py online_comparison/inputdata/creditos_json_0308.csv")
        sys.exit(1)
    
    file_path = sys.argv[1]
    diagnose_csv_file(file_path)
