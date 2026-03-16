// ========== 自动下载功能 ==========

// 下载记录的localStorage key
const DOWNLOAD_HISTORY_KEY = 'myDataCheck_downloadHistory';

/**
 * 获取下载历史记录
 */
function getDownloadHistory() {
    try {
        const data = localStorage.getItem(DOWNLOAD_HISTORY_KEY);
        return data ? JSON.parse(data) : {};
    } catch (e) {
        return {};
    }
}

/**
 * 标记文件已下载
 * @param {string} filename - 文件名
 * @param {string} module - 模块名
 */
function markFileDownloaded(filename, module) {
    try {
        const history = getDownloadHistory();
        const key = `${module}:${filename}`;
        history[key] = {
            filename,
            module,
            downloadTime: new Date().toISOString()
        };
        localStorage.setItem(DOWNLOAD_HISTORY_KEY, JSON.stringify(history));
    } catch (e) {
        console.error('[AutoDownload] 保存下载记录失败:', e);
    }
}

/**
 * 检查文件是否已下载
 * @param {string} filename - 文件名
 * @param {string} module - 模块名
 */
function isFileDownloaded(filename, module) {
    const history = getDownloadHistory();
    const key = `${module}:${filename}`;
    return !!history[key];
}

/**
 * 清理过期的下载记录（超过7天）
 */
function cleanupDownloadHistory() {
    try {
        const history = getDownloadHistory();
        const now = new Date();
        const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);

        let cleaned = false;
        for (const key in history) {
            const record = history[key];
            if (record.downloadTime) {
                const downloadTime = new Date(record.downloadTime);
                if (downloadTime < sevenDaysAgo) {
                    delete history[key];
                    cleaned = true;
                }
            }
        }

        if (cleaned) {
            localStorage.setItem(DOWNLOAD_HISTORY_KEY, JSON.stringify(history));
        }
    } catch (e) {
        console.error('[AutoDownload] 清理下载记录失败:', e);
    }
}

/**
 * 任务完成后自动下载输出文件
 * @param {string} module - 模块名 (api_comparison, online_comparison, data_comparison)
 * @param {number} minutes - 获取最近多少分钟内的文件
 * @param {string} taskId - 任务ID（可选），如果提供则自动标记任务为已下载
 */
async function autoDownloadOutputFiles(module, minutes = 2, taskId = null) {
    try {
        console.log(`[AutoDownload] 开始获取 ${module} 模块的输出文件...`);
        console.log(`[AutoDownload] taskId: ${taskId}`);

        const response = await fetch('/api/latest-output-files', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ module, minutes })
        });

        const data = await response.json();

        if (!data.success) {
            console.error('[AutoDownload] 获取文件列表失败:', data.error);
            return;
        }

        const files = data.files || [];

        if (files.length === 0) {
            console.log('[AutoDownload] 没有找到需要下载的文件');
            // 即使没有文件，如果提供了taskId，也标记任务为已下载
            if (taskId) {
                if (typeof markTaskDownloaded === 'function') {
                    markTaskDownloaded(taskId);
                    console.log(`[AutoDownload] 任务已标记为已下载（无文件）: ${taskId}`);
                } else {
                    console.error('[AutoDownload] markTaskDownloaded 函数不存在');
                }
                markTaskDownloadedOnServer(taskId);
            }
            return;
        }

        // 过滤掉已下载的文件
        const undownloadedFiles = files.filter(file => !isFileDownloaded(file.filename, module));

        if (undownloadedFiles.length === 0) {
            console.log(`[AutoDownload] 所有文件已下载，跳过重复下载`);
            // 即使文件已下载，如果提供了taskId，也标记任务为已下载
            if (taskId) {
                if (typeof markTaskDownloaded === 'function') {
                    markTaskDownloaded(taskId);
                    console.log(`[AutoDownload] 任务已标记为已下载（文件已下载）: ${taskId}`);
                } else {
                    console.error('[AutoDownload] markTaskDownloaded 函数不存在');
                }
                markTaskDownloadedOnServer(taskId);
            }
            return;
        }

        console.log(`[AutoDownload] 找到 ${undownloadedFiles.length} 个未下载的文件，开始下载...`);

        // 显示下载提示
        showDownloadNotification(undownloadedFiles);

        // 依次下载文件（间隔500ms，避免浏览器阻止）
        for (let i = 0; i < undownloadedFiles.length; i++) {
            const file = undownloadedFiles[i];
            setTimeout(() => {
                downloadFile(file.filename, module);
                markFileDownloaded(file.filename, module);
            }, i * 500);
        }

        // 如果提供了taskId，标记任务为已下载
        if (taskId) {
            if (typeof markTaskDownloaded === 'function') {
                markTaskDownloaded(taskId);
                console.log(`[AutoDownload] 任务已标记为已下载: ${taskId}`);
            } else {
                console.error('[AutoDownload] markTaskDownloaded 函数不存在');
            }
            markTaskDownloadedOnServer(taskId);
        } else {
            console.warn('[AutoDownload] 未提供 taskId，无法标记任务为已下载');
        }

        // 清理过期记录
        cleanupDownloadHistory();

    } catch (error) {
        console.error('[AutoDownload] 自动下载失败:', error);
    }
}

