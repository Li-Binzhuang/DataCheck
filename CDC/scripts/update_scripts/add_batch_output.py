#!/usr/bin/env python3
"""
CDC板块衍生脚本 - 添加分批输出功能

将四个板块的输出从"全量文件+sample200"改为"分批输出多个文件"，每个文件500条数据。

使用方法:
    python add_batch_output.py

修改标识: zlf update
"""

import json
import sys
from pathlib import Path


def update_notebook_batch_output(notebook_path, prefix, output_dir_var="OUTPUT_DIR"):
    """
    更新notebook，添加分批输出功能
    
    Args:
        notebook_path: notebook文件路径
        prefix: 输出文件前缀 (如 "cdc1_features", "cdcboss_features")
        output_dir_var: 输出目录变量名 (如 "OUTPUT_DIR", "output_dir")
    """
    print(f"\n{'='*60}")
    print(f"处理文件: {notebook_path}")
    print(f"输出前缀: {prefix}")
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
        
        # 检查是否包含 WRITE_SAMPLE_200 配置
        source_text = ''.join(source)
        
        if 'WRITE_SAMPLE_200 = True' in source_text:
            print(f"[FOUND] Cell {cell_idx}: 找到 WRITE_SAMPLE_200 配置")
            
            # 修改配置部分
            new_source = []
            skip_next = False
            
            for i, line in enumerate(source):
                # 跳过 WRITE_SAMPLE_200 行
                if 'WRITE_SAMPLE_200 = True' in line:
                    # 添加新的 BATCH_SIZE 配置
                    new_source.append("# zlf update: 改为分批输出，每个文件500条数据\n")
                    new_source.append("BATCH_SIZE = 500  # 每个文件的行数，可以根据需要调整\n")
                    skip_next = True
                    modified = True
                    continue
                
                # 跳过空行（如果前面删除了 WRITE_SAMPLE_200）
                if skip_next and line.strip() == "":
                    skip_next = False
                    new_source.append(line)
                    continue
                
                # 删除 features_out_path 和 features_sample200_path 定义
                if 'features_out_path' in line or 'features_sample200_path' in line or 'feat_out_path' in line:
                    if 'csv_filename' not in line:  # 保留 BOSS 板块的 csv_filename
                        continue
                
                new_source.append(line)
            
            cell['source'] = new_source
            print(f"[UPDATE] Cell {cell_idx}: 已更新配置部分")
        
        # 检查是否包含输出逻辑（全量输出 + sample200）
        if '_features_to_write.to_csv' in source_text or 'features_sample200' in source_text:
            if 'WRITE_SAMPLE_200' in source_text or 'if WRITE_SAMPLE_200:' in source_text:
                print(f"[FOUND] Cell {cell_idx}: 找到输出逻辑")
                
                # 构建新的输出逻辑
                new_source = []
                in_output_section = False
                indent = "    "  # 默认缩进
                
                for i, line in enumerate(source):
                    # 找到 _features_to_write 定义的开始
                    if '_features_to_write = ' in line and 'rename' in line:
                        new_source.append(line)
                        in_output_section = True
                        continue
                    
                    # 找到 round(6) 行
                    if in_output_section and '.round(6)' in line:
                        new_source.append(line)
                        new_source.append("\n")
                        
                        # 添加分批输出逻辑
                        new_source.append(f"{indent}# zlf update: 分批输出功能 - 每个文件500条数据\n")
                        new_source.append(f"{indent}total_rows = len(_features_to_write)\n")
                        new_source.append(f"{indent}num_batches = (total_rows + BATCH_SIZE - 1) // BATCH_SIZE  # 向上取整\n")
                        new_source.append("\n")
                        new_source.append(f'{indent}print("[INFO] 开始分批输出特征文件")\n')
                        new_source.append(f'{indent}print(f"[INFO] 总数据量: {{total_rows}} 行")\n')
                        new_source.append(f'{indent}print(f"[INFO] 批次大小: {{BATCH_SIZE}} 行/文件")\n')
                        new_source.append(f'{indent}print(f"[INFO] 输出文件数: {{num_batches}} 个")\n')
                        new_source.append(f'{indent}print()\n')
                        new_source.append("\n")
                        new_source.append(f"{indent}batch_files = []  # 记录所有输出的文件路径\n")
                        new_source.append("\n")
                        new_source.append(f"{indent}for batch_idx in range(num_batches):\n")
                        new_source.append(f"{indent}    start_idx = batch_idx * BATCH_SIZE\n")
                        new_source.append(f"{indent}    end_idx = min((batch_idx + 1) * BATCH_SIZE, total_rows)\n")
                        new_source.append(f"{indent}    \n")
                        new_source.append(f"{indent}    # 提取当前批次的数据\n")
                        new_source.append(f"{indent}    batch_data = _features_to_write.iloc[start_idx:end_idx]\n")
                        new_source.append(f"{indent}    \n")
                        new_source.append(f'{indent}    # 生成文件名：{prefix}_batch{{批次号}}_{{起始行}}-{{结束行}}.csv\n')
                        new_source.append(f'{indent}    batch_filename = f"{prefix}_batch{{batch_idx + 1:03d}}_{{start_idx + 1}}-{{end_idx}}.csv"\n')
                        new_source.append(f"{indent}    batch_path = {output_dir_var} / batch_filename\n")
                        new_source.append(f"{indent}    \n")
                        new_source.append(f"{indent}    # 输出到CSV\n")
                        new_source.append(f'{indent}    batch_data.to_csv(batch_path, index=False, encoding="utf-8-sig")\n')
                        new_source.append(f"{indent}    batch_files.append(batch_path)\n")
                        new_source.append(f"{indent}    \n")
                        new_source.append(f'{indent}    print(f"[WRITE] 批次 {{batch_idx + 1}}/{{num_batches}}: {{batch_filename}}")\n')
                        new_source.append(f'{indent}    print(f"        行范围: {{start_idx + 1}} - {{end_idx}} ({{len(batch_data)}} 行)")\n')
                        new_source.append("\n")
                        new_source.append(f'{indent}print()\n')
                        new_source.append(f'{indent}print("[SUCCESS] 分批输出完成！")\n')
                        
                        # 跳过原来的全量输出和sample200输出
                        skip_until_print = True
                        continue
                    
                    # 跳过旧的输出逻辑，直到找到 print("written:") 或类似的打印语句
                    if in_output_section:
                        if 'print("written:' in line or 'print(\'written:\'' in line:
                            # 找到打印部分，添加新的打印逻辑
                            new_source.append(f'{indent}print("written:")\n')
                            
                            # 检查是否有 WRITE_FLAT_CSV 判断
                            for j in range(i+1, min(i+5, len(source))):
                                if 'WRITE_FLAT_CSV' in source[j]:
                                    new_source.append(source[j])
                                    if j+1 < len(source):
                                        new_source.append(source[j+1])  # print 语句
                                    break
                            
                            new_source.append(f"{indent}for batch_file in batch_files:\n")
                            new_source.append(f'{indent}    print("-", batch_file)\n')
                            
                            in_output_section = False
                            modified = True
                            
                            # 跳过原来的打印语句
                            continue
                        
                        # 跳过旧的输出相关代码
                        if any(x in line for x in ['_features_to_write.to_csv', 'features_sample200', 
                                                     'features_out_path', 'features_sample200_path',
                                                     'WRITE_SAMPLE_200', 'feat_out_path']):
                            continue
                    
                    new_source.append(line)
                
                cell['source'] = new_source
                print(f"[UPDATE] Cell {cell_idx}: 已更新输出逻辑")
    
    if modified:
        # 保存修改后的notebook
        with open(notebook_path, 'w', encoding='utf-8') as f:
            json.dump(nb, f, ensure_ascii=False, indent=1)
        print(f"\n[SUCCESS] 已保存修改: {notebook_path}\n")
        return True
    else:
        print(f"\n[INFO] 未找到需要修改的内容\n")
        return False


