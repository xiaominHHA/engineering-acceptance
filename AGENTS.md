# AGENTS.md

## 1. 项目目标与最高优先级

本仓库用于完成工程化验收项目。重点不是复杂功能或精致 UI，而是证明：

- 仓库结构清晰、职责边界明确；
- Flutter 与 Spring Boot 使用官方标准项目结构；
- Spring Boot、MySQL、MongoDB 通过 Docker 运行；
- MySQL 存储用户/个人信息，MongoDB 存储论坛帖子；
- Bash 脚本统一 lint、test、build、check、deploy；
- 测试使用真实 MySQL/MongoDB 容器和固定、可重复的数据；
- 生产部署考虑共享服务器隔离、资源限制、SSH、Nginx、域名及数据库安全；
- AI 辅助产出的代码、架构和原理最终必须能由开发者解释。

若其他建议、示例项目或 AI 输出与验收要求冲突，以验收要求为准。不得为了“显得高级”增加与验收无关的技术或抽象。

## 2. 固定技术栈

- Frontend：Flutter / Dart
- Backend：Spring Boot / Java 21 / Maven Wrapper
- Relational DB：MySQL
- Document DB：MongoDB
- Container：Docker / Docker Compose
- Environment：WSL Ubuntu
- Scripts：Bash (`.sh`)
- Reverse proxy：共享 `campus-nginx`（仅通过本项目 marker block 接入）
- CI：GitHub Actions（调用仓库统一脚本，不复制另一套规则）

暂不引入：

- 微服务；
- Redis（除非用户明确批准）；
- Kafka、RabbitMQ；
- Keycloak；
- Zipkin、Jaeger、ELK；
- Kubernetes、Helm；
- API Gateway；
- CQRS、Event Sourcing；
- GraphQL、gRPC；
- 复杂 Flutter 状态管理或设计系统。

## 3. 项目结构原则

顶层目录职责：

- `frontend/`：Flutter 轻客户端；
- `backend/`：Spring Boot 单体后端；
- `infra/`：Compose、环境变量示例、测试初始化数据、Nginx 模板；
- `scripts/`：根脚本使用的辅助脚本；
- `docs/`：架构、开发、测试、部署说明；
- `.github/workflows/`：CI；
- `dist/`：构建产物，必须被 Git 忽略。

Flutter 必须使用 `flutter create`，Spring Boot 必须使用 Spring Initializr。不得手工伪造标准项目骨架。

后端业务代码出现后，按“业务模块内聚 + 模块内部标准分层”组织，例如 `user/controller`、`user/service`、`user/repository`、`user/entity`、`user/dto`，以及 `forum/controller`、`forum/service`、`forum/repository`、`forum/document`、`forum/dto`。

- Controller 不直接访问 Repository；
- Service 承担业务逻辑；
- MySQL Entity 与 MongoDB Document 分离；
- 不创建无实际调用方的 BaseService、BaseRepository、通用 DAO、Facade；
- 类和函数保持单一清晰职责；
- 避免跨层调用与循环依赖。

Flutter 保持轻客户端：Page/View 负责展示与输入；Service/Repository 负责 API 访问；不直接连接数据库；不复制后端权威业务规则；不在页面堆积网络、持久化和业务逻辑。

## 4. 数据职责

MySQL 只负责结构化、核心用户数据，例如账号、密码哈希、昵称、生日、学校、班级、创建/更新时间。

MongoDB 只负责论坛文档数据，例如帖子 ID、作者用户 ID、标题、内容、创建/更新时间。MongoDB 只保存关联所需的用户 ID，不复制整份用户资料。

## 5. AI / Codex 工作流

开始任何任务前必须：

1. 执行 `git status`；
2. 阅读根目录 `AGENTS.md`；
3. 阅读与任务相关的 README、docs 和配置；
4. 确认技术栈、目录边界和已有实现；
5. 先说明计划，再做最小范围修改。

修改过程中：

