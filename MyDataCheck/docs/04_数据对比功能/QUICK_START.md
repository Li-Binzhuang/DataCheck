# 数据对比模块 - 快速开始

## 5分钟快速上手

### 方式1：Web界面（推荐）

#### 步骤1：启动Web服务
```bash
cd MyDataCheck
./start_web.sh
```

#### 步骤2：访问Web界面
打开浏览器访问：http://localhost:5000

#### 步骤3：选择"数据对比"Tab
点击页面顶部的"📊 数据对比"标签

#### 步骤4：上传文件
- 上传Sql文件（CSV或XLSX格式）
- 上传接口文件（CSV或XLSX格式）

#### 步骤5：配置参数
- Sql文件主键列索引：0（A列）
- 接口文件主键列索引：0（A列）
- Sql文件特征起始列：1（B列开始）
- 接口文件特征起始列：1（B列开始）
- 转换特征值为数值：勾选（推荐）

#### 步骤6：执行对比
点击"▶️ 执行对比"按钮，等待执行完成

#### 步骤7：查看结果
结果文件保存在：`outputdata/data_comparison/`

---

### 方式2：命令行

#### 步骤1：准备文件
将待对比的文件放在 `inputdata/data_comparison/` 目录下

#### 步骤2：编辑配置
编辑 `data_comparison/config.json`：
```json
{
  "scenarios": [
    {
      "name": "我的对比任务",
      "enabled": true,
      "sql_file": "sql_data.csv",
      "api_file": "api_data.csv",
      "sql_key_column": 0,
      "api_key_column": 0,
      "sql_feature_start": 1,
      "api_feature_start": 1,
      "convert_feature_to_number": true,
      "output_prefix": "my_compare"
    }
  ]
}
```

#### 步骤3：执行对比
```bash
cd MyDataCheck/data_comparison
python execute_data_comparison.py
```

#### 步骤4：查看结果
结果文件保存在：`outputdata/data_comparison/`

---

### 方式3：Python代码

```python
import sys
import os

# 添加项目路径
sys.path.insert(0, '/path/to/MyDataCheck')

from data_comparison.job.data_comparator import compare_two_files
from data_comparison.job.report_generator import generate_comparison_reports

# 执行对比
results = compare_two_files(
    sql_file_path="inputdata/data_comparison/sql_data.csv",
    api_file_path="inputdata/data_comparison/api_data.csv",
    sql_key_column=0,
    api_key_column=0,
    sql_feature_start=1,
    api_feature_start=1,
    convert_feature_to_number=True
)

# 生成报告
generate_comparison_reports(
    "outputdata/data_comparison/my_result",
    results
)

print("对比完成！")
```

---

## 输出文件说明

执行完成后，会在 `outputdata/data_comparison/` 目录下生成以下文件：

1. **{prefix}_{timestamp}_差异特征汇总.csv**
   - 列出所有有差异的特征
   - 显示差异数量和占比

2. **{prefix}_{timestamp}_差异数据明细.csv**
   - 详细列出每条差异记录
   - 包含主键值、cust_no、特征名、两个文件的值

3. **{prefix}_{timestamp}_特征统计.csv**
   - 每个特征的统计信息
   - 包含总对比次数、一致数量、差异数量、一致率

4. **{prefix}_{timestamp}_全量数据合并.csv**
   - 合并两个文件的所有数据
   - 标记数据来源和对比结果

5. **{prefix}_{timestamp}_仅在接口文件中的数据.csv**
   - 在接口文件中存在，但在Sql文件中不存在的记录

6. **{prefix}_{timestamp}_仅在Sql文件中的数据.csv**
   - 在Sql文件中存在，但在接口文件中不存在的记录

---

## 常见问题

### Q1：列索引怎么确定？
**A**：列索引从0开始，A列=0，B列=1，C列=2，以此类推。

### Q2：什么是特征起始列？
**A**：特征起始列是指特征数据开始的列。例如，如果A列是主键，B列开始是特征，则特征起始列为1。

### Q3：是否需要转换特征值为数值？
**A**：如果数据中包含引号（如 "8"），或者需要进行数值对比，建议勾选此选项。

### Q4：支持哪些文件格式？
**A**：支持CSV和XLSX格式。CSV文件支持UTF-8、GBK、GB2312编码。

### Q5：大文件需要多长时间？
**A**：处理速度取决于文件大小和特征数量。一般10万行数据约需1-2分钟。

### Q6：如何查看历史配置？
**A**：配置保存在 `data_comparison/config.json` 文件中，可以直接编辑或通过Web界面加载。

---

## 下一步

- 查看 [README.md](./README.md) 了解详细功能
- 查看 [数据对比功能说明](../md/数据对比功能说明.md) 了解原理
- 查看 [数据对比转换功能快速参考](../数据对比转换功能快速参考.md) 了解转换规则

---

## 需要帮助？

如有问题，请查看：
- [数据对比功能完整更新记录](../md/数据对比功能完整更新记录.md)
- [数据对比模块重构完成报告](../md/数据对比模块重构完成报告.md)
