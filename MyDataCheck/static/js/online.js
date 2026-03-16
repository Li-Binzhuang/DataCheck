// ========== 线上灰度落数对比相关函数 ==========

async function handleOnlineFileSelect(fileType, input) {
    const file = input.files[0];
    if (!file) return;

    if (!file.name.endsWith('.csv') && !file.name.endsWith('.xlsx') && !file.name.endsWith('.xls')) {
        showAlert('只支持CSV和XLSX文件', 'error', 'online');
        input.value = '';
        return;
    }

    const fileInfo = document.getElementById(`file-info-${fileType}`);
    const isXlsx = file.name.endsWith('.xlsx') || file.name.endsWith('.xls');
    fileInfo.textContent = `上传中: ${file.name}${isXlsx ? ' (将自动转换为CSV)' : ''}...`;
    fileInfo.style.color = '#667eea';

    try {
        const formData = new FormData();
        formData.append('file', file);

        const response = await fetch('/api/upload/online', {
            method: 'POST',
            body: formData
        });

        const data = await response.json();

        if (data.success) {
            fileInfo.textContent = `✓ 已上传: ${data.filename}`;
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

// ========== 线上灰度落数对比相关函数 ==========

// 添加线上灰度落数对比场景
function addOnlineScenario(scenarioData = null, isFirst = false) {
    onlineScenarioCount++;
    const scenarioId = `online_scenario_${onlineScenarioCount}`;
    const container = document.getElementById('online-scenarios-container');

    const scenario = scenarioData || {
        name: `场景${onlineScenarioCount}`,
        enabled: true,
        description: '',
        output_prefix: '',
        online_file: '',
        offline_file: '',
        json_column: '',
        online_key_column: 0,
        offline_key_column: 1,
        online_feature_start_column: 3,
        offline_feature_start_column: 3,
        convert_string_to_number: false,
        enable_tolerance: false,
        tolerance_value: 0.000001,
        compare_common_features_only: false,
        output_full_data: false
    };

    const isFirstScenario = isFirst || (onlineScenarioCount === 1 && !scenarioData);
    const deleteButton = isFirstScenario ? '' : `<button class="btn-icon btn-delete" onclick="removeOnlineScenario('${scenarioId}')">删除</button>`;

    // 修复数值解析
    const getIntValue = (val, defaultValue) => {
        if (val === '' || val === null || val === undefined) return defaultValue;
        const parsed = parseInt(val);
        return isNaN(parsed) ? defaultValue : parsed;
    };

    // 解析主键列配置：支持单列(int)或多列(数组)
    const formatKeyColumnDisplay = (val, defaultValue) => {
        if (val === '' || val === null || val === undefined) return String(defaultValue);
        if (Array.isArray(val)) return val.join(',');
        return String(val);
    };

    const onlineKeyColDisplay = formatKeyColumnDisplay(scenario.online_key_column, 0);
    const offlineKeyColDisplay = formatKeyColumnDisplay(scenario.offline_key_column, 1);
    const onlineFeatureStart = getIntValue(scenario.online_feature_start_column, 3);
    const offlineFeatureStart = getIntValue(scenario.offline_feature_start_column, 3);

    const card = document.createElement('div');
    card.className = `scenario-card ${scenario.enabled ? 'enabled' : ''}`;
    card.id = scenarioId;
    card.innerHTML = `
        <div class="scenario-header" onclick="toggleOnlineScenarioCollapse('${scenarioId}')">
            <div style="display: flex; align-items: center; flex: 1;">
                <div class="scenario-title">
                    <input type="text" class="online-scenario-name-input" value="${scenario.name}" 
                           placeholder="场景名称"
                           onclick="event.stopPropagation();"
                           onkeydown="event.stopPropagation();"
                           onkeyup="event.stopPropagation();"
                           onkeypress="event.stopPropagation();"
                           onfocus="event.stopPropagation();"
                           onblur="event.stopPropagation();">
                </div>
                <button class="scenario-toggle-btn" id="online-toggle-btn-${scenarioId}" onclick="event.stopPropagation(); toggleOnlineScenarioCollapse('${scenarioId}')" title="展开/收起">▼</button>
            </div>
            <div class="scenario-actions" onclick="event.stopPropagation();">
                <div class="checkbox-group">
                    <input type="checkbox" class="online-scenario-enabled" ${scenario.enabled ? 'checked' : ''} 
                           onchange="toggleOnlineScenario('${scenarioId}')">
                    <label style="margin: 0;">启用</label>
                </div>
                ${deleteButton}
            </div>
        </div>
        
        <div class="scenario-content" id="online-scenario-content-${scenarioId}">
        <div class="form-group">
            <label>场景描述:</label>
            <input type="text" class="online-scenario-description" value="${scenario.description || ''}" placeholder="场景描述（可选）">
        </div>
        
        <div class="form-group">
            <label>输出文件前缀:</label>
            <input type="text" class="online-scenario-output-prefix" value="${scenario.output_prefix || ''}" placeholder="例如: yx_online">
        </div>
        
        <!-- 步骤1：JSON解析配置 -->
        <div style="background: #e8f4f8; border-left: 4px solid #17a2b8; padding: 12px; margin-bottom: 15px; border-radius: 4px;">
            <h3 style="margin: 0 0 10px 0; color: #17a2b8; font-size: 14px;">步骤1：JSON解析配置</h3>
            
            <div class="form-group">
                <label>样本文件 (CSV/PKL/XLSX):</label>
                <input type="file" class="online-scenario-offline-file" accept=".csv,.pkl,.xlsx" onchange="handleOnlineScenarioFileSelect('${scenarioId}', 'offline', this)">
                <input type="hidden" class="online-scenario-offline-filename" value="${scenario.offline_file || ''}">
                <div class="file-info" id="file-info-${scenarioId}-offline" style="margin-top: 8px; padding: 8px; background: #f8f9fa; border-radius: 4px;">
                    ${scenario.offline_file ? `当前文件: ${scenario.offline_file}` : '未选择文件（支持CSV、PKL和XLSX文件）'}
                </div>
            </div>
            
            <div class="form-group">
                <label>灰度落数文件 (CSV/PKL/XLSX):</label>
                <input type="file" class="online-scenario-online-file" accept=".csv,.pkl,.xlsx" onchange="handleOnlineScenarioFileSelect('${scenarioId}', 'online', this)">
                <input type="hidden" class="online-scenario-online-filename" value="${scenario.online_file || ''}">
                <div class="file-info" id="file-info-${scenarioId}-online" style="margin-top: 8px; padding: 8px; background: #f8f9fa; border-radius: 4px;">
                    ${scenario.online_file ? `当前文件: ${scenario.online_file}` : '未选择文件（支持CSV、PKL和XLSX文件）'}
                </div>
            </div>
            
            <div class="form-group">
                <label>JSON列名:</label>
                <input type="text" class="online-scenario-json-column" value="${scenario.json_column || ''}" placeholder="例如: local_olduser_repayment_new_full">
            </div>
            
            <div class="button-group" style="margin-top: 10px;">
                <button class="btn-primary" onclick="parseOnlineScenarioJSON('${scenarioId}')" id="parse-btn-${scenarioId}">🔍 解析JSON</button>
            </div>
            
            <!-- 列名展示区域（在解析按钮下方） -->
            <div id="parse-columns-display-area-${scenarioId}" style="display: none; margin-top: 15px; padding: 15px; background: #f8f9fa; border-radius: 6px; border: 1px solid #17a2b8;">
                <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 15px;">
                    <h4 style="margin: 0; color: #17a2b8; font-size: 14px; font-weight: 600;">📋 文件列名信息</h4>
                    <button onclick="toggleParseColumnsDisplay('${scenarioId}')" style="background: #17a2b8; color: white; border: none; padding: 2px 6px; border-radius: 3px; cursor: pointer; font-size: 10px;">收起</button>
                </div>
                
                <!-- 解析后的文件列名 -->
                <div id="parse-online-columns-section-${scenarioId}" style="display: none; margin-bottom: 15px; padding: 12px; background: #f0f4ff; border-radius: 4px; border: 1px solid #667eea;">
                    <h5 style="margin: 0 0 10px 0; color: #667eea; font-size: 13px; font-weight: 600;">📄 解析后的文件列名</h5>
                    <div id="parse-online-columns-list-${scenarioId}" style="font-size: 11px; line-height: 1.8;"></div>
                </div>
                
                <!-- 离线文件列名 -->
                <div id="parse-offline-columns-section-${scenarioId}" style="display: none; padding: 12px; background: #fff3cd; border-radius: 4px; border: 1px solid #ffc107;">
                    <h5 style="margin: 0 0 10px 0; color: #856404; font-size: 13px; font-weight: 600;">📄 离线文件列名</h5>
                    <div id="parse-offline-columns-list-${scenarioId}" style="font-size: 11px; line-height: 1.8;"></div>
                </div>
            </div>
        </div>
        
        <!-- 步骤2：对比配置 -->
        <div style="background: #fff3cd; border-left: 4px solid #ffc107; padding: 12px; margin-bottom: 15px; border-radius: 4px;">
            <h3 style="margin: 0 0 10px 0; color: #856404; font-size: 14px;">步骤2：数据对比配置</h3>
            
            <div class="form-row">
                <div class="form-group">
                    <label>在线文件主键列索引 (A列=0，多列用逗号分隔如0,1):</label>
                    <input type="text" class="online-scenario-online-key-column" value="${onlineKeyColDisplay}" placeholder="例如: 0 或 0,1">
                </div>
                <div class="form-group">
                    <label>离线文件主键列索引 (A列=0，多列用逗号分隔如0,1):</label>
                    <input type="text" class="online-scenario-offline-key-column" value="${offlineKeyColDisplay}" placeholder="例如: 1 或 0,1">
                </div>
            </div>
            
            <div class="form-group">
                <div class="checkbox-group">
                    <input type="checkbox" class="online-scenario-convert-string" ${scenario.convert_string_to_number ? 'checked' : ''}>
                    <label style="margin: 0;">转换字符串为数值</label>
                </div>
            </div>
            
            <div class="form-row">
                <div class="form-group">
                    <label>在线文件特征起始列索引:</label>
                    <input type="number" class="online-scenario-online-feature-start" value="${onlineFeatureStart}" min="0">
                </div>
                <div class="form-group">
                    <label>离线文件特征起始列索引:</label>
                    <input type="number" class="online-scenario-offline-feature-start" value="${offlineFeatureStart}" min="0">
                </div>
            </div>
            
            <div class="form-group" style="margin-top: 15px;">
                <div class="checkbox-group">
                    <input type="checkbox" class="online-scenario-enable-tolerance" ${scenario.enable_tolerance ? 'checked' : ''} onchange="toggleOnlineToleranceInput('${scenarioId}')">
                    <label style="margin: 0;">启用容错对比</label>
                </div>
                <div id="tolerance-input-${scenarioId}" style="margin-top: 10px; display: ${scenario.enable_tolerance ? 'block' : 'none'};">
                    <label>容错值（差值在此范围内视为一致）:</label>
                    <input type="number" class="online-scenario-tolerance-value" value="${scenario.tolerance_value || 0.000001}" step="0.000001" min="0" placeholder="默认: 0.000001">
                    <small style="display: block; margin-top: 5px; color: #666;">例如: 0.000001 表示差值小于等于 0.000001 时认为一致</small>
                </div>
            </div>
            
            <div class="form-group" style="margin-top: 15px;">
                <div class="checkbox-group">
                    <input type="checkbox" class="online-scenario-compare-common-only" ${scenario.compare_common_features_only ? 'checked' : ''}>
                    <label style="margin: 0;">仅对比共有特征</label>
                </div>
                <small style="display: block; margin-top: 5px; color: #666;">勾选后只对比两个文件中都存在的特征列，未勾选则对比所有特征（缺失特征视为差异）</small>
            </div>
            
            <div class="form-group" style="margin-top: 15px;">
                <div class="checkbox-group">
                    <input type="checkbox" class="online-scenario-output-full-data" ${scenario.output_full_data ? 'checked' : ''}>
                    <label style="margin: 0;">输出全量数据合并文件</label>
                </div>
                <small style="display: block; margin-top: 5px; color: #666;">勾选后会生成全量数据合并CSV文件（文件较大时会增加处理时间，默认不输出）</small>
            </div>
        </div>
        </div>
    `;

    container.appendChild(card);

    // 场景名称输入事件
    const nameInput = card.querySelector('.online-scenario-name-input');
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

function toggleOnlineScenario(scenarioId) {
    const card = document.getElementById(scenarioId);
    const enabled = card.querySelector('.online-scenario-enabled').checked;
    if (enabled) {
        card.classList.add('enabled');
    } else {
        card.classList.remove('enabled');
    }
}

// 切换容错输入框显示（线上灰度落数对比）
function toggleOnlineToleranceInput(scenarioId) {
    const card = document.getElementById(scenarioId);
    const enableTolerance = card.querySelector('.online-scenario-enable-tolerance').checked;
    const toleranceInput = document.getElementById(`tolerance-input-${scenarioId}`);

    if (toleranceInput) {
        toleranceInput.style.display = enableTolerance ? 'block' : 'none';
    }
}

// 切换场景卡片的展开/收起状态（线上灰度落数对比）
function toggleOnlineScenarioCollapse(scenarioId) {
    const content = document.getElementById(`online-scenario-content-${scenarioId}`);
    const toggleBtn = document.getElementById(`online-toggle-btn-${scenarioId}`);
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

async function removeOnlineScenario(scenarioId) {
    if (confirm('确定要删除这个场景吗？')) {
        // 先获取要删除的场景名称（用于调试）
        const cardToRemove = document.getElementById(scenarioId);
        const scenarioName = cardToRemove ? cardToRemove.querySelector('.online-scenario-name-input')?.value || scenarioId : scenarioId;

        // 删除DOM元素
        cardToRemove.remove();

        // 更新剩余场景的删除按钮显示
        const remainingCards = document.querySelectorAll('#online-scenarios-container .scenario-card');
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
            const config = collectOnlineConfig();

            if (config.scenarios.length === 0) {
                showAlert('至少需要添加一个场景', 'error', 'online');
                return;
            }

            // 验证收集的场景数量
            console.log(`删除场景 "${scenarioName}" 后，剩余场景数: ${config.scenarios.length}`);
            console.log('剩余场景名称:', config.scenarios.map(s => s.name));

            const response = await fetch('/api/config/online/save', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ config: config })
            });

            const data = await response.json();

            if (data.success) {
                showAlert(`场景 "${scenarioName}" 已删除，配置已保存（剩余 ${config.scenarios.length} 个场景）`, 'success', 'online');
            } else {
                showAlert('场景已删除，但保存配置失败: ' + data.error, 'error', 'online');
            }
        } catch (error) {
            showAlert('场景已删除，但保存配置失败: ' + error.message, 'error', 'online');
            console.error('删除场景后保存配置失败:', error);
        }
    }
}

async function handleOnlineScenarioFileSelect(scenarioId, fileType, input) {
    const file = input.files[0];
    if (!file) return;

    // 支持CSV、PKL和XLSX文件
    if (!file.name.endsWith('.csv') && !file.name.endsWith('.pkl') && !file.name.endsWith('.xlsx') && !file.name.endsWith('.xls')) {
        showAlert('只支持CSV、PKL和XLSX文件', 'error', 'online');
        input.value = '';
        return;
    }

    const fileInfo = document.getElementById(`file-info-${scenarioId}-${fileType}`);
    const isPkl = file.name.endsWith('.pkl');
    const isXlsx = file.name.endsWith('.xlsx') || file.name.endsWith('.xls');
    fileInfo.textContent = `上传中: ${file.name}${isPkl || isXlsx ? ' (将自动转换为CSV)' : ''}...`;
    fileInfo.style.color = '#667eea';

    try {
        const formData = new FormData();
        formData.append('file', file);

        const response = await fetch('/api/upload/online', {
            method: 'POST',
            body: formData
        });

        const data = await response.json();

        if (data.success) {
            const hiddenInput = document.getElementById(scenarioId).querySelector(`.online-scenario-${fileType}-filename`);
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

function collectOnlineConfig() {
    // 收集所有场景的配置
    const scenarios = [];
    const scenarioCards = document.querySelectorAll('#online-scenarios-container .scenario-card');

    scenarioCards.forEach(card => {
        const getIntValue = (selector, defaultValue) => {
            const elem = card.querySelector(selector);
            if (!elem) return defaultValue;
            const val = elem.value;
            if (val === '' || val === null || val === undefined) return defaultValue;
            const parsed = parseInt(val);
            return isNaN(parsed) ? defaultValue : parsed;
        };

        // 安全地获取元素值，避免null错误
        const getNameInput = () => {
            const elem = card.querySelector('.online-scenario-name-input');
            if (!elem) return '未命名场景';
            const val = elem.value ? elem.value.trim() : '';
            return val || '未命名场景';
        };
        const getEnabled = () => {
            const elem = card.querySelector('.online-scenario-enabled');
            return elem ? elem.checked : true;
        };
        const getValue = (selector, defaultValue = '') => {
            const elem = card.querySelector(selector);
            return elem ? (elem.value || defaultValue) : defaultValue;
        };
        const getChecked = (selector, defaultValue = false) => {
            const elem = card.querySelector(selector);
            return elem ? elem.checked : defaultValue;
        };
        const getFloatValue = (selector, defaultValue) => {
            const elem = card.querySelector(selector);
            if (!elem) return defaultValue;
            const val = elem.value;
            if (val === '' || val === null || val === undefined) return defaultValue;
            const parsed = parseFloat(val);
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

        // 解析主键列配置：支持单列(int)或多列(逗号分隔)
        const getKeyColumnValue = (selector, defaultValue) => {
            const elem = card.querySelector(selector);
            if (!elem) return defaultValue;
            const val = (elem.value || '').trim();
            if (!val) return defaultValue;
            // 如果包含逗号，解析为数组
            if (val.includes(',')) {
                const parts = val.split(',').map(s => parseInt(s.trim())).filter(n => !isNaN(n));
                return parts.length > 0 ? parts : defaultValue;
            }
            const parsed = parseInt(val);
            return isNaN(parsed) ? defaultValue : parsed;
        };

        const scenario = {
            name: getNameInput(),
            enabled: getEnabled(),
            description: getValue('.online-scenario-description'),
            output_prefix: getValue('.online-scenario-output-prefix'),
            online_file: getFileValue('.online-scenario-online-filename', '.online-scenario-online-file'),
            offline_file: getFileValue('.online-scenario-offline-filename', '.online-scenario-offline-file'),
            json_column: getValue('.online-scenario-json-column'),
            online_key_column: getKeyColumnValue('.online-scenario-online-key-column', 0),
            offline_key_column: getKeyColumnValue('.online-scenario-offline-key-column', 1),
            online_feature_start_column: getIntValue('.online-scenario-online-feature-start', 3),
            offline_feature_start_column: getIntValue('.online-scenario-offline-feature-start', 3),
            convert_string_to_number: getChecked('.online-scenario-convert-string', false),
            enable_tolerance: getChecked('.online-scenario-enable-tolerance', false),
            tolerance_value: getFloatValue('.online-scenario-tolerance-value', 0.000001),
            compare_common_features_only: getChecked('.online-scenario-compare-common-only', false),
            output_full_data: getChecked('.online-scenario-output-full-data', false)
        };
        scenarios.push(scenario);
    });

    return {
        scenarios: scenarios
    };
}

async function loadOnlineConfig() {
    try {
        const response = await fetch('/api/config/online/load');
        const data = await response.json();

        if (data.success) {
            const config = data.config;

            // 清空场景容器
            document.getElementById('online-scenarios-container').innerHTML = '';
            onlineScenarioCount = 0;

            // 检查是否是多场景配置
            if (config.scenarios && Array.isArray(config.scenarios) && config.scenarios.length > 0) {
                // 多场景模式
                config.scenarios.forEach((scenario, index) => {
                    addOnlineScenario(scenario, index === 0);
                });
            } else {
                // 单场景模式（兼容旧配置）
                const singleScenario = {
                    name: '场景1',
                    enabled: true,
                    description: '',
                    output_prefix: config.output_prefix || '',
                    online_file: config.online_file || '',
                    offline_file: config.offline_file || '',
                    json_column: config.json_column || '',
                    online_key_column: config.online_key_column !== undefined ? config.online_key_column : 0,
                    offline_key_column: config.offline_key_column !== undefined ? config.offline_key_column : 1,
                    online_feature_start_column: config.online_feature_start_column !== undefined ? config.online_feature_start_column : (config.feature_start_column || 3),
                    offline_feature_start_column: config.offline_feature_start_column !== undefined ? config.offline_feature_start_column : (config.feature_start_column || 3),
                    convert_string_to_number: config.convert_string_to_number || false
                };
                addOnlineScenario(singleScenario, true);
            }
        } else {
            // 如果没有配置，添加一个默认场景
            addOnlineScenario(null, true);
        }
    } catch (error) {
        console.error('加载配置失败:', error);
        // 出错时也添加一个默认场景
        addOnlineScenario(null, true);
    }
}

async function saveOnlineConfig() {
    try {
        const config = collectOnlineConfig();

        if (!config.scenarios || config.scenarios.length === 0) {
            showAlert('至少需要添加一个场景', 'error', 'online');
            return;
        }

        // 验证场景名称（至少要有名称）
        for (const scenario of config.scenarios) {
            if (!scenario.name || scenario.name.trim() === '' || scenario.name === '未命名场景') {
                showAlert('请为所有场景设置名称', 'error', 'online');
                return;
            }
        }

        const response = await fetch('/api/config/online/save', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ config: config })
        });

        const data = await response.json();

        if (data.success) {
            showAlert(`配置保存成功！已保存 ${config.scenarios.length} 个场景`, 'success', 'online');
        } else {
            showAlert('保存失败: ' + data.error, 'error', 'online');
        }
    } catch (error) {
        showAlert('保存失败: ' + error.message, 'error', 'online');
    }
}

// 为特定场景解析JSON
async function parseOnlineScenarioJSON(scenarioId) {
    const card = document.getElementById(scenarioId);
    if (!card) {
        showAlert('场景卡片未找到', 'error', 'online');
        return;
    }

    // 获取解析按钮（在函数开始时获取，后续会重新验证）
    let parseBtn = document.getElementById(`parse-btn-${scenarioId}`);
    if (!parseBtn) {
        showAlert('解析按钮未找到', 'error', 'online');
        return;
    }
    if (parseBtn.disabled) {
        showAlert('正在解析中，请稍候...', 'error', 'online');
        return;
    }

    try {
        const getIntValue = (selector, defaultValue) => {
            const elem = card.querySelector(selector);
            if (!elem) return defaultValue;
            const val = elem.value;
            if (val === '' || val === null || val === undefined) return defaultValue;
            const parsed = parseInt(val);
            return isNaN(parsed) ? defaultValue : parsed;
        };

        // 安全地获取元素值，避免null错误
        const getValue = (selector, defaultValue = '') => {
            const elem = card.querySelector(selector);
            return elem ? (elem.value || defaultValue) : defaultValue;
        };
        const getChecked = (selector, defaultValue = false) => {
            const elem = card.querySelector(selector);
            return elem ? elem.checked : defaultValue;
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

        const config = {
            output_prefix: getValue('.online-scenario-output-prefix'),
            online_file: getFileValue('.online-scenario-online-filename', '.online-scenario-online-file'),
            offline_file: getFileValue('.online-scenario-offline-filename', '.online-scenario-offline-file'),
            json_column: getValue('.online-scenario-json-column'),
            online_key_column: (() => {
                const val = (card.querySelector('.online-scenario-online-key-column')?.value || '').trim();
                if (!val) return 0;
                if (val.includes(',')) {
                    const parts = val.split(',').map(s => parseInt(s.trim())).filter(n => !isNaN(n));
                    return parts.length > 0 ? parts : 0;
                }
                const parsed = parseInt(val);
                return isNaN(parsed) ? 0 : parsed;
            })(),
            convert_string_to_number: getChecked('.online-scenario-convert-string', false)
        };

        if (!config.online_file) {
            showAlert('请上传线上文件', 'error', 'online');
            return;
        }

        if (!config.json_column) {
            showAlert('请输入JSON列名', 'error', 'online');
            return;
        }

        // 确保parseBtn和parentElement存在（在清空输出之前检查）
        if (!parseBtn || !parseBtn.parentElement) {
            showAlert('解析按钮或其父元素未找到', 'error', 'online');
            return;
        }

        // 清空该场景的输出（注意：clearOnlineScenarioOutput不会影响parseBtn）
        clearOnlineScenarioOutput(scenarioId);

        // 再次确认parseBtn仍然存在（防止在清空过程中被移除）
        const verifyParseBtn = document.getElementById(`parse-btn-${scenarioId}`);
        if (!verifyParseBtn || !verifyParseBtn.parentElement) {
            showAlert('解析按钮在清空输出后未找到', 'error', 'online');
            return;
        }

        verifyParseBtn.disabled = true;
        const loadingSpinner = document.createElement('span');
        loadingSpinner.className = 'loading';
        loadingSpinner.style.display = 'inline-block';
        loadingSpinner.style.marginLeft = '10px';
        verifyParseBtn.parentElement.appendChild(loadingSpinner);

        // 使用验证后的按钮引用（避免作用域问题，在readStream函数中需要使用）
        const finalParseBtn = verifyParseBtn;
        const finalLoadingSpinner = loadingSpinner;

        // 获取当前用户标识
        const userId = getUserId() || 'anonymous';

        // 直接发送config对象，不需要双重JSON编码
        fetch('/api/parse/online', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ config: config, user_id: userId })
        })
            .then(response => {
                if (!response.ok) {
                    throw new Error('解析失败');
                }

                const reader = response.body.getReader();
                const decoder = new TextDecoder();
                let buffer = '';

                // 定义列名提取相关的变量和函数（用于解析JSON）
                let parseColumnsBuffer = [];
                let inParseColumnsSection = false;
                let offlineParseColumnsBuffer = [];
                let inOfflineParseColumnsSection = false;

                function processParseLine(line, tab) {
                    if (line.startsWith('data: ')) {
                        try {
                            const data = JSON.parse(line.substring(6));
                            if (data.type === 'start') {
                                appendOutput(tab, data.message, 'info');
                            } else if (data.type === 'output') {
                                const message = data.message;
                                appendOutput(tab, message, 'output');

                                // 检测列名信息
                                if (tab === 'online') {
                                    // 检测离线文件列名
                                    if (message.includes('离线文件列名')) {
                                        inOfflineParseColumnsSection = true;
                                        offlineParseColumnsBuffer = [];
                                        const match = message.match(/共\s*(\d+)\s*列/);
                                        if (match) {
                                            offlineParseColumnsBuffer.totalCount = parseInt(match[1]);
                                        }
                                    } else if (inOfflineParseColumnsSection) {
                                        if (message.includes('、')) {
                                            offlineParseColumnsBuffer.push(message);
                                            extractAndDisplayOfflineParseColumns(offlineParseColumnsBuffer, scenarioId);
                                            inOfflineParseColumnsSection = false;
                                            offlineParseColumnsBuffer = [];
                                        } else if (message.includes('还有') || message.includes('列未显示')) {
                                            if (offlineParseColumnsBuffer.length > 0) {
                                                extractAndDisplayOfflineParseColumns(offlineParseColumnsBuffer, scenarioId);
                                            }
                                            inOfflineParseColumnsSection = false;
                                            offlineParseColumnsBuffer = [];
                                        }
                                    }

                                    // 检测解析后的文件列名
                                    if (message.includes('解析后的文件列名')) {
                                        inParseColumnsSection = true;
                                        parseColumnsBuffer = [];
                                        const match = message.match(/共\s*(\d+)\s*列/);
                                        if (match) {
                                            parseColumnsBuffer.totalCount = parseInt(match[1]);
                                        }
                                    } else if (inParseColumnsSection) {
                                        if (message.includes('、')) {
                                            parseColumnsBuffer.push(message);
                                            extractAndDisplayParseColumns(parseColumnsBuffer, scenarioId);
                                            inParseColumnsSection = false;
                                            parseColumnsBuffer = [];
                                        } else if (message.includes('还有') || message.includes('列未显示')) {
                                            if (parseColumnsBuffer.length > 0) {
                                                extractAndDisplayParseColumns(parseColumnsBuffer, scenarioId);
                                            }
                                            inParseColumnsSection = false;
                                            parseColumnsBuffer = [];
                                        }
                                    }
                                }
                            } else if (data.type === 'error') {
                                appendOutput(tab, data.message, 'error');
                            } else if (data.type === 'end') {
                                if (tab === 'online') {
                                    // 在解析完成时，确保显示所有已提取的列名
                                    if (offlineParseColumnsBuffer.length > 0) {
                                        extractAndDisplayOfflineParseColumns(offlineParseColumnsBuffer, scenarioId);
                                    }
                                    if (parseColumnsBuffer.length > 0) {
                                        extractAndDisplayParseColumns(parseColumnsBuffer, scenarioId);
                                    }
                                    // 确保列名显示区域可见（即使没有提取到列名，也显示区域）
                                    const displayArea = document.getElementById(`parse-columns-display-area-${scenarioId}`);
                                    if (displayArea) {
                                        displayArea.style.display = 'block';
                                    }
                                }
                                appendOutput(tab, data.message, 'success');
                            }
                        } catch (e) {
                            // 忽略解析错误
                        }
                    }
                }

                function extractAndDisplayOfflineParseColumns(buffer, scenarioId) {
                    const lines = [];
                    for (let i = 0; i < buffer.length; i++) {
                        if (typeof buffer[i] === 'string') {
                            lines.push(buffer[i]);
                        }
                    }

                    let columnNames = [];
                    for (const line of lines) {
                        if (line.includes('、')) {
                            const cols = line.split('、');
                            columnNames = cols.map(col => col.trim()).filter(col => col && !col.includes('还有') && !col.includes('列未显示'));
                            break;
                        }
                    }

                    const validColumns = columnNames.slice(0, 5);
                    if (validColumns.length > 0) {
                        let totalCount = buffer.totalCount || null;
                        if (!totalCount && lines.length > 0) {
                            const match = lines[0].match(/共\s*(\d+)\s*列/);
                            if (match) {
                                totalCount = parseInt(match[1]);
                            }
                        }
                        displayParseOfflineColumns(validColumns, totalCount || validColumns.length, scenarioId);
                    }
                }

                function extractAndDisplayParseColumns(buffer, scenarioId) {
                    const lines = [];
                    for (let i = 0; i < buffer.length; i++) {
                        if (typeof buffer[i] === 'string') {
                            lines.push(buffer[i]);
                        }
                    }

                    let columnNames = [];
                    for (const line of lines) {
                        if (line.includes('、')) {
                            const cols = line.split('、');
                            columnNames = cols.map(col => col.trim()).filter(col => col && !col.includes('还有') && !col.includes('列未显示'));
                            break;
                        }
                    }

                    const validColumns = columnNames.slice(0, 5);
                    if (validColumns.length > 0) {
                        let totalCount = buffer.totalCount || null;
                        if (!totalCount && lines.length > 0) {
                            const match = lines[0].match(/共\s*(\d+)\s*列/);
                            if (match) {
                                totalCount = parseInt(match[1]);
                            }
                        }
                        displayParseOnlineColumns(validColumns, totalCount || validColumns.length, scenarioId);
                        // 启用该场景的执行按钮
                        const executeBtn = document.getElementById(`execute-btn-${scenarioId}`);
                        if (executeBtn) {
                            executeBtn.disabled = false;
                        }
                    }
                }

                function readStream() {
                    // 获取执行按钮引用（在函数作用域内）
                    const executeBtn = document.getElementById(`execute-btn-${scenarioId}`);
                    // 使用外部作用域的finalParseBtn和finalLoadingSpinner（避免作用域问题）
                    const currentParseBtn = finalParseBtn;
                    const currentLoadingSpinner = finalLoadingSpinner;

                    reader.read().then(({ done, value }) => {
                        if (done) {
                            if (buffer.trim()) {
                                const lines = buffer.split('\n');
                                for (const line of lines) {
                                    if (line.trim()) {
                                        processParseLine(line, 'online');
                                    }
                                }
                                buffer = '';
                            }
                            // 解析完成后，确保启用执行按钮
                            if (executeBtn) {
                                executeBtn.disabled = false;
                            }
                            if (currentParseBtn) {
                                currentParseBtn.disabled = false;
                            }
                            if (currentLoadingSpinner) {
                                currentLoadingSpinner.remove();
                            }
                            // 确保列名显示区域可见
                            const displayArea = document.getElementById(`parse-columns-display-area-${scenarioId}`);
                            if (displayArea) {
                                displayArea.style.display = 'block';
                            }
                            return;
                        }

                        buffer += decoder.decode(value, { stream: true });
                        const lines = buffer.split('\n');
                        buffer = lines.pop() || '';

                        for (const line of lines) {
                            processParseLine(line, 'online');
                        }

                        readStream();
                    }).catch(error => {
                        appendOutput('online', '错误: ' + error.message, 'error');
                        if (currentParseBtn) {
                            currentParseBtn.disabled = false;
                        }
                        if (currentLoadingSpinner) {
                            currentLoadingSpinner.remove();
                        }
                    });
                }

                readStream();
            })
            .catch(error => {
                showAlert('解析失败: ' + error.message, 'error', 'online');
                // 重新获取按钮引用，因为可能在catch块中变量已失效
                const errorParseBtn = document.getElementById(`parse-btn-${scenarioId}`);
                if (errorParseBtn && errorParseBtn.parentElement) {
                    errorParseBtn.disabled = false;
                    const loadingSpinner = errorParseBtn.parentElement.querySelector('.loading');
                    if (loadingSpinner) loadingSpinner.remove();
                }
            });
    } catch (error) {
        showAlert('解析失败: ' + error.message, 'error', 'online');
        // 确保在catch块中也恢复按钮状态
        const catchParseBtn = document.getElementById(`parse-btn-${scenarioId}`);
        if (catchParseBtn && catchParseBtn.parentElement) {
            catchParseBtn.disabled = false;
            const loadingSpinner = catchParseBtn.parentElement.querySelector('.loading');
            if (loadingSpinner) loadingSpinner.remove();
        }
    }
}

