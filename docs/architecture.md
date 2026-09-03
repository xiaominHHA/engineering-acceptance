# 架构

## 已确认边界

- `frontend/` 是 Flutter 轻客户端，只通过 HTTP API 访问后端。
- `backend/` 是单体 Spring Boot 应用，统一承载 API 和业务规则。
- MySQL 只保存账号和个人信息等结构化核心用户数据。
- MongoDB 保存帖子、评论和点赞关系；文档仅保存关联用户 ID，不复制用户资料。
- Spring Boot、MySQL、MongoDB 在 local、test、production 中均通过 Docker 运行。
- 不引入微服务、Redis、消息队列、独立认证服务或分布式追踪系统。

## 当前实现

- `frontend/` 由 Flutter 3.47.1 的 `flutter create` 创建，包含 Android 与官方 Web scaffolding。Auth、Profile、Forum 按 feature 组织，依赖方向固定为 Page → ChangeNotifier ViewModel → Repository → ApiClient；页面不直接处理 HTTP status，ApiClient 不包含业务模型或 UI 文案。
- Web 未显式注入 `API_BASE_URL` 时使用 `Uri.base.origin`，使静态页面和 `/api` 保持同源；Android 继续使用构建期 `API_BASE_URL`，debug 默认访问 emulator host。
- Flutter project name 为 `engineering_acceptance_app`，Android applicationId 为 `com.campusmeow.acceptance.app`。
- `backend/` 由官方 Spring Initializr 创建，使用 Spring Boot 4.1.1、Java 21 和 Maven Wrapper。
- 后端依赖包含 Web MVC、Validation、Actuator、Spring Security Resource Server、JPA、MySQL Driver、MongoDB、Flyway 和测试支持。
- 后端入口类为 `com.campusmeow.acceptance.EngineeringAcceptanceApplication`。
- `user/` 模块负责 MySQL 用户与个人资料，`forum/` 模块负责 MongoDB 帖子、评论和点赞；Controller 通过 Service 访问各自 Repository，响应 DTO 不暴露密码哈希。
- 后端通过小型业务异常和全局 REST advice 返回稳定的 `code`、`message`、`fieldErrors` 错误 contract；Service 不使用 HTTP 异常表达业务错误。
- 注册和登录返回短期 HS256 bearer token 与当前用户。token 仅包含 user subject、签发/过期时间，签名密钥来自环境且不进入 Git；Flutter 通过 `flutter_secure_storage` 保存必要 session，启动时验证未过期 token，401 或显式退出会同时清除内存与持久化 session。服务端保持无状态，不提供 refresh token。
- `GET/PUT /api/users/{id}` 要求 token subject 与 path id 一致，匿名访问返回 401、跨用户访问返回 403。帖子/评论写操作和点赞使用 authenticated principal；只有作者可删除自己的帖子或评论。帖子列表、详情和评论保持匿名可读。
- `GET /api/posts` 和评论列表使用有上限的数组分页；点赞通过 `(postId,userId)` 唯一索引保持幂等。帖子统计按当前页批量查询 MongoDB，帖子和评论昵称按唯一用户 ID 批量读取 MySQL，避免逐条 N+1。
- Flutter Auth 拆分 LoginPage/LoginViewModel 与 RegisterPage/RegisterViewModel；Forum 使用单一 `ForumRepository`，feed 和详情各自拥有小型 ViewModel。
- rollout 期间 Flutter 发帖请求仍携带旧 `v1.0.10` 所需的 `authorUserId`；新后端兼容接收但不使用该字段授权或决定作者，实际作者始终来自 authenticated principal。旧后端退役后应删除这一临时请求字段。

MySQL schema 的唯一 owner 是 `backend/src/main/resources/db/migration/` 中的 Flyway migration；Docker init SQL 不定义应用表，Hibernate 固定使用 `ddl-auto=validate`。Forum Mongo 索引由职责单一的 initializer 显式确保，不开启全局 auto-index。Compose test 通过独立 project 验证真实 MySQL/MongoDB。

## 基础设施目录

- `infra/compose/`：local、test、production、production-smoke 和隔离的 web-preview Compose。
- `infra/nginx/`：既有共享 production ingress 的本项目 server block 模板。
- `infra/web/`：项目专属 Web preview gateway 配置；不修改或替代共享 `campus-nginx`。
- `infra/production/`：production 数据库用户等初始化辅助文件。
- `infra/test/`：真实数据库集成测试所需的确定性 fixture。
