# 快速开始指南

## 问题
Notebook 无法执行，因为 Python 3.15 不支持 pandas。

## 解决方案（3步）

### 步骤 1: 切换 Python 版本

在终端运行：

```bash
cd /Users/zhanglifeng12703/Documents/OverseasPython/Mytest
./switch_python.sh
```

选择 `1` (Python 3.12)

### 步骤 2: 安装依赖（如果脚本未自动安装）

```bash
source .venv/bin/activate
pip install pandas numpy
```

### 步骤 3: 重启 Cursor

1. 完全关闭 Cursor
2. 重新打开 Cursor
3. 打开 `ipynb/parse_pkl_to_csv.ipynb`
4. 运行第1步代码块，应该显示 Python 3.12 和 pandas 已安装

## 验证

运行 notebook 第1步代码块，应该看到：
```
Python: 3.12.x | 路径: .../.venv/bin/python
✅ pandas 3.0.0, numpy 2.4.1
```

然后可以继续执行后续步骤。

## 如果仍然不行

运行自动切换脚本（非交互式）：
```bash
./auto_switch_python312.sh
```

然后重启 Cursor。