// 执行特定场景
async function executeOnlineScenario(scenarioId) {
    const card = document.getElementById(scenarioId);
    if (!card) return;

    const executeBtn = document.getElementById(`execute-btn-${scenarioId}`);
    if (!executeBtn) {
        showAlert('执行按钮未找到', 'error', 'online');
        return;
    }
    if (executeBtn.disabled) {
        showAlert('执行按钮已禁用，请先解析JSON', 'error', 'online');
        return;
    }

    if (isExecutingOnline) {
        showAlert('正在执行中，请稍候...', 'error', 'online');
        return;
    }

    try {
        const getIntValue = (selector, defaultValue) => {
            const elem = card.querySelector(selector);
            if (!elem) return defaultValue;
            const val = elem.value;
            if (val === '' || val === null || val === undefined) return defaultValue;
            const parsed = parseInt(val);
            return isNaN(parsed) ? defaultValue : parsed;
        };

        // 安全地获取元素值，避免null错误
        const getValue = (selector, defaultValue = '') => {
            const elem = card.querySelector(selector);
            return elem ? (elem.value || defaultValue) : defaultValue;
        };
        const getChecked = (selector, defaultValue = false) => {
            const elem = card.querySelector(selector);
            return elem ? elem.checked : defaultValue;
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

        // 解析主键列：支持单列或逗号分隔的多列
        const parseKeyColumn = (selector, defaultValue) => {
            const val = (card.querySelector(selector)?.value || '').trim();
            if (!val) return defaultValue;
            if (val.includes(',')) {
                const parts = val.split(',').map(s => parseInt(s.trim())).filter(n => !isNaN(n));
                return parts.length > 0 ? parts : defaultValue;
            }
            const parsed = parseInt(val);
            return isNaN(parsed) ? defaultValue : parsed;
        };

        const config = {
            output_prefix: getValue('.online-scenario-output-prefix'),
            online_file: getFileValue('.online-scenario-online-filename', '.online-scenario-online-file'),
            offline_file: getFileValue('.online-scenario-offline-filename', '.online-scenario-offline-file'),
            json_column: getValue('.online-scenario-json-column'),
            online_key_column: parseKeyColumn('.online-scenario-online-key-column', 0),
            offline_key_column: parseKeyColumn('.online-scenario-offline-key-column', 1),
            online_feature_start_column: getIntValue('.online-scenario-online-feature-start', 3),
            offline_feature_start_column: getIntValue('.online-scenario-offline-feature-start', 3),
            convert_string_to_number: getChecked('.online-scenario-convert-string', false),
            enable_tolerance: getChecked('.online-scenario-enable-tolerance', false),
            tolerance_value: parseFloat(card.querySelector('.online-scenario-tolerance-value')?.value) || 0.000001,
            compare_common_features_only: getChecked('.online-scenario-compare-common-only', false),
            output_full_data: getChecked('.online-scenario-output-full-data', false)
        };

        if (!config.online_file) {
            showAlert('请上传线上文件', 'error', 'online');
            return;
        }

        if (!config.offline_file) {
            showAlert('请上传离线文件', 'error', 'online');
            return;
        }

        if (!config.json_column) {
            showAlert('请输入JSON列名', 'error', 'online');
            return;
        }

        clearOutput('online');

        isExecutingOnline = true;
        updateStatus('running', '执行中...', 'online');
        // 保存executeBtn和loadingSpinner的引用，避免在异步回调中失效
        const currentExecuteBtn = executeBtn;
        const loadingSpinner = document.getElementById('loading-spinner-online');
        const currentLoadingSpinner = loadingSpinner;

        if (currentExecuteBtn) {
            currentExecuteBtn.disabled = true;
        }
        if (currentLoadingSpinner) {
            currentLoadingSpinner.style.display = 'inline-block';
        }

        // 获取当前用户标识
        const userId = getUserId() || 'anonymous';

        // 直接发送config对象，不需要双重JSON编码
        fetch('/api/execute/online', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ config: config, user_id: userId })
        })
            .then(response => {
                if (!response.ok) {
                    throw new Error('执行失败');
                }

                const reader = response.body.getReader();
                const decoder = new TextDecoder();
                let buffer = '';

                function processLine(line, tab) {
                    if (line.startsWith('data: ')) {
                        try {
                            const data = JSON.parse(line.substring(6));
                            if (data.type === 'start') {
                                appendOutput(tab, data.message, 'info');
                                // 保存task_id
                                if (data.task_id) {
                                    window._currentOnlineTaskId = data.task_id;
                                }
                            } else if (data.type === 'output') {
                                appendOutput(tab, data.message, 'output');
                            } else if (data.type === 'error') {
                                appendOutput(tab, data.message, 'error');
                            } else if (data.type === 'end') {
                                appendOutput(tab, data.message, 'success');
                            }
                        } catch (e) {
                            // 忽略解析错误
                        }
                    }
                }

                function readStream() {
                    // 保存executeBtn和loadingSpinner的引用，避免在异步回调中失效
                    const savedExecuteBtn = currentExecuteBtn;
                    const savedLoadingSpinner = currentLoadingSpinner;

                    reader.read().then(({ done, value }) => {
                        if (done) {
                            if (buffer.trim()) {
                                const lines = buffer.split('\n');
                                for (const line of lines) {
                                    if (line.trim()) {
                                        processLine(line, 'online');
                                    }
                                }
                                buffer = '';
                            }
                            isExecutingOnline = false;
                            updateStatus('success', '执行完成', 'online');
                            showAlert('🎉 线上灰度对比执行完成！', 'success', 'online');
                            // 添加完成提示到输出面板
                            appendOutput('online', '🎉 任务执行完成！', 'success');
                            if (savedExecuteBtn) {
                                savedExecuteBtn.disabled = false;
                            }
                            if (savedLoadingSpinner) {
                                savedLoadingSpinner.style.display = 'none';
                            }
                            // 自动下载输出文件，并传入taskId
                            const taskId = window._currentOnlineTaskId || null;
                            setTimeout(() => autoDownloadOutputFiles('online_comparison', 2, taskId), 1000);
                            return;
                        }

                        buffer += decoder.decode(value, { stream: true });
                        const lines = buffer.split('\n');
                        buffer = lines.pop() || '';

                        for (const line of lines) {
                            processLine(line, 'online');
                        }

                        readStream();
                    }).catch(error => {
                        appendOutput('online', '错误: ' + error.message, 'error');
                        isExecutingOnline = false;
                        updateStatus('error', '执行失败', 'online');
                        if (savedExecuteBtn) {
                            savedExecuteBtn.disabled = false;
                        }
                        if (savedLoadingSpinner) {
                            savedLoadingSpinner.style.display = 'none';
                        }
                    });
                }

                readStream();
            })
            .catch(error => {
                showAlert('执行失败: ' + error.message, 'error', 'online');
                isExecutingOnline = false;
                updateStatus('error', '执行失败', 'online');
                if (currentExecuteBtn) {
                    currentExecuteBtn.disabled = false;
                }
                if (currentLoadingSpinner) {
                    currentLoadingSpinner.style.display = 'none';
                }
            });
    } catch (error) {
        showAlert('执行失败: ' + error.message, 'error', 'online');
        isExecutingOnline = false;
        updateStatus('error', '执行失败', 'online');
        // 重新获取按钮引用，因为可能在catch块中变量已失效
        const finalExecuteBtn = document.getElementById(`execute-btn-${scenarioId}`);
        const finalLoadingSpinner = document.getElementById('loading-spinner-online');
        if (finalExecuteBtn) {
            finalExecuteBtn.disabled = false;
        }
        if (finalLoadingSpinner) {
            finalLoadingSpinner.style.display = 'none';
        }
    }
}

