// ========== 数据对比相关函数 ==========

let compareFile1 = null;
let compareFile2 = null;
let isExecutingCompare = false;
let fileInputMode = 'upload'; // 'upload' 或 'path'

/**
 * 解析主键列输入
 * 支持单列(数字)或多列(逗号分隔的数字)
 * @param {string} input - 输入字符串
 * @returns {number|number[]} - 单列返回数字，多列返回数组
 */
function parseKeyColumns(input) {
    const trimmed = input.trim();

    // 检查是否包含逗号
    if (trimmed.includes(',')) {
        // 多列主键：分割并转换为数字数组
        const columns = trimmed.split(',')
            .map(s => s.trim())
            .filter(s => s !== '')
            .map(s => parseInt(s))
            .filter(n => !isNaN(n) && n >= 0);

        return columns.length > 0 ? columns : 0;
    } else {
        // 单列主键：直接转换为数字
        const num = parseInt(trimmed);
        return isNaN(num) || num < 0 ? 0 : num;
    }
}

/**
 * 格式化主键列显示
 * @param {number|number[]} keyColumn - 主键列配置
 * @returns {string} - 格式化后的字符串
 */
function formatKeyColumns(keyColumn) {
    if (Array.isArray(keyColumn)) {
        return keyColumn.join(',');
    }
    return String(keyColumn);
}

// 切换文件输入模式
function toggleFileInputMode() {
    const mode = document.querySelector('input[name="file-input-mode"]:checked').value;
    fileInputMode = mode;

    const uploadContainer = document.getElementById('upload-mode-container');
    const pathContainer = document.getElementById('path-mode-container');

    if (mode === 'upload') {
        uploadContainer.style.display = 'block';
        pathContainer.style.display = 'none';
    } else {
        uploadContainer.style.display = 'none';
        pathContainer.style.display = 'block';
    }

    // 检查是否可以启用执行按钮
    checkCompareReady();
}

// 处理路径输入
function handlePathInput() {
    const path1 = document.getElementById('compare-path1').value.trim();
    const path2 = document.getElementById('compare-path2').value.trim();

    if (path1) {
        compareFile1 = 'PATH:' + path1;
    }
    if (path2) {
        compareFile2 = 'PATH:' + path2;
    }

    checkCompareReady();
}

// 检查是否可以执行对比
function checkCompareReady() {
    const btn = document.getElementById('btn-execute-compare');
    if (fileInputMode === 'upload') {
        btn.disabled = !(compareFile1 && compareFile2 && !compareFile1.startsWith('PATH:') && !compareFile2.startsWith('PATH:'));
    } else {
        const path1 = document.getElementById('compare-path1').value.trim();
        const path2 = document.getElementById('compare-path2').value.trim();
        btn.disabled = !(path1 && path2);
    }
}

