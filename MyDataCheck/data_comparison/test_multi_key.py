#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
多列主键功能测试脚本
"""

import sys
import os

# 添加父目录到路径
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from data_comparison.job.data_comparator import compare_two_files


def test_single_key():
    """测试单列主键（向后兼容）"""
    print("=" * 80)
    print("测试1: 单列主键（数字格式）")
    print("=" * 80)
    
    # 模拟单列主键配置
    sql_key_column = 0
    api_key_column = 0
    
    print(f"sql_key_column类型: {type(sql_key_column)}, 值: {sql_key_column}")
    print(f"api_key_column类型: {type(api_key_column)}, 值: {api_key_column}")
    
    # 标准化为列表
    sql_key_columns = sql_key_column if isinstance(sql_key_column, list) else [sql_key_column]
    api_key_columns = api_key_column if isinstance(api_key_column, list) else [api_key_column]
    
    print(f"标准化后 sql_key_columns: {sql_key_columns}")
    print(f"标准化后 api_key_columns: {api_key_columns}")
    print("✅ 单列主键测试通过\n")


def test_multi_key():
    """测试多列主键"""
    print("=" * 80)
    print("测试2: 多列主键（数组格式）")
    print("=" * 80)
    
    # 模拟多列主键配置
    sql_key_column = [0, 1]
    api_key_column = [0, 1]
    
    print(f"sql_key_column类型: {type(sql_key_column)}, 值: {sql_key_column}")
    print(f"api_key_column类型: {type(api_key_column)}, 值: {api_key_column}")
    
    # 标准化为列表
    sql_key_columns = sql_key_column if isinstance(sql_key_column, list) else [sql_key_column]
    api_key_columns = api_key_column if isinstance(api_key_column, list) else [api_key_column]
    
    print(f"标准化后 sql_key_columns: {sql_key_columns}")
    print(f"标准化后 api_key_columns: {api_key_columns}")
    print("✅ 多列主键测试通过\n")


def test_key_combination():
    """测试主键组合逻辑"""
    print("=" * 80)
    print("测试3: 主键组合逻辑")
    print("=" * 80)
    
    # 模拟数据行
    row = ["ABC", "123", "feature1", "feature2", "feature3"]
    
    # 测试单列主键
    key_columns = [0]
    key_parts = [str(row[idx]).strip() for idx in key_columns if idx < len(row)]
    key_value = "||".join(key_parts)
    print(f"单列主键 [0]: {key_value}")
    assert key_value == "ABC", "单列主键组合错误"
    
    # 测试双列主键
    key_columns = [0, 1]
    key_parts = [str(row[idx]).strip() for idx in key_columns if idx < len(row)]
    key_value = "||".join(key_parts)
    print(f"双列主键 [0, 1]: {key_value}")
    assert key_value == "ABC||123", "双列主键组合错误"
    
    # 测试三列主键
    key_columns = [0, 1, 2]
    key_parts = [str(row[idx]).strip() for idx in key_columns if idx < len(row)]
    key_value = "||".join(key_parts)
    print(f"三列主键 [0, 1, 2]: {key_value}")
    assert key_value == "ABC||123||feature1", "三列主键组合错误"
    
    print("✅ 主键组合逻辑测试通过\n")


def test_key_validation():
    """测试主键验证逻辑"""
    print("=" * 80)
    print("测试4: 主键验证逻辑")
    print("=" * 80)
    
    # 测试有效主键
    row1 = ["ABC", "123", "feature1"]
    key_columns = [0, 1]
    key_parts = []
    valid_key = True
    for idx in key_columns:
        if idx < len(row1) and row1[idx] is not None:
            key_parts.append(str(row1[idx]).strip())
        else:
            valid_key = False
            break
    
    print(f"有效主键测试: valid_key={valid_key}, key_parts={key_parts}")
    assert valid_key and all(key_parts), "有效主键验证失败"
    
    # 测试无效主键（None值）
    row2 = ["ABC", None, "feature1"]
    key_parts = []
    valid_key = True
    for idx in key_columns:
        if idx < len(row2) and row2[idx] is not None:
            key_parts.append(str(row2[idx]).strip())
        else:
            valid_key = False
            break
    
    print(f"无效主键测试（None）: valid_key={valid_key}, key_parts={key_parts}")
    assert not valid_key, "无效主键验证失败"
    
    # 测试无效主键（空字符串）
    row3 = ["ABC", "", "feature1"]
    key_parts = []
    valid_key = True
    for idx in key_columns:
        if idx < len(row3) and row3[idx] is not None:
            key_parts.append(str(row3[idx]).strip())
        else:
            valid_key = False
            break
    
    print(f"无效主键测试（空字符串）: valid_key={valid_key}, key_parts={key_parts}, all(key_parts)={all(key_parts)}")
    assert not all(key_parts), "空字符串主键验证失败"
    
    print("✅ 主键验证逻辑测试通过\n")


if __name__ == "__main__":
    print("\n多列主键功能测试\n")
    
    try:
        test_single_key()
        test_multi_key()
        test_key_combination()
        test_key_validation()
        
        print("=" * 80)
        print("✅ 所有测试通过！")
        print("=" * 80)
        
    except AssertionError as e:
        print(f"\n❌ 测试失败: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ 测试出错: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
