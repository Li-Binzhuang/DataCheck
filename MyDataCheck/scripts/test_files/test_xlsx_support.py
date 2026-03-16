#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
测试XLSX文件支持功能

用法：
    python test_xlsx_support.py
"""

import os
import sys

# 添加当前目录到路径
sys.path.insert(0, os.path.dirname(__file__))

from common.csv_tool import read_csv_with_encoding


def test_csv_reading():
    """测试CSV文件读取"""
    print("=" * 60)
    print("测试1: CSV文件读取")
    print("=" * 60)
    
    # 查找一个CSV文件进行测试
    test_dirs = ['inputdata', 'api_comparison/inputdata', 'data_comparison/inputdata']
    csv_file = None
    
    for test_dir in test_dirs:
        if os.path.exists(test_dir):
            for f in os.listdir(test_dir):
                if f.endswith('.csv'):
                    csv_file = os.path.join(test_dir, f)
                    break
            if csv_file:
                break
    
    if csv_file:
        try:
            headers, rows = read_csv_with_encoding(csv_file)
            print(f"✅ CSV文件读取成功: {csv_file}")
            print(f"   表头数量: {len(headers)}")
            print(f"   数据行数: {len(rows)}")
            print(f"   前3列表头: {headers[:3]}")
            return True
        except Exception as e:
            print(f"❌ CSV文件读取失败: {str(e)}")
            return False
    else:
        print("⚠️  未找到CSV测试文件，跳过测试")
        return True


def test_xlsx_reading():
    """测试XLSX文件读取"""
    print("\n" + "=" * 60)
    print("测试2: XLSX文件读取")
    print("=" * 60)
    
    # 查找一个XLSX文件进行测试
    test_dirs = ['inputdata', 'api_comparison/inputdata', 'data_comparison/inputdata']
    xlsx_file = None
    
    for test_dir in test_dirs:
        if os.path.exists(test_dir):
            for f in os.listdir(test_dir):
                if f.endswith('.xlsx') or f.endswith('.xls'):
                    xlsx_file = os.path.join(test_dir, f)
                    break
            if xlsx_file:
                break
    
    if xlsx_file:
        try:
            headers, rows = read_csv_with_encoding(xlsx_file)
            print(f"✅ XLSX文件读取成功: {xlsx_file}")
            print(f"   表头数量: {len(headers)}")
            print(f"   数据行数: {len(rows)}")
            print(f"   前3列表头: {headers[:3]}")
            return True
        except ImportError as e:
            print(f"⚠️  需要安装openpyxl库: {str(e)}")
            print(f"   请运行: pip install openpyxl")
            return False
        except Exception as e:
            print(f"❌ XLSX文件读取失败: {str(e)}")
            import traceback
            traceback.print_exc()
            return False
    else:
        print("⚠️  未找到XLSX测试文件，跳过测试")
        print("   提示: 可以手动上传一个XLSX文件到inputdata目录进行测试")
        return True


def test_openpyxl_installation():
    """测试openpyxl库是否已安装"""
    print("\n" + "=" * 60)
    print("测试3: openpyxl库安装检查")
    print("=" * 60)
    
    try:
        import openpyxl
        print(f"✅ openpyxl已安装，版本: {openpyxl.__version__}")
        return True
    except ImportError:
        print("❌ openpyxl未安装")
        print("   请运行: pip install openpyxl")
        return False


def main():
    """主测试函数"""
    print("\n" + "=" * 60)
    print("XLSX文件支持功能测试")
    print("=" * 60)
    
    results = []
    
    # 测试1: openpyxl库安装
    results.append(("openpyxl库安装", test_openpyxl_installation()))
    
    # 测试2: CSV文件读取
    results.append(("CSV文件读取", test_csv_reading()))
    
    # 测试3: XLSX文件读取
    results.append(("XLSX文件读取", test_xlsx_reading()))
    
    # 总结
    print("\n" + "=" * 60)
    print("测试总结")
    print("=" * 60)
    
    for test_name, result in results:
        status = "✅ 通过" if result else "❌ 失败"
        print(f"{test_name}: {status}")
    
    all_passed = all(result for _, result in results)
    
    print("\n" + "=" * 60)
    if all_passed:
        print("🎉 所有测试通过！XLSX文件支持功能正常")
    else:
        print("⚠️  部分测试失败，请检查上述错误信息")
    print("=" * 60)
    
    return 0 if all_passed else 1


if __name__ == '__main__':
    sys.exit(main())
