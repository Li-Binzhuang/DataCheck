/**
 * 跑数模块 JavaScript
 */

// 入参配置列表
let batchRunParams = [];

// 初始化跑数页面
function initBatchRunPage() {
    loadBatchRunConfig();
    loadBatchRunFiles();
}

// 添加入参配置
function addBatchRunParam() {
    const container = document.getElementById('batch-run-params-container');
    const index = batchRunParams.length;

    const paramHtml = `
        <div class="param-item" id="batch-run-param-${index}" style="display: flex; gap: 8px; align-items: center; margin-bottom: 8px; padding: 8px; background: #f8f9fa; border-radius: 4px; flex-wrap: wrap;">
            <input type="text" placeholder="参数名(如custNo)" id="param-name-${index}" style="flex: 1; min-width: 120px; padding: 6px;">
            <input type="number" placeholder="列索引(A=0)" id="param-col-${index}" min="0" style="width: 90px; padding: 6px;">
            <label style="display: flex; align-items: center; gap: 4px; font-size: 12px; white-space: nowrap;">
                <input type="checkbox" id="param-time-${index}" onchange="toggleTSeparator(${index})"> 时间字段
            </label>
            <label id="param-t-label-${index}" style="display: none; align-items: center; gap: 4px; font-size: 12px; white-space: nowrap;">
                <input type="checkbox" id="param-t-${index}"> 用T分隔
            </label>
            <button onclick="removeBatchRunParam(${index})" style="padding: 4px 8px; background: #dc3545; color: white; border: none; border-radius: 4px; cursor: pointer;">删除</button>
        </div>
    `;

    container.insertAdjacentHTML('beforeend', paramHtml);
    batchRunParams.push(index);
}

// 切换T分隔符选项显示
function toggleTSeparator(index) {
    const isTime = document.getElementById(`param-time-${index}`)?.checked;
    const tLabel = document.getElementById(`param-t-label-${index}`);
    if (tLabel) {
        tLabel.style.display = isTime ? 'flex' : 'none';
    }
}

// 删除入参配置
function removeBatchRunParam(index) {
    const elem = document.getElementById(`batch-run-param-${index}`);
    if (elem) {
        elem.remove();
        batchRunParams = batchRunParams.filter(i => i !== index);
    }
}

// 收集入参配置
function collectBatchRunParams() {
    const params = [];
    batchRunParams.forEach(index => {
        const name = document.getElementById(`param-name-${index}`)?.value?.trim();
        const col = document.getElementById(`param-col-${index}`)?.value;
        const isTime = document.getElementById(`param-time-${index}`)?.checked || false;
        const useT = document.getElementById(`param-t-${index}`)?.checked || false;

        if (name && col !== '') {
            params.push({
                param_name: name,
                column_index: parseInt(col),
                is_time_field: isTime,
                use_t_separator: useT
            });
        }
    });
    return params;
}

// 加载配置
async function loadBatchRunConfig() {
    try {
        const response = await fetch('/api/batch-run/config/load');
        const data = await response.json();

        if (data.success && data.config) {
            const config = data.config;

            document.getElementById('batch-run-api-url').value = config.api_url || '';
            document.getElementById('batch-run-input-file').value = config.input_csv_file || '';
            document.getElementById('batch-run-output-prefix').value = config.output_file_prefix || 'batch_run';
            document.getElementById('batch-run-thread-count').value = config.thread_count || 50;
            document.getElementById('batch-run-timeout').value = config.timeout || 30;

            // 加载入参配置
            const container = document.getElementById('batch-run-params-container');
            container.innerHTML = '';
            batchRunParams = [];

            if (config.api_params && config.api_params.length > 0) {
                config.api_params.forEach((param, i) => {
                    addBatchRunParam();
                    document.getElementById(`param-name-${i}`).value = param.param_name || '';
                    document.getElementById(`param-col-${i}`).value = param.column_index ?? '';
                    document.getElementById(`param-time-${i}`).checked = param.is_time_field || false;
                    // 恢复T分隔符选项
                    if (param.is_time_field) {
                        toggleTSeparator(i);
                        document.getElementById(`param-t-${i}`).checked = param.use_t_separator || false;
                    }
                });
            }
        }
    } catch (e) {
        console.error('加载配置失败:', e);
    }
}

// 保存配置
async function saveBatchRunConfig() {
    const config = {
        api_url: document.getElementById('batch-run-api-url').value.trim(),
        input_csv_file: document.getElementById('batch-run-input-file').value.trim(),
        output_file_prefix: document.getElementById('batch-run-output-prefix').value.trim() || 'batch_run',
        thread_count: parseInt(document.getElementById('batch-run-thread-count').value) || 50,
        timeout: parseInt(document.getElementById('batch-run-timeout').value) || 30,
        api_params: collectBatchRunParams()
    };

    try {
        const response = await fetch('/api/batch-run/config/save', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ config })
        });
        const data = await response.json();

        if (data.success) {
            alert('配置保存成功');
        } else {
            alert('保存失败: ' + data.error);
        }
    } catch (e) {
        alert('保存失败: ' + e.message);
    }
}

