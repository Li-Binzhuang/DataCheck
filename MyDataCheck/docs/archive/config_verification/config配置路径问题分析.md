# MyDataCheck配置文件路径问题分析

## 问题描述

前端Web页面在读取和保存"接口数据校对"配置时，存在路径混乱的问题。

## 当前情况

### 配置文件位置

1. **MyDataCheck/config.json** (根目录)
   - 内容：接口数据校对配置（scenarios格式）
   - 场景：hd_fx_

2. **MyDataCheck/api_comparison/config.json** (正确位置)
   - 内容：接口数据校对配置（scenarios格式）
   - 场景：qx_

3. **MyDataCheck/online_comparison/config.json** (正确位置)
   - 内容：线上灰度落数对比配置
   - 用途：线上灰度落数对比功能

### Web API路由分析

根据 `web_app.py` 的代码：

#### 接口数据校对（API Comparison）
```python
# 加载配置
@app.route('/api/config/load', methods=['GET'])
def load_config():
    config_file_path = os.path.join(script_dir, "api_comparison", "config.json")
    # ✅ 正确：读取 api_comparison/config.json
```

```python
# 保存配置
@app.route('/api/config/save', methods=['POST'])
def save_config():
    config_file_path = os.path.join(script_dir, "api_comparison", "config.json")
    # ✅ 正确：保存到 api_comparison/config.json
```

#### 线上灰度落数对比（Online Comparison）
```python
# 加载配置
@app.route('/api/config/online/load', methods=['GET'])
def load_online_config():
    config_file_path = os.path.join(online_comparison_dir, "config.json")
    # ✅ 正确：读取 online_comparison/config.json
```

```python
# 保存配置
@app.route('/api/config/online/save', methods=['POST'])
def save_online_config():
    config_file_path = os.path.join(online_comparison_dir, "config.json")
    # ✅ 正确：保存到 online_comparison/config.json
```

## 结论

### ✅ Web API路由是正确的！

经过检查，`web_app.py` 中的配置读取和保存路径**完全正确**：

1. **接口数据校对** → `MyDataCheck/api_comparison/config.json`
2. **线上灰度落数对比** → `MyDataCheck/online_comparison/config.json`

### ❓ 根目录的config.json是什么？

`MyDataCheck/config.json` 这个文件可能是：
1. 历史遗留文件（旧版本的配置）
2. 测试文件
3. 备份文件

**它不被Web应用使用！**

## 建议操作

### 方案1：删除根目录的config.json（推荐）

如果确认根目录的config.json不再需要：
```bash
cd MyDataCheck
rm config.json
```

### 方案2：重命名为备份文件

如果想保留作为参考：
```bash
cd MyDataCheck
mv config.json config.json.backup
```

### 方案3：添加说明文档

在根目录创建README说明配置文件位置：
```markdown
# 配置文件说明

- 接口数据校对配置：`api_comparison/config.json`
- 线上灰度落数对比配置：`online_comparison/config.json`
```

## 验证

可以通过以下方式验证：

1. 启动Web服务：`./start_web.sh`
2. 打开浏览器访问Web界面
3. 在"接口数据校对"页面修改配置并保存
4. 检查 `api_comparison/config.json` 是否更新
5. 检查根目录的 `config.json` 是否未变化

## 总结

**Web应用的配置路径是正确的，不需要修改代码。**

根目录的 `config.json` 是冗余文件，建议删除或重命名，以避免混淆。
