# Web模块说明

## 目录结构

```
web/
├── __init__.py              # 模块初始化
├── app.py                   # Flask应用主入口
├── config.py                # 配置和常量
├── utils.py                 # 工具函数（OutputCapture等）
├── routes/                  # 路由模块
│   ├── __init__.py
│   ├── api_comparison.py    # 接口数据对比相关路由
│   ├── online_comparison.py # 线上灰度对比相关路由
│   ├── data_comparison.py   # 数据对比相关路由
│   ├── pkl_tools.py         # PKL工具相关路由
│   └── main.py              # 主页路由
└── README.md                # 本文件
```

## 模块职责

### app.py
- Flask应用初始化
- 注册所有蓝图
- 错误处理
- 信号处理

### config.py
- 目录路径配置
- 应用配置
- 常量定义

### utils.py
- OutputCapture类
- 其他通用工具函数

### routes/
各个功能模块的路由处理：

#### api_comparison.py
- `/api/config/load` - 加载接口对比配置
- `/api/config/save` - 保存接口对比配置
- `/api/upload` - 上传文件
- `/api/execute` - 执行接口对比

#### online_comparison.py
- `/api/config/online/load` - 加载线上对比配置
- `/api/config/online/save` - 保存线上对比配置
- `/api/upload/online` - 上传线上对比文件
- `/api/parse/online` - 解析JSON
- `/api/execute/online` - 执行线上对比

#### data_comparison.py
- `/api/compare/upload` - 上传数据对比文件
- `/api/compare/execute` - 执行数据对比
- `/api/compare/config/save` - 保存数据对比配置
- `/api/compare/config/load` - 加载数据对比配置

#### pkl_tools.py
- `/api/pkl/parse` - 解析PKL文件
- `/api/pkl/convert` - 转换PKL为CSV
- `/api/pkl/convert-cdcv2` - 转换PKL为CDC V2格式
- `/api/pkl/info` - 获取PKL文件信息

#### main.py
- `/` - 主页

## 优势

1. **模块化**：每个功能独立，职责清晰
2. **可维护性**：修改某个功能不影响其他模块
3. **可扩展性**：添加新功能只需新增路由文件
4. **可测试性**：每个模块可以独立测试
5. **代码复用**：公共功能提取到utils
6. **清晰的结构**：一目了然的文件组织

## 迁移说明

从原来的`web_app.py`（1764行）拆分为：
- `app.py`：约100行
- `config.py`：约80行
- `utils.py`：约50行
- `routes/api_comparison.py`：约400行
- `routes/online_comparison.py`：约500行
- `routes/data_comparison.py`：约300行
- `routes/pkl_tools.py`：约250行
- `routes/main.py`：约20行

总计约1700行，但分散在8个文件中，每个文件不超过500行。

## 使用方式

启动应用：
```bash
python -m web.app
# 或
python web/app.py
```

原有的启动方式仍然兼容：
```bash
python web_app.py
```
