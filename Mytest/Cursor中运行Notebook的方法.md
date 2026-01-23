# 在 Cursor 中运行 Jupyter Notebook 的方法

## 问题
Cursor 中没有 "Notebook: Select Kernel" 选项，无法直接切换内核。

## 解决方案

### 方法1: 从终端启动 Jupyter（最可靠，推荐）✅

1. **运行启动脚本**：
   ```bash
   cd /Users/zhanglifeng12703/Documents/OverseasPython/Mytest
   ./start_jupyter.sh
   ```

2. **浏览器会自动打开 Jupyter Notebook 界面**

3. **在浏览器中打开 `ipynb/parse_pkl_to_csv.ipynb`**

4. **此时会自动使用 Python 3.12 环境**

### 方法2: 切换 Python 版本后重启 Cursor

1. **运行切换脚本**：
   ```bash
   cd /Users/zhanglifeng12703/Documents/OverseasPython/Mytest
   ./switch_python.sh
   ```
   选择 Python 3.12

2. **完全关闭 Cursor**

3. **重新打开 Cursor 和 notebook**

4. **Cursor 可能会自动检测到新的 Python 环境**

### 方法3: 手动指定 Python 解释器

如果 Cursor 支持手动指定 Python 解释器：

1. 打开 Cursor 设置
2. 查找 "Python Interpreter" 或 "Python Path" 设置
3. 设置为：`/Users/zhanglifeng12703/Documents/OverseasPython/Mytest/.venv/bin/python`

### 方法4: 使用 VS Code 或其他编辑器

如果 Cursor 的 Jupyter 支持有限，可以使用：
- VS Code（有更好的 Jupyter 支持）
- JupyterLab（浏览器界面）
- PyCharm（专业 Python IDE）

## 推荐使用方法1

**从终端启动 Jupyter 是最可靠的方法**，因为：
- ✅ 自动使用虚拟环境的 Python
- ✅ 不需要切换内核
- ✅ 环境隔离清晰
- ✅ 兼容性最好

## 快速命令

```bash
# 切换到项目目录
cd /Users/zhanglifeng12703/Documents/OverseasPython/Mytest

# 启动 Jupyter（会自动使用 Python 3.12）
./start_jupyter.sh
```

然后在浏览器中打开 notebook 即可！
