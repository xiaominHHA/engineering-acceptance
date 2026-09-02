# 架构

## 已确认边界

- `frontend/` 是 Flutter 轻客户端，只通过 HTTP API 访问后端。
- `backend/` 是单体 Spring Boot 应用，统一承载 API 和业务规则。
- MySQL 只保存账号和个人信息等结构化核心用户数据。
- MongoDB 只保存论坛帖子；帖子仅保存关联用户 ID，不复制用户资料。
- Spring Boot、MySQL、MongoDB 在 local、test、production 中均通过 Docker 运行。
- 不引入微服务、Redis、消息队列、独立认证服务或分布式追踪系统。

## 当前实现

- `frontend/` 由 Flutter 3.47.1 的 `flutter create` 创建，仅包含 Android 平台。Auth、Profile、Forum 按 feature 组织，依赖方向固定为 Page → ChangeNotifier ViewModel → Repository → ApiClient；页面不直接处理 HTTP status，ApiClient 不包含业务模型或 UI 文案。
- Flutter project name 为 `engineering_acceptance_app`，Android applicationId 为 `com.campusmeow.acceptance.app`。
- `backend/` 由官方 Spring Initializr 创建，使用 Spring Boot 4.1.1、Java 21 和 Maven Wrapper。
- 后端依赖包含 Web MVC、Validation、Actuator、Spring Security Resource Server、JPA、MySQL Driver、MongoDB、Flyway 和测试支持。
- 后端入口类为 `com.campusmeow.acceptance.EngineeringAcceptanceApplication`。
- `user/` 模块负责 MySQL 用户与个人资料，`forum/` 模块负责 MongoDB 帖子；Controller 通过 Service 访问各自 Repository，响应 DTO 不暴露密码哈希。
- 后端通过小型业务异常和全局 REST advice 返回稳定的 `code`、`message`、`fieldErrors` 错误 contract；Service 不使用 HTTP 异常表达业务错误。
- 注册和登录返回短期 HS256 bearer token 与当前用户。token 仅包含 user subject、签发/过期时间，签名密钥来自环境且不进入 Git；Flutter 通过 Android secure storage 保存必要 session，启动时验证未过期 token，401 或显式退出会同时清除内存与持久化 session。服务端保持无状态，不提供 refresh token。
- `GET/PUT /api/users/{id}` 要求 token subject 与 path id 一致，匿名访问返回 401、跨用户访问返回 403。`POST /api/posts` 和 `DELETE /api/posts/{id}` 只信任 authenticated principal，且仅作者可删除自己的帖子；`GET /api/posts` 保持匿名可读。帖子列表批量读取关联用户昵称，避免逐帖查询 MySQL。

MySQL schema 的唯一 owner 是 `backend/src/main/resources/db/migration/` 中的 Flyway migration；Docker init SQL 不定义应用表，Hibernate 固定使用 `ddl-auto=validate`。Compose local/test/production 基线已创建；test 环境通过独立 project 验证真实 MySQL/MongoDB，业务集成测试覆盖用户密码哈希、资料读写和帖子读写。
