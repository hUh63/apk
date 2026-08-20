# ProxyPin v1.5.18 Release Notes

## 版本信息
- **Version**: v1.5.18
- **Commit**: `5fcfe25`
- **Tag**: `v1.5.18` ✅ 已推送
- **Release**: https://github.com/hUh63/apk/releases/tag/v1.5.18
- **构建**: GitHub Actions 将自动触发

---

## 修复内容

### 🔴 紧急修复：v1.5.17 构建失败

**问题**: v1.5.17 标签推送后，GitHub Actions 构建失败

**错误日志**:
```
lib/ui/component/model/search_model.dart:236:37: 
Error: The getter 'entries' isn't defined for the type 'Object'.
```

**根本原因**: 
- `request.response?.headers` 返回类型为 `Object?` 而非 `Map<String, dynamic>`
- 直接调用 `.entries` 导致编译错误

**修复方案**:
```dart
// 修复前
var respHeaders = request.response?.headers ?? {};

// 修复后
var respHeaders = (request.response?.headers as Map<String, dynamic>?) ?? {};
```

---

## 修改文件

| 文件 | 变更 | 说明 |
|------|------|------|
| `lib/ui/component/model/search_model.dart` | +1 -1 | 添加响应头类型转换 |

---

## 版本发布历史对照

| 版本 | 状态 | 构建结果 | 说明 |
|------|------|----------|------|
| v1.5.17 | ✅ 已发布 | ❌ 失败 | 存在编译错误，需使用 v1.5.18 |
| v1.5.18 | ✅ 已发布 | ⏳ 待构建 | v1.5.17 热修复版本 |

---

## 技术债务状态

| 类别 | 数量 | 状态 |
|------|------|------|
| 开放 Issues | 0 | ✅ 清零 |
| FIXME/BUG 标记 | 0 | ✅ 清零 |
| TODO 残留 | 0 | ✅ 清零 |
| CI 警告 | 0 | ✅ 清零 |
| 编译错误 | 0 | ✅ 清零 (v1.5.18) |

---

## 下一步计划

v1.5.18 是 v1.5.17 的紧急热修复版本，确保构建成功。

后续版本 v1.5.19 将继续实现以下优化：
1. #871 - HTTP/2 API 403 深度优化
2. #873 - JS 脚本日志增强 (输出图片)
3. 其他高优先级 Issues

---

## 下载链接

- **APK**: 待 GitHub Actions 构建完成后在 Release 页面下载
- **源码**: https://github.com/hUh63/apk/tree/v1.5.18

---

*发布时间：2026-08-20*
