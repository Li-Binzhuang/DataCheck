# 合并表格数据模块修复说明

## 问题1：横向合并功能不工作（已修复）

### 问题描述
用户反馈：选择多个文件后横向合并，点击"执行合并"没有反应，没有生成合并文件。

### 问题原因
后端代码 `web/routes/merge_csv_routes.py` 中缺少横向合并时的重复列处理逻辑。

### 修复内容
详见原文档内容...

## 问题2：点击"执行合并"按钮报错（已修复）

### 问题描述
点击"执行合并"按钮后，浏览器控制台报错：
```
TypeError: Cannot set properties of null (setting 'className')
```
功能无法执行。

### 问题原因
`merge-csv.js` 中使用的函数调用方式与项目中其他模块不一致：

1. **函数参数顺序错误**：
   - 项目标准：`updateStatus(status, text, tab)`
   - merge-csv.js：`updateStatus(pageId, status, text)` ❌

2. **使用了不存在的函数**：
   - 使用了 `addOutputLine()` 函数，但项目中实际是 `appendOutput()`
   - 参数顺序也不匹配

3. **自定义了重复的函数**：
   - 自定义了 `showAlert()` 函数，但参数顺序与 `pkl.js` 中的标准版本不同

### 修复内容

#### 1. 修正 updateStatus 调用
```javascript
// 修改前
updateStatus('merge-csv', 'running', '正在合并文件...');
updateStatus('merge-csv', 'success', '合并完成');
updateStatus('merge-csv', 'error', '合并失败');

// 修改后
updateStatus('running', '正在合并文件...', 'merge-csv');
updateStatus('success', '合并完成', 'merge-csv');
updateStatus('error', '合并失败', 'merge-csv');
```

#### 2. 替换 addOutputLine 为 appendOutput
```javascript
// 修改前
addOutputLine('merge-csv', '✅ 合并成功！', 'success');
addOutputLine('merge-csv', `输出文件: ${result.output_file}`, 'info');

// 修改后
appendOutput('✅ 合并成功！', 'success', 'merge-csv');
appendOutput(`输出文件: ${result.output_file}`, 'info', 'merge-csv');
```

#### 3. 修正 showAlert 调用并删除自定义版本
```javascript
// 修改前
showAlert('merge-csv', '请至少选择2个CSV文件进行合并', 'error');

// 修改后
showAlert('请至少选择2个CSV文件进行合并', 'error', 'merge-csv');
```

删除了 `merge-csv.js` 中自定义的 `showAlert` 函数，使用 `pkl.js` 中的标准版本。

### 函数签名参考

项目中的标准函数签名（来自 `api-compare.js` 和 `pkl.js`）：

```javascript
// 状态更新
updateStatus(status, text, tab = 'api')

// 输出信息
appendOutput(message, type = 'output', tab = 'api')

// 清空输出
clearOutput(tab = 'api')

// 显示警告
showAlert(message, type, tab = 'api')
```

## 修复时间

- 问题1修复：2024-03-09
- 问题2修复：2024-03-09

## 相关文件

- `web/routes/merge_csv_routes.py` - 后端路由（已修复）
- `static/js/merge-csv.js` - 前端逻辑（已修复）
- `test_merge_csv_fix.py` - 测试脚本（已删除）
- `MERGE_CSV_FEATURE.md` - 功能文档

### 1. 后端修复 (web/routes/merge_csv_routes.py)

添加了完整的重复列处理逻辑：

```python
# 获取横向合并的额外参数
remove_duplicates = request.form.get('remove_duplicates', 'false').lower() == 'true'
duplicate_columns = request.form.get('duplicate_columns', '').strip()

# 横向合并时处理重复列
if merge_mode == 'horizontal' and remove_duplicates and len(dataframes) > 1:
    first_df = dataframes[0]
    processed_dfs = [first_df]
    removed_columns = []
    
    # 确定要检查的列名
    if duplicate_columns:
        # 使用指定的列名
        columns_to_check = [col.strip() for col in duplicate_columns.split(',')]
    else:
        # 自动检测：使用第一个文件的所有列名
        columns_to_check = first_df.columns.tolist()
    
    # 处理后续的每个DataFrame
    for df in dataframes[1:]:
        # 找出重复列
        duplicate_cols = [col for col in df.columns if col in columns_to_check]
        
        if duplicate_cols:
            # 移除重复列
            df_cleaned = df.drop(columns=duplicate_cols)
            removed_columns.extend(duplicate_cols)
            processed_dfs.append(df_cleaned)
        else:
            processed_dfs.append(df)
    
    # 合并处理后的DataFrames
    merged_df = pd.concat(processed_dfs, axis=1)
    
    # 返回移除的列信息
    if removed_columns:
        response_data['removed_columns'] = list(set(removed_columns))
```

### 2. 前端修复 (static/js/merge-csv.js)

修正布尔值参数的发送格式：

```javascript
// 修改前
formData.append('remove_duplicates', removeDuplicates);

// 修改后
formData.append('remove_duplicates', removeDuplicates ? 'true' : 'false');
```

## 功能说明

### 横向合并 - 自动移除重复列

当勾选"自动移除重复列"时：

1. 保留第一个文件的所有列
2. 从第2、3、4...个文件中移除与第一个文件重复的列
3. 最终合并所有处理后的文件

**示例：**
```
文件1: user_id, name, age
文件2: user_id, feature1, feature2
文件3: user_id, feature3, feature4

结果: user_id, name, age, feature1, feature2, feature3, feature4
说明: 文件2和文件3的user_id列被自动移除
```

### 横向合并 - 指定移除列名

在"指定重复列名"输入框中填写列名（逗号分隔）：

1. 只检查指定的列名
2. 从第2、3、4...个文件中移除这些指定的列
3. 其他重复列保留（pandas会自动添加后缀）

**示例：**
```
指定列名: user_id,order_id

文件1: user_id, order_id, amount
文件2: user_id, order_id, feature1
文件3: user_id, order_id, feature2

结果: user_id, order_id, amount, feature1, feature2
说明: 只移除指定的user_id和order_id列
```

## 测试验证

创建了测试脚本 `test_merge_csv_fix.py`，验证了以下场景：

1. ✅ 横向合并 - 自动移除重复列
2. ✅ 横向合并 - 指定移除列名
3. ✅ 纵向合并

所有测试通过，功能正常。

## 使用步骤

1. 在左侧菜单点击"小工具集合" → "合并表格文件"
2. 选择多个CSV文件（按住Ctrl或Cmd多选）
3. 选择"横向合并（追加列）"
4. 勾选"自动移除重复列"
5. 可选：在"指定重复列名"中填写要移除的列名（如 `user_id,order_id`）
6. 输入输出文件名
7. 点击"执行合并"
8. 等待处理完成，文件会自动下载

## 修复时间

2024-03-09

## 相关文件

- `web/routes/merge_csv_routes.py` - 后端路由（已修复）
- `static/js/merge-csv.js` - 前端逻辑（已修复）
- `test_merge_csv_fix.py` - 测试脚本（新增）
- `MERGE_CSV_FEATURE.md` - 功能文档
