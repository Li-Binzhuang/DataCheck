#!/usr/bin/env python3
"""
CDC板块衍生脚本 - 添加分批输出功能

将全量数据分批输出到多个CSV文件，每个文件500条数据
替代原来的全量输出和sample200输出
"""

import json

def add_batch_output_code():
    """生成分批输出的代码片段"""
    
    code = '''
# zlf update: 分批输出功能 - 每个文件500条数据
if WRITE_FEATURES_CSV:
    from datetime import datetime
    from pathlib import Path
    
    # 生成输出文件名前缀
    output_prefix = "{板块名称}_features"  # 例如：cdc1_features, cdc2_features, cdcboss_features
    
    # 确保 outputs 目录存在
    output_dir = Path("outputs")
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # zlf update: 对数值特征列保留6位小数
    _features_to_write = features_df.copy()
    _round_cols = [c for c in _features_to_write.columns if c not in {"apply_id", "request_time"}]
    _features_to_write[_round_cols] = _features_to_write[_round_cols].apply(pd.to_numeric, errors="coerce").round(6)
    
    # 分批输出：每个文件500条数据
    batch_size = 500
    total_rows = len(_features_to_write)
    num_batches = (total_rows + batch_size - 1) // batch_size  # 向上取整
    
    print(f"[INFO] 开始分批输出特征文件")
    print(f"[INFO] 总数据量: {total_rows} 行")
    print(f"[INFO] 批次大小: {batch_size} 行/文件")
    print(f"[INFO] 输出文件数: {num_batches} 个")
    print()
    
    for batch_idx in range(num_batches):
        start_idx = batch_idx * batch_size
        end_idx = min((batch_idx + 1) * batch_size, total_rows)
        
        # 提取当前批次的数据
        batch_data = _features_to_write.iloc[start_idx:end_idx]
        
        # 生成文件名：{前缀}_batch{批次号}_{起始行}-{结束行}.csv
        batch_filename = f"{output_prefix}_batch{batch_idx + 1:03d}_{start_idx + 1}-{end_idx}.csv"
        batch_path = output_dir / batch_filename
        
        # 输出到CSV
        batch_data.to_csv(batch_path, index=False, encoding="utf-8-sig")
        
        print(f"[WRITE] 批次 {batch_idx + 1}/{num_batches}: {batch_filename}")
        print(f"        行范围: {start_idx + 1} - {end_idx} ({len(batch_data)} 行)")
    
    print()
    print(f"[SUCCESS] 分批输出完成！")
    print(f"[INFO] 输出目录: {output_dir.resolve()}")
    print(f"[INFO] 文件命名格式: {output_prefix}_batch{'{批次号:03d}'}_{'{起始行}'}-{'{结束行}'}.csv")
else:
    print("[INFO] WRITE_FEATURES_CSV = False，跳过特征文件输出")
'''
    
    return code

if __name__ == "__main__":
    print("=" * 80)
    print("CDC板块衍生脚本 - 分批输出功能说明")
    print("=" * 80)
    print()
    
    print("功能说明：")
    print("  - 将全量数据分批输出到多个CSV文件")
    print("  - 每个文件包含500条数据")
    print("  - 替代原来的全量输出和sample200输出")
    print()
    
    print("输出文件命名格式：")
    print("  {板块前缀}_batch{批次号:03d}_{起始行}-{结束行}.csv")
    print()
    
    print("示例：")
    print("  第一板块：cdc1_features_batch001_1-500.csv")
    print("           cdc1_features_batch002_501-1000.csv")
    print("           cdc1_features_batch003_1001-1500.csv")
    print()
    
    print("  BOSS板块：cdcboss_features_batch001_1-500.csv")
    print("            cdcboss_features_batch002_501-1000.csv")
    print()
    
    print("优点：")
    print("  ✅ 文件大小可控，每个文件约500行")
    print("  ✅ 方便分批查看和核对数据")
    print("  ✅ 避免单个文件过大")
    print("  ✅ 文件名包含行范围，便于定位")
    print()
    
    print("配置：")
    print("  batch_size = 500  # 每个文件的行数，可以调整")
