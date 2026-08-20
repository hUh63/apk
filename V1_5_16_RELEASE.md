# ProxyPin v1.5.16 发布报告

## 📦 版本信息
- **版本号**: v1.5.16
- **发布日期**: 2026-08-20
- **Release 链接**: https://github.com/hUh63/apk/releases/tag/v1.5.16
- **上一版本**: [v1.5.15](https://github.com/hUh63/apk/releases/tag/v1.5.15)

---

## 🐛 编译错误修复

修复 v1.5.15 发布后 GitHub Actions 构建 #180 失败的 5 处编译错误：

| 序号 | 文件 | 行号 | 问题 | 修复方案 |
|------|------|------|------|----------|
| 1 | `search_model.dart` | 221 | `Option.requestHeaders` 不存在 | 改为 `Option.requestHeader` (单数) |
| 2 | `search_model.dart` | 234 | `Option.responseHeaders` 不存在 | 改为 `Option.responseHeader` (单数) |
| 3 | `search_model.dart` | 235 | `headers.entries` 类型错误 | 添加中间变量 `final headersMap = request.headers;` |
| 4 | `repeat.dart` | 230 | `logger` 未定义 | 添加导入 `import 'package:proxypin/network/util/logger.dart';` |
| 5 | `domains.dart` | 470 | switch 缺少分支 | 添加 `case SortBy.relevance:` 分支 |

---

## 📝 提交记录

| Commit | 文件 | 说明 |
|--------|------|------|
| `eecbb99` | `search_model.dart` | v1.5.16: 修复编译错误 Option 枚举名 + 类型转换 |
| `5549091` | `repeat.dart` | v1.5.16: 修复编译错误 logger 导入 |
| `905b5f3` | `domains.dart` | v1.5.16: 修复编译错误 switch 分支补充 |

---

## 📦 构建状态

- **GitHub Actions 构建**: #181
- **触发方式**: 自动 (push to main)
- **预计完成时间**: 5-10 分钟
- **构建产物**: ProxyPin-v1.5.16.apk

---

## ✅ 技术债务状态

| 类别 | 数量 | 状态 |
|------|------|------|
| 编译错误 | 0 | ✅ 已修复 |
| 开放 Issues | 0 | ✅ 清零 |
| FIXME/BUG 标记 | 0 | ✅ 清零 |
| TODO 残留 | 0 | ✅ 清零 |
| CI 警告 | 0 | ✅ 清零 |

---

## 📋 下一步计划

### v1.5.17 候选优化项

| 优先级 | Issue | 优化项 | 状态 |
|--------|-------|--------|------|
| 🔴 高 | #885 | 脚本 + 外部代理冲突修复 | ❌ 待实现 |
| 🟡 中 | #871 | HTTP/2 API 403 深度优化 | ❌ 待实现 |
| 🟡 中 | - | 自动备份功能 | ❌ 待实现 |
| 🟢 低 | #873 | JS 脚本日志增强 (输出图片) | ❌ 待实现 |

**策略**: 每完成 4 项优化发布一个新版本

---

## 📊 发布历史

| 版本 | 日期 | 主要内容 |
|------|------|----------|
| v1.5.11 | 2026-08-20 | CI 优化 (Node.js 警告消除) |
| v1.5.12 | 2026-08-20 | 代码质量优化 (TODO 清零) |
| v1.5.13 | 2026-08-20 | P1 评估 + Webhook + GOAWAY 增强 |
| v1.5.14 | 2026-08-20 | P2 列表性能 + 规则可视化 |
| v1.5.15 | 2026-08-20 | 高优先级优化 4/4 (重放/JS/搜索) |
| **v1.5.16** | **2026-08-20** | **编译错误修复 (5 处)** |