// 加载文件列表
async function loadBatchRunFiles() {
    try {
        const response = await fetch('/api/batch-run/files');
        const data = await response.json();

        if (data.success) {
            const select = document.getElementById('batch-run-input-file');
            const currentValue = select.value;

            // 保留第一个空选项
            select.innerHTML = '<option value="">-- 选择文件 --</option>';

            data.files.forEach(file => {
                const option = document.createElement('option');
                option.value = file.name;
                option.textContent = `${file.name} (${(file.size / 1024).toFixed(1)} KB)`;
                select.appendChild(option);
            });

            // 恢复之前的选择
            if (currentValue) {
                select.value = currentValue;
            }
        }
    } catch (e) {
        console.error('加载文件列表失败:', e);
    }
}

// 上传文件
async function uploadBatchRunFile() {
    const input = document.getElementById('batch-run-file-upload');
    if (!input.files || !input.files[0]) {
        alert('请选择文件');
        return;
    }

    const file = input.files[0];
    const formData = new FormData();
    formData.append('file', file);

    try {
        const response = await fetch('/api/batch-run/upload', {
            method: 'POST',
            body: formData
        });
        const data = await response.json();

        if (data.success) {
            alert('上传成功: ' + data.filename);
            loadBatchRunFiles();
            document.getElementById('batch-run-input-file').value = data.filename;
        } else {
            alert('上传失败: ' + data.error);
        }
    } catch (e) {
        alert('上传失败: ' + e.message);
    }

    input.value = '';
}

// 执行跑数
async function executeBatchRun() {
    const config = {
        api_url: document.getElementById('batch-run-api-url').value.trim(),
        input_csv_file: document.getElementById('batch-run-input-file').value.trim(),
        output_file_prefix: document.getElementById('batch-run-output-prefix').value.trim() || 'batch_run',
        thread_count: parseInt(document.getElementById('batch-run-thread-count').value) || 50,
        timeout: parseInt(document.getElementById('batch-run-timeout').value) || 30,
        api_params: collectBatchRunParams()
    };

    if (!config.api_url) {
        alert('请输入接口URL');
        return;
    }
    if (!config.input_csv_file) {
        alert('请选择输入文件');
        return;
    }
    if (config.api_params.length === 0) {
        alert('请至少添加一个入参配置');
        return;
    }

    // 更新UI状态
    const btn = document.getElementById('btn-execute-batch-run');
    const spinner = document.getElementById('loading-spinner-batch-run');
    const statusText = document.getElementById('status-text-batch-run');
    const outputPanel = document.getElementById('output-panel-batch-run');

    // 重置状态
    btn.disabled = true;
    spinner.style.display = 'inline-block';
    statusText.textContent = '执行中...';
    outputPanel.innerHTML = '';

    const resetUI = () => {
        btn.disabled = false;
        spinner.style.display = 'none';
    };

    // 获取当前用户标识
    const userId = getUserId() || 'anonymous';

    try {
        const response = await fetch('/api/batch-run/execute', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ config, user_id: userId })
        });

        if (!response.ok) {
            throw new Error(`HTTP错误: ${response.status}`);
        }

        const reader = response.body.getReader();
        const decoder = new TextDecoder();
        let savedTaskId = null; // 保存taskId

        while (true) {
            const { done, value } = await reader.read();
            if (done) break;

            const text = decoder.decode(value, { stream: true });
            const lines = text.split('\n');

            for (const line of lines) {
                if (line.startsWith('data: ')) {
                    try {
                        const data = JSON.parse(line.slice(6));

                        // 保存task_id
                        if (data.type === 'start' && data.task_id) {
                            savedTaskId = data.task_id;
                        }

                        if (data.message) {
                            appendBatchRunOutput(data.message, data.type);
                        }
                        if (data.type === 'end') {
                            statusText.textContent = '完成';
                            // 自动下载输出文件，使用保存的taskId
                            setTimeout(() => autoDownloadOutputFiles('batch_run', 2, savedTaskId), 1000);
                        }
                    } catch (e) { }
                }
            }
        }

        if (statusText.textContent === '执行中...') {
            statusText.textContent = '完成';
        }
    } catch (e) {
        appendBatchRunOutput('执行错误: ' + e.message, 'error');
        statusText.textContent = '错误';
    } finally {
        resetUI();
    }
}

// 添加输出
function appendBatchRunOutput(message, type = 'info') {
    const panel = document.getElementById('output-panel-batch-run');
    const div = document.createElement('div');
    div.className = `output-line ${type}`;
    div.textContent = message;
    panel.appendChild(div);
    panel.scrollTop = panel.scrollHeight;
}

// 清空输出
function clearBatchRunOutput() {
    document.getElementById('output-panel-batch-run').innerHTML = '<div class="output-line info">等待执行...</div>';
    document.getElementById('status-text-batch-run').textContent = '就绪';
}

// 页面切换时初始化
document.addEventListener('DOMContentLoaded', function () {
    // 如果当前页面是跑数页面，初始化
    if (document.getElementById('page-batch-run')) {
        initBatchRunPage();
    }
});

// 监听页面切换，当切换到跑数页面时初始化
const originalSwitchPage = window.switchPage;
window.switchPage = function (pageName) {
    if (originalSwitchPage) {
        originalSwitchPage(pageName);
    }
    if (pageName === 'batch-run') {
        initBatchRunPage();
    }
};