function clearOnlineScenarioOutput(scenarioId) {
    // 清空online标签页的输出区域
    clearOutput('online');

    // 清空该场景的列名显示区域
    const parseColumnsDisplayArea = document.getElementById(`parse-columns-display-area-${scenarioId}`);
    if (parseColumnsDisplayArea) {
        parseColumnsDisplayArea.style.display = 'none';
    }

    const onlineColumnsSection = document.getElementById(`parse-online-columns-section-${scenarioId}`);
    if (onlineColumnsSection) {
        onlineColumnsSection.style.display = 'none';
    }

    const offlineColumnsSection = document.getElementById(`parse-offline-columns-section-${scenarioId}`);
    if (offlineColumnsSection) {
        offlineColumnsSection.style.display = 'none';
    }

    const onlineColumnsList = document.getElementById(`parse-online-columns-list-${scenarioId}`);
    if (onlineColumnsList) {
        onlineColumnsList.innerHTML = '';
    }

    const offlineColumnsList = document.getElementById(`parse-offline-columns-list-${scenarioId}`);
    if (offlineColumnsList) {
        offlineColumnsList.innerHTML = '';
    }

    // 禁用执行按钮（因为输出已清空，需要重新解析）
    const executeBtn = document.getElementById(`execute-btn-${scenarioId}`);
    if (executeBtn) {
        executeBtn.disabled = true;
    }
}

