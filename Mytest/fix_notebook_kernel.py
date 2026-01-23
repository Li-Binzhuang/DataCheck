#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
修复 notebook 的内核配置，指向正确的 Python 3.12 环境
"""

import json
import os
import sys

def fix_notebook_kernel(notebook_path):
    """修复 notebook 的内核配置"""
    
    # 读取 notebook
    with open(notebook_path, 'r', encoding='utf-8') as f:
        notebook = json.load(f)
    
    # 设置正确的内核配置
    venv_python = "/Users/zhanglifeng12703/Documents/OverseasPython/Mytest/.venv/bin/python"
    
    # 检查 Python 版本
    if os.path.exists(venv_python):
        import subprocess
        try:
            result = subprocess.run([venv_python, "--version"], 
                                  capture_output=True, text=True, timeout=5)
            python_version = result.stdout.strip()
            print(f"虚拟环境 Python: {python_version}")
        except:
            python_version = "未知"
    else:
        print(f"⚠️  虚拟环境不存在: {venv_python}")
        return False
    
    # 更新内核配置
    if 'metadata' not in notebook:
        notebook['metadata'] = {}
    
    notebook['metadata']['kernelspec'] = {
        "display_name": "Python 3.12 (Mytest)",
        "language": "python",
        "name": "python312-mytest"
    }
    
    notebook['metadata']['language_info'] = {
        "codemirror_mode": {
            "name": "ipython",
            "version": 3
        },
        "file_extension": ".py",
        "mimetype": "text/x-python",
        "name": "python",
        "nbconvert_exporter": "python",
        "pygments_lexer": "ipython3",
        "version": python_version.replace("Python ", "")
    }
    
    # 保存 notebook
    with open(notebook_path, 'w', encoding='utf-8') as f:
        json.dump(notebook, f, indent=1, ensure_ascii=False)
    
    print(f"✅ 已更新 notebook 内核配置")
    print(f"   内核: Python 3.12 (Mytest)")
    print(f"   Python 路径: {venv_python}")
    
    return True

if __name__ == '__main__':
    notebook_path = "/Users/zhanglifeng12703/Documents/OverseasPython/Mytest/ipynb/parse_pkl_to_csv.ipynb"
    
    if not os.path.exists(notebook_path):
        print(f"❌ Notebook 不存在: {notebook_path}")
        sys.exit(1)
    
    print("=" * 70)
    print("修复 Notebook 内核配置")
    print("=" * 70)
    print()
    
    if fix_notebook_kernel(notebook_path):
        print()
        print("=" * 70)
        print("✅ 修复完成！")
        print("=" * 70)
        print()
        print("请重启 Cursor，然后重新打开 notebook")
        print("或者运行: ./start_jupyter.sh 从浏览器打开")
    else:
        print()
        print("❌ 修复失败，请先运行: ./switch_python.sh")
