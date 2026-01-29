#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
任务状态管理器模块

功能说明:
    - 管理任务状态和进度
    - 保存任务输出日志
    - 支持任务恢复和查询
    - 线程安全

使用示例:
    # 创建任务
    >>> from common.task_manager import TaskManager
    >>> task_id = TaskManager.create_task("接口数据对比", "api_comparison")
    
    # 更新任务状态
    >>> TaskManager.update_task(task_id, status="running", progress=50)
    
    # 添加日志
    >>> TaskManager.add_log(task_id, "正在处理第100行...")
    
    # 查询任务
    >>> task_info = TaskManager.get_task(task_id)
    >>> print(task_info['status'])  # running
    
    # 获取日志
    >>> logs = TaskManager.get_logs(task_id, last_n=100)

作者: MyDataCheck Team
创建时间: 2026-01-29
"""

import threading
import uuid
import json
import os
from datetime import datetime
from typing import Dict, List, Optional, Any
from collections import deque


class TaskManager:
    """
    任务状态管理器（单例模式）
    
    功能:
        - 管理任务状态（创建、运行、完成、失败、停止）
        - 保存任务输出日志（内存缓存 + 文件持久化）
        - 支持任务查询和恢复
        - 线程安全
    
    任务状态:
        - pending: 等待执行
        - running: 执行中
        - completed: 已完成
        - failed: 失败
        - stopped: 已停止
    """
    
    _instance: Optional['TaskManager'] = None
    _lock = threading.Lock()
    
    # 日志配置
    MAX_MEMORY_LOGS = 1000  # 内存中保存的最大日志条数
    LOG_DIR = "MyDataCheck/logs/tasks"  # 日志文件目录
    
    def __new__(cls):
        """单例模式：确保只有一个实例"""
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = super().__new__(cls)
                    cls._instance._tasks: Dict[str, Dict[str, Any]] = {}
                    cls._instance._logs: Dict[str, deque] = {}
                    cls._instance._task_lock = threading.Lock()
                    cls._instance._ensure_log_dir()
        return cls._instance
    
    def _ensure_log_dir(self):
        """确保日志目录存在"""
        if not os.path.exists(self.LOG_DIR):
            os.makedirs(self.LOG_DIR, exist_ok=True)
    
    @classmethod
    def create_task(cls, task_name: str, task_type: str = "unknown") -> str:
        """
        创建一个新任务
        
        Args:
            task_name: 任务名称
            task_type: 任务类型（api_comparison, data_comparison等）
        
        Returns:
            str: 任务ID
        """
        instance = cls()
        task_id = str(uuid.uuid4())
        
        task_info = {
            'task_id': task_id,
            'task_name': task_name,
            'task_type': task_type,
            'status': 'pending',
            'progress': 0,
            'total': 0,
            'current_step': '',
            'created_at': datetime.now().isoformat(),
            'started_at': None,
            'completed_at': None,
            'error_message': None,
            'output_files': []
        }
        
        with instance._task_lock:
            instance._tasks[task_id] = task_info
            instance._logs[task_id] = deque(maxlen=cls.MAX_MEMORY_LOGS)
        
        # 保存任务信息到文件
        instance._save_task_info(task_id)
        
        print(f"[TaskManager] 任务已创建: {task_name} (ID: {task_id[:8]}...)")
        return task_id
    
    @classmethod
    def update_task(cls, task_id: str, **kwargs) -> bool:
        """
        更新任务信息
        
        Args:
            task_id: 任务ID
            **kwargs: 要更新的字段
                - status: 任务状态
                - progress: 当前进度
                - total: 总数
                - current_step: 当前步骤描述
                - error_message: 错误信息
                - output_files: 输出文件列表
        
        Returns:
            bool: 是否更新成功
        """
        instance = cls()
        
        with instance._task_lock:
            if task_id not in instance._tasks:
                return False
            
            task = instance._tasks[task_id]
            
            # 更新字段
            for key, value in kwargs.items():
                if key in task:
                    task[key] = value
            
            # 自动设置时间戳
            if 'status' in kwargs:
                if kwargs['status'] == 'running' and task['started_at'] is None:
                    task['started_at'] = datetime.now().isoformat()
                elif kwargs['status'] in ['completed', 'failed', 'stopped']:
                    task['completed_at'] = datetime.now().isoformat()
        
        # 保存到文件
        instance._save_task_info(task_id)
        return True
    
    @classmethod
    def add_log(cls, task_id: str, message: str, level: str = "info") -> bool:
        """
        添加任务日志
        
        Args:
            task_id: 任务ID
            message: 日志消息
            level: 日志级别（info, warning, error, success）
        
        Returns:
            bool: 是否添加成功
        """
        instance = cls()
        
        with instance._task_lock:
            if task_id not in instance._logs:
                return False
            
            log_entry = {
                'timestamp': datetime.now().isoformat(),
                'level': level,
                'message': message
            }
            
            # 添加到内存
            instance._logs[task_id].append(log_entry)
        
        # 追加到文件
        instance._append_log_to_file(task_id, log_entry)
        return True
    
    @classmethod
    def get_task(cls, task_id: str) -> Optional[Dict[str, Any]]:
        """
        获取任务信息
        
        Args:
            task_id: 任务ID
        
        Returns:
            dict: 任务信息，如果不存在返回None
        """
        instance = cls()
        
        with instance._task_lock:
            return instance._tasks.get(task_id, None)
    
    @classmethod
    def get_logs(cls, task_id: str, last_n: int = None, from_file: bool = False) -> List[Dict[str, Any]]:
        """
        获取任务日志
        
        Args:
            task_id: 任务ID
            last_n: 获取最后N条日志（None表示全部）
            from_file: 是否从文件读取（True=文件，False=内存）
        
        Returns:
            list: 日志列表
        """
        instance = cls()
        
        if from_file:
            # 从文件读取
            return instance._read_logs_from_file(task_id, last_n)
        else:
            # 从内存读取
            with instance._task_lock:
                if task_id not in instance._logs:
                    return []
                
                logs = list(instance._logs[task_id])
                if last_n is not None:
                    logs = logs[-last_n:]
                return logs
    
    @classmethod
    def get_all_tasks(cls, status: str = None) -> List[Dict[str, Any]]:
        """
        获取所有任务
        
        Args:
            status: 过滤状态（None表示全部）
        
        Returns:
            list: 任务列表
        """
        instance = cls()
        
        with instance._task_lock:
            tasks = list(instance._tasks.values())
            
            if status:
                tasks = [t for t in tasks if t['status'] == status]
            
            # 按创建时间倒序
            tasks.sort(key=lambda x: x['created_at'], reverse=True)
            return tasks
    
    @classmethod
    def delete_task(cls, task_id: str) -> bool:
        """
        删除任务（清理资源）
        
        Args:
            task_id: 任务ID
        
        Returns:
            bool: 是否删除成功
        """
        instance = cls()
        
        with instance._task_lock:
            if task_id in instance._tasks:
                del instance._tasks[task_id]
            if task_id in instance._logs:
                del instance._logs[task_id]
        
        # 删除日志文件
        instance._delete_log_file(task_id)
        instance._delete_task_file(task_id)
        
        print(f"[TaskManager] 任务已删除: {task_id[:8]}...")
        return True
    
    @classmethod
    def cleanup_completed_task_logs(cls, task_id: str, keep_summary: bool = True) -> bool:
        """
        清理已完成任务的日志（保留任务信息）
        
        Args:
            task_id: 任务ID
            keep_summary: 是否保留摘要信息（默认True）
        
        Returns:
            bool: 是否清理成功
        """
        instance = cls()
        
        with instance._task_lock:
            # 检查任务是否存在且已完成
            if task_id not in instance._tasks:
                return False
            
            task = instance._tasks[task_id]
            if task['status'] not in ['completed', 'failed', 'stopped']:
                print(f"[TaskManager] 任务未完成，不清理日志: {task_id[:8]}...")
                return False
            
            # 清理内存中的日志
            if task_id in instance._logs:
                if keep_summary:
                    # 保留最后10条日志作为摘要
                    logs = list(instance._logs[task_id])
                    summary_logs = logs[-10:] if len(logs) > 10 else logs
                    instance._logs[task_id] = deque(summary_logs, maxlen=cls.MAX_MEMORY_LOGS)
                else:
                    # 完全清空
                    instance._logs[task_id].clear()
        
        # 删除日志文件
        instance._delete_log_file(task_id)
        
        # 如果保留摘要，重新写入摘要日志
        if keep_summary:
            with instance._task_lock:
                if task_id in instance._logs:
                    for log in instance._logs[task_id]:
                        instance._append_log_to_file(task_id, log)
        
        print(f"[TaskManager] 任务日志已清理: {task_id[:8]}... (保留摘要: {keep_summary})")
        return True
    
    @classmethod
    def cleanup_old_tasks(cls, days: int = 7, status_filter: List[str] = None) -> int:
        """
        清理N天前的旧任务
        
        Args:
            days: 清理多少天前的任务
            status_filter: 只清理指定状态的任务（None表示全部）
        
        Returns:
            int: 清理的任务数量
        """
        instance = cls()
        
        from datetime import datetime, timedelta
        cutoff_time = datetime.now() - timedelta(days=days)
        
        tasks_to_delete = []
        
        with instance._task_lock:
            for task_id, task in instance._tasks.items():
                # 检查创建时间
                created_at = datetime.fromisoformat(task['created_at'])
                if created_at < cutoff_time:
                    # 检查状态过滤
                    if status_filter is None or task['status'] in status_filter:
                        tasks_to_delete.append(task_id)
        
        # 删除任务
        deleted_count = 0
        for task_id in tasks_to_delete:
            if cls.delete_task(task_id):
                deleted_count += 1
        
        print(f"[TaskManager] 清理了 {deleted_count} 个 {days} 天前的任务")
        return deleted_count
    
    @classmethod
    def delete_task(cls, task_id: str) -> bool:
        """
        删除任务（清理资源）
        
        Args:
            task_id: 任务ID
        
        Returns:
            bool: 是否删除成功
        """
        instance = cls()
        
        with instance._task_lock:
            if task_id in instance._tasks:
                del instance._tasks[task_id]
            if task_id in instance._logs:
                del instance._logs[task_id]
        
        # 删除日志文件
        instance._delete_log_file(task_id)
        instance._delete_task_file(task_id)
        
        print(f"[TaskManager] 任务已删除: {task_id[:8]}...")
        return True
    
    def _save_task_info(self, task_id: str):
        """保存任务信息到文件"""
        try:
            task_file = os.path.join(self.LOG_DIR, f"{task_id}_info.json")
            with open(task_file, 'w', encoding='utf-8') as f:
                json.dump(self._tasks[task_id], f, ensure_ascii=False, indent=2)
        except Exception as e:
            print(f"[TaskManager] 保存任务信息失败: {e}")
    
    def _append_log_to_file(self, task_id: str, log_entry: Dict[str, Any]):
        """追加日志到文件"""
        try:
            log_file = os.path.join(self.LOG_DIR, f"{task_id}_logs.jsonl")
            with open(log_file, 'a', encoding='utf-8') as f:
                f.write(json.dumps(log_entry, ensure_ascii=False) + '\n')
        except Exception as e:
            print(f"[TaskManager] 保存日志失败: {e}")
    
    def _read_logs_from_file(self, task_id: str, last_n: int = None) -> List[Dict[str, Any]]:
        """从文件读取日志"""
        try:
            log_file = os.path.join(self.LOG_DIR, f"{task_id}_logs.jsonl")
            if not os.path.exists(log_file):
                return []
            
            logs = []
            with open(log_file, 'r', encoding='utf-8') as f:
                for line in f:
                    if line.strip():
                        logs.append(json.loads(line))
            
            if last_n is not None:
                logs = logs[-last_n:]
            return logs
        except Exception as e:
            print(f"[TaskManager] 读取日志失败: {e}")
            return []
    
    def _delete_log_file(self, task_id: str):
        """删除日志文件"""
        try:
            log_file = os.path.join(self.LOG_DIR, f"{task_id}_logs.jsonl")
            if os.path.exists(log_file):
                os.remove(log_file)
        except Exception as e:
            print(f"[TaskManager] 删除日志文件失败: {e}")
    
    def _delete_task_file(self, task_id: str):
        """删除任务信息文件"""
        try:
            task_file = os.path.join(self.LOG_DIR, f"{task_id}_info.json")
            if os.path.exists(task_file):
                os.remove(task_file)
        except Exception as e:
            print(f"[TaskManager] 删除任务文件失败: {e}")


if __name__ == "__main__":
    # 测试代码
    print("=== 任务管理器测试 ===\n")
    
    # 测试1: 创建任务
    print("测试1: 创建任务")
    task_id = TaskManager.create_task("测试任务", "test")
    print(f"任务ID: {task_id}\n")
    
    # 测试2: 更新任务状态
    print("测试2: 更新任务状态")
    TaskManager.update_task(task_id, status="running", progress=0, total=100)
    print("任务状态已更新为 running\n")
    
    # 测试3: 添加日志
    print("测试3: 添加日志")
    TaskManager.add_log(task_id, "开始执行任务", "info")
    TaskManager.add_log(task_id, "处理第10行", "info")
    TaskManager.add_log(task_id, "处理第20行", "info")
    TaskManager.add_log(task_id, "发现警告", "warning")
    TaskManager.add_log(task_id, "处理第30行", "info")
    print("已添加5条日志\n")
    
    # 测试4: 获取任务信息
    print("测试4: 获取任务信息")
    task_info = TaskManager.get_task(task_id)
    print(f"任务名称: {task_info['task_name']}")
    print(f"任务状态: {task_info['status']}")
    print(f"任务进度: {task_info['progress']}/{task_info['total']}\n")
    
    # 测试5: 获取日志
    print("测试5: 获取日志（内存）")
    logs = TaskManager.get_logs(task_id, last_n=3)
    for log in logs:
        print(f"  [{log['level']}] {log['message']}")
    print()
    
    # 测试6: 从文件读取日志
    print("测试6: 获取日志（文件）")
    logs = TaskManager.get_logs(task_id, from_file=True)
    print(f"文件中共有 {len(logs)} 条日志\n")
    
    # 测试7: 完成任务
    print("测试7: 完成任务")
    TaskManager.update_task(task_id, status="completed", progress=100)
    TaskManager.add_log(task_id, "任务执行完成", "success")
    print("任务已完成\n")
    
    # 测试8: 获取所有任务
    print("测试8: 获取所有任务")
    all_tasks = TaskManager.get_all_tasks()
    print(f"共有 {len(all_tasks)} 个任务\n")
    
    # 测试9: 删除任务
    print("测试9: 删除任务")
    TaskManager.delete_task(task_id)
    print("任务已删除\n")
    
    print("=== 测试完成 ===")
