# 架构

## 已确认边界

- `frontend/` 是 Flutter 轻客户端，只通过 HTTP API 访问后端。
- `backend/` 是单体 Spring Boot 应用，统一承载 API 和业务规则。
- MySQL 只保存账号和个人信息等结构化核心用户数据。
- MongoDB 只保存论坛帖子；帖子仅保存关联用户 ID，不复制用户资料。
- Spring Boot、MySQL、MongoDB 在 local、test、production 中均通过 Docker 运行。
- 不引入微服务、Redis、消息队列、独立认证服务或分布式追踪系统。

## 当前实现

- `frontend/` 由 Flutter 3.47.1 的 `flutter create` 创建，仅包含 Android 平台；页面通过集中配置的 HTTP API 完成注册、登录、资料编辑和论坛列表/发帖。
- Flutter project name 为 `engineering_acceptance_app`，Android applicationId 为 `com.campusmeow.acceptance.app`。
- `backend/` 由官方 Spring Initializr 创建，使用 Spring Boot 4.1.1、Java 21 和 Maven Wrapper。
- 后端依赖包含 Web MVC、Validation、Actuator、JPA、MySQL Driver、MongoDB、Flyway、BCrypt crypto 和 Initializr 默认测试支持。
- 后端入口类为 `com.campusmeow.acceptance.EngineeringAcceptanceApplication`。
- `user/` 模块负责 MySQL 用户与个人资料，`forum/` 模块负责 MongoDB 帖子；Controller 通过 Service 访问各自 Repository，响应 DTO 不暴露密码哈希。

MySQL schema 的唯一 owner 是 `backend/src/main/resources/db/migration/` 中的 Flyway migration；Docker init SQL 不定义应用表，Hibernate 固定使用 `ddl-auto=validate`。Compose local/test/production 基线已创建；test 环境通过独立 project 验证真实 MySQL/MongoDB，业务集成测试覆盖用户密码哈希、资料读写和帖子读写。