function toggleParseColumnsDisplay(scenarioId) {
    const area = document.getElementById(`parse-columns-display-area-${scenarioId}`);
    if (area) {
        area.style.display = area.style.display === 'none' ? 'block' : 'none';
    }
}

function parseOnlineJSON() {
    if (isParsingOnline) {
        showAlert('正在解析中，请稍候...', 'error', 'online');
        return;
    }

    try {
        const fullConfig = collectOnlineConfig();

        // 获取第一个启用的场景
        const enabledScenarios = fullConfig.scenarios.filter(s => s.enabled !== false);
        if (enabledScenarios.length === 0) {
            showAlert('没有启用的场景', 'error', 'online');
            return;
        }
        const config = enabledScenarios[0];

        if (!config.online_file) {
            showAlert('请上传线上文件', 'error', 'online');
            return;
        }

        if (!config.json_column) {
            showAlert('请输入JSON列名', 'error', 'online');
            return;
        }

        clearOutput('online');

        isParsingOnline = true;
        updateStatus('running', '解析JSON中...', 'online');
        document.getElementById('parse-btn-online').disabled = true;
        document.getElementById('loading-spinner-online').style.display = 'inline-block';
        isOnlineParsed = false;  // 重置解析状态
        document.getElementById('execute-btn-online').disabled = true;  // 禁用对比按钮

        // 只收集解析所需的配置（从步骤2读取索引配置）
        const parseConfig = {
            online_file: config.online_file,
            offline_file: config.offline_file || '',  // 添加离线文件，用于读取列名
            json_column: config.json_column,
            online_key_column: config.online_key_column || 0,  // 从步骤2读取，默认0
            convert_string_to_number: config.convert_string_to_number || false,  // 从步骤2读取，默认false
            output_prefix: config.output_prefix
        };

        // 直接发送parseConfig对象，不需要双重JSON编码
        fetch('/api/parse/online', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ config: parseConfig })
        })
            .then(response => {
                if (!response.ok) {
                    throw new Error('解析失败');
                }

                const reader = response.body.getReader();
                const decoder = new TextDecoder();
                let buffer = '';

                // 定义列名提取相关的变量和函数（用于解析JSON）
                let parseColumnsBuffer = [];
                let inParseColumnsSection = false;
                let offlineParseColumnsBuffer = [];
                let inOfflineParseColumnsSection = false;

                function processParseLine(line, tab) {
                    if (line.startsWith('data: ')) {
                        try {
                            const data = JSON.parse(line.substring(6));
                            if (data.type === 'start') {
                                appendOutput(tab, data.message, 'info');
                            } else if (data.type === 'output') {
                                const message = data.message;
                                appendOutput(tab, message, 'output');

                                // 检测列名信息
                                if (tab === 'online') {
                                    // 检测离线文件列名
                                    if (message.includes('离线文件列名')) {
                                        inOfflineParseColumnsSection = true;
                                        offlineParseColumnsBuffer = [];
                                        // 提取总列数
                                        const match = message.match(/共\s*(\d+)\s*列/);
                                        if (match) {
                                            // 将totalCount作为数组的一个特殊属性存储
                                            offlineParseColumnsBuffer.totalCount = parseInt(match[1]);
                                        }
                                    } else if (inOfflineParseColumnsSection) {
                                        // 如果包含顿号，说明是列名行
                                        if (message.includes('、')) {
                                            offlineParseColumnsBuffer.push(message);
                                            // 处理并显示离线文件列名
                                            extractAndDisplayOfflineParseColumns(offlineParseColumnsBuffer);
                                            inOfflineParseColumnsSection = false;
                                            offlineParseColumnsBuffer = [];
                                        } else if (message.includes('还有') || message.includes('列未显示')) {
                                            // 遇到提示信息，说明列名行已结束
                                            if (offlineParseColumnsBuffer.length > 0) {
                                                extractAndDisplayOfflineParseColumns(offlineParseColumnsBuffer);
                                            }
                                            inOfflineParseColumnsSection = false;
                                            offlineParseColumnsBuffer = [];
                                        }
                                    }

                                    // 检测解析后的文件列名
                                    if (message.includes('解析后的文件列名')) {
                                        inParseColumnsSection = true;
                                        parseColumnsBuffer = [];
                                        // 提取总列数
                                        const match = message.match(/共\s*(\d+)\s*列/);
                                        if (match) {
                                            // 将totalCount作为数组的一个特殊属性存储
                                            parseColumnsBuffer.totalCount = parseInt(match[1]);
                                        }
                                    } else if (inParseColumnsSection) {
                                        // 如果包含顿号，说明是列名行
                                        if (message.includes('、')) {
                                            parseColumnsBuffer.push(message);
                                            // 处理并显示解析后的文件列名
                                            extractAndDisplayParseColumns(parseColumnsBuffer);
                                            isOnlineParsed = true;
                                            inParseColumnsSection = false;
                                            parseColumnsBuffer = [];
                                        } else if (message.includes('还有') || message.includes('列未显示')) {
                                            // 遇到提示信息，说明列名行已结束
                                            if (parseColumnsBuffer.length > 0) {
                                                extractAndDisplayParseColumns(parseColumnsBuffer);
                                                isOnlineParsed = true;
                                            }
                                            inParseColumnsSection = false;
                                            parseColumnsBuffer = [];
                                        }
                                    }
                                }
                            } else if (data.type === 'error') {
                                appendOutput(tab, data.message, 'error');
                            } else if (data.type === 'end') {
                                // 结束时处理剩余的列名
                                if (tab === 'online') {
                                    if (offlineParseColumnsBuffer.length > 0) {
                                        extractAndDisplayOfflineParseColumns(offlineParseColumnsBuffer);
                                    }
                                    if (parseColumnsBuffer.length > 0) {
                                        extractAndDisplayParseColumns(parseColumnsBuffer);
                                        isOnlineParsed = true;
                                    }
                                }
                                appendOutput(tab, data.message, 'success');
                            }
                        } catch (e) {
                            // 忽略解析错误
                        }
                    }
                }

                function extractAndDisplayOfflineParseColumns(buffer) {
                    // 处理buffer数组（过滤掉非字符串元素）
                    const lines = [];
                    for (let i = 0; i < buffer.length; i++) {
                        if (typeof buffer[i] === 'string') {
                            lines.push(buffer[i]);
                        }
                    }

                    // 解析格式：特征名1、特征名2、特征名3...
                    let columnNames = [];
                    for (const line of lines) {
                        // 用顿号分隔
                        if (line.includes('、')) {
                            const cols = line.split('、');
                            columnNames = cols.map(col => col.trim()).filter(col => col && !col.includes('还有') && !col.includes('列未显示'));
                            break;
                        }
                    }

                    // 只取前5列
                    const validColumns = columnNames.slice(0, 5);
                    if (validColumns.length > 0) {
                        // 从消息中提取总列数
                        let totalCount = buffer.totalCount || null;
                        if (!totalCount && lines.length > 0) {
                            const match = lines[0].match(/共\s*(\d+)\s*列/);
                            if (match) {
                                totalCount = parseInt(match[1]);
                            }
                        }
                        // 显示在步骤1的解析按钮下方
                        displayParseOfflineColumns(validColumns, totalCount || validColumns.length);
                    }
                }

                function extractAndDisplayParseColumns(buffer) {
                    // 处理buffer数组（过滤掉非字符串元素）
                    const lines = [];
                    for (let i = 0; i < buffer.length; i++) {
                        if (typeof buffer[i] === 'string') {
                            lines.push(buffer[i]);
                        }
                    }

                    // 解析格式：特征名1、特征名2、特征名3...
                    let columnNames = [];
                    for (const line of lines) {
                        // 用顿号分隔
                        if (line.includes('、')) {
                            const cols = line.split('、');
                            columnNames = cols.map(col => col.trim()).filter(col => col && !col.includes('还有') && !col.includes('列未显示'));
                            break;
                        }
                    }

                    // 只取前5列
                    const validColumns = columnNames.slice(0, 5);
                    if (validColumns.length > 0) {
                        // 从消息中提取总列数
                        let totalCount = buffer.totalCount || null;
                        if (!totalCount && lines.length > 0) {
                            const match = lines[0].match(/共\s*(\d+)\s*列/);
                            if (match) {
                                totalCount = parseInt(match[1]);
                            }
                        }
                        const actualTotalCount = totalCount || validColumns.length;
                        // 显示在步骤1的解析按钮下方
                        displayParseOnlineColumns(validColumns, actualTotalCount);
                        // 标记JSON已解析完成，启用对比按钮
                        isOnlineParsed = true;
                        document.getElementById('execute-btn-online').disabled = false;
                    }
                }

                function processParseBuffer(buf, tab) {
                    const lines = buf.split('\n');
                    for (const line of lines) {
                        if (line.trim()) {
                            processParseLine(line, tab);
                        }
                    }
                }

                function readStream() {
                    reader.read().then(({ done, value }) => {
                        if (done) {
                            if (buffer.trim()) {
                                processParseBuffer(buffer, 'online');
                                buffer = '';
                            }
                            isParsingOnline = false;
                            updateStatus('success', '解析完成', 'online');
                            document.getElementById('parse-btn-online').disabled = false;
                            document.getElementById('loading-spinner-online').style.display = 'none';

                            // 解析完成后启用对比按钮
                            setTimeout(() => {
                                // 无论列名是否提取成功，都标记为已解析并启用按钮
                                isOnlineParsed = true;
                                document.getElementById('execute-btn-online').disabled = false;
                                showAlert('JSON解析完成，可以开始对比', 'success', 'online');
                            }, 500);
                            return;
                        }

                        buffer += decoder.decode(value, { stream: true });
                        const lines = buffer.split('\n');
                        buffer = lines.pop() || '';

                        for (const line of lines) {
                            processParseLine(line, 'online');
                        }

                        readStream();
                    }).catch(error => {
                        appendOutput('online', '错误: ' + error.message, 'error');
                        isParsingOnline = false;
                        updateStatus('error', '解析失败', 'online');
                        document.getElementById('parse-btn-online').disabled = false;
                        document.getElementById('loading-spinner-online').style.display = 'none';
                    });
                }

                readStream();
            })
            .catch(error => {
                appendOutput('online', '解析错误: ' + error.message, 'error');
                isParsingOnline = false;
                updateStatus('error', '解析失败', 'online');
                document.getElementById('parse-btn-online').disabled = false;
                document.getElementById('loading-spinner-online').style.display = 'none';
            });

    } catch (error) {
        showAlert('解析失败: ' + error.message, 'error', 'online');
        isParsingOnline = false;
        updateStatus('error', '解析失败', 'online');
        document.getElementById('loading-spinner-online').style.display = 'none';
    }
}

