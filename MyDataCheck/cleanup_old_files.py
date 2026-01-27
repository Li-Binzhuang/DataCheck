#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
定期清理旧CSV文件
功能：删除 outputdata 和 inputdata 文件夹下超过指定天数的 .csv 文件
"""

import os
import sys
import time
from datetime import datetime, timedelta
from pathlib import Path


class FileCleanup:
    """文件清理器"""
    
    def __init__(self, base_dir: str = None, days_to_keep: int = 5, dry_run: bool = False):
        """
        初始化清理器
        
        Args:
            base_dir: 基础目录（默认为脚本所在目录）
            days_to_keep: 保留最近几天的文件（默认5天）
            dry_run: 是否为试运行模式（只显示不删除）
        """
        self.base_dir = base_dir or os.path.dirname(os.path.abspath(__file__))
        self.days_to_keep = days_to_keep
        self.dry_run = dry_run
        
        # 需要清理的目录
        self.cleanup_dirs = [
            os.path.join(self.base_dir, 'outputdata'),
            os.path.join(self.base_dir, 'inputdata'),
        ]
        
        # 统计信息
        self.stats = {
            'total_scanned': 0,
            'total_deleted': 0,
            'total_size_freed': 0,
            'errors': 0,
        }
    
    def get_file_age_days(self, file_path: str) -> float:
        """
        获取文件的年龄（天数）
        
        Args:
            file_path: 文件路径
        
        Returns:
            文件年龄（天数）
        """
        try:
            # 获取文件修改时间
            mtime = os.path.getmtime(file_path)
            file_time = datetime.fromtimestamp(mtime)
            now = datetime.now()
            age = (now - file_time).total_seconds() / 86400  # 转换为天数
            return age
        except Exception as e:
            print(f"⚠️  获取文件时间失败: {file_path}, 错误: {e}")
            return 0
    
    def format_size(self, size_bytes: int) -> str:
        """
        格式化文件大小
        
        Args:
            size_bytes: 字节数
        
        Returns:
            格式化后的大小字符串
        """
        for unit in ['B', 'KB', 'MB', 'GB']:
            if size_bytes < 1024.0:
                return f"{size_bytes:.2f} {unit}"
            size_bytes /= 1024.0
        return f"{size_bytes:.2f} TB"
    
    def should_delete(self, file_path: str) -> bool:
        """
        判断文件是否应该被删除
        
        Args:
            file_path: 文件路径
        
        Returns:
            是否应该删除
        """
        # 只删除 .csv 文件
        if not file_path.lower().endswith('.csv'):
            return False
        
        # 检查文件年龄
        age_days = self.get_file_age_days(file_path)
        return age_days > self.days_to_keep
    
    def scan_directory(self, directory: str) -> list:
        """
        扫描目录，查找需要删除的文件
        
        Args:
            directory: 目录路径
        
        Returns:
            需要删除的文件列表
        """
        files_to_delete = []
        
        if not os.path.exists(directory):
            print(f"⚠️  目录不存在: {directory}")
            return files_to_delete
        
        print(f"\n📂 扫描目录: {directory}")
        
        # 递归扫描所有子目录
        for root, dirs, files in os.walk(directory):
            for filename in files:
                file_path = os.path.join(root, filename)
                self.stats['total_scanned'] += 1
                
                if self.should_delete(file_path):
                    try:
                        file_size = os.path.getsize(file_path)
                        age_days = self.get_file_age_days(file_path)
                        files_to_delete.append({
                            'path': file_path,
                            'size': file_size,
                            'age_days': age_days,
                        })
                    except Exception as e:
                        print(f"⚠️  获取文件信息失败: {file_path}, 错误: {e}")
                        self.stats['errors'] += 1
        
        return files_to_delete
    
    def delete_file(self, file_info: dict) -> bool:
        """
        删除文件
        
        Args:
            file_info: 文件信息字典
        
        Returns:
            是否删除成功
        """
        file_path = file_info['path']
        
        try:
            if self.dry_run:
                print(f"  [试运行] 将删除: {file_path}")
                print(f"           大小: {self.format_size(file_info['size'])}, 年龄: {file_info['age_days']:.1f} 天")
                return True
            else:
                os.remove(file_path)
                print(f"  ✅ 已删除: {file_path}")
                print(f"           大小: {self.format_size(file_info['size'])}, 年龄: {file_info['age_days']:.1f} 天")
                self.stats['total_deleted'] += 1
                self.stats['total_size_freed'] += file_info['size']
                return True
        except Exception as e:
            print(f"  ❌ 删除失败: {file_path}, 错误: {e}")
            self.stats['errors'] += 1
            return False
    
    def cleanup(self):
        """执行清理"""
        print("=" * 80)
        print("CSV文件清理工具")
        print("=" * 80)
        print(f"保留天数: {self.days_to_keep} 天")
        print(f"运行模式: {'试运行（不会真正删除）' if self.dry_run else '正式运行'}")
        print(f"开始时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        
        # 扫描所有目录
        all_files_to_delete = []
        for directory in self.cleanup_dirs:
            files = self.scan_directory(directory)
            all_files_to_delete.extend(files)
        
        # 显示统计信息
        print(f"\n{'='*80}")
        print(f"扫描完成")
        print(f"{'='*80}")
        print(f"扫描文件总数: {self.stats['total_scanned']}")
        print(f"需要删除的文件: {len(all_files_to_delete)}")
        
        if len(all_files_to_delete) == 0:
            print(f"\n✅ 没有需要删除的文件")
            return
        
        # 计算总大小
        total_size = sum(f['size'] for f in all_files_to_delete)
        print(f"可释放空间: {self.format_size(total_size)}")
        
        # 按年龄排序（最旧的在前）
        all_files_to_delete.sort(key=lambda x: x['age_days'], reverse=True)
        
        # 删除文件
        print(f"\n{'='*80}")
        print(f"开始删除文件")
        print(f"{'='*80}")
        
        for file_info in all_files_to_delete:
            self.delete_file(file_info)
        
        # 最终统计
        print(f"\n{'='*80}")
        print(f"清理完成")
        print(f"{'='*80}")
        print(f"扫描文件总数: {self.stats['total_scanned']}")
        print(f"删除文件数量: {self.stats['total_deleted']}")
        print(f"释放空间大小: {self.format_size(self.stats['total_size_freed'])}")
        print(f"错误数量: {self.stats['errors']}")
        print(f"完成时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"{'='*80}")


def main():
    """主函数"""
    import argparse
    
    parser = argparse.ArgumentParser(description='清理旧的CSV文件')
    parser.add_argument('--days', type=int, default=5, help='保留最近几天的文件（默认5天）')
    parser.add_argument('--dry-run', action='store_true', help='试运行模式（只显示不删除）')
    parser.add_argument('--base-dir', type=str, default=None, help='基础目录（默认为脚本所在目录）')
    
    args = parser.parse_args()
    
    # 创建清理器并执行
    cleaner = FileCleanup(
        base_dir=args.base_dir,
        days_to_keep=args.days,
        dry_run=args.dry_run
    )
    
    cleaner.cleanup()


if __name__ == '__main__':
    main()
