#!/usr/bin/env python3
"""
CDC项目文件整理脚本

将.md和.py文件归档到合理的目录结构中
"""

import shutil
from pathlib import Path

def organize_cdc_files():
    """整理CDC项目文件"""
    
    cdc_dir = Path("CDC")
    
    # 创建目录结构
    dirs = {
        "docs": cdc_dir / "docs",
        "docs_zlf_update": cdc_dir / "docs" / "zlf_update",
        "docs_float": cdc_dir / "docs" / "浮点数处理",
        "docs_npnan": cdc_dir / "docs" / "npnan补充修复",
        "docs_batch": cdc_dir / "docs" / "分批输出",
        "docs_utilization": cdc_dir / "docs" / "utilization验证",
        "scripts": cdc_dir / "scripts",
        "scripts_update": cdc_dir / "scripts" / "update_scripts",
        "scripts_verify": cdc_dir / "scripts" / "verify_scripts",
        "scripts_utils": cdc_dir / "scripts" / "utils",
    }
    
    # 创建目录
    for dir_path in dirs.values():
        dir_path.mkdir(parents=True, exist_ok=True)
        print(f"创建目录: {dir_path}")
    
    # 文件移动规则
    moves = {
        # zlf_update相关文档
        "zlf_update_summary.md": dirs["docs_zlf_update"],
        "zlf_update_quick_reference.md": dirs["docs_zlf_update"],
        "zlf_update_verification_report.md": dirs["docs_zlf_update"],
        "zlf_update_最终总结.md": dirs["docs_zlf_update"],
        "zlf_update_统计报告.md": dirs["docs_zlf_update"],
        "README_zlf_update.md": dirs["docs_zlf_update"],
        
        # 浮点数处理相关文档
        "浮点数处理功能说明.md": dirs["docs_float"],
        "浮点数处理快速参考.md": dirs["docs_float"],
        "浮点数处理功能完成报告.md": dirs["docs_float"],
        
        # np.nan补充修复相关文档
        "np.nan补充修复说明.md": dirs["docs_npnan"],
        "np.nan补充修复快速参考.md": dirs["docs_npnan"],
        "np.nan补充修复完成报告.md": dirs["docs_npnan"],
        
        # 分批输出相关文档
        "分批输出功能说明.md": dirs["docs_batch"],
        "分批输出快速参考.md": dirs["docs_batch"],
        "前200条记录输出快速参考.md": dirs["docs_batch"],
        "前200条记录输出功能完成报告.md": dirs["docs_batch"],
        "README_前200条记录输出.md": dirs["docs_batch"],
        
        # utilization验证相关文档
        "BOSS板块utilization特征精度验证.md": dirs["docs_utilization"],
        "BOSS板块utilization特征精度快速参考.md": dirs["docs_utilization"],
        
        # 更新脚本
        "update_fillna_comprehensive.py": dirs["scripts_update"],
        "update_fillna_to_minus999.py": dirs["scripts_update"],
        "add_float_processing.py": dirs["scripts_update"],
        "add_sample200_output.py": dirs["scripts_update"],
        "add_sample200_to_boss.py": dirs["scripts_update"],
        "fix_decimal_precision.py": dirs["scripts_update"],
        
        # 验证脚本
        "verify_float_precision.py": dirs["scripts_verify"],
        "verify_all_zlf_updates.sh": dirs["scripts_verify"],
        
        # 工具脚本
        "查询apply_id示例.py": dirs["scripts_utils"],
        "查看解析结果详细版.py": dirs["scripts_utils"],
    }
    
    # 执行移动
    print("\n开始移动文件...")
    moved_count = 0
    skipped_count = 0
    
    for filename, target_dir in moves.items():
        source = cdc_dir / filename
        target = target_dir / filename
        
        if source.exists():
            if not target.exists():
                shutil.move(str(source), str(target))
                print(f"✅ 移动: {filename} -> {target_dir.name}")
                moved_count += 1
            else:
                print(f"⚠️  跳过: {filename} (目标已存在)")
                skipped_count += 1
        else:
            print(f"❌ 未找到: {filename}")
    
    print(f"\n移动完成: {moved_count} 个文件")
    print(f"跳过: {skipped_count} 个文件")
    
    # 创建README文件
    create_readme_files(dirs)
    
    return moved_count

