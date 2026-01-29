// ========== 数据对比相关函数 ==========

let compareFile1 = null;
let compareFile2 = null;
let isExecutingCompare = false;

async function handleCompareFileSelect(fileNum, input) {
    const file = input.files[0];
    if (!file) return;

    if (!file.name.endsWith('.csv') && !file.name.endsWith('.xlsx')) {
        showAlert('只支持CSV和XLSX文件', 'error', 'compare');
        input.value = '';
        return;
    }

    const fileInfo = document.getElementById(`file-info-compare-${fileNum}`);
    fileInfo.textContent = `上传中: ${file.name}...`;
    fileInfo.style.color = '#667eea';

    try {
        const formData = new FormData();
        formData.append('file', file);
        formData.append('file_num', fileNum);

        const response = await fetch('/api/compare/upload', {
            method: 'POST',
            body: formData
        });

        const data = await response.json();

        if (data.success) {
            if (fileNum === 1) {
                compareFile1 = data.filename;
            } else {
                compareFile2 = data.filename;
            }
            
            fileInfo.textContent = `✓ 已上传: ${data.filename}`;
            fileInfo.style.color = '#28a745';
            
            // 检查是否两个文件都已上传
            if (compareFile1 && compareFile2) {
                document.getElementById('btn-execute-compare').disabled = false;
            }
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

async function executeCompare() {
    if (isExecutingCompare) {
        showAlert('正在执行中，请稍候...', 'error', 'compare');
        return;
    }

    if (!compareFile1 || !compareFile2) {
        showAlert('请先上传两个文件', 'error', 'compare');
        return;
    }

    isExecutingCompare = true;
    const executeBtn = document.getElementById('btn-execute-compare');
    const statusIndicator = document.getElementById('status-indicator-compare');
    const statusText = document.getElementById('status-text-compare');
    const loadingSpinner = document.getElementById('loading-spinner-compare');
    const outputPanel = document.getElementById('output-panel-compare');

    executeBtn.disabled = true;
    statusIndicator.className = 'status-indicator running';
    statusText.textContent = '执行中...';
    loadingSpinner.style.display = 'inline-block';
    outputPanel.innerHTML = '';

    try {
        const config = {
            file1: compareFile1,
            file2: compareFile2,
            key_column_1: parseInt(document.getElementById('compare-key-column-1').value) || 0,
            key_column_2: parseInt(document.getElementById('compare-key-column-2').value) || 0,
            feature_start_1: parseInt(document.getElementById('compare-feature-start-1').value) || 1,
            feature_start_2: parseInt(document.getElementById('compare-feature-start-2').value) || 1,
            output_prefix: document.getElementById('compare-output-prefix').value || 'compare',
            convert_feature_to_number: document.getElementById('compare-convert-feature').checked
        };

        const response = await fetch('/api/compare/execute', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ config: config })
        });

        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }

        const reader = response.body.getReader();
        const decoder = new TextDecoder();

        while (true) {
            const { done, value } = await reader.read();
            if (done) break;

            const chunk = decoder.decode(value);
            const lines = chunk.split('\n');

            for (const line of lines) {
                if (line.startsWith('data: ')) {
                    try {
                        const data = JSON.parse(line.substring(6));
                        
                        if (data.type === 'output') {
                            const outputLine = document.createElement('div');
                            outputLine.className = 'output-line';
                            outputLine.textContent = data.message;
                            
                            if (data.message.includes('✅') || data.message.includes('成功')) {
                                outputLine.classList.add('success');
                            } else if (data.message.includes('❌') || data.message.includes('错误') || data.message.includes('失败')) {
                                outputLine.classList.add('error');
                            } else if (data.message.includes('⚠️') || data.message.includes('警告')) {
                                outputLine.classList.add('warning');
                            } else if (data.message.includes('[INFO]')) {
                                outputLine.classList.add('info');
                            }
                            
                            outputPanel.appendChild(outputLine);
                            outputPanel.scrollTop = outputPanel.scrollHeight;
                        } else if (data.type === 'end') {
                            statusIndicator.className = 'status-indicator success';
                            statusText.textContent = '执行完成';
                            showAlert('数据对比完成！', 'success', 'compare');
                        } else if (data.type === 'error') {
                            statusIndicator.className = 'status-indicator error';
                            statusText.textContent = '执行失败';
                            showAlert(data.message, 'error', 'compare');
                        }
                    } catch (e) {
                        console.error('解析输出失败:', e);
                    }
                }
            }
        }
    } catch (error) {
        statusIndicator.className = 'status-indicator error';
        statusText.textContent = '执行失败';
        showAlert('执行失败: ' + error.message, 'error', 'compare');
        
        const errorLine = document.createElement('div');
        errorLine.className = 'output-line error';
        errorLine.textContent = `❌ 错误: ${error.message}`;
        outputPanel.appendChild(errorLine);
    } finally {
        isExecutingCompare = false;
        executeBtn.disabled = false;
        loadingSpinner.style.display = 'none';
    }
}