function executeOnlineConfig() {
    if (isExecutingOnline) {
        showAlert('正在执行中，请稍候...', 'error', 'online');
        return;
    }

    // 注意：不再检查isOnlineParsed，因为后端会自动查找已存在的解析文件
    // 如果没有解析文件，后端会自动进行解析

    try {
        const config = collectOnlineConfig();

        // 验证多场景配置
        if (!config.scenarios || config.scenarios.length === 0) {
            showAlert('没有配置场景', 'error', 'online');
            return;
        }

        // 检查第一个启用的场景
        const enabledScenarios = config.scenarios.filter(s => s.enabled !== false);
        if (enabledScenarios.length === 0) {
            showAlert('没有启用的场景', 'error', 'online');
            return;
        }

        const firstScenario = enabledScenarios[0];
        if (!firstScenario.online_file) {
            showAlert('请上传线上文件', 'error', 'online');
            return;
        }

        if (!firstScenario.offline_file) {
            showAlert('请上传离线文件', 'error', 'online');
            return;
        }

        if (!firstScenario.json_column) {
            showAlert('请输入JSON列名', 'error', 'online');
            return;
        }

        clearOutput('online');

        isExecutingOnline = true;
        updateStatus('running', '执行中...', 'online');
        document.getElementById('execute-btn-online').disabled = true;
        document.getElementById('loading-spinner-online').style.display = 'inline-block';

        // 直接发送config对象，不需要双重JSON编码
        fetch('/api/execute/online', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ config: config })
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
                                processBuffer(buffer, 'online');
                                buffer = '';
                            }
                            isExecutingOnline = false;
                            updateStatus('success', '执行完成', 'online');
                            showAlert('🎉 线上灰度对比执行完成！', 'success', 'online');
                            appendOutput('online', '🎉 任务执行完成！', 'success');
                            document.getElementById('execute-btn-online').disabled = false;
                            document.getElementById('loading-spinner-online').style.display = 'none';
                            // 自动下载输出文件，并传入taskId
                            const taskId = window._currentOnlineTaskId || null;
                            setTimeout(() => autoDownloadOutputFiles('online_comparison', 2, taskId), 1000);
                            return;
                        }

                        buffer += decoder.decode(value, { stream: true });
                        const lines = buffer.split('\n');
                        buffer = lines.pop() || '';

                        for (const line of lines) {
                            processLine(line, 'online');
                        }

                        readStream();
                    }).catch(error => {
                        appendOutput('online', '错误: ' + error.message, 'error');
                        isExecutingOnline = false;
                        updateStatus('error', '执行失败', 'online');
                        document.getElementById('execute-btn-online').disabled = false;
                        document.getElementById('loading-spinner-online').style.display = 'none';
                    });
                }

                let columnsBuffer = [];
                let inColumnsSection = false;
                let offlineColumnsBuffer = [];
                let inOfflineColumnsSection = false;

                function processLine(line, tab) {
                    if (line.startsWith('data: ')) {
                        try {
                            const data = JSON.parse(line.substring(6));
                            if (data.type === 'start') {
                                appendOutput(tab, data.message, 'info');
                                // 保存task_id
                                if (data.task_id) {
                                    window._currentOnlineTaskId = data.task_id;
                                }
                            } else if (data.type === 'output') {
                                const message = data.message;
                                appendOutput(tab, message, 'output');

                                // 检测列名信息（线上灰度落数对比）
                                if (tab === 'online') {
                                    // 检测解析后的文件列名（步骤1：JSON解析）
                                    if (message.includes('解析后的文件列名')) {
                                        inColumnsSection = true;
                                        columnsBuffer = [];
                                    } else if (inColumnsSection && message.includes('=')) {
                                        // 遇到分隔线，处理已收集的列名
                                        if (columnsBuffer.length > 0) {
                                            extractAndDisplayColumns(columnsBuffer);
                                            // 标记JSON已解析完成
                                            isOnlineParsed = true;
                                        }
                                        inColumnsSection = false;
                                        columnsBuffer = [];
                                    } else if (inColumnsSection && message.trim() && !message.includes('=')) {
                                        // 收集列名行
                                        columnsBuffer.push(message);
                                    }

                                    // 检测离线文件列名（步骤2：对比时）
                                    if (message.includes('离线文件列名')) {
                                        inOfflineColumnsSection = true;
                                        offlineColumnsBuffer = [];
                                    } else if (inOfflineColumnsSection && message.includes('=')) {
                                        // 遇到分隔线，处理已收集的离线文件列名
                                        if (offlineColumnsBuffer.length > 0) {
                                            extractAndDisplayOfflineColumns(offlineColumnsBuffer);
                                        }
                                        inOfflineColumnsSection = false;
                                        offlineColumnsBuffer = [];
                                    } else if (inOfflineColumnsSection && message.trim() && !message.includes('=')) {
                                        // 收集离线文件列名行
                                        offlineColumnsBuffer.push(message);
                                    }
                                }
                            } else if (data.type === 'error') {
                                appendOutput(tab, data.message, 'error');
                            } else if (data.type === 'end') {
                                // 结束时处理剩余的列名
                                if (tab === 'online') {
                                    if (columnsBuffer.length > 0) {
                                        extractAndDisplayColumns(columnsBuffer);
                                        isOnlineParsed = true;
                                    }
                                    if (offlineColumnsBuffer.length > 0) {
                                        extractAndDisplayOfflineColumns(offlineColumnsBuffer);
                                    }
                                }
                                appendOutput(tab, data.message, 'success');
                            }
                        } catch (e) {
                            // 忽略解析错误
                        }
                    }
                }

                function extractAndDisplayColumns(buffer) {
                    // 解析格式：特征名1、特征名2、特征名3...
                    let columnNames = [];
                    for (const line of buffer) {
                        // 用顿号分隔
                        if (line.includes('、')) {
                            const cols = line.split('、');
                            columnNames = cols.map(col => col.trim()).filter(col => col && !col.includes('还有') && !col.includes('列未显示'));
                            break;
                        }
                    }

                    // 只取前5列
                    const validColumns = columnNames.slice(0, 5);
                    if (validColumns.length > 0) {
                        // 显示在步骤1的解析按钮下方（执行对比时也会显示）
                        displayParseOnlineColumns(validColumns, validColumns.length);
                        // 标记JSON已解析完成，启用对比按钮
                        isOnlineParsed = true;
                        document.getElementById('execute-btn-online').disabled = false;
                    }
                }

                function extractAndDisplayOfflineColumns(buffer) {
                    // 解析格式：特征名1、特征名2、特征名3...
                    let columnNames = [];
                    for (const line of buffer) {
                        // 用顿号分隔
                        if (line.includes('、')) {
                            const cols = line.split('、');
                            columnNames = cols.map(col => col.trim()).filter(col => col && !col.includes('还有') && !col.includes('列未显示'));
                            break;
                        }
                    }

                    // 只取前5列
                    const validColumns = columnNames.slice(0, 5);
                    if (validColumns.length > 0) {
                        // 显示在步骤1的解析按钮下方（执行对比时也会显示）
                        displayParseOfflineColumns(validColumns, validColumns.length);
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
                appendOutput('online', '执行错误: ' + error.message, 'error');
                isExecutingOnline = false;
                updateStatus('error', '执行失败', 'online');
                document.getElementById('execute-btn-online').disabled = false;
                document.getElementById('loading-spinner-online').style.display = 'none';
            });

    } catch (error) {
        showAlert('执行失败: ' + error.message, 'error', 'online');
        isExecutingOnline = false;
        updateStatus('error', '执行失败', 'online');
        document.getElementById('loading-spinner-online').style.display = 'none';
    }
}

