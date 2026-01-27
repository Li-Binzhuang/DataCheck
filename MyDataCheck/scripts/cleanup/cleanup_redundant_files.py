#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
清理 MyDataCheck 项目中的冗余文件

功能:
    1. 删除所有 .DS_Store 文件（macOS系统文件）
    2. 删除所有 __pycache__ 目录和 .pyc 文件
    3. 归档测试脚本到 tests 目录
    4. 清理测试输出文件
    5. 删除不再使用的测试模板

作者: MyDataCheck Team
创建时间: 2026-01-27
"""

import os
import shutil
import sys


def remove_ds_store(root_dir):
    """删除所有 .DS_Store 文件"""
    print("\n" + "="*80)
    print("清理 .DS_Store 文件")
    print("="*80)
    
    count = 0
    for root, dirs, files in os.walk(root_dir):
        for file in files:
            if file == '.DS_Store':
                file_path = os.path.join(root, file)
                try:
                    os.remove(file_path)
                    print(f"  ✅ 已删除: {file_path}")
                    count += 1
                except Exception as e:
                    print(f"  ❌ 删除失败: {file_path} - {e}")
    
    print(f"\n共删除 {count} 个 .DS_Store 文件")
    return count


def remove_pycache(root_dir):
    """删除所有 __pycache__ 目录和 .pyc 文件"""
    print("\n" + "="*80)
    print("清理 Python 缓存文件")
    print("="*80)
    
    dir_count = 0
    file_count = 0
    
    for root, dirs, files in os.walk(root_dir, topdown=False):
        # 删除 .pyc 文件
        for file in files:
            if file.endswith('.pyc'):
                file_path = os.path.join(root, file)
                try:
                    os.remove(file_path)
                    print(f"  ✅ 已删除: {file_path}")
                    file_count += 1
                except Exception as e:
                    print(f"  ❌ 删除失败: {file_path} - {e}")
        
        # 删除 __pycache__ 目录
        for dir_name in dirs:
            if dir_name == '__pycache__':
                dir_path = os.path.join(root, dir_name)
                try:
                    shutil.rmtree(dir_path)
                    print(f"  ✅ 已删除目录: {dir_path}")
                    dir_count += 1
                except Exception as e:
                    print(f"  ❌ 删除失败: {dir_path} - {e}")
    
    print(f"\n共删除 {dir_count} 个 __pycache__ 目录和 {file_count} 个 .pyc 文件")
    return dir_count + file_count


def archive_test_scripts(root_dir):
    """归档测试脚本到 tests 目录"""
    print("\n" + "="*80)
    print("归档测试脚本")
    print("="*80)
    
    test_scripts = [
        'demo_50000_rows.py',
        'test_api_comparison_memory.py',
        'test_memory_cleanup.py',
        'test_memory_optimization.py',
        'test_progress_display.py',
        'test_write_performance.py',
        'verify_optimization.py'
    ]
    
    tests_dir = os.path.join(root_dir, 'tests')
    archived_dir = os.path.join(tests_dir, 'archived')
    os.makedirs(archived_dir, exist_ok=True)
    
    count = 0
    for script in test_scripts:
        src = os.path.join(root_dir, script)
        if os.path.exists(src):
            dst = os.path.join(archived_dir, script)
            try:
                shutil.move(src, dst)
                print(f"  ✅ 已归档: {script} → tests/archived/")
                count += 1
            except Exception as e:
                print(f"  ❌ 归档失败: {script} - {e}")
    
    print(f"\n共归档 {count} 个测试脚本")
    return count


def clean_test_output(root_dir):
    """清理测试输出文件"""
    print("\n" + "="*80)
    print("清理测试输出文件")
    print("="*80)
    
    output_dir = os.path.join(root_dir, 'outputdata')
    test_files = [
        'test_optimized_result_analysis_report.csv',
        'test_optimized_result_feature_stats.csv',
        'test_original_result_全量数据合并.csv',
        'test_original_result_analysis_report.csv',
        'test_original_result_feature_stats.csv',
        'test_stream_output.csv',
        'test_traditional_output.csv'
    ]
    
    count = 0
    total_size = 0
    
    for file in test_files:
        file_path = os.path.join(output_dir, file)
        if os.path.exists(file_path):
            try:
                size = os.path.getsize(file_path)
                os.remove(file_path)
                total_size += size
                print(f"  ✅ 已删除: {file} ({size / 1024 / 1024:.2f} MB)")
                count += 1
            except Exception as e:
                print(f"  ❌ 删除失败: {file} - {e}")
    
    print(f"\n共删除 {count} 个测试文件，释放 {total_size / 1024 / 1024:.2f} MB 空间")
    return count


def remove_test_template(root_dir):
    """删除不再使用的测试模板"""
    print("\n" + "="*80)
    print("删除测试模板")
    print("="*80)
    
    test_template = os.path.join(root_dir, 'templates', 'test_menu.html')
    
    if os.path.exists(test_template):
        try:
            os.remove(test_template)
            print(f"  ✅ 已删除: templates/test_menu.html")
            return 1
        except Exception as e:
            print(f"  ❌ 删除失败: {e}")
            return 0
    else:
        print(f"  ℹ️  文件不存在: templates/test_menu.html")
        return 0


def create_archived_readme(root_dir):
    """创建归档目录的 README"""
    archived_dir = os.path.join(root_dir, 'tests', 'archived')
    readme_path = os.path.join(archived_dir, 'README.md')
    
    content = """# 测试脚本归档

