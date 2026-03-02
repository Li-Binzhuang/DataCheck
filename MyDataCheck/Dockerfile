# MyDataCheck Docker镜像
# Python 3.12 + Flask Web应用

# 使用阿里云镜像源（国内网络更稳定）
FROM registry.cn-hangzhou.aliyuncs.com/library/python:3.12-slim

# 设置工作目录
WORKDIR /app

# 设置环境变量
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONWARNINGS="ignore::Warning" \
    SERVER_HOST=0.0.0.0 \
    SERVER_PORT=5001 \
    CLEANUP_RETENTION_DAYS=3 \
    DISABLE_OPEN_FOLDER=1

# 配置pip使用国内镜像源
RUN pip config set global.index-url https://mirrors.aliyun.com/pypi/simple/ \
    && pip config set global.trusted-host mirrors.aliyun.com

# 安装系统依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# 复制依赖文件
COPY requirements.txt .

# 安装Python依赖
RUN pip install --no-cache-dir -r requirements.txt

# 复制项目文件
COPY . .

# 创建数据目录
RUN mkdir -p inputdata/api_comparison inputdata/data_comparison inputdata/online_comparison \
    outputdata/api_comparison outputdata/data_comparison outputdata/online_comparison \
    outputdata/performance_test outputdata/progress_test logs

# 暴露端口
EXPOSE 5001

# 启动命令
CMD ["python", "web/app.py"]
