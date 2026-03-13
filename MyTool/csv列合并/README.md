# CSV 列合并工具

按组合主键 (apply_id + create_time + cust_no) 合并多个 CSV 文件的列

## 快速开始

### 安装加速库（可选，但强烈推荐）
```bash
bash install_pyarrow.sh
```
安装 pyarrow 后，CSV 读写速度可提升 3-10 倍！

### 推荐使用

### 1. merge_csv_fast_fixed.py ⚡ (推荐 - 速度最快)
```bash
python merge_csv_fast_fixed.py
# 或指定文件夹
python merge_csv_fast_fixed.py bl_0302
```
- 使用索引加速合并（比普通 merge 快 3-5 倍）
- 支持 pyarrow 引擎加速读写
- 一次性读取所有文件，内存占用中等
- 适合：内存充足（>2GB 可用）

### 2. merge_csv_batch.py 💾 (稳定 - 内存最小)
```bash
python merge_csv_batch.py
# 或指定文件夹
python merge_csv_batch.py bl_0302
```
- 分批两两合并，内存占用最小
- 支持 pyarrow 引擎加速保存
- 速度较慢但稳定
- 适合：内存不足（<1GB 可用）

## 功能说明

两个脚本都会：
- ✅ 按组合主键 (apply_id + create_time + cust_no) 合并列（inner join）
- ✅ 删除 user_type, rule_type, business_type, if_reoffer 四列
- ✅ 保留所有组合主键字段
- ✅ 每次合并后立即删除重复列（避免行数翻倍）
- ✅ 输出文件：merged_0302new.csv

## 性能对比

| 脚本 | 速度 | 内存占用 | 稳定性 | 适用场景 |
|------|------|----------|--------|----------|
| merge_csv_fast_fixed.py | ⚡⚡⚡⚡⚡ | 中 | 高 | 内存充足，追求速度 |
| merge_csv_batch.py | ⚡⚡ | 低 | 极高 | 内存不足，追求稳定 |

### 速度提升技巧

1. **安装 pyarrow**（最重要）
   ```bash
   bash install_pyarrow.sh
   ```
   - CSV 读写速度提升 3-10 倍
   - 两个脚本都会自动使用

2. **使用 SSD 硬盘**
   - 机械硬盘会严重拖慢速度

3. **关闭其他程序**
   - 释放更多内存给 Python

### 预期速度（32个文件，每个约3MB）

| 配置 | merge_csv_fast_fixed.py | merge_csv_batch.py |
|------|------------------------|-------------------|
| 无 pyarrow | 5-8 分钟 | 10-15 分钟 |
| 有 pyarrow | 2-3 分钟 | 5-8 分钟 |

## 为什么使用组合主键？

如果单个文件中存在重复的 apply_id（同一个 apply_id 出现多次），使用单一主键会导致：
- 合并时产生笛卡尔积
- 行数异常增加

使用组合主键 (apply_id + create_time + cust_no) 可以：
- 精确匹配每一行
- 保持行数稳定
- 避免数据重复

## 数据源

默认处理 `data` 文件夹中的所有 CSV 文件

## 注意事项

- 使用 `inner` join，只保留所有文件都有的组合主键
- 三个主键字段必须在所有文件中都存在
- 如果需要保留所有行（并集），需要修改代码中的 `how='inner'` 为 `how='outer'`
