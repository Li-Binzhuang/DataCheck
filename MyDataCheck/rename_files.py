#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
批量重命名 Python 文件：将中文文件名改为英文
"""

import os
import sys

# 重命名映射表
RENAME_MAP = {
    # api_comparison/job/
    "api_comparison/job/对比接口数据.py": "api_comparison/job/compare_api_data.py",
    "api_comparison/job/检测列索引.py": "api_comparison/job/detect_column_index.py",
    "api_comparison/job/流程执行器.py": "api_comparison/job/process_executor.py",
    "api_comparison/job/获取接口数据.py": "api_comparison/job/fetch_api_data.py",
    "api_comparison/job/转换特征值为数值.py": "api_comparison/job/convert_feature_to_number.py",
    "api_comparison/job/配置管理.py": "api_comparison/job/config_manager.py",
    
    # common/
    "common/csv工具.py": "common/csv_tool.py",
    "common/值比较器.py": "common/value_comparator.py",
    "common/报告生成器.py": "common/report_generator.py",
    "common/数据格式化.py": "common/data_formatter.py",
    
    # online_comparison/job/
    "online_comparison/job/JSON解析器.py": "online_comparison/job/json_parser.py",
    "online_comparison/job/报告生成器.py": "online_comparison/job/report_generator.py",
    "online_comparison/job/数据对比器.py": "online_comparison/job/data_comparator.py",
    
    # 根目录文件
    "api_comparison/执行对比流程data.py": "api_comparison/execute_comparison_flow.py",
    "online_comparison/执行对比流程_online.py": "online_comparison/execute_online_comparison_flow.py",
}


def main():
    """主函数"""
    # 获取脚本所在目录
    script_dir = os.path.dirname(os.path.abspath(__file__))
    os.chdir(script_dir)
    
    print("=" * 60)
    print("批量重命名 Python 文件：中文 -> 英文")
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


if __name__ == "__main__":
    main()
