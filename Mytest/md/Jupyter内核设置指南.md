# Jupyter Notebook 内核设置指南

## 问题说明

Cursor 中的 Jupyter Notebook 仍在使用 Python 3.15，而虚拟环境已切换到 Python 3.12。需要将 Jupyter 内核指向新的虚拟环境。

## 解决方案

### 方法1: 在 Cursor 中切换内核（推荐）

1. **打开 notebook** `ipynb/parse_pkl_to_csv.ipynb`

2. **查看当前内核**：
   - 点击右上角的 "Kernel" 或 "内核" 按钮
   - 查看当前使用的内核名称

3. **切换内核**：
   - 点击 "Kernel" → "Change Kernel" 或 "更改内核"
   - 如果看到 "Python 3.12 (Mytest)" 选项，选择它
   - 如果没有，继续执行方法2

### 方法2: 手动注册内核

在终端执行以下命令：

```bash
cd /Users/zhanglifeng12703/Documents/OverseasPython/Mytest

# 激活虚拟环境
source .venv/bin/activate

# 安装 ipykernel（如果未安装）
pip install ipykernel

# 注册内核
python -m ipykernel install --user --name=python312-mytest --display-name="Python 3.12 (Mytest)"
```

### 方法3: 在 Notebook 中直接指定 Python 路径

如果上述方法都不行，可以在 notebook 的第一个 cell 中添加：

```python
import sys
sys.executable = '/Users/zhanglifeng12703/Documents/OverseasPython/Mytest/.venv/bin/python'
```

但这只是临时方案，最好还是切换内核。

## 验证设置

切换内核后，在 notebook 中运行：

```python
import sys
print("Python 版本:", sys.version)
print("Python 路径:", sys.executable)

import pandas as pd
print("pandas 版本:", pd.__version__)
```

应该显示：
- Python 版本: 3.12.x
- Python 路径: .../Mytest/.venv/bin/python
- pandas 版本: 3.0.0

## 常见问题

### Q: 找不到 "Change Kernel" 选项？
A: 在 Cursor 中，可能需要：
   - 右键点击 notebook
   - 选择 "Select Kernel" 或类似选项
   - 或者点击右上角的齿轮图标

### Q: 内核列表中没有 Python 3.12？
A: 执行方法2手动注册内核，然后重启 Cursor

### Q: 切换后仍然报错？
A: 确保：
   1. 虚拟环境中已安装 pandas: `pip list | grep pandas`
   2. 重启了 Cursor
   3. 重新运行了第一个 cell
