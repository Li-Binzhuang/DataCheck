#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
UI合并脚本
功能：将旧版index.html的JavaScript代码合并到新版index_new.html中
"""

import re
import os
from datetime import datetime


def extract_javascript(html_file):
    """从HTML文件中提取JavaScript代码"""
    with open(html_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 查找<script>标签中的内容
    pattern = r'<script>(.*?)</script>'
    matches = re.findall(pattern, content, re.DOTALL)
    
    if matches:
        return matches[0]
    return ""


def merge_javascript(new_html_file, old_html_file, output_file):
    """合并JavaScript代码"""
    print("开始合并UI...")
    
    # 读取新版HTML
    with open(new_html_file, 'r', encoding='utf-8') as f:
        new_content = f.read()
    
    # 提取旧版JavaScript
    old_js = extract_javascript(old_html_file)
    
    if not old_js:
        print("❌ 错误：无法从旧版HTML中提取JavaScript代码")
        return False
    
    print(f"✅ 成功提取JavaScript代码，共 {len(old_js)} 字符")
    
    # 在新版HTML中查找<script>标签
    script_pattern = r'(<script>)(.*?)(</script>)'
    
    def replace_script(match):
        return match.group(1) + old_js + match.group(3)
    
    # 替换JavaScript代码
    merged_content = re.sub(script_pattern, replace_script, new_content, flags=re.DOTALL)
    
    # 保存合并后的文件
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(merged_content)
    
    print(f"✅ 成功生成合并后的文件: {output_file}")
    return True


def backup_file(file_path):
    """备份文件"""
    if os.path.exists(file_path):
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_path = f"{file_path}.backup_{timestamp}"
        os.rename(file_path, backup_path)
        print(f"✅ 已备份原文件: {backup_path}")
        return backup_path
    return None


def main():
    """主函数"""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    
    old_html = os.path.join(script_dir, "index_old_tabs.html")
    new_html = os.path.join(script_dir, "index_new.html")
    output_html = os.path.join(script_dir, "index_merged.html")
    final_html = os.path.join(script_dir, "index.html")
    
    # 检查文件是否存在
    if not os.path.exists(old_html):
        print(f"❌ 错误：找不到文件 {old_html}")
        return
    
    if not os.path.exists(new_html):
        print(f"❌ 错误：找不到文件 {new_html}")
        return
    
    print("="*60)
    print("UI合并工具")
    print("="*60)
    print(f"旧版文件: {old_html}")
    print(f"新版文件: {new_html}")
    print(f"输出文件: {output_html}")
    print("="*60)
    
    # 合并JavaScript
    if merge_javascript(new_html, old_html, output_html):
        print("\n✅ 合并成功！")
        print(f"\n生成的文件: {output_html}")
        print("\n下一步操作：")
        print("1. 检查合并后的文件是否正确")
        print("2. 在浏览器中测试所有功能")
        print("3. 如果测试通过，执行以下命令替换：")
        print(f"   mv {output_html} {final_html}")
    else:
        print("\n❌ 合并失败！")


if __name__ == "__main__":
    main()
