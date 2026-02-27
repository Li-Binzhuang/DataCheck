#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
从特征SQL文件中提取依赖的库表，并匹配reports中的分析报告
"""

import os
import re
from collections import defaultdict

# 目录配置
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
SQL_DIR = os.path.join(SCRIPT_DIR, "特征Sql")
REPORT_DIR = os.path.join(SCRIPT_DIR, "reports")
OUTPUT_FILE = os.path.join(SCRIPT_DIR, "表依赖关系汇总.md")


def extract_tables_from_sql(sql_content):
    """从SQL内容中提取表名"""
    tables = set()
    
    # 匹配 FROM 和 JOIN 后的表名
    # 支持格式：database.schema.table 或 schema.table 或 table
    patterns = [
        r'(?:FROM|JOIN)\s+([a-zA-Z0-9_]+\.[a-zA-Z0-9_]+\.[a-zA-Z0-9_]+)',  # db.schema.table
        r'(?:FROM|JOIN)\s+([a-zA-Z0-9_]+\.[a-zA-Z0-9_]+)',  # schema.table
    ]
    
    for pattern in patterns:
        matches = re.findall(pattern, sql_content, re.IGNORECASE)
        tables.update(matches)
    
    return tables


def extract_table_from_report(report_path):
    """从报告文件中提取表名"""
    try:
        with open(report_path, 'r', encoding='utf-8') as f:
            content = f.read()
            
        # 匹配 **表名**: `表名` 或 **表代码**: 表名
        patterns = [
            r'\*\*表名\*\*:\s*`([^`]+)`',
            r'\*\*表代码\*\*:\s*([a-zA-Z0-9_\.]+)',
        ]
        
        for pattern in patterns:
            match = re.search(pattern, content)
            if match:
                return match.group(1).strip()
        
        return None
    except Exception as e:
        print(f"读取报告文件失败 {report_path}: {e}")
        return None


def load_all_reports():
    """加载所有报告文件，建立表名到报告的映射"""
    table_to_report = {}
    
    if not os.path.exists(REPORT_DIR):
        print(f"报告目录不存在: {REPORT_DIR}")
        return table_to_report
    
    for filename in os.listdir(REPORT_DIR):
        if not filename.endswith('.md'):
            continue
        
        report_path = os.path.join(REPORT_DIR, filename)
        table_name = extract_table_from_report(report_path)
        
        if table_name:
            table_to_report[table_name] = filename
    
    return table_to_report


def process_all_sql_files():
    """处理所有SQL文件，提取表名"""
    all_tables = set()
    
    if not os.path.exists(SQL_DIR):
        print(f"SQL目录不存在: {SQL_DIR}")
        return all_tables
    
    sql_files = [f for f in os.listdir(SQL_DIR) if f.endswith('.sql')]
    print(f"找到 {len(sql_files)} 个SQL文件")
    
    for filename in sql_files:
        sql_path = os.path.join(SQL_DIR, filename)
        
        try:
            with open(sql_path, 'r', encoding='utf-8') as f:
                sql_content = f.read()
            
            tables = extract_tables_from_sql(sql_content)
            all_tables.update(tables)
            print(f"  {filename}: 提取到 {len(tables)} 个表")
            
        except Exception as e:
            print(f"  读取SQL文件失败 {filename}: {e}")
    
    return all_tables


def generate_report(all_tables, table_to_report):
    """生成汇总报告"""
    # 按表名排序
    sorted_tables = sorted(all_tables)
    
    # 分类：有报告的表 和 无报告的表
    tables_with_report = []
    tables_without_report = []
    
    for table in sorted_tables:
        # 尝试完全匹配
        if table in table_to_report:
            tables_with_report.append((table, table_to_report[table]))
        else:
            # 尝试部分匹配（只匹配表名部分，不含库名）
            table_short = table.split('.')[-1]
            matched = False
            for report_table, report_file in table_to_report.items():
                if table_short == report_table.split('.')[-1]:
                    tables_with_report.append((table, report_file))
                    matched = True
                    break
            
            if not matched:
                tables_without_report.append(table)
    
    # 生成Markdown报告
    lines = []
    lines.append("# SQL依赖表汇总报告")
    lines.append("")
    lines.append(f"**生成时间**: {__import__('datetime').datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    lines.append(f"**SQL文件数**: {len(os.listdir(SQL_DIR)) if os.path.exists(SQL_DIR) else 0}")
    lines.append(f"**依赖表总数**: {len(all_tables)} (去重后)")
    lines.append(f"**有分析报告**: {len(tables_with_report)} 个表")
    lines.append(f"**无分析报告**: {len(tables_without_report)} 个表")
    lines.append("")
    lines.append("---")
    lines.append("")
    
    # 有报告的表
    lines.append("## 一、有分析报告的表")
    lines.append("")
    lines.append("| 序号 | 表名 | 分析报告 |")
    lines.append("|------|------|----------|")
    
    for idx, (table, report) in enumerate(tables_with_report, 1):
        report_link = f"[{report}](reports/{report})"
        lines.append(f"| {idx} | `{table}` | {report_link} |")
    
    lines.append("")
    lines.append("---")
    lines.append("")
    
    # 无报告的表
    lines.append("## 二、无分析报告的表")
    lines.append("")
    lines.append("| 序号 | 表名 |")
    lines.append("|------|------|")
    
    for idx, table in enumerate(tables_without_report, 1):
        lines.append(f"| {idx} | `{table}` |")
    
    lines.append("")
    lines.append("---")
    lines.append("")
    
    # 所有表清单
    lines.append("## 三、所有依赖表清单（按字母排序）")
    lines.append("")
    for idx, table in enumerate(sorted_tables, 1):
        lines.append(f"{idx}. `{table}`")
    
    lines.append("")
    
    # 写入文件
    with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines))
    
    print(f"\n✅ 报告已生成: {OUTPUT_FILE}")


def main():
    """主函数"""
    print("="*60)
    print("SQL依赖表提取工具")
    print("="*60)
    print()
    
    # 1. 加载所有报告
    print("步骤1: 加载分析报告...")
    table_to_report = load_all_reports()
    print(f"  找到 {len(table_to_report)} 个表的分析报告")
    print()
    
    # 2. 提取所有SQL中的表
    print("步骤2: 提取SQL文件中的表...")
    all_tables = process_all_sql_files()
    print(f"  共提取到 {len(all_tables)} 个不重复的表")
    print()
    
    # 3. 生成报告
    print("步骤3: 生成汇总报告...")
    generate_report(all_tables, table_to_report)
    print()
    
    print("="*60)
    print("处理完成！")
    print("="*60)


if __name__ == "__main__":
    main()
