# 在 Cursor 中切换 Jupyter Notebook 内核的方法

## 问题
Cursor 中的 Jupyter Notebook 仍在使用 Python 3.15，需要切换到 Python 3.12 虚拟环境。

## 方法1: 通过 Cursor 界面切换（如果可用）

### 查找内核选择器
1. **查看右上角**：可能有一个下拉菜单或按钮显示当前内核
2. **查看状态栏**：底部状态栏可能显示 Python 版本
3. **右键菜单**：右键点击 notebook 文件，查看是否有 "Select Kernel" 或 "选择内核" 选项
4. **命令面板**：
   - 按 `Cmd+Shift+P` (Mac) 或 `Ctrl+Shift+P` (Windows/Linux)
   - 输入 "kernel" 或 "内核"
   - 选择 "Notebook: Select Kernel" 或类似选项

## 方法2: 手动注册内核（推荐）

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

然后：
1. **重启 Cursor**
2. 重新打开 notebook
3. 使用命令面板 (`Cmd+Shift+P`) 选择 "Notebook: Select Kernel"
4. 选择 "Python 3.12 (Mytest)"

## 方法3: 从终端启动 Jupyter（最可靠）

如果 Cursor 的内核切换有问题，可以从终端启动 Jupyter：

```bash
cd /Users/zhanglifeng12703/Documents/OverseasPython/Mytest

# 激活虚拟环境
source .venv/bin/activate

# 启动 Jupyter Notebook
jupyter notebook
```

然后在浏览器中打开 notebook，内核会自动使用虚拟环境的 Python 3.12。

## 方法4: 检查 notebook 元数据

如果上述方法都不行，可以检查 notebook 文件中的内核设置：

1. 打开 `ipynb/parse_pkl_to_csv.ipynb`
2. 查看文件开头的元数据，找到 `"kernelspec"` 部分
3. 确保它指向正确的 Python 环境

## 验证设置

切换内核后，运行 notebook 中的第 0 步代码块（"检查并设置 Python 环境"），应该看到：
- Python 版本: 3.12.x
- Python 路径: .../Mytest/.venv/bin/python
- pandas 和 numpy 可以正常导入

## 如果仍然无法切换

如果所有方法都失败，可以：
1. 使用 VS Code 或其他支持 Jupyter 的编辑器
2. 或者直接在终端使用 Python 脚本而不是 notebook
