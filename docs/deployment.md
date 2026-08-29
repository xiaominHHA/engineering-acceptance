# 部署

## 已确认原则

- production Compose 只包含 backend、MySQL、MongoDB。
- backend 和数据库只绑定服务器的 `127.0.0.1` 唯一端口。
- MySQL、MongoDB 的管理连接使用 SSH Tunnel，不直接暴露公网。
- 所有生产容器设置资源限制，数据库必须设置最大内存。
- 部署使用显式存在的 Git release tag；服务器 checkout 指定 tag 后执行 Compose build/up 和健康检查。
- 项目不引入 Docker Registry，部署不使用 `latest`。
- Nginx 方案保留为模板，但不假定项目独占 Nginx 或服务器的 80/443。
- `infra/nginx/backend.conf.template` 仅供负责人按确认的三级域名、回环端口和 TLS 路径渲染后使用。
- `deploy.sh <release-tag>` 在本地工作树干净且服务器变量齐全时，令远端 checkout 指定 tag，执行 production Compose build/up 并检查 Actuator；缺少信息时安全拒绝执行。

## 待服务器负责人确认

- SSH 主机、账号及授权方式
- 三级域名
- backend 回环宿主端口
- MySQL、MongoDB 回环宿主端口
- Nginx 管理方式及最终拓扑
- backend、MySQL、MongoDB 的 CPU/内存额度
- 服务器部署目录
- TLS 证书申请、安装及续期方式
- 服务器 Docker Engine 与 Docker Compose 版本

以上信息确认前，不创建真实生产配置、不连接服务器、不部署，也不写入猜测值。
