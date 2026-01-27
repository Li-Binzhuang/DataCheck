# PKL文件上传功能说明

## 功能概述

MyDataCheck项目现在支持上传`.pkl`文件，系统会自动将其转换为`.csv`文件用于数据对比。

## 支持的文件类型

- **CSV文件** (`.csv`) - 直接使用
- **PKL文件** (`.pkl`) - 自动转换为CSV后使用

## 使用方法

### 1. 接口数据对比

1. 在"接口数据对比"标签页中
2. 点击"输入CSV/PKL文件"的文件选择按钮
3. 选择`.pkl`或`.csv`文件
4. 如果是PKL文件，系统会自动转换并显示：`✓ PKL已转换: 原文件名.pkl → 转换后文件名.csv`
5. 转换后的CSV文件会自动保存到`inputdata/api_comparison/`目录

### 2. 线上灰度落数对比

1. 在"线上灰度落数对比"标签页中
2. 在"离线文件"或"线上文件"处点击文件选择按钮
3. 选择`.pkl`或`.csv`文件
4. PKL文件会自动转换为CSV格式
5. 转换后的CSV文件会自动保存到`inputdata/online_comparison/`目录

## PKL文件要求

PKL文件应包含以下数据类型之一：

1. **pandas DataFrame** - 最佳选择，直接转换
2. **字典 (dict)** - 会尝试转换为DataFrame
3. **列表 (list)** - 会尝试转换为DataFrame
4. **其他对象** - 会尝试包装为DataFrame

## 转换逻辑

```python
# 读取PKL文件
with open(pkl_file, 'rb') as f:
    data = pickle.load(f)

# 根据数据类型转换
if isinstance(data, pd.DataFrame):
    df = data  # 直接使用
elif isinstance(data, dict):
    df = pd.DataFrame(data)  # 字典转DataFrame
elif isinstance(data, list):
    df = pd.DataFrame(data)  # 列表转DataFrame
else:
    df = pd.DataFrame([data])  # 其他类型包装

# 保存为CSV
df.to_csv(csv_file, index=False, encoding='utf-8')
```

## 文件存储位置

### 接口数据对比
- **上传目录**: `MyDataCheck/inputdata/api_comparison/`
- **PKL文件**: `原文件名.pkl`
- **转换后CSV**: `原文件名.csv`

### 线上灰度落数对比
- **上传目录**: `MyDataCheck/inputdata/online_comparison/`
- **PKL文件**: `原文件名.pkl`
- **转换后CSV**: `原文件名.csv`

## API接口

### 1. 上传文件（接口数据对比）

**端点**: `POST /api/upload`

**请求**:
```
Content-Type: multipart/form-data
file: <pkl或csv文件>
```

**响应**:
```json
{
  "success": true,
  "filename": "data.csv",
  "original_filename": "data.pkl",
  "converted": true,
  "message": "PKL文件已转换为CSV: data.csv"
}
```

### 2. 上传文件（线上灰度落数对比）

**端点**: `POST /api/upload/online`

**请求/响应**: 同上

### 3. 获取PKL文件信息

**端点**: `POST /api/pkl/info`

**请求**:
```json
{
  "filename": "data.pkl",
  "type": "api"  // 或 "online"
}
```

**响应**:
```json
{
  "success": true,
  "info": {
    "type": "DataFrame",
    "shape": [100, 10],
    "rows": 100,
    "cols": 10,
    "columns": ["col1", "col2", ...]
  }
}
```

## 注意事项

1. **文件大小**: 建议PKL文件不超过100MB
2. **数据格式**: PKL文件中的数据应该是表格型数据
3. **编码**: 转换后的CSV文件使用UTF-8编码
4. **索引**: 转换时不保存DataFrame的索引（`index=False`）
5. **覆盖**: 如果同名CSV文件已存在，会被覆盖

## 错误处理

如果PKL文件转换失败，会显示错误信息：

- `✗ 上传失败: PKL文件转换失败: <错误详情>`

常见错误原因：
1. PKL文件损坏或格式不正确
2. PKL文件包含无法转换为表格的数据类型
3. 内存不足（文件过大）
4. 权限问题（无法写入目标目录）

## 示例

### Python生成PKL文件示例

```python
import pandas as pd
import pickle

# 创建DataFrame
df = pd.DataFrame({
    'cust_no': ['800001054335', '800001054336'],
    'name': ['张三', '李四'],
    'amount': [1000.0, 2000.0]
})

# 保存为PKL文件
with open('data.pkl', 'wb') as f:
    pickle.dump(df, f)

# 或者直接使用pandas
df.to_pickle('data.pkl')
```

### 上传并使用

1. 在Web界面上传`data.pkl`
2. 系统自动转换为`data.csv`
3. 在配置中使用`data.csv`作为输入文件
4. 执行数据对比流程

## 更新日志

**版本**: 1.1.0  
**日期**: 2026-01-22  
**更新内容**:
- 新增PKL文件上传支持
- 自动转换PKL为CSV
- 更新Web界面提示信息
- 新增PKL文件信息查询API

---

**维护**: MyDataCheck开发团队  
**最后更新**: 2026-01-22
