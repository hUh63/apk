# Changelog

## v1.22.18 (2026-08-29)

### 功能完善

- **MCP 定时任务再增强**：新增「每周」模式（周一~周日多选芯片）；一次性任务支持日历选择执行日期（showDatePicker，最长两年后）；任务卡片每周模式显示选中星期
- **环境变量内置通用变量**（上游 #900）：`{{timestamp}}`、`{{timestamp_ms}}`、`{{datetime}}`、`{{date}}`、`{{time}}`、`{{uuid}}` 可直接引用，无需手动定义
- **多选支持全选**（上游 #906）：请求列表选择模式新增「全选」按钮（桌面/移动端），选中当前可见的全部请求
- **修复 Android 保存图片无效**（上游 #902）：file_picker 在 Android 上 saveFile 不写入字节，改为写临时文件后调起系统分享面板保存

## v1.22.17 (2026-08-28)

### 功能完善

- **MCP 定时任务增强**：新增定时方式选择（一次性 / 每天重复 / 固定间隔）、重复次数上限（留空无限）、间隔分钟数；任务卡片展示模式徽标与执行进度；持久化格式向后兼容旧版 `repeatDaily` 字段
- **MCP blockRequest 真实拦截**：命中「onRequest 触发器 + 拦截动作」的请求在发出前短路返回 403（此前仅打标记不生效）
- **MCP sendNotification 真实通知**：经 EventBus 发布通知事件，桌面/移动端以 toast 展示（此前仅记录日志）
- **规则引擎动作补全**：notify 发送真实通知；startCapture/stopCapture 支持代理启停控制
- **API 端点提取功能修复**：修复 `api_extractor.dart` 引用不存在类型（`Request`/`Response`）导致的编译错误，适配 `HttpRequest`/`HttpResponse`；三种导出（OpenAPI/Postman/JSON）从占位补齐为真实文件保存；桌面请求列表菜单与工具箱新增「API 端点」入口
- **启动页（Splash）**：组件接线到移动端启动流程；偏好设置新增「启动页」配置区块——开关、展示时长（0.5–5s）、背景（默认渐变 / 自定义图片 / 透明跟随主题）、自定义小字
- **日志查看入口**：`LogViewerPage` 接入工具箱「其他」分组
- **弱网离线模式修复**：开启离线后请求被 502 拦截（此前逻辑反转，流量照常放行）

### Bug 修复

- HTTP/2：SETTINGS_MAX_FRAME_SIZE 值错位（误写 maxHeaderListSize）；畸形帧缺伪头时空指针崩溃改为受控异常；RST_STREAM 时清理流上下文防止泄漏；GOAWAY 移除「自动重试」死标记
- HTTP/2 专用客户端通道（`Http2ClientHandler`）实现接收窗口归还：连接建立即扩大连接窗口，按阈值发送连接级/流级 WINDOW_UPDATE，消除大响应窗口耗尽挂起风险
- 脚本执行异常时写入合法状态码 500（此前为非法的 -1）
- 脚本 Dart 内联分支明确提示不支持（无 Dart 运行时），不再静默假装执行
- MCP 自动化 `onRequest`/`onResponse`/`onProxyStart`/`onProxyStop` 触发器接入转发管道与代理生命周期（此前任务静默不执行）
- MCP `modifyResponse` 状态码真实生效（此前丢弃用户参数写入占位值）
- 历史记录持久化串行写队列，消除并发全量重写交错/截断风险
- HistoryTask 空闲 30 秒自动暂停，释放定时器与文件句柄
- HAR 导出流式写入，避免大列表导出时双份内存驻留
- enhanced_scheduler Cron 表达式重写为逐级进位算法，修复跨日/跨月/跨年调度错误

### 工程清理

- 移除 22 个开发过程文档（构建修复记录、旧版审查/验证/优化报告等）
- 移除未接线且与 `api_endpoint_page.dart` 重复的 `api_endpoints_page.dart`
- 文档保留：`README.md`/`README_CN.md`、`AGENTS.md`（开发指南）、`MCP_INTEGRATION.md`、`docs/MCP_AUTOMATION_GUIDE.md`、`docs/WORKFLOW_TUTORIAL.md`

## v1.22.16 (2026-08-27)

### MCP 自动化页面修复

- 运行状态指示器：进入页面不再先闪「已停止」，状态胶囊旁新增启停开关
- TabBar 靠左对齐（`tabAlignment: start`）
- 规则弹窗限制最大宽高、下拉框 `isExpanded`，修复显示异常与断言崩溃
- Prompts 列表/调用弹窗/结果弹窗全链路防御异常数据，修复白屏
- Roots 支持自由添加/编辑/删除并持久化（`mcp_roots.json`），`roots/list` 即时生效
- 新增 `startMcp`/`stopMcp`/`refreshMcpRoots` 桌面端 IPC
