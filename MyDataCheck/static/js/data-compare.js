// ========== 数据对比相关函数 ==========

let compareFile1 = null;
let compareFile2 = null;
let isExecutingCompare = false;
let fileInputMode = 'upload'; // 'upload' 或 'path'

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

    if (!file.name.endsWith('.csv') && !file.name.endsWith('.xlsx')) {
        showAlert('只支持CSV和XLSX文件', 'error', 'compare');
        input.value = '';
        return;
    }

    const fileInfo = document.getElementById(`file-info-compare-${fileNum}`);

    // 显示文件大小
    const fileSizeMB = (file.size / 1024 / 1024).toFixed(2);
    fileInfo.textContent = `上传中: ${file.name} (${fileSizeMB}MB)...`;
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
            key_column_1: parseInt(document.getElementById('compare-key-column-1').value) || 0,
            key_column_2: parseInt(document.getElementById('compare-key-column-2').value) || 0,
            feature_start_1: parseInt(document.getElementById('compare-feature-start-1').value) || 1,
            feature_start_2: parseInt(document.getElementById('compare-feature-start-2').value) || 1,
            output_prefix: document.getElementById('compare-output-prefix').value || 'compare',
            convert_feature_to_number: document.getElementById('compare-convert-feature').checked,
            output_full_data: document.getElementById('compare-output-full').checked
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

    if (!file.name.endsWith('.csv')) {
        showAlert('只支持CSV文件', 'error', 'compare');
        input.value = '';
        return;
    }

    const fileInfo = document.getElementById('file-info-decimal');
    const fileSizeMB = (file.size / 1024 / 1024).toFixed(2);
    fileInfo.textContent = `上传中: ${file.name} (${fileSizeMB}MB)...`;
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
            showAlert('请先上传差异明细文件', 'error', 'compare');
            return;
        }
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
    infoLine.textContent = `[INFO] 开始处理 - 接口小数: ${methodText}, 对比: ${compareModeText}`;
    outputPanel.appendChild(infoLine);

    try {
        const config = {
            file: file,
            method: decimalMethod,
            compare_mode: compareMode,
            tolerance: toleranceValue,
            output_prefix: outputPrefix,
            output_full_data: document.getElementById('decimal-output-full').checked
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
