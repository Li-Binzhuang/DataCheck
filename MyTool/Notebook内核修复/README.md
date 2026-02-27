# Notebook内核修复工具

修复 Jupyter Notebook 的内核配置，指向正确的 Python 环境。

## 用法

```bash
python fix_kernel.py <notebook文件路径>
```

## 示例

```bash
python fix_kernel.py ../ipynb/parse_pkl_to_csv.ipynb
```

## 功能

- 更新 notebook 的 kernelspec 配置
- 设置正确的 Python 版本信息
