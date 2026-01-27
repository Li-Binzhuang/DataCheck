# MyDataCheck 快速参考

**版本**：v2.0  
**更新**：2026-01-27

---

## 🚀 快速启动

```bash
# 进入项目目录
cd MyDataCheck

# 启动Web服务
./start_web.sh

# 访问界面
open http://localhost:5000

# 停止服务
./stop_web.sh
```

---

## 📊 四大功能

### 1. 📡 接口数据对比
- 对比API返回数据与预期数据
- 支持多场景配置
- 支持动态参数
- 自动生成对比报告

### 2. 🌐 线上灰度落数对比
- 对比线上环境与灰度环境
- JSON数据解析
- 特征值对比
- 差异报告生成

### 3. 📊 数据对比
- CSV/XLSX文件对比
- 自定义主键列
- 特征值转换
- 详细差异报告

### 4. 📦 PKL文件解析
- PKL文件内容查看
- 转换为CSV格式
- CDC V2格式转换
- 大文件支持

---

## 🎨 界面优化

### 侧边栏功能
- **位置**：左侧固定
- **收起按钮**：右侧中间偏上（小按钮）
- **快捷键**：点击按钮收起/展开
- **图标**：展开◀ / 收起▶

### 视觉特点
- ✅ 渐变紫色主题
- ✅ 流畅动画效果
- ✅ 响应式设计
- ✅ 图标大小固定（18px）

---

## 📁 目录结构

```
MyDataCheck/
├── web_app.py           # 主入口（26行）
├── start_web.sh         # 启动脚本
├── stop_web.sh          # 停止脚本
│
├── web/                 # Web应用
│   ├── app.py          # Flask应用
│   └── routes/         # 路由模块
│
├── templates/           # HTML模板
│   └── index.html      # 主页面
│
├── inputdata/           # 输入数据
├── outputdata/          # 输出数据
├── docs/                # 项目文档
├── md/                  # 详细文档
└── backups/             # 备份文件
```

---

## 🔧 常用命令

### 启动服务
```bash
# 方式1：使用脚本
./start_web.sh

# 方式2：直接运行
python3 web_app.py
```

### 查看日志
```bash
# 实时查看
tail -f nohup.out

# 查看最后100行
tail -100 nohup.out
```

### 停止服务
```bash
# 使用脚本
./stop_web.sh

# 手动停止
ps aux | grep web_app.py
kill <PID>
```

### 文件整理
```bash
# 完整整理（推荐）
./organize_all_files.sh

# 基础整理
./organize_files.sh

# 清理冗余文件
./cleanup_redundant_files.sh
```

---

## 📝 配置文件

### 接口对比配置
```
api_comparison/config.json
```

### 线上对比配置
```
online_comparison/config.json
```

### 数据对比配置
```
data_comparison/config.json
```

---

## 🎯 使用技巧

### 接口对比
1. 添加场景（可多个）
2. 配置CSV文件路径
3. 设置API地址和参数
4. 点击"执行对比"
5. 查看输出结果

### 数据对比
1. 上传两个文件（CSV/XLSX）
2. 设置主键列索引（A列=0）
3. 设置特征起始列
4. 勾选"转换特征值"（推荐）
5. 执行对比

### PKL解析
1. 上传PKL文件
2. 点击"解析文件"查看内容
3. 选择转换格式：
   - 标准CSV
   - CDC V2核心CSV
4. 下载转换结果

---

## 📚 文档导航

### 快速开始
- [安装指南](md/01_快速开始/INSTALL.md)
- [快速开始](md/01_快速开始/QUICK_START.md)
- [可视化指南](md/01_快速开始/VISUAL_GUIDE.md)

### 功能说明
- [Web界面使用](md/02_Web界面/Web界面使用说明.md)
- [数据对比功能](md/04_数据对比功能/数据对比功能说明.md)
- [PKL功能](md/05_PKL功能/PKL功能快速参考.md)

### 开发文档
- [项目状态报告](PROJECT_STATUS.md)
- [Web应用重构](md/03_Web应用重构/Web应用模块化拆分方案.md)
- [文档索引](md/INDEX.md)

### 项目管理
- [迁移报告](docs/migration/迁移成功总结.md)
- [清理报告](docs/cleanup/README.md)

---

## ⚠️ 注意事项

### 文件路径
- 使用相对路径或绝对路径
- CSV文件需要UTF-8编码
- 大文件建议分批处理

### 性能优化
- 默认线程数：150
- 默认超时：60秒
- 可根据实际情况调整

### 数据安全
- 输入数据保存在 `inputdata/`
- 输出数据保存在 `outputdata/`
- 定期清理临时文件

---

## 🐛 常见问题

### Q1: 服务启动失败？
```bash
# 检查端口占用
lsof -i :5000

# 杀死占用进程
kill -9 <PID>

# 重新启动
./start_web.sh
```

### Q2: 文件上传失败？
- 检查文件格式（CSV/XLSX/PKL）
- 检查文件编码（UTF-8）
- 检查文件大小（<100MB）

### Q3: 对比结果不准确？
- 勾选"转换特征值为数值"
- 检查主键列索引是否正确
- 检查特征起始列是否正确

### Q4: 界面显示异常？
- 清除浏览器缓存
- 使用Chrome/Safari浏览器
- 检查网络连接

---

## 🔗 快速链接

| 功能 | 链接 |
|------|------|
| 启动服务 | `./start_web.sh` |
| 访问界面 | http://localhost:5000 |
| 停止服务 | `./stop_web.sh` |
| 项目状态 | [PROJECT_STATUS.md](PROJECT_STATUS.md) |
| 文档索引 | [md/INDEX.md](md/INDEX.md) |

---

## 📊 最近更新

### v2.0 (2026-01-27)
- ✅ 侧边栏UI优化
- ✅ web_app.py模块化重构（1764行→26行）
- ✅ 清理33个冗余文件
- ✅ 文档整理到docs目录

---

## 💡 提示

### 开发建议
- 新功能使用Blueprint模块化
- 保持代码简洁清晰
- 及时更新文档
- 定期清理冗余文件

### 维护建议
- 每月执行 `./organize_all_files.sh`
- 定期备份重要文件
- 保持依赖更新
- 关注性能优化

---

**快速参考版本**：v2.0  
**最后更新**：2026-01-27  
**维护状态**：✅ 活跃

---

*需要帮助？查看 [完整文档](md/INDEX.md) 或 [项目状态](PROJECT_STATUS.md)*
