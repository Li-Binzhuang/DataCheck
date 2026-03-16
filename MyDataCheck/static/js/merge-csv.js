/**
 * 合并CSV文件功能模块
 * 
 * 功能：
 * - 上传多个CSV文件
 * - 纵向合并（追加行）或横向合并（追加列）
 * - 横向合并支持自动排除重复列
 * - 输出合并后的CSV文件
 */

// 存储选中的文件
let selectedMergeCsvFiles = [];

/**
 * 切换横向合并选项显示
 */
function toggleHorizontalOptions() {
    const mergeMode = document.querySelector('input[name="merge-mode"]:checked').value;
    const horizontalOptions = document.getElementById('horizontal-merge-options');

    if (mergeMode === 'horizontal') {
        horizontalOptions.style.display = 'block';
    } else {
        horizontalOptions.style.display = 'none';
    }
}

/**
 * 处理文件选择
 */
function handleMergeCsvFilesSelect(input) {
    const files = Array.from(input.files);

    if (files.length === 0) {
        document.getElementById('file-info-merge-csv').textContent = '未选择文件';
        document.getElementById('btn-execute-merge-csv').disabled = true;
        selectedMergeCsvFiles = [];
        return;
    }

    // 验证文件类型
    const invalidFiles = files.filter(f => !f.name.toLowerCase().endsWith('.csv'));
    if (invalidFiles.length > 0) {
        showAlert('merge-csv', `以下文件不是CSV格式：${invalidFiles.map(f => f.name).join(', ')}`, 'error');
        return;
    }

    selectedMergeCsvFiles = files;

    // 显示文件信息
    const fileInfo = document.getElementById('file-info-merge-csv');
    if (files.length === 1) {
        fileInfo.textContent = `已选择: ${files[0].name}`;
    } else {
        fileInfo.innerHTML = `已选择 ${files.length} 个文件：<br>${files.map(f => f.name).join('<br>')}`;
    }

    // 启用执行按钮
    document.getElementById('btn-execute-merge-csv').disabled = false;
}

/**
 * 清空选中的文件
 */
function clearMergeCsvFiles() {
    document.getElementById('merge-csv-files').value = '';
    document.getElementById('file-info-merge-csv').textContent = '未选择文件';
    document.getElementById('btn-execute-merge-csv').disabled = true;
    selectedMergeCsvFiles = [];
    clearOutput('merge-csv');
}

/**
 * 执行CSV合并（支持进度展示）
 */
async function executeMergeCsv() {
    if (selectedMergeCsvFiles.length < 2) {
        showAlert('merge-csv', '请至少选择2个CSV文件进行合并', 'error');
        return;
    }

    // 获取配置
    const mergeMode = document.querySelector('input[name="merge-mode"]:checked').value;
    const outputFilename = document.getElementById('merge-output-filename').value.trim() || 'merged';

    // 横向合并的额外配置
    let keyColumns = '';
    if (mergeMode === 'horizontal') {
        keyColumns = document.getElementById('key-column-names').value.trim();
    }

    // 更新UI状态
    updateMergeStatus('running', '正在合并文件...');
    document.getElementById('btn-execute-merge-csv').disabled = true;
    clearOutput('merge-csv');

    try {
        // 构建FormData
        const formData = new FormData();
        selectedMergeCsvFiles.forEach(file => {
            formData.append('files', file);
        });
        formData.append('merge_mode', mergeMode);
        formData.append('output_filename', outputFilename);
        formData.append('key_columns', keyColumns);

        appendOutput('merge-csv', `开始合并 ${selectedMergeCsvFiles.length} 个文件...`, 'info');
        appendOutput('merge-csv', `合并方式: ${mergeMode === 'vertical' ? '纵向合并（追加行）' : '横向合并（追加列）'}`, 'info');

        if (mergeMode === 'horizontal') {
            if (keyColumns) {
                appendOutput('merge-csv', `主键列: ${keyColumns}`, 'info');
            } else {
                appendOutput('merge-csv', '未指定主键，将按列直接拼接', 'info');
            }
        }

        appendOutput('merge-csv', '正在上传文件到服务器...', 'info');

        // 使用 fetch 发送请求并处理 SSE 流
        const response = await fetch('/merge-csv/execute', {
            method: 'POST',
            body: formData
        });

        if (!response.ok) {
            throw new Error(`HTTP错误! 状态码: ${response.status}`);
        }

        appendOutput('merge-csv', '文件上传成功，开始处理...', 'info');

        // 检查响应类型
        const contentType = response.headers.get('content-type');
        console.log('响应类型:', contentType);

        if (contentType && contentType.includes('text/event-stream')) {
            // SSE 流式响应
            appendOutput('merge-csv', '使用流式处理模式...', 'info');
            await handleSSEResponse(response);
        } else {
            // 降级到传统 JSON 响应
            appendOutput('merge-csv', '使用标准处理模式...', 'info');
            const result = await response.json();
            handleJSONResponse(result);
        }

    } catch (error) {
        console.error('合并CSV文件失败:', error);
        appendOutput('merge-csv', `❌ 合并失败: ${error.message}`, 'error');
        updateMergeStatus('error', '合并失败');
    } finally {
        document.getElementById('btn-execute-merge-csv').disabled = false;
    }
}

