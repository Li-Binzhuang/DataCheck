# 修复 Notebook 运行问题

## 问题原因
虚拟环境不存在或使用了 Python 3.15（不支持 pandas）

## 已完成的修复
✅ 已创建 Python 3.12 虚拟环境  
✅ 已更新 notebook 元数据指向 Python 3.12

## 需要您手动完成的步骤

### 步骤 1: 安装依赖包（重要！）

**必须在终端运行以下命令：**

```bash
cd /Users/zhanglifeng12703/Documents/OverseasPython/Mytest
source .venv/bin/activate
pip install pandas numpy
```

**如果遇到 SSL 证书错误，使用：**

```bash
pip install --trusted-host pypi.org --trusted-host pypi.python.org --trusted-host files.pythonhosted.org pandas numpy
```

**如果遇到权限问题，使用：**

```bash
pip install --user pandas numpy
```

**验证安装：**

```bash
python -c "import pandas; print('pandas', pandas.__version__)"
python -c "import numpy; print('numpy', numpy.__version__)"
```

应该看到类似：
```
pandas 2.2.0
numpy 1.26.0
```

### 步骤 2: 验证安装

```bash
python -c "import pandas; print('pandas', pandas.__version__)"
python -c "import numpy; print('numpy', numpy.__version__)"
```

应该看到类似输出：
```
pandas 2.2.0
numpy 1.26.0
```

### 步骤 3: 重启 Cursor

1. 完全关闭 Cursor
2. 重新打开 Cursor
3. 打开 `ipynb/parse_pkl_to_csv.ipynb`
4. 运行第1步代码块

### 步骤 4: 验证 Notebook 运行

运行第1步代码块，应该看到：
```
Python: 3.12.12 | 路径: .../.venv/bin/python
✅ pandas 2.2.0, numpy 1.26.0
```

## 如果仍然不行

### 方法 1: 手动选择内核

1. 在 Cursor 中打开 notebook
2. 点击右上角的 "Kernel" 或 "内核" 按钮
3. 选择 "Python 3.12" 或 `.venv` 环境

### 方法 2: 使用 Jupyter Notebook（浏览器）

```bash
cd /Users/zhanglifeng12703/Documents/OverseasPython/Mytest
source .venv/bin/activate
pip install jupyter
jupyter notebook
```

浏览器会自动打开，在浏览器中打开 `ipynb/parse_pkl_to_csv.ipynb`

## 当前状态

- ✅ Python 3.12 虚拟环境已创建
- ✅ Notebook 元数据已更新
- ⏳ 等待安装 pandas 和 numpy
