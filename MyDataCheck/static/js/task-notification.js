/**
 * 任务完成通知模块
 * 功能：
 * 1. 检查当前用户是否有已完成但未下载的任务
 * 2. 弹出提醒让用户下载
 */

// 已下载任务的localStorage key
const DOWNLOADED_TASKS_KEY = 'myDataCheck_downloadedTasks';

/**
 * 通知服务端标记任务为已下载，刷新页面后不再提醒
 * @param {string} taskId - 任务ID
 */
function markTaskDownloadedOnServer(taskId) {
    if (!taskId) return;
    fetch(`/api/tasks/${taskId}/mark-downloaded`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' }
    }).then(resp => resp.json()).then(data => {
        if (data.success) {
            console.log(`[TaskNotification] 服务端已标记任务为已下载: ${taskId}`);
        }
    }).catch(err => {
        console.error('[TaskNotification] 服务端标记失败:', err);
    });
}

// 获取已下载的任务列表
function getDownloadedTasks() {
    try {
        const data = localStorage.getItem(DOWNLOADED_TASKS_KEY);
        return data ? JSON.parse(data) : {};
    } catch (e) {
        return {};
    }
}

// 标记任务已下载
function markTaskDownloaded(taskId) {
    try {
        console.log(`[TaskNotification] 标记任务为已下载: ${taskId}`);
        const downloaded = getDownloadedTasks();
        downloaded[taskId] = {
            taskId,
            downloadTime: new Date().toISOString()
        };
        localStorage.setItem(DOWNLOADED_TASKS_KEY, JSON.stringify(downloaded));
        console.log(`[TaskNotification] 任务已保存到 localStorage:`, downloaded[taskId]);
    } catch (e) {
        console.error('保存任务下载记录失败:', e);
    }
}

// 检查任务是否已下载
function isTaskDownloaded(taskId) {
    const downloaded = getDownloadedTasks();
    return !!downloaded[taskId];
}

// 清理过期的任务下载记录（超过30天）
function cleanupTaskDownloadHistory() {
    try {
        const downloaded = getDownloadedTasks();
        const now = new Date();
        const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);

        let cleaned = false;
        for (const taskId in downloaded) {
            const record = downloaded[taskId];
            if (record.downloadTime) {
                const downloadTime = new Date(record.downloadTime);
                if (downloadTime < thirtyDaysAgo) {
                    delete downloaded[taskId];
                    cleaned = true;
                }
            }
        }

        if (cleaned) {
            localStorage.setItem(DOWNLOADED_TASKS_KEY, JSON.stringify(downloaded));
        }
    } catch (e) {
        console.error('清理任务下载记录失败:', e);
    }
}

// 检查已完成的任务
async function checkCompletedTasks() {
    const userId = getUserId();
    if (!userId) return;

    try {
        console.log(`[TaskNotification] 检查用户 ${userId} 的已完成任务...`);

        const response = await fetch(`/api/tasks?user_id=${encodeURIComponent(userId)}&status=completed`);
        const data = await response.json();

        if (data.success && data.tasks && data.tasks.length > 0) {
            console.log(`[TaskNotification] 找到 ${data.tasks.length} 个已完成任务`);

            // 获取已下载的任务记录
            const downloadedTasks = getDownloadedTasks();
            console.log(`[TaskNotification] 已下载任务记录:`, downloadedTasks);

            // 过滤出未下载的已完成任务
            const undownloadedTasks = data.tasks.filter(task => {
                const isDownloaded = isTaskDownloaded(task.task_id);
                console.log(`[TaskNotification] 任务 ${task.task_id}: ${isDownloaded ? '已下载' : '未下载'}`);
                return !isDownloaded && task.status === 'completed';
            });

            console.log(`[TaskNotification] 未下载任务数: ${undownloadedTasks.length}`);

            if (undownloadedTasks.length > 0) {
                showTaskNotificationModal(undownloadedTasks);
            }
        } else {
            console.log(`[TaskNotification] 没有找到已完成任务`);
        }

        // 清理过期记录
        cleanupTaskDownloadHistory();
    } catch (error) {
        console.error('检查已完成任务失败:', error);
    }
}

