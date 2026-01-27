#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
测试进度显示功能
演示CSV写入时的进度显示效果
"""

import os
import sys
import time

# 添加项目路径
sys.path.insert(0, os.path.dirname(__file__))

from common.csv_tool import CSVBatchWriter


def test_progress_display():
    """测试进度显示功能"""
    print("=" * 80)
    print("CSV写入进度显示测试")
    print("=" * 80)
    
    output_dir = "outputdata/progress_test"
    os.makedirs(output_dir, exist_ok=True)
    
    # 测试1: 不显示进度
    print("\n测试1: 不显示进度（默认行为）")
    print("-" * 80)
    headers = ["col1", "col2", "col3"]
    data = [[f"val{i}_1", f"val{i}_2", f"val{i}_3"] for i in range(1000)]
    
    file1 = os.path.join(output_dir, "test_no_progress.csv")
    with CSVBatchWriter(file1, headers) as writer:
        for row in data:
            writer.write_row(row)
    
    # 测试2: 显示进度（不知道总行数）
    print("\n测试2: 显示进度（不知道总行数）")
    print("-" * 80)
    file2 = os.path.join(output_dir, "test_progress_unknown.csv")
    with CSVBatchWriter(file2, headers, show_progress=True) as writer:
        for row in data:
            writer.write_row(row)
            time.sleep(0.001)  # 模拟处理时间
    
    # 测试3: 显示进度（知道总行数）
    print("\n测试3: 显示进度（知道总行数，显示百分比）")
    print("-" * 80)
    file3 = os.path.join(output_dir, "test_progress_known.csv")
    total = len(data)
    with CSVBatchWriter(file3, headers, show_progress=True, total_rows=total) as writer:
        for row in data:
            writer.write_row(row)
            time.sleep(0.001)  # 模拟处理时间
    
    # 测试4: 大数据集进度显示
    print("\n测试4: 大数据集进度显示（5000行）")
    print("-" * 80)
    large_data = [[f"val{i}_1", f"val{i}_2", f"val{i}_3"] for i in range(5000)]
    file4 = os.path.join(output_dir, "test_progress_large.csv")
    total = len(large_data)
    with CSVBatchWriter(file4, headers, show_progress=True, total_rows=total, batch_size=1000) as writer:
        for row in large_data:
            writer.write_row(row)
            time.sleep(0.0001)  # 模拟处理时间
    
    # 清理测试文件
    print("\n清理测试文件...")
    for f in [file1, file2, file3, file4]:
        if os.path.exists(f):
            os.remove(f)
    
    print("\n" + "=" * 80)
    print("✅ 进度显示测试完成")
    print("=" * 80)
    print("\n使用说明:")
    print("  • 默认不显示进度（保持简洁）")
    print("  • 设置 show_progress=True 启用进度显示")
    print("  • 提供 total_rows 参数可显示百分比")
    print("  • 进度每100行更新一次（或每1000行，取决于是否知道总数）")
    print("  • 使用 \\r 实现同行刷新，不会产生大量输出")


if __name__ == "__main__":
    test_progress_display()
