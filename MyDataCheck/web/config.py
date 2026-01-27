#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Web应用配置模块

功能说明:
    - 定义项目目录结构
    - 配置Flask应用参数
    - 管理文件上传限制
    - 提供目录初始化和文件验证工具

作者: MyDataCheck Team
创建时间: 2026-01
最后更新: 2026-01-27
"""

import os

# ==================== 目录配置 ====================

# 获取项目根目录（MyDataCheck目录）
SCRIPT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# 各功能模块目录
JOB_DIR = os.path.join(SCRIPT_DIR, "api_comparison", "job")                    # 接口对比任务目录
ONLINE_COMPARISON_DIR = os.path.join(SCRIPT_DIR, "online_comparison")          # 线上对比目录
ONLINE_JOB_DIR = os.path.join(ONLINE_COMPARISON_DIR, "job")                    # 线上对比任务目录
DATA_COMPARISON_DIR = os.path.join(SCRIPT_DIR, "data_comparison")              # 数据对比目录
DATA_COMPARISON_JOB_DIR = os.path.join(DATA_COMPARISON_DIR, "job")             # 数据对比任务目录
COMMON_DIR = os.path.join(SCRIPT_DIR, "common")                                # 公共工具目录

# 输出数据目录（存放对比结果）
OUTPUT_DATA_DIR = os.path.join(SCRIPT_DIR, "outputdata")                       # 输出数据根目录
API_OUTPUT_DIR = os.path.join(OUTPUT_DATA_DIR, "api_comparison")               # 接口对比输出目录
ONLINE_OUTPUT_DIR = os.path.join(OUTPUT_DATA_DIR, "online_comparison")         # 线上对比输出目录
COMPARE_OUTPUT_DIR = os.path.join(OUTPUT_DATA_DIR, "data_comparison")          # 数据对比输出目录

# 输入数据目录（存放待对比文件）
INPUT_DATA_DIR = os.path.join(SCRIPT_DIR, "inputdata")                         # 输入数据根目录
API_INPUT_DIR = os.path.join(INPUT_DATA_DIR, "api_comparison")                 # 接口对比输入目录
ONLINE_INPUT_DIR = os.path.join(INPUT_DATA_DIR, "online_comparison")           # 线上对比输入目录
COMPARE_INPUT_DIR = os.path.join(INPUT_DATA_DIR, "data_comparison")            # 数据对比输入目录

# ==================== Flask配置 ====================

# 文件上传大小限制（1GB）
MAX_CONTENT_LENGTH = 1024 * 1024 * 1024  # 1GB = 1024MB = 1024*1024KB = 1024*1024*1024B

# 允许的文件扩展名
ALLOWED_EXTENSIONS = {'csv', 'pkl', 'xlsx'}

# ==================== 工具函数 ====================

def init_directories():
    """
    初始化所有必要的目录
    
    功能:
        创建输入输出数据目录，如果目录已存在则跳过
    
    目录列表:
        - API对比输入输出目录
        - 线上对比输入输出目录
        - 数据对比输入输出目录
    
    Note:
        该函数在应用启动时自动调用，确保目录结构完整
    
    示例:
        >>> init_directories()
        # 创建所有必要的目录
    """
    directories = [
        API_OUTPUT_DIR,      # 接口对比输出
        ONLINE_OUTPUT_DIR,   # 线上对比输出
        COMPARE_OUTPUT_DIR,  # 数据对比输出
        API_INPUT_DIR,       # 接口对比输入
        ONLINE_INPUT_DIR,    # 线上对比输入
        COMPARE_INPUT_DIR    # 数据对比输入
    ]
    
    for directory in directories:
        os.makedirs(directory, exist_ok=True)


def allowed_file(filename, extensions=None):
    """
    检查文件扩展名是否允许
    
    Args:
        filename (str): 文件名（包含扩展名）
        extensions (set, optional): 允许的扩展名集合，默认使用ALLOWED_EXTENSIONS
    
    Returns:
        bool: 如果文件扩展名在允许列表中返回True，否则返回False
    
    示例:
        >>> allowed_file('data.csv')
        True
        >>> allowed_file('data.txt')
        False
        >>> allowed_file('data.xlsx', {'xlsx', 'xls'})
        True
    
    Note:
        - 扩展名检查不区分大小写
        - 文件名必须包含点号(.)
    """
    if extensions is None:
        extensions = ALLOWED_EXTENSIONS
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in extensions
