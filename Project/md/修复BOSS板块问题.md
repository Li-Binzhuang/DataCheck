# BOSS板块衍生.ipynb 问题修复指南

## 发现的问题

1. **缺少 `openpyxl` 模块**：代码尝试使用 `openpyxl` 引擎写入 Excel 文件
2. **缺少 `scripts.build_all_blocks_feature_quality_excel` 模块**：代码尝试导入该模块但不存在

## 已完成的修复

✅ 已创建 `scripts/build_all_blocks_feature_quality_excel.py` 模块  
✅ 已创建 `scripts/__init__.py`  
✅ 已创建 `安装依赖.sh` 脚本

## 需要您手动完成的步骤

### 步骤 1: 安装 openpyxl

在终端运行：

```bash
cd /Users/zhanglifeng12703/Documents/OverseasPython/CDC
./安装依赖.sh
```

或者手动安装：

```bash
cd /Users/zhanglifeng12703/Documents/OverseasPython
source .venv/bin/activate
pip install openpyxl
```

如果遇到 SSL 错误：

```bash
pip install --trusted-host pypi.org --trusted-host pypi.python.org --trusted-host files.pythonhosted.org openpyxl
```

### 步骤 2: 验证安装

```bash
python -c "import openpyxl; print('openpyxl', openpyxl.__version__)"
```

### 步骤 3: 重新运行 notebook

安装完成后，重新运行 `BOSS板块衍生.ipynb` 应该就可以正常执行了。

## 已创建的模块

`scripts/build_all_blocks_feature_quality_excel.py` 包含以下函数：
- `_strip_feature_name()`: 去除特征名前后缀
- `_iv_one()`: 计算 IV 值
- `_corr_pearson()`: 计算 Pearson 相关系数
- `_psi_one()`: 计算 PSI 值
- `SENTINEL`: 常量 -999

## 如果仍然报错

请提供具体的错误信息，我会继续帮您修复。
