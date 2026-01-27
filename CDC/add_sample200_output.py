#!/usr/bin/env python3
"""
为CDC项目的四个Notebook添加前200条记录输出功能

功能：在每个Notebook的第4个代码格（输出部分）添加：
1. WRITE_SAMPLE_200 开关
2. 输出前200条记录到 *_sample200.csv 文件
"""

import json
from pathlib import Path


def add_sample200_to_notebook(notebook_path: Path, block_name: str, output_filename_prefix: str):
    """
    为指定的Notebook添加前200条记录输出功能
    
    Args:
        notebook_path: Notebook文件路径
        block_name: 板块名称（用于日志）
        output_filename_prefix: 输出文件名前缀（如 cdc1_features_consultas）
    """
    print(f"\n处理 {block_name}: {notebook_path}")
    
    # 读取notebook
    with open(notebook_path, 'r', encoding='utf-8') as f:
        nb = json.load(f)
    
    # 找到第4个代码格（索引为3，因为从0开始）
    # 通常第4个代码格是输出部分
    code_cells = [cell for cell in nb['cells'] if cell['cell_type'] == 'code']
    
    if len(code_cells) < 4:
        print(f"  警告：{block_name} 的代码格数量少于4个，跳过")
        return
    
    output_cell = code_cells[3]  # 第4个代码格
    source_lines = output_cell['source']
    
    # 检查是否已经添加过
    if any('WRITE_SAMPLE_200' in line for line in source_lines):
        print(f"  {block_name} 已经添加过 WRITE_SAMPLE_200，跳过")
        return
    
    # 找到 WRITE_FLAT_CSV 所在行的索引
    write_flat_idx = None
    for i, line in enumerate(source_lines):
        if 'WRITE_FLAT_CSV = True' in line:
            write_flat_idx = i
            break
    
    if write_flat_idx is None:
        print(f"  警告：{block_name} 未找到 WRITE_FLAT_CSV，跳过")
        return
    
    # 在 WRITE_FLAT_CSV 后面添加 WRITE_SAMPLE_200
    new_line = 'WRITE_SAMPLE_200 = True  # True：输出前200条记录的小文件；False：跳过样本输出\n'
    source_lines.insert(write_flat_idx + 1, new_line)
    
    # 找到输出路径定义部分，添加 sample200 路径
    features_out_path_idx = None
    for i, line in enumerate(source_lines):
        if 'features_out_path = OUTPUT_DIR' in line or 'feat_out_path = OUTPUT_DIR' in line:
            features_out_path_idx = i
            break
    
    if features_out_path_idx is not None:
        # 添加 sample200 路径定义
        sample200_path_line = f'features_sample200_path = OUTPUT_DIR / "{output_filename_prefix}_sample200.csv"  # 定义"前200条样本"的输出路径\n'
        source_lines.insert(features_out_path_idx + 1, sample200_path_line)
    
    # 找到 features_to_write.to_csv 后面，添加 sample200 输出逻辑
    to_csv_idx = None
    for i, line in enumerate(source_lines):
        if '_features_to_write.to_csv(' in line or '_features_to_write.to_csv' in line:
            # 找到这个to_csv调用的结束位置（找到下一个不是缩进continuation的行）
            j = i + 1
            while j < len(source_lines) and (source_lines[j].strip() == '' or 
                                              source_lines[j].startswith('        ') or
                                              source_lines[j].strip().startswith(')')):
                j += 1
            to_csv_idx = j
            break
    
    if to_csv_idx is not None:
        # 添加 sample200 输出代码
        sample200_code = [
            '    \n',
            '    # 输出前200条记录的小文件（用于快速查看和测试）\n',
            '    if WRITE_SAMPLE_200:\n',
            '        _features_sample200 = _features_to_write.head(200)  # 取前200条记录\n',
            '        _features_sample200.to_csv(\n',
            '            features_sample200_path,\n',
            '            index=False,\n',
            '            encoding="utf-8-sig",\n',
            '        )\n',
            '\n',
        ]
        for idx, code_line in enumerate(sample200_code):
            source_lines.insert(to_csv_idx + idx, code_line)
    
    # 找到 print("-", features_out_path) 后面，添加 sample200 输出提示
    print_features_idx = None
    for i, line in enumerate(source_lines):
        if 'print("-", features_out_path)' in line or 'print("-", feat_out_path)' in line:
            print_features_idx = i
            break
    
    if print_features_idx is not None:
        # 添加 sample200 输出提示
        sample200_print = [
            '    if WRITE_SAMPLE_200:\n',
            '        print("-", features_sample200_path)  # 输出前200条样本路径\n',
        ]
        for idx, print_line in enumerate(sample200_print):
            source_lines.insert(print_features_idx + 1 + idx, print_line)
    
    # 更新注释：从"2个outputs"改为"3个outputs"
    for i, line in enumerate(source_lines):
        if '你最终只需要 2 个 outputs' in line:
            source_lines[i] = line.replace('2 个', '3 个')
        if '# 2) 衍生后的特征表' in line:
            # 在下一行添加第3个输出说明
            source_lines.insert(i + 1, f'# 3) 前200条记录的小文件（{output_filename_prefix}_sample200.csv）- 用于快速查看和测试\n')
            break
    
    # 保存修改后的notebook
    with open(notebook_path, 'w', encoding='utf-8') as f:
        json.dump(nb, f, ensure_ascii=False, indent=1)
    
    print(f"  ✓ {block_name} 修改完成")


def main():
    """主函数：处理所有四个Notebook"""
    base_dir = Path(__file__).parent
    
    notebooks = [
        {
            'path': base_dir / '第一板块衍生.ipynb',
            'name': '第一板块（consultas）',
            'prefix': 'cdc1_features_consultas'
        },
        {
            'path': base_dir / '第二板块衍生.ipynb',
            'name': '第二板块（creditos）',
            'prefix': 'cdc2_features_creditos'
        },
        {
            'path': base_dir / '第三板块衍生.ipynb',
            'name': '第三板块（clavePrevencion）',
            'prefix': 'cdc3_features_clave_prevencion'
        },
        {
            'path': base_dir / 'BOSS板块衍生.ipynb',
            'name': 'BOSS板块',
            'prefix': 'cdc_boss_features'
        },
    ]
    
    print("=" * 60)
    print("CDC项目：添加前200条记录输出功能")
    print("=" * 60)
    
    for nb_info in notebooks:
        if nb_info['path'].exists():
            add_sample200_to_notebook(
                nb_info['path'],
                nb_info['name'],
                nb_info['prefix']
            )
        else:
            print(f"\n警告：{nb_info['name']} 文件不存在: {nb_info['path']}")
    
    print("\n" + "=" * 60)
    print("处理完成！")
    print("=" * 60)
    print("\n使用说明：")
    print("1. 打开任意一个Notebook")
    print("2. 运行所有代码格")
    print("3. 在 outputs/ 目录下会生成三个文件：")
    print("   - *_flat.csv: 平铺明细表（全量）")
    print("   - *_features_*.csv: 特征表（全量）")
    print("   - *_features_*_sample200.csv: 前200条记录（用于快速查看）")
    print("\n如果不想输出前200条记录，将 WRITE_SAMPLE_200 改为 False")


if __name__ == '__main__':
    main()
