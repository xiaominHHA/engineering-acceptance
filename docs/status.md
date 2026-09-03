# 项目状态

状态按证据区分：`implemented`、`automated tested`、`real-device verified` 和 `production verified` 不互相替代。

## VERIFIED

- 真实 Android 手机可启动当前 APK；登录后的 secure session 在杀掉 App 后可恢复（real-device verified）。
- Profile DatePicker、资料保存及切换页面后的最新值保持正常（real-device verified）。
- 旧 production backend 下可发帖，成功结果立即合并到 feed，去重和时间倒序正常（real-device verified）。
- 自有帖子显示删除入口和确认 Dialog；旧 backend 不支持 DELETE 时提示版本不支持且不做本地假删除（real-device verified）。
- 普通 branch CI 不读取 production signing secrets；commit `235d20f6ffdc` 的 CI run `33601967241` 已通过（automated tested）。

## IMPLEMENTED / AUTOMATED TESTED

- 登录与注册已拆分；登录用户名和社区昵称的用途、输入顺序和 autofill 语义已明确（implemented，Flutter tested）。
- Forum V1 已实现详情、数组分页/加载更多、pull-to-refresh、幂等点赞、一级回复评论、作者删除评论、统计和帖子级联清理（implemented，Flutter + real MongoDB integration tested；唯一点赞索引由真实 MongoDB 验证）。
- 帖子/评论作者昵称和当前页统计使用批量读取，未引入逐条 N+1（implemented，integration tested）。
- backend runtime 已配置专用 non-root 用户；production Mongo 应用凭据已改为目标 database `readWrite` 用户，并提供 fresh/existing 环境的幂等初始化路径（production-like smoke verified，尚未 production verified）。

## PENDING

- 注册字段已调整为 username → nickname → password；中文昵称输入需用新 APK 再做真机验证。
- 新 backend 的完整 Forum V1、作者权限和 `authorNickname` 尚未 real-device / production verified。
- production feed 中的工程 smoke 帖来自历史真实域名发布验证，不是当前隔离 production-like harness；清理前必须按明确文档 ID、标题、时间和作者逐条确认，禁止模糊条件批量删除。
- 用户可见名称 `Engineering Acceptance` 仍需在 release 前人工选择；repository、artifact 和内部标识不随意改名。
- MuMu 模拟器启动兼容性尚未关闭；当前主要交付证据为真实 Android 手机。

## BLOCKED / EXTERNAL PREREQUISITE

- bearer token 正式上线前，共享基础设施必须先完成 TLS 并验证证书和域名。
- 新 backend deploy 前必须配置独立 production `APP_AUTH_SIGNING_KEY`。
- 旧 APK 不发送 bearer token；secured backend rollout 必须按部署文档执行并通知 breaking change，不能永久保留匿名写接口。
- 新代码尚未创建正式 tag/release/deploy；当前 production backend 仍为 `v1.0.10`。
- production MongoDB 应用用户、backend non-root 尚待 release/production 验证；隔离 backup/restore drill 尚未完成。
