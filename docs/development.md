# 本地开发

目标环境为 WSL Ubuntu，项目自动化统一使用 Bash/`sh`；不提供或依赖 PowerShell 版本的 harness。当前已确认工具版本：

- Flutter 3.47.1 stable
- Dart 3.13.1
- OpenJDK/Javac 21.0.12
- Maven 3.9.16（通过 Maven Wrapper 3.3.4）
- Spring Boot 4.1.1

Flutter 官方骨架使用以下命令创建，仅包含 Android 平台：

```bash
flutter create --platforms=android --org com.campusmeow.acceptance \
  --project-name engineering_acceptance_app frontend
```

Android 特定调整包括 applicationId/namespace、`MainActivity` package、显示名称和 `INTERNET` permission。main/release network security config 默认禁止 cleartext，仅允许 `wm7023.campusmeow.com` 使用 HTTP；debug network security config 单独允许本地调试所需的 cleartext。

Flutter 开发侧可使用：

```bash
cd frontend
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-warnings --fatal-infos
flutter test
```

如需 debug APK，可执行 `flutter build apk --debug`。正式 release APK 由根目录 `./build.sh` 构建到 `dist/frontend/engineering-acceptance-app-<version>.apk`，并注入 production `API_BASE_URL`、release version 和 Git commit。

未传 `--dart-define` 时，Flutter 开发配置默认使用 Android Emulator 的 `http://10.0.2.2:18080`。根目录 `./build.sh` 会为 release APK 明确注入 `http://wm7023.campusmeow.com`；需要构建其他目标时可执行 `API_BASE_URL=http://example.test ./build.sh` 覆盖。release Android network security config 仅允许生产域名使用明文 HTTP，debug 资源单独保留本地开发所需的明文访问。

正式 Android 签名使用仓库外的稳定 keystore，不允许回退到 debug key。推荐在 `$HOME/.config/engineering-acceptance/android-signing.properties` 使用 Android 官方 `key.properties` 的四个字段 `storeFile`、`storePassword`、`keyAlias`、`keyPassword`，并将 keystore 和 properties 权限设为 `600`。也可通过同名的 `ANDROID_KEYSTORE_PATH`、`ANDROID_KEYSTORE_PASSWORD`、`ANDROID_KEY_ALIAS`、`ANDROID_KEY_PASSWORD` 环境变量注入。构建命令为：

```bash
chmod 600 "$HOME/.config/engineering-acceptance/android-release.jks"
chmod 600 "$HOME/.config/engineering-acceptance/android-signing.properties"
./build.sh
```

密码不写入仓库、命令参数或日志。CI 的普通分支和 PR 使用显式 debug APK 验证构建，不读取 production signing secrets；仅 release tag 使用加密 secrets 恢复临时 keystore并构建正式签名 APK。可用 Android SDK 的 `apksigner verify --verbose --print-certs <apk>` 验证签名和证书 SHA-256 fingerprint；release 配置缺失时构建会明确失败。

Spring Boot 骨架通过官方 `https://start.spring.io/starter.zip` 创建，参数为 Maven、Java 21、Jar、group/package `com.campusmeow.acceptance`、artifact/name `engineering-acceptance-backend`，以及 Web、Validation、Actuator、JPA、MySQL、MongoDB 依赖。

后端入口类为 `EngineeringAcceptanceApplication`，项目使用 Maven Wrapper。完整后端测试依赖 test Compose 提供的真实 MySQL/MongoDB，因此不要把裸 `./mvnw test` 当作独立验收入口：根目录 `./test.sh` 会创建隔离数据库并运行 Maven tests，完整质量门禁使用 `./check.sh`，正式 JAR 使用 `./build.sh` 构建。如需仅构建 backend 而不运行测试，可在 `backend/` 执行 `./mvnw -q package -DskipTests`，但该命令不能替代 `./test.sh`。

根目录统一脚本已实现：`lint.sh` 执行静态检查，`test.sh` 执行隔离 Docker 集成测试，`build.sh` 输出 `dist/` 中的 APK/JAR，`check.sh` 串行执行前三者，`deploy.sh` 只部署显式 release tag。Docker Compose 配置位于 `infra/compose/`。

fresh local volume 启动时由 backend 执行 Flyway migration，再由 Hibernate 校验 schema。existing local volume 如果出现 schema drift，应先审计并显式处理；不得永久启用 `baseline-on-migrate`，也不得通过删除 production 数据解决 migration 问题。

本地和测试环境使用明确标记为非生产的 token signing key。production 必须通过服务器 secret 文件提供至少 32 字节的独立随机 `APP_AUTH_SIGNING_KEY`；token 默认有效期为 30 分钟。Flutter 使用 `flutter_secure_storage` 持久化必要 session，启动时对未过期 bearer token 调用受保护资料接口验证；过期或 401 会清除 session。旧后端无 token 响应仅作为 rollout 期间的 UI continuity 保存，不能通过新后端认证。

当前 APK 以真实 Android 手机作为主要交付验证设备；MuMu 模拟器启动兼容性尚未关闭，不据此改动 secure storage 或 Android SDK baseline。实现、真机和生产状态分别记录在 [项目状态](status.md)。
