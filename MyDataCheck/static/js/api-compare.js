// ========== 接口数据对比相关函数 ==========

// 添加场景
function addScenario(scenarioData = null, isFirst = false) {
    scenarioCount++;
    const scenarioId = `scenario_${scenarioCount}`;
    const container = document.getElementById('scenarios-container');

    const scenario = scenarioData || {
        name: `场景${scenarioCount}`,
        enabled: true,
        description: '',
        input_csv_file: '',
        output_file_prefix: '',
        api_url: '',
        convert_feature_to_number: true,
        add_one_second: true,
        column_config: {
            cust_no_column: 0,
            use_create_time_column: 2,
            feature_start_column: 3
        }
    };

    const isFirstScenario = isFirst || (scenarioCount === 1 && !scenarioData);
    const deleteButton = isFirstScenario ? '' : `<button class="btn-icon btn-delete" onclick="removeScenario('${scenarioId}')">删除</button>`;

    const card = document.createElement('div');
    card.className = `scenario-card ${scenario.enabled ? 'enabled' : ''}`;
    card.id = scenarioId;
    card.innerHTML = `
        <div class="scenario-header" onclick="toggleScenarioCollapse('${scenarioId}')">
            <div style="display: flex; align-items: center; flex: 1;">
                <div class="scenario-title">
                    <input type="text" class="scenario-name-input" value="${scenario.name}" 
                           placeholder="场景名称"
                           onclick="event.stopPropagation();"
                           onkeydown="event.stopPropagation();"
                           onkeyup="event.stopPropagation();"
                           onkeypress="event.stopPropagation();"
                           onfocus="event.stopPropagation();"
                           onblur="event.stopPropagation();">
                </div>
                <button class="scenario-toggle-btn" id="toggle-btn-${scenarioId}" onclick="event.stopPropagation(); toggleScenarioCollapse('${scenarioId}')" title="展开/收起">▼</button>
            </div>
            <div class="scenario-actions" onclick="event.stopPropagation();">
                <div class="checkbox-group">
                    <input type="checkbox" class="scenario-enabled" ${scenario.enabled ? 'checked' : ''} 
                           onchange="toggleScenario('${scenarioId}')">
                    <label style="margin: 0;">启用</label>
                </div>
                ${deleteButton}
            </div>
        </div>
        
        <div class="scenario-content" id="scenario-content-${scenarioId}">
        <div class="form-group">
            <label>描述:</label>
            <input type="text" class="scenario-description" value="${scenario.description}" placeholder="场景描述">
        </div>

        <div class="form-group">
            <label>输入CSV/PKL文件:</label>
            <input type="file" class="scenario-file-input" accept=".csv,.pkl" 
                   onchange="handleFileSelect('${scenarioId}', this)">
            <input type="hidden" class="scenario-filename" value="${scenario.input_csv_file}">
            <div class="file-info" id="file-info-${scenarioId}" style="margin-top: 8px; padding: 8px; background: #f8f9fa; border-radius: 4px;">
                ${scenario.input_csv_file ? `当前文件: ${scenario.input_csv_file}` : '未选择文件（支持CSV和PKL文件，PKL将自动转换为CSV）'}
            </div>
        </div>

        <div class="form-row">
            <div class="form-group">
                <label>输出文件前缀:</label>
                <input type="text" class="scenario-output-prefix" value="${scenario.output_file_prefix}" placeholder="输出文件前缀">
            </div>
            <div class="form-group">
                <label>API地址:</label>
                <input type="url" class="scenario-api-url" value="${scenario.api_url}" 
                       placeholder="http://example.com/api">
            </div>
        </div>

        <div class="form-group">
            <div class="checkbox-group">
                <input type="checkbox" class="scenario-convert-feature" ${scenario.convert_feature_to_number ? 'checked' : ''}>
                <label style="margin: 0;">转换特征值为数值</label>
            </div>
        </div>

        <div class="form-group">
            <div class="checkbox-group">
                <input type="checkbox" class="scenario-add-one-second" ${scenario.add_one_second ? 'checked' : ''}>
                <label style="margin: 0;">请求接口时时间加1秒</label>
            </div>
        </div>

        <div class="form-group">
            <div class="checkbox-group">
                <input type="checkbox" class="scenario-calculate-difference" ${scenario.calculate_difference === false ? '' : ''}>
                <label style="margin: 0;">计算差值（CSV值 - API值）</label>
            </div>
        </div>

        <!-- 接口参数配置 -->
        <div class="api-params-config">
            <h4>接口参数配置 
                <button class="btn-small btn-success" onclick="addApiParam('${scenarioId}')" style="float: right;">➕ 添加参数</button>
            </h4>
            <div class="api-params-list" id="api-params-${scenarioId}">
                ${scenario.api_params && scenario.api_params.length > 0 ? scenario.api_params.map((param, index) => `
                    <div class="api-param-item" data-param-index="${index}">
                        <div class="form-row">
                            <div class="form-group" style="flex: 2;">
                                <label>参数名称:</label>
                                <input type="text" class="param-name" value="${param.param_name || ''}" placeholder="如: custNo, applyId">
                            </div>
                            <div class="form-group" style="flex: 1;">
                                <label>列索引:</label>
                                <input type="number" class="param-column" value="${param.column_index !== undefined ? param.column_index : ''}" min="0" placeholder="留空则不传">
                            </div>
                            <div class="form-group" style="flex: 1;">
                                <label style="display: flex; align-items: center;">
                                    <input type="checkbox" class="param-is-time" ${param.is_time_field ? 'checked' : ''} style="margin-right: 5px;" onchange="toggleTSeparator('${scenarioId}', ${index})">
                                    时间字段
                                </label>
                            </div>
                            <div class="form-group" style="flex: 1;">
                                <label style="display: flex; align-items: center;">
                                    <input type="checkbox" class="param-add-t-separator" ${param.add_t_separator !== false ? 'checked' : ''} ${param.is_time_field ? '' : 'disabled'} style="margin-right: 5px;">
                                    加T分隔符
                                </label>
                            </div>
                            <div class="form-group" style="flex: 1;">
                                <label style="display: flex; align-items: center;">
                                    <input type="checkbox" class="param-convert-date-to-time" ${param.convert_date_to_time !== false ? 'checked' : ''} ${param.is_time_field ? '' : 'disabled'} style="margin-right: 5px;">
                                    日期转时间
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
                                <input type="text" class="param-name" value="custNo" placeholder="如: custNo, applyId">
                            </div>
                            <div class="form-group" style="flex: 1;">
                                <label>列索引:</label>
                                <input type="number" class="param-column" value="0" min="0" placeholder="留空则不传">
                            </div>
                            <div class="form-group" style="flex: 1;">
                                <label style="display: flex; align-items: center;">
                                    <input type="checkbox" class="param-is-time" style="margin-right: 5px;" onchange="toggleTSeparator('${scenarioId}', 0)">
                                    时间字段
                                </label>
                            </div>
                            <div class="form-group" style="flex: 1;">
                                <label style="display: flex; align-items: center;">
                                    <input type="checkbox" class="param-add-t-separator" checked disabled style="margin-right: 5px;">
                                    加T分隔符
                                </label>
                            </div>
                            <div class="form-group" style="flex: 1;">
                                <label style="display: flex; align-items: center;">
                                    <input type="checkbox" class="param-convert-date-to-time" checked disabled style="margin-right: 5px;">
                                    日期转时间
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
                                <input type="text" class="param-name" value="baseTime" placeholder="如: custNo, applyId">
                            </div>
                            <div class="form-group" style="flex: 1;">
                                <label>列索引:</label>
                                <input type="number" class="param-column" value="2" min="0" placeholder="留空则不传">
                            </div>
                            <div class="form-group" style="flex: 1;">
                                <label style="display: flex; align-items: center;">
                                    <input type="checkbox" class="param-is-time" checked style="margin-right: 5px;" onchange="toggleTSeparator('${scenarioId}', 1)">
                                    时间字段
                                </label>
                            </div>
                            <div class="form-group" style="flex: 1;">
                                <label style="display: flex; align-items: center;">
                                    <input type="checkbox" class="param-add-t-separator" checked style="margin-right: 5px;">
                                    加T分隔符
                                </label>
                            </div>
                            <div class="form-group" style="flex: 1;">
                                <label style="display: flex; align-items: center;">
                                    <input type="checkbox" class="param-convert-date-to-time" checked style="margin-right: 5px;">
                                    日期转时间
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
                💡 提示: 参数名称对应接口入参字段名，列索引指定从CSV文件的哪一列读取该参数的值。<strong>列索引留空则该参数不作为入参传递。</strong>勾选"时间字段"会对该参数进行时间格式标准化处理。"日期转时间"选项控制是否将日期格式（如：2025-01-01、2025/01/01、20250101）自动转换为时间格式（添加00:00:00.000）。"加T分隔符"选项控制时间格式中日期和时间之间是否使用T分隔符（如：2025-01-01T12:00:00.000 或 2025-01-01 12:00:00.000）。
            </p>
        </div>

        <!-- 特征列配置 -->
        <div class="column-config">
            <h4>特征列配置</h4>
            <div class="form-row">
                <div class="form-group">
                    <label>特征起始列索引:</label>
                    <input type="number" class="scenario-feature-column" value="${scenario.column_config ? scenario.column_config.feature_start_column : 3}" min="0">
                </div>
            </div>
        </div>
        </div>
    `;

    container.appendChild(card);

    const nameInput = card.querySelector('.scenario-name-input');
    if (nameInput) {
        // 确保输入框可以正常获得焦点和编辑
        nameInput.addEventListener('mousedown', function (e) {
            e.stopPropagation();
        });

        nameInput.addEventListener('focus', function (e) {
            e.stopPropagation();
            // 不自动选中，让用户可以正常编辑
        });
    }
}

function toggleScenario(scenarioId) {
    const card = document.getElementById(scenarioId);
    const enabled = card.querySelector('.scenario-enabled').checked;
    if (enabled) {
        card.classList.add('enabled');
    } else {
        card.classList.remove('enabled');
    }
}

// 添加接口参数
function addApiParam(scenarioId) {
    const container = document.getElementById(`api-params-${scenarioId}`);
    if (!container) return;

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
                    <input type="number" class="param-column" value="" min="0" placeholder="留空则不传">
                </div>
                <div class="form-group" style="flex: 1;">
                    <label style="display: flex; align-items: center;">
                        <input type="checkbox" class="param-is-time" style="margin-right: 5px;" onchange="toggleTSeparator('${scenarioId}', ${newIndex})">
                        时间字段
                    </label>
                </div>
                <div class="form-group" style="flex: 1;">
                    <label style="display: flex; align-items: center;">
                        <input type="checkbox" class="param-add-t-separator" checked disabled style="margin-right: 5px;">
                        加T分隔符
                    </label>
                </div>
                <div class="form-group" style="flex: 1;">
                    <label style="display: flex; align-items: center;">
                        <input type="checkbox" class="param-convert-date-to-time" checked disabled style="margin-right: 5px;">
                        日期转时间
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
// 切换T分隔符和日期转换复选框的启用/禁用状态
function toggleTSeparator(scenarioId, paramIndex) {
    const container = document.getElementById(`api-params-${scenarioId}`);
    if (!container) return;

    const paramItem = container.querySelector(`[data-param-index="${paramIndex}"]`);
    if (!paramItem) return;

    const isTimeField = paramItem.querySelector('.param-is-time')?.checked || false;
    const tSeparatorCheckbox = paramItem.querySelector('.param-add-t-separator');
    const convertDateCheckbox = paramItem.querySelector('.param-convert-date-to-time');

    if (tSeparatorCheckbox) {
        // 如果时间字段被勾选，启用T分隔符复选框；否则禁用
        tSeparatorCheckbox.disabled = !isTimeField;
        // 如果禁用，保持当前值；如果启用且之前未设置，默认勾选
        if (!isTimeField) {
            // 禁用时，保持当前值不变
        } else if (!tSeparatorCheckbox.hasAttribute('data-initialized')) {
            // 首次启用时，默认勾选
            tSeparatorCheckbox.checked = true;
            tSeparatorCheckbox.setAttribute('data-initialized', 'true');
        }
    }

    if (convertDateCheckbox) {
        // 如果时间字段被勾选，启用日期转换复选框；否则禁用
        convertDateCheckbox.disabled = !isTimeField;
        // 如果禁用，保持当前值；如果启用且之前未设置，默认勾选
        if (!isTimeField) {
            // 禁用时，保持当前值不变
        } else if (!convertDateCheckbox.hasAttribute('data-initialized')) {
            // 首次启用时，默认勾选
            convertDateCheckbox.checked = true;
            convertDateCheckbox.setAttribute('data-initialized', 'true');
        }
    }
}

function removeApiParam(scenarioId, paramIndex) {
    const container = document.getElementById(`api-params-${scenarioId}`);
    if (!container) return;

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
            // 更新 toggleTSeparator 的调用
            const timeCheckbox = item.querySelector('.param-is-time');
            if (timeCheckbox) {
                timeCheckbox.setAttribute('onchange', `toggleTSeparator('${scenarioId}', ${index})`);
            }
        });
    }
}

// 切换场景卡片的展开/收起状态（接口数据对比）
function toggleScenarioCollapse(scenarioId) {
    const content = document.getElementById(`scenario-content-${scenarioId}`);
    const toggleBtn = document.getElementById(`toggle-btn-${scenarioId}`);
    const card = document.getElementById(scenarioId);

    if (!content || !toggleBtn || !card) return;

    if (content.classList.contains('collapsed')) {
        // 展开
        content.classList.remove('collapsed');
        card.classList.remove('collapsed');
        // 获取实际高度并设置
        const actualHeight = content.scrollHeight;
        content.style.maxHeight = actualHeight + 'px';
        // 动画完成后，移除内联样式，让CSS控制
        setTimeout(() => {
            content.style.maxHeight = '';
        }, 300);
        toggleBtn.textContent = '▼';
        toggleBtn.classList.remove('collapsed');
    } else {
        // 收起
        const currentHeight = content.scrollHeight;
        content.style.maxHeight = currentHeight + 'px';
        // 强制重排
        content.offsetHeight;
        setTimeout(() => {
            content.style.maxHeight = '0px';
            content.classList.add('collapsed');
            card.classList.add('collapsed');
            toggleBtn.textContent = '▶';
            toggleBtn.classList.add('collapsed');
        }, 10);
    }
}

async function removeScenario(scenarioId) {
    if (confirm('确定要删除这个场景吗？')) {
        // 先获取要删除的场景名称（用于调试）
        const cardToRemove = document.getElementById(scenarioId);
        const scenarioName = cardToRemove ? cardToRemove.querySelector('.scenario-name-input')?.value || scenarioId : scenarioId;

        // 删除DOM元素
        cardToRemove.remove();

        // 更新剩余场景的删除按钮显示
        const container = document.getElementById('scenarios-container');
        const remainingCards = container ? container.querySelectorAll('.scenario-card') : [];
        if (remainingCards.length === 1) {
            const firstCard = remainingCards[0];
            const actionsDiv = firstCard.querySelector('.scenario-actions');
            const deleteBtn = actionsDiv.querySelector('.btn-delete');
            if (deleteBtn) {
                deleteBtn.remove();
            }
        }

        // 等待DOM更新完成
        await new Promise(resolve => setTimeout(resolve, 100));

        // 自动保存配置
        try {
            const config = collectConfig();

            if (config.scenarios.length === 0) {
                showAlert('至少需要添加一个场景', 'error', 'api');
                return;
            }

            // 验证收集的场景数量
            console.log(`删除场景 "${scenarioName}" 后，剩余场景数: ${config.scenarios.length}`);
            console.log('剩余场景名称:', config.scenarios.map(s => s.name));

            const response = await fetch('/api/config/save', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ config: config })
            });

            const data = await response.json();

            if (data.success) {
                showAlert(`场景 "${scenarioName}" 已删除，配置已保存（剩余 ${config.scenarios.length} 个场景）`, 'success', 'api');
            } else {
                showAlert('场景已删除，但保存配置失败: ' + data.error, 'error', 'api');
            }
        } catch (error) {
            showAlert('场景已删除，但保存配置失败: ' + error.message, 'error', 'api');
            console.error('删除场景后保存配置失败:', error);
        }
    }
}

async function handleFileSelect(scenarioId, input) {
    const file = input.files[0];
    if (!file) return;

    // 支持CSV和PKL文件
    if (!file.name.endsWith('.csv') && !file.name.endsWith('.pkl')) {
        showAlert('只支持CSV和PKL文件', 'error', 'api');
        input.value = '';
        return;
    }

    const fileInfo = document.getElementById(`file-info-${scenarioId}`);
    const isPkl = file.name.endsWith('.pkl');
    fileInfo.textContent = `上传中: ${file.name}${isPkl ? ' (将自动转换为CSV)' : ''}...`;
    fileInfo.style.color = '#667eea';

    try {
        const formData = new FormData();
        formData.append('file', file);

        const response = await fetch('/api/upload', {
            method: 'POST',
            body: formData
        });

        const data = await response.json();

        if (data.success) {
            const hiddenInput = document.getElementById(scenarioId).querySelector('.scenario-filename');
            hiddenInput.value = data.filename;

            if (data.converted) {
                fileInfo.textContent = `✓ PKL已转换: ${data.original_filename} → ${data.filename}`;
            } else {
                fileInfo.textContent = `✓ 已上传: ${data.filename}`;
            }
            fileInfo.style.color = '#28a745';
        } else {
            fileInfo.textContent = `✗ 上传失败: ${data.error}`;
            fileInfo.style.color = '#dc3545';
            input.value = '';
        }
    } catch (error) {
        fileInfo.textContent = `✗ 上传错误: ${error.message}`;
        fileInfo.style.color = '#dc3545';
        input.value = '';
    }
}

function collectConfig() {
    // 安全地获取全局配置值
    const getGlobalValue = (id, defaultValue) => {
        const elem = document.getElementById(id);
        if (!elem) return defaultValue;
        const val = elem.value;
        if (val === '' || val === null || val === undefined) return defaultValue;
        const parsed = parseInt(val);
        return isNaN(parsed) ? defaultValue : parsed;
    };
    const getGlobalChecked = (id, defaultValue = false) => {
        const elem = document.getElementById(id);
        return elem ? elem.checked : defaultValue;
    };

    const globalThreadCount = getGlobalValue('global_thread_count', 150);
    const globalTimeout = getGlobalValue('global_timeout', 60);
    const globalBatchSize = getGlobalValue('global_batch_size', 50);

    const scenarios = [];
    // 只从接口数据对比的容器中收集场景卡片
    const container = document.getElementById('scenarios-container');
    const scenarioCards = container ? container.querySelectorAll('.scenario-card') : [];

    scenarioCards.forEach(card => {
        // 安全地获取元素值，避免null错误
        const getValue = (selector, defaultValue = '') => {
            const elem = card.querySelector(selector);
            if (!elem) return defaultValue;
            const val = elem.value;
            // 对于场景名称，trim后如果为空则使用默认值
            if (selector === '.scenario-name-input') {
                const trimmed = val ? val.trim() : '';
                return trimmed || defaultValue;
            }
            return val || defaultValue;
        };
        const getChecked = (selector, defaultValue = false) => {
            const elem = card.querySelector(selector);
            return elem ? elem.checked : defaultValue;
        };
        const getIntValue = (selector, defaultValue = 0) => {
            const elem = card.querySelector(selector);
            if (!elem) return defaultValue;
            const val = elem.value;
            if (val === '' || val === null || val === undefined) return defaultValue;
            const parsed = parseInt(val);
            return isNaN(parsed) ? defaultValue : parsed;
        };
        const getFileValue = (filenameSelector, fileSelector) => {
            const filenameElem = card.querySelector(filenameSelector);
            const fileElem = card.querySelector(fileSelector);
            if (filenameElem && filenameElem.value) {
                return filenameElem.value;
            }
            if (fileElem && fileElem.files && fileElem.files[0]) {
                return fileElem.files[0].name;
            }
            return '';
        };

        // 收集接口参数配置
        const apiParamsList = card.querySelector('.api-params-list');
        const apiParams = [];
        if (apiParamsList) {
            const paramItems = apiParamsList.querySelectorAll('.api-param-item');
            paramItems.forEach(item => {
                const paramName = item.querySelector('.param-name')?.value?.trim();
                const columnInput = item.querySelector('.param-column');
                const columnValue = columnInput?.value?.trim();
                const isTimeField = item.querySelector('.param-is-time')?.checked || false;
                const addTSeparator = item.querySelector('.param-add-t-separator')?.checked !== false; // 默认true
                const convertDateToTime = item.querySelector('.param-convert-date-to-time')?.checked !== false; // 默认true

                // 只有参数名不为空才添加
                if (paramName) {
                    // 如果列索引为空，则不添加该参数（不作为入参）
                    if (columnValue !== '' && columnValue !== null && columnValue !== undefined) {
                        const columnIndex = parseInt(columnValue);
                        if (!isNaN(columnIndex) && columnIndex >= 0) {
                            const paramObj = {
                                param_name: paramName,
                                column_index: columnIndex,
                                is_time_field: isTimeField
                            };
                            // 如果是时间字段，添加T分隔符和日期转换配置
                            if (isTimeField) {
                                paramObj.add_t_separator = addTSeparator;
                                paramObj.convert_date_to_time = convertDateToTime;
                            }
                            apiParams.push(paramObj);
                        }
                    }
                }
            });
        }

        const scenario = {
            name: getValue('.scenario-name-input', '未命名场景'),
            enabled: getChecked('.scenario-enabled', true),
            description: getValue('.scenario-description'),
            input_csv_file: getFileValue('.scenario-filename', '.scenario-file-input'),
            output_file_prefix: getValue('.scenario-output-prefix'),
            api_url: getValue('.scenario-api-url'),
            thread_count: globalThreadCount,
            timeout: globalTimeout,
            batch_size: globalBatchSize,
            convert_feature_to_number: getChecked('.scenario-convert-feature', true),
            add_one_second: getChecked('.scenario-add-one-second', true),
            calculate_difference: getChecked('.scenario-calculate-difference', false),
            column_config: {
                feature_start_column: getIntValue('.scenario-feature-column', 3)
            }
        };

        // 如果有接口参数配置，添加到场景中
        if (apiParams.length > 0) {
            scenario.api_params = apiParams;
        } else {
            // 如果没有配置接口参数，使用旧的列配置（向后兼容）
            scenario.column_config.cust_no_column = getIntValue('.scenario-cust-no-column', 0);
            scenario.column_config.use_create_time_column = getIntValue('.scenario-time-column', 2);
        }

        scenarios.push(scenario);
    });

    return {
        scenarios: scenarios,
        global_config: {
            default_thread_count: globalThreadCount,
            default_timeout: globalTimeout,
            default_batch_size: globalBatchSize,
            default_convert_feature_to_number: getGlobalChecked('global_convert_feature', true),
            default_ignore_default_fill: getGlobalChecked('global_ignore_default_fill', false)
        },
        output_config: {
            output_intermediate_files: getGlobalChecked('output_intermediate_files', true)
        }
    };
}

async function loadConfig() {
    try {
        console.log('[DEBUG] 开始加载接口数据对比配置...');

        const response = await fetch('/api/config/load');
        const data = await response.json();

        console.log('[DEBUG] 响应数据:', data);

        if (data.success) {
            const config = data.config;
            console.log('[DEBUG] 配置内容:', config);

            // 安全地设置全局配置值
            const globalThreadCountElem = document.getElementById('global_thread_count');
            if (globalThreadCountElem) {
                globalThreadCountElem.value = config.global_config?.default_thread_count || 150;
                console.log('[DEBUG] 设置线程数:', globalThreadCountElem.value);
            }
            const globalTimeoutElem = document.getElementById('global_timeout');
            if (globalTimeoutElem) {
                globalTimeoutElem.value = config.global_config?.default_timeout || 60;
                console.log('[DEBUG] 设置超时时间:', globalTimeoutElem.value);
            }
            const globalBatchSizeElem = document.getElementById('global_batch_size');
            if (globalBatchSizeElem) {
                globalBatchSizeElem.value = config.global_config?.default_batch_size || 50;
                console.log('[DEBUG] 设置批次大小:', globalBatchSizeElem.value);
            }
            const globalConvertFeatureElem = document.getElementById('global_convert_feature');
            if (globalConvertFeatureElem) {
                globalConvertFeatureElem.checked = config.global_config?.default_convert_feature_to_number !== false;
                console.log('[DEBUG] 设置特征转换:', globalConvertFeatureElem.checked);
            }
            const globalIgnoreDefaultFillElem = document.getElementById('global_ignore_default_fill');
            if (globalIgnoreDefaultFillElem) {
                globalIgnoreDefaultFillElem.checked = config.global_config?.default_ignore_default_fill === true;
                console.log('[DEBUG] 设置忽略默认填充值:', globalIgnoreDefaultFillElem.checked);
            }

            // 加载输出控制配置
            const outputIntermediateFilesElem = document.getElementById('output_intermediate_files');
            if (outputIntermediateFilesElem) {
                outputIntermediateFilesElem.checked = config.output_config?.output_intermediate_files !== false;
                console.log('[DEBUG] 设置输出中间文件:', outputIntermediateFilesElem.checked);
            }

            document.getElementById('scenarios-container').innerHTML = '';
            scenarioCount = 0;

            if (config.scenarios && config.scenarios.length > 0) {
                console.log('[DEBUG] 加载场景数量:', config.scenarios.length);
                config.scenarios.forEach((scenario, index) => {
                    addScenario(scenario, index === 0);
                });
            } else {
                console.log('[DEBUG] 没有场景配置，添加默认场景');
                addScenario(null, true);
            }

            console.log('[SUCCESS] 接口数据对比配置加载成功');
            showAlert('✅ 配置加载成功！', 'success', 'api');
        } else {
            console.warn('[WARN] 配置加载失败，使用默认配置');
            addScenario(null, true);
        }
    } catch (error) {
        console.error('[ERROR] 配置加载异常:', error);
        addScenario(null, true);
    }
}

async function saveConfig() {
    try {
        const config = collectConfig();

        if (config.scenarios.length === 0) {
            showAlert('至少需要添加一个场景', 'error', 'api');
            return;
        }

        const response = await fetch('/api/config/save', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ config: config })
        });

        const data = await response.json();

        if (data.success) {
            showAlert('配置保存成功', 'success', 'api');
        } else {
            showAlert('保存失败: ' + data.error, 'error', 'api');
        }
    } catch (error) {
        showAlert('保存失败: ' + error.message, 'error', 'api');
    }
}

function executeConfig() {
    if (isExecuting) {
        showAlert('正在执行中，请稍候...', 'error', 'api');
        return;
    }

    try {
        const config = collectConfig();

        if (config.scenarios.length === 0) {
            showAlert('至少需要添加一个场景', 'error', 'api');
            return;
        }

        const enabledScenarios = config.scenarios.filter(s => s.enabled);
        if (enabledScenarios.length === 0) {
            showAlert('至少需要启用一个场景', 'error', 'api');
            return;
        }

        clearOutput('api');

        isExecuting = true;
        updateStatus('running', '执行中...', 'api');
        document.querySelectorAll('[id^="execute-btn-"]').forEach(btn => {
            if (btn.id !== 'execute-btn-online') {
                btn.disabled = true;
            }
        });
        document.getElementById('loading-spinner-api').style.display = 'inline-block';

        const configJson = JSON.stringify(config);

        // 获取当前用户标识
        const userId = getUserId() || 'anonymous';

        fetch('/api/execute', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ config: configJson, user_id: userId })
        })
            .then(response => {
                if (!response.ok) {
                    throw new Error('执行失败');
                }

                const reader = response.body.getReader();
                const decoder = new TextDecoder();
                let buffer = '';

                function readStream() {
                    reader.read().then(({ done, value }) => {
                        if (done) {
                            if (buffer.trim()) {
                                processBuffer(buffer, 'api');
                                buffer = '';
                            }
                            isExecuting = false;
                            updateStatus('success', '执行完成', 'api');
                            showAlert('🎉 接口数据对比执行完成！', 'success', 'api');
                            appendOutput('🎉 任务执行完成！', 'success', 'api');
                            document.querySelectorAll('[id^="execute-btn-"]').forEach(btn => {
                                if (btn.id !== 'execute-btn-online') {
                                    btn.disabled = false;
                                }
                            });
                            document.getElementById('loading-spinner-api').style.display = 'none';
                            // 自动下载输出文件
                            setTimeout(() => autoDownloadOutputFiles('api_comparison', 2), 1000);
                            return;
                        }

                        buffer += decoder.decode(value, { stream: true });
                        const lines = buffer.split('\n');
                        buffer = lines.pop() || '';

                        for (const line of lines) {
                            processLine(line, 'api');
                        }

                        readStream();
                    }).catch(error => {
                        appendOutput('错误: ' + error.message, 'error', 'api');
                        isExecuting = false;
                        updateStatus('error', '执行失败', 'api');
                        document.querySelectorAll('[id^="execute-btn-"]').forEach(btn => {
                            if (btn.id !== 'execute-btn-online') {
                                btn.disabled = false;
                            }
                        });
                        document.getElementById('loading-spinner-api').style.display = 'none';
                    });
                }

                function processLine(line, tab) {
                    if (line.startsWith('data: ')) {
                        try {
                            const data = JSON.parse(line.substring(6));
                            if (data.type === 'start') {
                                appendOutput(data.message, 'info', tab);
                                // 保存task_id并显示停止按钮
                                if (data.task_id && typeof setCurrentTaskId === 'function') {
                                    setCurrentTaskId(data.task_id);
                                }
                            } else if (data.type === 'output') {
                                appendOutput(data.message, 'output', tab);
                            } else if (data.type === 'error') {
                                appendOutput(data.message, 'error', tab);
                            } else if (data.type === 'end') {
                                appendOutput(data.message, 'success', tab);
                                // 清除task_id并隐藏停止按钮
                                if (typeof clearCurrentTaskId === 'function') {
                                    clearCurrentTaskId();
                                }
                            }
                        } catch (e) {
                            // 忽略解析错误
                        }
                    }
                }

                function processBuffer(buf, tab) {
                    const lines = buf.split('\n');
                    for (const line of lines) {
                        if (line.trim()) {
                            processLine(line, tab);
                        }
                    }
                }

                readStream();
            })
            .catch(error => {
                appendOutput('执行错误: ' + error.message, 'error', 'api');
                isExecuting = false;
                updateStatus('error', '执行失败', 'api');
                document.querySelectorAll('[id^="execute-btn-"]').forEach(btn => {
                    if (btn.id !== 'execute-btn-online') {
                        btn.disabled = false;
                    }
                });
                document.getElementById('loading-spinner-api').style.display = 'none';
            });

    } catch (error) {
        showAlert('执行失败: ' + error.message, 'error', 'api');
        isExecuting = false;
        updateStatus('error', '执行失败', 'api');
        document.getElementById('loading-spinner-api').style.display = 'none';
    }
}

function clearOutput(tab = 'api') {
    document.getElementById(`output-panel-${tab}`).innerHTML = '<div class="output-line info">输出已清空...</div>';
}

function appendOutput(message, type = 'output', tab = 'api') {
    // 初始化计数器
    if (!outputCounters[tab]) {
        outputCounters[tab] = 0;
    }
    outputCounters[tab]++;

    const outputPanel = document.getElementById(`output-panel-${tab}`);

    // 创建输出行
    const line = document.createElement('div');
    line.className = 'output-line';

    // 检测完成标记
    const isCompletion = message.includes('🎉') || message.includes('任务执行完成');

    // 添加类型样式
    if (isCompletion) {
        // 完成消息特殊样式
        line.className += ' completion';
        line.style.fontSize = '16px';
        line.style.fontWeight = 'bold';
        line.style.padding = '12px';
        line.style.margin = '8px 0';
        line.style.background = 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)';
        line.style.color = 'white';
        line.style.borderRadius = '8px';
        line.style.boxShadow = '0 4px 6px rgba(0,0,0,0.1)';
    } else if (message.includes('错误') || message.includes('❌') || message.includes('失败')) {
        line.className += ' error';
    } else if (message.includes('成功') || message.includes('✅') || message.includes('完成')) {
        line.className += ' success';
    } else if (message.includes('警告') || message.includes('⚠️')) {
        line.className += ' warning';
    } else {
        line.className += ' info';
    }

    line.textContent = message;
    outputPanel.appendChild(line);

    // 限制最大行数（防止内存溢出）
    const lines = outputPanel.querySelectorAll('.output-line');
    if (lines.length > MAX_OUTPUT_LINES) {
        const removeCount = lines.length - MAX_OUTPUT_LINES;
        for (let i = 0; i < removeCount; i++) {
            lines[i].remove();
        }
    }

    // 滚动到底部（防抖）
    if (outputPanel._scrollTimeout) {
        clearTimeout(outputPanel._scrollTimeout);
    }
    outputPanel._scrollTimeout = setTimeout(() => {
        outputPanel.scrollTop = outputPanel.scrollHeight;
    }, 50);
}

function updateStatus(status, text, tab = 'api') {
    const indicator = document.getElementById(`status-indicator-${tab}`);
    const statusText = document.getElementById(`status-text-${tab}`);

    indicator.className = 'status-indicator ' + status;
    statusText.textContent = text;
}



// ========== 页面加载时自动加载配置 ==========
document.addEventListener('DOMContentLoaded', function () {
    // 检查是否在接口数据对比页面
    const apiPage = document.getElementById('page-api');
    if (apiPage) {
        console.log('[INFO] 页面加载完成，自动加载接口数据对比配置...');
        // 延迟500ms加载配置，确保页面元素已完全初始化
        setTimeout(() => {
            loadConfig();
        }, 500);
    }
});
