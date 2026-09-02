# Flutter Frontend

本目录是 `engineering-acceptance` 的 Flutter Android 客户端，保持标准 `flutter create` 项目结构。

- `lib/core/config/`：运行配置
- `lib/core/network/`、`lib/core/error/`、`lib/core/session/`：无 UI 文案的 HTTP transport、typed failure 与安全 session 存储
- `lib/models/`：客户端模型
- `lib/features/`：Auth、Profile、Forum 的 Page、ViewModel 与 Repository

认证使用后端签发的短期 bearer token；必要 session 由 `flutter_secure_storage` 保存，启动时验证，过期、401 或显式退出会清除。旧后端无 token session 只在 rollout 期间维持 UI continuity，不构成新后端认证。正式 APK 必须通过仓库外的稳定 keystore 构建。

正式测试、构建和项目级说明统一参见：

- [项目总览](../README.md)
- [本地开发与构建](../docs/development.md)
