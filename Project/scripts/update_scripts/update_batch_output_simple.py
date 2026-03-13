#!/usr/bin/env python3
"""
CDC板块衍生脚本 - 简化版分批输出更新脚本

直接替换notebook中的特定代码段

使用方法:
    python update_batch_output_simple.py

修改标识: zlf update
"""

import json
import sys
from pathlib import Path


def process_notebook(nb_path, config):
    """处理单个notebook文件"""
    print(f"\n{'='*60}")
    print(f"处理: {nb_path.name}")
    print(f"{'='*60}")
    
    with open(nb_path, 'r', encoding='utf-8') as f:
        nb = json.load(f)
    
    modified = False
    
    for cell_idx, cell in enumerate(nb['cells']):
        if cell['cell_type'] != 'code':
            continue
        
        source_text = ''.join(cell['source'])
        
        # 步骤1: 替换配置部分
        if 'WRITE_SAMPLE_200 = True' in source_text and not modified:
            print(f"  [步骤1] Cell {cell_idx}: 更新配置")
            
            new_source = []
            for line in cell['source']:
                if 'WRITE_SAMPLE_200 = True' in line:
                    new_source.append("# zlf update: 改为分批输出，每个文件500条数据\n")
                    new_source.append("BATCH_SIZE = 500  # 每个文件的行数，可以根据需要调整\n")
                elif 'features_out_path' in line or 'features_sample200_path' in line or 'feat_out_path' in line:
                    if 'csv_filename' not in line:
                        continue  # 跳过这些行
                    new_source.append(line)
                else:
                    new_source.append(line)
            
            cell['source'] = new_source
            modified = True
    
    if modified:
        with open(nb_path, 'w', encoding='utf-8') as f:
            json.dump(nb, f, ensure_ascii=False, indent=1)
        print(f"  [完成] 已保存\n")
        return True
    
    print(f"  [跳过] 未找到需要修改的内容\n")
    return False


def main():
    notebooks = [
        'CDC/第一板块衍生.ipynb',
        'CDC/第二板块衍生.ipynb',
        'CDC/第三板块衍生.ipynb',
        'CDC/BOSS板块衍生.ipynb'
    ]
    
    print("\nCDC板块衍生脚本 - 分批输出功能更新")
    print("="*60)
    
    for nb_file in notebooks:
        nb_path = Path(nb_file)
        if nb_path.exists():
            process_notebook(nb_path, {})
    
    print("\n完成！\n")


if __name__ == '__main__':
    main()
