FROM nginxproxy/nginx-proxy
RUN { \
      echo 'server_tokens off;'; \
      echo 'client_max_body_size 100m;'; \
      echo 'proxy_buffer_size 256k;'; \
      echo 'proxy_buffers 4 256k;'; \
      echo 'proxy_busy_buffers_size 256k;'; \
      echo 'proxy_hide_header X-Generator;'; \
      echo 'client_header_buffer_size 64k;'; \
      echo 'large_client_header_buffers 4 64k;'; \
    } > /etc/nginx/conf.d/my_proxy.conf
