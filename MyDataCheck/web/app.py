#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Flask应用主入口模块

功能说明:
    - 创建和配置Flask应用实例
    - 初始化应用目录结构
    - 注册路由蓝图
    - 处理全局错误
    - 启动Web服务器

作者: MyDataCheck Team
创建时间: 2026-01
最后更新: 2026-03-02
"""

import os
import sys
import signal
from flask import Flask

# 添加父目录到路径，确保可以导入web模块
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from web.config import init_directories, MAX_CONTENT_LENGTH
from web.routes import register_blueprints
from common.auto_cleanup import startup_cleanup

# ==================== 环境变量配置 ====================
# 服务端口，默认5001
SERVER_PORT = int(os.environ.get('SERVER_PORT', 5001))
# 服务Host，默认0.0.0.0
SERVER_HOST = os.environ.get('SERVER_HOST', '0.0.0.0')
# 清理保留天数，默认3天
CLEANUP_RETENTION_DAYS = int(os.environ.get('CLEANUP_RETENTION_DAYS', 3))


def create_app():
    """
    创建并配置Flask应用实例
    
    功能:
        1. 设置模板目录路径
        2. 配置文件上传大小限制
        3. 初始化必要的目录结构
        4. 注册所有路由蓝图
        5. 配置全局错误处理器
    
    Returns:
        Flask: 配置完成的Flask应用实例
    
    示例:
        >>> app = create_app()
        >>> app.run(host='0.0.0.0', port=5001)
    """
    # 获取templates目录路径（相对于项目根目录）
    template_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'templates')
    
    # 获取static目录路径（相对于项目根目录）
    static_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'static')
    
    # 创建Flask应用实例
    app = Flask(__name__, template_folder=template_dir, static_folder=static_dir, static_url_path='/static')
    
    # 配置应用：设置最大上传文件大小（5GB）
    app.config['MAX_CONTENT_LENGTH'] = MAX_CONTENT_LENGTH
    print(f"[CONFIG] 文件上传大小限制: {MAX_CONTENT_LENGTH / (1024**3):.2f} GB")
    
    # 初始化目录：创建输入输出数据目录
    init_directories()
    
    # 启动定时清理任务（每日凌晨3点清理N天前的旧文件）
    startup_cleanup(retention_days=CLEANUP_RETENTION_DAYS)
    
    # 注册蓝图：注册所有功能模块的路由
    register_blueprints(app)
    
    # 错误处理：处理文件过大错误
    @app.errorhandler(413)
    def request_entity_too_large(error):
        """
        处理413错误（请求实体过大）
        
        当上传的文件超过MAX_CONTENT_LENGTH限制时触发
        
        Args:
            error: 错误对象
        
        Returns:
            tuple: (JSON响应, HTTP状态码)
        """
        from flask import jsonify
        return jsonify({
            'success': False,
            'error': '文件过大，超过1GB限制'
        }), 413
    
    return app


def signal_handler(sig, frame):
    """
    处理系统信号（Ctrl+C）
    
    当用户按下Ctrl+C时，优雅地关闭服务器
    
    Args:
        sig: 信号编号
        frame: 当前堆栈帧
    
    Note:
        该函数会终止程序执行
    """
    print('\n\n收到中断信号，正在关闭服务器...')
    sys.exit(0)


def main():
    """
    主函数：启动Web服务器
    
    功能:
        1. 注册信号处理器（Ctrl+C）
        2. 创建Flask应用实例
        3. 显示启动信息
        4. 启动Web服务器
    
    环境变量:
        - SERVER_HOST: 监听地址，默认0.0.0.0
        - SERVER_PORT: 端口号，默认5001
        - CLEANUP_RETENTION_DAYS: 清理保留天数，默认3天
    
    Note:
        服务器启动后，可通过配置的地址和端口访问
        按 Ctrl+C 可停止服务器
    """
    # 注册信号处理器：捕获Ctrl+C信号
    signal.signal(signal.SIGINT, signal_handler)
    
    # 创建应用实例
    app = create_app()
    
    # 显示启动信息
    print("=" * 80)
    print("数据对比 - Web界面")
    print("=" * 80)
    print("服务器启动中...")
    print(f"监听地址: {SERVER_HOST}:{SERVER_PORT}")
    print(f"清理策略: 每日凌晨3点清理{CLEANUP_RETENTION_DAYS}天前的数据")
    print("按 Ctrl+C 停止服务器")
    print("=" * 80)
    
    # 启动服务器
    app.run(
        host=SERVER_HOST,    # 监听地址（环境变量配置）
        port=SERVER_PORT,    # 端口号（环境变量配置）
        debug=False,         # 生产模式（关闭调试）
        threaded=True        # 启用多线程处理请求
    )


if __name__ == '__main__':
    main()
