# 多阶段: 安装 tencent-channel-cli + 运行 api_server
FROM python:3.12-slim

# 安装 node (cli 依赖 node 运行时)
RUN apt-get update && apt-get install -y nodejs npm && rm -rf /var/lib/apt/lists/*
RUN npm install -g tencent-channel-cli

WORKDIR /app
COPY . /app

# 默认允许本地回环调试; 部署时通过环境变量/挂载卷提供登录态
CMD ["python", "api_server.py"]
