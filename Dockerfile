FROM nginxproxy/nginx-proxy AS builder

ENV GEOIP2_VERSION=3.4

# 安装编译依赖并编译 GeoIP2 模块
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpcre3-dev \
    zlib1g-dev \
    libgeoip-dev \
    libmaxminddb-dev \
    wget \
    git \
    && cd /opt \
    && git clone --depth 1 -b $GEOIP2_VERSION --single-branch https://github.com/leev/ngx_http_geoip2_module.git \
    && wget -O - http://nginx.org/download/nginx-$NGINX_VERSION.tar.gz | tar xzf - \
    && cd nginx-$NGINX_VERSION \
    && ./configure --with-compat --add-dynamic-module=/opt/ngx_http_geoip2_module \
    && make modules

# 最终镜像
FROM nginxproxy/nginx-proxy

# 复制编译好的模块
COPY --from=builder /opt/nginx-*/objs/ngx_http_geoip2_module.so /usr/lib/nginx/modules/

# 安装运行时依赖并下载 GeoIP 数据库
RUN apt-get update \
    && apt-get install -y --no-install-recommends libmaxminddb0 wget \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && chmod 644 /usr/lib/nginx/modules/ngx_http_geoip2_module.so \
    && sed -i '1iload_module /usr/lib/nginx/modules/ngx_http_geoip2_module.so;' /etc/nginx/nginx.conf \
    && mkdir -p /usr/share/geoip \
    && wget -O /usr/share/geoip/GeoLite2-Country.mmdb https://github.com/P3TERX/GeoLite.mmdb/raw/download/GeoLite2-Country.mmdb \
    && wget -O /usr/share/geoip/GeoLite2-City.mmdb https://github.com/P3TERX/GeoLite.mmdb/raw/download/GeoLite2-City.mmdb

COPY rootfs/etc/nginx/conf.d/my_proxy.conf /etc/nginx/conf.d/my_proxy.conf
COPY rootfs/etc/nginx/conf.d/geoip2.conf /etc/nginx/conf.d/geoip2.conf
ADD https://raw.githubusercontent.com/h5bp/server-configs-nginx/main/h5bp/web_performance/compression.conf /etc/nginx/conf.d/compression-gzip.conf
