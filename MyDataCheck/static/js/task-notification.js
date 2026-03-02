/**
 * 任务完成通知模块
 * 功能：
 * 1. 检查当前用户是否有已完成但未下载的任务
 * 2. 弹出提醒让用户下载
 */

// 已提醒过的任务ID集合（避免重复提醒）
const NOTIFIED_TASKS_KEY = 'myDataCheck_notifiedTasks';

// 获取已提醒的任务列表
function getNotifiedTasks() {
    const data = localStorage.getItem(NOTIFIED_TASKS_KEY);
    return data ? JSON.parse(data) : [];
}

// 标记任务已提醒
function markTaskNotified(taskId) {
    const notified = getNotifiedTasks();
    if (!notified.includes(taskId)) {
        notified.push(taskId);
        localStorage.setItem(NOTIFIED_TASKS_KEY, JSON.stringify(notified));
    }
}

// 检查已完成的任务
async function checkCompletedTasks() {
    const userId = getUserId();
    if (!userId) return;

    try {
        const response = await fetch(`/api/tasks?user_id=${encodeURIComponent(userId)}&status=completed`);
        const data = await response.json();

        if (data.success && data.tasks && data.tasks.length > 0) {
            const notifiedTasks = getNotifiedTasks();

            // 过滤出未提醒的已完成任务
            const unnotifiedTasks = data.tasks.filter(task =>
                !notifiedTasks.includes(task.task_id) &&
                task.status === 'completed'
            );

            if (unnotifiedTasks.length > 0) {
                showTaskNotificationModal(unnotifiedTasks);
            }
        }
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
            <button class="btn-download-all" onclick="downloadAllTaskFiles()">全部下载</button>
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

            // 标记任务已提醒
            markTaskNotified(taskId);

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

// 稍后提醒（关闭弹窗但不标记已提醒）
function dismissTaskNotification() {
    closeTaskNotificationModal();
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
