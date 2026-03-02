// ========== 自动下载功能 ==========

/**
 * 任务完成后自动下载输出文件
 * @param {string} module - 模块名 (api_comparison, online_comparison, data_comparison)
 * @param {number} minutes - 获取最近多少分钟内的文件
 */
async function autoDownloadOutputFiles(module, minutes = 2) {
    try {
        console.log(`[AutoDownload] 开始获取 ${module} 模块的输出文件...`);

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
            return;
        }

        console.log(`[AutoDownload] 找到 ${files.length} 个文件，开始下载...`);

        // 显示下载提示
        showDownloadNotification(files);

        // 依次下载文件（间隔500ms，避免浏览器阻止）
        for (let i = 0; i < files.length; i++) {
            const file = files[i];
            setTimeout(() => {
                downloadFile(file.filename, module);
            }, i * 500);
        }

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
