# 测试

## 已确认原则

- `test.sh` 每次使用唯一 Compose project 和新 volumes。
- MySQL、MongoDB 使用版本化的固定初始化数据。
- 后端必须包含连接真实 MySQL/MongoDB 的集成测试；mock 不能替代该测试。
- 测试数据库不发布宿主端口，也不得连接 local 或 production。
- 结束时只清理本次测试创建的容器、网络和 volumes。
- Flutter 使用标准 `flutter test`。

## Stage 2 已验证范围

Flutter 官方 Widget smoke test 已通过：

```bash
cd frontend
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

后端使用 Maven Wrapper 完成编译、测试和打包：

```bash
cd backend
./mvnw --version
./mvnw test
./mvnw package
```

以上后端命令均已通过；Flutter 的 `flutter build apk --debug` 也已通过并生成 debug APK。`./check.sh` 当前尚不存在，因此按照开发规范本阶段不适用且未执行；该脚本创建后，后续阶段必须使用它作为完整质量门禁。

当前后端测试是纯 JUnit 骨架 smoke test，只检查入口类具有 `@SpringBootApplication`。它不加载 Spring context、不连接数据库，也不是数据库集成测试。这样可以在 Compose 尚未创建时明确隔离骨架验证，且不会偷偷连接 local/production。

真实 MySQL/MongoDB 集成测试、固定初始化数据和 `test.sh` 均尚未实现，必须在 Docker Compose 阶段补齐。
