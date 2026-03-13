#!/usr/bin/env python3
"""
将 cdc灰度验证.csv 转换为 pkl 文件
"""
import pandas as pd
import pickle
from pathlib import Path

# 获取脚本所在目录
script_dir = Path(__file__).parent

# 读取 CSV 文件
csv_file = script_dir / 'cdc灰度验证 (1).csv'
print(f"正在读取 CSV 文件: {csv_file}")
df = pd.read_csv(csv_file, index_col=0)

print(f"读取完成，共 {len(df)} 行数据")
print(f"原始列名: {df.columns.tolist()}")

# 将 create_time 重命名为 apply_time
if 'create_time' in df.columns:
    df = df.rename(columns={'create_time': 'apply_time'})
    print("已将 create_time 重命名为 apply_time")

print(f"最终列名: {df.columns.tolist()}")

# 保存为 pkl 文件
output_file = script_dir / 'cdc灰度验证.pkl'
print(f"正在保存为 {output_file}...")

with open(output_file, 'wb') as f:
    pickle.dump(df, f)

print(f"转换完成！文件已保存为: {output_file}")
print(f"数据形状: {df.shape}")
