# 部署

## 已确认原则

- production Compose 只包含 backend、MySQL、MongoDB。
- backend 和数据库只绑定服务器的 `127.0.0.1` 唯一端口。
- MySQL、MongoDB 的管理连接使用 SSH Tunnel，不直接暴露公网。
- 所有生产容器设置资源限制，数据库必须设置最大内存。
- 部署使用显式存在的 Git release tag；服务器 checkout 指定 tag 后执行 Compose build/up 和健康检查。
- 项目不引入 Docker Registry；production backend 镜像以 release tag 显式命名，不依赖 `latest`。镜像通过多阶段 Dockerfile 从服务器 checkout 的 tag 源码构建，runtime image 不复用服务器旧 JAR。
- MySQL schema 只由 backend 内随 release 发布的 Flyway migration 管理；生产使用 `baseline-on-migrate=false`，Hibernate 使用 `ddl-auto=validate`。涉及 MySQL schema migration 的生产发布，在执行 `deploy.sh` 前，发布流程必须先完成本项目 MySQL 的逻辑备份；`deploy.sh` 本身不自动执行数据库备份。部署不删除 production volume，也不使用 Docker init SQL 修改已有生产 schema。
- 本项目 Nginx server block 以 `infra/nginx/backend.conf.template` 维护，并接入共享 `campus-nginx`；当前模板提供已确认域名的 HTTP 反代配置。项目不独占共享 Nginx 或服务器的 80/443，HTTPS/TLS 后续按服务器负责人方案处理。
- `deploy.sh <release-tag>` 在本地工作树干净且服务器变量齐全时，令远端 checkout 指定 tag，执行 production Compose build/up 并检查 Actuator；缺少信息时安全拒绝执行。
- 当前服务器已确认：`ubuntu@106.53.116.230`，部署目录 `/home/ubuntu/engineering-acceptance-wm7023`；backend/MySQL/MongoDB 分别使用 `127.0.0.1:18023/13323/27023`，内存上限为 `512m/384m/256m`。
- backend 同时加入应用内部网络 `wm7023-internal` 和共享边缘网络 `wm7023-edge`，并以唯一 alias `wm7023-backend` 接入共享 `campus-nginx`；数据库只加入内部网络。
- 共享 Nginx 配置位于 `/home/ubuntu/dsl_campus/docker/nginx/nginx.conf`。部署脚本仅更新带有本项目专属标记的配置块，并保持配置文件原 inode、owner、group 和 mode；修改前创建备份，同时验证宿主与容器配置 marker/SHA-256 及 `nginx -T` 有效配置。仅在 `nginx -t` 成功后 reload，失败时原位恢复备份。

## 仍待确认

- TLS 证书路径、申请、安装及续期方式
- 公网 IPv6 路由需要从具备 IPv6 的外部客户端完成最终验证

生产 secret 仅保存在服务器 `/home/ubuntu/.config/engineering-acceptance/production.env`，权限必须为 `600`，其内容不进入 Git 或部署日志。
