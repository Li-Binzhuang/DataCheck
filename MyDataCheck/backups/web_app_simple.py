#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
数据对比 - Web界面主入口（模块化版本）

功能：提供Web界面用于输入配置和执行对比流程
- 接口数据对比
- 线上灰度落数对比  
- 数据对比
- PKL文件解析

版本：v2.0（模块化重构版）
更新时间：2026-01-27
"""

import os
import sys

# 添加当前目录到路径
sys.path.insert(0, os.path.dirname(__file__))

# 导入模块化的Flask应用
from web.app import main

if __name__ == '__main__':
    main()
