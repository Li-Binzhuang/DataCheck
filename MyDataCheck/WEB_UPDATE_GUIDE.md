# Web 界面更新指南 - 支持动态接口参数配置

## 修改说明

为了支持灵活的接口参数配置（参数名称和数量可自定义），需要对 `templates/index.html` 进行以下修改:

### 1. 在场景配置卡片中添加"接口参数配置"部分

在 `<div class="column-config">` 之前添加新的参数配置区域:

```html
<!-- 接口参数配置（新增） -->
<div class="api-params-config">
    <h4>接口参数配置 
        <button class="btn-small btn-success" onclick="addApiParam('${scenarioId}')" style="float: right;">➕ 添加参数</button>
    </h4>
    <div class="api-params-list" id="api-params-${scenarioId}">
        ${scenario.api_params ? scenario.api_params.map((param, index) => `
            <div class="api-param-item" data-param-index="${index}">
                <div class="form-row">
                    <div class="form-group" style="flex: 2;">
                        <label>参数名称:</label>
                        <input type="text" class="param-name" value="${param.param_name}" placeholder="如: custNo">
                    </div>
                    <div class="form-group" style="flex: 1;">
                        <label>列索引:</label>
                        <input type="number" class="param-column" value="${param.column_index}" min="0">
                    </div>
                    <div class="form-group" style="flex: 1;">
                        <label style="display: flex; align-items: center;">
                            <input type="checkbox" class="param-is-time" ${param.is_time_field ? 'checked' : ''} style="margin-right: 5px;">
                            时间字段
                        </label>
                    </div>
                    <div class="form-group" style="flex: 0.5;">
                        <button class="btn-small btn-danger" onclick="removeApiParam('${scenarioId}', ${index})" style="margin-top: 20px;">🗑️</button>
                    </div>
                </div>
            </div>
        `).join('') : `
            <div class="api-param-item" data-param-index="0">
                <div class="form-row">
                    <div class="form-group" style="flex: 2;">
                        <label>参数名称:</label>
                        <input type="text" class="param-name" value="custNo" placeholder="如: custNo">
                    </div>
                    <div class="form-group" style="flex: 1;">
                        <label>列索引:</label>
                        <input type="number" class="param-column" value="0" min="0">
                    </div>
                    <div class="form-group" style="flex: 1;">
                        <label style="display: flex; align-items: center;">
                            <input type="checkbox" class="param-is-time" style="margin-right: 5px;">
                            时间字段
                        </label>
                    </div>
                    <div class="form-group" style="flex: 0.5;">
                        <button class="btn-small btn-danger" onclick="removeApiParam('${scenarioId}', 0)" style="margin-top: 20px;">🗑️</button>
                    </div>
                </div>
            </div>
            <div class="api-param-item" data-param-index="1">
                <div class="form-row">
                    <div class="form-group" style="flex: 2;">
                        <label>参数名称:</label>
                        <input type="text" class="param-name" value="baseTime" placeholder="如: baseTime">
                    </div>
                    <div class="form-group" style="flex: 1;">
                        <label>列索引:</label>
                        <input type="number" class="param-column" value="2" min="0">
                    </div>
                    <div class="form-group" style="flex: 1;">
                        <label style="display: flex; align-items: center;">
                            <input type="checkbox" class="param-is-time" checked style="margin-right: 5px;">
                            时间字段
                        </label>
                    </div>
                    <div class="form-group" style="flex: 0.5;">
                        <button class="btn-small btn-danger" onclick="removeApiParam('${scenarioId}', 1)" style="margin-top: 20px;">🗑️</button>
                    </div>
                </div>
            </div>
        `}
    </div>
    <p style="color: #666; font-size: 11px; margin-top: 8px;">
        💡 提示: 参数名称对应接口入参字段名，列索引指定从CSV文件的哪一列读取该参数的值。勾选"时间字段"会对该参数进行时间格式标准化处理。
    </p>
</div>
```

### 2. 添加 CSS 样式

在 `<style>` 标签中添加:

```css
.api-params-config {
    background: #fff3cd;
    padding: 12px;
    border-radius: 6px;
    margin-bottom: 12px;
    border: 1px solid #ffc107;
}

.api-params-config h4 {
    font-size: 13px;
    margin-bottom: 8px;
    color: #856404;
}

.api-param-item {
    background: white;
    padding: 8px;
    border-radius: 4px;
    margin-bottom: 8px;
    border: 1px solid #e0e0e0;
}

.btn-small {
    padding: 4px 8px;
    font-size: 11px;
    border: none;
    border-radius: 4px;
    cursor: pointer;
    transition: all 0.3s;
}

.btn-small.btn-success {
    background: #28a745;
    color: white;
}

.btn-small.btn-success:hover {
    background: #218838;
}

.btn-small.btn-danger {
    background: #dc3545;
    color: white;
}

.btn-small.btn-danger:hover {
    background: #c82333;
}
```

