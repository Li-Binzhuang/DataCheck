# 数据对比配置说明

## 配置文件位置

`MyDataCheck/data_comparison/config.json`

## 配置结构

```json
{
  "scenarios": [
    {
      "name": "场景名称",
      "enabled": true,
      "description": "场景描述",
      "sql_file": "Sql文件名.csv",
      "api_file": "接口文件名.csv",
      "sql_key_column": 0,
      "api_key_column": 0,
      "sql_feature_start": 1,
      "api_feature_start": 1,
      "convert_feature_to_number": true,
      "output_prefix": "compare"
    }
  ],
  "global_config": {
    "default_convert_feature_to_number": true,
    "default_sql_key_column": 0,
    "default_api_key_column": 0,
    "default_sql_feature_start": 1,
    "default_api_feature_start": 1
  }
}
```

## 字段说明

### scenarios（场景列表）

每个场景包含以下字段：

- **name**：场景名称（必填）
- **enabled**：是否启用该场景（true/false）
- **description**：场景描述（可选）
- **sql_file**：Sql文件名（必填，文件应放在`inputdata/data_comparison/`目录）
- **api_file**：接口文件名（必填，文件应放在`inputdata/data_comparison/`目录）
- **sql_key_column**：Sql文件的主键列索引（从0开始，A列=0，B列=1...）
- **api_key_column**：接口文件的主键列索引（从0开始）
- **sql_feature_start**：Sql文件特征列起始索引（从0开始）
- **api_feature_start**：接口文件特征列起始索引（从0开始）
- **convert_feature_to_number**：是否转换特征值为数值（true/false）
- **output_prefix**：输出文件前缀

### global_config（全局默认配置）

全局配置会作为场景的默认值：

- **default_convert_feature_to_number**：默认是否转换特征值为数值
- **default_sql_key_column**：默认Sql文件主键列索引
- **default_api_key_column**：默认接口文件主键列索引
- **default_sql_feature_start**：默认Sql文件特征起始列索引
- **default_api_feature_start**：默认接口文件特征起始列索引

## 使用方式

### 1. 通过Web界面

1. 在Web界面的"数据对比"页面配置参数
2. 点击"💾 保存配置"按钮保存当前配置
3. 点击"📂 加载配置"按钮加载已保存的配置

### 2. 手动编辑配置文件

直接编辑`config.json`文件，然后：
- 在Web界面点击"📂 加载配置"
- 或使用命令行执行：`python execute_data_comparison.py`

### 3. 命令行执行

```bash
cd MyDataCheck/data_comparison
python execute_data_comparison.py
```

脚本会自动读取`config.json`并执行所有启用的场景。

## 配置示例

### 示例1：基本配置

```json
{
  "scenarios": [
    {
      "name": "基本对比",
      "enabled": true,
      "description": "对比Sql文件和接口文件",
      "sql_file": "sql_data.csv",
      "api_file": "api_data.csv",
      "sql_key_column": 0,
      "api_key_column": 0,
      "sql_feature_start": 1,
      "api_feature_start": 1,
      "convert_feature_to_number": true,
      "output_prefix": "basic_compare"
    }
  ],
  "global_config": {
    "default_convert_feature_to_number": true,
    "default_sql_key_column": 0,
    "default_api_key_column": 0,
    "default_sql_feature_start": 1,
    "default_api_feature_start": 1
  }
}
```

### 示例2：多场景配置

```json
{
  "scenarios": [
    {
      "name": "场景1-用户特征对比",
      "enabled": true,
      "description": "对比用户特征数据",
      "sql_file": "user_features_sql.csv",
      "api_file": "user_features_api.csv",
      "sql_key_column": 0,
      "api_key_column": 0,
      "sql_feature_start": 2,
      "api_feature_start": 2,
      "convert_feature_to_number": true,
      "output_prefix": "user_features"
    },
    {
      "name": "场景2-订单特征对比",
      "enabled": true,
      "description": "对比订单特征数据",
      "sql_file": "order_features_sql.csv",
      "api_file": "order_features_api.csv",
      "sql_key_column": 1,
      "api_key_column": 1,
      "sql_feature_start": 3,
      "api_feature_start": 3,
      "convert_feature_to_number": true,
      "output_prefix": "order_features"
    }
  ],
  "global_config": {
    "default_convert_feature_to_number": true,
    "default_sql_key_column": 0,
    "default_api_key_column": 0,
    "default_sql_feature_start": 1,
    "default_api_feature_start": 1
  }
}
```

## 输出文件

执行对比后，会在`outputdata/data_comparison/`目录生成以下文件：

- `{output_prefix}_{时间戳}_差异特征汇总.csv`
- `{output_prefix}_{时间戳}_差异数据明细.csv`
- `{output_prefix}_{时间戳}_特征统计.csv`
- `{output_prefix}_{时间戳}_全量数据合并.csv`
- `{output_prefix}_{时间戳}_仅在接口文件中的数据.csv`（如果有）
- `{output_prefix}_{时间戳}_仅在Sql文件中的数据.csv`（如果有）

时间戳格式：`月日时分`（如：01262130）

## 注意事项

1. **文件路径**：所有输入文件必须放在`inputdata/data_comparison/`目录
2. **列索引**：列索引从0开始（A列=0，B列=1，C列=2...）
3. **特征转换**：启用`convert_feature_to_number`会自动去除引号并尝试转换为数值
4. **主键匹配**：对比时会根据主键列的值进行匹配
5. **配置保存**：Web界面保存配置时会覆盖现有配置文件

## 常见问题

### Q: 如何指定主键列？
A: 使用`sql_key_column`和`api_key_column`指定列索引（从0开始）

### Q: 如何跳过某些列？
A: 使用`sql_feature_start`和`api_feature_start`指定特征列的起始位置

### Q: 配置文件在哪里？
A: `MyDataCheck/data_comparison/config.json`

### Q: 如何禁用某个场景？
A: 将场景的`enabled`字段设置为`false`

### Q: 输出文件在哪里？
A: `MyDataCheck/outputdata/data_comparison/`

---

**更新时间**：2026-01-26
