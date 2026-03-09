# XLSX前端验证修复说明

## 问题描述

用户上传.xlsx文件时，前端JavaScript代码中的文件验证逻辑阻止了文件上传，显示"只支持CSV和PKL文件"的错误提示。

虽然HTML的`accept`属性已经更新为支持.xlsx，但JavaScript中的文件名验证代码没有同步更新。

## 修复内容

### 修改的文件

更新了以下JavaScript文件中的文件验证逻辑：

#### 1. static/js/api-compare.js (接口数据对比)
**函数**: `handleFileSelect(scenarioId, input)`

**修改前**:
```javascript
// 支持CSV和PKL文件
if (!file.name.endsWith('.csv') && !file.name.endsWith('.pkl')) {
    showAlert('只支持CSV和PKL文件', 'error', 'api');
    input.value = '';
    return;
}
```

**修改后**:
```javascript
// 支持CSV、PKL和XLSX文件
if (!file.name.endsWith('.csv') && !file.name.endsWith('.pkl') && !file.name.endsWith('.xlsx') && !file.name.endsWith('.xls')) {
    showAlert('只支持CSV、PKL和XLSX文件', 'error', 'api');
    input.value = '';
    return;
}
```

同时更新了上传提示信息，显示XLSX文件将自动转换为CSV。

#### 2. static/js/online.js (线上灰度落数对比)
**函数1**: `handleOnlineFileSelect(fileType, input)`

**修改前**:
```javascript
if (!file.name.endsWith('.csv')) {
    showAlert('只支持CSV文件', 'error', 'online');
    input.value = '';
    return;
}
```

**修改后**:
```javascript
if (!file.name.endsWith('.csv') && !file.name.endsWith('.xlsx') && !file.name.endsWith('.xls')) {
    showAlert('只支持CSV和XLSX文件', 'error', 'online');
    input.value = '';
    return;
}
```

**函数2**: `handleOnlineScenarioFileSelect(scenarioId, fileType, input)`

**修改前**:
```javascript
// 支持CSV和PKL文件
if (!file.name.endsWith('.csv') && !file.name.endsWith('.pkl')) {
    showAlert('只支持CSV和PKL文件', 'error', 'online');
    input.value = '';
    return;
}
```

**修改后**:
```javascript
// 支持CSV、PKL和XLSX文件
if (!file.name.endsWith('.csv') && !file.name.endsWith('.pkl') && !file.name.endsWith('.xlsx') && !file.name.endsWith('.xls')) {
    showAlert('只支持CSV、PKL和XLSX文件', 'error', 'online');
    input.value = '';
    return;
}
```

#### 3. static/js/data-compare.js (数据对比)
**函数1**: `handleCompareFileSelect(fileNum, input)`

**修改前**:
```javascript
if (!file.name.endsWith('.csv') && !file.name.endsWith('.xlsx')) {
    showAlert('只支持CSV和XLSX文件', 'error', 'compare');
    input.value = '';
    return;
}
```

**修改后**:
```javascript
if (!file.name.endsWith('.csv') && !file.name.endsWith('.xlsx') && !file.name.endsWith('.xls')) {
    showAlert('只支持CSV和XLSX文件', 'error', 'compare');
    input.value = '';
    return;
}
```

**函数2**: `handleDecimalFileSelect(input)` (小数处理工具)

**修改前**:
```javascript
if (!file.name.endsWith('.csv')) {
    showAlert('只支持CSV文件', 'error', 'compare');
    input.value = '';
    return;
}
```

**修改后**:
```javascript
if (!file.name.endsWith('.csv') && !file.name.endsWith('.xlsx') && !file.name.endsWith('.xls')) {
    showAlert('只支持CSV和XLSX文件', 'error', 'compare');
    input.value = '';
    return;
}
```

### 修改总结

- 更新了5个文件验证函数
- 添加了对 `.xlsx` 和 `.xls` 文件扩展名的支持
- 更新了错误提示信息
- 添加了XLSX文件转换提示

## 支持的文件格式

现在所有模块的前端验证都支持：
- `.csv` - CSV文件
- `.xlsx` - Excel 2007+格式
- `.xls` - Excel 97-2003格式
- `.pkl` - Pickle文件（部分模块）

## 用户体验改进

1. **上传提示**: 当用户上传XLSX或PKL文件时，会显示"(将自动转换为CSV)"提示
2. **错误提示**: 更新了错误提示信息，明确告知支持的文件格式
3. **文件大小显示**: 保留了文件大小显示功能

## 测试建议

1. 清除浏览器缓存
2. 强制刷新页面（Ctrl+F5 或 Cmd+Shift+R）
3. 尝试上传.xlsx文件
4. 验证文件上传成功并自动转换为CSV

## 更新日期

2024-03-09
