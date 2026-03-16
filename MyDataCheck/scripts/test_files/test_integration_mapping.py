#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
特征名称映射功能 - 集成测试
测试完整的数据对比流程，包括映射功能
"""

import sys
import os

# 添加项目路径
sys.path.insert(0, os.path.dirname(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'data_comparison', 'job'))

from data_comparison.job.data_comparator import compare_two_files


def test_integration_with_mapping():
    """集成测试：使用映射功能进行数据对比"""
    
    print("="*80)
    print("特征名称映射功能 - 集成测试")
    print("="*80)
    
    # 测试文件路径
    file1_path = os.path.join(os.path.dirname(__file__), 'test_data', 'test_mapping_file1.csv')
    file2_path = os.path.join(os.path.dirname(__file__), 'test_data', 'test_mapping_file2.csv')
    
    print(f"\n测试文件:")
    print(f"  file1: {file1_path}")
    print(f"  file2: {file2_path}")
    
    # 检查文件是否存在
    if not os.path.exists(file1_path):
        print(f"\n❌ 错误: 文件不存在 - {file1_path}")
        return False
    
    if not os.path.exists(file2_path):
        print(f"\n❌ 错误: 文件不存在 - {file2_path}")
        return False
    
    print("\n" + "="*80)
    print("测试场景1: 为file1添加前缀 'model_'")
    print("="*80)
    print("\n预期结果: file1的列名 age, income, score 会映射为 model_age, model_income, model_score")
    print("          然后与file2的列名 model_age, model_income, model_score 进行对比")
    print("          应该完全匹配，无差异\n")
    
    try:
        # 执行对比（启用映射）
        results = compare_two_files(
            sql_file_path=file1_path,
            api_file_path=file2_path,
            sql_key_column=0,  # id列
            api_key_column=0,  # id列
            sql_feature_start=2,  # 从age列开始
            api_feature_start=2,  # 从model_age列开始
            convert_feature_to_number=True,
            ignore_default_fill=False,
            enable_column_mapping=True,  # 启用映射
            mapping_file='file1',  # 为file1添加映射
            mapping_prefix='model_',  # 前缀
            mapping_suffix=''  # 无后缀
        )
        
        # 检查结果
        diff_count = results.get('diff_count', 0)
        matched_count = results.get('matched_count', 0)
        
        print(f"\n对比结果:")
        print(f"  匹配记录数: {matched_count}")
        print(f"  差异数量: {diff_count}")
        
        if diff_count == 0:
            print("\n✅ 测试通过: 启用映射后，所有特征值完全匹配！")
            return True
        else:
            print(f"\n❌ 测试失败: 仍有 {diff_count} 个差异")
            return False
            
    except Exception as e:
        print(f"\n❌ 测试失败: {str(e)}")
        import traceback
        traceback.print_exc()
        return False


def test_integration_without_mapping():
    """集成测试：不使用映射功能进行数据对比（对照组）"""
    
    print("\n" + "="*80)
    print("测试场景2: 不启用映射（对照组）")
    print("="*80)
    print("\n预期结果: file1的列名 age, income, score 与 file2的列名 model_age, model_income, model_score")
    print("          无法匹配，应该有差异\n")
    
    file1_path = os.path.join(os.path.dirname(__file__), 'test_data', 'test_mapping_file1.csv')
    file2_path = os.path.join(os.path.dirname(__file__), 'test_data', 'test_mapping_file2.csv')
    
    try:
        # 执行对比（不启用映射）
        results = compare_two_files(
            sql_file_path=file1_path,
            api_file_path=file2_path,
            sql_key_column=0,
            api_key_column=0,
            sql_feature_start=2,
            api_feature_start=2,
            convert_feature_to_number=True,
            ignore_default_fill=False,
            enable_column_mapping=False,  # 不启用映射
            mapping_file=None,
            mapping_prefix='',
            mapping_suffix=''
        )
        
        # 检查结果
        all_features = results.get('all_features', [])
        
        print(f"\n对比结果:")
        print(f"  实际对比的特征数: {len(all_features)}")
        print(f"  特征列表: {all_features}")
        
        # 不启用映射时，应该只对比file1中存在的特征（age, income, score）
        # 这些特征在file2中不存在（file2有model_age, model_income, model_score）
        # 所以应该无法找到匹配的特征
        
        if len(all_features) == 3 and 'age' in all_features:
            print("\n✅ 测试通过: 不启用映射时，使用file1的原始列名进行对比")
            return True
        else:
            print(f"\n⚠️  测试结果异常: 特征列表不符合预期")
            return False
            
    except Exception as e:
        print(f"\n❌ 测试失败: {str(e)}")
        import traceback
        traceback.print_exc()
        return False


def main():
    """主测试函数"""
    print("\n" + "="*80)
    print("开始集成测试")
    print("="*80)
    
    # 测试1: 启用映射
    test1_passed = test_integration_with_mapping()
    
    # 测试2: 不启用映射（对照组）
    test2_passed = test_integration_without_mapping()
    
    # 总结
    print("\n" + "="*80)
    print("测试总结")
    print("="*80)
    print(f"测试1 (启用映射): {'✅ 通过' if test1_passed else '❌ 失败'}")
    print(f"测试2 (不启用映射): {'✅ 通过' if test2_passed else '❌ 失败'}")
    
    if test1_passed and test2_passed:
        print("\n🎉 所有集成测试通过！")
        print("="*80 + "\n")
        return True
    else:
        print("\n⚠️  部分测试失败，请检查")
        print("="*80 + "\n")
        return False


if __name__ == '__main__':
    success = main()
    sys.exit(0 if success else 1)
