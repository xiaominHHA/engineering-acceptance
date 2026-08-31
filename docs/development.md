# 本地开发

目标环境为 WSL Ubuntu。当前已确认工具版本：

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

如需 debug APK，可执行 `flutter build apk --debug`。验收正式 release APK 由根目录 `./build.sh` 构建，输出到 `dist/frontend/app-release.apk`，并由 `build.sh` 注入 production `API_BASE_URL`。

未传 `--dart-define` 时，Flutter 开发配置默认使用 Android Emulator 的 `http://10.0.2.2:18080`。根目录 `./build.sh` 会为 release APK 明确注入 `http://wm7023.campusmeow.com`；需要构建其他目标时可执行 `API_BASE_URL=http://example.test ./build.sh` 覆盖。release Android network security config 仅允许生产域名使用明文 HTTP，debug 资源单独保留本地开发所需的明文访问。

Spring Boot 骨架通过官方 `https://start.spring.io/starter.zip` 创建，参数为 Maven、Java 21、Jar、group/package `com.campusmeow.acceptance`、artifact/name `engineering-acceptance-backend`，以及 Web、Validation、Actuator、JPA、MySQL、MongoDB 依赖。

后端入口类为 `EngineeringAcceptanceApplication`，项目使用 Maven Wrapper。完整后端测试依赖 test Compose 提供的真实 MySQL/MongoDB，因此不要把裸 `./mvnw test` 当作独立验收入口：根目录 `./test.sh` 会创建隔离数据库并运行 Maven tests，完整质量门禁使用 `./check.sh`，正式 JAR 使用 `./build.sh` 构建。如需仅构建 backend 而不运行测试，可在 `backend/` 执行 `./mvnw -q package -DskipTests`，但该命令不能替代 `./test.sh`。

根目录统一脚本已实现：`lint.sh` 执行静态检查，`test.sh` 执行隔离 Docker 集成测试，`build.sh` 输出 `dist/` 中的 APK/JAR，`check.sh` 串行执行前三者，`deploy.sh` 只部署显式 release tag。Docker Compose 配置位于 `infra/compose/`。

fresh local volume 启动时由 backend 执行 Flyway migration，再由 Hibernate 校验 schema。existing local volume 如果出现 schema drift，应先审计并显式处理；不得永久启用 `baseline-on-migrate`，也不得通过删除 production 数据解决 migration 问题。
