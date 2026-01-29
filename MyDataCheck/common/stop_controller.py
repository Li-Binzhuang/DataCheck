#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
停止控制器模块

功能说明:
    - 提供全局的停止信号控制
    - 支持多任务独立停止
    - 线程安全的停止机制
    - 不影响现有代码逻辑

使用示例:
    # 在执行任务前注册
    >>> from common.stop_controller import StopController
    >>> task_id = StopController.register_task()
    
    # 在任务循环中检查
    >>> for i in range(1000):
    ...     if StopController.should_stop(task_id):
    ...         print("任务被停止")
    ...         break
    ...     # 执行任务
    
    # 任务完成后清理
    >>> StopController.unregister_task(task_id)
    
    # 从外部停止任务
    >>> StopController.stop_task(task_id)

作者: MyDataCheck Team
创建时间: 2026-01-29
"""

import threading
import uuid
from typing import Dict, Optional


class StopController:
    """
    停止控制器（单例模式）
    
    功能:
        - 管理多个任务的停止信号
        - 线程安全
        - 支持任务注册、停止、清理
    
    属性:
        _instance: 单例实例
        _lock: 线程锁
        _tasks: 任务字典 {task_id: stop_flag}
    """
    
    _instance: Optional['StopController'] = None
    _lock = threading.Lock()
    
    def __new__(cls):
        """单例模式：确保只有一个实例"""
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = super().__new__(cls)
                    cls._instance._tasks: Dict[str, bool] = {}
                    cls._instance._task_lock = threading.Lock()
        return cls._instance
    
    @classmethod
    def register_task(cls, task_name: str = None) -> str:
        """
        注册一个新任务
        
        Args:
            task_name: 任务名称（可选），用于标识任务
        
        Returns:
            str: 任务ID（UUID格式）
        
        示例:
            >>> task_id = StopController.register_task("接口对比任务")
            >>> print(task_id)
            'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
        """
        instance = cls()
        task_id = str(uuid.uuid4())
        
        with instance._task_lock:
            instance._tasks[task_id] = False  # False表示未停止
        
        if task_name:
            print(f"[StopController] 任务已注册: {task_name} (ID: {task_id[:8]}...)")
        
        return task_id
    
    @classmethod
    def should_stop(cls, task_id: str) -> bool:
        """
        检查任务是否应该停止
        
        Args:
            task_id: 任务ID
        
        Returns:
            bool: True表示应该停止，False表示继续执行
        
        示例:
            >>> if StopController.should_stop(task_id):
            ...     print("任务被停止")
            ...     break
        """
        instance = cls()
        
        with instance._task_lock:
            return instance._tasks.get(task_id, False)
    
    @classmethod
    def stop_task(cls, task_id: str) -> bool:
        """
        停止指定任务
        
        Args:
            task_id: 任务ID
        
        Returns:
            bool: True表示成功设置停止信号，False表示任务不存在
        
        示例:
            >>> success = StopController.stop_task(task_id)
            >>> if success:
            ...     print("停止信号已发送")
        """
        instance = cls()
        
        with instance._task_lock:
            if task_id in instance._tasks:
                instance._tasks[task_id] = True
                print(f"[StopController] 停止信号已发送: {task_id[:8]}...")
                return True
            else:
                print(f"[StopController] 任务不存在: {task_id[:8]}...")
                return False
    
    @classmethod
    def unregister_task(cls, task_id: str) -> bool:
        """
        注销任务（清理资源）
        
        Args:
            task_id: 任务ID
        
        Returns:
            bool: True表示成功注销，False表示任务不存在
        
        示例:
            >>> StopController.unregister_task(task_id)
        """
        instance = cls()
        
        with instance._task_lock:
            if task_id in instance._tasks:
                del instance._tasks[task_id]
                print(f"[StopController] 任务已注销: {task_id[:8]}...")
                return True
            else:
                return False
    
    @classmethod
    def get_all_tasks(cls) -> Dict[str, bool]:
        """
        获取所有任务的状态
        
        Returns:
            dict: {task_id: stop_flag}
        
        示例:
            >>> tasks = StopController.get_all_tasks()
            >>> for task_id, stopped in tasks.items():
            ...     print(f"{task_id}: {'已停止' if stopped else '运行中'}")
        """
        instance = cls()
        
        with instance._task_lock:
            return instance._tasks.copy()
    
    @classmethod
    def clear_all_tasks(cls):
        """
        清理所有任务（用于测试或重置）
        
        示例:
            >>> StopController.clear_all_tasks()
        """
        instance = cls()
        
        with instance._task_lock:
            instance._tasks.clear()
            print("[StopController] 所有任务已清理")


# 便捷函数（可选）
def create_stop_checker(task_id: str):
    """
    创建一个停止检查函数（闭包）
    
    Args:
        task_id: 任务ID
    
    Returns:
        function: 返回一个无参数的检查函数
    
    示例:
        >>> task_id = StopController.register_task()
        >>> should_stop = create_stop_checker(task_id)
        >>> 
        >>> for i in range(1000):
        ...     if should_stop():
        ...         break
        ...     # 执行任务
    """
    def checker():
        return StopController.should_stop(task_id)
    return checker


if __name__ == "__main__":
    # 测试代码
    print("=== 停止控制器测试 ===\n")
    
    # 测试1: 注册任务
    print("测试1: 注册任务")
    task1 = StopController.register_task("测试任务1")
    task2 = StopController.register_task("测试任务2")
    print(f"任务1 ID: {task1}")
    print(f"任务2 ID: {task2}")
    print()
    
    # 测试2: 检查停止状态
    print("测试2: 检查停止状态")
    print(f"任务1 应该停止吗? {StopController.should_stop(task1)}")
    print(f"任务2 应该停止吗? {StopController.should_stop(task2)}")
    print()
    
    # 测试3: 停止任务1
    print("测试3: 停止任务1")
    StopController.stop_task(task1)
    print(f"任务1 应该停止吗? {StopController.should_stop(task1)}")
    print(f"任务2 应该停止吗? {StopController.should_stop(task2)}")
    print()
    
    # 测试4: 获取所有任务
    print("测试4: 获取所有任务")
    all_tasks = StopController.get_all_tasks()
    for tid, stopped in all_tasks.items():
        print(f"  {tid[:8]}...: {'已停止' if stopped else '运行中'}")
    print()
    
    # 测试5: 注销任务
    print("测试5: 注销任务")
    StopController.unregister_task(task1)
    StopController.unregister_task(task2)
    print(f"剩余任务数: {len(StopController.get_all_tasks())}")
    print()
    
    # 测试6: 便捷函数
    print("测试6: 便捷函数")
    task3 = StopController.register_task("测试任务3")
    should_stop = create_stop_checker(task3)
    print(f"使用便捷函数检查: {should_stop()}")
    StopController.stop_task(task3)
    print(f"停止后检查: {should_stop()}")
    StopController.unregister_task(task3)
    print()
    
    print("=== 测试完成 ===")
