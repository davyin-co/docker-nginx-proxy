# syntax=docker/dockerfile:1
# CVE-2026-123007 修复版：基于官方 nginx:1.31.9（≥1.31.9 已修复 HTTP/2 漏洞）
# 注意：固定版本号，升级时手动修改并重建

FROM nginxproxy/nginx-proxy:1.11 AS upstream

FROM nginx:1.31.9

# nginx-proxy 运行组件（模板 / entrypoint / 进程管理器 / 二进制 / 主配置）
# 上游 nginxproxy/nginx-proxy 尚未发布基于修复版 nginx 的构建（见 nginxproxy/nginx-proxy#...），
# 故直接取官方修复版 nginx 基础镜像 + 上游运行组件自行组装
COPY --from=upstream /app /app
COPY --from=upstream /usr/local/bin/docker-gen /usr/local/bin/docker-gen
COPY --from=upstream /usr/local/bin/forego /usr/local/bin/forego
COPY --from=upstream /etc/nginx/nginx.conf /etc/nginx/nginx.conf

# entrypoint 需要的路径 + 加载官方 geoip 动态模块
RUN mkdir -p /etc/nginx/dhparam /etc/nginx/certs /usr/share/geoip \
    && sed -i '1iload_module /usr/lib/nginx/modules/ngx_http_geoip_module.so;' /etc/nginx/nginx.conf

# GeoLite2 数据库（官方 geoip 模块自 nginx 1.31.7 起原生支持 MaxMind DB / MMDB 格式，
# 无需再编译第三方 ngx_http_geoip2_module）
RUN apt-get update \
    && apt-get install -y --no-install-recommends wget \
    && wget -O /usr/share/geoip/GeoLite2-Country.mmdb https://github.com/P3TERX/GeoLite.mmdb/raw/download/GeoLite2-Country.mmdb \
    && wget -O /usr/share/geoip/GeoLite2-City.mmdb https://github.com/P3TERX/GeoLite.mmdb/raw/download/GeoLite2-City.mmdb \
    && apt-get purge -y wget && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

COPY rootfs/etc/nginx/conf.d/my_proxy.conf /etc/nginx/conf.d/my_proxy.conf
COPY rootfs/etc/nginx/conf.d/geoip.conf /etc/nginx/conf.d/geoip.conf
COPY rootfs/usr/share/nginx/html/errors/ /usr/share/nginx/html/errors/
ADD https://raw.githubusercontent.com/h5bp/server-configs-nginx/main/h5bp/web_performance/compression.conf /etc/nginx/conf.d/compression-gzip.conf

EXPOSE 80
WORKDIR /app
ENV DOCKER_HOST=unix:///tmp/docker.sock \
    NGINX_PROXY_VERSION=1.11.6 \
    DOCKER_GEN_VERSION=0.17.2
ENTRYPOINT ["/app/docker-entrypoint.sh"]
CMD ["forego", "start", "-r"]
