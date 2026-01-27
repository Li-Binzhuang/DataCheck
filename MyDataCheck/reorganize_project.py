#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
重新组织 MyDataCheck 项目目录结构

目标：
    1. 清理根目录，只保留核心文件
    2. 将脚本文件归类到 scripts/ 目录
    3. 将测试文件归档到 tests/archived/ 目录
    4. 将文档文件整理到 docs/ 目录
    5. 保持项目整洁和易于维护

作者: MyDataCheck Team
创建时间: 2026-01-27
"""

import os
import shutil


def create_directory_structure():
    """创建目录结构"""
    directories = [
        'scripts/cleanup',      # 清理脚本
        'scripts/maintenance',  # 维护脚本
        'scripts/startup',      # 启动脚本
        'tests/archived',       # 归档的测试
        'docs/01_快速开始',     # 快速开始文档
    ]
    
    for directory in directories:
        os.makedirs(directory, exist_ok=True)
        print(f"  ✅ 创建目录: {directory}")


def move_files():
    """移动文件到合适的位置"""
    
    moves = {
        # 清理脚本 → scripts/cleanup/
        'cleanup_old_files.py': 'scripts/cleanup/',
        'cleanup_redundant_files.py': 'scripts/cleanup/',
        'cleanup_now.sh': 'scripts/cleanup/',
        'setup_auto_cleanup.sh': 'scripts/cleanup/',
        
        # 启动脚本 → scripts/startup/
        'start_web.sh': 'scripts/startup/',
        'start_web_production.sh': 'scripts/startup/',
        'stop_web.sh': 'scripts/startup/',
        'install_psutil.sh': 'scripts/startup/',
        
        # 维护脚本 → scripts/maintenance/
        'check_startup.py': 'scripts/maintenance/',
        
        # 测试脚本 → tests/archived/
        'demo_50000_rows.py': 'tests/archived/',
        'test_api_comparison_memory.py': 'tests/archived/',
        'test_memory_cleanup.py': 'tests/archived/',
        'test_memory_optimization.py': 'tests/archived/',
        'test_progress_display.py': 'tests/archived/',
        'test_write_performance.py': 'tests/archived/',
        'verify_optimization.py': 'tests/archived/',
        
        # 文档 → docs/01_快速开始/
        'CLEANUP_GUIDE.md': 'docs/01_快速开始/',
        'MEMORY_OPTIMIZATION.md': 'docs/01_快速开始/',
    }
    
    print("\n" + "="*80)
    print("移动文件")
    print("="*80)
    
    moved_count = 0
    for src, dst_dir in moves.items():
        if os.path.exists(src):
            dst = os.path.join(dst_dir, src)
            try:
                shutil.move(src, dst)
                print(f"  ✅ {src} → {dst_dir}")
                moved_count += 1
            except Exception as e:
                print(f"  ❌ 移动失败: {src} - {e}")
        else:
            print(f"  ⚠️  文件不存在: {src}")
    
    return moved_count


def create_readme_files():
    """创建各目录的 README 文件"""
    
    readmes = {
        'scripts/cleanup/README.md': """# 清理脚本

本目录包含项目清理相关的脚本。

## 脚本说明

| 脚本 | 说明 | 使用方法 |
|------|------|----------|
| cleanup_old_files.py | 清理旧的输出文件（5天前） | `python cleanup_old_files.py` |
| cleanup_redundant_files.py | 清理冗余文件（缓存、测试等） | `python cleanup_redundant_files.py` |
| cleanup_now.sh | 立即执行清理 | `./cleanup_now.sh` |
| setup_auto_cleanup.sh | 设置自动清理定时任务 | `./setup_auto_cleanup.sh` |

## 使用建议

1. **日常清理**: 使用 `cleanup_old_files.py` 清理旧文件
2. **深度清理**: 使用 `cleanup_redundant_files.py` 清理冗余文件
3. **自动化**: 使用 `setup_auto_cleanup.sh` 设置定时任务

## 注意事项

- 清理前建议先备份重要数据
- 使用 `--dry-run` 参数预览清理内容
- 定期检查清理日志
""",
        
        'scripts/startup/README.md': """# 启动脚本

本目录包含项目启动和停止相关的脚本。

## 脚本说明

