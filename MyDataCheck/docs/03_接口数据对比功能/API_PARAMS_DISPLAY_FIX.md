# 接口数据对比 - 入参显示修复说明

## 问题描述

在接口数据对比的输出报告中，`applyId` 和 `request_time` 两列显示的是从CSV文件中读取的原始值，而不是实际发送给接口的参数值。

### 原有行为
- `applyId` 列显示：CSV文件中的原始值
- `request_time` 列显示：CSV文件中的原始值

### 期望行为
- `applyId` 列显示：实际发送给接口的入参值
- `request_time` 列显示：实际发送给接口的入参值（baseTime）

## 修复内容

### 修改文件
- `api_comparison/job/streaming_comparator.py`

### 修改位置
在 `_compare_single_row()` 方法中，修改了获取 `applyId` 和 `request_time` 的逻辑。

### 修改前
```python
# 尝试获取时间字段
use_create_time = request_params.get("baseTime", original_values.get("baseTime", ""))

# 优先从接口入参中获取 applyId
apply_id = original_values.get("applyId", original_values.get("apply_id", ""))
```

### 修改后
```python
# 获取实际发送给接口的时间参数（从request_params中获取）
# 这是接口入参中实际使用的baseTime值
use_create_time = request_params.get("baseTime", "")

# 获取实际发送给接口的applyId参数（从request_params中获取）
# 优先从request_params中获取，这是接口入参中实际使用的值
apply_id = request_params.get("applyId", request_params.get("apply_id", ""))

# 如果request_params中没有，尝试从original_values中获取
if not apply_id:
    apply_id = original_values.get("applyId", original_values.get("apply_id", ""))
```

## 关键改进

1. **优先使用request_params** - 从实际发送给接口的参数中获取值
2. **准确反映入参** - 显示的值是接口实际接收到的参数值
3. **处理参数转换** - 如果参数在发送前进行了转换（如加1秒），会显示转换后的值

## 数据流说明

### 数据处理流程
```
CSV文件 → 读取原始值 → 构建请求参数 → 发送接口 → 获取响应 → 对比 → 输出报告
                                                              ↑
                                                    现在从这里获取参数值
```

### 参数值来源
- **original_values**: CSV文件中读取的原始值
- **request_params**: 实际发送给接口的参数值（可能经过转换）

## 示例

### 场景：baseTime加1秒处理

**CSV文件中的值**
```
baseTime: 2026-03-05 10:00:00
```

**接口配置**
```
add_one_second: true  # 发送接口时加1秒
```

**修改前的输出**
```
request_time: 2026-03-05 10:00:00  (原始值)
```

**修改后的输出**
```
request_time: 2026-03-05 10:00:01  (实际发送给接口的值)
```

## 影响范围

### 受影响的输出文件
- `*_analysis_report.csv` - 分析报告文件

### 受影响的列
- `applyId` 列
- `request_time` 列

### 不受影响的部分
- CSV值列 - 仍然显示原始CSV值
- API值列 - 仍然显示接口返回值
- 差值列 - 计算逻辑不变

## 测试建议

1. **验证参数转换**
   - 配置 `add_one_second: true`
   - 检查输出中的 `request_time` 是否比CSV值晚1秒

2. **验证参数映射**
   - 检查 `applyId` 是否显示实际发送给接口的值
   - 对比接口日志确认参数值一致

3. **验证向后兼容**
   - 不配置参数转换时，值应该与CSV相同
   - 其他列的值应该保持不变

## 相关配置

### 参数配置示例
```json
{
  "params": [
    {
      "param_name": "baseTime",
      "column_index": 3,
      "is_time_field": true,
      "add_one_second": true
    },
    {
      "param_name": "applyId",
      "column_index": 1
    }
  ]
}
```

## 常见问题

### Q: 为什么request_time和CSV中的值不同？
A: 这是正常的。如果配置了 `add_one_second: true`，接口会收到加1秒后的值。输出报告现在显示的是实际发送给接口的值。

### Q: 如何验证修改是否生效？
A: 对比接口日志和输出报告中的参数值，应该一致。

### Q: 这个修改会影响对比结果吗？
A: 不会。只是改变了输出报告中显示的参数值，对比逻辑和结果不变。

## 版本信息

- **修改日期**: 2026-03-05
- **修改文件**: api_comparison/job/streaming_comparator.py
- **修改方法**: _compare_single_row()
- **影响版本**: v2.0+

---

**说明**: 此修改确保输出报告中显示的参数值与实际发送给接口的参数值一致，便于调试和验证。
