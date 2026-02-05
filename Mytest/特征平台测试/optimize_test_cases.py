#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
根据用例名称优化测试步骤和预期结果
"""

import csv
import re

def optimize_test_case(case_name, current_steps, current_result, force=False):
    """根据用例名称优化测试步骤和预期结果"""
    
    # 根据用例名称生成测试步骤和预期结果（精简版）
    optimizations = {
        # 批量导入相关
        "批量任务_失败场景_上传文件与模板不一致_任务失败": {
            "steps": "上传与模板格式不一致的Excel文件",
            "result": "任务失败，提示文件格式与模板不一致"
        },
        "批量任务_失败场景_单次导入超过500条_任务失败": {
            "steps": "上传超过500条记录的Excel文件",
            "result": "任务失败，提示单次导入不能超过500条"
        },
        "批量任务_失败场景_单次导入特征互相依赖_任务失败": {
            "steps": "上传包含互相依赖特征的Excel文件",
            "result": "任务失败，提示特征存在循环依赖"
        },
        
        # 特征编码相关
        "批量任务_部分失败场景_特征编码以数字开头/包含空格_导入失败": {
            "steps": "上传特征编码以数字开头或包含空格的Excel文件",
            "result": "该条记录失败，提示特征编码不能以数字开头或包含空格"
        },
        
        # 默认值相关
        "批量任务_部分失败场景_默认值数据类型错_导入失败": {
            "steps": "上传默认值类型与特征类型不匹配的Excel文件",
            "result": "该条记录失败，提示默认值类型不匹配"
        },
        
        # 数据源相关
        "批量任务_部分失败场景_数据源错误_导入失败": {
            "steps": "上传包含不存在或错误数据源的Excel文件",
            "result": "该条记录失败，提示数据源不存在或配置错误"
        },
        "批量任务_部分失败场景_前置特征不存在_不执行外部连通性测试": {
            "steps": "上传衍生特征但前置特征不存在的Excel文件",
            "result": "该条记录失败，提示前置特征不存在，不执行连通性测试"
        },
        
        # 数据源类型连通性测试
        "批量任务_部分失败场景_数据源类型_HTTP_发送 HTTP 请求到配置的服务地址，验证接口可达性": {
            "steps": "上传包含HTTP数据源的Excel文件，查看连通性测试",
            "result": "发送HTTP请求验证接口可达性，显示测试结果"
        },
        "批量任务_部分失败场景_数据源类型_Sql_执行数据库连接测试，验证 SQL 配置正确性": {
            "steps": "上传包含SQL数据源的Excel文件，查看连通性测试",
            "result": "执行数据库连接测试，验证SQL配置正确性"
        },
        "批量任务_部分失败场景_数据源类型_REDIS_执行 Redis 连接测试，验证 Key 配置正确性": {
            "steps": "上传包含REDIS数据源的Excel文件，查看连通性测试",
            "result": "执行Redis连接测试，验证Key配置正确性"
        },
        "批量任务_部分失败场景_数据源类型_KAFKA_执行 Kafka 连接测试，验证 Topic 配置正确性": {
            "steps": "上传包含KAFKA数据源的Excel文件，查看连通性测试",
            "result": "执行Kafka连接测试，验证Topic配置正确性"
        },
        
        # 查询服务&apicode重复
        "批量任务_部分失败场景_数据源类型_Sql_查询服务&apicode*重复_导入失败": {
            "steps": "上传SQL数据源查询服务&apicode重复的Excel文件",
            "result": "该条记录失败，提示查询服务&apicode已存在"
        },
        "批量任务_部分失败场景_数据源类型_REDIS_查询服务&apicode*重复_导入失败": {
            "steps": "上传REDIS数据源查询服务&apicode重复的Excel文件",
            "result": "该条记录失败，提示查询服务&apicode已存在"
        },
        "批量任务_部分失败场景_数据源类型_KAFKA_查询服务&apicode*重复_导入失败": {
            "steps": "上传KAFKA数据源查询服务&apicode重复的Excel文件",
            "result": "该条记录失败，提示查询服务&apicode已存在"
        },
        "批量任务_部分失败场景_数据源类型_HTTP_查询服务&apicode*重复_导入成功": {
            "steps": "上传HTTP数据源查询服务&apicode重复的Excel文件",
            "result": "HTTP数据源允许重复，导入成功"
        },
        
        # 衍生特征前置特征相关
        "批量任务_部分失败场景_一级分类为'衍生特征',前置特征为空_导入失败": {
            "steps": "上传衍生特征但前置特征为空的Excel文件",
            "result": "该条记录失败，提示衍生特征必须配置前置特征"
        },
        "批量任务_部分失败场景_一级分类为'衍生特征',前置特征非空,格式错误_导入失败": {
            "steps": "上传前置特征格式错误的衍生特征Excel文件",
            "result": "该条记录失败，提示前置特征格式不正确"
        },
        "批量任务_部分失败场景_一级分类为'衍生特征',单个特征的前置特征重复_导入失败": {
            "steps": "上传单个特征配置了重复前置特征的Excel文件",
            "result": "该条记录失败，提示前置特征不能重复"
        },
    }
    
    # 查找匹配的优化规则
    for key, value in optimizations.items():
        if key in case_name:
            return value["steps"], value["result"]
    
    # 如果没有匹配的规则，返回原值
    return current_steps, current_result

def process_csv(input_file, output_file):
    """处理CSV文件，优化测试步骤和预期结果"""
    
    print(f"正在读取文件: {input_file}")
    
    with open(input_file, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        rows = list(reader)
    
    print(f"共读取 {len(rows)} 行数据")
    
    updated_count = 0
    for row in rows:
        case_name = row.get('用例名称', '')
        if not case_name or not case_name.strip():
            continue
            
        current_steps = row.get('测试步骤', '')
        current_result = row.get('预期结果', '')
        
        # 优化测试步骤和预期结果（强制优化匹配的用例）
        new_steps, new_result = optimize_test_case(case_name, current_steps, current_result, force=True)
        
        if new_steps != current_steps or new_result != current_result:
            row['测试步骤'] = new_steps
            row['预期结果'] = new_result
            updated_count += 1
            print(f"✓ 已优化: {case_name}")
    
    print(f"\n共优化 {updated_count} 个用例")
    
    # 写入新文件
    print(f"正在写入文件: {output_file}")
    with open(output_file, 'w', encoding='utf-8', newline='') as f:
        if rows:
            fieldnames = rows[0].keys()
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(rows)
    
    print(f"✅ 文件已保存: {output_file}")

if __name__ == '__main__':
    input_file = 'Mytest/特征平台测试/特征平台_完整测试用例_最终版.csv'
    output_file = 'Mytest/特征平台测试/特征平台_完整测试用例_最终版_优化.csv'
    
    process_csv(input_file, output_file)