### 3. 添加 JavaScript 函数

在 `<script>` 标签中添加以下函数:

```javascript
// 添加接口参数
function addApiParam(scenarioId) {
    const container = document.getElementById(`api-params-${scenarioId}`);
    const paramItems = container.querySelectorAll('.api-param-item');
    const newIndex = paramItems.length;
    
    const newParamHtml = `
        <div class="api-param-item" data-param-index="${newIndex}">
            <div class="form-row">
                <div class="form-group" style="flex: 2;">
                    <label>参数名称:</label>
                    <input type="text" class="param-name" value="" placeholder="如: applyId">
                </div>
                <div class="form-group" style="flex: 1;">
                    <label>列索引:</label>
                    <input type="number" class="param-column" value="0" min="0">
                </div>
                <div class="form-group" style="flex: 1;">
                    <label style="display: flex; align-items: center;">
                        <input type="checkbox" class="param-is-time" style="margin-right: 5px;">
                        时间字段
                    </label>
                </div>
                <div class="form-group" style="flex: 0.5;">
                    <button class="btn-small btn-danger" onclick="removeApiParam('${scenarioId}', ${newIndex})" style="margin-top: 20px;">🗑️</button>
                </div>
            </div>
        </div>
    `;
    
    container.insertAdjacentHTML('beforeend', newParamHtml);
}

// 删除接口参数
function removeApiParam(scenarioId, paramIndex) {
    const container = document.getElementById(`api-params-${scenarioId}`);
    const paramItems = container.querySelectorAll('.api-param-item');
    
    // 至少保留一个参数
    if (paramItems.length <= 1) {
        alert('至少需要保留一个接口参数');
        return;
    }
    
    const paramItem = container.querySelector(`[data-param-index="${paramIndex}"]`);
    if (paramItem) {
        paramItem.remove();
        
        // 重新编号
        const remainingItems = container.querySelectorAll('.api-param-item');
        remainingItems.forEach((item, index) => {
            item.setAttribute('data-param-index', index);
            const deleteBtn = item.querySelector('.btn-danger');
            if (deleteBtn) {
                deleteBtn.setAttribute('onclick', `removeApiParam('${scenarioId}', ${index})`);
            }
        });
    }
}
```

### 4. 修改 saveConfig() 函数

在收集场景配置时，添加接口参数的收集逻辑:

```javascript
// 在 saveConfig() 函数中，收集场景配置时添加:

// 收集接口参数配置
const apiParamsList = card.querySelector('.api-params-list');
const apiParams = [];
if (apiParamsList) {
    const paramItems = apiParamsList.querySelectorAll('.api-param-item');
    paramItems.forEach(item => {
        const paramName = item.querySelector('.param-name').value.trim();
        const columnIndex = parseInt(item.querySelector('.param-column').value);
        const isTimeField = item.querySelector('.param-is-time').checked;
        
        if (paramName) {  // 只添加有参数名的配置
            apiParams.push({
                param_name: paramName,
                column_index: columnIndex,
                is_time_field: isTimeField
            });
        }
    });
}

// 在场景配置对象中添加:
if (apiParams.length > 0) {
    scenarioConfig.api_params = apiParams;
}
```

## 配置文件示例

更新后的 `config.json` 示例:

```json
{
  "scenarios": [
    {
      "name": "双参数接口",
      "enabled": true,
      "input_csv_file": "test.csv",
      "output_file_prefix": "test",
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
    },
    {
      "name": "单参数接口",
      "enabled": true,
      "input_csv_file": "test2.csv",
      "output_file_prefix": "test2",
      "api_url": "http://example.com/api2",
      "api_params": [
        {
          "param_name": "applyId",
          "column_index": 1,
          "is_time_field": false
        }
      ],
      "column_config": {
        "feature_start_column": 2
      }
    }
  ]
}
```

## 向后兼容

如果配置文件中没有 `api_params` 字段，系统会自动使用旧的 `column_config` 中的 `cust_no_column` 和 `use_create_time_column` 来构建默认的参数配置。

## 测试建议

1. 测试双参数接口（custNo + baseTime）
2. 测试单参数接口（只有 applyId）
3. 测试三参数接口（custNo + applyId + baseTime）
4. 测试时间字段的标准化处理
5. 测试参数的添加和删除功能
