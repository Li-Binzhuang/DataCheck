#!/usr/bin/env python3
"""
zlf update: 修改四个板块衍生脚本,将特征空值填充从0改为-999

功能说明:
1. 读取四个板块衍生的ipynb文件
2. 在关键位置的注释前添加"zlf update"标识
3. 将特征计算中的fillna(0)改为fillna(-999)
4. 保持其他fillna("")等字符串填充不变
"""

import json
import re
from pathlib import Path


def update_notebook(notebook_path: Path) -> None:
    """更新单个notebook文件"""
    print(f"\n处理文件: {notebook_path.name}")
    
    with open(notebook_path, 'r', encoding='utf-8') as f:
        nb = json.load(f)
    
    modified_count = 0
    
    for cell in nb.get('cells', []):
        if cell.get('cell_type') != 'code':
            continue
            
        source_lines = cell.get('source', [])
        if not source_lines:
            continue
        
        new_source = []
        i = 0
        while i < len(source_lines):
            line = source_lines[i]
            
            # 检查是否是需要修改的fillna(0)行
            # 排除fillna("")和fillna("...")这种字符串填充
            if '.fillna(0)' in line and 'fillna("")' not in line:
                # 检查是否是特征计算相关的行
                # 包括: cnt, total, ratio, valid等特征计算
                is_feature_line = any(keyword in line for keyword in [
                    'cnt', 'total', 'ratio', 'valid', 'notnull',
                    'mean', 'std', 'min', 'max', 'sum'
                ])
                
                if is_feature_line:
                    # 在这一行前添加zlf update注释
                    indent = len(line) - len(line.lstrip())
                    comment_line = ' ' * indent + '# zlf update: 特征值为空时填充-999\n'
                    new_source.append(comment_line)
                    
                    # 替换fillna(0)为fillna(-999)
                    updated_line = line.replace('.fillna(0)', '.fillna(-999)')
                    new_source.append(updated_line)
                    modified_count += 1
                    print(f"  修改行: {line.strip()[:80]}...")
                else:
                    new_source.append(line)
            else:
                new_source.append(line)
            
            i += 1
        
        cell['source'] = new_source
    
    # 保存修改后的notebook
    with open(notebook_path, 'w', encoding='utf-8') as f:
        json.dump(nb, f, ensure_ascii=False, indent=1)
    
    print(f"  完成! 共修改 {modified_count} 处")


def main():
    """主函数"""
    base_dir = Path(__file__).parent
    
    notebooks = [
        base_dir / "第一板块衍生.ipynb",
        base_dir / "第二板块衍生.ipynb",
        base_dir / "第三板块衍生.ipynb",
        base_dir / "BOSS板块衍生.ipynb",
    ]
    
    print("=" * 60)
    print("zlf update: 开始批量修改板块衍生脚本")
    print("=" * 60)
    
    total_modified = 0
    for nb_path in notebooks:
        if not nb_path.exists():
            print(f"\n警告: 文件不存在 - {nb_path.name}")
            continue
        
        try:
            update_notebook(nb_path)
            total_modified += 1
        except Exception as e:
            print(f"\n错误: 处理 {nb_path.name} 时出错: {e}")
    
    print("\n" + "=" * 60)
    print(f"完成! 共成功修改 {total_modified} 个文件")
    print("=" * 60)


if __name__ == "__main__":
    main()
