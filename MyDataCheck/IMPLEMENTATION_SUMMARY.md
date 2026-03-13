# CSV 数据对比模块 - 列名前后缀匹配功能实现总结

## 功能概述

在 MyDataCheck 项目的 CSV 数据对比模块中，添加了列名前后缀匹配功能。当两个表格的列名存在前后缀差异时，用户可以通过指定列名前缀和后缀来自动匹配列名，无需手动修改文件。

## 实现范围

### 1. 前端界面修改

**文件**: `MyDataCheck/templates/index.html`

在 CSV 对比配置面板中添加了"列名匹配配置"部分：
- 列名前缀输入框
- 列名后缀输入框
- 配置说明和使用示例

### 2. 前端 JavaScript 修改

**文件**: `MyDataCheck/static/js/data-compare.js`

修改了以下函数：
- `executeCompare()`: 添加 `column_prefix` 和 `column_suffix` 参数到配置对象
- `saveCompareConfig()`: 保存列名前后缀配置到 `config.json`
- `loadCompareConfig()`: 从配置文件加载列名前后缀设置

### 3. 后端路由修改

**文件**: `MyDataCheck/web/routes/compare_routes.py`

修改了 `execute_compare_flow()` 函数：
- 从配置中提取 `column_prefix` 和 `column_suffix` 参数
- 将这些参数传递给数据对比函数

### 4. 核心对比逻辑修改

**文件**: `MyDataCheck/data_comparison/job/data_comparator.py`

修改了 `compare_two_files()` 函数：
- 添加 `column_prefix` 和 `column_suffix` 参数
- 实现列名前后缀匹配逻辑
- 优先级：直接匹配 > 前后缀匹配
- 添加详细的日志输出，显示匹配结果

## 工作原理

### 列名匹配流程

```
模型表列名: inst_telcel_scat_account_count_7d
                    ↓
            尝试直接匹配
                    ↓
        在接口表中查找相同列名
                    ↓
        如果未找到且启用了前后缀
                    ↓
        应用前后缀转换
                    ↓
前缀 + 列名 + 后缀 = local_all_sms_inst_telcel_scat_account_count_7d_v3
                    ↓
        在接口表中查找该列名
                    ↓
    如果找到 → 对比该列的数据
    如果未找到 → 该列标记为"匹配失败"
```

### 匹配优先级

1. **直接匹配**（优先级最高）：在接口表中查找与模型表列名完全相同的列
2. **前后缀匹配**（优先级次之）：如果直接匹配失败且配置了前后缀，则尝试带前后缀的匹配

这样设计可以确保即使配置了前后缀，也不会影响那些列名完全相同的列的匹配。

## 代码变更详情

### 1. 函数签名变更

```python
# 原始签名
def compare_two_files(
    sql_file_path: str,
    api_file_path: str,
    sql_key_column,
    api_key_column,
    sql_feature_start: int = 1,
    api_feature_start: int = 1,
    convert_feature_to_number: bool = True,
    ignore_default_fill: bool = False,
    ignore_decimal_diff: bool = False,
    decimal_threshold: float = 0.0001
):

# 新签名
def compare_two_files(
    sql_file_path: str,
    api_file_path: str,
    sql_key_column,
    api_key_column,
    sql_feature_start: int = 1,
    api_feature_start: int = 1,
    convert_feature_to_number: bool = True,
    ignore_default_fill: bool = False,
    ignore_decimal_diff: bool = False,
    decimal_threshold: float = 0.0001,
    column_prefix: str = '',
    column_suffix: str = ''
):
```

### 2. 特征映射逻辑

```python
# 预先构建接口文件特征名到索引的映射
api_feature_index = {feature: api_feature_start + idx for idx, feature in enumerate(feature_cols_api)}

# 以Sql文件为基准，构建特征映射
for idx, feature_sql in enumerate(feature_cols_sql):
    actual_sql_idx = sql_feature_start + idx
    
    # 首先尝试直接匹配
    actual_api_idx = api_feature_index.get(feature_sql)
    
    # 如果直接匹配失败且启用了前后缀，尝试带前后缀的匹配
    if actual_api_idx is None and (column_prefix or column_suffix):
        feature_with_affixes = f"{column_prefix}{feature_sql}{column_suffix}"
        actual_api_idx = api_feature_index.get(feature_with_affixes)
        if actual_api_idx is not None:
            print(f"  ✓ 列名匹配: '{feature_sql}' <- '{feature_with_affixes}'")
    
    feature_mapping[feature_sql] = (actual_api_idx, actual_sql_idx)
    all_features.append(feature_sql)
```

## 测试验证

### 测试文件

**文件**: `MyDataCheck/test_column_prefix_suffix.py`

创建了自动化测试脚本，验证功能正常工作：

1. **测试 1**：不使用前后缀（基准测试）
   - 模型表列名与接口表列名不匹配
   - 预期结果：一致率 33.33%（只有 `feature_c` 列匹配）

2. **测试 2**：使用前后缀匹配
   - 配置前缀：`local_all_sms_`
   - 配置后缀：`_v3`
   - 预期结果：一致率 100%（所有列都成功匹配）

### 测试结果

```
✓ 前后缀匹配功能正常工作！
  使用前后缀后，一致率从 33.33% 提升到 100.00%
```

## 使用指南

### 基本步骤

1. **上传文件**：上传或指定两个 CSV/XLSX 文件
2. **配置列名匹配**：
   - 填写列名前缀（可选）
   - 填写列名后缀（可选）
3. **执行对比**：点击"执行对比"按钮
4. **查看结果**：系统会自动匹配列名并进行对比

### 配置示例

#### 示例 1：仅有前缀

```
模型表列名: feature_a, feature_b
接口表列名: prefix_feature_a, prefix_feature_b

配置:
- 列名前缀: prefix_
- 列名后缀: (留空)
```

#### 示例 2：仅有后缀

```
模型表列名: feature_a, feature_b
接口表列名: feature_a_v2, feature_b_v2

配置:
- 列名前缀: (留空)
- 列名后缀: _v2
```

#### 示例 3：前后缀都有

```
模型表列名: feature_a, feature_b
接口表列名: api_feature_a_v3, api_feature_b_v3

配置:
- 列名前缀: api_
- 列名后缀: _v3
```

## 性能影响

- 前后缀匹配使用字典查找，时间复杂度为 O(1)
- 对整体对比性能的影响可以忽略不计
- 不会增加内存占用

## 向后兼容性

- 如果不填写前后缀，系统会使用原始列名进行精确匹配（默认行为）
- 现有的配置文件仍然可以正常使用
- 新增的参数都有默认值（空字符串），不会破坏现有功能

## 文档

- **用户指南**: `MyDataCheck/COLUMN_PREFIX_SUFFIX_GUIDE.md`
- **实现总结**: `MyDataCheck/IMPLEMENTATION_SUMMARY.md`（本文件）
- **测试脚本**: `MyDataCheck/test_column_prefix_suffix.py`

## 后续改进建议

1. **正则表达式支持**：支持使用正则表达式进行更复杂的列名匹配
2. **列名映射文件**：支持上传 CSV 文件来定义列名映射关系
3. **自动检测**：根据两个表格的列名自动建议前后缀配置
4. **批量配置**：支持为多个特征组定义不同的前后缀

## 总结

列名前后缀匹配功能已成功实现并通过测试。该功能：
- 提供了灵活的列名匹配方式
- 无需修改源文件即可处理列名差异
- 保持了向后兼容性
- 对性能没有显著影响
- 提供了详细的日志输出便于调试