- 不覆盖用户已有的未提交修改；
- 不随意重命名大量文件；
- 不顺手重构无关代码；
- 不自动安装全局依赖；
- 不修改用户的 WSL、Git、Docker 全局配置；
- 不添加需求未证明必要的新框架；
- 不隐藏错误或吞掉底层命令输出；
- 不通过删除/跳过测试或降低规则让检查通过；
- 配置或架构变化必须同步更新文档。

完成任务前必须：

- 运行修改范围对应的最小测试；
- 阶段性交付执行当前阶段已经具备且适用的验证；
- `check.sh` 尚未创建时，不要求执行不存在的脚本；`check.sh` 创建完成后，后续所有可交付阶段必须运行 `./check.sh`；
- 执行 `git diff` 自检；
- 汇报修改文件、执行命令、验证结果和尚未解决的问题或风险。

未适用、尚不存在或未实际执行的检查必须明确记录，不得伪造结果或声称已经测试、通过。

## 6. Git 规范

目标分支模型：

- `main`：可发布、已验收状态；
- `develop`：日常集成；
- `feat/*`：新功能；
- `fix/*`：普通修复；
- `refactor/*`：重构；
- `test/*`：测试调整；
- `docs/*`：文档修改；
- `release/*`：发布准备。

功能从 `develop` 拉短生命周期分支并通过 PR 合入；发布前从 `develop` 拉 `release/*`；release 阶段只做修复、版本和发布准备；稳定后合入 `main` 并打 tag；release 修复同步回 `develop`。

除非用户明确授权，AI 不得执行 `git add`、`git commit`、`git push`、创建/合并 PR、创建/推送 tag、修改远程仓库或远程部署。

## 7. 根目录脚本语义

根目录必须提供 `lint.sh`、`test.sh`、`build.sh`、`check.sh`、`deploy.sh`。

所有 Shell 脚本必须使用 Bash 和 `set -Eeuo pipefail`，从自身位置解析仓库根目录，失败返回非零退出码，不静默安装依赖，不做宽泛清理，正确引用变量，并通过 ShellCheck。

### `lint.sh`

只做静态质量检查，不运行测试或生成正式产物。必须覆盖：

- `dart format --output=none --set-exit-if-changed`；
- `flutter analyze --fatal-warnings --fatal-infos`；
- Java Checkstyle / 静态检查和 warning 策略；
- ShellCheck；
- 三套 Compose 配置解析；
- `.java` / `.dart` 单文件不超过 800 行；
- 基础 secret 扫描。

项目自身 warning 按规则视为失败。

### `test.sh`

只负责自动化测试。每次必须创建独立、唯一的 test Compose project 和新 volumes，并启动真实 MySQL、MongoDB。MySQL schema 由 `backend/src/main/resources/db/migration/V1__create_users_table.sql` 等 Flyway migration 创建；migration 完成后，Spring 测试框架通过 `backend/src/test/resources/mysql-fixture.sql` 插入固定 MySQL fixture；MongoDB 继续由 `infra/test/mongo/init.js` 初始化固定 fixture。等待数据库健康后运行 Spring Boot 单元测试、真实数据库集成测试和 Flutter test；最终只清理本次 project、network、containers、volumes。禁止连接 local/production，禁止宽泛 Docker 清理。mock 不能替代真实数据库集成测试。

### `build.sh`

只生成：

- `dist/frontend/app-release.apk`；
- `dist/backend/<artifactId>-<version>.jar`。

不负责 Docker image、部署、Git tag 或 push。

### `check.sh`

作为本地、Codex、CI 共用的唯一质量门禁，依次执行 `lint.sh`、`test.sh`、`build.sh`，任一步失败立即停止。仅在 `./check.sh` 全部通过后，当前状态才可称为可交付。

### `deploy.sh`

只部署一个显式指定且已存在的 release tag；不使用 latest；不自动创建或 push tag；不自动修改 DNS、防火墙或 TLS 账户；不执行数据库破坏性清理或宽泛 Docker prune。

