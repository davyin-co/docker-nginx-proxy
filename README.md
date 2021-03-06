# 介绍
[nginx proxy](https://github.com/nginx-proxy/nginx-proxy)的增强，
* 添加了max_client_body_size: 100m。因为在实践中这个值经常需要调整。
* 隐藏nginx版本。

# docker-compose example
```bash
docker network create \
                --driver=bridge \
                --subnet=10.10.255.0/24 \
                --ip-range=10.10.255.0/24 \
                --gateway=10.10.255.254 \
                proxy
```

docker-compose.yml 
```
version: "3"
services:
  nginx-proxy:
    image: "davyinsa/nginx-proxy"
    container_name: proxy
    volumes:
      - /var/run/docker.sock:/tmp/docker.sock:ro
      - ./ssl:/etc/nginx/certs
      - ./vhost:/etc/nginx/vhost.d
      #- ./nginx/custom.conf:/etc/nginx/conf.d/custom.conf
    restart: always
    ports:
      - "80:80"
      - "443:443"
    environment:
      #- HTTPS_METHOD=nohttps
      - ENABLE_IPV6=true
      - HSTS=off
      #- SSL_POLICY=Mozilla-Modern
      - SSL_POLICY=Mozilla-Intermediate
networks:
  default:
    external:
      name: proxy
```

```
docker-compose up -d
```
