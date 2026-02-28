#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
路由模块
"""

from flask import Blueprint


def register_blueprints(app):
    """注册所有蓝图到Flask应用"""
    from .main import main_bp
    from .api_routes import api_bp
    from .online_routes import online_bp
    from .compare_routes import compare_bp
    from .pkl_routes import pkl_bp
    from .stop_routes import stop_bp
    from .batch_run_routes import batch_run_bp
    
    app.register_blueprint(main_bp)
    app.register_blueprint(api_bp)
    app.register_blueprint(online_bp)
    app.register_blueprint(compare_bp)
    app.register_blueprint(pkl_bp)
    app.register_blueprint(stop_bp)
    app.register_blueprint(batch_run_bp)
