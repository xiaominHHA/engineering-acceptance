# 本地开发

目标环境为 WSL Ubuntu。当前已确认工具版本：

- Flutter 3.47.1 stable
- Dart 3.13.1
- OpenJDK/Javac 21.0.12
- Maven Wrapper 3.9.16
- Spring Boot 4.1.1

Flutter 官方骨架使用以下命令创建，仅包含 Android 平台：

```bash
flutter create --platforms=android --org com.campusmeow.acceptance \
  --project-name engineering_acceptance_app frontend
```

生成后只调整了 Android applicationId/namespace、`MainActivity` package 和显示名称。

当前 Flutter 验证命令及结果：

```bash
cd frontend
flutter pub get                         # 通过
dart format --output=none --set-exit-if-changed .  # 通过
flutter analyze                         # 通过
flutter test                             # 通过
flutter build apk --debug                # 通过
```

APK 由 Flutter 输出到 `frontend/build/app/outputs/flutter-apk/app-debug.apk`。

Spring Boot 骨架通过官方 `https://start.spring.io/starter.zip` 创建，参数为 Maven、Java 21、Jar、group/package `com.campusmeow.acceptance`、artifact/name `engineering-acceptance-backend`，以及 Web、Validation、Actuator、JPA、MySQL、MongoDB 依赖。

后端入口类为 `EngineeringAcceptanceApplication`。当前验证使用项目自带 Maven Wrapper：`./mvnw --version`、`./mvnw test` 和 `./mvnw package` 均通过，JAR 输出到 `backend/target/engineering-acceptance-backend-0.0.1-SNAPSHOT.jar`。

当前 WSL 中 `docker` 和 `docker compose` 命令不可用，提示需要启用 Docker Desktop WSL integration。Stage 2 不使用 Docker；进入 Compose 阶段前必须先修复该环境问题。

根目录统一脚本尚未实现，当前不要尝试 README 中列出的脚本。
