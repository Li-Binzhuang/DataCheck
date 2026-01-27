# 动态接口参数配置功能

## 功能概述

为 MyDataCheck 项目的接口数据对比模块增加了灵活的接口参数配置功能,支持:

✅ **任意数量的接口参数** - 不再限制为固定的 custNo 和 baseTime  
✅ **自定义参数名称** - 参数名称可以根据实际接口需求自定义  
✅ **灵活的列索引映射** - 每个参数可以指定从 CSV 文件的哪一列读取  
✅ **时间字段标记** - 可以标记哪些参数是时间字段,系统会自动进行格式标准化  
✅ **向后兼容** - 完全兼容旧的 column_config 配置格式  

---

## 已修改的文件

### 1. 后端代码

#### `MyDataCheck/api_comparison/job/fetch_api_data.py`
- ✅ 修改 `ApiDataFetcher.__init__()` - 添加 `api_params` 参数支持
- ✅ 修改 `send_request()` - 支持动态参数字典
- ✅ 修改 `process_row()` - 根据 api_params 配置动态构建请求参数
- ✅ 修改第一条请求调试信息输出 - 支持动态参数显示

#### `MyDataCheck/api_comparison/job/process_executor.py`
- ✅ 修改 `fetch_api_data_step()` - 添加 `api_params` 参数传递
- ✅ 修改 `execute_single_scenario()` - 从配置中读取 api_params 并传递

### 2. 配置文件

#### `MyDataCheck/api_comparison/config_example_with_dynamic_params.json`
- ✅ 新增配置示例文件,展示各种参数配置场景

### 3. 文档和测试

#### `MyDataCheck/WEB_UPDATE_GUIDE.md`
- ✅ Web 界面更新指南,详细说明如何修改 HTML 界面

#### `MyDataCheck/test_dynamic_params.py`
- ✅ 测试脚本,验证动态参数配置功能

#### `MyDataCheck/DYNAMIC_PARAMS_FEATURE.md`
- ✅ 本文档,功能说明和使用指南

---

## 配置格式

### 新格式 (推荐)

```json
{
  "scenarios": [
    {
      "name": "场景名称",
      "api_url": "http://example.com/api",
      "api_params": [
        {
          "param_name": "custNo",
          "column_index": 0,
          "is_time_field": false
        },
        {
          "param_name": "baseTime",
          "column_index": 2,
          "is_time_field": true
        }
      ],
      "column_config": {
        "feature_start_column": 3
      }
    }
  ]
}
```

### 旧格式 (仍然支持)

```json
{
  "scenarios": [
    {
      "name": "场景名称",
      "api_url": "http://example.com/api",
      "column_config": {
        "cust_no_column": 0,
        "use_create_time_column": 2,
        "feature_start_column": 3
      }
    }
  ]
}
```

---

## 使用场景

### 场景 1: 双参数接口 (custNo + baseTime)

**配置:**
```json
"api_params": [
  {"param_name": "custNo", "column_index": 0, "is_time_field": false},
  {"param_name": "baseTime", "column_index": 2, "is_time_field": true}
]
```

**CSV 文件:**
```
cust_no,apply_id,use_create_time,feature1,feature2
800001054335,123456,2025-01-19 10:30:00,value1,value2
```

**接口请求:**
```json
{
  "custNo": "800001054335",
  "baseTime": "2025-01-19T10:30:00.000"
}
```

---

### 场景 2: 单参数接口 (只有 applyId)

**配置:**
```json
"api_params": [
  {"param_name": "applyId", "column_index": 1, "is_time_field": false}
]
```

**CSV 文件:**
```
cust_no,apply_id,feature1,feature2
800001054335,123456,value1,value2
```

**接口请求:**
```json
{
  "applyId": "123456"
}
```

---

### 场景 3: 三参数接口 (custNo + applyId + baseTime)

**配置:**
```json
"api_params": [
  {"param_name": "custNo", "column_index": 0, "is_time_field": false},
  {"param_name": "applyId", "column_index": 1, "is_time_field": false},
  {"param_name": "baseTime", "column_index": 3, "is_time_field": true}
]
```

**CSV 文件:**
```
cust_no,apply_id,order_id,use_create_time,feature1,feature2
800001054335,123456,789,2025-01-19 10:30:00,value1,value2
```

**接口请求:**
```json
{
  "custNo": "800001054335",
  "applyId": "123456",
  "baseTime": "2025-01-19T10:30:00.000"
}
`