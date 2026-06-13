# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目性质

这是 [nginxproxy/nginx-proxy](https://github.com/nginx-proxy/nginx-proxy) 的**定制化 Docker 镜像**项目（基于 davyinsa fork），并扩展了带 ModSecurity/CRS WAF 防护的变体。所有内容都是围绕两个 `Dockerfile` 构建镜像的配置。

## 镜像变体

- `Dockerfile` — 主镜像：在官方 `nginxproxy/nginx-proxy` 之上编译并集成 `ngx_http_geoip2_module`，使用 GeoLite2 数据库。
- `Dockerfile-crs` — WAF 变体：基于 `owasp/modsecurity-crs:nginx-alpine`，叠加 s6-overlay + docker-gen，并将镜像标签打为 `:crs`。

两个镜像都会被 CI 推送到 Docker Hub（`davyinsa/nginx-proxy` / `:crs`）和阿里云容器镜像服务（`registry.cn-hangzhou.aliyuncs.com/davyin/nginx-proxy` / `:crs`）。

## 架构概览

```
Dockerfile       ── 基于 nginxproxy/nginx-proxy
                   ├─ 多阶段构建：builder 阶段从源码编译 ngx_http_geoip2_module.so
                   └─ 运行阶段：注入 my_proxy.conf + geoip2.conf + h5bp gzip 配置

Dockerfile-crs   ── 基于 owasp/modsecurity-crs:nginx-alpine
                   ├─ 复制 shinsenter/s6-overlay 作为 init 系统
                   ├─ 复制 nginxproxy/docker-gen 用于自动发现后端容器
                   ├─ 复制 nginx-proxy 1.2.3 的 nginx.tmpl
                   └─ 用 rootfs 覆盖默认配置（含自定义 5XX 错误页）

rootfs/          ── 覆盖到最终镜像的文件系统
  ├─ etc/nginx/conf.d/my_proxy.conf        全局调优（client_max_body_size=1024m、隐藏 X-Generator、超时/缓冲区参数）
  ├─ etc/nginx/conf.d/geoip2.conf          GeoIP2 变量映射 + real_ip 提取
  ├─ etc/nginx/templates/conf.d/custom.conf.template  模板：每个后端 vhost 自动应用的配置（100m body size 版本）
  ├─ etc/cont-init.d/10-rm-crs-container-default-server.sh  启动时删除 CRS 基础镜像自带的 default server
  ├─ etc/services.d/nginx-entrypoint/run   s6 服务：拉起 nginx 前台进程
  ├─ etc/services.d/dockergen/run          s6 服务：用 sed 修补 nginx.tmpl 后启动 docker-gen 监听容器事件触发 reload
  └─ usr/share/nginx/html/errors/50x.html  自定义 5XX 错误页（中文/英文双语切换）

ssl/, vhost/     ── 运行时挂载点（存放 TLS 证书与 vhost 自定义片段，初始为空）
```

### 关键设计点

- **GeoIP2 通过动态模块注入**：`Dockerfile` 用多阶段构建在 `nginxproxy/nginx-proxy` 之上重新编译动态模块，再在最终阶段 `sed` 注入 `load_module` 到 `/etc/nginx/nginx.conf` 顶部。修改 GeoIP 版本只需改 `GEOIP2_VERSION` 环境变量。
- **CRS 变体的 template 修补**：`dockergen/run` 在启动前用 `sed` 删掉 `nginx.tmpl` 中的 `RESOLVERS` 块、`error_log /dev/stderr`、`access_log off` 三段——这些是 CRS 基础镜像里的兼容问题，删除后才能与本项目的日志环境变量配合。
- **my_proxy.conf vs custom.conf.template**：`my_proxy.conf` 是全局配置（1024m body size），`custom.conf.template` 是 per-vhost 模板（100m body size），两者 body size 不同是有意为之——全局兜底大，per-vhost 默认小。
- **GitHub Actions 定时触发**：`schedule: cron: '30 2 * * *'` 每天凌晨 2:30 自动重建镜像（用于更新 GeoLite2 数据库）。

## 常用命令

### 构建镜像

```bash
# 主镜像
docker build -t davyinsa/nginx-proxy -f Dockerfile .

# WAF 变体
docker build -t davyinsa/nginx-proxy:crs -f Dockerfile-crs .
```

### 本地运行（需要外部 proxy 网络）

```bash
docker network create --driver=bridge --subnet=10.10.255.0/24 \
  --ip-range=10.10.255.0/24 --gateway=10.10.255.254 proxy

docker-compose up -d   # 使用仓库根目录的 docker-compose.yml
```

### 自定义配置后重新构建

任何 `rootfs/` 下的文件被修改后，必须重新 `docker build`（没有开发态热重载）：

- 改 nginx 全局配置 → 编辑 `rootfs/etc/nginx/conf.d/my_proxy.conf`
- 改 GeoIP 变量 → 编辑 `rootfs/etc/nginx/conf.d/geoip2.conf`
- 改 5XX 错误页 → 编辑 `rootfs/usr/share/nginx/html/errors/50x.html`
- 改 vhost 模板默认 body size 等 → 编辑 `rootfs/etc/nginx/templates/conf.d/custom.conf.template`
- 改 GeoIP 模块版本 → 调整 `Dockerfile` 顶部的 `GEOIP2_VERSION`

### 验证镜像内容

```bash
# 进入镜像检查配置
docker run --rm -it davyinsa/nginx-proxy sh
# 查看最终 nginx.conf
docker run --rm davyinsa/nginx-proxy cat /etc/nginx/nginx.conf | head -20
```

## CI/CD

`.github/workflows/docker-publish.yml` 在 push 到 main/master、手动触发、每天凌晨 2:30 触发。**不支持多架构以外的本地测试**——所有构建在 GitHub Actions 上完成（linux/amd64, linux/arm64）。本地构建不会推送到任何仓库。

需要新镜像标签时修改 workflow 文件中的 `tags:` 字段；多仓库凭据在 GitHub Secrets 中以 `DOCKERHUB_*` 和 `ALIYUNCR_*` 形式存储。

## 注意事项

- 这是 Docker 镜像项目，**没有单元测试或 lint 配置**——所有"测试"都是镜像构建成功即通过。
- `rootfs/etc/services.d/dockergen/run` 中的 `sed` 修补**硬编码**针对 nginx-proxy 1.2.3 的 `nginx.tmpl`；上游该文件结构变更时这些 sed 表达式需要更新。
- 修改 `Dockerfile` 后务必本地构建一次再 push：CI 失败会导致多架构镜像不一致。
- `ssl/` 和 `vhost/` 目录在仓库里是空的占位符，运行时由用户挂载，不要把证书提交进仓库。
