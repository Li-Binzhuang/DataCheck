# PKL功能快速参考

## 🚀 快速开始

### 环境要求
- Python 3.11 或 3.12 (不支持3.15)
- pandas >= 2.0.0
- numpy >= 1.24.0

### 一键安装
```bash
# 切换Python环境并安装依赖
cd MyDataCheck
rm -rf .venv
python3.12 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## 📁 文件路径规则

```
上传PKL: inputdata/api_comparison/test.pkl
转换CSV: outputdata/api_comparison/test.csv
```

## 🔧 使用方法

### Web界面
```bash
./start_web.sh
# 访问 http://localhost:5000
# 上传.pkl文件 → 自动转换 → 使用CSV文件名
```

### Python代码
```python
from common.pkl_converter import convert_pkl_to_csv

success, msg, csv_path = convert_pkl_to_csv(
    'inputdata/api_comparison/data.pkl'
)
print(f"{msg} → {csv_path}")
```

### API调用
```python
import requests

with open('data.pkl', 'rb') as f:
    r = requests.post('http://localhost:5000/api/upload', 
                      files={'file': f})
    print(r.json())
```

## ⚠️ 常见问题

### pandas安装失败
```bash
# 原因: Python 3.15不兼容
# 解决: 切换到Python 3.12
python3.12 -m venv .venv
```

### 找不到转换后的文件
```bash
# 检查outputdata目录,不是inputdata
ls -l outputdata/api_comparison/
```

### 转换失败
```bash
# 检查pandas是否安装
python -c "import pandas; print('OK')"
```

## 📚 完整文档

- [PKL功能完成总结.md](PKL功能完成总结.md) - 完整功能说明
- [Python环境切换指南.md](Python环境切换指南.md) - 环境配置
- [PKL功能更新说明.md](PKL功能更新说明.md) - 更新日志

## ✅ 测试命令

```bash
# 测试路径转换
python test_path_conversion.py

# 测试PKL转换(需要pandas)
python test_pkl_converter.py

# 启动Web服务
./start_web.sh
```

---
**版本**: 1.2.0 | **更新**: 2026-01-22
