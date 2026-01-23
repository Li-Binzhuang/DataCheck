# MyDataCheck 文档目录

## 📁 文档结构

### 根目录文档（用户文档）

#### PKL功能
- **PKL功能快速参考.md** - PKL功能快速使用指南
- **PKL文件上传功能说明.md** - PKL上传功能详细说明
- **处理大PKL文件.md** - 大文件处理指南

#### 服务管理
- **重启Web服务说明.md** - Web服务重启指南

### md/目录文档（项目文档）

#### 安装和快速开始
- **INSTALL.md** - 安装指南
- **QUICK_START.md** - 快速开始指南
- **VISUAL_GUIDE.md** - 可视化使用指南

#### 使用说明
- **Web界面使用说明.md** - Web界面详细使用说明

### archive/目录（归档文档）

#### old_structure/（旧项目结构文档）
- 目录结构说明.md - 旧"场景1_接口数据对比"结构说明
- 使用说明.md - 基于旧结构的使用说明
- 时间字段T分隔符开关功能说明.md - 功能说明（已集成到新结构）
- 特征字段为null的原因分析.md - 问题分析（问题已解决）
- 停止服务说明.md - 基于旧路径的服务停止说明
- README.md - 归档说明

#### pkl_feature/
- PKL功能完成总结.md
- PKL功能更新说明.md

#### python_env/
- Python环境切换指南.md
- 修复PKL功能.md
- 快速修复指南.md

#### config_verification/
- config配置路径问题分析.md
- 配置文件验证结果.md

#### development/
- 冗余分析报告.md
- 冗余代码清理报告.md
- 脚本功能分析.md
- 脚本结构说明.md
- 需求检查报告.md
- 最近优化对输出CSV的影响分析.md
- 接口数据为空问题诊断报告.md
- 接口数据结构兼容优化说明.md
- COMPLETION_SUMMARY.md - 任务完成总结
- DYNAMIC_PARAMS_FEATURE.md - 动态参数功能文档
- FEATURE_SUMMARY.md - 功能实现总结
- IMPLEMENTATION_STATUS.md - 实现状态跟踪
- WEB_UPDATE_GUIDE.md - Web更新指南
- test_web_interface.md - Web测试文档

## 📊 文档统计

- **根目录**: 4个用户文档
- **md/目录**: 5个项目文档
- **archive/**: 27个归档文档
- **总计**: 36个文档

## 🔍 快速查找

### 我想...
- **安装项目** → INSTALL.md
- **快速开始** → QUICK_START.md
- **使用Web界面** → Web界面使用说明.md 或 VISUAL_GUIDE.md
- **上传PKL文件** → PKL文件上传功能说明.md
- **处理大文件** → 处理大PKL文件.md
- **重启服务** → 重启Web服务说明.md
- **了解旧项目结构** → archive/old_structure/README.md

## 📝 文档维护

### 归档规则
- **开发文档**: 开发过程中的分析、报告 → archive/development/
- **问题解决文档**: 已解决问题的文档 → archive/对应分类/
- **功能开发文档**: 功能完成后的总结 → archive/对应分类/
- **旧结构文档**: 描述已废弃项目结构的文档 → archive/old_structure/

### 保留规则
- **用户文档**: 用户使用指南保留在根目录
- **项目文档**: 项目说明、安装指南保留在md/目录
- **功能文档**: 当前功能的使用说明保留在md/目录

### 最近归档（2026-01-23）
归档了5个描述旧项目结构"场景1_接口数据对比"的文档到 `archive/old_structure/`：
- 项目已从"场景1_接口数据对比"重构为 `api_comparison/`
- 旧文档中的路径、脚本名称、配置格式已过时
- 当前项目使用Web界面进行配置和操作

## 🗂️ 子目录README

- **api_comparison/json/README.md** - JSON配置说明
- **inputdata/README.md** - 输入目录说明
- **online_comparison/README.md** - 线上对比说明
- **outputdata/README.md** - 输出目录说明

## 📅 最后更新

2026年1月23日 - 完成文档整理归档
