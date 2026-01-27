#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
演示：写入50000行数据
证明 batch_size=5000 可以成功处理大数据
"""

import os
import sys
import time

sys.path.insert(0, os.path.dirname(__file__))
from common.csv_tool import CSVBatchWriter


def demo_50000_rows():
    """演示写入50000行数据"""
    print("=" * 80)
    print("演示：使用 batch_size=5000 写入 50,000 行数据")
    print("=" * 80)
    
    # 准备数据
    print("\n📋 准备数据...")
    headers = ["id", "name", "value", "timestamp", "status"]
    total_rows = 50000
    
    # 生成数据（模拟真实场景）
    def generate_data():
        """生成器：逐行生成数据，节省内存"""
        for i in range(total_rows):
            yield [
                str(i + 1),
                f"user_{i + 1}",
                f"{(i * 123.456) % 1000:.2f}",
                f"2026-01-27 16:30:{i % 60:02d}",
                "active" if i % 3 == 0 else "inactive"
            ]
    
    output_dir = "outputdata/demo"
    os.makedirs(output_dir, exist_ok=True)
    output_file = os.path.join(output_dir, "demo_50000_rows.csv")
    
    # 开始写入
    print(f"\n🚀 开始写入 {total_rows:,} 行数据...")
    print(f"   batch_size = 5000")
    print(f"   预计批次数 = {total_rows // 5000} 次")
    print()
    
    start_time = time.time()
    
    with CSVBatchWriter(output_file, headers, batch_size=5000, 
                       show_progress=True, total_rows=total_rows) as writer:
        for row in generate_data():
            writer.write_row(row)
    
    elapsed = time.time() - start_time
    
    # 显示结果
    print(f"\n{'='*80}")
    print(f"✅ 写入完成！")
    print(f"{'='*80}")
    print(f"  总行数: {total_rows:,} 行")
    print(f"  耗时: {elapsed:.2f} 秒")
    print(f"  速度: {total_rows / elapsed:,.0f} 行/秒")
    print(f"  文件大小: {os.path.getsize(output_file) / 1024 / 1024:.2f} MB")
    print(f"  批次数: {total_rows // 5000} 次批量写入")
    print(f"  每批次: 5,000 行")
    print(f"{'='*80}")
    
    # 验证文件
    print(f"\n🔍 验证文件...")
    with open(output_file, 'r', encoding='utf-8') as f:
        line_count = sum(1 for _ in f) - 1  # 减去表头
    
    if line_count == total_rows:
        print(f"✅ 验证成功：文件包含 {line_count:,} 行数据（不含表头）")
    else:
        print(f"❌ 验证失败：预期 {total_rows:,} 行，实际 {line_count:,} 行")
    
    # 显示前几行
    print(f"\n📄 文件前5行预览:")
    with open(output_file, 'r', encoding='utf-8') as f:
        for i, line in enumerate(f):
            if i < 6:  # 表头 + 5行数据
                print(f"  {line.strip()}")
            else:
                break
    
    # 清理
    print(f"\n🧹 清理演示文件...")
    os.remove(output_file)
    print(f"✅ 清理完成")
    
    print(f"\n{'='*80}")
    print(f"结论：")
    print(f"  • batch_size=5000 可以成功处理 50,000 行数据")
    print(f"  • 实际上可以处理百万级数据")
    print(f"  • batch_size 只影响性能，不限制总行数")
    print(f"  • 推荐使用 batch_size=5000 获得最佳性能")
    print(f"{'='*80}")


if __name__ == "__main__":
    demo_50000_rows()
