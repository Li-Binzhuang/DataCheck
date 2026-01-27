#!/usr/bin/env python3
"""
为BOSS板块Notebook添加前200条记录输出功能
"""

import json
from pathlib import Path


def add_sample200_to_boss_notebook():
    """为BOSS板块Notebook添加前200条记录输出功能"""
    notebook_path = Path(__file__).parent / 'BOSS板块衍生.ipynb'
    
    print(f"处理 BOSS板块: {notebook_path}")
    
    # 读取notebook
    with open(notebook_path, 'r', encoding='utf-8') as f:
        nb = json.load(f)
    
    # 找到输出代码格（包含 WRITE_FEATURES_CSV 的那个）
    target_cell_idx = None
    for i, cell in enumerate(nb['cells']):
        if cell['cell_type'] == 'code':
            source = ''.join(cell['source'])
            if 'WRITE_FEATURES_CSV = True' in source and 'cdcboss_features_full_data.csv' in source:
                target_cell_idx = i
                break
    
    if target_cell_idx is None:
        print("  警告：未找到BOSS板块的输出代码格")
        return
    
    output_cell = nb['cells'][target_cell_idx]
    source_lines = output_cell['source']
    
    # 检查是否已经添加过
    if any('WRITE_SAMPLE_200' in line for line in source_lines):
        print("  BOSS板块已经添加过 WRITE_SAMPLE_200，跳过")
        return
    
    # 找到 WRITE_FEATURES_CSV 所在行
    write_csv_idx = None
    for i, line in enumerate(source_lines):
        if 'WRITE_FEATURES_CSV = True' in line:
            write_csv_idx = i
            break
    
    if write_csv_idx is None:
        print("  警告：未找到 WRITE_FEATURES_CSV")
        return
    
    # 在 WRITE_FEATURES_CSV 后面添加 WRITE_SAMPLE_200
    new_line = 'WRITE_SAMPLE_200 = True  # 设置为 True 输出前200条样本，False 则跳过\n'
    source_lines.insert(write_csv_idx + 1, new_line)
    
    # 找到 features_df.to_csv 后面，添加 sample200 输出逻辑
    to_csv_idx = None
    for i, line in enumerate(source_lines):
        if 'features_df.to_csv(csv_path' in line:
            to_csv_idx = i + 1
            break
    
    if to_csv_idx is not None:
        # 添加 sample200 输出代码
        sample200_code = [
            '    \n',
            '    # 输出前200条记录的小文件（用于快速查看和测试）\n',
            '    if WRITE_SAMPLE_200:\n',
            '        csv_sample200_filename = "cdcboss_features_sample200.csv"\n',
            '        csv_sample200_path = Path("outputs") / csv_sample200_filename\n',
            '        features_sample200 = features_df.head(200)  # 取前200条记录\n',
            '        features_sample200.to_csv(csv_sample200_path, index=False, encoding="utf-8-sig")\n',
            '        print(f"[WRITE] BOSS 特征前200条样本已输出到: {csv_sample200_path.resolve()}")\n',
            '        print(f"[INFO] 样本数据形状: {features_sample200.shape}")\n',
            '    \n',
        ]
        for idx, code_line in enumerate(sample200_code):
            source_lines.insert(to_csv_idx + idx, code_line)
    
    # 保存修改后的notebook
    with open(notebook_path, 'w', encoding='utf-8') as f:
        json.dump(nb, f, ensure_ascii=False, indent=1)
    
    print("  ✓ BOSS板块修改完成")


def main():
    """主函数"""
    print("=" * 60)
    print("CDC项目：为BOSS板块添加前200条记录输出功能")
    print("=" * 60)
    
    add_sample200_to_boss_notebook()
    
    print("\n" + "=" * 60)
    print("处理完成！")
    print("=" * 60)
    print("\n使用说明：")
    print("1. 打开 BOSS板块衍生.ipynb")
    print("2. 运行所有代码格")
    print("3. 在 outputs/ 目录下会生成两个文件：")
    print("   - cdcboss_features_full_data.csv: 特征表（全量）")
    print("   - cdcboss_features_sample200.csv: 前200条记录（用于快速查看）")
    print("\n如果不想输出前200条记录，将 WRITE_SAMPLE_200 改为 False")


if __name__ == '__main__':
    main()
