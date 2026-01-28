#!/usr/bin/env python3
"""
修复CDC项目中的小数精度问题

问题：在特征字典中设置了6位小数，但在输出CSV时又被round(2)覆盖
解决：将所有输出相关的round(2)改为round(6)
"""

import json
from pathlib import Path


def fix_decimal_precision_in_notebook(notebook_path: Path, block_name: str):
    """
    修复Notebook中的小数精度问题
    
    Args:
        notebook_path: Notebook文件路径
        block_name: 板块名称（用于日志）
    """
    print(f"\n处理 {block_name}: {notebook_path}")
    
    # 读取notebook
    with open(notebook_path, 'r', encoding='utf-8') as f:
        nb = json.load(f)
    
    modified = False
    
    # 遍历所有代码格
    for cell in nb['cells']:
        if cell['cell_type'] == 'code':
            source_lines = cell['source']
            
            # 检查并修改每一行
            for i, line in enumerate(source_lines):
                # 查找 .round(2) 并替换为 .round(6)
                if '.round(2)' in line and ('_features_to_write' in line or 'features[_round_cols]' in line):
                    old_line = line
                    new_line = line.replace('.round(2)', '.round(6)')
                    source_lines[i] = new_line
                    modified = True
                    print(f"  修改: round(2) -> round(6)")
                
                # 查找注释中的"保留2位小数"并替换为"保留6位小数"
                if '保留2位小数' in line or '保留小数点后2位' in line:
                    old_line = line
                    new_line = line.replace('保留2位小数', '保留6位小数').replace('保留小数点后2位', '保留小数点后6位')
                    source_lines[i] = new_line
                    modified = True
                    print(f"  修改注释: 2位 -> 6位")
    
    if modified:
        # 保存修改后的notebook
        with open(notebook_path, 'w', encoding='utf-8') as f:
            json.dump(nb, f, ensure_ascii=False, indent=1)
        print(f"  ✓ {block_name} 修改完成")
    else:
        print(f"  {block_name} 无需修改")


def main():
    """主函数：处理所有Notebook"""
    base_dir = Path(__file__).parent
    
    notebooks = [
        {
            'path': base_dir / '第一板块衍生.ipynb',
            'name': '第一板块（consultas）'
        },
        {
            'path': base_dir / '第二板块衍生.ipynb',
            'name': '第二板块（creditos）'
        },
        {
            'path': base_dir / '第三板块衍生.ipynb',
            'name': '第三板块（clavePrevencion）'
        },
        {
            'path': base_dir / 'BOSS板块衍生.ipynb',
            'name': 'BOSS板块'
        },
    ]
    
    print("=" * 60)
    print("CDC项目：修复小数精度问题")
    print("=" * 60)
    print("\n问题说明：")
    print("- 特征字典中设置了6位小数")
    print("- 但输出CSV时被round(2)覆盖")
    print("\n解决方案：")
    print("- 将所有输出相关的round(2)改为round(6)")
    print("- 保持与特征字典的精度一致")
    
    for nb_info in notebooks:
        if nb_info['path'].exists():
            fix_decimal_precision_in_notebook(
                nb_info['path'],
                nb_info['name']
            )
        else:
            print(f"\n警告：{nb_info['name']} 文件不存在: {nb_info['path']}")
    
    print("\n" + "=" * 60)
    print("修复完成！")
    print("=" * 60)
    print("\n验证方法：")
    print("1. 打开任意Notebook")
    print("2. 运行所有代码格")
    print("3. 查看输出的CSV文件")
    print("4. 确认浮点数列保留6位小数")
    print("\n示例：")
    print("  修复前: 0.17")
    print("  修复后: 0.170000")


if __name__ == '__main__':
    main()
