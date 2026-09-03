# 项目状态

状态按证据区分：`implemented`、`automated tested`、`real-device verified` 和 `production verified` 不互相替代。

## VERIFIED

- `v1.1.0` Android APK 已在真实手机完成主要功能验证；登录后的 secure session 在杀掉 App 后可恢复（real-device verified）。
- Profile DatePicker、资料保存及切换页面后的最新值保持正常（real-device verified）。
- 发帖成功结果立即合并到 feed，去重和时间倒序正常；帖子详情、点赞、评论/回复及作者删除已完成真机主要功能验证（real-device verified）。
- 当前 server backend build commit `614830ba79a66943940985206a3fd5ffe17c3704` 已部署；bearer auth、Profile 与完整 Forum V1 API 已完成实际 API smoke（production verified）。
- Flutter Web 临时公网 HTTPS preview 已验证注册、登录、刷新后 session 恢复、发帖、详情、点赞/取消、评论/回复以及删除自己的评论和帖子（browser verified）。
- 普通 branch CI 不读取 production signing secrets；合并 Web preview 后的 `develop` CI run `33716675355` 已通过（automated tested）。

## IMPLEMENTED / AUTOMATED TESTED

- Flutter Web 官方 scaffolding、跨平台 ApiClient 和浏览器 current-origin API 解析已实现；release bundle、项目专属 Caddy same-origin gateway 及 Quick Tunnel HTTPS 路由已完成自动检查、HTTP smoke 和浏览器验证。
- 登录与注册已拆分；登录用户名和社区昵称的用途、输入顺序和 autofill 语义已明确（implemented，Flutter tested）。
- Forum V1 已实现详情、数组分页/加载更多、pull-to-refresh、幂等点赞、一级回复评论、作者删除评论、统计和帖子级联清理（implemented，Flutter + real MongoDB integration tested；唯一点赞索引由真实 MongoDB 验证）。
- 帖子/评论作者昵称和当前页统计使用批量读取，未引入逐条 N+1（implemented，integration tested）。
- backend runtime 使用专用 non-root 用户；Mongo 应用凭据使用目标 database 的 `readWrite` 用户，并提供 fresh/existing 环境的幂等初始化路径（production-like smoke 与当前部署验证）。

## PENDING

- 注册字段已调整为 username → nickname → password；中文昵称输入需用新 APK 再做真机验证。
- production feed 中的工程 smoke 帖来自历史真实域名发布验证，不是当前隔离 production-like harness；清理前必须按明确文档 ID、标题、时间和作者逐条确认，禁止模糊条件批量删除。
- 用户可见名称 `Engineering Acceptance` 仍需在 release 前人工选择；repository、artifact 和内部标识不随意改名。
- MuMu 模拟器启动兼容性尚未关闭；当前主要交付证据为真实 Android 手机。

## BLOCKED / EXTERNAL PREREQUISITE

- 当前长期 production ingress 仍为 HTTP；永久 HTTPS/TLS 方案尚未完成。Cloudflare Quick Tunnel 仅用于临时 Web preview。
- 旧 APK 不发送 bearer token，不能用于当前 secured backend 的受保护写接口；应使用 `v1.1.0` 或更新客户端。
- 隔离 backup/restore drill 尚未完成，restart persistence 不作为恢复验证。
