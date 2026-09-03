# 部署

## 已确认原则

- production Compose 只包含 backend、MySQL、MongoDB。
- backend 和数据库只绑定服务器的 `127.0.0.1` 唯一端口。
- MySQL、MongoDB 的管理连接使用 SSH Tunnel，不直接暴露公网。
- 本项目公网只使用共享入口的 80/443 和服务器 SSH 22；不对本项目 backend 或数据库增加公网监听，此约束不用于判断服务器上其他项目的端口。
- 所有生产容器设置资源限制，数据库必须设置最大内存。
- 部署使用显式存在的 Git release tag；服务器 checkout 指定 tag 后执行 Compose build/up 和健康检查。
- 项目不引入 Docker Registry；production backend 镜像以 release tag 显式命名，不依赖 `latest`。镜像通过多阶段 Dockerfile 从服务器 checkout 的 tag 源码构建，runtime image 使用专用非 root 用户运行且不复用服务器旧 JAR。
- Git annotated tag 是 release identity 的唯一来源；deploy 将去掉 `v` 的版本和准确 commit/build time 传入 Maven 与 Docker，镜像包含 OCI version/revision/created labels，Actuator `/actuator/info` 只公开 build name/version/time/commit。
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

## 当前生产版本

当前 server backend 运行 build commit `614830ba79a66943940985206a3fd5ffe17c3704`，bearer auth、完整 Forum V1 API、删除权限和昵称 enrichment 已完成实际 API smoke。仓库现有正式 release tag 为不可变的 `v1.1.0`；当前长期 production ingress 仍为 HTTP，临时 Web preview 的 HTTPS Tunnel 不等同于永久 TLS 上线。

## 数据库管理

数据库宿主端口只绑定 loopback，管理时通过 SSH Tunnel 转发到开发机，并使用官方客户端；命令中的端口、主机和用户均为占位值：

```bash
# MySQL
ssh -L <local-mysql-port>:127.0.0.1:<server-mysql-loopback-port> ubuntu@<server>
mysql -h 127.0.0.1 -P <local-mysql-port> -u <mysql-user> -p <database>

# MongoDB
ssh -L <local-mongo-port>:127.0.0.1:<server-mongo-loopback-port> ubuntu@<server>
mongosh 'mongodb://127.0.0.1:<local-mongo-port>/<database>' --username <mongo-user> --authenticationDatabase <auth-database>
```

密码、private key 和 production env 不写入命令示例、仓库或日志；服务器上不安装第三方数据库 GUI。新 production 配置要求 `MONGO_APP_USERNAME`/`MONGO_APP_PASSWORD`，应用用户只拥有目标 database 的 `readWrite`；root 仅用于管理和部署时通过官方 `mongosh` 幂等创建或校正该用户。existing volume 不依赖 entrypoint init 重跑，fresh deploy 同样先建立应用用户再启动 backend。数据库 restore 尚未经过隔离演练，不以 restart persistence 代替恢复验证。

## Authentication rollout

Secured backend 已启用，受保护接口以 bearer principal 为唯一身份来源。旧 APK 不理解新的 AuthResponse，也不发送 bearer token，因此其资料写入和发帖会返回 401；应使用 `v1.1.0` 或更新客户端，不能为旧客户端永久保留匿名写接口。

## HTTPS migration prerequisite

正式迁移顺序固定为：复用共享服务器既有证书管理方式完成 TLS → 验证域名、证书链和有效期及 HTTP 跳转 → 将 `build.sh` 默认 URL 切到 HTTPS并移除 release cleartext 例外 → 使用稳定 keystore 构建并安装 HTTPS APK → 最后才部署 secured backend。debug/integration test 仍通过 debug 专用配置访问 localhost/`10.0.2.2` HTTP。

## 临时 Flutter Web preview

Web demo 使用 `infra/compose/compose.web-preview.yml` 启动项目专属 Caddy gateway：静态文件与 `/api/*`、`/actuator/*` 共用一个 origin，gateway 仅绑定 `127.0.0.1:18024` 并通过 `wm7023-edge` 访问 `wm7023-backend:8080`。Cloudflare Quick Tunnel 为该 loopback gateway 提供临时 HTTPS URL，因此无需 backend CORS；随机 URL 不提交 Git，也不作为永久 production ingress。此 preview 不读取或修改共享 `campus-nginx` 配置。
