#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
场景1：接口数据对比 - 主执行脚本
功能：统一配置所有参数，执行完整的接口数据获取和对比流程

使用说明：
1. 配置 CONFIG_JSON_FILE 变量，指向JSON配置文件路径（例如: "config.json"）
2. 确保JSON配置文件存在且格式正确（参考 json/config_template.json）
3. 运行此脚本即可完成整个流程

注意：必须使用JSON配置文件，不支持代码中的变量配置
"""

import os
import sys
import importlib.util
from datetime import datetime

# 添加父目录到路径，以便导入公共工具模块
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

# 动态导入job模块中的功能模块
script_dir = os.path.dirname(os.path.abspath(__file__))
job_dir = os.path.join(script_dir, "job")

# 动态导入配置管理模块
config_module_path = os.path.join(job_dir, "config_manager.py")
spec_config = importlib.util.spec_from_file_location("config_manager", config_module_path)
config_module = importlib.util.module_from_spec(spec_config)
spec_config.loader.exec_module(config_module)
load_config_from_json = config_module.load_config_from_json
build_single_scenario_config = config_module.build_single_scenario_config
build_global_config = config_module.build_global_config
cleanup_column_config = config_module.cleanup_column_config

# 动态导入流程执行器模块
executor_module_path = os.path.join(job_dir, "process_executor.py")
spec_executor = importlib.util.spec_from_file_location("process_executor", executor_module_path)
executor_module = importlib.util.module_from_spec(spec_executor)
spec_executor.loader.exec_module(executor_module)
execute_single_scenario = executor_module.execute_single_scenario

# ========== 配置参数 ==========
# 必须配置JSON配置文件路径，不支持代码中的变量配置
# 请确保 config.json 文件存在并正确配置

# 配置文件路径（必须设置，不能为None）
CONFIG_JSON_FILE = "config.json"  # JSON配置文件路径

# ========== 配置参数结束 ==========


def main():
    """主函数"""
    print("场景1：接口数据对比 - 完整流程")
    print("="*60)
    
    # 获取脚本所在目录
    script_dir = os.path.dirname(os.path.abspath(__file__))
    
    # 生成时间戳后缀（格式：MMDDHHmm，例如：01081550 表示1月8日15:50）
    now = datetime.now()
    timestamp_suffix = now.strftime("%m%d%H%M")  # 月日时分，例如：01081550
    
    # 检查配置文件路径是否设置
    if not CONFIG_JSON_FILE:
        print(f"\n{'='*80}")
        print(f"❌ 错误: 未配置JSON配置文件路径")
        print(f"{'='*80}")
        print(f"\n请设置 CONFIG_JSON_FILE 变量，指向JSON配置文件路径")
        print(f"例如: CONFIG_JSON_FILE = \"config.json\"")
        print(f"\n配置文件应包含以下结构:")
        print(f"  - scenarios: 场景配置列表")
        print(f"  - global_config: 全局配置（可选）")
        print(f"\n参考配置模板: json/config_template.json")
        print(f"{'='*80}\n")
        return
    
    # 从JSON文件加载配置
    config_file_path = os.path.join(script_dir, CONFIG_JSON_FILE)
    json_config = load_config_from_json(config_file_path)
    
    if not json_config:
        print(f"\n{'='*80}")
        print(f"❌ 错误: 无法加载配置文件")
        print(f"{'='*80}")
        print(f"\n配置文件路径: {config_file_path}")
        print(f"\n可能的原因:")
        print(f"  1. 配置文件不存在")
        print(f"  2. 配置文件格式错误（不是有效的JSON）")
        print(f"  3. 文件权限问题")
        print(f"\n请检查配置文件是否存在且格式正确")
        print(f"参考配置模板: json/config_template.json")
        print(f"{'='*80}\n")
        return
    
    # 使用JSON配置，支持多场景
    scenarios = json_config.get('scenarios', [])
    global_config = json_config.get('global_config', {})
    
    if not scenarios:
        print(f"❌ 错误: 配置文件中没有找到场景配置")
        return
    
    # 过滤出启用的场景
    enabled_scenarios = [s for s in scenarios if s.get('enabled', True)]
    
    if not enabled_scenarios:
        print(f"⚠️  警告: 没有启用的场景")
        return
    
    print(f"找到 {len(enabled_scenarios)} 个启用的场景\n")
    
    # 清理列索引配置文件中不再存在的场景
    all_scenario_names = [s.get('name') for s in scenarios if s.get('name')]
    column_config_path = os.path.join(script_dir, "json", "column_index_config.json")
    cleanup_column_config(column_config_path, all_scenario_names)
    
    # 执行每个场景
    success_count = 0
    fail_count = 0
    
    for i, scenario in enumerate(enabled_scenarios, 1):
        print(f"[{i}/{len(enabled_scenarios)}] ", end="")
        
        if execute_single_scenario(scenario, global_config, script_dir, timestamp_suffix):
            success_count += 1
        else:
            fail_count += 1
    
    # 总结
    print(f"\n{'='*60}")
    print(f"执行完成: 成功 {success_count} 个, 失败 {fail_count} 个")
    print(f"{'='*60}")


if __name__ == "__main__":
    main()