本目录存放已归档的测试脚本。

## 归档的脚本

| 脚本 | 说明 | 归档原因 |
|------|------|----------|
| demo_50000_rows.py | 演示批量写入50000行数据 | 功能已验证，保留作为参考 |
| test_api_comparison_memory.py | 接口对比内存测试 | 优化已完成，保留作为参考 |
| test_memory_cleanup.py | 内存清理功能测试 | 功能已验证，保留作为参考 |
| test_memory_optimization.py | 内存优化测试 | 优化已完成，保留作为参考 |
| test_progress_display.py | 进度显示测试 | 功能已验证，保留作为参考 |
| test_write_performance.py | 写入性能测试 | 优化已完成，保留作为参考 |
| verify_optimization.py | 优化验证脚本 | 功能已验证，保留作为参考 |

## 使用说明

这些脚本已完成其使命，功能已集成到主程序中。

如需重新测试，可以从这里找到相关脚本。

## 归档时间

2026-01-27
"""
    
    with open(readme_path, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"\n  ✅ 已创建: tests/archived/README.md")


def main():
    """主函数"""
    print("\n" + "="*80)
    print("MyDataCheck 项目冗余文件清理")
    print("="*80)
    
    # 获取项目根目录
    root_dir = os.path.dirname(os.path.abspath(__file__))
    print(f"\n项目目录: {root_dir}")
    
    # 统计
    total_removed = 0
    
    # 1. 删除 .DS_Store
    total_removed += remove_ds_store(root_dir)
    
    # 2. 删除 Python 缓存
    total_removed += remove_pycache(root_dir)
    
    # 3. 归档测试脚本
    total_removed += archive_test_scripts(root_dir)
    
    # 4. 清理测试输出
    total_removed += clean_test_output(root_dir)
    
    # 5. 删除测试模板
    total_removed += remove_test_template(root_dir)
    
    # 6. 创建归档说明
    create_archived_readme(root_dir)
    
    # 总结
    print("\n" + "="*80)
    print("清理完成")
    print("="*80)
    print(f"\n共处理 {total_removed} 个文件/目录")
    print("\n清理内容:")
    print("  ✅ .DS_Store 文件（macOS系统文件）")
    print("  ✅ __pycache__ 目录和 .pyc 文件")
    print("  ✅ 测试脚本（已归档到 tests/archived/）")
    print("  ✅ 测试输出文件")
    print("  ✅ 测试模板文件")
    print("\n项目现在更加整洁了！")
    print("="*80 + "\n")


if __name__ == "__main__":
    # 确认执行
    print("\n⚠️  警告：此脚本将删除以下内容：")
    print("  • 所有 .DS_Store 文件")
    print("  • 所有 __pycache__ 目录和 .pyc 文件")
    print("  • 测试脚本（归档到 tests/archived/）")
    print("  • 测试输出文件")
    print("  • 测试模板文件")
    print("\n这些操作不可恢复！")
    
    response = input("\n是否继续？(yes/no): ").strip().lower()
    
    if response in ['yes', 'y']:
        main()
    else:
        print("\n已取消清理操作")
        sys.exit(0)
