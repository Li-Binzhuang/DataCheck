# 侧边栏菜单切换问题修复指南

## 问题描述
点击左侧菜单栏无法切换页面

## 已修复内容

### 1. 添加switchPage函数
在JavaScript中添加了正确的`switchPage`函数，用于处理侧边栏菜单的点击事件。

### 2. 添加调试日志
在函数中添加了console.log，方便在浏览器控制台查看执行情况。

### 3. 修复event对象引用
添加了对event对象的检查，避免undefined错误。

## 测试步骤

### 1. 重启Web服务
```bash
cd MyDataCheck
./stop_web.sh
./start_web.sh
```

### 2. 打开浏览器
访问：http://localhost:5000

### 3. 打开开发者工具
- Chrome/Edge: F12 或 Cmd+Option+I (Mac)
- 查看Console标签

### 4. 测试菜单切换
点击左侧菜单项，观察：
- 页面是否切换
- Console中的日志输出

### 预期日志输出
```
switchPage called with: api
Hiding section: page-api
Hiding section: page-online
Hiding section: page-compare
Hiding section: page-pkl
Showing page: page-api
Menu item activated
```

## 如果仍然无法切换

### 检查1：浏览器缓存
清除浏览器缓存：
- Chrome: Cmd+Shift+Delete (Mac) 或 Ctrl+Shift+Delete (Windows)
- 选择"缓存的图片和文件"
- 点击"清除数据"

### 检查2：强制刷新
- Mac: Cmd+Shift+R
- Windows: Ctrl+Shift+R

### 检查3：查看Console错误
打开浏览器Console，查看是否有JavaScript错误。

### 检查4：验证HTML结构
在Console中执行：
```javascript
// 检查页面元素是否存在
console.log('page-api:', document.getElementById('page-api'));
console.log('page-online:', document.getElementById('page-online'));
console.log('page-compare:', document.getElementById('page-compare'));
console.log('page-pkl:', document.getElementById('page-pkl'));

// 检查菜单项
console.log('menu items:', document.querySelectorAll('.menu-item').length);
```

### 检查5：手动测试函数
在Console中执行：
```javascript
switchPage('online');
```

## 常见问题

### Q1: 点击菜单没有反应
**A**: 检查Console是否有错误，可能是JavaScript加载失败。

### Q2: 页面切换了但菜单没有高亮
**A**: 检查CSS中的.menu-item.active样式是否正确。

### Q3: 只有第一次点击有效
**A**: 可能是event对象的问题，已在代码中修复。

### Q4: Console显示"Page not found"
**A**: 检查HTML中的页面ID是否正确（应该是page-api, page-online等）。

## 备用方案

如果问题仍然存在，可以使用测试页面验证：

### 1. 访问测试页面
http://localhost:5000/test_menu.html

### 2. 如果测试页面正常
说明switchPage函数本身没问题，可能是：
- CSS样式问题
- HTML结构问题
- 其他JavaScript冲突

### 3. 如果测试页面也不正常
说明是浏览器或服务器问题：
- 清除缓存
- 重启浏览器
- 重启Web服务

## 代码位置

### JavaScript函数
文件：`MyDataCheck/templates/index.html`
位置：`<script>`标签开始处（约第741行）

### HTML菜单
文件：`MyDataCheck/templates/index.html`
位置：`.sidebar-menu`部分（约第495行）

### 页面内容
文件：`MyDataCheck/templates/index.html`
位置：`.main-content`部分（约第517行）

## 联系支持

如果以上方法都无法解决问题，请提供：
1. 浏览器Console的完整错误信息
2. 浏览器类型和版本
3. 操作系统信息

---

**修复时间**: 2026-01-26
**修复内容**: 添加switchPage函数和调试日志
**状态**: ✅ 已修复
