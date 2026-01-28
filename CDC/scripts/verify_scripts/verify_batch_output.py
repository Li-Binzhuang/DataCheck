#!/usr/bin/env python3
"""
CDC板块衍生脚本 - 分批输出验证脚本

验证分批输出功能是否正常工作

使用方法:
    python verify_batch_output.py

或指定板块:
    python verify_batch_output.py --block 1
    python verify_batch_output.py --block boss
    python verify_batch_output.py --all
"""

import pandas as pd
from pathlib import Path
import sys
import argparse


def verify_batch_files(prefix, output_dir="outputs", expected_batch_size=500):
    """
    验证分批输出文件
    
    Args:
        prefix: 文件前缀 (如 "cdc1_features", "cdcboss_features")
        output_dir: 输出目录
        expected_batch_size: 预期的批次大小
    
    Returns:
        dict: 验证结果
    """
    print(f"\n{'='*60}")
    print(f"验证板块: {prefix}")
    print(f"{'='*60}\n")
    
    output_path = Path(output_dir)
    
    # 查找所有批次文件
    batch_files = sorted(output_path.glob(f"{prefix}_batch*.csv"))
    
    if not batch_files:
        print(f"❌ 未找到批次文件: {prefix}_batch*.csv")
        return {
            "success": False,
            "error": "未找到批次文件"
        }
    
    print(f"✅ 找到 {len(batch_files)} 个批次文件\n")
    
    # 验证每个批次文件
    total_rows = 0
    batch_info = []
    all_apply_ids = []
    
    for idx, batch_file in enumerate(batch_files, 1):
        try:
            df = pd.read_csv(batch_file)
            rows = len(df)
            total_rows += rows
            
            # 检查是否有 apply_id 列
            if 'apply_id' in df.columns:
                apply_ids = df['apply_id'].tolist()
                all_apply_ids.extend(apply_ids)
            
            # 验证行数
            is_last = (idx == len(batch_files))
            expected_rows = expected_batch_size if not is_last else "≤500"
            status = "✅" if (rows <= expected_batch_size) else "⚠️"
            
            batch_info.append({
                "file": batch_file.name,
                "rows": rows,
                "status": status
            })
            
            print(f"{status} 批次 {idx:03d}: {batch_file.name}")
            print(f"   行数: {rows} (预期: {expected_rows})")
            
        except Exception as e:
            print(f"❌ 读取文件失败: {batch_file.name}")
            print(f"   错误: {e}")
            return {
                "success": False,
                "error": f"读取文件失败: {e}"
            }
    
    print(f"\n{'='*60}")
    print(f"总计统计")
    print(f"{'='*60}")
    print(f"批次文件数: {len(batch_files)}")
    print(f"总行数: {total_rows}")
    
    # 检查 apply_id 唯一性
    if all_apply_ids:
        unique_apply_ids = len(set(all_apply_ids))
        print(f"唯一 apply_id 数: {unique_apply_ids}")
        
        if unique_apply_ids != len(all_apply_ids):
            print(f"⚠️  警告: 存在重复的 apply_id！")
            duplicates = len(all_apply_ids) - unique_apply_ids
            print(f"   重复数量: {duplicates}")
        else:
            print(f"✅ 所有 apply_id 唯一")
    
    # 验证文件命名
    print(f"\n{'='*60}")
    print(f"文件命名验证")
    print(f"{'='*60}")
    
    naming_correct = True
    for idx, batch_file in enumerate(batch_files, 1):
        # 预期文件名格式: {prefix}_batch{idx:03d}_{start}-{end}.csv
        expected_pattern = f"{prefix}_batch{idx:03d}_"
        if not batch_file.name.startswith(expected_pattern):
            print(f"⚠️  文件命名不符合预期: {batch_file.name}")
            naming_correct = False
    
    if naming_correct:
        print(f"✅ 所有文件命名正确")
    
    print(f"\n{'='*60}")
    print(f"验证完成")
    print(f"{'='*60}\n")
    
    return {
        "success": True,
        "batch_count": len(batch_files),
        "total_rows": total_rows,
        "unique_apply_ids": unique_apply_ids if all_apply_ids else None,
        "naming_correct": naming_correct
    }



def verify_all_blocks(output_dir="outputs"):
    """验证所有四个板块"""
    blocks = [
        ("cdc1_features", "第一板块"),
        ("cdc2_features", "第二板块"),
        ("cdc3_features", "第三板块"),
        ("cdcboss_features", "BOSS板块")
    ]
    
    print("\n" + "="*60)
    print("CDC板块衍生脚本 - 分批输出验证")
    print("="*60)
    
    results = {}
    
    for prefix, name in blocks:
        result = verify_batch_files(prefix, output_dir)
        results[name] = result
    
    # 总结报告
    print("\n" + "="*60)
    print("总结报告")
    print("="*60 + "\n")
    
    for name, result in results.items():
        if result["success"]:
            print(f"✅ {name}: 验证通过")
            print(f"   批次数: {result['batch_count']}")
            print(f"   总行数: {result['total_rows']}")
        else:
            print(f"❌ {name}: 验证失败")
            print(f"   错误: {result.get('error', '未知错误')}")
    
    print()


def main():
    """主函数"""
    parser = argparse.ArgumentParser(description='验证CDC分批输出功能')
    parser.add_argument('--block', type=str, help='指定板块 (1/2/3/boss)')
    parser.add_argument('--all', action='store_true', help='验证所有板块')
    parser.add_argument('--dir', type=str, default='outputs', help='输出目录 (默认: outputs)')
    
    args = parser.parse_args()
    
    # 切换到 CDC 目录
    script_dir = Path(__file__).parent
    cdc_dir = script_dir.parent.parent
    
    output_dir = cdc_dir / args.dir
    
    if not output_dir.exists():
        print(f"❌ 输出目录不存在: {output_dir}")
        print(f"   请先运行板块衍生脚本生成输出文件")
        sys.exit(1)
    
    if args.all or not args.block:
        # 验证所有板块
        verify_all_blocks(output_dir)
    else:
        # 验证指定板块
        block_map = {
            '1': ('cdc1_features', '第一板块'),
            '2': ('cdc2_features', '第二板块'),
            '3': ('cdc3_features', '第三板块'),
            'boss': ('cdcboss_features', 'BOSS板块')
        }
        
        if args.block.lower() not in block_map:
            print(f"❌ 无效的板块: {args.block}")
            print(f"   有效选项: 1, 2, 3, boss")
            sys.exit(1)
        
        prefix, name = block_map[args.block.lower()]
        print(f"\n验证 {name}...")
        verify_batch_files(prefix, output_dir)


if __name__ == '__main__':
    main()
