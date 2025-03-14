FROM nginxproxy/nginx-proxy
RUN { \
      echo 'server_tokens off;'; \
      echo 'client_max_body_size 1024m;'; \
      echo 'proxy_buffer_size 256k;'; \
      echo 'proxy_buffers 4 256k;'; \
      echo 'proxy_busy_buffers_size 256k;'; \
      echo 'proxy_hide_header X-Generator;'; \
      echo 'client_header_buffer_size 64k;'; \
      echo 'large_client_header_buffers 4 64k;'; \
      echo 'proxy_connect_timeout 300;'; \
      echo 'proxy_send_timeout  300;'; \
      echo 'proxy_read_timeout  300;'; \
      echo 'send_timeout 300;'; \
    } > /etc/nginx/conf.d/my_proxy.conf
ADD https://raw.githubusercontent.com/h5bp/server-configs-nginx/main/h5bp/web_performance/compression.conf /etc/nginx/conf.d/compression-gzip.conf
