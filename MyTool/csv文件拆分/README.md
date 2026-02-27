# CSV文件拆分工具

将大CSV文件拆分为多个小文件。

## 用法

```bash
python split_csv.py <输入文件> [每个文件行数]
```

## 示例

```bash
# 默认每个文件100万行
python split_csv.py data.csv

# 指定每个文件10万行
python split_csv.py data.csv 100000
```

## 输出

输出文件命名格式：`原文件名_part1.csv`, `原文件名_part2.csv`, ...
