# MyDataCheck 项目清理指南

## 快速清理

### 一键清理（推荐）

```bash
cd MyDataCheck
python cleanup_redundant_files.py
```

脚本会自动清理：
- ✅ 所有 .DS_Store 文件（17个）
- ✅ 所有 Python 缓存文件（50+个）
- ✅ 测试脚本（归档到 tests/archived/）
- ✅ 测试输出文件（释放约10MB空间）
- ✅ 测试模板文件

### 手动清理

如果需要手动清理，可以使用以下命令：

```bash
# 1. 删除 .DS_Store 文件
find . -name ".DS_Store" -delete

# 2. 删除 Python 缓存
find . -name "__pycache__" -type d -exec rm -rf {} +
find . -name "*.pyc" -delete

# 3. 清理测试输出
rm outputdata/test_*.csv
```

## 清理内容

### 系统文件
- `.DS_Store` - macOS 系统文件，无功能影响

### Python 缓存
- `__pycache__/` - Python 字节码缓存目录
- `*.pyc` - Python 字节码文件

### 测试文件
- 测试脚本 → 归档到 `tests/archived/`
- 测试输出 → 删除
- 测试模板 → 删除

## 清理效果

| 项目 | 数量 | 空间 | 影响 |
|------|------|------|------|
| .DS_Store | 17个 | ~100KB | 无 |
| Python缓存 | 50+个 | ~5MB | 无（会自动重建） |
| 测试脚本 | 7个 | ~50KB | 无（已归档） |
| 测试输出 | 7个 | ~10MB | 无 |
| 测试模板 | 1个 | ~5KB | 无 |
| **总计** | **80+个** | **~15MB** | **无** |

## 安全性

✅ **完全安全**
- 不影响任何功能
- 不影响任何性能
- 不删除任何重要文件
- 测试脚本已归档，可随时找回

## 验证清理

清理后验证功能正常：

```bash
# 1. 启动服务
./start_web.sh

# 2. 访问界面
# http://127.0.0.1:5001

# 3. 测试功能
# - 接口数据对比
# - 线上灰度落数对比
# - 数据对比
# - PKL文件解析
```

## 定期清理

建议定期清理（每周或每月）：

```bash
# 快速清理（只清理缓存和系统文件）
find . -name ".DS_Store" -delete
find . -name "__pycache__" -type d -exec rm -rf {} +
```

## 自动清理

可以添加到 Git hooks：

```bash
# .git/hooks/pre-commit
#!/bin/bash
find . -name ".DS_Store" -delete
find . -name "__pycache__" -type d -exec rm -rf {} +
```

## 相关文档

- [项目冗余文件清理报告](docs/cleanup/项目冗余文件清理报告.md) - 详细清理报告
- [代码优化建议](docs/cleanup/代码优化建议.md) - 进一步优化建议
- [测试脚本归档说明](tests/archived/README.md) - 归档的测试脚本

## 常见问题

### Q: 清理后 Python 缓存会重新生成吗？

A: 是的，Python 会在运行时自动重新生成缓存文件，不影响性能。

### Q: 测试脚本删除后还能找回吗？

A: 可以，测试脚本已归档到 `tests/archived/` 目录，随时可以找回。

### Q: 清理会影响正在运行的服务吗？

A: 建议先停止服务再清理，清理后重新启动即可。

### Q: 可以只清理部分内容吗？

A: 可以，编辑 `cleanup_redundant_files.py` 脚本，注释掉不需要的清理步骤。

---

**清理脚本**: `cleanup_redundant_files.py`  
**状态**: ✅ 准备就绪  
**安全性**: ✅ 完全安全
