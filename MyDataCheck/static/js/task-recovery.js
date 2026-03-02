// ========== 任务恢复功能 ==========

// 全局变量
let currentRecoveredTaskId = null;
let currentRecoveredTab = null;  // 当前恢复任务对应的tab
let logPollingInterval = null;

/**
 * 根据任务类型获取对应的tab/页面
 */
function getTabForTaskType(taskType) {
    const mapping = {
        'api_comparison': 'api',
        'data_comparison': 'compare',
        'batch_run': 'batch-run',
        'online_comparison': 'online',
        'decimal_process': 'decimal'
    };
    return mapping[taskType] || 'api';
}

/**
 * 页面加载时检查是否有正在执行的任务
 */
function checkRunningTasks() {
    fetch('/api/tasks?status=running')
        .then(response => response.json())
        .then(data => {
            if (data.success && data.tasks && data.tasks.length > 0) {
                // 有正在执行的任务
                const task = data.tasks[0];  // 取最新的一个
                showTaskRecoveryPrompt(task);
            }
        })
        .catch(error => {
            console.error('检查运行中任务失败:', error);
        });
}

/**
 * 显示任务恢复提示
 */
function showTaskRecoveryPrompt(task) {
    const message = `检测到有正在执行的任务:\n\n` +
                   `任务名称: ${task.task_name}\n` +
                   `任务状态: ${getStatusText(task.status)}\n` +
                   `当前进度: ${task.progress}/${task.total}\n` +
                   `当前步骤: ${task.current_step || '无'}\n\n` +
                   `是否恢复查看该任务的执行进度？`;
    
    if (confirm(message)) {
        recoverTask(task);
    }
}

/**
 * 根据任务ID恢复任务（先获取任务信息）
 * @param {string} taskId - 任务ID
 */
function recoverTaskById(taskId) {
    fetch(`/api/tasks/${taskId}`)
        .then(response => response.json())
        .then(data => {
            if (data.success && data.task) {
                recoverTask(data.task);
            } else {
                alert('获取任务信息失败');
            }
        })
        .catch(error => {
            alert('恢复任务失败: ' + error.message);
        });
}

/**
 * 恢复任务（显示历史日志并开始轮询）
 * @param {Object} task - 任务对象，包含 task_id, task_type 等
 */
function recoverTask(task) {
    const taskId = task.task_id;
    const tab = getTabForTaskType(task.task_type || 'api_comparison');
    
    currentRecoveredTaskId = taskId;
    currentRecoveredTab = tab;
    
    // 切换到对应页面
    if (typeof switchPage === 'function') {
        switchPage(tab);
    }
    
    // 清空输出面板
    clearOutput(tab);
    
    // 显示恢复提示
    appendOutput('正在恢复任务...', 'info', tab);
    
    // 获取任务信息
    fetch(`/api/tasks/${taskId}`)
        .then(response => response.json())
        .then(data => {
            if (data.success && data.task) {
                const taskData = data.task;
                const taskTab = getTabForTaskType(taskData.task_type || 'api_comparison');
                currentRecoveredTab = taskTab;
                
                // 显示任务信息
                appendOutput(`任务名称: ${taskData.task_name}`, 'info', taskTab);
                appendOutput(`任务状态: ${getStatusText(taskData.status)}`, 'info', taskTab);
                appendOutput(`当前进度: ${taskData.progress}/${taskData.total}`, 'info', taskTab);
                if (taskData.current_step) {
                    appendOutput(`当前步骤: ${taskData.current_step}`, 'info', taskTab);
                }
                appendOutput('', 'info', taskTab);
                appendOutput('='.repeat(60), 'info', taskTab);
                appendOutput('历史日志:', 'info', taskTab);
                appendOutput('='.repeat(60), 'info', taskTab);
                
                // 加载历史日志
                loadTaskLogs(taskId, null, taskTab);
                
                // 如果任务还在运行，开始轮询新日志
                if (taskData.status === 'running') {
                    startLogPolling(taskId, taskTab);
                    updateStatus('running', '执行中（已恢复）', taskTab);
                    
                    // 显示停止按钮（仅接口对比支持）
                    if (typeof setCurrentTaskId === 'function' && taskTab === 'api') {
                        setCurrentTaskId(taskId);
                    }
                } else {
                    updateStatus(taskData.status, getStatusText(taskData.status), taskTab);
                }
            } else {
                appendOutput('恢复任务失败: ' + (data.error || '未知错误'), 'error', tab);
            }
        })
        .catch(error => {
            appendOutput('恢复任务失败: ' + error.message, 'error', tab);
        });
}

/**
 * 加载任务历史日志
 * @param {string} taskId - 任务ID
 * @param {number|null} lastN - 获取最后N条（null表示全部）
 * @param {string} tab - 输出面板tab（api/compare/batch-run/online/decimal）
 */
function loadTaskLogs(taskId, lastN = null, tab = null) {
    const outputTab = tab || currentRecoveredTab || 'api';
    let url = `/api/tasks/${taskId}/logs?from_file=true`;
    if (lastN) {
        url += `&last_n=${lastN}`;
    }
    
    fetch(url)
        .then(response => response.json())
        .then(data => {
            if (data.success && data.logs) {
                data.logs.forEach(log => {
                    appendOutput(log.message, log.level, outputTab);
                });
                
                if (data.logs.length > 0) {
                    appendOutput('', 'info', outputTab);
                    appendOutput('='.repeat(60), 'info', outputTab);
                    appendOutput('实时日志:', 'info', outputTab);
                    appendOutput('='.repeat(60), 'info', outputTab);
                }
            }
        })
        .catch(error => {
            console.error('加载历史日志失败:', error);
        });
}

