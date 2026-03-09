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
 * 执行CSV合并
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
    let removeDuplicates = false;
    let duplicateColumns = '';
    if (mergeMode === 'horizontal') {
        removeDuplicates = document.getElementById('remove-duplicate-columns').checked;
        duplicateColumns = document.getElementById('duplicate-column-names').value.trim();
    }

    // 更新UI状态
    updateStatus('merge-csv', 'running', '正在合并文件...');
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
        formData.append('remove_duplicates', removeDuplicates);
        formData.append('duplicate_columns', duplicateColumns);

        addOutputLine('merge-csv', `开始合并 ${selectedMergeCsvFiles.length} 个文件...`, 'info');
        addOutputLine('merge-csv', `合并方式: ${mergeMode === 'vertical' ? '纵向合并（追加行）' : '横向合并（追加列）'}`, 'info');

        if (mergeMode === 'horizontal' && removeDuplicates) {
            if (duplicateColumns) {
                addOutputLine('merge-csv', `将移除指定的重复列: ${duplicateColumns}`, 'info');
            } else {
                addOutputLine('merge-csv', '将自动检测并移除所有重复列', 'info');
            }
        }

        // 发送请求
        const response = await fetch('/merge-csv/execute', {
            method: 'POST',
            body: formData
        });

        const result = await response.json();

        if (result.success) {
            addOutputLine('merge-csv', '✅ 合并成功！', 'success');
            addOutputLine('merge-csv', `输出文件: ${result.output_file}`, 'info');
            addOutputLine('merge-csv', `总行数: ${result.total_rows}`, 'info');
            addOutputLine('merge-csv', `总列数: ${result.total_columns}`, 'info');

            if (result.removed_columns && result.removed_columns.length > 0) {
                addOutputLine('merge-csv', `已移除重复列 (${result.removed_columns.length}个): ${result.removed_columns.join(', ')}`, 'info');
            }

            // 自动下载
            if (result.download_url) {
                addOutputLine('merge-csv', '正在下载文件...', 'info');
                window.location.href = result.download_url;
            }

            updateStatus('merge-csv', 'success', '合并完成');
        } else {
            addOutputLine('merge-csv', `❌ 合并失败: ${result.error}`, 'error');
            updateStatus('merge-csv', 'error', '合并失败');
        }
    } catch (error) {
        console.error('合并CSV文件失败:', error);
        addOutputLine('merge-csv', `❌ 合并失败: ${error.message}`, 'error');
        updateStatus('merge-csv', 'error', '合并失败');
    } finally {
        document.getElementById('btn-execute-merge-csv').disabled = false;
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
