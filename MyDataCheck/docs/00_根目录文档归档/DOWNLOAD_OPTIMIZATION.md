# 文件下载逻辑优化说明

## 优化目标

解决所有模块的文件下载重复问题：
- 如果上次已下载完成，刷新页面不提示下载，不重复下载
- 如果上次未下载完成，刷新页面提示下载

## 优化方案

### 1. 核心机制

使用 `localStorage` 记录下载历史，实现跨页面刷新的下载状态追踪。

### 2. 涉及模块

所有使用自动下载功能的模块：
- ✅ API对比模块 (`api_comparison`)
- ✅ 线上灰度对比模块 (`online_comparison`)
- ✅ 数据对比模块 (`data_comparison`)
- ✅ 批量运行模块 (`batch_run`)
- ✅ 任务通知模块 (task notifications)

### 3. 实现细节

#### 3.1 文件下载记录 (`auto-download.js`)

**新增功能：**

1. **下载历史管理**
   ```javascript
   // localStorage key: 'myDataCheck_downloadHistory'
   // 数据结构: { "module:filename": { filename, module, downloadTime } }
   ```

2. **核心函数**
   - `getDownloadHistory()` - 获取下载历史
   - `markFileDownloaded(filename, module)` - 标记文件已下载
   - `isFileDownloaded(filename, module)` - 检查文件是否已下载
   - `cleanupDownloadHistory()` - 清理7天前的记录

3. **优化后的下载流程**
   ```javascript
   async function autoDownloadOutputFiles(module, minutes = 2) {
       // 1. 获取最近生成的文件列表
       // 2. 过滤掉已下载的文件
       // 3. 只下载未下载的文件
       // 4. 标记文件为已下载
       // 5. 清理过期记录
   }
   ```

#### 3.2 任务下载记录 (`task-notification.js`)

**新增功能：**

1. **任务下载历史管理**
   ```javascript
   // localStorage key: 'myDataCheck_downloadedTasks'
   // 数据结构: { "taskId": { taskId, downloadTime } }
   ```

2. **核心函数**
   - `getDownloadedTasks()` - 获取已下载任务列表
   - `markTaskDownloaded(taskId)` - 标记任务已下载
   - `isTaskDownloaded(taskId)` - 检查任务是否已下载
   - `cleanupTaskDownloadHistory()` - 清理30天前的记录

3. **优化后的任务检查流程**
   ```javascript
   async function checkCompletedTasks() {
       // 1. 获取已完成的任务
       // 2. 过滤掉已下载的任务
       // 3. 只提示未下载的任务
       // 4. 清理过期记录
   }
   ```

### 4. 使用场景

#### 场景1：任务执行完成后自动下载

```javascript
// 在任务完成时调用
setTimeout(() => autoDownloadOutputFiles('online_comparison', 2), 1000);
```

**行为：**
- 首次执行：下载所有文件，记录到localStorage
- 刷新页面：不会重复下载已下载的文件
- 新文件生成：只下载新文件

#### 场景2：页面刷新后检查未下载任务

```javascript
// 页面加载时调用
checkCompletedTasks();
```

**行为：**
- 首次完成：弹窗提示下载
- 下载后刷新：不再提示该任务
- 新任务完成：提示新任务

#### 场景3：手动下载最新文件

```javascript
// 用户手动触发
manualDownloadLatestFiles('api_comparison');
```

**行为：**
- 获取最近1小时的文件
- 过滤已下载的文件
- 只下载未下载的文件

### 5. 数据清理策略

#### 文件下载记录
- 保留时间：7天
- 清理时机：每次调用 `autoDownloadOutputFiles` 时
- 原因：文件下载记录较多，7天足够覆盖正常使用场景

#### 任务下载记录
- 保留时间：30天
- 清理时机：每次调用 `checkCompletedTasks` 时
- 原因：任务记录较少，保留更长时间便于追溯

### 6. 兼容性说明

#### 向后兼容
- 旧的 `NOTIFIED_TASKS_KEY` 不再使用，但不影响现有功能
- 新逻辑基于下载状态而非提醒状态，更准确

#### 浏览器支持
- 依赖 `localStorage`，所有现代浏览器均支持
- 如果 localStorage 不可用，降级为不记录（每次都下载）

### 7. 测试验证

#### 测试步骤

1. **测试自动下载**
   - 执行一个对比任务
   - 等待任务完成，观察自动下载
   - 刷新页面，确认不会重复下载

2. **测试任务通知**
   - 完成一个任务但不下载
   - 刷新页面，应该弹出下载提示
   - 点击下载后刷新，不应再提示

3. **测试新文件下载**
   - 执行第一个任务，下载文件
   - 执行第二个任务，生成新文件
   - 应该只下载新文件，不下载旧文件

4. **测试记录清理**
   - 修改系统时间到8天后
   - 执行任务，观察是否清理旧记录

#### 验证点

- ✅ 首次下载正常
- ✅ 刷新后不重复下载
- ✅ 新文件能正常下载
- ✅ 任务通知不重复
- ✅ 过期记录自动清理
- ✅ localStorage 数据结构正确

### 8. 调试方法

#### 查看下载历史
```javascript
// 在浏览器控制台执行
console.log(JSON.parse(localStorage.getItem('myDataCheck_downloadHistory')));
```

#### 查看任务下载记录
```javascript
// 在浏览器控制台执行
console.log(JSON.parse(localStorage.getItem('myDataCheck_downloadedTasks')));
```

#### 清空下载记录（用于测试）
```javascript
// 清空文件下载记录
localStorage.removeItem('myDataCheck_downloadHistory');

// 清空任务下载记录
localStorage.removeItem('myDataCheck_downloadedTasks');
```

#### 手动标记文件已下载
```javascript
// 在浏览器控制台执行
markFileDownloaded('test_file.csv', 'api_comparison');
```

### 9. 注意事项

1. **localStorage 容量限制**
   - 大多数浏览器限制为 5-10MB
   - 当前设计每条记录约100字节，可存储数万条记录
   - 定期清理确保不会超限

2. **跨标签页同步**
   - localStorage 在同域名下的所有标签页共享
   - 一个标签页下载后，其他标签页也能看到下载状态

3. **隐私模式**
   - 隐私模式下 localStorage 可能受限
   - 关闭浏览器后数据会清空

4. **多用户场景**
   - 当前实现基于浏览器，不区分用户
   - 如需区分用户，可在 key 中加入 userId

### 10. 未来优化方向

1. **服务端记录**
   - 将下载状态记录到服务端
   - 支持跨设备、跨浏览器同步

2. **下载进度追踪**
   - 记录下载进度，支持断点续传
   - 显示下载失败的文件

3. **批量操作**
   - 支持批量清除下载记录
   - 支持重新下载指定文件

4. **统计分析**
   - 统计下载次数、下载时间
   - 分析用户下载习惯

## 修改文件清单

1. ✅ `static/js/auto-download.js` - 文件下载逻辑优化
2. ✅ `static/js/task-notification.js` - 任务通知逻辑优化

## 影响范围

- 所有使用自动下载功能的模块
- 任务完成通知功能
- 不影响手动下载功能
- 不影响现有API接口

## 回滚方案

如果出现问题，可以通过以下方式回滚：

1. 恢复 `auto-download.js` 到优化前版本
2. 恢复 `task-notification.js` 到优化前版本
3. 清空用户的 localStorage 记录

```javascript
// 清空所有下载记录
localStorage.removeItem('myDataCheck_downloadHistory');
localStorage.removeItem('myDataCheck_downloadedTasks');
```
