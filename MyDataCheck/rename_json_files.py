#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
批量重命名 JSON 文件：将中文文件名改为英文
"""

import os
import sys

# 重命名映射表
RENAME_MAP = {
    # api_comparison/json/
    "api_comparison/json/列索引配置.json": "api_comparison/json/column_index_config.json",
    "api_comparison/json/配置模板.json": "api_comparison/json/config_template.json",
    
    # api_comparison/
    "api_comparison/执行配置.json": "api_comparison/config.json",
    
    # online_comparison/
    "online_comparison/执行配置.json": "online_comparison/config.json",
    
    # 根目录
    "执行配置.json": "config.json",
}


def main():
    """主函数"""
    # 获取脚本所在目录
    script_dir = os.path.dirname(os.path.abspath(__file__))
    os.chdir(script_dir)
    
    print("=" * 60)
    print("批量重命名 JSON 文件：中文 -> 英文")
    print("=" * 60)
    print()
    
    success_count = 0
    skip_count = 0
    error_count = 0
    
    for old_rel_path, new_rel_path in RENAME_MAP.items():
        old_path = os.path.join(script_dir, old_rel_path)
        new_path = os.path.join(script_dir, new_rel_path)
        
        # 检查旧文件是否存在
        if not os.path.exists(old_path):
            print(f"⚠️  跳过（文件不存在）: {old_rel_path}")
            skip_count += 1
            continue
        
        # 检查新文件是否已存在
        if os.path.exists(new_path):
            print(f"⚠️  跳过（目标文件已存在）: {new_rel_path}")
            skip_count += 1
            continue
        
        try:
            # 重命名文件
            os.rename(old_path, new_path)
            print(f"✓ 重命名成功: {old_rel_path}")
            print(f"  -> {new_rel_path}")
            success_count += 1
        except Exception as e:
            print(f"✗ 重命名失败: {old_rel_path}")
            print(f"  错误: {e}")
            error_count += 1
    
    print()
    print("=" * 60)
    print("重命名完成！")
    print(f"  成功: {success_count} 个")
    print(f"  跳过: {skip_count} 个")
    print(f"  失败: {error_count} 个")
    print("=" * 60)
    print()
    print("⚠️  注意：请运行 update_json_references.py 更新代码中的引用")


if __name__ == "__main__":
    main()