/**
 * 处理 SSE 流式响应
 */
async function handleSSEResponse(response) {
    const reader = response.body.getReader();
    const decoder = new TextDecoder();
    let buffer = '';

    while (true) {
        const { done, value } = await reader.read();

        if (done) break;

        buffer += decoder.decode(value, { stream: true });

        // 处理完整的 SSE 消息
        const lines = buffer.split('\n\n');
        buffer = lines.pop(); // 保留不完整的消息

        for (const line of lines) {
            if (line.startsWith('data: ')) {
                try {
                    const data = JSON.parse(line.substring(6));

                    if (data.type === 'progress') {
                        appendOutput('merge-csv', `[${data.percent}%] ${data.message}`, 'info');
                        updateMergeStatus('running', `${data.message} (${data.percent}%)`);
                    } else if (data.type === 'success') {
                        handleSuccessResponse(data);
                    } else if (data.type === 'error') {
                        appendOutput('merge-csv', `❌ 合并失败: ${data.message}`, 'error');
                        updateMergeStatus('error', '合并失败');
                    }
                } catch (e) {
                    console.error('解析SSE消息失败:', e, line);
                }
            }
        }
    }
}

/**
 * 处理 JSON 响应
 */
function handleJSONResponse(result) {
    if (result.success) {
        handleSuccessResponse(result);
    } else {
        appendOutput('merge-csv', `❌ 合并失败: ${result.error}`, 'error');
        updateMergeStatus('error', '合并失败');
    }
}

/**
 * 处理成功响应
 */
function handleSuccessResponse(data) {
    appendOutput('merge-csv', '✅ 合并成功！', 'success');
    appendOutput('merge-csv', `输出文件: ${data.output_file}`, 'info');
    appendOutput('merge-csv', `总行数: ${data.total_rows.toLocaleString()}`, 'info');
    appendOutput('merge-csv', `总列数: ${data.total_columns}`, 'info');

    if (data.removed_columns && data.removed_columns.length > 0) {
        appendOutput('merge-csv', `已移除重复列 (${data.removed_count || data.removed_columns.length}个): ${data.removed_columns.join(', ')}`, 'info');
    }

    // 自动下载
    if (data.download_url) {
        appendOutput('merge-csv', '正在下载文件...', 'info');
        window.location.href = data.download_url;
    }

    updateMergeStatus('success', '合并完成');
}

/**
 * 更新状态指示器
 */
function updateMergeStatus(status, text) {
    const indicator = document.getElementById('status-indicator-merge-csv');
    const statusText = document.getElementById('status-text-merge-csv');
    const spinner = document.getElementById('loading-spinner-merge-csv');

    if (indicator) {
        indicator.className = 'status-indicator ' + status;
    }
    if (statusText) {
        statusText.textContent = text;
    }
    if (spinner) {
        spinner.style.display = status === 'running' ? 'inline-block' : 'none';
    }
}

/**
 * 显示提示信息
 */
