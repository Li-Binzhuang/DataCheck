#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
CSV工具模块
功能：提供CSV文件读取、写入等通用功能（支持流式处理）
"""

import csv
import os
from typing import List, Tuple, Iterator, Optional


def read_csv_with_encoding(file_path: str) -> Tuple[List[str], List[List[str]]]:
    """
    通用CSV文件读取函数，自动尝试多种编码
    
    Args:
        file_path: CSV文件路径
    
    Returns:
        (表头列表, 数据行列表)
    """
    if not os.path.exists(file_path):
        raise FileNotFoundError(f"文件不存在: {file_path}")
    
    # 尝试多种编码方式
    encodings = ["utf-8", "gbk", "gb2312", "latin-1", "cp1252", "utf-8-sig"]
    
    for encoding in encodings:
        try:
            headers = []
            rows = []
            with open(file_path, "r", encoding=encoding) as f:
                reader = csv.reader(f)
                headers = next(reader)  # 读取表头
                
                # 读取所有行
                for row in reader:
                    rows.append(row)
            
            print(f"文件读取成功: {file_path}, 使用编码: {encoding}, 共 {len(rows)} 行")
            return headers, rows
        except UnicodeDecodeError:
            continue
        except Exception as e:
            continue
    
    raise Exception(f"读取CSV文件失败: 尝试了多种编码方式({', '.join(encodings)})均失败")


def write_csv_file(file_path: str, headers: List[str], rows: List[List[str]]):
    """
    通用CSV文件写入函数

    Args:
        file_path: 输出文件路径
        headers: 表头列表
        rows: 数据行列表
    """
    # 确保输出目录存在
    output_dir = os.path.dirname(file_path)
    if output_dir and not os.path.exists(output_dir):
        try:
            os.makedirs(output_dir, exist_ok=True)
        except Exception as e:
            print(f"创建目录失败: {output_dir}, 错误: {e}")
    
    with open(file_path, "w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(headers)
        for row in rows:
            writer.writerow(row)


class CSVStreamWriter:
    """
    CSV流式写入器，支持逐行写入，减少内存占用
    
    使用示例:
        with CSVStreamWriter("output.csv", headers) as writer:
            for row in data_generator():
                writer.write_row(row)
    """
    
    def __init__(self, file_path: str, headers: List[str]):
        """
        初始化CSV流式写入器
        
        Args:
            file_path: 输出文件路径
            headers: 表头列表
        """
        self.file_path = file_path
        self.headers = headers
        self.file_handle = None
        self.writer = None
        self.row_count = 0
        
        # 确保输出目录存在
        output_dir = os.path.dirname(file_path)
        if output_dir and not os.path.exists(output_dir):
            try:
                os.makedirs(output_dir, exist_ok=True)
            except Exception as e:
                print(f"创建目录失败: {output_dir}, 错误: {e}")
    
    def __enter__(self):
        """进入上下文管理器"""
        self.file_handle = open(self.file_path, "w", encoding="utf-8", newline="")
        self.writer = csv.writer(self.file_handle)
        self.writer.writerow(self.headers)
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        """退出上下文管理器"""
        if self.file_handle:
            self.file_handle.close()
            if exc_type is None:
                print(f"✅ CSV文件写入完成: {self.file_path}, 共 {self.row_count} 行")
    
    def write_row(self, row: List[str]):
        """
        写入一行数据
        
        Args:
            row: 数据行
        """
        if self.writer:
            self.writer.writerow(row)
            self.row_count += 1
            # 每1000行刷新一次缓冲区
            if self.row_count % 1000 == 0:
                self.file_handle.flush()
    
    def write_rows(self, rows: List[List[str]]):
        """
        批量写入多行数据
        
        Args:
            rows: 数据行列表
        """
        if self.writer:
            for row in rows:
                self.writer.writerow(row)
                self.row_count += 1
            self.file_handle.flush()
