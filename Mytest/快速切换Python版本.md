# 快速切换 Python 版本指南

## 使用方法

### 方法1: 使用切换脚本（推荐）

```bash
cd /Users/zhanglifeng12703/Documents/OverseasPython/Mytest
./switch_python.sh
```

脚本会：
1. 自动查找系统中可用的 Python 版本（3.9, 3.10, 3.11, 3.12）
2. 显示所有可用版本供选择
3. 备份旧的虚拟环境
4. 使用选定的 Python 版本创建新虚拟环境
5. 自动安装 pandas 和 numpy

### 方法2: 手动切换

```bash
cd /Users/zhanglifeng12703/Documents/OverseasPython/Mytest

# 1. 备份旧虚拟环境（可选）
mv .venv .venv.backup

# 2. 使用 Python 3.12 创建新虚拟环境
python3.12 -m venv .venv

# 3. 激活虚拟环境
source .venv/bin/activate

# 4. 安装依赖
pip install pandas numpy
```

## 查找 Python 版本

如果不知道系统中安装了哪些 Python 版本，可以运行：

```bash
# 查找所有 python3.x 命令
ls -la /usr/local/bin/python3* 2>/dev/null
ls -la /opt/homebrew/bin/python3* 2>/dev/null

# 或者使用 which
which python3.12
which python3.11
which python3.10
```

## 安装 Python 3.12

如果没有 Python 3.12，可以使用 Homebrew 安装：

```bash
brew install python@3.12
```

## 切换后

切换完成后，需要：

1. **在 Cursor 中切换 Jupyter 内核**：
   - 按 `Cmd+Shift+P`
   - 输入 "kernel"
   - 选择 "Notebook: Select Kernel"
   - 选择 "Python Environments"
   - 选择：`/Users/zhanglifeng12703/Documents/OverseasPython/Mytest/.venv/bin/python`

2. **或者在终端启动 Jupyter**：
   ```bash
   cd /Users/zhanglifeng12703/Documents/OverseasPython/Mytest
   source .venv/bin/activate
   jupyter notebook
   ```

## 常见问题

### Q: 找不到 python3.12？
A: 需要先安装：`brew install python@3.12`

### Q: 切换后仍然报错？
A: 确保：
   1. 虚拟环境已激活
   2. 在 Cursor 中切换了 Jupyter 内核
   3. 重启了 Cursor

### Q: 想保留旧环境？
A: 脚本会自动备份到 `.venv.backup.时间戳`，可以随时恢复
