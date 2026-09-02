# 项目状态

状态按证据区分：`implemented`、`automated tested`、`real-device verified` 和 `production verified` 不互相替代。

## VERIFIED

- 真实 Android 手机可启动当前 APK；登录后的 secure session 在杀掉 App 后可恢复（real-device verified）。
- Profile DatePicker、资料保存及切换页面后的最新值保持正常（real-device verified）。
- 旧 production backend 下可发帖，成功结果立即合并到 feed，去重和时间倒序正常（real-device verified）。
- 自有帖子显示删除入口和确认 Dialog；旧 backend 不支持 DELETE 时提示版本不支持且不做本地假删除（real-device verified）。
- 普通 branch CI 不读取 production signing secrets；commit `235d20f6ffdc` 的 CI run `33601967241` 已通过（automated tested）。

## PENDING

- 注册字段已调整为 username → nickname → password；中文昵称输入需用新 APK 再做真机验证。
- 新 backend 的作者 DELETE、非作者 403 和 `authorNickname` 已 automated tested，尚未 production verified。
- production feed 中的工程 smoke 帖来自历史真实域名发布验证，不是当前隔离 production-like harness；清理前必须按明确文档 ID、标题、时间和作者逐条确认，禁止模糊条件批量删除。
- 用户可见名称 `Engineering Acceptance` 仍需在 release 前人工选择；repository、artifact 和内部标识不随意改名。
- MuMu 模拟器启动兼容性尚未关闭；当前主要交付证据为真实 Android 手机。

## BLOCKED / EXTERNAL PREREQUISITE

- bearer token 正式上线前，共享基础设施必须先完成 TLS 并验证证书和域名。
- 新 backend deploy 前必须配置独立 production `APP_AUTH_SIGNING_KEY`。
- 旧 APK 不发送 bearer token；secured backend rollout 必须按部署文档执行并通知 breaking change，不能永久保留匿名写接口。
- 新代码尚未创建正式 tag/release/deploy；当前 production backend 仍为 `v1.0.10`。
- production MongoDB application credential least privilege、backend container non-root 和隔离 backup/restore drill 尚未完成。