def main():
    """主函数"""
    # 定义四个板块的配置
    notebooks = [
        {
            'path': 'CDC/第一板块衍生.ipynb',
            'prefix': 'cdc1_features',
            'output_dir': 'OUTPUT_DIR'
        },
        {
            'path': 'CDC/第二板块衍生.ipynb',
            'prefix': 'cdc2_features',
            'output_dir': 'OUTPUT_DIR'
        },
        {
            'path': 'CDC/第三板块衍生.ipynb',
            'prefix': 'cdc3_features',
            'output_dir': 'OUTPUT_DIR'
        },
        {
            'path': 'CDC/BOSS板块衍生.ipynb',
            'prefix': 'cdcboss_features',
            'output_dir': 'output_dir'
        }
    ]
    
    print("\n" + "="*60)
    print("CDC板块衍生脚本 - 添加分批输出功能")
    print("="*60)
    
    success_count = 0
    for nb_config in notebooks:
        nb_path = Path(nb_config['path'])
        if not nb_path.exists():
            print(f"\n[ERROR] 文件不存在: {nb_path}")
            continue
        
        if update_notebook_batch_output(nb_path, nb_config['prefix'], nb_config['output_dir']):
            success_count += 1
    
    print("\n" + "="*60)
    print(f"完成！成功修改 {success_count}/{len(notebooks)} 个文件")
    print("="*60 + "\n")


if __name__ == '__main__':
    main()
