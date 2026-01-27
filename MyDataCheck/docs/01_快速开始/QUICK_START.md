# MyDataCheck - 快速开始指南

## 问题解决 ✅

### 原始错误
```
ModuleNotFoundError: No module named 'requests'
```

### 解决方案
已更新 `requirements.txt` 并安装所需依赖:

```bash
pip install Flask requests
```

## 验证安装

运行测试脚本验证所有模块:

```bash
python MyDataCheck/test_import.py
```

预期输出:
```
✅ flask.Flask
✅ requests
✅ api_comparison.job.fetch_api_data.ApiDataFetcher
✅ api_comparison.job.process_executor.execute_single_scenario
✅ api_comparison.job.compare_api_data.DataComparator
✅ common.csv_tool.read_csv_with_encoding
✅ common.value_comparator.compare_values

✅ 所有模块导入成功!
```

## 启动 Web 服务

```bash
cd MyDataCheck
python web_app.py
```

或使用启动脚本:

```bash
./start_web.sh
```

访问: http://localhost:5000

## 新功能 - 动态接口参数配置

### 功能特性

✅ **任意数量参数** - 支持 1 个、2 个或多个参数  
✅ **自定义参数名** - 参数名称可自定义（如 custNo, applyId, baseTime）  
✅ **灵活列映射** - 每个参数可指定从 CSV 的哪一列读取  
✅ **时间字段标记** - 自动进行时间格式标准化  
✅ **向后兼容** - 完全兼容旧的 column_config 格式  

### 配置示例

#### 单参数接口
```json
{
  "api_params": [
    {
      "param_name": "applyId",
      "column_index": 1,
      "is_time_field": false
    }
  ]
}
```

#### 双参数接口 (默认)
```json
{
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
  ]
}
```

#### 三参数接口
```json
{
  "api_params": [
    {
      "param_name": "custNo",
      "column_index": 0,
      "is_time_field": false
    },
    {
      "param_name": "applyId",
      "column_index": 1,
      "is_time_field": false
    },
    {
      "param_name": "baseTime",
      "column_index": 3,
      "is_time_field": true
    }
  ]
}
```

### 测试新功能

```bash
python MyDataCheck/test_dynamic_params.py
```

## 文件说明

- `requirements.txt` - Python 依赖列表
- `test_import.py` - 模块导入测试脚本
- `test_dynamic_params.py` - 动态参数功能测试脚本
- `INSTALL.md` - 详细安装指南
- `FEATURE_SUMMARY.md` - 新功能总结
- `WEB_UPDATE_GUIDE.md` - Web 界面更新指南

## 下一步

1. ✅ 后端代码已完成并测试通过
2. ⏳ Web 界面需要手动更新（参考 `WEB_UPDATE_GUIDE.md`）
3. ✅ 配置示例已提供（`config_example_with_dynamic_params.json`）

## 常见问题

### Q: 如何使用新的参数配置?

在 `api_comparison/config.json` 中添加 `api_params` 字段:

```json
{
  "scenarios": [
    {
      "name": "我的场景",
      "api_params": [
        {"param_name": "custNo", "column_index": 0, "is_time_field": false},
        {"param_name": "baseTime", "column_index": 2, "is_time_field": true}
      ]
    }
  ]
}
```

### Q: 旧配置还能用吗?

可以!系统会自动将旧的 `column_config` 转换为新格式:

```json
{
  "column_config": {
    "cust_no_column": 0,
    "use_create_time_column": 2
  }
}
```

会自动转换为:

```json
{
  "api_params": [
    {"param_name": "custNo", "column_index": 0, "is_time_field": false},
    {"param_name": "baseTime", "column_index": 2, "is_time_field": true}
  ]
}
```

## 技术支持

如有问题,请查看:
- `INSTALL.md` - 安装问题
- `FEATURE_SUMMARY.md` - 功能说明
- `WEB_UPDATE_GUIDE.md` - Web 界面更新
