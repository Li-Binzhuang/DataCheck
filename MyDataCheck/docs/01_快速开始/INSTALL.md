# MyDataCheck 安装指南

## 环境要求

- Python 3.7+
- pip

## 安装步骤

### 1. 安装依赖

```bash
cd MyDataCheck
pip install -r requirements.txt
```

或者手动安装:

```bash
pip install Flask>=2.0.0
pip install requests>=2.25.0
```

### 2. 启动 Web 服务

```bash
# 使用启动脚本
./start_web.sh

# 或者直接运行
python web_app.py
```

### 3. 访问 Web 界面

打开浏览器访问: http://localhost:5000

### 4. 停止服务

```bash
./stop_web.sh
```

## 常见问题

### Q: ModuleNotFoundError: No module named 'requests'

**解决方法:**
```bash
pip install requests
```

### Q: ModuleNotFoundError: No module named 'Flask'

**解决方法:**
```bash
pip install Flask
```

### Q: 端口 5000 已被占用

**解决方法:**

修改 `web_app.py` 中的端口号:

```python
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001, debug=False)  # 改为 5001 或其他端口
```

## 项目结构

```
MyDataCheck/
├── web_app.py              # Web 应用主文件
├── requirements.txt        # Python 依赖
├── start_web.sh           # 启动脚本
├── stop_web.sh            # 停止脚本
├── templates/             # HTML 模板
│   └── index.html
├── api_comparison/        # 接口数据对比模块
│   ├── config.json
│   └── job/
├── online_comparison/     # 线上灰度落数对比模块
│   ├── config.json
│   └── job/
├── common/                # 公共工具模块
├── inputdata/             # 输入数据目录
│   ├── api_comparison/
│   └── online_comparison/
└── outputdata/            # 输出数据目录
    ├── api_comparison/
    └── online_comparison/
```

## 功能模块

### 1. 接口数据对比

- 支持多场景配置
- 支持动态接口参数配置
- 支持并发请求
- 自动生成对比报告

### 2. 线上灰度落数对比

- JSON 数据解析
- 数据对比分析
- 差异报告生成

## 更新日志

### v2.0 (2025-01-21)

- ✅ 新增动态接口参数配置功能
- ✅ 支持任意数量的接口参数
- ✅ 支持自定义参数名称
- ✅ 支持时间字段自动标准化
- ✅ 向后兼容旧配置格式

### v1.0

- 初始版本
- 接口数据对比功能
- 线上灰度落数对比功能
