# 部署

## 已确认原则

- production Compose 只包含 backend、MySQL、MongoDB。
- backend 和数据库只绑定服务器的 `127.0.0.1` 唯一端口。
- MySQL、MongoDB 的管理连接使用 SSH Tunnel，不直接暴露公网。
- 所有生产容器设置资源限制，数据库必须设置最大内存。
- 部署使用显式存在的 Git release tag；服务器 checkout 指定 tag 后执行 Compose build/up 和健康检查。
- 项目不引入 Docker Registry，部署不使用 `latest`。
- Nginx 方案保留为模板，但不假定项目独占 Nginx 或服务器的 80/443。
- `infra/nginx/backend.conf.template` 当前提供已确认域名的 HTTP 反代模板；HTTPS/TLS 后续按服务器负责人方案处理。
- `deploy.sh <release-tag>` 在本地工作树干净且服务器变量齐全时，令远端 checkout 指定 tag，执行 production Compose build/up 并检查 Actuator；缺少信息时安全拒绝执行。
- 当前服务器已确认：`ubuntu@106.53.116.230`，部署目录 `/home/ubuntu/engineering-acceptance-wm7023`；backend/MySQL/MongoDB 分别使用 `127.0.0.1:18023/13323/27023`，内存上限为 `512m/384m/256m`。
- backend 同时加入应用内部网络 `wm7023-internal` 和共享边缘网络 `wm7023-edge`，并以唯一 alias `wm7023-backend` 接入共享 `campus-nginx`；数据库只加入内部网络。
- 共享 Nginx 配置位于 `/home/ubuntu/dsl_campus/docker/nginx/nginx.conf`，部署脚本仅替换带有本项目专属标记的配置块；修改前创建备份，先执行 `nginx -t`，仅成功后 reload，失败恢复原配置。

## 仍待确认

- TLS 证书路径、申请、安装及续期方式
- 服务器 Docker Engine 与 Docker Compose 版本

以上仍待确认项解决前，不连接服务器、不部署，也不写入生产 secret。
