#!/usr/bin/env python3
"""
合并分批输出的CSV文件为全量文件

用途：将每个板块的分批文件（batch001, batch002, ...）合并成一个全量文件
"""

import pandas as pd
from pathlib import Path
import sys

def merge_batch_files(output_dir: Path, prefix: str, output_filename: str):
    """
    合并指定前缀的所有分批文件
    
    Args:
        output_dir: 输出目录
        prefix: 文件前缀，如 "cdc1_features_batch"
        output_filename: 输出的全量文件名
    """
    # 查找所有分批文件
    batch_files = sorted(output_dir.glob(f"{prefix}*.csv"))
    
    if not batch_files:
        print(f"[WARN] 未找到匹配的文件: {prefix}*.csv")
        return False
    
    print(f"[INFO] 找到 {len(batch_files)} 个分批文件")
    print(f"[INFO] 开始合并...")
    
    # 读取并合并所有分批文件
    dfs = []
    total_rows = 0
    
    for i, batch_file in enumerate(batch_files, 1):
        df = pd.read_csv(batch_file)
        dfs.append(df)
        total_rows += len(df)
        print(f"[READ] {i}/{len(batch_files)}: {batch_file.name} ({len(df)} 行)")
    
    # 合并
    merged_df = pd.concat(dfs, ignore_index=True)
    
    # 输出
    output_path = output_dir / output_filename
    merged_df.to_csv(output_path, index=False, encoding="utf-8-sig")
    
    print(f"[SUCCESS] 合并完成！")
    print(f"[WRITE] 全量文件: {output_filename}")
    print(f"        总行数: {total_rows} 行")
    print(f"        路径: {output_path}")
    
    return True


def main():
    """主函数"""
    # 输出目录
    output_dir = Path("outputs")
    
    if not output_dir.exists():
        print(f"[ERROR] 输出目录不存在: {output_dir}")
        sys.exit(1)
    
    print("=" * 60)
    print("CDC板块特征文件合并工具")
    print("=" * 60)
    print()
    
    # 定义要合并的板块
    blocks = [
        {
            "name": "第一板块（consultas）",
            "prefix": "cdc1_features_batch",
            "output": "cdc1_features_full_data.csv"
        },
        {
            "name": "第二板块（creditos）",
            "prefix": "cdc2_features_batch",
            "output": "cdc2_features_full_data.csv"
        },
        {
            "name": "第三板块（clave_prevencion）",
            "prefix": "cdc3_features_batch",
            "output": "cdc3_features_full_data.csv"
        },
        {
            "name": "BOSS板块",
            "prefix": "cdcboss_features_batch",
            "output": "cdcboss_features_full_data.csv"
        }
    ]
    
    # 合并每个板块
    success_count = 0
    
    for block in blocks:
        print(f"\n{'=' * 60}")
        print(f"处理: {block['name']}")
        print(f"{'=' * 60}")
        
        success = merge_batch_files(
            output_dir=output_dir,
            prefix=block["prefix"],
            output_filename=block["output"]
        )
        
        if success:
            success_count += 1
    
    # 总结
    print()
    print("=" * 60)
    print("合并完成总结")
    print("=" * 60)
    print(f"成功合并: {success_count}/{len(blocks)} 个板块")
    
    if success_count == len(blocks):
        print()
        print("✅ 所有板块合并成功！")
        print()
        print("生成的全量文件:")
        for block in blocks:
            output_path = output_dir / block["output"]
            if output_path.exists():
                print(f"  - {output_path}")
    else:
        print()
        print("⚠️ 部分板块合并失败，请检查日志")


if __name__ == "__main__":
    main()
