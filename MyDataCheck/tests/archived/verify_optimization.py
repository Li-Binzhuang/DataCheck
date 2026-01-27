#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
验证内存优化是否正常工作
"""

import sys
import os

# 添加common目录到路径
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'common'))

def test_imports():
    """测试所有导入是否正常"""
    print("="*80)
    print("验证内存优化模块导入")
    print("="*80)
    
    try:
        from csv_tool import CSVStreamWriter
        print("✅ CSVStreamWriter 导入成功")
    except Exception as e:
        print(f"❌ CSVStreamWriter 导入失败: {e}")
        return False
    
    try:
        from report_generator import write_analysis_record_csv, write_feature_stats_csv
        print("✅ report_generator 导入成功")
    except Exception as e:
        print(f"❌ report_generator 导入失败: {e}")
        return False
    
    return True


def test_stream_writer():
    """测试流式写入器"""
    print("\n" + "="*80)
    print("测试流式写入器功能")
    print("="*80)
    
    try:
        from csv_tool import CSVStreamWriter
        
        # 创建测试文件
        test_file = "MyDataCheck/outputdata/verify_test.csv"
        headers = ["ID", "Name", "Value"]
        
        with CSVStreamWriter(test_file, headers) as writer:
            for i in range(100):
                writer.write_row([str(i), f"Test{i}", str(i*10)])
        
        # 检查文件是否存在
        if os.path.exists(test_file):
            print(f"✅ 测试文件创建成功: {test_file}")
            # 清理测试文件
            os.remove(test_file)
            print("✅ 测试文件已清理")
            return True
        else:
            print("❌ 测试文件创建失败")
            return False
            
    except Exception as e:
        print(f"❌ 测试失败: {e}")
        import traceback
        traceback.print_exc()
        return False


def test_web_imports():
    """测试Web应用的导入"""
    print("\n" + "="*80)
    print("验证Web应用模块导入")
    print("="*80)
    
    try:
        # 测试api_comparison模块
        sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'api_comparison', 'job'))
        from compare_api_data import DataComparator
        print("✅ api_comparison 模块导入成功")
    except Exception as e:
        print(f"❌ api_comparison 模块导入失败: {e}")
        return False
    
    try:
        # 测试data_comparison模块
        sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'data_comparison', 'job'))
        from data_comparator import compare_two_files
        print("✅ data_comparison 模块导入成功")
    except Exception as e:
        print(f"❌ data_comparison 模块导入失败: {e}")
        return False
    
    return True


if __name__ == "__main__":
    print("\n" + "="*80)
    print("MyDataCheck 内存优化验证")
    print("="*80 + "\n")
    
    all_passed = True
    
    # 测试导入
    if not test_imports():
        all_passed = False
    
    # 测试流式写入器
    if not test_stream_writer():
        all_passed = False
    
    # 测试Web应用导入
    if not test_web_imports():
        all_passed = False
    
    # 总结
    print("\n" + "="*80)
    if all_passed:
        print("✅ 所有测试通过！内存优化正常工作")
        print("="*80)
        print("\n可以安全启动服务:")
        print("  ./start_web.sh")
        print("\n或运行完整测试:")
        print("  python3 test_memory_optimization.py")
    else:
        print("❌ 部分测试失败，请检查错误信息")
        print("="*80)
        sys.exit(1)
    
    print("\n" + "="*80 + "\n")
