#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
启动前检查脚本
验证所有模块是否可以正常导入
"""

import sys
import os

# 添加路径
sys.path.insert(0, os.path.dirname(__file__))

def check_imports():
    """检查所有关键模块的导入"""
    print("="*80)
    print("MyDataCheck 启动前检查")
    print("="*80)
    
    checks = []
    
    # 1. 检查内存管理模块
    print("\n1. 检查内存管理模块...")
    try:
        from common.memory_manager import MemoryMonitor, MemoryManager
        print("   ✅ memory_manager 导入成功")
        checks.append(True)
    except Exception as e:
        print(f"   ❌ memory_manager 导入失败: {e}")
        checks.append(False)
    
    # 2. 检查CSV工具
    print("\n2. 检查CSV工具...")
    try:
        from common.csv_tool import CSVStreamWriter, read_csv_with_encoding
        print("   ✅ csv_tool 导入成功")
        checks.append(True)
    except Exception as e:
        print(f"   ❌ csv_tool 导入失败: {e}")
        checks.append(False)
    
    # 3. 检查报告生成器
    print("\n3. 检查报告生成器...")
    try:
        from common.report_generator import write_analysis_record_csv
        print("   ✅ report_generator 导入成功")
        checks.append(True)
    except Exception as e:
        print(f"   ❌ report_generator 导入失败: {e}")
        checks.append(False)
    
    # 4. 检查接口对比模块
    print("\n4. 检查接口对比模块...")
    try:
        from api_comparison.job.compare_api_data import DataComparator
        print("   ✅ api_comparison 导入成功")
        checks.append(True)
    except Exception as e:
        print(f"   ❌ api_comparison 导入失败: {e}")
        checks.append(False)
    
    # 5. 检查数据对比模块
    print("\n5. 检查数据对比模块...")
    try:
        from data_comparison.job.data_comparator import compare_two_files
        print("   ✅ data_comparison 导入成功")
        checks.append(True)
    except Exception as e:
        print(f"   ❌ data_comparison 导入失败: {e}")
        checks.append(False)
    
    # 6. 检查Flask依赖
    print("\n6. 检查Flask依赖...")
    try:
        import flask
        print(f"   ✅ Flask 已安装 (版本: {flask.__version__})")
        checks.append(True)
    except Exception as e:
        print(f"   ❌ Flask 未安装: {e}")
        checks.append(False)
    
    # 7. 检查pandas依赖
    print("\n7. 检查pandas依赖...")
    try:
        import pandas
        print(f"   ✅ pandas 已安装 (版本: {pandas.__version__})")
        checks.append(True)
    except Exception as e:
        print(f"   ❌ pandas 未安装: {e}")
        checks.append(False)
    
    # 8. 检查psutil依赖
    print("\n8. 检查psutil依赖...")
    try:
        import psutil
        print(f"   ✅ psutil 已安装 (版本: {psutil.__version__})")
        checks.append(True)
    except Exception as e:
        print(f"   ❌ psutil 未安装: {e}")
        checks.append(False)
    
    # 总结
    print("\n" + "="*80)
    print("检查结果")
    print("="*80)
    
    passed = sum(checks)
    total = len(checks)
    
    print(f"\n通过: {passed}/{total}")
    
    if all(checks):
        print("\n✅ 所有检查通过！可以启动服务")
        print("\n启动命令:")
        print("  ./start_web.sh")
        print("\n或:")
        print("  source .venv/bin/activate")
        print("  python web_app.py")
        return True
    else:
        print("\n❌ 部分检查失败，请先解决问题")
        print("\n建议:")
        print("  1. 检查虚拟环境是否激活")
        print("  2. 安装缺失的依赖: pip install -r requirements.txt")
        print("  3. 检查Python版本: python --version (推荐 3.12)")
        return False


if __name__ == "__main__":
    success = check_imports()
    sys.exit(0 if success else 1)