| 脚本 | 说明 | 使用方法 |
|------|------|----------|
| start_web.sh | 启动 Web 服务（开发模式） | `./start_web.sh` |
| start_web_production.sh | 启动 Web 服务（生产模式） | `./start_web_production.sh` |
| stop_web.sh | 停止 Web 服务 | `./stop_web.sh` |
| install_psutil.sh | 安装 psutil 依赖 | `./install_psutil.sh` |

## 快速启动

```bash
# 从项目根目录启动
cd MyDataCheck
./scripts/startup/start_web.sh

# 或者创建软链接到根目录
ln -s scripts/startup/start_web.sh start_web.sh
./start_web.sh
```

## 访问地址

- 开发模式: http://127.0.0.1:5001
- 生产模式: 根据配置

## 注意事项

- 首次启动前确保已安装依赖
- 生产模式需要配置环境变量
- 停止服务使用 Ctrl+C 或 stop_web.sh
""",
        
        'scripts/maintenance/README.md': """# 维护脚本

本目录包含项目维护相关的脚本。

## 脚本说明

| 脚本 | 说明 | 使用方法 |
|------|------|----------|
| check_startup.py | 检查启动环境 | `python check_startup.py` |

## 使用场景

1. **启动前检查**: 验证环境配置是否正确
2. **问题排查**: 诊断启动失败原因
3. **依赖验证**: 检查所有依赖是否安装

## 检查内容

- Python 版本
- 虚拟环境状态
- 依赖包安装情况
- 模块导入测试
- 端口占用检查
"""
    }
    
    print("\n" + "="*80)
    print("创建 README 文件")
    print("="*80)
    
    for path, content in readmes.items():
        try:
            with open(path, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"  ✅ 创建: {path}")
        except Exception as e:
            print(f"  ❌ 创建失败: {path} - {e}")


def create_root_symlinks():
    """在根目录创建常用脚本的软链接"""
    
    print("\n" + "="*80)
    print("创建软链接（便于快速访问）")
    print("="*80)
    
    symlinks = {
        'start_web.sh': 'scripts/startup/start_web.sh',
        'stop_web.sh': 'scripts/startup/stop_web.sh',
    }
    
    for link_name, target in symlinks.items():
        if os.path.exists(link_name):
            print(f"  ⚠️  软链接已存在: {link_name}")
            continue
        
        try:
            os.symlink(target, link_name)
            print(f"  ✅ 创建软链接: {link_name} → {target}")
        except Exception as e:
            print(f"  ❌ 创建失败: {link_name} - {e}")


def update_documentation():
    """更新文档中的路径引用"""
    
    print("\n" + "="*80)
    print("更新文档")
    print("="*80)
    
    # 创建目录结构说明
    structure_doc = """# MyDataCheck 项目目录结构

## 根目录文件（精简后）

```
MyDataCheck/
├── README.md                    # 项目说明
├── requirements.txt             # Python 依赖
├── web_app.py                   # Web 应用入口
├── start_web.sh                 # 启动脚本（软链接）
├── stop_web.sh                  # 停止脚本（软链接）
└── .gitignore                   # Git 忽略配置
```

## 核心目录

```
├── api_comparison/              # 接口数据对比模块
├── common/                      # 公共工具模块
├── data_comparison/             # 数据对比模块
├── online_comparison/           # 线上对比模块
├── web/                         # Web 应用模块
├── static/                      # 静态资源
└── templates/                   # HTML 模板
```

## 脚本目录

```
├── scripts/
│   ├── cleanup/                 # 清理脚本
│   │   ├── cleanup_old_files.py
│   │   ├── cleanup_redundant_files.py
│   │   ├── cleanup_now.sh
│   │   └── setup_auto_cleanup.sh
│   ├── startup/                 # 启动脚本
│   │   ├── start_web.sh
│   │   ├── start_web_production.sh
│   │   ├── stop_web.sh
│   │   └── install_psutil.sh
│   └── maintenance/             # 维护脚本
│       └── check_startup.py
```

## 测试目录

```
├── tests/
│   ├── archived/                # 归档的测试脚本
│   │   ├── demo_50000_rows.py
│   │   ├── test_memory_*.py
│   │   └── verify_optimization.py
│   ├── test_import.py
│   └── test_dynamic_params.py
```