// 显示任务完成提醒弹窗
function showTaskNotificationModal(tasks) {
    // 如果已有弹窗，先关闭
    closeTaskNotificationModal();

    // 创建遮罩层
    const overlay = document.createElement('div');
    overlay.className = 'task-notification-overlay';
    overlay.id = 'task-notification-overlay';

    // 生成任务列表HTML
    const taskListHtml = tasks.map(task => `
        <div class="task-notification-item" data-task-id="${task.task_id}">
            <div class="task-notification-status">✅</div>
            <div class="task-notification-info">
                <div class="task-notification-name">${task.task_type || '数据对比'} - ${task.task_name || '未命名'}</div>
                <div class="task-notification-time">完成时间：${formatTaskTime(task.end_time || task.update_time)}</div>
            </div>
            <button class="btn-download-task" onclick="downloadTaskFiles('${task.task_id}')">下载结果</button>
        </div>
    `).join('');

    // 创建弹窗
    const modal = document.createElement('div');
    modal.className = 'task-notification-modal';
    modal.innerHTML = `
        <div class="task-notification-header">
            <span class="task-notification-icon">📢</span>
            <h3>任务完成提醒</h3>
        </div>
        <div class="task-notification-body">
            <p class="task-notification-summary">您有 <strong>${tasks.length}</strong> 个任务已完成：</p>
            <div class="task-notification-list">
                ${taskListHtml}
            </div>
        </div>
        <div class="task-notification-footer">
            <button class="btn-later" onclick="dismissTaskNotification()">稍后提醒</button>
            <button class="btn-download-all" onclick="confirmDownloadNotification()">下载提醒</button>
        </div>
    `;

    overlay.appendChild(modal);
    document.body.appendChild(overlay);

    // 保存当前待处理的任务
    window._pendingNotificationTasks = tasks;
}

// 关闭任务完成提醒弹窗
function closeTaskNotificationModal() {
    const overlay = document.getElementById('task-notification-overlay');
    if (overlay) {
        overlay.remove();
    }
}

// 格式化任务时间
function formatTaskTime(timeStr) {
    if (!timeStr) return '未知';
    try {
        const date = new Date(timeStr);
        const month = String(date.getMonth() + 1).padStart(2, '0');
        const day = String(date.getDate()).padStart(2, '0');
        const hour = String(date.getHours()).padStart(2, '0');
        const minute = String(date.getMinutes()).padStart(2, '0');
        return `${month}-${day} ${hour}:${minute}`;
    } catch (e) {
        return timeStr;
    }
}

// 下载单个任务的文件
async function downloadTaskFiles(taskId) {
    try {
        const response = await fetch(`/api/task/${taskId}/files`);
        const data = await response.json();

        if (data.success && data.files && data.files.length > 0) {
            // 依次下载文件
            for (const file of data.files) {
                await downloadFile(file.path);
                await sleep(500); // 间隔500ms避免浏览器阻止
            }

            // 标记任务已下载
            markTaskDownloaded(taskId);
            markTaskDownloadedOnServer(taskId);

            // 更新UI
            const taskItem = document.querySelector(`.task-notification-item[data-task-id="${taskId}"]`);
            if (taskItem) {
                taskItem.classList.add('downloaded');
                taskItem.querySelector('.btn-download-task').textContent = '已下载';
                taskItem.querySelector('.btn-download-task').disabled = true;
            }
        } else {
            alert('未找到该任务的输出文件');
        }
    } catch (error) {
        console.error('下载任务文件失败:', error);
        alert('下载失败，请稍后重试');
    }
}

// 下载所有任务的文件
async function downloadAllTaskFiles() {
    const tasks = window._pendingNotificationTasks || [];

    for (const task of tasks) {
        await downloadTaskFiles(task.task_id);
        await sleep(1000);
    }

    // 关闭弹窗
    closeTaskNotificationModal();
}

// 稍后提醒（关闭弹窗但不标记已下载）
function dismissTaskNotification() {
    closeTaskNotificationModal();
}

// 点击"下载提醒"按钮时，标记所有任务为已下载并关闭弹窗
function confirmDownloadNotification() {
    const tasks = window._pendingNotificationTasks || [];

    // 标记所有任务为已下载
    for (const task of tasks) {
        markTaskDownloaded(task.task_id);
        markTaskDownloadedOnServer(task.task_id);
    }

    // 关闭弹窗
    closeTaskNotificationModal();

    console.log(`[TaskNotification] 已标记 ${tasks.length} 个任务为已下载`);
}

// 下载文件
function downloadFile(filePath) {
    return new Promise((resolve) => {
        const filename = filePath.split('/').pop();
        const link = document.createElement('a');
        link.href = `/download/${encodeURIComponent(filename)}`;
        link.download = filename;
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        resolve();
    });
}

// 延时函数
function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}