生产使用共享 `campus-nginx`，共享配置路径已明确。部署脚本只管理带本项目 BEGIN/END marker 的 `wm7023` server block，不得修改其他项目配置块。修改宿主 `nginx.conf` 前必须创建备份，并在原 inode 上原位写入；随后校验 host/container marker、SHA-256、`nginx -t` 以及 `nginx -T` 中的本项目 server block。只有全部验证成功才能 graceful reload；失败时在宿主原 inode 上 rollback。脚本不得 restart/recreate 共享 Nginx；若 host/container SHA 不一致等 bind-mount 状态异常，必须安全停止并要求人工检查。

推荐链路：本地 `./check.sh` 通过 → 明确 release tag → 服务器 fetch/checkout 指定 tag → production Compose build/up → health check。

## 8. Docker / Compose 规范

通用要求：

- 不设置固定 `container_name`；
- 容器间通过 Compose service name 通信；
- local、test、production 使用不同 project name、network、volume；
- 配置健康检查；
- 不硬编码真实凭据；
- 镜像版本明确，生产不依赖 latest；
- 禁止操作与本项目无关的容器、网络或 volumes。

Local：backend、mysql、mongodb 全部通过 Docker 运行；宿主访问只绑定 `127.0.0.1`；使用独立 local volumes；Flutter 不进入 Compose。

Test：每次创建新数据库容器和 volumes；数据库不发布宿主端口；初始化数据固定可重复；测试结束精确清理本次资源。

Production：运行 backend、mysql、mongodb；共享 `campus-nginx` 通过 `wm7023-edge` 和唯一 alias `wm7023-backend` 反向代理 backend，MySQL/MongoDB 不加入 edge network。backend 只绑定分配的 loopback 宿主端口；MySQL/MongoDB 只绑定 `127.0.0.1` 的唯一端口供 SSH Tunnel，数据库不得暴露公网。backend、MySQL、MongoDB 的已确认内存上限分别为 `512m`、`384m`、`256m`；使用独立 production volumes；秘密来自服务器环境；设置日志轮转；local/test 不得引用 production project 或 volumes。

## 9. Secret 与安全规范

不得提交 `.env`、私钥、SSH key、TLS 私钥/证书密钥、真实数据库密码、token、AccessKey/SecretKey、生产连接串或生产数据库备份。只允许提交 `.example` 配置文件。

日志不得输出密码、token、私钥或完整敏感个人信息。生产数据库管理必须通过 SSH Tunnel 或负责人批准的安全方式，不直接开放公网端口。

## 10. CI 规范

GitHub Actions 只负责 checkout、准备固定版本环境、调用 `./check.sh`，需要时上传 `dist/`。CI 不复制 lint/test/build 命令。本地、Codex、CI 共用同一质量门禁。

## 11. 文档规范

`README.md` 只做项目入口：项目目标、技术栈、目录导航、统一命令、当前状态和 docs 链接。详细内容放在 `docs/architecture.md`、`docs/development.md`、`docs/testing.md`、`docs/deployment.md`。

文档只描述真实、已验证的工程状态。服务器 IP、端口、域名、Nginx 拓扑、CPU/内存额度、TLS 方式未确认时必须标记“待确认”，不得编造。

## 12. Definition of Done

一个阶段只有同时满足以下条件才能标记完成：

- 代码/配置实际落盘；
- 对应静态检查通过；
- 对应测试通过；
- 必要构建成功；
- 文档与真实实现一致；
- 没有已知 secret 泄露；
- 没有破坏 local/test/production 隔离；
- `git diff` 已自检；
- 已执行当前阶段已经具备且适用的验证；
- `check.sh` 创建完成后，阶段性交付运行 `./check.sh` 成功；在其尚未创建前，不要求执行不存在的 `check.sh`；
- 未适用、尚不存在或未执行的检查已明确记录，没有伪造验证结果。

“文件已生成”“看起来正确”或“AI 认为没有问题”都不等于完成。
