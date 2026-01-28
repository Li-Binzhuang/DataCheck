#!/usr/bin/env python3
"""
zlf update: 全面修改四个板块衍生脚本,将特征空值填充从0改为-999

修改策略:
1. 保留字符串填充: fillna("") 不变
2. 修改数值填充: fillna(0) -> fillna(-999)
3. 修改数值填充: fillna(0.0) -> fillna(-999.0)
4. 在修改行前添加 "zlf update" 注释
"""

import json
import re
from pathlib import Path


def should_modify_line(line: str) -> bool:
    """判断是否应该修改这一行"""
    # 排除字符串填充
    if 'fillna("")' in line or "fillna('')" in line:
        return False
    
    # 包含数值0的fillna
    if '.fillna(0)' in line or '.fillna(0.0)' in line:
        return True
    
    return False


def add_zlf_comment(line: str) -> str:
    """在行前添加zlf update注释"""
    indent = len(line) - len(line.lstrip())
    return ' ' * indent + '# zlf update: 特征值为空时填充-999\n'


def update_fillna_in_line(line: str) -> str:
    """更新行中的fillna(0)为fillna(-999)"""
    # 替换 .fillna(0) 为 .fillna(-999)
    line = re.sub(r'\.fillna\(0\)', '.fillna(-999)', line)
    # 替换 .fillna(0.0) 为 .fillna(-999.0)
    line = re.sub(r'\.fillna\(0\.0\)', '.fillna(-999.0)', line)
    return line


def update_notebook(notebook_path: Path) -> dict:
    """更新单个notebook文件,返回统计信息"""
    print(f"\n{'='*60}")
    print(f"处理文件: {notebook_path.name}")
    print(f"{'='*60}")
    
    with open(notebook_path, 'r', encoding='utf-8') as f:
        nb = json.load(f)
    
    stats = {
        'total_cells': 0,
        'modified_cells': 0,
        'modified_lines': 0,
        'modifications': []
    }
    
    for cell_idx, cell in enumerate(nb.get('cells', [])):
        if cell.get('cell_type') != 'code':
            continue
        
        stats['total_cells'] += 1
        source_lines = cell.get('source', [])
        if not source_lines:
            continue
        
        new_source = []
        cell_modified = False
        
        for line_idx, line in enumerate(source_lines):
            if should_modify_line(line):
                # 添加zlf update注释
                comment = add_zlf_comment(line)
                new_source.append(comment)
                
                # 修改fillna
                updated_line = update_fillna_in_line(line)
                new_source.append(updated_line)
                
                # 记录修改
                cell_modified = True
                stats['modified_lines'] += 1
                
                # 截取行内容用于显示
                display_line = line.strip()
                if len(display_line) > 70:
                    display_line = display_line[:70] + '...'
                
                modification_info = {
                    'cell': cell_idx + 1,
                    'line': line_idx + 1,
                    'original': display_line,
                    'updated': updated_line.strip()[:70] + ('...' if len(updated_line.strip()) > 70 else '')
                }
                stats['modifications'].append(modification_info)
                
                print(f"  [Cell {cell_idx+1}, Line {line_idx+1}]")
                print(f"    原始: {display_line}")
                print(f"    修改: {modification_info['updated']}")
            else:
                new_source.append(line)
        
        if cell_modified:
            stats['modified_cells'] += 1
            cell['source'] = new_source
    
    # 保存修改后的notebook
    with open(notebook_path, 'w', encoding='utf-8') as f:
        json.dump(nb, f, ensure_ascii=False, indent=1)
    
    return stats


def print_summary(all_stats: dict):
    """打印总结信息"""
    print("\n" + "="*60)
    print("修改总结")
    print("="*60)
    
    total_files = len(all_stats)
    total_modified_lines = sum(s['modified_lines'] for s in all_stats.values())
    
    print(f"\n处理文件数: {total_files}")
    print(f"总修改行数: {total_modified_lines}\n")
    
    for filename, stats in all_stats.items():
        print(f"{filename}:")
        print(f"  - 代码单元格数: {stats['total_cells']}")
        print(f"  - 修改的单元格: {stats['modified_cells']}")
        print(f"  - 修改的行数: {stats['modified_lines']}")
    
    print("\n" + "="*60)
    print("zlf update: 所有修改已完成!")
    print("="*60)


def main():
    """主函数"""
    base_dir = Path(__file__).parent
    
    notebooks = [
        "第一板块衍生.ipynb",
        "第二板块衍生.ipynb",
        "第三板块衍生.ipynb",
        "BOSS板块衍生.ipynb",
    ]
    
    print("="*60)
    print("zlf update: 开始全面修改板块衍生脚本")
    print("将特征空值填充从 0 改为 -999")
    print("="*60)
    
    all_stats = {}
    
    for nb_name in notebooks:
        nb_path = base_dir / nb_name
        
        if not nb_path.exists():
            print(f"\n警告: 文件不存在 - {nb_name}")
            continue
        
        try:
            stats = update_notebook(nb_path)
            all_stats[nb_name] = stats
        except Exception as e:
            print(f"\n错误: 处理 {nb_name} 时出错: {e}")
            import traceback
            traceback.print_exc()
    
    if all_stats:
        print_summary(all_stats)
    else:
        print("\n没有文件被修改")


if __name__ == "__main__":
    main()
