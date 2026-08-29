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

五个脚本已实现并由 `./check.sh` 统一执行；`deploy.sh` 目前只做 release tag 和待确认服务器配置校验，不执行远程部署。

## 当前状态

Stage 3 已完成 Docker Compose 三环境、固定测试数据、真实数据库集成测试和根目录质量门禁。尚未实现登录、个人信息或论坛业务，也未创建 CI 或配置 Nginx。服务器连接信息、三级域名、宿主端口、Nginx 管理方式、容器资源额度、部署目录和 TLS 管理方式均待服务器负责人确认。

## 文档

- [架构](docs/architecture.md)
- [开发](docs/development.md)
- [测试](docs/testing.md)
- [部署](docs/deployment.md)
- [AI/Codex 开发规范](AGENTS.md)
