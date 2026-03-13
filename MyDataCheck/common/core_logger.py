#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
核心日志模块 - 为所有功能模块提供统一的日志记录
支持性能分析、错误追踪、执行流程记录
"""

import os
import json
import time
from datetime import datetime
from pathlib import Path


class CoreLogger:
    """核心日志记录器"""
    
    def __init__(self, module_name: str, log_dir: str = None):
        """
        初始化日志记录器
        
        Args:
            module_name: 模块名称（如 'data_comparison', 'merge_csv'）
            log_dir: 日志目录，默认为 logs/{module_name}
        """
        self.module_name = module_name
        
        # 设置日志目录
        if log_dir is None:
            log_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'logs', module_name)
        
        self.log_dir = log_dir
        os.makedirs(self.log_dir, exist_ok=True)
        
        # 当前执行的日志文件
        self.current_log_file = None
        self.current_log_data = {
            'module': module_name,
            'start_time': None,
            'end_time': None,
            'duration': 0,
            'status': 'running',
            'events': [],
            'performance': {},
            'errors': []
        }
        
        self.start_time = None
    
    def start_execution(self, task_name: str, config: dict = None):
        """
        开始执行任务
        
        Args:
            task_name: 任务名称
            config: 任务配置
        """
        self.start_time = time.time()
        self.current_log_data = {
            'module': self.module_name,
            'task_name': task_name,
            'start_time': datetime.now().isoformat(),
            'end_time': None,
            'duration': 0,
            'status': 'running',
            'config': config or {},
            'events': [],
            'performance': {},
            'errors': [],
            'progress': []
        }
        
        self.log_event('START', f'开始执行任务: {task_name}')
    
    def log_event(self, event_type: str, message: str, data: dict = None):
        """
        记录事件
        
        Args:
            event_type: 事件类型（如 'START', 'PROGRESS', 'CHECKPOINT', 'ERROR', 'END'）
            message: 事件消息
            data: 附加数据
        """
        event = {
            'timestamp': datetime.now().isoformat(),
            'type': event_type,
            'message': message,
            'elapsed_time': time.time() - self.start_time if self.start_time else 0
        }
        
        if data:
            event['data'] = data
        
        self.current_log_data['events'].append(event)
        
        # 同时打印到控制台
        print(f"[{event_type}] {message}")
    
    def log_progress(self, current: int, total: int, stage: str = None):
        """
        记录进度
        
        Args:
            current: 当前进度
            total: 总数
            stage: 阶段名称
        """
        percentage = (current / total * 100) if total > 0 else 0
        
        progress_entry = {
            'timestamp': datetime.now().isoformat(),
            'current': current,
            'total': total,
            'percentage': round(percentage, 2),
            'stage': stage,
            'elapsed_time': time.time() - self.start_time if self.start_time else 0
        }
        
        self.current_log_data['progress'].append(progress_entry)
        
        # 每10%输出一次
        if percentage % 10 < 1 or current == total:
            print(f"[PROGRESS] {stage or '处理'}: {current}/{total} ({percentage:.1f}%)")
    
    def log_performance(self, metric_name: str, value: float, unit: str = None):
        """
        记录性能指标
        
        Args:
            metric_name: 指标名称
            value: 指标值
            unit: 单位（如 'ms', 'MB', 'rows'）
        """
        self.current_log_data['performance'][metric_name] = {
            'value': value,
            'unit': unit,
            'timestamp': datetime.now().isoformat()
        }
    
    def log_error(self, error_type: str, error_message: str, traceback_str: str = None):
        """
        记录错误
        
        Args:
            error_type: 错误类型
            error_message: 错误消息
            traceback_str: 错误堆栈
        """
        error_entry = {
            'timestamp': datetime.now().isoformat(),
            'type': error_type,
            'message': error_message,
            'traceback': traceback_str,
            'elapsed_time': time.time() - self.start_time if self.start_time else 0
        }
        
        self.current_log_data['errors'].append(error_entry)
        self.log_event('ERROR', f'{error_type}: {error_message}')
    
    def end_execution(self, status: str = 'completed', summary: dict = None):
        """
        结束执行任务
        
        Args:
            status: 执行状态（'completed', 'failed', 'cancelled'）
            summary: 执行摘要
        """
        end_time = time.time()
        duration = end_time - self.start_time if self.start_time else 0
        
        self.current_log_data['end_time'] = datetime.now().isoformat()
        self.current_log_data['duration'] = round(duration, 2)
        self.current_log_data['status'] = status
        
        if summary:
            self.current_log_data['summary'] = summary
        
        self.log_event('END', f'任务执行完成: {status}', {'duration': duration})
        
        # 保存日志
        self._save_logs()
    
    def _save_logs(self):
        """保存日志文件"""
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        
        # 保存当前日志
        current_log_file = os.path.join(self.log_dir, f'current_{timestamp}.json')
        with open(current_log_file, 'w', encoding='utf-8') as f:
            json.dump(self.current_log_data, f, ensure_ascii=False, indent=2)
        
        # 保存上一次日志（如果存在）
        self._rotate_logs()
    
    def _rotate_logs(self):
        """
        日志轮转 - 保留当前和上一次的日志
        """
        log_files = sorted([f for f in os.listdir(self.log_dir) if f.startswith('current_')])
        
        # 如果超过2个日志文件，删除最旧的
        if len(log_files) > 2:
            for old_file in log_files[:-2]:
                old_path = os.path.join(self.log_dir, old_file)
                try:
                    os.remove(old_path)
                except Exception as e:
                    print(f"[WARN] 删除旧日志失败: {old_path}, 错误: {e}")
    
    def get_latest_logs(self, count: int = 2):
        """
        获取最新的日志
        
        Args:
            count: 获取的日志数量
        
        Returns:
            日志列表
        """
        log_files = sorted([f for f in os.listdir(self.log_dir) if f.startswith('current_')], reverse=True)
        
        logs = []
        for log_file in log_files[:count]:
            log_path = os.path.join(self.log_dir, log_file)
            try:
                with open(log_path, 'r', encoding='utf-8') as f:
                    logs.append(json.load(f))
            except Exception as e:
                print(f"[WARN] 读取日志失败: {log_path}, 错误: {e}")
        
        return logs
    
    def get_comparison_report(self):
        """
        获取对比报告（当前执行 vs 上一次执行）
        
        Returns:
            对比报告
        """
        logs = self.get_latest_logs(2)
        
        if len(logs) < 2:
            return {'message': '没有足够的日志进行对比'}
        
        current = logs[0]
        previous = logs[1]
        
        report = {
            'current': {
                'task_name': current.get('task_name'),
                'start_time': current.get('start_time'),
                'duration': current.get('duration'),
                'status': current.get('status'),
                'events_count': len(current.get('events', [])),
                'errors_count': len(current.get('errors', []))
            },
            'previous': {
                'task_name': previous.get('task_name'),
                'start_time': previous.get('start_time'),
                'duration': previous.get('duration'),
                'status': previous.get('status'),
                'events_count': len(previous.get('events', [])),
                'errors_count': len(previous.get('errors', []))
            },
            'comparison': {
                'duration_improvement': round(
                    (previous.get('duration', 0) - current.get('duration', 0)) / 
                    (previous.get('duration', 1) or 1) * 100, 2
                ) if previous.get('duration') else 0,
                'status_same': current.get('status') == previous.get('status'),
                'errors_reduced': len(current.get('errors', [])) < len(previous.get('errors', []))
            }
        }
        
        return report


# 全局日志记录器实例
_loggers = {}


def get_logger(module_name: str, log_dir: str = None) -> CoreLogger:
    """
    获取或创建日志记录器
    
    Args:
        module_name: 模块名称
        log_dir: 日志目录
    
    Returns:
        CoreLogger 实例
    """
    if module_name not in _loggers:
        _loggers[module_name] = CoreLogger(module_name, log_dir)
    
    return _loggers[module_name]