function clearCompareOutput() {
    const outputPanel = document.getElementById('output-panel-compare');
    const statusIndicator = document.getElementById('status-indicator-compare');
    const statusText = document.getElementById('status-text-compare');
    
    outputPanel.innerHTML = '<div class="output-line info">等待执行...</div>';
    statusIndicator.className = 'status-indicator';
    statusText.textContent = '就绪';
}

// 保存数据对比配置
async function saveCompareConfig() {
    try {
        console.log('[DEBUG] 开始保存配置...');
        
        const config = {
            scenarios: [{
                name: "当前配置",
                enabled: true,
                description: "通过Web界面保存的配置",
                sql_file: compareFile1 || "",
                api_file: compareFile2 || "",
                sql_key_column: parseInt(document.getElementById('compare-key-column-1').value) || 0,
                api_key_column: parseInt(document.getElementById('compare-key-column-2').value) || 0,
                sql_feature_start: parseInt(document.getElementById('compare-feature-start-1').value) || 1,
                api_feature_start: parseInt(document.getElementById('compare-feature-start-2').value) || 1,
                convert_feature_to_number: document.getElementById('compare-convert-feature').checked,
                output_prefix: document.getElementById('compare-output-prefix').value || 'compare'
            }],
            global_config: {
                default_convert_feature_to_number: document.getElementById('compare-convert-feature').checked,
                default_sql_key_column: parseInt(document.getElementById('compare-key-column-1').value) || 0,
                default_api_key_column: parseInt(document.getElementById('compare-key-column-2').value) || 0,
                default_sql_feature_start: parseInt(document.getElementById('compare-feature-start-1').value) || 1,
                default_api_feature_start: parseInt(document.getElementById('compare-feature-start-2').value) || 1
            }
        };

        console.log('[DEBUG] 配置数据:', config);

        const response = await fetch('/api/compare/config/save', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(config)
        });

        console.log('[DEBUG] 响应状态:', response.status);

        const data = await response.json();
        console.log('[DEBUG] 响应数据:', data);

        if (data.success) {
            showAlert('✅ 配置保存成功！保存到 data_comparison/config.json', 'success', 'compare');
            console.log('[SUCCESS] 配置保存成功');
        } else {
            showAlert('❌ 配置保存失败: ' + data.error, 'error', 'compare');
            console.error('[ERROR] 配置保存失败:', data.error);
        }
    } catch (error) {
        showAlert('❌ 配置保存失败: ' + error.message, 'error', 'compare');
        console.error('[ERROR] 配置保存异常:', error);
    }
}

