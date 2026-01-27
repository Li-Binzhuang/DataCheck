# PKL文件上传功能 - 更新说明

## 更新时间
2026-01-22

## 最新更新 ⚠️

### 重要变更
1. **输出目录调整**: PKL转换后的CSV文件现在输出到`outputdata`目录,而不是`inputdata`目录
2. **Python版本兼容性**: 发现Python 3.15.0a2与pandas不兼容

## 问题修复
✅ 修复了web_app.py中的语法错误（try-except结构）  
✅ 添加了pandas依赖检查，提供友好的错误提示  
✅ 更新了requirements.txt，添加pandas依赖  
✅ **修改PKL转换逻辑，输出到outputdata目录**

## 新增功能

### 1. PKL文件上传支持
- 接口数据对比支持上传.pkl文件
- 线上灰度落数对比支持上传.pkl文件
- 自动转换pkl为csv格式
- **转换后的CSV自动保存到outputdata目录**

### 2. 文件类型支持
- `.csv` - 直接使用
- `.pkl` - 自动转换为CSV（输出到outputdata）

### 3. 新增API
- `POST /api/upload` - 支持CSV和PKL文件上传（接口对比）
- `POST /api/upload/online` - 支持CSV和PKL文件上传（线上对比）
- `POST /api/pkl/info` - 获取PKL文件信息

## 文件清单

### 新增文件
1. `MyDataCheck/common/pkl_converter.py` - PKL转换工具模块
2. `MyDataCheck/PKL文件上传功能说明.md` - 详细使用文档
3. `MyDataCheck/test_pkl_converter.py` - 测试脚本

### 修改文件
1. `MyDataCheck/web_app.py` - 添加PKL上传和转换逻辑
2. `MyDataCheck/templates/index.html` - 更新前端界面
3. `MyDataCheck/requirements.txt` - 添加pandas依赖
4. `MyDataCheck/common/pkl_converter.py` - 修改输出目录逻辑

## Python版本兼容性问题 ⚠️

### 当前问题
项目使用**Python 3.15.0a2**(alpha版本),pandas/numpy无法在此版本上编译安装。

**错误信息**:
```
numpy编译错误: thread_local关键字在Python 3.15上不兼容
error: metadata-generation-failed
```

### 解决方案

#### 方案1: 使用Python 3.11或3.12(推荐) ✅
```bash
# 1. 删除现有虚拟环境
rm -rf MyDataCheck/.venv

# 2. 使用Python 3.11或3.12创建新虚拟环境
python3.11 -m venv MyDataCheck/.venv
# 或
python3.12 -m venv MyDataCheck/.venv

# 3. 激活虚拟环境
source MyDataCheck/.venv/bin/activate

# 4. 安装依赖
pip install -r MyDataCheck/requirements.txt
```

#### 方案2: 保持当前配置(功能降级)
如果暂时无法更换Python版本,代码已实现优雅降级:
- PKL转换功能会提示"需要安装pandas库"
- 其他功能不受影响
- 用户可以手动转换PKL文件后上传CSV

## 输出目录说明 📁

### 文件流转路径
```
上传PKL文件
    ↓
保存到 inputdata/api_comparison/ (或 online_comparison/)
    ↓
自动转换
    ↓
输出到 outputdata/api_comparison/ (或 online_comparison/)
    ↓
使用转换后的CSV进行数据对比
```

### 目录结构
```
MyDataCheck/
├── inputdata/
│   ├── api_comparison/          # 上传的原始PKL文件
│   └── online_comparison/       # 上传的原始PKL文件
└── outputdata/
    ├── api_comparison/          # 转换后的CSV文件 ✅
    └── online_comparison/       # 转换后的CSV文件 ✅
```

## 使用方法

### 方式1：Web界面
1. 启动Web服务：`./MyDataCheck/start_web.sh`
2. 打开浏览器访问：`http://localhost:5000`
3. 在文件上传处选择.pkl或.csv文件
4. PKL文件会自动转换为CSV并保存到outputdata目录

### 方式2：API调用
```python
import requests

# 上传PKL文件
with open('data.pkl', 'rb') as f:
    files = {'file': f}
    response = requests.post('http://localhost:5000/api/upload', files=files)
    result = response.json()
    print(f"转换后的文件: {result['filename']}")
    print(f"保存位置: outputdata/api_comparison/{result['filename']}")
```

## 转换逻辑

```python
# 支持的数据类型
1. pandas.DataFrame → 直接转换
2. dict → pd.DataFrame(dict)
3. list → pd.DataFrame(list)
4. 其他 → pd.DataFrame([data])

# 输出路径规则
inputdata/api_comparison/data.pkl 
    → outputdata/api_comparison/data.csv
```

## 注意事项

1. **pandas依赖**: PKL转换功能需要pandas库(Python 3.11-3.13)
2. **Python版本**: 推荐使用Python 3.11或3.12,不支持3.15
3. **文件大小**: 建议PKL文件不超过100MB
4. **数据格式**: PKL文件应包含表格型数据
5. **编码**: 转换后的CSV使用UTF-8编码
6. **输出位置**: 转换后的CSV保存在outputdata目录
7. **覆盖**: 同名CSV文件会被覆盖

## 错误处理

### pandas未安装
```
需要安装pandas库: pip install pandas
```

### Python版本不兼容
```
请使用Python 3.11或3.12重新创建虚拟环境
```

## 测试

运行测试脚本（需要pandas）：
```bash
python3 MyDataCheck/test_pkl_converter.py
```

## 相关文档

- [PKL文件上传功能说明.md](PKL文件上传功能说明.md) - 详细使用文档
- [requirements.txt](requirements.txt) - 依赖列表

---

**维护**: MyDataCheck开发团队  
**版本**: 1.2.0  
**状态**: ⚠️ 需要Python 3.11/3.12环境

