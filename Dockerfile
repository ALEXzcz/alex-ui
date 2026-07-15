FROM nginxinc/nginx-unprivileged:1.25-alpine

ARG APP_NAME=alex-ui
ARG BUILD_TIME
ARG IMAGE_VERSION
ARG VCS_REF
ARG VCS_URL
ARG VCS_BRANCH

LABEL org.opencontainers.image.title="${APP_NAME}" \
      org.opencontainers.image.description="alex-ui frontend service" \
      org.opencontainers.image.version="${IMAGE_VERSION}" \
      org.opencontainers.image.created="${BUILD_TIME}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.source="${VCS_URL}" \
      org.opencontainers.image.ref.name="${VCS_BRANCH}"

USER root

RUN mkdir -p /usr/share/nginx/html /etc/nginx/conf.d /tmp/nginx \
    && chown -R nginx:nginx /usr/share/nginx/html /etc/nginx/conf.d /tmp/nginx

# 挂载站点配置文件，覆盖 nginx 默认站点配置
COPY --chown=nginx:nginx default.conf /etc/nginx/conf.d/default.conf
# 把 CI 阶段生成的 dist/ 放到 nginx 默认静态目录
COPY --chown=nginx:nginx dist/ /usr/share/nginx/html/

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD busybox wget -q -O /dev/null http://127.0.0.1:8080/alex/ || exit 1

USER nginx
