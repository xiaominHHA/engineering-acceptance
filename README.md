# Engineering Acceptance

一个以工程规范和 AI Agent harness 为重点的全栈验收项目。功能和 UI 保持简单，优先保证仓库边界、测试隔离、脚本语义、Docker 安全及设计可解释性。

## 技术栈

- Flutter 3.47.1 / Dart 3.13.1
- Spring Boot 4.1.1 / Java 21 / Maven 3.9.16（通过 Maven Wrapper 3.3.4）
- MySQL
- MongoDB
- Docker Compose
- Bash / WSL Ubuntu

## 目录

- `frontend/`：Flutter 轻客户端
- `backend/`：Spring Boot 单体后端
- `infra/`：Compose、环境示例、MongoDB 测试数据和 Nginx 模板
- `scripts/`：根目录脚本的辅助实现
- `docs/`：架构、开发、测试和部署说明
- `dist/`：本地正式构建产物，不进入 Git

## 统一命令

工程基线完成后统一使用：

```bash
./lint.sh
./test.sh
./build.sh
./check.sh
./deploy.sh <release-tag>
```

五个脚本均已实现；`./check.sh` 依次执行 `lint.sh`、`test.sh` 和 `build.sh`，`deploy.sh` 仅在明确指定 release tag 时单独执行。

## 当前状态

工程基线包含最小用户/个人信息与论坛闭环、短期 bearer token 身份边界、安全会话恢复、作者昵称和自有帖子删除、GitHub Actions 质量门禁、release 部署及共享 Nginx 接入。服务器地址、域名、端口、部署目录和共享 Nginx 拓扑已确认；HTTPS/TLS 切换仍以共享基础设施证书就绪为前置条件。

MySQL 保存用户账号及个人资料；MongoDB 保存论坛帖子。MySQL schema 在所有环境中只由 Flyway 版本化 migration 管理，Hibernate 只负责校验。local Compose 发布三个本地回环服务，test Compose 使用临时隔离数据库。production Compose 包含 backend、MySQL、MongoDB，三者宿主端口均只绑定 `127.0.0.1`；MySQL/MongoDB 的 loopback 端口用于 SSH Tunnel 管理，公网业务流量通过共享 `campus-nginx` 进入 backend，本项目不额外暴露 backend 或数据库公网端口。

本地 demo 可直接使用仓库中的 `infra/env/local.env.example`：执行 `docker compose --env-file infra/env/local.env.example -f infra/compose/compose.local.yml up -d --build`。质量门禁依次使用 `./lint.sh`、`./test.sh`、`./build.sh` 或统一执行 `./check.sh`。正式 APK 必须使用仓库外的稳定 keystore；配置见 [本地开发](docs/development.md)。TLS 尚未就绪期间，`./build.sh` 默认连接当前 HTTP 生产域名；证书验证通过后按 [部署文档](docs/deployment.md) 切换为 HTTPS并移除 release cleartext 例外。

Git 工作流为 `main`（发布）、`develop`（集成）和短生命周期 `feat/*`/`release/*` 分支。生产发布使用不可变的 annotated tag，tag 是 release 版本的唯一来源：同一版本进入 Android versionName/versionCode、Maven/JAR、Docker tag/OCI labels 和 CI artifact 名，产物同时记录 commit SHA 和构建时间。

## 文档

- [架构](docs/architecture.md)
- [开发](docs/development.md)
- [测试](docs/testing.md)
- [部署](docs/deployment.md)
- [AI/Codex 开发规范](AGENTS.md)
