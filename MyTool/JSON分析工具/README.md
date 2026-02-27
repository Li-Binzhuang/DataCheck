# JSON分析工具

分析 JSON 文件的数据结构，特别适用于信贷征信数据分析。

## 用法

```bash
python analyze_json.py [json文件路径]
```

不指定文件时，默认分析同目录下的 `cdcjson.txt`。

## 功能

- 解析多个 JSON 对象
- 分析顶层字段结构
- 解析嵌套的 response_body 字段
- 统计征信查询和信贷账户信息
