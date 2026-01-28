#!/usr/bin/env python3
"""
CDC板块衍生脚本 - 禁用明细文件输出

将 WRITE_FLAT_CSV 改为 False，只输出特征文件

使用方法:
    python disable_flat_csv_output.py

修改标识: zlf update
"""

import json
from pathlib import Path


def update_notebook_disable_flat_csv(notebook_path):
    """
    更新notebook，将 WRITE_FLAT_CSV 改为 False
    
    Args:
        notebook_path: notebook文件路径
    """
    print(f"\n{'='*60}")
    print(f"处理文件: {notebook_path.name}")
    print(f"{'='*60}\n")
    
    # 读取notebook
    with open(notebook_path, 'r', encoding='utf-8') as f:
        nb = json.load(f)
    
    modified = False
    
    # 遍历所有cell
    for cell_idx, cell in enumerate(nb['cells']):
        if cell['cell_type'] != 'code':
            continue
            
        source = cell['source']
        if not source:
            continue
        
        # 检查是否包含 WRITE_FLAT_CSV = True
        source_text = ''.join(source)
        
        if 'WRITE_FLAT_CSV = True' in source_text:
            print(f"[FOUND] Cell {cell_idx}: 找到 WRITE_FLAT_CSV = True")
            
            # 修改配置
            new_source = []
            for line in source:
                if 'WRITE_FLAT_CSV = True' in line:
                    # 替换为 False，并添加注释
                    new_line = line.replace('WRITE_FLAT_CSV = True', 'WRITE_FLAT_CSV = False')
                    # 添加 zlf update 注释
                    if '# True' in new_line:
                        new_line = new_line.split('#')[0] + '# zlf update: 暂不输出明细文件，只输出特征文件\n'
                    new_source.append(new_line)
                    modified = True
                    print(f"[UPDATE] 已将 WRITE_FLAT_CSV 改为 False")
                else:
                    new_source.append(line)
            
            cell['source'] = new_source
    
    if modified:
        # 保存修改后的notebook
        with open(notebook_path, 'w', encoding='utf-8') as f:
            json.dump(nb, f, ensure_ascii=False, indent=1)
        print(f"\n[SUCCESS] 已保存修改: {notebook_path.name}\n")
        return True
    else:
        print(f"\n[INFO] 未找到 WRITE_FLAT_CSV = True\n")
        return False


def main():
    """主函数"""
    # 定义需要修改的三个板块（BOSS板块没有WRITE_FLAT_CSV）
    notebooks = [
        'CDC/第一板块衍生.ipynb',
        'CDC/第二板块衍生.ipynb',
        'CDC/第三板块衍生.ipynb',
    ]
    
    print("\n" + "="*60)
    print("CDC板块衍生脚本 - 禁用明细文件输出")
    print("="*60)
    print("\n将 WRITE_FLAT_CSV 改为 False，只输出特征文件\n")
    
    success_count = 0
    for nb_file in notebooks:
        nb_path = Path(nb_file)
        if not nb_path.exists():
            print(f"\n[ERROR] 文件不存在: {nb_path}")
            continue
        
        if update_notebook_disable_flat_csv(nb_path):
            success_count += 1
    
    print("\n" + "="*60)
    print(f"完成！成功修改 {success_count}/{len(notebooks)} 个文件")
    print("="*60)
    print("\n修改内容:")
    print("  - WRITE_FLAT_CSV: True → False")
    print("  - 添加注释: zlf update: 暂不输出明细文件，只输出特征文件")
    print("\n结果:")
    print("  - 第一板块: 不再输出 consultas_flat.csv")
    print("  - 第二板块: 不再输出 creditos_flat.csv")
    print("  - 第三板块: 不再输出 clave_prevencion_flat.csv")
    print("  - BOSS板块: 无需修改（本来就只输出特征文件）")
    print("\n")


if __name__ == '__main__':
    main()
