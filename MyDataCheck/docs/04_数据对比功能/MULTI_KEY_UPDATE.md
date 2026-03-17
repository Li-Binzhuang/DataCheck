# 多列主键支持更新说明

## 更新内容

数据对比模块现已支持单列或多列组合主键，可以灵活配置主键列数量。

## 主要变更

### 1. 配置格式

主键列配置 `sql_key_column` 和 `api_key_column` 现在支持两种格式：

- **单列主键**：使用数字
  ```json
  "sql_key_column": 0,
  "api_key_column": 0
  ```

- **多列主键**：使用数组
  ```json
  "sql_key_column": [0, 1],
  "api_key_column": [0, 1]
  ```

### 2. 主键组合方式

多列主键会使用 `||` 作为分隔符组合成唯一键，例如：
- 第1列值：`ABC`
- 第2列值：`123`
- 组合主键：`ABC||123`

### 3. 特征列起始位置

使用多列主键时，需要相应调整特征列起始位置：

```json
{
  "sql_key_column": [0, 1],      // 使用A列和B列作为主键
  "api_key_column": [0, 1],      // 使用A列和B列作为主键
  "sql_feature_start": 2,        // 特征从C列开始（索引2）
  "api_feature_start": 2         // 特征从C列开始（索引2）
}
```

## 配置示例

### 示例1：单列主键（原有方式）

```json
{
  "scenarios": [
    {
      "name": "单列主键对比",
      "enabled": true,
      "description": "使用A列作为主键",
      "sql_file": "sql_data.csv",
      "api_file": "api_data.csv",
      "sql_key_column": 0,
      "api_key_column": 0,
      "sql_feature_start": 1,
      "api_feature_start": 1,
      "convert_feature_to_number": true,
      "output_prefix": "single_key"
    }
  ]
}
```

### 示例2：双列主键

```json
{
  "scenarios": [
    {
      "name": "双列主键对比",
      "enabled": true,
      "description": "使用A列+B列作为组合主键",
      "sql_file": "sql_data.csv",
      "api_file": "api_data.csv",
      "sql_key_column": [0, 1],
      "api_key_column": [0, 1],
      "sql_feature_start": 2,
      "api_feature_start": 2,
      "convert_feature_to_number": true,
      "output_prefix": "dual_key"
    }
  ]
}
```

### 示例3：三列主键

```json
{
  "scenarios": [
    {
      "name": "三列主键对比",
      "enabled": true,
      "description": "使用A列+B列+C列作为组合主键",
      "sql_file": "sql_data.csv",
      "api_file": "api_data.csv",
      "sql_key_column": [0, 1, 2],
      "api_key_column": [0, 1, 2],
      "sql_feature_start": 3,
      "api_feature_start": 3,
      "convert_feature_to_number": true,
      "output_prefix": "triple_key"
    }
  ]
}
```

## 使用方法

### 方法1：通过Web界面（待更新）

Web界面将在后续版本中支持多列主键配置。

### 方法2：手动编辑配置文件

1. 编辑 `data_comparison/config.json`
2. 修改 `sql_key_column` 和 `api_key_column` 为数组格式
3. 调整 `sql_feature_start` 和 `api_feature_start` 的值
4. 保存配置文件

### 方法3：命令行执行

```bash
cd data_comparison
python execute_data_comparison.py
```

## 输出文件

输出文件格式保持不变，主键值会显示为组合后的字符串（使用 `||` 分隔）：

- `{output_prefix}_{时间戳}_差异特征汇总.csv`
- `{output_prefix}_{时间戳}_差异数据明细.csv`
- `{output_prefix}_{时间戳}_特征统计.csv`
- `{output_prefix}_{时间戳}_全量数据合并.csv`（可选）
- `{output_prefix}_{时间戳}_仅在接口灰度从库中的数据.csv`（如有）
- `{output_prefix}_{时间戳}_仅在模型特征表中的数据.csv`（如有）

## 注意事项

1. **列索引从0开始**：A列=0，B列=1，C列=2，以此类推

2. **主键列数量必须一致**：`sql_key_column` 和 `api_key_column` 的列数必须相同
   ```json
   // ✅ 正确
   "sql_key_column": [0, 1],
   "api_key_column": [0, 1]
   
   // ❌ 错误
   "sql_key_column": [0, 1],
   "api_key_column": [0]
   ```

3. **特征起始位置**：使用多列主键时，特征起始位置应该在主键列之后
   ```json
   // 使用A列和B列作为主键
   "sql_key_column": [0, 1],
   "sql_feature_start": 2  // 特征从C列开始
   ```

4. **主键值不能为空**：任何一列的主键值为空时，该行数据会被标记为"仅在XX文件中"

5. **向后兼容**：原有的单列主键配置（数字格式）仍然完全支持

## 技术细节

### 代码变更

1. **data_comparator.py**
   - 支持单列和多列主键参数
   - 使用 `||` 分隔符组合多列主键值
   - 构建索引时处理多列主键

2. **report_generator.py**
   - 更新全量数据合并逻辑以支持多列主键
   - 主键值显示为组合后的字符串

3. **CONFIG_GUIDE.md**
   - 添加多列主键配置说明和示例

### 性能影响

多列主键不会影响对比性能，仍然使用O(1)的字典查找。

## 示例配置文件

完整的配置示例请参考：
- `config_example_multi_key.json` - 包含单列、双列、三列主键的示例

## 常见问题

### Q: 如何从单列主键迁移到多列主键？

A: 只需修改配置文件：
```json
// 原配置
"sql_key_column": 0,
"sql_feature_start": 1

// 改为
"sql_key_column": [0, 1],
"sql_feature_start": 2
```

### Q: 主键列可以不连续吗？

A: 可以，例如使用A列和D列：
```json
"sql_key_column": [0, 3],  // A列和D列
"sql_feature_start": 1     // 特征从B列开始
```

### Q: 最多支持几列主键？

A: 理论上没有限制，但建议不超过5列以保持可读性。

### Q: 如何在输出文件中区分主键列？

A: 输出文件中主键值会使用 `||` 分隔，例如 `ABC||123||XYZ`

---

**更新时间**：2026-03-05
**版本**：v2.0
