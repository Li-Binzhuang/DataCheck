# JSON配置文件说明

## 文件列表

### 1. `执行配置.json` - 主配置文件

**用途**：定义所有数据对比场景的参数配置

**结构**：
```json
{
  "scenarios": [
    {
      "name": "场景名称",
      "enabled": true,
      "input_csv_file": "输入文件.csv",
      "api_url": "接口URL",
      ...
    }
  ],
  "global_config": {
    "default_thread_count": 150,
    ...
  }
}
```

**特点**：
- ✅ 支持多场景配置
- ✅ 每个场景可独立启用/禁用（`enabled` 字段）
- ✅ 场景未指定的参数会使用全局默认值
- ✅ 集中管理所有配置，无需修改代码

**使用方式**：
1. 编辑此文件，添加你的场景配置
2. 设置 `enabled: true` 启用场景，`false` 禁用场景
3. 运行 `执行对比流程.py` 执行所有启用的场景

---

### 2. `列索引配置.json` - 列索引缓存文件

**用途**：存储所有场景自动检测到的列索引配置

**结构**：
```json
{
  "说明": {
    "文件用途": "存储所有场景的列索引配置（自动检测结果）",
    ...
  },
  "scenarios": {
    "场景1名称": {
      "cust_no_column": 0,
      "use_create_time_column": 2,
      "feature_start_column": 3,
      "last_updated": "2026-01-08 16:00:00",
      "input_file": "输入文件.csv"
    },
    "场景2名称": {
      ...
    }
  }
}
```

**特点**：
- ✅ 统一的多场景格式（所有场景在一个文件中）
- ✅ 自动生成和维护（无需手动编辑）
- ✅ 记录更新时间，便于追踪
- ✅ 按场景名称组织，互不干扰

**生成时机**：
- 当 `执行配置.json` 中 `auto_detect_columns: true` 时
- 每次执行会自动检测并更新对应场景的配置

**注意事项**：
- ⚠️ 此文件由系统自动生成，通常不需要手动编辑
- ⚠️ 如果CSV文件结构发生变化，需要删除对应场景的配置或重新运行检测

---

## 多场景配置示例

### 示例1：启用多个场景

```json
{
  "scenarios": [
    {
      "name": "qx_0108数据对比",
      "enabled": true,
      "input_csv_file": "qx_0108_sqldata.csv",
      "api_url": "http://api.example.com/endpoint1"
    },
    {
      "name": "test_001数据对比",
      "enabled": true,
      "input_csv_file": "test_001.csv",
      "api_url": "http://api.example.com/endpoint2"
    }
  ]
}
```

**执行结果**：两个场景都会执行

---

### 示例2：部分场景禁用

```json
{
  "scenarios": [
    {
      "name": "场景1",
      "enabled": true,
      ...
    },
    {
      "name": "场景2",
      "enabled": false,  // 禁用此场景
      ...
    }
  ]
}
```

**执行结果**：只执行场景1，场景2会被跳过

---

### 示例3：使用全局默认值

```json
{
  "scenarios": [
    {
      "name": "场景1",
      "enabled": true,
      "input_csv_file": "file1.csv",
      "api_url": "http://api.example.com/endpoint"
      // thread_count 和 timeout 未指定，使用全局默认值
    }
  ],
  "global_config": {
    "default_thread_count": 150,
    "default_timeout": 60
  }
}
```

**执行结果**：场景1使用150线程和60秒超时

---

## 文件关系

```
执行配置.json
    ↓ (定义场景)
    ├─ 场景1: qx_0108数据对比
    │   └─ auto_detect_columns: true
    │       └─ 自动检测列索引
    │           └─ 保存到 → 列索引配置.json (scenarios.qx_0108数据对比)
    │
    └─ 场景2: test_001数据对比
        └─ auto_detect_columns: false
            └─ 使用执行配置.json中的column_config
```

---

## 常见问题

### Q1: 如何添加新场景？
A: 在 `执行配置.json` 的 `scenarios` 数组中添加新的场景对象，设置 `enabled: true` 即可。

### Q2: 列索引配置会自动更新吗？
A: 是的。当 `auto_detect_columns: true` 时，每次执行都会自动检测并更新 `列索引配置.json` 中对应场景的配置。

### Q3: 可以手动编辑列索引配置吗？
A: 可以，但不推荐。建议通过设置 `auto_detect_columns: false` 并在 `执行配置.json` 中手动指定 `column_config`。

### Q4: 如何删除某个场景的列索引配置？
A: 直接编辑 `列索引配置.json`，删除 `scenarios` 对象中对应的场景键值对即可。

### Q5: 多个场景可以使用同一个CSV文件吗？
A: 可以，但每个场景需要有不同的 `name`，列索引配置会按场景名称分别保存。

---

## 参考文件

- `配置模板.json` - 详细的配置模板和字段说明
- `执行对比流程.py` - 主执行脚本
