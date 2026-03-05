# 数据对比模块 v2.0 更新日志

## 版本信息
- **版本号**: v2.0.0
- **发布日期**: 2026-03-05
- **更新类型**: 功能增强

## 主要更新

### 🎉 新增功能：多列主键支持

数据对比模块现已支持单列或多列组合主键，提供更灵活的数据对比能力。

#### 核心特性
1. **向后兼容**：原有单列主键配置完全兼容
2. **灵活配置**：支持任意数量的列组合作为主键
3. **自动处理**：自动识别单列和多列配置格式
4. **性能优化**：多列主键不影响对比性能

#### 配置格式

**单列主键（原有方式）**
```json
{
  "sql_key_column": 0,
  "api_key_column": 0,
  "sql_feature_start": 1,
  "api_feature_start": 1
}
```

**多列主键（新增）**
```json
{
  "sql_key_column": [0, 1],
  "api_key_column": [0, 1],
  "sql_feature_start": 2,
  "api_feature_start": 2
}
```

## 文件变更

### 修改的文件

1. **data_comparator.py**
   - 更新函数签名，支持单列和多列主键参数
   - 添加主键标准化逻辑
   - 更新索引构建逻辑，支持多列主键组合
   - 使用 `||` 作为多列主键分隔符

2. **report_generator.py**
   - 更新全量数据合并逻辑
   - 支持多列主键的输出格式

3. **CONFIG_GUIDE.md**
   - 添加多列主键配置说明
   - 新增配置示例

4. **README.md**
   - 更新功能说明
   - 添加多列主键文档链接
   - 更新版本历史

### 新增的文件

1. **config_example_multi_key.json**
   - 单列、双列、三列主键配置示例

2. **MULTI_KEY_UPDATE.md**
   - 详细的多列主键功能说明
   - 配置示例和使用方法
   - 技术细节和注意事项

3. **MULTI_KEY_QUICK_REFERENCE.md**
   - 快速配置参考
   - 常见场景示例
   - 错误排查指南

4. **test_multi_key.py**
   - 多列主键功能测试脚本
   - 验证单列和多列主键逻辑
   - 主键组合和验证测试

5. **CHANGELOG_v2.0.md**
   - 本更新日志

## 技术实现

### 主键处理逻辑

```python
# 标准化主键列为列表格式
sql_key_columns = sql_key_column if isinstance(sql_key_column, list) else [sql_key_column]
api_key_columns = api_key_column if isinstance(api_key_column, list) else [api_key_column]

# 构建组合主键
key_parts = []
for idx in sql_key_columns:
    if idx < len(row) and row[idx] is not None:
        key_parts.append(str(row[idx]).strip())

key_value = "||".join(key_parts)  # 使用||作为分隔符
```

### 主键验证

- 所有主键列的值都不能为None
- 所有主键列的值都不能为空字符串
- 任一列无效则整行被标记为"仅在XX文件中"

### 输出格式

**单列主键输出**
```
主键值: ABC123
```

**多列主键输出**
```
主键值: ABC123||20260305||PROD001
```

## 使用示例

### 场景1：用户ID作为主键（单列）
```json
{
  "name": "用户特征对比",
  "sql_key_column": 0,
  "api_key_column": 0,
  "sql_feature_start": 1,
  "api_feature_start": 1
}
```

### 场景2：用户ID+日期作为主键（双列）
```json
{
  "name": "用户日期特征对比",
  "sql_key_column": [0, 1],
  "api_key_column": [0, 1],
  "sql_feature_start": 2,
  "api_feature_start": 2
}
```

### 场景3：用户ID+产品ID+日期作为主键（三列）
```json
{
  "name": "用户产品日期特征对比",
  "sql_key_column": [0, 1, 2],
  "api_key_column": [0, 1, 2],
  "sql_feature_start": 3,
  "api_feature_start": 3
}
```

## 测试验证

运行测试脚本验证功能：
```bash
cd data_comparison
python test_multi_key.py
```

测试覆盖：
- ✅ 单列主键格式识别
- ✅ 多列主键格式识别
- ✅ 主键组合逻辑
- ✅ 主键验证逻辑

## 兼容性

### 向后兼容
- ✅ 原有单列主键配置完全兼容
- ✅ 现有配置文件无需修改即可继续使用
- ✅ 输出文件格式保持一致

### 升级建议
- 无需强制升级
- 如需使用多列主键，按文档修改配置即可
- 建议先在测试环境验证

## 注意事项

1. **主键列数一致**：sql_key_column 和 api_key_column 的列数必须相同
2. **特征起始位置**：使用多列主键时，特征起始位置应在主键列之后
3. **主键值完整性**：任一主键列为空会导致该行被标记为不匹配
4. **分隔符**：多列主键使用 `||` 分隔，避免在主键值中使用此字符

## 性能影响

- ✅ 无性能下降
- ✅ 仍使用O(1)字典查找
- ✅ 内存使用无明显增加

## 后续计划

- [ ] Web界面支持多列主键配置
- [ ] 支持自定义主键分隔符
- [ ] 添加主键列自动检测功能

## 文档资源

- [多列主键快速参考](MULTI_KEY_QUICK_REFERENCE.md)
- [多列主键详细说明](MULTI_KEY_UPDATE.md)
- [配置指南](CONFIG_GUIDE.md)
- [README](README.md)

## 反馈与支持

如遇到问题或有改进建议，请联系开发团队。

---
**更新人员**: Kiro AI Assistant  
**更新日期**: 2026-03-05  
**版本**: v2.0.0
