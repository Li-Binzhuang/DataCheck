#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
配置管理模块
功能：保存和加载数据对比配置
"""

import os
import json
from datetime import datetime


def save_config(config_path: str, scenarios: list, global_config: dict = None):
    """
    保存配置到文件
    
    Args:
        config_path: 配置文件路径
        scenarios: 场景列表
        global_config: 全局配置（可选）
    """
    config = {
        "scenarios": scenarios,
        "global_config": global_config or {
            "default_convert_feature_to_number": True,
            "default_sql_key_column": 0,
            "default_api_key_column": 0,
            "default_sql_feature_start": 1,
            "default_api_feature_start": 1
        },
        "last_updated": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    }
    
    # 确保目录存在
    os.makedirs(os.path.dirname(config_path), exist_ok=True)
    
    # 保存配置
    with open(config_path, 'w', encoding='utf-8') as f:
        json.dump(config, f, ensure_ascii=False, indent=2)
    
    print(f"配置已保存: {config_path}")


def load_config(config_path: str):
    """
    从文件加载配置
    
    Args:
        config_path: 配置文件路径
    
    Returns:
        配置字典
    """
    if not os.path.exists(config_path):
        # 返回默认配置
        return {
            "scenarios": [],
            "global_config": {
                "default_convert_feature_to_number": True,
                "default_sql_key_column": 0,
                "default_api_key_column": 0,
                "default_sql_feature_start": 1,
                "default_api_feature_start": 1
            }
        }
    
    with open(config_path, 'r', encoding='utf-8') as f:
        config = json.load(f)
    
    return config


def add_scenario(config_path: str, scenario: dict):
    """
    添加场景到配置
    
    Args:
        config_path: 配置文件路径
        scenario: 场景配置
    """
    config = load_config(config_path)
    config["scenarios"].append(scenario)
    save_config(config_path, config["scenarios"], config.get("global_config"))


def update_scenario(config_path: str, scenario_name: str, updated_scenario: dict):
    """
    更新场景配置
    
    Args:
        config_path: 配置文件路径
        scenario_name: 场景名称
        updated_scenario: 更新后的场景配置
    """
    config = load_config(config_path)
    
    # 查找并更新场景
    for i, scenario in enumerate(config["scenarios"]):
        if scenario.get("name") == scenario_name:
            config["scenarios"][i] = updated_scenario
            break
    
    save_config(config_path, config["scenarios"], config.get("global_config"))


def delete_scenario(config_path: str, scenario_name: str):
    """
    删除场景
    
    Args:
        config_path: 配置文件路径
        scenario_name: 场景名称
    """
    config = load_config(config_path)
    
    # 过滤掉要删除的场景
    config["scenarios"] = [s for s in config["scenarios"] if s.get("name") != scenario_name]
    
    save_config(config_path, config["scenarios"], config.get("global_config"))


def get_scenario(config_path: str, scenario_name: str):
    """
    获取指定场景的配置
    
    Args:
        config_path: 配置文件路径
        scenario_name: 场景名称
    
    Returns:
        场景配置字典，如果不存在则返回None
    """
    config = load_config(config_path)
    
    for scenario in config["scenarios"]:
        if scenario.get("name") == scenario_name:
            return scenario
    
    return None