// 加载数据对比配置
async function loadCompareConfig() {
    try {
        console.log('[DEBUG] 开始加载配置...');
        
        const response = await fetch('/api/compare/config/load', {
            method: 'GET'
        });

        console.log('[DEBUG] 响应状态:', response.status);

        const data = await response.json();
        console.log('[DEBUG] 响应数据:', data);

        if (data.success && data.config) {
            const config = data.config;
            console.log('[DEBUG] 配置内容:', config);
            
            // 加载全局配置
            if (config.global_config) {
                const gc = config.global_config;
                console.log('[DEBUG] 加载全局配置:', gc);
                document.getElementById('compare-key-column-1').value = gc.default_sql_key_column || 0;
                document.getElementById('compare-key-column-2').value = gc.default_api_key_column || 0;
                document.getElementById('compare-feature-start-1').value = gc.default_sql_feature_start || 1;
                document.getElementById('compare-feature-start-2').value = gc.default_api_feature_start || 1;
                document.getElementById('compare-convert-feature').checked = gc.default_convert_feature_to_number !== false;
            }
            
            // 加载第一个场景的配置（如果存在）
            if (config.scenarios && config.scenarios.length > 0) {
                const scenario = config.scenarios[0];
                console.log('[DEBUG] 加载场景配置:', scenario);
                
                // 更新文件信息显示
                if (scenario.sql_file) {
                    compareFile1 = scenario.sql_file;
                    document.getElementById('file-info-compare-1').textContent = `配置中的文件: ${scenario.sql_file}`;
                    document.getElementById('file-info-compare-1').style.color = '#667eea';
                    console.log('[DEBUG] 设置文件1:', scenario.sql_file);
                }
                
                if (scenario.api_file) {
                    compareFile2 = scenario.api_file;
                    document.getElementById('file-info-compare-2').textContent = `配置中的文件: ${scenario.api_file}`;
                    document.getElementById('file-info-compare-2').style.color = '#667eea';
                    console.log('[DEBUG] 设置文件2:', scenario.api_file);
                }
                
                // 更新其他配置
                if (scenario.sql_key_column !== undefined) {
                    document.getElementById('compare-key-column-1').value = scenario.sql_key_column;
                    console.log('[DEBUG] 设置SQL关键列:', scenario.sql_key_column);
                }
                if (scenario.api_key_column !== undefined) {
                    document.getElementById('compare-key-column-2').value = scenario.api_key_column;
                    console.log('[DEBUG] 设置API关键列:', scenario.api_key_column);
                }
                if (scenario.sql_feature_start !== undefined) {
                    document.getElementById('compare-feature-start-1').value = scenario.sql_feature_start;
                    console.log('[DEBUG] 设置SQL特征起始列:', scenario.sql_feature_start);
                }
                if (scenario.api_feature_start !== undefined) {
                    document.getElementById('compare-feature-start-2').value = scenario.api_feature_start;
                    console.log('[DEBUG] 设置API特征起始列:', scenario.api_feature_start);
                }
                if (scenario.output_prefix) {
                    document.getElementById('compare-output-prefix').value = scenario.output_prefix;
                    console.log('[DEBUG] 设置输出前缀:', scenario.output_prefix);
                }
                if (scenario.convert_feature_to_number !== undefined) {
                    document.getElementById('compare-convert-feature').checked = scenario.convert_feature_to_number;
                    console.log('[DEBUG] 设置特征转换:', scenario.convert_feature_to_number);
                }
                
                // 如果两个文件都存在，启用执行按钮
                if (compareFile1 && compareFile2) {
                    document.getElementById('btn-execute-compare').disabled = false;
                    console.log('[DEBUG] 两个文件都存在，启用执行按钮');
                }
            }
            
            console.log('[SUCCESS] 配置加载成功');
            showAlert('✅ 配置加载成功！', 'success', 'compare');
        } else {
            console.warn('[WARN] 配置加载失败或配置为空');
            showAlert('⚠️ 配置加载失败: ' + (data.error || '未找到配置文件'), 'error', 'compare');
        }
    } catch (error) {
        console.error('[ERROR] 配置加载异常:', error);
        showAlert('❌ 配置加载失败: ' + error.message, 'error', 'compare');
    }
}


// ========== 页面加载时自动加载配置 ==========
document.addEventListener('DOMContentLoaded', function() {
    // 检查是否在数据对比页面
    const comparePage = document.getElementById('page-compare');
    if (comparePage) {
        console.log('[INFO] 页面加载完成，自动加载数据对比配置...');
        // 延迟500ms加载配置，确保页面元素已完全初始化
        setTimeout(() => {
            loadCompareConfig();
        }, 500);
    }
});