/**
 * 开始轮询新日志
 * @param {string} taskId - 任务ID
 * @param {string} tab - 输出面板tab
 */
function startLogPolling(taskId, tab = null) {
    const outputTab = tab || currentRecoveredTab || 'api';
    let lastLogCount = 0;
    
    if (logPollingInterval) {
        clearInterval(logPollingInterval);
    }
    
    logPollingInterval = setInterval(() => {
        fetch(`/api/tasks/${taskId}`)
            .then(response => response.json())
            .then(data => {
                if (data.success && data.task) {
                    const task = data.task;
                    
                    if (task.progress !== undefined && task.total !== undefined) {
                        const progressText = `进度: ${task.progress}/${task.total}`;
                        updateStatus('running', progressText, outputTab);
                    }
                    
                    if (task.status !== 'running') {
                        stopLogPolling();
                        updateStatus(task.status, getStatusText(task.status), outputTab);
                        
                        if (typeof clearCurrentTaskId === 'function' && outputTab === 'api') {
                            clearCurrentTaskId();
                        }
                        
                        loadNewLogs(taskId, lastLogCount, outputTab);
                        return;
                    }
                    
                    loadNewLogs(taskId, lastLogCount, outputTab, (newCount) => {
                        lastLogCount = newCount;
                    });
                }
            })
            .catch(error => {
                console.error('轮询任务状态失败:', error);
            });
    }, 2000);
}

/**
 * 加载新日志（增量）
 * @param {string} taskId - 任务ID
 * @param {number} skipCount - 跳过的日志条数
 * @param {string} tab - 输出面板tab
 * @param {function} callback - 回调，参数为新日志总数
 */
function loadNewLogs(taskId, skipCount, tab, callback) {
    const outputTab = (typeof tab === 'function') ? (currentRecoveredTab || 'api') : (tab || currentRecoveredTab || 'api');
    const cb = (typeof tab === 'function') ? tab : callback;
    
    fetch(`/api/tasks/${taskId}/logs?from_file=true`)
        .then(response => response.json())
        .then(data => {
            if (data.success && data.logs) {
                const newLogs = data.logs.slice(skipCount);
                newLogs.forEach(log => {
                    appendOutput(log.message, log.level, outputTab);
                });
                if (cb) {
                    cb(data.logs.length);
                }
            }
        })
        .catch(error => {
            console.error('加载新日志失败:', error);
        });
}

/**
 * 停止日志轮询
 */
function stopLogPolling() {
    if (logPollingInterval) {
        clearInterval(logPollingInterval);
        logPollingInterval = null;
    }
}

/**
 * 获取状态文本
 */
function getStatusText(status) {
    const statusMap = {
        'pending': '等待执行',
        'running': '执行中',
        'completed': '已完成',
        'failed': '失败',
        'stopped': '已停止'
    };
    return statusMap[status] || status;
}

/**
 * 显示任务历史（可选功能）
 */
function showTaskHistory() {
    fetch('/api/tasks')
        .then(response => response.json())
        .then(data => {
            if (data.success && data.tasks) {
                displayTaskHistoryModal(data.tasks);
            }
        })
        .catch(error => {
            console.error('获取任务历史失败:', error);
            alert('获取任务历史失败: ' + error.message);
        });
}

/**
 * 显示任务历史模态框
 */
function displayTaskHistoryModal(tasks) {
    // 创建模态框HTML
    let html = `
        <div class="modal-overlay" id="task-history-modal" onclick="closeTaskHistoryModal()">
            <div class="modal-content" onclick="event.stopPropagation()">
                <div class="modal-header">
                    <h3>任务历史</h3>
                    <button class="btn-close" onclick="closeTaskHistoryModal()">×</button>
                </div>
                <div class="modal-body">
                    <table class="task-history-table">
                        <thead>
                            <tr>
                                <th>任务名称</th>
                                <th>状态</th>
                                <th>进度</th>
                                <th>创建时间</th>
                                <th>操作</th>
                            </tr>
                        </thead>
                        <tbody>
    `;
    
    tasks.forEach(task => {
        const statusClass = task.status === 'completed' ? 'success' : 
                           task.status === 'failed' ? 'error' : 
                           task.status === 'running' ? 'running' : 'info';
        
        html += `
            <tr>
                <td>${task.task_name}</td>
                <td><span class="status-badge ${statusClass}">${getStatusText(task.status)}</span></td>
                <td>${task.progress}/${task.total}</td>
                <td>${formatDateTime(task.created_at)}</td>
                <td>
                    <button class="btn-small btn-primary" onclick="recoverTaskById('${task.task_id}'); closeTaskHistoryModal();">查看</button>
                </td>
            </tr>
        `;
    });
    
    html += `
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    `;
    
    // 添加到页面
    document.body.insertAdjacentHTML('beforeend', html);
}

/**
 * 关闭任务历史模态框
 */
function closeTaskHistoryModal() {
    const modal = document.getElementById('task-history-modal');
    if (modal) {
        modal.remove();
    }
}

/**
 * 格式化日期时间
 */
function formatDateTime(isoString) {
    if (!isoString) return '-';
    const date = new Date(isoString);
    return date.toLocaleString('zh-CN', {
        year: 'numeric',
        month: '2-digit',
        day: '2-digit',
        hour: '2-digit',
        minute: '2-digit',
        second: '2-digit'
    });
}

// 页面加载时自动检查
document.addEventListener('DOMContentLoaded', function() {
    // 延迟1秒检查，确保页面完全加载
    setTimeout(checkRunningTasks, 1000);
});

// 页面卸载时停止轮询
window.addEventListener('beforeunload', function() {
    stopLogPolling();
});
