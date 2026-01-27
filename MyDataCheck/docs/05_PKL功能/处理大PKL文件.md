# 处理大PKL文件指南

## 问题说明

如果PKL文件过大（超过1GB），Web界面上传可能会遇到413错误。

## 解决方案

### 方案1: 使用命令行工具（推荐）✅

如果文件很大，建议直接使用命令行工具处理：

```bash
cd MyDataCheck
source .venv/bin/activate

# 将PKL文件放到inputdata目录
cp your_file.pkl inputdata/api_comparison/

# 使用Python脚本转换
python -c "
from common.pkl_converter import convert_pkl_to_csv
success, msg, csv_path = convert_pkl_to_csv('inputdata/api_comparison/your_file.pkl')
print(f'{msg} -> {csv_path}')
"
```

### 方案2: 增加文件大小限制

如果确实需要通过Web界面上传，可以：

1. **修改Flask配置**（已更新为1GB）：
   - 文件：`web_app.py`
   - 配置：`MAX_CONTENT_LENGTH = 1024 * 1024 * 1024` (1GB)

2. **重启Web服务**：
   ```bash
   cd MyDataCheck
   ./start_web.sh
   ```

### 方案3: 压缩文件

如果文件可以压缩：

```bash
# 压缩PKL文件（如果支持）
gzip your_file.pkl
# 上传压缩后的文件，然后在服务器上解压
```

### 方案4: 分割文件

如果文件可以分割：

```python
import pickle
import pandas as pd

# 读取大文件
with open('large_file.pkl', 'rb') as f:
    data = pickle.load(f)

# 如果是DataFrame，可以按行分割
if isinstance(data, pd.DataFrame):
    chunk_size = 100000  # 每10万行一个文件
    for i in range(0, len(data), chunk_size):
        chunk = data.iloc[i:i+chunk_size]
        chunk.to_pickle(f'large_file_part_{i//chunk_size}.pkl')
```

## 当前限制

- **Web界面上传限制**: 1GB
- **建议文件大小**: 小于500MB（上传速度更快）

## 验证文件大小

```bash
# 查看文件大小
ls -lh your_file.pkl

# 如果超过1GB，建议使用命令行工具
```

## 注意事项

1. 大文件上传可能需要较长时间（取决于网络速度）
2. 转换大文件也需要时间（取决于文件大小和服务器性能）
3. 如果文件超过1GB，强烈建议使用命令行工具