## 文档目录

```
├── docs/
│   ├── 01_快速开始/
│   │   ├── QUICK_START.md
│   │   ├── CLEANUP_GUIDE.md
│   │   └── MEMORY_OPTIMIZATION.md
│   ├── 02_Web界面/
│   ├── 04_数据对比功能/
│   ├── 09_问题修复记录/
│   └── archive/
```

## 数据目录

```
├── inputdata/                   # 输入数据
│   ├── api_comparison/
│   ├── data_comparison/
│   └── online_comparison/
├── outputdata/                  # 输出数据
│   ├── api_comparison/
│   ├── data_comparison/
│   └── online_comparison/
└── logs/                        # 日志文件
```

## 优化效果

### 优化前
- 根目录文件：20+ 个
- 结构混乱，难以维护

### 优化后
- 根目录文件：6 个核心文件
- 结构清晰，易于维护
- 脚本分类管理
- 测试文件归档

## 快速访问

根目录保留了常用脚本的软链接：
- `start_web.sh` → `scripts/startup/start_web.sh`
- `stop_web.sh` → `scripts/startup/stop_web.sh`

可以直接在根目录使用：
```bash
./start_web.sh
./stop_web.sh
```

## 相关文档

- [清理脚本说明](../scripts/cleanup/README.md)
- [启动脚本说明](../scripts/startup/README.md)
- [维护脚本说明](../scripts/maintenance/README.md)
- [测试脚本归档](../tests/archived/README.md)
"""
    
    doc_path = 'docs/01_快速开始/项目目录结构.md'
    try:
        with open(doc_path, 'w', encoding='utf-8') as f:
            f.write(structure_doc)
        print(f"  ✅ 创建: {doc_path}")
    except Exception as e:
        print(f"  ❌ 创建失败: {doc_path} - {e}")


def main():
    """主函数"""
    print("\n" + "="*80)
    print("MyDataCheck 项目目录结构重组")
    print("="*80)
    
    root_dir = os.path.dirname(os.path.abspath(__file__))
    os.chdir(root_dir)
    
    print(f"\n项目目录: {root_dir}")
    
    # 1. 创建目录结构
    print("\n" + "="*80)
    print("创建目录结构")
    print("="*80)
    create_directory_structure()
    
    # 2. 移动文件
    moved_count = move_files()
    
    # 3. 创建 README
    create_readme_files()
    
    # 4. 创建软链接
    create_root_symlinks()
    
    # 5. 更新文档
    update_documentation()
    
    # 总结
    print("\n" + "="*80)
    print("重组完成")
    print("="*80)
    print(f"\n共移动 {moved_count} 个文件")
    print("\n目录结构:")
    print("  ✅ scripts/cleanup/      - 清理脚本")
    print("  ✅ scripts/startup/      - 启动脚本")
    print("  ✅ scripts/maintenance/  - 维护脚本")
    print("  ✅ tests/archived/       - 归档测试")
    print("  ✅ docs/01_快速开始/     - 快速文档")
    
    print("\n根目录保留:")
    print("  • README.md")
    print("  • requirements.txt")
    print("  • web_app.py")
    print("  • start_web.sh (软链接)")
    print("  • stop_web.sh (软链接)")
    
    print("\n使用方法:")
    print("  # 启动服务（软链接，在根目录直接使用）")
    print("  ./start_web.sh")
    print("")
    print("  # 或使用完整路径")
    print("  ./scripts/startup/start_web.sh")
    
    print("\n" + "="*80)
    print("✅ 项目目录结构已优化！")
    print("="*80 + "\n")


if __name__ == "__main__":
    # 确认执行
    print("\n⚠️  警告：此脚本将重组项目目录结构")
    print("\n将执行以下操作:")
    print("  • 创建 scripts/ 子目录")
    print("  • 移动脚本文件到对应目录")
    print("  • 移动测试文件到 tests/archived/")
    print("  • 移动文档到 docs/01_快速开始/")
    print("  • 在根目录创建常用脚本的软链接")
    
    response = input("\n是否继续？(yes/no): ").strip().lower()
    
    if response in ['yes', 'y']:
        main()
    else:
        print("\n已取消重组操作")
