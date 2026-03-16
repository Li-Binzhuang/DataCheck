// UI交互相关函数

// 侧边栏切换函数
function toggleSidebar() {
    const sidebar = document.getElementById('sidebar');
    const mainContent = document.getElementById('mainContent');

    // 切换侧边栏的collapsed类
    sidebar.classList.toggle('collapsed');

    // 切换主内容区域的expanded类
    mainContent.classList.toggle('expanded');

    // 保存状态到localStorage
    const isCollapsed = sidebar.classList.contains('collapsed');
    localStorage.setItem('sidebarCollapsed', isCollapsed);
}

// 页面加载时恢复状态
window.addEventListener('DOMContentLoaded', function () {
    // 恢复侧边栏状态
    const sidebarCollapsed = localStorage.getItem('sidebarCollapsed');
    if (sidebarCollapsed === 'true') {
        const sidebar = document.getElementById('sidebar');
        const mainContent = document.getElementById('mainContent');
        sidebar.classList.add('collapsed');
        mainContent.classList.add('expanded');
    }

    // 恢复二级菜单展开状态
    const toolsExpanded = localStorage.getItem('submenu-tools-expanded');
    if (toolsExpanded === 'true') {
        const submenu = document.getElementById('submenu-tools');
        const parentItem = document.querySelector('.menu-parent[onclick*="tools"]');
        if (submenu && parentItem) {
            submenu.classList.add('expanded');
            parentItem.classList.add('expanded');
        }
    }
});

// 页面切换函数（侧边栏菜单）
function switchPage(pageName) {
    console.log('switchPage called with:', pageName);

    // 隐藏所有页面
    document.querySelectorAll('.content-section').forEach(section => {
        section.classList.remove('active');
        console.log('Hiding section:', section.id);
    });

    // 移除所有菜单项的active状态（包括子菜单项）
    document.querySelectorAll('.menu-item').forEach(item => {
        item.classList.remove('active');
    });

    // 显示选中的页面
    const targetPage = document.getElementById(`page-${pageName}`);
    if (targetPage) {
        targetPage.classList.add('active');
        console.log('Showing page:', targetPage.id);

        // 如果切换到数据对比页面，重新加载配置
        if (pageName === 'compare') {
            console.log('[INFO] 切换到数据对比页面，重新加载配置...');
            setTimeout(() => {
                if (typeof loadCompareConfig === 'function') {
                    loadCompareConfig();
                }
            }, 100);
        }
    } else {
        console.error('Page not found:', `page-${pageName}`);
    }

    // 激活对应的菜单项
    if (typeof event !== 'undefined' && event && event.target) {
        const menuItem = event.target.closest('.menu-item');
        if (menuItem) {
            menuItem.classList.add('active');
            console.log('Menu item activated');
        }
    }
}

// 二级菜单展开/收起函数
function toggleSubmenu(event, submenuId) {
    event.stopPropagation(); // 阻止事件冒泡

    const submenu = document.getElementById(`submenu-${submenuId}`);
    const parentItem = event.currentTarget;

    if (submenu && parentItem) {
        const isExpanded = submenu.classList.contains('expanded');

        if (isExpanded) {
            // 收起
            submenu.classList.remove('expanded');
            parentItem.classList.remove('expanded');
        } else {
            // 展开
            submenu.classList.add('expanded');
            parentItem.classList.add('expanded');
        }

        // 保存状态到localStorage
        localStorage.setItem(`submenu-${submenuId}-expanded`, !isExpanded);
    }
}

// Tab切换（保留兼容性）
function switchTab(tabName) {
    switchPage(tabName);
}

// 输出相关函数
function appendOutput(tabId, message, type = 'info') {
    // 兼容两种调用格式：
    // 格式1 (ui.js): appendOutput(tabId, message, type)
    // 格式2 (api-compare等): appendOutput(message, type, tabId)
    // 判断依据：如果第一个参数对应不到 output-panel，则认为是格式2
    let outputDiv = document.getElementById(`output-panel-${tabId}`);
    if (!outputDiv && typeof message === 'string') {
        // 尝试格式2：第三个参数是tabId
        const altDiv = document.getElementById(`output-panel-${type}`);
        if (altDiv) {
            outputDiv = altDiv;
            const realTab = type;
            type = message;
            message = tabId;
            tabId = realTab;
        }
    }
    if (!outputDiv) return;

    // 初始化计数器
    if (!outputCounters[tabId]) {
        outputCounters[tabId] = 0;
    }

    // 检查是否是关键信息（错误、成功、进度等）
    const isKeyMessage = type === 'error' || type === 'success' ||
        message.includes('✓') || message.includes('✗') ||
        message.includes('开始') || message.includes('完成') ||
        message.includes('失败') || message.includes('成功') ||
        message.includes('进度') || message.includes('%');

    // 显示所有日志（不再采样）
    const line = document.createElement('div');
    line.className = `output-line ${type}`;
    line.textContent = message;
    outputDiv.appendChild(line);

    // 限制总行数（防止内存溢出）
    const lines = outputDiv.querySelectorAll('.output-line');
    if (lines.length > MAX_OUTPUT_LINES) {
        // 删除最旧的行（保留最新的MAX_OUTPUT_LINES行）
        const toRemove = lines.length - MAX_OUTPUT_LINES;
        for (let i = 0; i < toRemove; i++) {
            lines[i].remove();
        }
    }

    // 自动滚动到底部（防抖）
    clearTimeout(outputDiv.scrollTimeout);
    outputDiv.scrollTimeout = setTimeout(() => {
        outputDiv.scrollTop = outputDiv.scrollHeight;
    }, 50);
}

function clearOutput(tabId) {
    const outputDiv = document.getElementById(`output-panel-${tabId}`);
    if (outputDiv) {
        outputDiv.innerHTML = '';
        // 重置计数器
        outputCounters[tabId] = 0;
    }
}

// 场景折叠/展开函数
function toggleScenarioCollapse(scenarioId) {
    const content = document.getElementById(`scenario-content-${scenarioId}`);
    const toggleBtn = document.getElementById(`toggle-btn-${scenarioId}`);
    const card = document.getElementById(scenarioId);

    if (content && toggleBtn && card) {
        const isCollapsed = content.classList.contains('collapsed');

        if (isCollapsed) {
            // 展开
            content.classList.remove('collapsed');
            toggleBtn.classList.remove('collapsed');
            toggleBtn.textContent = '▼';
            card.classList.remove('collapsed');
        } else {
            // 收起
            content.classList.add('collapsed');
            toggleBtn.classList.add('collapsed');
            toggleBtn.textContent = '▶';
            card.classList.add('collapsed');
        }
    }
}
