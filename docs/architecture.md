# 架构

## 已确认边界

- `frontend/` 是 Flutter 轻客户端，只通过 HTTP API 访问后端。
- `backend/` 是单体 Spring Boot 应用，统一承载 API 和业务规则。
- MySQL 只保存账号和个人信息等结构化核心用户数据。
- MongoDB 只保存论坛帖子；帖子仅保存关联用户 ID，不复制用户资料。
- Spring Boot、MySQL、MongoDB 在 local、test、production 中均通过 Docker 运行。
- 不引入微服务、Redis、消息队列、独立认证服务或分布式追踪系统。

## 当前骨架

- `frontend/` 由 Flutter 3.47.1 的 `flutter create` 创建，仅包含 Android 平台和官方计数器示例。
- Flutter project name 为 `engineering_acceptance_app`，Android applicationId 为 `com.campusmeow.acceptance.app`。
- `backend/` 由官方 Spring Initializr 创建，使用 Spring Boot 4.1.1、Java 21 和 Maven Wrapper。
- 后端基础依赖仅包含 Web MVC、Validation、Actuator、JPA、MySQL Driver、MongoDB 和 Initializr 默认测试支持。
- 后端入口类为 `com.campusmeow.acceptance.EngineeringAcceptanceApplication`。

Compose 环境和真实数据库连接尚未创建。当前没有 Entity、Document、Controller、Service、Repository 或其他业务实现。