async function handleCompareFileSelect(fileNum, input) {
    const file = input.files[0];
    if (!file) return;

    if (!file.name.endsWith('.csv') && !file.name.endsWith('.xlsx') && !file.name.endsWith('.xls')) {
        showAlert('只支持CSV和XLSX文件', 'error', 'compare');
        input.value = '';
        return;
    }

    const fileInfo = document.getElementById(`file-info-compare-${fileNum}`);

    // 显示文件大小
    const fileSizeMB = (file.size / 1024 / 1024).toFixed(2);
    const isXlsx = file.name.endsWith('.xlsx') || file.name.endsWith('.xls');
    fileInfo.textContent = `上传中: ${file.name} (${fileSizeMB}MB)${isXlsx ? ' - 将自动转换为CSV' : ''}...`;
    fileInfo.style.color = '#667eea';

    try {
        const formData = new FormData();
        formData.append('file', file);
        formData.append('file_num', fileNum);

        // 使用XMLHttpRequest以支持上传进度
        const xhr = new XMLHttpRequest();

        const uploadPromise = new Promise((resolve, reject) => {
            xhr.upload.onprogress = (event) => {
                if (event.lengthComputable) {
                    const percent = Math.round((event.loaded / event.total) * 100);
                    fileInfo.textContent = `上传中: ${file.name} (${fileSizeMB}MB) - ${percent}%`;
                }
            };

            xhr.onload = () => {
                if (xhr.status === 200) {
                    try {
                        resolve(JSON.parse(xhr.responseText));
                    } catch (e) {
                        reject(new Error('解析响应失败'));
                    }
                } else {
                    reject(new Error(`上传失败: HTTP ${xhr.status}`));
                }
            };

            xhr.onerror = () => reject(new Error('网络错误'));
            xhr.ontimeout = () => reject(new Error('上传超时'));
        });

        xhr.open('POST', '/api/compare/upload');
        xhr.timeout = 300000; // 5分钟超时
        xhr.send(formData);

        const data = await uploadPromise;

        if (data.success) {
            if (fileNum === 1) {
                compareFile1 = data.filename;
                console.log('[INFO] 文件1已更新为:', compareFile1);
            } else {
                compareFile2 = data.filename;
                console.log('[INFO] 文件2已更新为:', compareFile2);
            }

            fileInfo.textContent = `✓ 已上传: ${data.filename}`;
            fileInfo.style.color = '#28a745';

            // 检查是否两个文件都已上传，启用执行按钮
            if (compareFile1 && compareFile2) {
                document.getElementById('btn-execute-compare').disabled = false;
            }

            // 同步更新配置保存时使用的文件名（确保保存配置时使用最新上传的文件）
            console.log('[INFO] 当前文件状态 - file1:', compareFile1, ', file2:', compareFile2);
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

    // 根据输入模式获取文件
    let file1, file2;
    if (fileInputMode === 'path') {
        file1 = 'PATH:' + document.getElementById('compare-path1').value.trim();
        file2 = 'PATH:' + document.getElementById('compare-path2').value.trim();
        if (!file1.substring(5) || !file2.substring(5)) {
            showAlert('请输入两个文件路径', 'error', 'compare');
            return;
        }
    } else {
        file1 = compareFile1;
        file2 = compareFile2;
        if (!file1 || !file2) {
            showAlert('请先上传两个文件或加载配置', 'error', 'compare');
            return;
        }
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

    // 显示当前使用的文件信息
    const infoLine = document.createElement('div');
    infoLine.className = 'output-line info';
    infoLine.textContent = `[INFO] 准备对比 - 模型特征表: ${file1}, 接口/灰度/从库: ${file2}`;
    outputPanel.appendChild(infoLine);

    try {
        // 使用当前变量中的文件名（可能是上传的新文件或配置加载的文件）
        console.log('[INFO] 执行对比 - 使用文件1:', file1);
        console.log('[INFO] 执行对比 - 使用文件2:', file2);

        const config = {
            file1: file1,
            file2: file2,
            key_column_1: parseKeyColumns(document.getElementById('compare-key-column-1').value),
            key_column_2: parseKeyColumns(document.getElementById('compare-key-column-2').value),
            feature_start_1: parseInt(document.getElementById('compare-feature-start-1').value) || 1,
            feature_start_2: parseInt(document.getElementById('compare-feature-start-2').value) || 1,
            output_prefix: document.getElementById('compare-output-prefix').value || 'compare',
            convert_feature_to_number: document.getElementById('compare-convert-feature').checked,
            ignore_default_fill: document.getElementById('compare-ignore-default-fill').checked,
            output_full_data: document.getElementById('compare-output-full').checked
        };

        // 获取当前用户标识
        const userId = getUserId() || 'anonymous';

        const response = await fetch('/api/compare/execute', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ config: config, user_id: userId })
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
                            showAlert('🎉 数据对比执行完成！', 'success', 'compare');
                            // 添加完成提示到输出面板
                            const completeLine = document.createElement('div');
                            completeLine.className = 'output-line success';
                            completeLine.textContent = '🎉 任务执行完成！';
                            outputPanel.appendChild(completeLine);
                            outputPanel.scrollTop = outputPanel.scrollHeight;
                            // 自动下载输出文件
                            setTimeout(() => autoDownloadOutputFiles('data_comparison', 2), 1000);
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
                sql_key_column: parseKeyColumns(document.getElementById('compare-key-column-1').value),
                api_key_column: parseKeyColumns(document.getElementById('compare-key-column-2').value),
                sql_feature_start: parseInt(document.getElementById('compare-feature-start-1').value) || 1,
                api_feature_start: parseInt(document.getElementById('compare-feature-start-2').value) || 1,
                convert_feature_to_number: document.getElementById('compare-convert-feature').checked,
                output_prefix: document.getElementById('compare-output-prefix').value || 'compare'
            }],
            global_config: {
                default_convert_feature_to_number: document.getElementById('compare-convert-feature').checked,
                default_sql_key_column: parseKeyColumns(document.getElementById('compare-key-column-1').value),
                default_api_key_column: parseKeyColumns(document.getElementById('compare-key-column-2').value),
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
// forceLoad: 是否强制从配置加载（覆盖当前上传的文件）
async function loadCompareConfig(forceLoad = false) {
    try {
        console.log('[DEBUG] 开始加载配置... forceLoad:', forceLoad);

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
                document.getElementById('compare-key-column-1').value = formatKeyColumns(gc.default_sql_key_column || 0);
                document.getElementById('compare-key-column-2').value = formatKeyColumns(gc.default_api_key_column || 0);
                document.getElementById('compare-feature-start-1').value = gc.default_sql_feature_start || 1;
                document.getElementById('compare-feature-start-2').value = gc.default_api_feature_start || 1;
                document.getElementById('compare-convert-feature').checked = gc.default_convert_feature_to_number !== false;
            }

            // 加载第一个场景的配置（如果存在）
            if (config.scenarios && config.scenarios.length > 0) {
                const scenario = config.scenarios[0];
                console.log('[DEBUG] 加载场景配置:', scenario);

                // 更新文件信息显示
                // forceLoad=true 或 变量为空时，从配置加载文件
                if (scenario.sql_file) {
                    if (forceLoad || !compareFile1) {
                        compareFile1 = scenario.sql_file;
                        document.getElementById('file-info-compare-1').textContent = `配置中的文件: ${scenario.sql_file}`;
                        document.getElementById('file-info-compare-1').style.color = '#667eea';
                        console.log('[DEBUG] 从配置加载文件1:', scenario.sql_file);
                    } else {
                        console.log('[DEBUG] 文件1已有上传文件，跳过配置加载:', compareFile1);
                    }
                }

                if (scenario.api_file) {
                    if (forceLoad || !compareFile2) {
                        compareFile2 = scenario.api_file;
                        document.getElementById('file-info-compare-2').textContent = `配置中的文件: ${scenario.api_file}`;
                        document.getElementById('file-info-compare-2').style.color = '#667eea';
                        console.log('[DEBUG] 从配置加载文件2:', scenario.api_file);
                    } else {
                        console.log('[DEBUG] 文件2已有上传文件，跳过配置加载:', compareFile2);
                    }
                }

                // 更新其他配置
                if (scenario.sql_key_column !== undefined) {
                    document.getElementById('compare-key-column-1').value = formatKeyColumns(scenario.sql_key_column);
                    console.log('[DEBUG] 设置SQL关键列:', scenario.sql_key_column);
                }
                if (scenario.api_key_column !== undefined) {
                    document.getElementById('compare-key-column-2').value = formatKeyColumns(scenario.api_key_column);
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
document.addEventListener('DOMContentLoaded', function () {
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


// ========== 小数位数处理相关函数 ==========

let decimalDiffFile = null;
let isExecutingDecimal = false;
let decimalFileInputMode = 'upload'; // 'upload' 或 'path'

// 切换小数处理文件输入模式
function toggleDecimalFileInputMode() {
    const mode = document.querySelector('input[name="decimal-file-input-mode"]:checked').value;
    decimalFileInputMode = mode;

    const uploadContainer = document.getElementById('decimal-upload-mode-container');
    const pathContainer = document.getElementById('decimal-path-mode-container');

    if (mode === 'upload') {
        uploadContainer.style.display = 'block';
        pathContainer.style.display = 'none';
    } else {
        uploadContainer.style.display = 'none';
        pathContainer.style.display = 'block';
    }

    checkDecimalReady();
}

// 处理小数处理路径输入
function handleDecimalPathInput() {
    const path = document.getElementById('decimal-file-path').value.trim();
    if (path) {
        decimalDiffFile = 'PATH:' + path;
    }
    checkDecimalReady();
}

// 检查是否可以执行小数处理
function checkDecimalReady() {
    const btn = document.getElementById('btn-execute-decimal');
    if (decimalFileInputMode === 'upload') {
        btn.disabled = !(decimalDiffFile && !decimalDiffFile.startsWith('PATH:'));
    } else {
        const path = document.getElementById('decimal-file-path').value.trim();
        btn.disabled = !path;
    }
}

// 切换容差输入框显示
function toggleToleranceInput() {
    const mode = document.querySelector('input[name="compare-mode"]:checked').value;
    const container = document.getElementById('tolerance-input-container');
    container.style.display = mode === 'tolerance' ? 'block' : 'none';
}

async function handleDecimalFileSelect(input) {
    const file = input.files[0];
    if (!file) return;

    if (!file.name.endsWith('.csv') && !file.name.endsWith('.xlsx') && !file.name.endsWith('.xls')) {
        showAlert('只支持CSV和XLSX文件', 'error', 'compare');
        input.value = '';
        return;
    }

    const fileInfo = document.getElementById('file-info-decimal');
    const fileSizeMB = (file.size / 1024 / 1024).toFixed(2);
    const isXlsx = file.name.endsWith('.xlsx') || file.name.endsWith('.xls');
    fileInfo.textContent = `上传中: ${file.name} (${fileSizeMB}MB)${isXlsx ? ' - 将自动转换为CSV' : ''}...`;
    fileInfo.style.color = '#667eea';

    try {
        const formData = new FormData();
        formData.append('file', file);

        const xhr = new XMLHttpRequest();

        const uploadPromise = new Promise((resolve, reject) => {
            xhr.upload.onprogress = (event) => {
                if (event.lengthComputable) {
                    const percent = Math.round((event.loaded / event.total) * 100);
                    fileInfo.textContent = `上传中: ${file.name} (${fileSizeMB}MB) - ${percent}%`;
                }
            };

            xhr.onload = () => {
                if (xhr.status === 200) {
                    try {
                        resolve(JSON.parse(xhr.responseText));
                    } catch (e) {
                        reject(new Error('解析响应失败'));
                    }
                } else {
                    reject(new Error(`上传失败: HTTP ${xhr.status}`));
                }
            };

            xhr.onerror = () => reject(new Error('网络错误'));
            xhr.ontimeout = () => reject(new Error('上传超时'));
        });

        xhr.open('POST', '/api/compare/decimal/upload');
        xhr.timeout = 300000;
        xhr.send(formData);

        const data = await uploadPromise;

        if (data.success) {
            decimalDiffFile = data.filename;
            fileInfo.textContent = `✓ 已上传: ${data.filename}`;
            fileInfo.style.color = '#28a745';
            document.getElementById('btn-execute-decimal').disabled = false;
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

async function executeDecimalProcess() {
    if (isExecutingDecimal) {
        showAlert('正在执行中，请稍候...', 'error', 'compare');
        return;
    }

    // 根据输入模式获取文件
    let file;
    if (decimalFileInputMode === 'path') {
        file = 'PATH:' + document.getElementById('decimal-file-path').value.trim();
        if (!file.substring(5)) {
            showAlert('请输入文件路径', 'error', 'compare');
            return;
        }
    } else {
        file = decimalDiffFile;
        if (!file) {
            showAlert('请先上传CSV文件', 'error', 'compare');
            return;
        }
    }

    // 获取列名
    const sourceColumn = document.getElementById('decimal-source-column').value.trim();
    const referenceColumn = document.getElementById('decimal-reference-column').value.trim();

    if (!sourceColumn || !referenceColumn) {
        showAlert('请指定源列和参考列', 'error', 'compare');
        return;
    }

    isExecutingDecimal = true;
    const executeBtn = document.getElementById('btn-execute-decimal');
    const statusIndicator = document.getElementById('status-indicator-decimal');
    const statusText = document.getElementById('status-text-decimal');
    const loadingSpinner = document.getElementById('loading-spinner-decimal');
    const outputPanel = document.getElementById('output-panel-decimal');

    executeBtn.disabled = true;
    statusIndicator.className = 'status-indicator running';
    statusText.textContent = '执行中...';
    loadingSpinner.style.display = 'inline-block';
    outputPanel.innerHTML = '';

    // 获取小数处理方式和对比方式
    const decimalMethod = document.querySelector('input[name="decimal-method"]:checked').value;
    const compareMode = document.querySelector('input[name="compare-mode"]:checked').value;
    const toleranceValue = parseFloat(document.getElementById('tolerance-value').value) || 0.01;
    const outputPrefix = document.getElementById('decimal-output-prefix').value || 'decimal_processed';

    const infoLine = document.createElement('div');
    infoLine.className = 'output-line info';
    const methodText = decimalMethod === 'none' ? '不处理' : decimalMethod === 'round' ? '四舍五入' : decimalMethod === 'double_round' ? '双精度四舍五入' : decimalMethod === 'truncate' ? '截取' : '向上取整';
    const compareModeText = compareMode === 'exact' ? '精确对比' : compareMode === 'tolerance' ? `容差对比(${toleranceValue})` : compareMode === 'last_digit' ? '最后一位差1不计异常' : '最后一位差2不计异常';
    infoLine.textContent = `[INFO] 开始处理 - 源列: ${sourceColumn}, 参考列: ${referenceColumn}, 处理方式: ${methodText}, 对比: ${compareModeText}`;
    outputPanel.appendChild(infoLine);

    try {
        // 获取当前用户标识
        const userId = getUserId() || 'anonymous';

        const config = {
            file: file,
            source_column: sourceColumn,
            reference_column: referenceColumn,
            method: decimalMethod,
            compare_mode: compareMode,
            tolerance: toleranceValue,
            output_prefix: outputPrefix,
            output_full_data: document.getElementById('decimal-output-full').checked,
            user_id: userId
        };

        const response = await fetch('/api/compare/decimal/execute', {
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
                            showAlert('🎉 小数位数处理完成！', 'success', 'compare');
                            const completeLine = document.createElement('div');
                            completeLine.className = 'output-line success';
                            completeLine.textContent = '🎉 处理完成！';
                            outputPanel.appendChild(completeLine);
                            outputPanel.scrollTop = outputPanel.scrollHeight;
                            // 自动下载输出文件
                            setTimeout(() => autoDownloadOutputFiles('data_comparison', 2), 1000);
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
        isExecutingDecimal = false;
        executeBtn.disabled = false;
        loadingSpinner.style.display = 'none';
    }
}

// ========== 小数处理配置保存和加载 ==========

/**
 * 保存小数处理配置
 */
async function saveDecimalConfig() {
    try {
        console.log('[DEBUG] 开始保存小数处理配置...');

        // 获取当前配置
        const config = {
            file_path: decimalDiffFile || "",
            source_column: document.getElementById('decimal-source-column').value.trim(),
            reference_column: document.getElementById('decimal-reference-column').value.trim(),
            decimal_method: document.querySelector('input[name="decimal-method"]:checked').value,
            compare_mode: document.querySelector('input[name="compare-mode"]:checked').value,
            tolerance_value: parseFloat(document.getElementById('tolerance-value').value) || 0.01,
            output_prefix: document.getElementById('decimal-output-prefix').value || 'decimal_processed',
            output_full_data: document.getElementById('decimal-output-full').checked,
            file_input_mode: decimalFileInputMode
        };

        console.log('[DEBUG] 配置数据:', config);

        const response = await fetch('/api/compare/decimal/config/save', {
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
            showAlert('✅ 配置保存成功！保存到 data_comparison/decimal_config.json', 'success', 'decimal');
            console.log('[SUCCESS] 配置保存成功');
        } else {
            showAlert('❌ 配置保存失败: ' + data.error, 'error', 'decimal');
            console.error('[ERROR] 配置保存失败:', data.error);
        }
    } catch (error) {
        showAlert('❌ 配置保存失败: ' + error.message, 'error', 'decimal');
        console.error('[ERROR] 配置保存异常:', error);
    }
}

/**
 * 加载小数处理配置
 * @param {boolean} forceLoad - 是否强制从配置加载（覆盖当前上传的文件）
 */
async function loadDecimalConfig(forceLoad = false) {
    try {
        console.log('[DEBUG] 开始加载小数处理配置... forceLoad:', forceLoad);

        const response = await fetch('/api/compare/decimal/config/load', {
            method: 'GET'
        });

        console.log('[DEBUG] 响应状态:', response.status);

        const data = await response.json();
        console.log('[DEBUG] 响应数据:', data);

        if (data.success && data.config) {
            const config = data.config;
            console.log('[DEBUG] 配置内容:', config);

            // 加载文件路径
            if (config.file_path) {
                if (forceLoad || !decimalDiffFile) {
                    decimalDiffFile = config.file_path;
                    document.getElementById('file-info-decimal').textContent = `配置中的文件: ${config.file_path}`;
                    document.getElementById('file-info-decimal').style.color = '#667eea';
                    console.log('[DEBUG] 从配置加载文件:', config.file_path);
                } else {
                    console.log('[DEBUG] 文件已有上传文件，跳过配置加载:', decimalDiffFile);
                }
            }

            // 加载列配置
            if (config.source_column) {
                document.getElementById('decimal-source-column').value = config.source_column;
            }
            if (config.reference_column) {
                document.getElementById('decimal-reference-column').value = config.reference_column;
            }

            // 加载处理方式
            if (config.decimal_method) {
                const methodRadio = document.querySelector(`input[name="decimal-method"][value="${config.decimal_method}"]`);
                if (methodRadio) {
                    methodRadio.checked = true;
                }
            }

            // 加载对比方式
            if (config.compare_mode) {
                const compareModeRadio = document.querySelector(`input[name="compare-mode"][value="${config.compare_mode}"]`);
                if (compareModeRadio) {
                    compareModeRadio.checked = true;
                }
                // 触发容差输入框显示/隐藏
                toggleToleranceInput();
            }

            // 加载容差值
            if (config.tolerance_value !== undefined) {
                document.getElementById('tolerance-value').value = config.tolerance_value;
            }

            // 加载输出配置
            if (config.output_prefix) {
                document.getElementById('decimal-output-prefix').value = config.output_prefix;
            }
            if (config.output_full_data !== undefined) {
                document.getElementById('decimal-output-full').checked = config.output_full_data;
            }

            // 加载文件输入模式
            if (config.file_input_mode) {
                decimalFileInputMode = config.file_input_mode;
                const modeRadio = document.querySelector(`input[name="decimal-file-input-mode"][value="${config.file_input_mode}"]`);
                if (modeRadio) {
                    modeRadio.checked = true;
                    toggleDecimalFileInputMode();
                }
            }

            // 检查是否可以执行
            checkDecimalReady();

            showAlert('✅ 配置加载成功！', 'success', 'decimal');
            console.log('[SUCCESS] 配置加载成功');
        } else {
            showAlert('⚠️ 未找到保存的配置', 'warning', 'decimal');
            console.log('[INFO] 未找到保存的配置');
        }
    } catch (error) {
        showAlert('❌ 配置加载失败: ' + error.message, 'error', 'decimal');
        console.error('[ERROR] 配置加载异常:', error);
    }
}

// 页面加载时自动加载配置（如果存在）
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function () {
        // 延迟500ms加载配置，确保页面元素已完全初始化
        setTimeout(() => {
            loadDecimalConfig();
        }, 500);
    });
} else {
    // DOM已经加载完成
    setTimeout(() => {
        loadDecimalConfig();
    }, 500);
}