function clearOnlineOutput() {
    clearOutput('online');
    // 清空列名显示（步骤1解析按钮下方的显示区域）
    document.getElementById('parse-columns-display-area').style.display = 'none';
    document.getElementById('parse-offline-columns-section').style.display = 'none';
    document.getElementById('parse-offline-columns-list').innerHTML = '';
    document.getElementById('parse-online-columns-section').style.display = 'none';
    document.getElementById('parse-online-columns-list').innerHTML = '';
    // 重置解析状态
    isOnlineParsed = false;
}

// 清空特定场景的输出
function clearOnlineScenarioOutput(scenarioId) {
    // 清空online标签页的输出区域
    clearOutput('online');

    // 清空该场景的列名显示区域
    const parseColumnsDisplayArea = document.getElementById(`parse-columns-display-area-${scenarioId}`);
    if (parseColumnsDisplayArea) {
        parseColumnsDisplayArea.style.display = 'none';
    }

    const onlineColumnsSection = document.getElementById(`parse-online-columns-section-${scenarioId}`);
    if (onlineColumnsSection) {
        onlineColumnsSection.style.display = 'none';
    }

    const offlineColumnsSection = document.getElementById(`parse-offline-columns-section-${scenarioId}`);
    if (offlineColumnsSection) {
        offlineColumnsSection.style.display = 'none';
    }

    const onlineColumnsList = document.getElementById(`parse-online-columns-list-${scenarioId}`);
    if (onlineColumnsList) {
        onlineColumnsList.innerHTML = '';
    }

    const offlineColumnsList = document.getElementById(`parse-offline-columns-list-${scenarioId}`);
    if (offlineColumnsList) {
        offlineColumnsList.innerHTML = '';
    }

    // 禁用执行按钮（因为输出已清空，需要重新解析）
    const executeBtn = document.getElementById(`execute-btn-${scenarioId}`);
    if (executeBtn) {
        executeBtn.disabled = true;
    }
}

