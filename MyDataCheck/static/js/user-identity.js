/**
 * 用户标识管理模块
 * 功能：
 * 1. 首次访问时弹出输入框让用户输入标识
 * 2. 标识存储在localStorage持久化
 * 3. 再次访问时自动读取
 * 4. 提供切换用户功能
 */

// 用户标识存储键名
const USER_ID_KEY = 'myDataCheck_userId';
const USER_NAME_KEY = 'myDataCheck_userName';

// 获取当前用户标识
function getUserId() {
    return localStorage.getItem(USER_ID_KEY) || '';
}

// 获取当前用户名称（用于显示）
function getUserName() {
    return localStorage.getItem(USER_NAME_KEY) || '';
}

// 设置用户标识
function setUserIdentity(userId, userName) {
    localStorage.setItem(USER_ID_KEY, userId);
    localStorage.setItem(USER_NAME_KEY, userName || userId);
    updateUserDisplay();
}

// 更新页面上的用户显示
function updateUserDisplay() {
    const userNameEl = document.getElementById('current-user-name');
    const userName = getUserName();
    if (userNameEl && userName) {
        userNameEl.textContent = userName;
    }
}

// 显示用户标识输入弹窗
function showUserIdentityModal(isFirstTime = true) {
    // 创建遮罩层
    const overlay = document.createElement('div');
    overlay.className = 'user-modal-overlay';
    overlay.id = 'user-modal-overlay';

    // 创建弹窗
    const modal = document.createElement('div');
    modal.className = 'user-modal';
    modal.innerHTML = `
        <div class="user-modal-header">
            <span class="user-modal-icon">👤</span>
            <h3>${isFirstTime ? '欢迎使用数据对比平台' : '切换用户'}</h3>
        </div>
        <div class="user-modal-body">
            <p>${isFirstTime ? '请输入您的用户标识，用于区分不同用户的任务和文件' : '请输入新的用户标识'}</p>
            <div class="user-input-group">
                <label for="user-id-input">用户标识 <span class="required">*</span></label>
                <input type="text" id="user-id-input" placeholder="例如：zhangsan、工号等" maxlength="20" autocomplete="off">
                <p class="input-hint">建议使用姓名拼音或工号，方便识别</p>
            </div>
            <div class="user-input-group">
                <label for="user-name-input">显示名称（可选）</label>
                <input type="text" id="user-name-input" placeholder="例如：张三" maxlength="20" autocomplete="off">
                <p class="input-hint">用于页面显示，不填则使用用户标识</p>
            </div>
        </div>
        <div class="user-modal-footer">
            ${!isFirstTime ? '<button class="btn-cancel" onclick="closeUserModal()">取消</button>' : ''}
            <button class="btn-confirm" onclick="confirmUserIdentity()">确认</button>
        </div>
    `;

    overlay.appendChild(modal);
    document.body.appendChild(overlay);

    // 聚焦输入框
    setTimeout(() => {
        document.getElementById('user-id-input').focus();
    }, 100);

    // 回车确认
    document.getElementById('user-id-input').addEventListener('keypress', (e) => {
        if (e.key === 'Enter') confirmUserIdentity();
    });
    document.getElementById('user-name-input').addEventListener('keypress', (e) => {
        if (e.key === 'Enter') confirmUserIdentity();
    });
}

// 关闭用户标识弹窗
function closeUserModal() {
    const overlay = document.getElementById('user-modal-overlay');
    if (overlay) {
        overlay.remove();
    }
}

// 确认用户标识
function confirmUserIdentity() {
    const userIdInput = document.getElementById('user-id-input');
    const userNameInput = document.getElementById('user-name-input');

    const userId = userIdInput.value.trim();
    const userName = userNameInput.value.trim();

    if (!userId) {
        userIdInput.style.borderColor = '#e74c3c';
        userIdInput.focus();
        return;
    }

    // 验证用户标识格式（只允许字母、数字、下划线）
    if (!/^[a-zA-Z0-9_]+$/.test(userId)) {
        alert('用户标识只能包含字母、数字和下划线');
        userIdInput.focus();
        return;
    }

    // 保存用户标识
    setUserIdentity(userId, userName || userId);

    // 关闭弹窗
    closeUserModal();

    // 检查是否有已完成的任务
    checkCompletedTasks();
}

// 切换用户
function switchUser() {
    showUserIdentityModal(false);
}

// 页面加载时检查用户标识
function initUserIdentity() {
    const userId = getUserId();

    if (!userId) {
        // 首次访问，显示输入弹窗
        showUserIdentityModal(true);
    } else {
        // 已有用户标识，更新显示
        updateUserDisplay();
        // 检查是否有已完成的任务
        setTimeout(checkCompletedTasks, 1000);
    }
}

// 页面加载完成后初始化
document.addEventListener('DOMContentLoaded', initUserIdentity);
