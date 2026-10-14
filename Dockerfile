# ============================================================
# Docker 部署: 容器内用 busybox crond 做定时, 每天 07:00 (Asia/Shanghai)
# ------------------------------------------------------------
# 构建: docker build -t weather-push:1.0 .
# 运行: docker run -d --name weather-push \
#         --env-file .env \          # 密钥通过环境变量注入, 不进镜像层
#         -v /etc/localtime:/etc/localtime:ro \  # 可选: 与宿主时区对齐
#         weather-push:1.0
# 调试: docker run --rm --env-file .env weather-push:1.0 node src/index.js --dry-run
# 日志: docker logs -f weather-push
# ============================================================
FROM node:20-alpine

# 1) 设置时区（alpine 必须额外安装 tzdata）
ENV TZ=Asia/Shanghai
RUN apk add --no-cache tzdata \
 && cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
 && echo "Asia/Shanghai" > /etc/timezone

WORKDIR /app

# 2) 依赖: 零第三方包, 这里只是把 package.json 带上以便未来扩展
COPY package.json ./
RUN npm install --omit=dev --ignore-scripts || true

# 3) 源码（注意: 刻意不 COPY .env, 避免密钥被打进镜像层）
COPY src/ ./src/
RUN mkdir -p /app/logs

# 4) 容器内 crontab: 每天 07:00 执行, 输出重定向便于 docker logs 查看
RUN printf '%s\n' \
  'TZ=Asia/Shanghai' \
  '0 7 * * * cd /app && /usr/local/bin/node src/index.js >> /app/logs/cron.out 2>&1' \
  > /etc/crontabs/root

# 5) 前台运行 crond（-f 前台, -l 2 日志级别）
CMD ["crond", "-f", "-l", "2"]
