# 文件上传大小限制修复说明

## 问题
上传文件时提示：`413 Request Entity Too Large`

## 已完成的修复
✅ 已将文件上传大小限制从 1GB 提升到 10GB
✅ Web服务已重启，配置已生效

修改文件：`MyDataCheck/web/config.py`
```python
MAX_CONTENT_LENGTH = 10 * 1024 * 1024 * 1024  # 10GB
```

## 服务状态
✅ Web服务正在运行
✅ 访问地址: http://127.0.0.1:5001
✅ 文件上传限制: 10.00 GB

## 验证步骤

1. 访问 http://127.0.0.1:5001
2. 进入"数据对比"模块
3. 尝试上传大文件（1.42GB应该可以成功）
4. 如果仍然失败，请检查浏览器控制台的错误信息

## 如果仍然出现413错误

### 可能的原因：

1. **浏览器缓存**
   - 清除浏览器缓存
   - 使用隐私/无痕模式重新访问

2. **Nginx反向代理限制**
   如果使用了Nginx，需要修改配置：
   ```nginx
   http {
       client_max_body_size 10G;
   }
   ```
   然后重启Nginx：
   ```bash
   sudo nginx -t
   sudo nginx -s reload
   ```

3. **网络超时**
   - 大文件上传需要较长时间
   - 确保网络连接稳定
   - 可以尝试分批上传或压缩文件

## 手动重启服务（如需要）

```bash
cd MyDataCheck

# 查找进程
ps aux | grep web_app.py

# 停止进程
kill -9 <进程ID>

# 重新启动（使用虚拟环境）
source .venv/bin/activate
python3 web_app.py
```

## 注意事项

- ✅ 当前限制：10GB
- ⚠️ 上传大文件需要时间，请耐心等待
- ⚠️ 确保服务器有足够的磁盘空间
- ⚠️ 上传过程中不要关闭浏览器页面