function toggleColumnsDisplay() {
    const area = document.getElementById('columns-display-area');
    area.style.display = area.style.display === 'none' ? 'block' : 'none';
}

function displayParsedColumns(columns, totalCount = null) {
    const columnsList = document.getElementById('columns-list');
    const displayArea = document.getElementById('columns-display-area');

    if (!columns || columns.length === 0) {
        columnsList.innerHTML = '<div style="color: #666;">暂无列名信息</div>';
        return;
    }

    // 只显示前5列
    const displayColumns = columns.slice(0, 5);
    const actualTotalCount = totalCount || columns.length;

    let html = `<div style="margin-bottom: 8px; color: #555; font-weight: 500;">共 ${actualTotalCount} 列（显示前5列）：</div>`;
    html += '<div style="display: grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); gap: 8px;">';

    displayColumns.forEach((col, index) => {
        html += `<div style="padding: 4px 8px; background: white; border-radius: 4px; border: 1px solid #e0e0e0;">
            <span style="color: #667eea; font-weight: 500;">列${index}:</span> 
            <span style="color: #333;">${col}</span>
        </div>`;
    });

    if (actualTotalCount > 5) {
        html += `<div style="padding: 4px 8px; background: #f8f9fa; border-radius: 4px; border: 1px solid #e0e0e0; grid-column: 1 / -1; text-align: center; color: #666; font-style: italic;">
            ... 还有 ${actualTotalCount - 5} 列未显示
        </div>`;
    }

    html += '</div>';
    columnsList.innerHTML = html;
    displayArea.style.display = 'block';
}

