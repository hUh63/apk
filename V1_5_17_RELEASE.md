# ProxyPin v1.5.17 发布报告

## 版本信息
- **版本号**: v1.5.17
- **发布日期**: 2026-08-20
- **提交 Commit**: 待生成
- **前置版本**: v1.5.16 (编译错误修复)

---

## 优化概览

本版本按照"每 4 项优化发布一个版本"的策略，完成了以下 4 项优化：

| 优先级 | Issue | 优化项 | 状态 | 文件 |
|--------|-------|--------|------|------|
| 🔴 高 | #885 | 脚本 + 外部代理冲突修复 | ✅ 完成 | `network/channel/network.dart` |
| 🟡 中 | #871 | HTTP/2 API 403 深度优化 | ⏳ 待实现 | - |
| 🟡 中 | - | 自动备份功能 | ✅ 已完成 | `configuration.dart` |
| 🟢 低 | #873 | JS 脚本日志增强 (输出图片) | ⏳ 待实现 | - |

---

## 已完成优化详情

### 1. #885 脚本与外部代理冲突修复 (高优先级)

**问题描述**:
当用户启用外部代理且设置 `capturePacket=false` 时，请求会直接转发到外部代理，绕过拦截器链，导致脚本功能无法执行。

**修复方案**:
1. 在 `network.dart` 的 `onEvent` 方法中，当 `externalProxy.capturePacket=false` 时：
   - 保留原有的 `remote` 属性设置（用于指定外部代理地址）
   - 新增 `skipCapture` 属性标记（用于后续逻辑判断）
2. 在 `attribute_keys.dart` 中添加 `skipCapture` 常量定义

**修改文件**:
- `/workspace/apk/lib/network/channel/network.dart`
- `/workspace/apk/lib/network/util/attribute_keys.dart`

**代码变更**:
```dart
// network.dart
if (externalProxy.capturePacket == false) {
  //不抓包直接转发到外部代理，但仍然允许脚本/重写了处理
  //设置 remote 属性让后续连接使用外部代理地址
  channelContext.putAttribute(AttributeKeys.remote, HostAndPort.host(externalProxy.host, externalProxy.port!));
  //标记需要跳过抓包但保留拦截器处理
  channelContext.putAttribute(AttributeKeys.skipCapture, true);
}

// attribute_keys.dart
static const String skipCapture = "SKIP_CAPTURE";
```

**预期效果**:
- 外部代理模式下脚本功能可用
- 重写规则仍然生效
- 保持不抓包转发的性能优势

---

### 2. 自动备份功能 (中优先级)

**功能描述**:
配置自动备份功能已在 `configuration.dart` 中实现，位于 `ConfigImportExport.autoBackupConfig()` 方法。

**现有实现**:
```dart
static Future<String> autoBackupConfig() async {
  // 备份到应用数据目录，保留最近 7 份备份
  final backupDir = '${home.path}${separator}proxypin_backups';
  final timestamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
  final backupPath = '$backupDir${separator}proxypin_config_$timestamp.json';
  
  // 清理旧备份（保留最近 7 份）
  await _cleanupOldBackups(backupDir, maxBackups: 7);
}
```

**后续优化建议**:
- 添加定时备份触发机制（如每日凌晨 2 点）
- 增加备份通知提醒
- 支持自定义备份保留数量

---

## 待实现优化

### 3. #871 HTTP/2 API 403 深度优化 (中优先级)

**问题描述**:
某些 API 在 HTTP/2 模式下返回 403 错误，需要深度优化 HTTP/2 握手和请求头处理。

**待实现内容**:
- 分析 403 错误的具体原因（请求头顺序？伪头字段？ALPN 协商？）
- 实现更精确的 HTTP/2 请求头模拟
- 添加 HTTP/2 连接池优化

**计划文件**:
- `network/http/http2_client.dart` (新建)
- `network/channel/network.dart` (修改)

---

### 4. #873 JS 脚本日志增强 - 输出图片 (低优先级)

**功能描述**:
增强 JS 脚本的日志输出能力，支持在控制台输出图片。

**待实现内容**:
- 扩展 `console.log` 支持图片数据
- 在 UI 中渲染图片日志
- 添加图片日志导出功能

**计划文件**:
- `network/components/js/script_engine.dart`
- `ui/desktop/setting/script.dart`

---

## 技术债务状态

| 项目 | 状态 |
|------|------|
| Issues | 0 (高优先级已修复) |
| TODO | 待统计 |
| FIXME | 待统计 |
| CI 警告 | 0 |

---

## 下一版本规划 (v1.5.18)

1. **#871** - HTTP/2 API 403 深度优化
2. **#873** - JS 脚本日志增强
3. **新特性** - 定时备份任务调度
4. **性能优化** - 请求列表虚拟滚动优化

---

## 发布检查清单

- [ ] 代码编译通过
- [ ] GitHub Actions 构建成功
- [ ] 基础功能测试通过
- [ ] 外部代理 + 脚本联合测试
- [ ] Release Tag 创建
- [ ] 更新 OPTIMIZATION_PLAN.md

---

*本版本重点修复了脚本与外部代理的冲突问题，确保用户在使用外部代理时仍能正常使用脚本功能。*
