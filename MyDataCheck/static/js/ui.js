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

// 页面加载时恢复侧边栏状态
window.addEventListener('DOMContentLoaded', function() {
    const sidebarCollapsed = localStorage.getItem('sidebarCollapsed');
    if (sidebarCollapsed === 'true') {
        const sidebar = document.getElementById('sidebar');
        const mainContent = document.getElementById('mainContent');
        sidebar.classList.add('collapsed');
        mainContent.classList.add('expanded');
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
    
    // 移除所有菜单项的active状态
    document.querySelectorAll('.menu-item').forEach(item => {
        item.classList.remove('active');
    });
    
    // 显示选中的页面
    const targetPage = document.getElementById(`page-${pageName}`);
    if (targetPage) {
        targetPage.classList.add('active');
        console.log('Showing page:', targetPage.id);
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

// Tab切换（保留兼容性）
function switchTab(tabName) {
    switchPage(tabName);
}

// 输出相关函数
function appendOutput(tabId, message, type = 'info') {
    const outputDiv = document.getElementById(`${tabId}-output`);
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
    
    // 如果是关键信息，总是显示
    if (isKeyMessage) {
        const line = document.createElement('div');
        line.className = `output-line ${type}`;
        line.textContent = message;
        outputDiv.appendChild(line);
        outputDiv.scrollTop = outputDiv.scrollHeight;
        return;
    }
    
    // 非关键信息：采样显示
    outputCounters[tabId]++;
    
    // 每SAMPLE_RATE条显示一条
    if (outputCounters[tabId] % SAMPLE_RATE === 0) {
        const line = document.createElement('div');
        line.className = `output-line ${type}`;
        line.textContent = message;
        outputDiv.appendChild(line);
        
        // 限制总行数
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
}

function clearOutput(tabId) {
    const outputDiv = document.getElementById(`${tabId}-output`);
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
