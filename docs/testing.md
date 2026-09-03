# 测试

## 原则

- `test.sh` 每次使用唯一 Compose project 和新 volumes。
- MySQL schema 只由与 local/production 相同的 Flyway migration 创建。
- MySQL fixture 在 migration 完成后由测试框架插入；MongoDB 使用固定 init fixture。
- 后端测试连接真实 MySQL/MongoDB，mock 不能替代数据库集成测试。
- 测试数据库不发布宿主端口，也不连接 local 或 production。
- 退出时只清理本次 project 的容器、network、volumes 和临时 image。
- Flutter 使用标准 `flutter test`。

## 当前质量门禁

`./test.sh` 首先创建全新 MySQL/MongoDB。backend 启动后执行严格的 Flyway V1，测试断言 `flyway_schema_history` 中 V1 成功、`users` 表存在且 Hibernate schema validation 通过。随后插入固定 MySQL fixture，并验证真实数据库连接和完整用户/论坛 API 流程。安全集成测试经过真实 Spring Security filter，覆盖缺失/无效/过期 token、跨用户 403、自有资料更新、服务端权威帖子作者和作者删除权限。Forum 集成测试还验证分页边界、详情、点赞幂等和唯一索引、一级回复同帖约束、评论删除权限、批量昵称/统计，以及删除帖子后的评论/点赞显式清理。

脚本还启动独立的 production-like Compose：使用正式多阶段 Dockerfile、production profile、临时回环端口、临时 secrets 和临时 volumes。它验证 build version/commit、注册 token、BCrypt 与响应脱敏、认证资料 GET/PUT、认证发帖和匿名列表；只重启该临时 backend 后，再确认 V1 未重复执行且 MySQL/MongoDB 数据均未丢失。该检查证明 restart persistence，不等同于数据库 backup/restore 演练；后者仍是独立的发布准备事项。

所有临时资源按唯一 project 精确清理，不执行 Docker prune。`./check.sh` 依次运行 lint、上述测试和正式 APK/JAR 构建。
