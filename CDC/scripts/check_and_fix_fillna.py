#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
检查并修复CDC衍生脚本中的空值填充问题
确保所有空值都填充为-999
"""

import re
import json
import os


def check_notebook_fillna(notebook_path):
    """
    检查notebook中的fillna使用情况
    
    Returns:
        dict: 检查结果
    """
    print(f"\n{'='*80}")
    print(f"检查文件: {os.path.basename(notebook_path)}")
    print(f"{'='*80}")
    
    with open(notebook_path, 'r', encoding='utf-8') as f:
        notebook = json.load(f)
    
    results = {
        'fillna_0': [],  # fillna(0)
        'fillna_empty': [],  # fillna("")
        'fillna_nan': [],  # fillna(np.nan)
        'fillna_minus999': [],  # fillna(-999)
        'assign_nan': [],  # = np.nan
        'assign_0': [],  # = 0 (可能需要改为-999)
        'cnt_features': [],  # cnt特征
        'sumsq_features': [],  # sumsq特征
        'cnt_in_ndays_features': [],  # cnt_in_Ndays特征
    }
    
    line_num = 0
    for cell in notebook['cells']:
        if cell['cell_type'] == 'code':
            source = ''.join(cell['source'])
            lines = source.split('\n')
            
            for i, line in enumerate(lines):
                line_num += 1
                
                # 跳过注释行
                if line.strip().startswith('#'):
                    continue
                
                # 检查 fillna(0)
                if re.search(r'\.fillna\(0\)', line):
                    results['fillna_0'].append((line_num, line.strip()))
                
                # 检查 fillna("")
                if re.search(r'\.fillna\(["\'][\'"]\)', line):
                    results['fillna_empty'].append((line_num, line.strip()))
                
                # 检查 fillna(np.nan)
                if re.search(r'\.fillna\(np\.nan\)', line):
                    results['fillna_nan'].append((line_num, line.strip()))
                
                # 检查 fillna(-999)
                if re.search(r'\.fillna\(-999', line):
                    results['fillna_minus999'].append((line_num, line.strip()))
                
                # 检查 = np.nan
                if re.search(r'=\s*np\.nan', line) and 'fillna' not in line:
                    results['assign_nan'].append((line_num, line.strip()))
                
                # 检查 = 0 (特征赋值)
                if re.search(r'out\[.*\]\s*=\s*0(?:\.0)?(?:\s|$)', line):
                    results['assign_0'].append((line_num, line.strip()))
                
                # 检查 cnt 特征
                if re.search(r'_cnt["\']?\]?\s*=', line):
                    results['cnt_features'].append((line_num, line.strip()))
                
                # 检查 sumsq 特征
                if re.search(r'_sumsq["\']?\]?\s*=', line):
                    results['sumsq_features'].append((line_num, line.strip()))
                
                # 检查 cnt_in_Ndays 特征
                if re.search(r'_cnt_in_\d+days["\']?\]?\s*=', line):
                    results['cnt_in_ndays_features'].append((line_num, line.strip()))
    
    return results


def print_results(results, notebook_name):
    """打印检查结果"""
    print(f"\n检查结果汇总:")
    print(f"-" * 80)
    
    # fillna(0)
    if results['fillna_0']:
        print(f"\n⚠️  发现 {len(results['fillna_0'])} 处 fillna(0)，可能需要改为 fillna(-999):")
        for line_num, line in results['fillna_0'][:5]:
            print(f"  行 {line_num}: {line[:100]}")
        if len(results['fillna_0']) > 5:
            print(f"  ... 还有 {len(results['fillna_0']) - 5} 处")
    else:
        print(f"\n✅ 未发现 fillna(0)")
    
    # fillna("")
    if results['fillna_empty']:
        print(f"\n✅ 发现 {len(results['fillna_empty'])} 处 fillna(\"\")（字符串字段，正常）")
    
    # fillna(np.nan)
    if results['fillna_nan']:
        print(f"\n❌ 发现 {len(results['fillna_nan'])} 处 fillna(np.nan)，需要改为 fillna(-999):")
        for line_num, line in results['fillna_nan']:
            print(f"  行 {line_num}: {line[:100]}")
    else:
        print(f"\n✅ 未发现 fillna(np.nan)")
    
    # fillna(-999)
    if results['fillna_minus999']:
        print(f"\n✅ 发现 {len(results['fillna_minus999'])} 处 fillna(-999)（正确）")
    
    # = np.nan
    if results['assign_nan']:
        print(f"\n❌ 发现 {len(results['assign_nan'])} 处 = np.nan，需要改为 = -999:")
        for line_num, line in results['assign_nan']:
            print(f"  行 {line_num}: {line[:100]}")
    else:
        print(f"\n✅ 未发现 = np.nan")
    
    # = 0
    if results['assign_0']:
        print(f"\n⚠️  发现 {len(results['assign_0'])} 处特征赋值为 0，请检查是否应该为 -999:")
        for line_num, line in results['assign_0'][:10]:
            print(f"  行 {line_num}: {line[:100]}")
        if len(results['assign_0']) > 10:
            print(f"  ... 还有 {len(results['assign_0']) - 10} 处")
    
    # cnt 特征
    if results['cnt_features']:
        print(f"\n📊 发现 {len(results['cnt_features'])} 处 cnt 特征（需确保空值为-999）")
    
    # sumsq 特征
    if results['sumsq_features']:
        print(f"\n📊 发现 {len(results['sumsq_features'])} 处 sumsq 特征（需确保空值为-999）")
    
    # cnt_in_Ndays 特征
    if results['cnt_in_ndays_features']:
        print(f"\n📊 发现 {len(results['cnt_in_ndays_features'])} 处 cnt_in_Ndays 特征（需确保空值为-999）")


def generate_fix_suggestions(results, notebook_name):
    """生成修复建议"""
    print(f"\n{'='*80}")
    print(f"修复建议")
    print(f"{'='*80}")
    
    has_issues = False
    
    # fillna(0) 需要修复
    if results['fillna_0']:
        has_issues = True
        print(f"\n1. 修复 fillna(0) → fillna(-999)")
        print(f"   共 {len(results['fillna_0'])} 处需要修改")
        print(f"   建议：将所有 .fillna(0) 改为 .fillna(-999)")
    
    # fillna(np.nan) 需要修复
    if results['fillna_nan']:
        has_issues = True
        print(f"\n2. 修复 fillna(np.nan) → fillna(-999)")
        print(f"   共 {len(results['fillna_nan'])} 处需要修改")
        print(f"   建议：将所有 .fillna(np.nan) 改为 .fillna(-999)")
    
    # = np.nan 需要修复
    if results['assign_nan']:
        has_issues = True
        print(f"\n3. 修复 = np.nan → = -999")
        print(f"   共 {len(results['assign_nan'])} 处需要修改")
        print(f"   建议：将所有 = np.nan 改为 = -999")
    
    # = 0 可能需要修复
    if results['assign_0']:
        has_issues = True
        print(f"\n4. 检查 = 0 是否应该为 = -999")
        print(f"   共 {len(results['assign_0'])} 处需要检查")
        print(f"   建议：检查这些特征，如果是空值情况应该改为 -999")
    
    if not has_issues:
        print(f"\n✅ 未发现需要修复的问题！")
    
    return has_issues


def main():
    """主函数"""
    print("=" * 80)
    print("CDC衍生脚本空值填充检查工具")
    print("=" * 80)
    
    # 获取脚本所在目录的父目录（CDC目录）
    script_dir = os.path.dirname(os.path.abspath(__file__))
    cdc_dir = os.path.dirname(script_dir)
    
    notebooks = [
        os.path.join(cdc_dir, "第一板块衍生.ipynb"),
        os.path.join(cdc_dir, "第二板块衍生.ipynb"),
        os.path.join(cdc_dir, "第三板块衍生.ipynb"),
        os.path.join(cdc_dir, "BOSS板块衍生.ipynb")
    ]
    
    all_results = {}
    
    for notebook in notebooks:
        if os.path.exists(notebook):
            results = check_notebook_fillna(notebook)
            all_results[notebook] = results
            print_results(results, os.path.basename(notebook))
            generate_fix_suggestions(results, os.path.basename(notebook))
        else:
            print(f"\n❌ 文件不存在: {notebook}")
    
    # 总结
    print(f"\n{'='*80}")
    print(f"总体汇总")
    print(f"{'='*80}")
    
    total_fillna_0 = sum(len(r['fillna_0']) for r in all_results.values())
    total_fillna_nan = sum(len(r['fillna_nan']) for r in all_results.values())
    total_assign_nan = sum(len(r['assign_nan']) for r in all_results.values())
    total_assign_0 = sum(len(r['assign_0']) for r in all_results.values())
    total_fillna_minus999 = sum(len(r['fillna_minus999']) for r in all_results.values())
    
    print(f"\n所有文件统计:")
    print(f"  fillna(0): {total_fillna_0} 处")
    print(f"  fillna(np.nan): {total_fillna_nan} 处")
    print(f"  = np.nan: {total_assign_nan} 处")
    print(f"  = 0: {total_assign_0} 处")
    print(f"  fillna(-999): {total_fillna_minus999} 处 ✅")
    
    if total_fillna_0 + total_fillna_nan + total_assign_nan > 0:
        print(f"\n⚠️  发现 {total_fillna_0 + total_fillna_nan + total_assign_nan} 处需要修复的问题")
    else:
        print(f"\n✅ 所有文件的空值填充都正确！")


if __name__ == "__main__":
    main()
