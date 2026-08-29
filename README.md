# Engineering Acceptance

一个以工程规范和 AI Agent harness 为重点的全栈验收项目。功能和 UI 保持简单，优先保证仓库边界、测试隔离、脚本语义、Docker 安全及设计可解释性。

## 技术栈

- Flutter 3.47.1 / Dart 3.13.1
- Spring Boot 4.1.1 / Java 21.0.12 / Maven Wrapper 3.9.16
- MySQL
- MongoDB
- Docker Compose
- Bash / WSL Ubuntu

## 目录

- `frontend/`：Flutter 轻客户端
- `backend/`：Spring Boot 单体后端
- `infra/`：Compose、环境示例、测试数据和 Nginx 模板
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

五个脚本已实现并由 `./check.sh` 统一执行；`deploy.sh` 只接受明确 release tag，并以该 tag 构建显式版本的生产镜像。

## 当前状态

发布工程已完成：最小用户/个人信息与论坛闭环、GitHub Actions 质量门禁、release 部署和共享 Nginx 接入均已落盘。服务器地址、域名、端口、部署目录和共享 Nginx 拓扑已确认；HTTPS/TLS 仍按负责人方案处理。

MySQL 保存用户账号及个人资料；MongoDB 保存论坛帖子。local Compose 发布三个本地回环服务，test Compose 使用临时隔离数据库和固定初始化数据，production Compose 仅发布 backend、MySQL、MongoDB，并通过回环端口供 SSH Tunnel 管理。

本地启动：复制 `infra/env/local.env.example` 后执行 `docker compose --env-file infra/env/local.env.example -f infra/compose/compose.local.yml up -d --build`。质量门禁依次使用 `./lint.sh`、`./test.sh`、`./build.sh` 或统一执行 `./check.sh`。

Git 工作流为 `main`（发布）、`develop`（集成）和短生命周期 `feat/*`/`release/*` 分支。生产发布使用不可变的 annotated tag，服务器通过只读 Deploy Key checkout 指定 tag。

## 文档

- [架构](docs/architecture.md)
- [开发](docs/development.md)
- [测试](docs/testing.md)
- [部署](docs/deployment.md)
- [AI/Codex 开发规范](AGENTS.md)
