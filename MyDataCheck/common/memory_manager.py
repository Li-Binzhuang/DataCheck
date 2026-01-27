#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
内存管理模块
功能：提供内存监控和释放工具
"""f

import gc
import sys
import psutil
import os
from typing import Optional


class MemoryManager:
    """内存管理器"""
    
    @staticmethod
    def get_memory_usage() -> float:
        """
        获取当前进程的内存使用量（MB）
        
        Returns:
            float: 内存使用量（MB）
        """
        try:
            process = psutil.Process(os.getpid())
            mem_mb = process.memory_info().rss / 1024 / 1024
            return mem_mb
        except Exception:
            return 0.0
    
    @staticmethod
    def print_memory_usage(label: str = ""):
        """
        打印当前内存使用情况
        
        Args:
            label: 标签说明
        """
        mem_mb = MemoryManager.get_memory_usage()
        if label:
            print(f"[内存] {label}: {mem_mb:.2f} MB")
        else:
            print(f"[内存] 当前使用: {mem_mb:.2f} MB")
    
    @staticmethod
    def force_gc():
        """
        强制执行垃圾回收
        
        Returns:
            int: 回收的对象数量
        """
        # 执行三代垃圾回收
        collected = gc.collect(2)
        return collected
    
    @staticmethod
    def clear_variables(*var_names):
        """
        清理指定的变量
        
        Args:
            *var_names: 变量名列表
        """
        frame = sys._getframe(1)
        for var_name in var_names:
            if var_name in frame.f_locals:
                del frame.f_locals[var_name]
    
    @staticmethod
    def cleanup_after_task(verbose: bool = True):
        """
        任务完成后的内存清理
        
        Args:
            verbose: 是否打印详细信息
        
        Returns:
            tuple: (清理前内存, 清理后内存, 释放的内存)
        """
        if verbose:
            mem_before = MemoryManager.get_memory_usage()
            print(f"\n[内存清理] 开始清理...")
            print(f"  清理前: {mem_before:.2f} MB")
        else:
            mem_before = MemoryManager.get_memory_usage()
        
        # 执行垃圾回收
        collected = MemoryManager.force_gc()
        
        if verbose:
            mem_after = MemoryManager.get_memory_usage()
            freed = mem_before - mem_after
            print(f"  清理后: {mem_after:.2f} MB")
            print(f"  释放: {freed:.2f} MB")
            print(f"  回收对象: {collected} 个")
            print(f"[内存清理] 完成")
        else:
            mem_after = MemoryManager.get_memory_usage()
            freed = mem_before - mem_after
        
        return mem_before, mem_after, freed


class MemoryMonitor:
    """内存监控器（上下文管理器）"""
    
    def __init__(self, task_name: str = "任务", verbose: bool = True):
        """
        初始化内存监控器
        
        Args:
            task_name: 任务名称
            verbose: 是否打印详细信息
        """
        self.task_name = task_name
        self.verbose = verbose
        self.start_memory = 0.0
        self.end_memory = 0.0
    
    def __enter__(self):
        """进入上下文"""
        self.start_memory = MemoryManager.get_memory_usage()
        if self.verbose:
            print(f"\n[内存监控] {self.task_name} 开始")
            print(f"  初始内存: {self.start_memory:.2f} MB")
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        """退出上下文"""
        self.end_memory = MemoryManager.get_memory_usage()
        memory_used = self.end_memory - self.start_memory
        
        if self.verbose:
            print(f"\n[内存监控] {self.task_name} 完成")
            print(f"  结束内存: {self.end_memory:.2f} MB")
            print(f"  内存增长: {memory_used:.2f} MB")
        
        # 自动清理
        if self.verbose:
            MemoryManager.cleanup_after_task(verbose=True)
        else:
            MemoryManager.cleanup_after_task(verbose=False)
    
    def checkpoint(self, label: str = "检查点"):
        """
        记录检查点的内存使用
        
        Args:
            label: 检查点标签
        """
        current_memory = MemoryManager.get_memory_usage()
        memory_delta = current_memory - self.start_memory
        if self.verbose:
            print(f"  [{label}] 内存: {current_memory:.2f} MB (增长: {memory_delta:.2f} MB)")


def cleanup_large_objects(*objects):
    """
    清理大对象并释放内存
    
    Args:
        *objects: 要清理的对象
    
    Example:
        cleanup_large_objects(large_list, large_dict, large_dataframe)
    """
    for obj in objects:
        if obj is not None:
            # 如果是列表或字典，先清空
            if isinstance(obj, list):
                obj.clear()
            elif isinstance(obj, dict):
                obj.clear()
            # 删除引用
            del obj
    
    # 强制垃圾回收
    gc.collect()


# 便捷函数
def print_memory(label: str = ""):
    """打印内存使用（便捷函数）"""
    MemoryManager.print_memory_usage(label)


def cleanup():
    """清理内存（便捷函数）"""
    MemoryManager.cleanup_after_task(verbose=False)


def force_cleanup():
    """强制清理内存（便捷函数）"""
    MemoryManager.cleanup_after_task(verbose=True)