function toggleParseColumnsDisplay() {
    const area = document.getElementById('parse-columns-display-area');
    area.style.display = area.style.display === 'none' ? 'block' : 'none';
}

function displayParseOfflineColumns(columns, totalCount = null, scenarioId = null) {
    // 如果提供了scenarioId，使用场景特定的ID，否则使用默认ID（兼容旧代码）
    const idSuffix = scenarioId ? `-${scenarioId}` : '';
    const columnsList = document.getElementById(`parse-offline-columns-list${idSuffix}`);
    const displaySection = document.getElementById(`parse-offline-columns-section${idSuffix}`);
    const displayArea = document.getElementById(`parse-columns-display-area${idSuffix}`);

    if (!columns || columns.length === 0) {
        if (columnsList) {
            columnsList.innerHTML = '<div style="color: #666;">暂无列名信息</div>';
        }
        return;
    }

    if (!columnsList || !displaySection || !displayArea) {
        console.warn('列名显示元素未找到', { columnsList, displaySection, displayArea });
        return;
    }

    // 只显示前5列，用顿号分隔
    const displayColumns = columns.slice(0, 5);
    const actualTotalCount = totalCount || columns.length;

    // 简化为只显示特征名，用顿号分隔
    const columnText = displayColumns.join('、');
    let html = `<div style="color: #333; font-size: 13px; line-height: 1.6;">${columnText}</div>`;
    if (actualTotalCount > 5) {
        html += `<div style="margin-top: 4px; color: #666; font-size: 11px;">共 ${actualTotalCount} 列，还有 ${actualTotalCount - 5} 列未显示</div>`;
    }

    columnsList.innerHTML = html;
    displaySection.style.display = 'block';
    displayArea.style.display = 'block';
}

function displayParseOnlineColumns(columns, totalCount = null, scenarioId = null) {
    // 如果提供了scenarioId，使用场景特定的ID，否则使用默认ID（兼容旧代码）
    const idSuffix = scenarioId ? `-${scenarioId}` : '';
    const columnsList = document.getElementById(`parse-online-columns-list${idSuffix}`);
    const displaySection = document.getElementById(`parse-online-columns-section${idSuffix}`);
    const displayArea = document.getElementById(`parse-columns-display-area${idSuffix}`);

    if (!columns || columns.length === 0) {
        if (columnsList) {
            columnsList.innerHTML = '<div style="color: #666;">暂无列名信息</div>';
        }
        return;
    }

    if (!columnsList || !displaySection || !displayArea) {
        console.warn('列名显示元素未找到', { columnsList, displaySection, displayArea });
        return;
    }

    // 只显示前5列，用顿号分隔
    const displayColumns = columns.slice(0, 5);
    const actualTotalCount = totalCount || columns.length;

    // 简化为只显示特征名，用顿号分隔
    const columnText = displayColumns.join('、');
    let html = `<div style="color: #333; font-size: 13px; line-height: 1.6;">${columnText}</div>`;
    if (actualTotalCount > 5) {
        html += `<div style="margin-top: 4px; color: #666; font-size: 11px;">共 ${actualTotalCount} 列，还有 ${actualTotalCount - 5} 列未显示</div>`;
    }

    columnsList.innerHTML = html;
    displaySection.style.display = 'block';
    displayArea.style.display = 'block';
}

// 页面加载时自动加载配置
window.addEventListener('DOMContentLoaded', function () {
    loadConfig();
    loadOnlineConfig();
});

