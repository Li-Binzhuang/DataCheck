# 下载逻辑优化 - 快速指南

## 🎯 核心改进

**问题：** 刷新页面后重复下载文件

**解决方案：** 使用 localStorage 记录下载状态

## 📦 涉及文件

1. `static/js/auto-download.js` - 文件下载逻辑
2. `static/js/task-notification.js` - 任务通知逻辑

## 🔑 关键功能

### 文件下载记录

```javascript
// 标记文件已下载
markFileDownloaded('output.csv', 'api_comparison');

// 检查文件是否已下载
if (isFileDownloaded('output.csv', 'api_comparison')) {
    console.log('文件已下载，跳过');
}
```

### 任务下载记录

```javascript
// 标记任务已下载
markTaskDownloaded('task_123');

// 检查任务是否已下载
if (isTaskDownloaded('task_123')) {
    console.log('任务已下载，跳过提示');
}
```

## 🧪 测试方法

### 方法1：使用测试页面

1. 在浏览器中打开 `test_download_logic.html`
2. 测试各种场景
3. 查看 localStorage 数据

### 方法2：浏览器控制台

```javascript
// 查看文件下载记录
console.log(JSON.parse(localStorage.getItem('myDataCheck_downloadHistory')));

// 查看任务下载记录
console.log(JSON.parse(localStorage.getItem('myDataCheck_downloadedTasks')));

// 清空所有记录（用于测试）
localStorage.removeItem('myDataCheck_downloadHistory');
localStorage.removeItem('myDataCheck_downloadedTasks');
```

## ✅ 验证清单

- [ ] 首次执行任务，文件正常下载
- [ ] 刷新页面，不会重复下载
- [ ] 执行新任务，新文件正常下载
- [ ] 任务完成提示不重复
- [ ] localStorage 数据正确

## 🔧 调试技巧

### 查看下载历史

```javascript
// 获取所有下载记录
const history = JSON.parse(localStorage.getItem('myDataCheck_downloadHistory'));
console.table(history);
```

### 模拟下载

```javascript
// 手动标记文件已下载
markFileDownloaded('test.csv', 'api_comparison');

// 验证
console.log(isFileDownloaded('test.csv', 'api_comparison')); // true
```

### 清理测试数据

```javascript
// 清空文件记录
localStorage.removeItem('myDataCheck_downloadHistory');

// 清空任务记录
localStorage.removeItem('myDataCheck_downloadedTasks');
```

## 📊 数据结构

### 文件下载记录

```json
{
  "api_comparison:output_12251430.csv": {
    "filename": "output_12251430.csv",
    "module": "api_comparison",
    "downloadTime": "2024-12-25T14:30:00.000Z"
  }
}
```

### 任务下载记录

```json
{
  "task_123456": {
    "taskId": "task_123456",
    "downloadTime": "2024-12-25T14:30:00.000Z"
  }
}
```

## 🗑️ 清理策略

- **文件记录：** 7天后自动清理
- **任务记录：** 30天后自动清理
- **触发时机：** 每次调用下载函数时

## ⚠️ 注意事项

1. **localStorage 限制**
   - 容量：5-10MB
   - 当前设计：可存储数万条记录

2. **隐私模式**
   - 关闭浏览器后数据清空
   - 需要重新下载

3. **跨标签页**
   - 同域名下所有标签页共享
   - 一个标签页下载，其他标签页也能看到

## 🚀 快速测试

```bash
# 1. 打开测试页面
open test_download_logic.html

# 2. 或在浏览器控制台执行
markFileDownloaded('test.csv', 'api_comparison');
console.log(isFileDownloaded('test.csv', 'api_comparison'));
```

## 📞 问题排查

### 问题1：刷新后还是重复下载

**检查：**
```javascript
// 查看是否有记录
console.log(localStorage.getItem('myDataCheck_downloadHistory'));
```

**解决：**
- 确认 localStorage 可用
- 检查浏览器是否禁用了 localStorage
- 查看是否在隐私模式

### 问题2：记录太多占用空间

**检查：**
```javascript
// 查看记录数量
const history = JSON.parse(localStorage.getItem('myDataCheck_downloadHistory'));
console.log('记录数:', Object.keys(history).length);
```

**解决：**
```javascript
// 手动清理
cleanupDownloadHistory();
```

### 问题3：需要重新下载某个文件

**解决：**
```javascript
// 删除特定文件的记录
const history = JSON.parse(localStorage.getItem('myDataCheck_downloadHistory'));
delete history['api_comparison:output.csv'];
localStorage.setItem('myDataCheck_downloadHistory', JSON.stringify(history));
```

## 📚 相关文档

- 详细说明：`DOWNLOAD_OPTIMIZATION.md`
- 测试工具：`test_download_logic.html`