def create_readme_files(dirs):
    """创建各目录的README文件"""
    
    readmes = {
        dirs["docs"]: """# CDC项目文档

本目录包含CDC项目的所有文档，按主题分类。

## 目录结构

- `zlf_update/` - zlf update修改相关文档
- `浮点数处理/` - 浮点数精度处理相关文档
- `npnan补充修复/` - np.nan补充修复相关文档
- `分批输出/` - 分批输出功能相关文档
- `utilization验证/` - utilization特征验证相关文档

## 快速导航

- 总体修改总结：`zlf_update/zlf_update_最终总结.md`
- 文档索引：`../README_文档索引.md`
""",
        
        dirs["docs_zlf_update"]: """# zlf update 修改文档

本目录包含所有zlf update标识的修改相关文档。

## 文档列表

- `zlf_update_最终总结.md` - 最终总结报告
- `zlf_update_summary.md` - 修改总结
- `zlf_update_quick_reference.md` - 快速参考
- `zlf_update_verification_report.md` - 验证报告
- `zlf_update_统计报告.md` - 统计报告
- `README_zlf_update.md` - 完整使用指南
""",
        
        dirs["docs_float"]: """# 浮点数处理文档

本目录包含浮点数精度处理相关文档。

## 文档列表

- `浮点数处理功能说明.md` - 详细功能说明
- `浮点数处理快速参考.md` - 快速参考
- `浮点数处理功能完成报告.md` - 完成报告
""",
        
        dirs["docs_npnan"]: """# np.nan补充修复文档

本目录包含np.nan补充修复相关文档。

## 文档列表

- `np.nan补充修复说明.md` - 详细说明
- `np.nan补充修复快速参考.md` - 快速参考
- `np.nan补充修复完成报告.md` - 完成报告
""",
        
        dirs["docs_batch"]: """# 分批输出功能文档

本目录包含分批输出功能相关文档。

## 文档列表

- `分批输出功能说明.md` - 详细功能说明
- `分批输出快速参考.md` - 快速参考
- `前200条记录输出功能完成报告.md` - 完成报告
- `前200条记录输出快速参考.md` - 快速参考
- `README_前200条记录输出.md` - 使用指南
""",
        
        dirs["docs_utilization"]: """# utilization特征验证文档

本目录包含BOSS板块utilization特征精度验证相关文档。

## 文档列表

- `BOSS板块utilization特征精度验证.md` - 详细验证说明
- `BOSS板块utilization特征精度快速参考.md` - 快速参考
""",
        
        dirs["scripts"]: """# CDC项目脚本

本目录包含CDC项目的所有脚本，按功能分类。

## 目录结构

- `update_scripts/` - 更新和修改脚本
- `verify_scripts/` - 验证脚本
- `utils/` - 工具脚本

## 使用说明

详见各子目录的README文件。
""",
        
        dirs["scripts_update"]: """# 更新和修改脚本

本目录包含用于更新和修改代码的脚本。

## 脚本列表

- `update_fillna_comprehensive.py` - 空值填充全面修改脚本
- `update_fillna_to_minus999.py` - 空值填充初始修改脚本
- `add_float_processing.py` - 浮点数处理添加脚本
- `add_sample200_output.py` - 分批输出功能模板
- `add_sample200_to_boss.py` - 分批输出批量修改脚本
- `fix_decimal_precision.py` - 小数精度修复脚本
""",
        
        dirs["scripts_verify"]: """# 验证脚本

本目录包含用于验证修改的脚本。

## 脚本列表

- `verify_float_precision.py` - 浮点数精度验证脚本
- `verify_all_zlf_updates.sh` - zlf update综合验证脚本

## 使用方法

```bash
# Python验证脚本
python verify_float_precision.py

# Shell验证脚本
./verify_all_zlf_updates.sh
```
""",
        
        dirs["scripts_utils"]: """# 工具脚本

本目录包含各种工具脚本。

## 脚本列表

- `查询apply_id示例.py` - 查询apply_id示例
- `查看解析结果详细版.py` - 查看解析结果详细版

## 使用方法

详见各脚本的注释说明。
""",
    }
    
    print("\n创建README文件...")
    for dir_path, content in readmes.items():
        readme_path = dir_path / "README.md"
        if not readme_path.exists():
            readme_path.write_text(content, encoding="utf-8")
            print(f"✅ 创建: {readme_path.relative_to(Path('CDC'))}")

if __name__ == "__main__":
    print("=" * 80)
    print("CDC项目文件整理")
    print("=" * 80)
    print()
    
    try:
        moved_count = organize_cdc_files()
        print()
        print("=" * 80)
        print(f"✅ 整理完成！共移动 {moved_count} 个文件")
        print("=" * 80)
    except Exception as e:
        print(f"❌ 错误: {e}")
        import traceback
        traceback.print_exc()
