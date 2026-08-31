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

未传 `--dart-define` 时，Flutter 开发配置默认使用 Android Emulator 的 `http://10.0.2.2:18080`。根目录 `./build.sh` 会为 release APK 明确注入 `http://wm7023.campusmeow.com`；需要构建其他目标时可执行 `API_BASE_URL=http://example.test ./build.sh` 覆盖。release Android network security config 仅允许生产域名使用明文 HTTP，debug 资源单独保留本地开发所需的明文访问。

Spring Boot 骨架通过官方 `https://start.spring.io/starter.zip` 创建，参数为 Maven、Java 21、Jar、group/package `com.campusmeow.acceptance`、artifact/name `engineering-acceptance-backend`，以及 Web、Validation、Actuator、JPA、MySQL、MongoDB 依赖。

后端入口类为 `EngineeringAcceptanceApplication`。当前验证使用项目自带 Maven Wrapper：`./mvnw --version`、`./mvnw test` 和 `./mvnw package` 均通过，JAR 输出到 `backend/target/engineering-acceptance-backend-0.0.1-SNAPSHOT.jar`。

根目录统一脚本已实现：`lint.sh` 执行静态检查，`test.sh` 执行隔离 Docker 集成测试，`build.sh` 输出 `dist/` 中的 APK/JAR，`check.sh` 串行执行前三者，`deploy.sh` 只部署显式 release tag。Docker Compose 配置位于 `infra/compose/`。

本地首次启动会由 backend 自动执行 Flyway migration，再由 Hibernate 校验 schema。仓库当前没有已有 local volume，因此无需 baseline 或删除本地数据；若未来旧 local 数据卷出现 schema drift，应先审计并显式处理，不得永久启用 `baseline-on-migrate`。
