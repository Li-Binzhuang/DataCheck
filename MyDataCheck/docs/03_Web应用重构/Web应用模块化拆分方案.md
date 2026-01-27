# Web应用模块化拆分方案

## 背景

原`web_app.py`文件有1764行代码，包含18个路由，代码量过大，不便于维护。

## 拆分目标

1. 按功能模块拆分路由
2. 提取公共配置和工具函数
3. 使用Flask蓝图（Blueprint）组织路由
4. 保持向后兼容，不影响现有功能

## 新目录结构

```
MyDataCheck/
├── web/                          # Web模块（新增）
│   ├── __init__.py
│   ├── app.py                    # Flask应用主入口
│   ├── config.py                 # 配置和常量
│   ├── utils.py                  # 工具函数
│   ├── routes/                   # 路由模块
│   │   ├── __init__.py
│   │   ├── main.py               # 主页路由
│   │   ├── api_comparison.py    # 接口数据对比路由
│   │   ├── online_comparison.py # 线上灰度对比路由
│   │   ├── data_comparison.py   # 数据对比路由
│   │   └── pkl_tools.py          # PKL工具路由
│   └── README.md
├── web_app.py                    # 保留作为入口（兼容性）
└── ...
```

## 文件职责

### web/config.py（约80行）
**职责**：集中管理所有配置和常量

**内容**：
- 目录路径配置（输入/输出目录）
- Flask应用配置（文件大小限制等）
- 常量定义（允许的文件类型等）
- 目录初始化函数

**优势**：
- 配置集中管理，易于修改
- 避免硬编码路径
- 便于环境切换

### web/utils.py（约100行）
**职责**：提供通用工具函数

**内容**：
- `OutputCapture`类：捕获print输出
- `stream_response_generator`：生成SSE流式响应
- 其他通用辅助函数

**优势**：
- 代码复用
- 减少重复代码
- 便于单元测试

### web/routes/main.py（约20行）
**职责**：主页路由

**路由**：
- `GET /` - 渲染主页

### web/routes/api_comparison.py（约400行）
**职责**：接口数据对比相关功能

**路由**：
- `GET /api/config/load` - 加载配置
- `POST /api/config/save` - 保存配置
- `POST /api/upload` - 上传CSV/PKL文件
- `POST /api/execute` - 执行接口数据对比

**执行函数**：
- `execute_comparison_flow()` - 执行对比流程

### web/routes/online_comparison.py（约500行）
**职责**：线上灰度落数对比相关功能

**路由**：
- `GET /api/config/online/load` - 加载线上对比配置
- `POST /api/config/online/save` - 保存线上对比配置
- `POST /api/upload/online` - 上传线上对比文件
- `POST /api/parse/online` - 解析JSON文件
- `POST /api/execute/online` - 执行线上灰度对比

**执行函数**：
- `execute_online_parse_only()` - 仅解析JSON
- `execute_online_comparison_flow()` - 执行单场景对比
- `execute_online_multi_scenario_flow()` - 执行多场景对比

### web/routes/data_comparison.py（约300行）
**职责**：数据对比相关功能

**路由**：
- `POST /api/compare/upload` - 上传数据对比文件
- `POST /api/compare/execute` - 执行数据对比
- `POST /api/compare/config/save` - 保存配置
- `GET /api/compare/config/load` - 加载配置

**执行函数**：
- `execute_compare_flow()` - 执行数据对比流程

### web/routes/pkl_tools.py（约250行）
**职责**：PKL文件处理工具

**路由**：
- `POST /api/pkl/parse` - 解析PKL文件
- `POST /api/pkl/convert` - 转换PKL为CSV
- `POST /api/pkl/convert-cdcv2` - 转换PKL为CDC V2格式
- `POST /api/pkl/info` - 获取PKL文件信息

### web/app.py（约100行）
**职责**：Flask应用主入口

**内容**：
- 创建Flask应用
- 注册所有蓝图
- 配置错误处理
- 信号处理
- 启动应用

## 拆分优势

### 1. 可维护性提升
- 每个文件职责单一，代码量控制在500行以内
- 修改某个功能不影响其他模块
- 代码结构清晰，易于理解

### 2. 可扩展性增强
- 添加新功能只需新增路由文件
- 使用蓝图机制，模块独立
- 便于团队协作开发

### 3. 可测试性改善
- 每个模块可以独立测试
- 工具函数提取后便于单元测试
- 减少测试依赖

### 4. 代码复用
- 公共配置集中管理
- 工具函数统一提供
- 避免重复代码

### 5. 向后兼容
- 保留原`web_app.py`作为入口
- 所有路由和功能保持不变
- 不影响现有使用方式

## 迁移步骤

### 阶段1：创建新结构（已完成）
- [x] 创建`web/`目录
- [x] 创建`config.py`
- [x] 创建`utils.py`
- [x] 创建`routes/`目录
- [x] 创建`routes/main.py`

### 阶段2：拆分路由模块
- [ ] 创建`routes/api_comparison.py`
- [ ] 创建`routes/online_comparison.py`
- [ ] 创建`routes/data_comparison.py`
- [ ] 创建`routes/pkl_tools.py`

### 阶段3：创建主应用
- [ ] 创建`web/app.py`
- [ ] 注册所有蓝图
- [ ] 配置错误处理

### 阶段4：兼容性处理
- [ ] 更新`web_app.py`导入新模块
- [ ] 测试所有功能
- [ ] 确保向后兼容

### 阶段5：文档和测试
- [ ] 更新使用文档
- [ ] 添加单元测试
- [ ] 性能测试

## 使用方式

### 方式1：使用新入口（推荐）
```bash
cd MyDataCheck
python -m web.app
```

### 方式2：使用原入口（兼容）
```bash
cd MyDataCheck
python web_app.py
```

### 方式3：使用启动脚本
```bash
cd MyDataCheck
./start_web.sh
```

## 代码量对比

| 文件 | 行数 | 说明 |
|------|------|------|
| **原web_app.py** | **1764** | **单文件** |
| web/config.py | 80 | 配置 |
| web/utils.py | 100 | 工具 |
| web/routes/main.py | 20 | 主页 |
| web/routes/api_comparison.py | 400 | 接口对比 |
| web/routes/online_comparison.py | 500 | 线上对比 |
| web/routes/data_comparison.py | 300 | 数据对比 |
| web/routes/pkl_tools.py | 250 | PKL工具 |
| web/app.py | 100 | 主应用 |
| **总计** | **1750** | **8个文件** |

## 注意事项

1. **导入路径**：新模块使用相对导入，注意路径调整
2. **模块依赖**：确保所有依赖模块正确导入
3. **测试覆盖**：拆分后需要全面测试所有功能
4. **文档更新**：更新相关文档和注释
5. **向后兼容**：保持原有API不变

## 后续优化

1. **添加单元测试**：为每个模块添加测试用例
2. **API文档**：使用Swagger生成API文档
3. **日志系统**：统一日志记录
4. **错误处理**：完善错误处理机制
5. **性能优化**：优化大文件处理性能

---

**创建时间**：2026-01-26  
**状态**：设计阶段 → 实施中
