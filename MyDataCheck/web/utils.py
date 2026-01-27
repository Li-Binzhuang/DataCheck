#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Web应用工具函数模块

功能说明:
    - 捕获和重定向标准输出
    - 生成流式响应（SSE格式）
    - 支持实时输出显示

作者: MyDataCheck Team
创建时间: 2026-01
最后更新: 2026-01-27
"""

import sys
from queue import Queue


class OutputCapture:
    """
    输出捕获类
    
    功能:
        捕获print()输出和标准错误输出，并将其发送到队列中
        用于在Web界面实时显示后台任务的执行日志
    
    属性:
        output_queue (Queue): 输出队列，用于存储捕获的输出
        original_stdout: 原始标准输出流
        original_stderr: 原始标准错误流
        buffer (str): 输出缓冲区
    
    使用示例:
        >>> from queue import Queue
        >>> output_queue = Queue()
        >>> capture = OutputCapture(output_queue)
        >>> sys.stdout = capture
        >>> print("Hello")  # 输出会被捕获到队列中
        >>> sys.stdout = capture.original_stdout  # 恢复原始输出
    """
    
    def __init__(self, output_queue: Queue):
        """
        初始化输出捕获器
        
        Args:
            output_queue (Queue): 用于存储捕获输出的队列
        """
        self.output_queue = output_queue
        self.original_stdout = sys.stdout
        self.original_stderr = sys.stderr
        self.buffer = ""
    
    def write(self, text):
        """
        写入文本到捕获器
        
        该方法会被print()函数调用，用于捕获输出
        
        Args:
            text (str): 要写入的文本
        
        处理逻辑:
            1. 将文本写入原始输出（保持控制台显示）
            2. 将文本添加到缓冲区
            3. 遇到换行符时，将完整行发送到队列
        """
        # 保存到原始输出（控制台仍然可以看到输出）
        self.original_stdout.write(text)
        self.original_stdout.flush()
        
        # 添加到缓冲区
        self.buffer += text
        
        # 如果遇到换行符，发送完整行到队列
        if '\n' in self.buffer:
            lines = self.buffer.split('\n')
            # 保留最后不完整的行在缓冲区
            self.buffer = lines[-1]
            # 发送完整的行到队列
            for line in lines[:-1]:
                self.output_queue.put(line)
    
    def flush(self):
        """
        刷新缓冲区
        
        将缓冲区中剩余的内容发送到队列
        该方法在输出流关闭时自动调用
        """
        self.original_stdout.flush()
        # 发送缓冲区中剩余的内容
        if self.buffer:
            self.output_queue.put(self.buffer)
            self.buffer = ""


def stream_response_generator(output_queue: Queue, thread):
    """
    生成流式响应（SSE格式）
    
    功能:
        从输出队列中读取数据，并生成Server-Sent Events (SSE)格式的响应
        用于在Web界面实时显示后台任务的执行进度
    
    Args:
        output_queue (Queue): 输出队列，包含要发送的消息
        thread (Thread): 执行任务的线程对象
    
    Yields:
        str: SSE格式的数据行，格式为 "data: {json}\n\n"
    
    消息类型:
        - start: 任务开始
        - output: 任务输出（日志）
        - error: 错误信息
        - end: 任务结束
    
    使用示例:
        >>> from threading import Thread
        >>> from queue import Queue
        >>> output_queue = Queue()
        >>> thread = Thread(target=some_task, args=(output_queue,))
        >>> thread.start()
        >>> for data in stream_response_generator(output_queue, thread):
        ...     print(data)  # 发送到客户端
    
    Note:
        - 该函数是一个生成器，用于Flask的流式响应
        - 客户端需要使用EventSource API接收SSE消息
        - 队列中的None值表示任务结束
    """
    import json
    
    # 发送开始消息
    yield f"data: {json.dumps({'type': 'start', 'message': '开始执行...'})}\n\n"
    
    # 实时读取输出队列
    while True:
        try:
            # 从队列获取输出（阻塞等待，最多1秒）
            try:
                line = output_queue.get(timeout=1)
            except:
                # 检查线程是否还在运行
                if not thread.is_alive():
                    # 线程已结束，读取剩余输出
                    remaining = []
                    while not output_queue.empty():
                        try:
                            remaining.append(output_queue.get_nowait())
                        except:
                            break
                    # 发送剩余输出
                    for item in remaining:
                        if item is None:
                            break
                        yield f"data: {json.dumps({'type': 'output', 'message': str(item)})}\n\n"
                    break
                continue
            
            # None表示任务结束
            if line is None:
                break
            
            # 发送输出消息
            yield f"data: {json.dumps({'type': 'output', 'message': str(line)})}\n\n"
        except Exception as e:
            # 发送错误消息
            yield f"data: {json.dumps({'type': 'error', 'message': f'输出错误: {str(e)}'})}\n\n"
            break
    
    # 发送结束消息
    yield f"data: {json.dumps({'type': 'end', 'message': '执行完成'})}\n\n"
