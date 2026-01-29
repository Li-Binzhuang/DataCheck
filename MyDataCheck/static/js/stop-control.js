/**
 * 停止控制模块
 * 
 * 功能：
 * - 管理任务停止按钮
 * - 发送停止请求到后端
 * - 更新按钮状态
 * 
 * 作者: MyDataCheck Team
 * 创建时间: 2026-01-29
 */

// 全局变量：当前任务ID
let currentTaskId = null;

/**
 * 设置当前任务ID
 * @param {string} taskId - 任务ID
 */
function setCurrentTaskId(taskId) {
    currentTaskId = taskId;
    console.log('[StopControl] 任务ID已设置:', taskId);
    
    // 显示停止按钮
    showStopButton();
}

/**
 * 清除当前任务ID
 */
function clearCurrentTaskId() {
    console.log('[StopControl] 任务ID已清除:', currentTaskId);
    currentTaskId = null;
    
    // 隐藏停止按钮
    hideStopButton();
}

/**
 * 显示停止按钮
 */
function showStopButton() {
    const stopBtn = document.getElementById('btn-stop-task');
    if (stopBtn) {
        stopBtn.style.display = 'inline-block';
        stopBtn.disabled = false;
    }
}

/**
 * 隐藏停止按钮
 */
function hideStopButton() {
    const stopBtn = document.getElementById('btn-stop-task');
    if (stopBtn) {
        stopBtn.style.display = 'none';
        stopBtn.disabled = false;
    }
}

/**
 * 停止当前任务
 */
async function stopCurrentTask() {
    if (!currentTaskId) {
        console.warn('[StopControl] 没有正在运行的任务');
        return;
    }
    
    const stopBtn = document.getElementById('btn-stop-task');
    if (stopBtn) {
        stopBtn.disabled = true;
        stopBtn.textContent = '停止中...';
    }
    
    try {
        console.log('[StopControl] 发送停止请求:', currentTaskId);
        
        const response = await fetch(`/api/stop/task/${currentTaskId}`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            }
        });
        
        const result = await response.json();
        
        if (result.success) {
            console.log('[StopControl] 停止信号已发送');
            
            // 显示提示
            if (typeof showAlert === 'function') {
                showAlert('停止信号已发送，任务将在下一个检查点停止', 'info');
            }
            
            // 更新按钮状态
            if (stopBtn) {
                stopBtn.textContent = '已发送停止信号';
                stopBtn.disabled = true;
            }
        } else {
            console.error('[StopControl] 停止失败:', result.message);
            
            if (typeof showAlert === 'function') {
                showAlert(`停止失败: ${result.message}`, 'error');
            }
            
            // 恢复按钮
            if (stopBtn) {
                stopBtn.textContent = '停止执行';
                stopBtn.disabled = false;
            }
        }
    } catch (error) {
        console.error('[StopControl] 停止请求失败:', error);
        
        if (typeof showAlert === 'function') {
            showAlert(`停止请求失败: ${error.message}`, 'error');
        }
        
        // 恢复按钮
        if (stopBtn) {
            stopBtn.textContent = '停止执行';
            stopBtn.disabled = false;
        }
    }
}

/**
 * 获取所有任务状态
 */
async function getAllTasks() {
    try {
        const response = await fetch('/api/stop/tasks');
        const result = await response.json();
        
        if (result.success) {
            console.log('[StopControl] 任务列表:', result.tasks);
            return result.tasks;
        } else {
            console.error('[StopControl] 获取任务列表失败');
            return [];
        }
    } catch (error) {
        console.error('[StopControl] 获取任务列表失败:', error);
        return [];
    }
}

/**
 * 清理已完成的任务
 */
async function clearCompletedTasks() {
    try {
        const response = await fetch('/api/stop/clear', {
            method: 'POST'
        });
        
        const result = await response.json();
        
        if (result.success) {
            console.log('[StopControl] 已清理任务:', result.cleared_count);
            return result.cleared_count;
        } else {
            console.error('[StopControl] 清理任务失败');
            return 0;
        }
    } catch (error) {
        console.error('[StopControl] 清理任务失败:', error);
        return 0;
    }
}

// 页面加载时初始化
document.addEventListener('DOMContentLoaded', function() {
    console.log('[StopControl] 停止控制模块已加载');
    
    // 隐藏停止按钮
    hideStopButton();
    
    // 绑定停止按钮事件
    const stopBtn = document.getElementById('btn-stop-task');
    if (stopBtn) {
        stopBtn.addEventListener('click', stopCurrentTask);
    }
});
