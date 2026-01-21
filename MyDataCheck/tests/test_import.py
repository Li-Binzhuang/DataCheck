#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
测试所有模块导入是否正常
"""

import sys
import os

# 添加当前目录到路径
sys.path.insert(0, os.path.dirname(__file__))

print("="*60)
print("测试模块导入")
print("="*60)

# 测试导入
test_modules = [
    ("flask", "Flask"),
    ("requests", None),
    ("api_comparison.job.fetch_api_data", "ApiDataFetcher"),
    ("api_comparison.job.process_executor", "execute_single_scenario"),
    ("api_comparison.job.compare_api_data", "DataComparator"),
    ("common.csv_tool", "read_csv_with_encoding"),
    ("common.value_comparator", "compare_values"),
]

success_count = 0
fail_count = 0

for module_name, item_name in test_modules:
    try:
        if "." in module_name and module_name.startswith(("api_comparison", "common", "online_comparison")):
            # 导入项目内部模块
            parts = module_name.rsplit(".", 1)
            module = __import__(parts[0], fromlist=[parts[1]])
            submodule = getattr(module, parts[1])
            if item_name:
                getattr(submodule, item_name)
        else:
            # 导入外部库
            module = __import__(module_name)
            if item_name:
                getattr(module, item_name)
        
        display_name = f"{module_name}.{item_name}" if item_name else module_name
        print(f"✅ {display_name}")
        success_count += 1
    except Exception as e:
        display_name = f"{module_name}.{item_name}" if item_name else module_name
        print(f"❌ {display_name}: {str(e)}")
        fail_count += 1

print("="*60)
print(f"测试结果: 成功 {success_count}, 失败 {fail_count}")
print("="*60)

if fail_count == 0:
    print("\n✅ 所有模块导入成功!")
    print("\n可以启动 Web 服务:")
    print("  python web_app.py")
else:
    print(f"\n❌ 有 {fail_count} 个模块导入失败")
    print("\n请检查依赖是否已安装:")
    print("  pip install -r requirements.txt")
