#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
将 pkl_20260204.csv 转换为 pkl 文件
"""

import pandas as pd
from pathlib import Path

# 文件路径
CSV_FILE = Path(__file__).parent / "cdc灰度验证800001575242.csv"
PKL_FILE = Path(__file__).parent / "cdc灰度验证800001575242.pkl"

def main():
    print(f"读取 CSV 文件: {CSV_FILE}")
    
    # 尝试不同编码读取
    df = None
    for encoding in ['utf-8-sig', 'utf-8', 'gbk', 'latin1']:
        try:
            df = pd.read_csv(CSV_FILE, encoding=encoding)
            print(f"使用编码: {encoding}")
            break
        except Exception as e:
            continue
    
    if df is None:
        print("无法读取 CSV 文件")
        return
    
    print(f"数据行数: {len(df)}")
    print(f"数据列数: {len(df.columns)}")
    print(f"列名: {list(df.columns)}")
    
    # 保存为 pkl 文件
    df.to_pickle(PKL_FILE)
    print(f"\n已保存为 PKL 文件: {PKL_FILE}")

if __name__ == "__main__":
    main()