function showAlert(pageId, message, type = 'info') {
    const container = document.getElementById(`alert-container-${pageId}`);
    if (!container) return;

    const alertClass = type === 'error' ? 'alert-error' : type === 'success' ? 'alert-success' : 'alert-info';
    container.innerHTML = `<div class="alert ${alertClass}">${message}</div>`;

    // 3秒后自动消失
    setTimeout(() => {
        container.innerHTML = '';
    }, 3000);
}

/**
 * 收集当前合并配置（按合并方式分开存储）
 */
function collectMergeCsvConfig() {
    const mergeMode = document.querySelector('input[name="merge-mode"]:checked').value;
    const outputFilename = document.getElementById('merge-output-filename').value.trim() || 'merged';
    const keyColumns = document.getElementById('key-column-names').value.trim();

    return {
        merge_mode: mergeMode,
        output_filename: outputFilename,
        key_columns: keyColumns
    };
}

/**
 * 保存合并配置到服务器（仅保存当前合并方式的配置，不覆盖另一种）
 */
async function saveMergeCsvConfig() {
    try {
        const config = collectMergeCsvConfig();

        const response = await fetch('/merge-csv/config/save', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ config: config })
        });

        const data = await response.json();
        if (data.success) {
            const modeLabel = config.merge_mode === 'vertical' ? '纵向合并' : '横向合并';
            showAlert('merge-csv', `${modeLabel}配置已保存`, 'success');
        } else {
            showAlert('merge-csv', '保存配置失败: ' + data.error, 'error');
        }
    } catch (error) {
        showAlert('merge-csv', '保存配置失败: ' + error.message, 'error');
    }
}

/**
 * 从服务器加载合并配置并应用到表单
 */
async function loadMergeCsvConfig(silent) {
    try {
        const response = await fetch('/merge-csv/config/load');
        const data = await response.json();

        if (data.success) {
            const config = data.config;
            applyMergeCsvConfig(config);
            if (!silent) {
                showAlert('merge-csv', '配置已加载', 'success');
            }
        } else {
            if (!silent) {
                showAlert('merge-csv', '加载配置失败: ' + data.error, 'error');
            }
        }
    } catch (error) {
        if (!silent) {
            showAlert('merge-csv', '加载配置失败: ' + error.message, 'error');
        }
    }
}

/**
 * 将配置应用到表单
 */
function applyMergeCsvConfig(config) {
    // 恢复当前选中的合并方式（默认纵向）
    const lastMode = config.last_mode || 'vertical';
    const radio = document.querySelector(`input[name="merge-mode"][value="${lastMode}"]`);
    if (radio) {
        radio.checked = true;
        toggleHorizontalOptions();
    }

    // 根据当前合并方式恢复对应配置
    const modeConfig = config[lastMode] || {};

    if (modeConfig.output_filename) {
        document.getElementById('merge-output-filename').value = modeConfig.output_filename;
    }

    if (lastMode === 'horizontal' && modeConfig.key_columns !== undefined) {
        document.getElementById('key-column-names').value = modeConfig.key_columns;
    }
}

/**
 * 切换合并方式时，从配置中恢复对应方式的参数
 */
async function onMergeModeChange() {
    toggleHorizontalOptions();

    // 尝试从已保存的配置中恢复当前方式的参数
    try {
        const response = await fetch('/merge-csv/config/load');
        const data = await response.json();
        if (data.success) {
            const config = data.config;
            const currentMode = document.querySelector('input[name="merge-mode"]:checked').value;
            const modeConfig = config[currentMode] || {};

            if (modeConfig.output_filename) {
                document.getElementById('merge-output-filename').value = modeConfig.output_filename;
            }
            if (currentMode === 'horizontal' && modeConfig.key_columns !== undefined) {
                document.getElementById('key-column-names').value = modeConfig.key_columns;
            }
        }
    } catch (e) {
        // 静默失败
    }
}

// ========== 页面加载时自动加载配置 ==========
document.addEventListener('DOMContentLoaded', function () {
    const mergePage = document.getElementById('page-merge-csv');
    if (mergePage) {
        setTimeout(() => loadMergeCsvConfig(true), 300);
    }
});
