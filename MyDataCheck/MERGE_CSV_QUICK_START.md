# CSV合并功能 - 快速开始

## 🚀 立即开始

### 1. 重启服务器
```bash
# 停止当前服务器（Ctrl+C）
python web_app.py
```

### 2. 清除浏览器缓存
按 F12 → 右键刷新按钮 → "清空缓存并硬性重新加载"

### 3. 生成测试文件
```bash
python test_merge_new.py
```

### 4. 开始测试

## 📋 测试场景

### 场景1: 纵向合并（追加行）

**文件**: `vertical_test1.csv` + `vertical_test2.csv`

**操作步骤**:
1. 选择2个文件
2. 选择"纵向合并（追加行）"
3. 点击"执行合并"

**预期结果**:
- 200行，4列
- 列名：user_id, name, age, city
- 列名只出现一次（第一行）

### 场景2: 横向合并（按主键）

**文件**: `horizontal_test1.csv` + `horizontal_test2.csv` + `horizontal_test3.csv`

**操作步骤**:
1. 选择3个文件
2. 选择"横向合并（追加列）"
3. 主键列输入：`user_id`
4. 点击"执行合并"

**预期结果**:
- 100行，7列
- 列名：user_id, name, age, order_count, total_amount, points, level
- user_id列只保留一次
- 显示：已移除重复列 (2个): user_id_dup1, user_id_dup2

### 场景3: 大文件测试（20万行）

**生成文件**:
```bash
python test_merge_new.py large
```

**操作步骤**:
1. 选择 `large_vertical1.csv` + `large_vertical2.csv`
2. 选择"纵向合并（追加行）"
3. 点击"执行合并"
4. 观察实时进度

**预期结果**:
- 200,000行，4列
- 实时显示处理进度
- 处理时间：10-20秒

## ✅ 功能验证清单

- [ ] 纵向合并：列名只保留一次
- [ ] 纵向合并：后续文件从第二行开始追加
- [ ] 横向合并：按主键正确匹配
- [ ] 横向合并：自动移除重复列
- [ ] 大文件：实时进度更新
- [ ] 大文件：不会内存溢出
- [ ] 下载：自动下载合并结果

## 🎯 核心功能

### 纵向合并
- 列结构相同
- 只保留第一个文件的列名
- 后续文件跳过表头追加数据
- 支持大文件分块处理

### 横向合并
- 按主键列匹配合并
- 自动移除重复列
- 支持多个主键列（逗号分隔）
- 无主键时直接拼接

## 📊 测试数据说明

### vertical_test1.csv
```csv
user_id,name,age,city
1,User_1,21,Beijing
2,User_2,22,Shanghai
...
100,User_100,70,Shenzhen
```

### vertical_test2.csv
```csv
user_id,name,age,city
101,User_101,21,Beijing
102,User_102,22,Shanghai
...
200,User_200,70,Shenzhen
```

### horizontal_test1.csv
```csv
user_id,name,age
1,User_1,21
2,User_2,22
...
```

### horizontal_test2.csv
```csv
user_id,order_count,total_amount
1,1,110
2,2,120
...
```

### horizontal_test3.csv
```csv
user_id,points,level
1,5,Level_1
2,10,Level_2
...
```

## 🔧 故障排查

### 问题：点击按钮没反应
- 检查是否重启了服务器
- 检查是否清除了浏览器缓存
- 按F12查看控制台错误

### 问题：进度不更新
- 检查浏览器控制台是否显示"响应类型: text/event-stream"
- 检查服务器日志是否有错误

### 问题：合并结果不对
- 纵向合并：检查所有文件列名是否完全一致
- 横向合并：检查主键列名是否正确
- 打开下载的文件验证结果

## 📝 使用提示

1. **纵向合并**：适合合并多个结构相同的数据文件
2. **横向合并**：适合合并同一批数据的不同维度信息
3. **主键列**：横向合并时建议指定主键，确保数据正确匹配
4. **大文件**：纵向合并支持百万级数据，横向合并建议单文件<100MB
5. **文件编码**：建议使用UTF-8编码，避免乱码

## 🎉 完成！

功能已完全按照新需求实现，现在可以正常使用了！
