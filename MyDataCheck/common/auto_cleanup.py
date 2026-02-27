#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
自动清理模块

功能说明:
    - 定期清理 inputdata、outputdata、logs 目录中的旧文件
    - 在 Web 应用启动时自动执行
    - 支持配置保留天数

作者: MyDataCheck Team
创建时间: 2026-02-27
"""

import os
import time
import threading
from datetime import datetime, timedelta
from typing import List, Tuple


class AutoCleanup:
    """
    自动清理管理器
    
    功能:
        - 清理指定目录中超过保留天数的文件
        - 支持排除特定文件（如 README.md）
        - 记录清理日志
    """
    
    # 默认配置
    DEFAULT_RETENTION_DAYS = 7  # 默认保留7天
    EXCLUDED_FILES = {'.DS_Store', 'README.md', '.gitkeep', '__init__.py'}  # 排除的文件
    
    # 需要清理的目录（相对于 MyDataCheck 目录）
    CLEANUP_DIRS = [
        'inputdata/api_comparison',
        'inputdata/data_comparison', 
        'inputdata/online_comparison',
        'outputdata/api_comparison',
        'outputdata/data_comparison',
        'outputdata/online_comparison',
        'outputdata/performance_test',
        'outputdata/progress_test',
        'logs',
    ]
    
    _cleanup_done = False  # 标记是否已执行过清理
    _lock = threading.Lock()
    
    @classmethod
    def cleanup_old_files(cls, retention_days: int = None, verbose: bool = True) -> Tuple[int, int]:
        """
        清理旧文件
        
        Args:
            retention_days: 保留天数，默认7天
            verbose: 是否打印详细日志
        
        Returns:
            Tuple[int, int]: (删除的文件数, 释放的空间大小bytes)
        """
        if retention_days is None:
            retention_days = cls.DEFAULT_RETENTION_DAYS
        
        # 计算截止时间
        cutoff_time = time.time() - (retention_days * 24 * 60 * 60)
        cutoff_date = datetime.now() - timedelta(days=retention_days)
        
        deleted_count = 0
        freed_space = 0
        
        # 获取项目根目录
        base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        
        if verbose:
            print(f"\n[AutoCleanup] 开始清理 {retention_days} 天前的文件...")
            print(f"[AutoCleanup] 截止日期: {cutoff_date.strftime('%Y-%m-%d %H:%M:%S')}")
        
        for dir_path in cls.CLEANUP_DIRS:
            full_path = os.path.join(base_dir, dir_path)
            
            if not os.path.exists(full_path):
                continue
            
            dir_deleted, dir_freed = cls._cleanup_directory(
                full_path, cutoff_time, verbose
            )
            deleted_count += dir_deleted
            freed_space += dir_freed
        
        if verbose:
            freed_mb = freed_space / (1024 * 1024)
            print(f"[AutoCleanup] 清理完成: 删除 {deleted_count} 个文件, 释放 {freed_mb:.2f} MB")
        
        return deleted_count, freed_space
    
    @classmethod
    def _cleanup_directory(cls, dir_path: str, cutoff_time: float, verbose: bool) -> Tuple[int, int]:
        """
        清理单个目录
        
        Args:
            dir_path: 目录路径
            cutoff_time: 截止时间戳
            verbose: 是否打印详细日志
        
        Returns:
            Tuple[int, int]: (删除的文件数, 释放的空间大小bytes)
        """
        deleted_count = 0
        freed_space = 0
        
        try:
            for filename in os.listdir(dir_path):
                # 跳过排除的文件
                if filename in cls.EXCLUDED_FILES:
                    continue
                
                file_path = os.path.join(dir_path, filename)
                
                # 跳过目录（不递归删除子目录）
                if os.path.isdir(file_path):
                    continue
                
                try:
                    # 获取文件修改时间
                    file_mtime = os.path.getmtime(file_path)
                    
                    # 如果文件超过保留期限，删除
                    if file_mtime < cutoff_time:
                        file_size = os.path.getsize(file_path)
                        os.remove(file_path)
                        deleted_count += 1
                        freed_space += file_size
                        
                        if verbose:
                            mtime_str = datetime.fromtimestamp(file_mtime).strftime('%Y-%m-%d')
                            print(f"  删除: {filename} (修改于 {mtime_str})")
                            
                except (OSError, IOError) as e:
                    if verbose:
                        print(f"  跳过: {filename} (错误: {e})")
                        
        except Exception as e:
            if verbose:
                print(f"[AutoCleanup] 清理目录失败 {dir_path}: {e}")
        
        return deleted_count, freed_space
    
    @classmethod
    def startup_cleanup(cls, retention_days: int = None):
        """
        启动时清理（只执行一次）
        
        Args:
            retention_days: 保留天数
        """
        with cls._lock:
            if cls._cleanup_done:
                return
            cls._cleanup_done = True
        
        # 在后台线程执行清理，不阻塞启动
        def do_cleanup():
            try:
                cls.cleanup_old_files(retention_days, verbose=True)
            except Exception as e:
                print(f"[AutoCleanup] 启动清理失败: {e}")
        
        thread = threading.Thread(target=do_cleanup, daemon=True)
        thread.start()
    
    @classmethod
    def get_cleanup_stats(cls) -> dict:
        """
        获取各目录的文件统计信息
        
        Returns:
            dict: 各目录的文件数量和大小统计
        """
        base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        stats = {}
        
        for dir_path in cls.CLEANUP_DIRS:
            full_path = os.path.join(base_dir, dir_path)
            
            if not os.path.exists(full_path):
                stats[dir_path] = {'files': 0, 'size': 0}
                continue
            
            file_count = 0
            total_size = 0
            
            try:
                for filename in os.listdir(full_path):
                    if filename in cls.EXCLUDED_FILES:
                        continue
                    
                    file_path = os.path.join(full_path, filename)
                    if os.path.isfile(file_path):
                        file_count += 1
                        total_size += os.path.getsize(file_path)
            except Exception:
                pass
            
            stats[dir_path] = {
                'files': file_count,
                'size': total_size,
                'size_mb': round(total_size / (1024 * 1024), 2)
            }
        
        return stats


# 便捷函数
def startup_cleanup(retention_days: int = 7):
    """Web应用启动时调用"""
    AutoCleanup.startup_cleanup(retention_days)


def manual_cleanup(retention_days: int = 7) -> Tuple[int, int]:
    """手动触发清理"""
    return AutoCleanup.cleanup_old_files(retention_days, verbose=True)


if __name__ == "__main__":
    # 测试代码
    print("=== 自动清理模块测试 ===\n")
    
    # 显示当前统计
    print("当前文件统计:")
    stats = AutoCleanup.get_cleanup_stats()
    for dir_path, info in stats.items():
        print(f"  {dir_path}: {info['files']} 个文件, {info['size_mb']} MB")
    
    print("\n执行清理（7天前的文件）:")
    deleted, freed = manual_cleanup(7)
    print(f"\n总计: 删除 {deleted} 个文件, 释放 {freed / (1024*1024):.2f} MB")
