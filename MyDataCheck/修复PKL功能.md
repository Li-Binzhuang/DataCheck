# PKL功能修复指南

## 问题原因

当前虚拟环境使用的是 **Python 3.15 (alpha版本)**，pandas 库无法在此版本上安装。

## 解决方案

### 方案1: 安装 Python 3.12 并重新创建虚拟环境（推荐）✅

#### 步骤1: 安装 Python 3.12
```bash
# 使用 Homebrew 安装
brew install python@3.12

# 或者从官网下载安装
# https://www.python.org/downloads/
```

#### 步骤2: 重新创建虚拟环境
```bash
cd MyDataCheck

# 删除旧的虚拟环境
rm -rf .venv

# 使用 Python 3.12 创建新虚拟环境
python3.12 -m venv .venv

# 激活虚拟环境
source .venv/bin/activate

# 验证Python版本
python --version
# 应该显示: Python 3.12.x

# 安装依赖
pip install --upgrade pip
pip install -r requirements.txt
```

#### 步骤3: 验证安装
```bash
python -c "import pandas; print('pandas版本:', pandas.__version__)"
# 应该显示: pandas版本: 2.x.x
```

### 方案2: 使用 Python 3.11

如果系统中有 Python 3.11，步骤与方案1相同，只需将 `python3.12` 替换为 `python3.11`：

```bash
cd MyDataCheck
rm -rf .venv
python3.11 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

### 方案3: 使用安装脚本（尝试在当前环境安装）

如果暂时无法切换Python版本，可以尝试使用安装脚本：

```bash
cd MyDataCheck
./install_pandas.sh
```

**注意**: 此方法可能失败，因为 Python 3.15 与 pandas 不兼容。

## 验证修复

安装完成后，启动Web服务测试：

```bash
cd MyDataCheck
source .venv/bin/activate
python web_app.py
```

然后在浏览器中访问 `http://localhost:5000`，尝试上传和解析PKL文件。

## 常见问题

### Q1: 找不到 python3.12 命令
**A**: 需要先安装 Python 3.12
```bash
brew install python@3.12
```

### Q2: 安装后仍然报错
**A**: 确保：
1. 虚拟环境已激活 (`source .venv/bin/activate`)
2. Web服务使用的是正确的Python环境
3. 重启Web服务

### Q3: 如何检查当前使用的Python版本？
```bash
cd MyDataCheck
source .venv/bin/activate
python --version
```

## 快速修复命令（一键执行）

```bash
cd MyDataCheck && \
rm -rf .venv && \
python3.12 -m venv .venv && \
source .venv/bin/activate && \
pip install --upgrade pip && \
pip install -r requirements.txt && \
python -c "import pandas; print('✅ pandas安装成功，版本:', pandas.__version__)"
```

**注意**: 如果系统中没有 `python3.12`，请先安装 Python 3.12。
