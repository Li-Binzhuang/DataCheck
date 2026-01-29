// ========== 任务恢复功能 ==========

// 全局变量
let currentRecoveredTaskId = null;
let logPollingInterval = null;

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
        recoverTask(task.task_id);
    }
}

/**
 * 恢复任务（显示历史日志并开始轮询）
 */
function recoverTask(taskId) {
    currentRecoveredTaskId = taskId;
    
    // 清空输出面板
    clearOutput('api');
    
    // 显示恢复提示
    appendOutput('正在恢复任务...', 'info', 'api');
    
    // 获取任务信息
    fetch(`/api/tasks/${taskId}`)
        .then(response => response.json())
        .then(data => {
            if (data.success && data.task) {
                const task = data.task;
                
                // 显示任务信息
                appendOutput(`任务名称: ${task.task_name}`, 'info', 'api');
                appendOutput(`任务状态: ${getStatusText(task.status)}`, 'info', 'api');
                appendOutput(`当前进度: ${task.progress}/${task.total}`, 'info', 'api');
                if (task.current_step) {
                    appendOutput(`当前步骤: ${task.current_step}`, 'info', 'api');
                }
                appendOutput('', 'info', 'api');
                appendOutput('='.repeat(60), 'info', 'api');
                appendOutput('历史日志:', 'info', 'api');
                appendOutput('='.repeat(60), 'info', 'api');
                
                // 加载历史日志
                loadTaskLogs(taskId);
                
                // 如果任务还在运行，开始轮询新日志
                if (task.status === 'running') {
                    startLogPolling(taskId);
                    updateStatus('running', '执行中（已恢复）', 'api');
                    
                    // 显示停止按钮
                    if (typeof setCurrentTaskId === 'function') {
                        setCurrentTaskId(taskId);
                    }
                } else {
                    updateStatus(task.status, getStatusText(task.status), 'api');
                }
            } else {
                appendOutput('恢复任务失败: ' + (data.error || '未知错误'), 'error', 'api');
            }
        })
        .catch(error => {
            appendOutput('恢复任务失败: ' + error.message, 'error', 'api');
        });
}

/**
 * 加载任务历史日志
 */
function loadTaskLogs(taskId, lastN = null) {
    let url = `/api/tasks/${taskId}/logs?from_file=true`;
    if (lastN) {
        url += `&last_n=${lastN}`;
    }
    
    fetch(url)
        .then(response => response.json())
        .then(data => {
            if (data.success && data.logs) {
                // 显示日志
                data.logs.forEach(log => {
                    appendOutput(log.message, log.level, 'api');
                });
                
                if (data.logs.length > 0) {
                    appendOutput('', 'info', 'api');
                    appendOutput('='.repeat(60), 'info', 'api');
                    appendOutput('实时日志:', 'info', 'api');
                    appendOutput('='.repeat(60), 'info', 'api');
                }
            }
        })
        .catch(error => {
            console.error('加载历史日志失败:', error);
        });
}

/**
 * 开始轮询新日志
 */
function startLogPolling(taskId) {
    let lastLogCount = 0;
    
    // 清除之前的轮询
    if (logPollingInterval) {
        clearInterval(logPollingInterval);
    }
    
    // 每2秒轮询一次
    logPollingInterval = setInterval(() => {
        fetch(`/api/tasks/${taskId}`)
            .then(response => response.json())
            .then(data => {
                if (data.success && data.task) {
                    const task = data.task;
                    
                    // 更新进度
                    if (task.progress !== undefined && task.total !== undefined) {
                        const progressText = `进度: ${task.progress}/${task.total}`;
                        updateStatus('running', progressText, 'api');
                    }
                    
                    // 检查任务是否完成
                    if (task.status !== 'running') {
                        stopLogPolling();
                        updateStatus(task.status, getStatusText(task.status), 'api');
                        
                        // 隐藏停止按钮
                        if (typeof clearCurrentTaskId === 'function') {
                            clearCurrentTaskId();
                        }
                        
                        // 加载最后的日志
                        loadNewLogs(taskId, lastLogCount);
                        return;
                    }
                    
                    // 加载新日志
                    loadNewLogs(taskId, lastLogCount, (newCount) => {
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
 */
function loadNewLogs(taskId, skipCount, callback) {
    fetch(`/api/tasks/${taskId}/logs?from_file=true`)
        .then(response => response.json())
        .then(data => {
            if (data.success && data.logs) {
                const newLogs = data.logs.slice(skipCount);
                
                // 显示新日志
                newLogs.forEach(log => {
                    appendOutput(log.message, log.level, 'api');
                });
                
                // 回调返回新的总数
                if (callback) {
                    callback(data.logs.length);
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
                    <button class="btn-small btn-primary" onclick="recoverTask('${task.task_id}'); closeTaskHistoryModal();">查看</button>
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