/**
 * 下载单个文件
 * @param {string} filename - 文件名
 * @param {string} module - 模块名
 */
function downloadFile(filename, module) {
    const url = `/api/download/${encodeURIComponent(filename)}?module=${module}`;

    // 创建隐藏的a标签触发下载
    const link = document.createElement('a');
    link.href = url;
    link.download = filename;
    link.style.display = 'none';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);

    console.log(`[AutoDownload] 已触发下载: ${filename}`);
}

/**
 * 显示下载通知
 * @param {Array} files - 文件列表
 */
function showDownloadNotification(files) {
    // 创建通知元素
    const notification = document.createElement('div');
    notification.className = 'download-notification';
    notification.innerHTML = `
        <div class="download-notification-content">
            <div class="download-notification-icon">📥</div>
            <div class="download-notification-text">
                <strong>正在下载 ${files.length} 个文件</strong>
                <div class="download-file-list">
                    ${files.map(f => `<div class="download-file-item">${f.filename} (${f.size_human})</div>`).join('')}
                </div>
            </div>
            <button class="download-notification-close" onclick="this.parentElement.parentElement.remove()">×</button>
        </div>
    `;

    document.body.appendChild(notification);

    // 5秒后自动消失
    setTimeout(() => {
        if (notification.parentElement) {
            notification.classList.add('fade-out');
            setTimeout(() => notification.remove(), 300);
        }
    }, 5000);
}

/**
 * 手动下载指定模块的最新文件
 * @param {string} module - 模块名
 */
async function manualDownloadLatestFiles(module) {
    await autoDownloadOutputFiles(module, 60); // 获取最近1小时的文件
}

// 添加下载通知的样式
(function addDownloadStyles() {
    if (document.getElementById('auto-download-styles')) return;

    const style = document.createElement('style');
    style.id = 'auto-download-styles';
    style.textContent = `
        .download-notification {
            position: fixed;
            bottom: 20px;
            right: 20px;
            z-index: 10000;
            animation: slideIn 0.3s ease;
        }
        
        .download-notification.fade-out {
            animation: fadeOut 0.3s ease forwards;
        }
        
        .download-notification-content {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 16px 20px;
            border-radius: 12px;
            box-shadow: 0 8px 24px rgba(102, 126, 234, 0.4);
            display: flex;
            align-items: flex-start;
            gap: 12px;
            max-width: 400px;
        }
        
        .download-notification-icon {
            font-size: 24px;
        }
        
        .download-notification-text {
            flex: 1;
        }
        
        .download-notification-text strong {
            display: block;
            margin-bottom: 8px;
        }
        
        .download-file-list {
            font-size: 12px;
            opacity: 0.9;
            max-height: 100px;
            overflow-y: auto;
        }
        
        .download-file-item {
            padding: 2px 0;
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
        }
        
        .download-notification-close {
            background: rgba(255,255,255,0.2);
            border: none;
            color: white;
            width: 24px;
            height: 24px;
            border-radius: 50%;
            cursor: pointer;
            font-size: 16px;
            line-height: 1;
        }
        
        .download-notification-close:hover {
            background: rgba(255,255,255,0.3);
        }
        
        @keyframes slideIn {
            from {
                transform: translateX(100%);
                opacity: 0;
            }
            to {
                transform: translateX(0);
                opacity: 1;
            }
        }
        
        @keyframes fadeOut {
            from {
                opacity: 1;
            }
            to {
                opacity: 0;
            }
        }
    `;
    document.head.appendChild(style);
})();
