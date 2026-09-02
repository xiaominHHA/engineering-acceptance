# Flutter Frontend

本目录是 `engineering-acceptance` 的 Flutter Android 客户端，保持标准 `flutter create` 项目结构。

- `lib/core/config/`：运行配置
- `lib/core/network/`、`lib/core/error/`：无 UI 文案的 HTTP transport 与 typed failure
- `lib/models/`：客户端模型
- `lib/features/`：Auth、Profile、Forum 的 Page、ViewModel 与 Repository

认证使用后端签发的短期 bearer token，凭证仅由 `ApiClient` 保存在当前 App 进程内存；退出或重启后需要重新登录。正式 APK 必须通过仓库外的稳定 keystore 构建。

正式测试、构建和项目级说明统一参见：

- [项目总览](../README.md)
- [本地开发与构建](../docs/development.md)
