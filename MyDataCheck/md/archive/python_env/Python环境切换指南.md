# Python环境切换指南

## 问题说明

当前MyDataCheck项目使用Python 3.15.0a2(alpha版本),该版本与pandas/numpy不兼容,导致PKL文件转换功能无法使用。

## 推荐解决方案

### 方案1: 切换到Python 3.12(推荐)

#### 步骤1: 检查系统中的Python版本
```bash
# 查看所有可用的Python版本
ls -l /usr/local/bin/python* 2>/dev/null
ls -l /Library/Frameworks/Python.framework/Versions/
```

#### 步骤2: 安装Python 3.12(如果没有)
```bash
# 使用Homebrew安装
brew install python@3.12

# 或者从官网下载安装
# https://www.python.org/downloads/
```

#### 步骤3: 删除现有虚拟环境
```bash
cd MyDataCheck
rm -rf .venv
```

#### 步骤4: 使用Python 3.12创建新虚拟环境
```bash
# 方式1: 使用python3.12命令
python3.12 -m venv .venv

# 方式2: 指定完整路径
/Library/Frameworks/Python.framework/Versions/3.12/bin/python3 -m venv .venv

# 方式3: 使用Homebrew安装的版本
/usr/local/bin/python3.12 -m venv .venv
```

#### 步骤5: 激活虚拟环境
```bash
source .venv/bin/activate
```

#### 步骤6: 验证Python版本
```bash
python --version
# 应该显示: Python 3.12.x
```

#### 步骤7: 安装依赖
```bash
pip install --upgrade pip
pip install -r requirements.txt
```

#### 步骤8: 验证pandas安装
```bash
python -c "import pandas; print(f'pandas版本: {pandas.__version__}')"
```

### 方案2: 使用Python 3.11

如果系统中有Python 3.11,步骤与方案1相同,只需将`python3.12`替换为`python3.11`。

```bash
cd MyDataCheck
rm -rf .venv
python3.11 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

## 验证安装

### 测试PKL转换功能
```bash
# 激活虚拟环境
source MyDataCheck/.venv/bin/activate

# 运行测试脚本
python test_pkl_converter.py
```

### 启动Web服务
```bash
# 使用启动脚本
./start_web.sh

# 或手动启动
source .venv/bin/activate
python web_app.py
```

## 常见问题

### Q1: 找不到python3.12命令
**A**: 需要先安装Python 3.12:
```bash
brew install python@3.12
```

### Q2: pip安装pandas失败
**A**: 确保使用的是Python 3.11或3.12,不是3.15:
```bash
python --version  # 检查版本
```

### Q3: 虚拟环境激活后还是Python 3.15
**A**: 删除虚拟环境重新创建:
```bash
deactivate  # 先退出虚拟环境
rm -rf .venv
python3.12 -m venv .venv
source .venv/bin/activate
```

### Q4: 不想切换Python版本
**A**: 可以保持当前配置,PKL功能会优雅降级:
- 上传PKL文件时会提示"需要安装pandas库"
- 可以手动转换PKL为CSV后上传
- 其他功能不受影响

## 检查清单

安装完成后,请检查以下项目:

- [ ] Python版本为3.11或3.12
- [ ] 虚拟环境已激活
- [ ] pandas已成功安装
- [ ] numpy已成功安装
- [ ] Flask已成功安装
- [ ] Web服务可以正常启动
- [ ] PKL文件可以正常转换

## 快速命令

```bash
# 一键切换到Python 3.12环境
cd MyDataCheck
rm -rf .venv
python3.12 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
python -c "import pandas; print('✅ pandas安装成功')"
```

## 相关文档

- [PKL功能更新说明.md](PKL功能更新说明.md)
- [requirements.txt](requirements.txt)

---

**更新时间**: 2026-01-22  
**适用版本**: MyDataCheck 1.2.0
