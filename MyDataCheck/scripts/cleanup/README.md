# 清理脚本

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

## 快速使用

```bash
# 从项目根目录
cd MyDataCheck

# 清理旧文件（试运行）
python scripts/cleanup/cleanup_old_files.py --dry-run

# 清理旧文件（正式执行）
./scripts/cleanup/cleanup_now.sh

# 清理冗余文件
python scripts/cleanup/cleanup_redundant_files.py

# 设置自动清理
./scripts/cleanup/setup_auto_cleanup.sh
```

## 注意事项

- 清理前建议先备份重要数据
- 使用 `--dry-run` 参数预览清理内容
- 定期检查清理日志（logs/cleanup.log）
