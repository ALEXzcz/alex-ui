# 运行阶段基础镜像
FROM nginx:1.25.2
# 挂载站点配置文件，覆盖 nginx 默认站点配置
COPY default.conf /etc/nginx/conf.d/default.conf
# 把 CI 阶段生成的 dist/ 放到 nginx 默认静态目录
COPY dist/ /usr/share/nginx/html/
