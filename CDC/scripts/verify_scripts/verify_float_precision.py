#!/usr/bin/env python3
"""
验证CDC板块衍生脚本的浮点数精度处理

检查四个板块的notebook文件中是否都包含 round(6) 处理
"""

import json
import re
from pathlib import Path


def check_notebook_round6(notebook_path):
    """检查notebook文件中是否有round(6)处理"""
    with open(notebook_path, 'r', encoding='utf-8') as f:
        notebook = json.load(f)
    
    has_round6 = False
    round6_locations = []
    
    for idx, cell in enumerate(notebook.get('cells', [])):
        if cell.get('cell_type') == 'code':
            source = ''.join(cell.get('source', []))
            
            # 查找 round(6) 的使用
            if 'round(6)' in source:
                has_round6 = True
                # 提取包含round(6)的行
                lines = source.split('\n')
                for line_num, line in enumerate(lines, 1):
                    if 'round(6)' in line:
                        round6_locations.append({
                            'cell_index': idx,
                            'line': line.strip(),
                            'context': 'CSV输出' if 'to_csv' in source else '其他'
                        })
    
    return has_round6, round6_locations


def check_zlf_update_comment(notebook_path):
    """检查是否有zlf update注释（针对浮点数处理）"""
    with open(notebook_path, 'r', encoding='utf-8') as f:
        notebook = json.load(f)
    
    has_float_comment = False
    
    for cell in notebook.get('cells', []):
        if cell.get('cell_type') == 'code':
            source = ''.join(cell.get('source', []))
            
            # 查找浮点数相关的zlf update注释
            if 'zlf update' in source.lower() and ('小数' in source or 'round' in source):
                has_float_comment = True
                break
    
    return has_float_comment


def main():
    """主函数"""
    notebooks = [
        'CDC/第一板块衍生.ipynb',
        'CDC/第二板块衍生.ipynb',
        'CDC/第三板块衍生.ipynb',
        'CDC/BOSS板块衍生.ipynb'
    ]
    
    print("=" * 80)
    print("CDC板块衍生脚本 - 浮点数精度处理验证")
    print("=" * 80)
    print()
    
    all_passed = True
    
    for notebook_path in notebooks:
        notebook_file = Path(notebook_path)
        
        if not notebook_file.exists():
            print(f"❌ {notebook_path} - 文件不存在")
            all_passed = False
            continue
        
        print(f"检查: {notebook_path}")
        print("-" * 80)
        
        # 检查round(6)
        has_round6, locations = check_notebook_round6(notebook_path)
        
        if has_round6:
            print(f"✅ 包含 round(6) 处理")
            print(f"   找到 {len(locations)} 处使用")
            
            # 显示详细位置
            for loc in locations:
                print(f"   - Cell {loc['cell_index']}: {loc['line'][:80]}")
        else:
            print(f"❌ 缺少 round(6) 处理")
            all_passed = False
        
        # 检查zlf update注释（仅BOSS板块需要）
        if 'BOSS' in notebook_path:
            has_comment = check_zlf_update_comment(notebook_path)
            if has_comment:
                print(f"✅ 包含 zlf update 注释")
            else:
                print(f"⚠️  缺少 zlf update 注释")
        
        print()
    
    print("=" * 80)
    if all_passed:
        print("✅ 验证通过：所有板块都包含 round(6) 处理")
    else:
        print("❌ 验证失败：部分板块缺少 round(6) 处理")
    print("=" * 80)
    
    return 0 if all_passed else 1


if __name__ == '__main__':
    exit(main())
