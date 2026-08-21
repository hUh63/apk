# ProxyPin v1.22.6 构建修复报告

**日期**: 2026-08-21  
**版本**: v1.22.6  
**提交**: 0ed8126  
**状态**: ✅ 已推送，等待 GitHub Actions 构建

---

## 修复问题

### 1. MCP 自动化 UI 命名冲突 (关键阻塞)

**问题描述**: `mcp_automation.dart` (移动端/桌面端) 中直接使用 `Action()`, `Condition()`, `Rule()` 构造函数与 Flutter Material 库中的同名类冲突。

**v1.22.5 失败尝试**:
- 使用 `hide Action, Condition, Rule` 子句 - ❌ 无效
- 代码中仍然直接使用未限定的类名

**v1.22.6 正确修复**:
```dart
// 修复前 (v1.22.5)
import 'package:proxypin/network/mcp/mcp_rule_engine.dart' hide Action, Condition, Rule;
// 代码中直接使用: Rule(), Condition(), Action()

// 修复后 (v1.22.6)
import 'package:proxypin/network/mcp/mcp_rule_engine.dart' as mcp;
// 代码中使用: mcp.Rule(), mcp.Condition(), mcp.Action()
```

**修改文件**:
- `lib/ui/mobile/setting/mcp_automation.dart`
- `lib/ui/desktop/setting/mcp_automation.dart`

**具体改动**:
1. 导入语句改为 `as mcp` 别名
2. `McpRuleEngine` → `mcp.McpRuleEngine`
3. `Rule(` → `mcp.Rule(`
4. `Condition(` → `mcp.Condition(`
5. `Action(` → `mcp.Action(`
6. `ConditionType.custom` → `mcp.ConditionType.custom`
7. `ActionType.custom` → `mcp.ActionType.custom`
8. `Operator.contains` → `mcp.Operator.contains`
9. `RulePriority.normal` → `mcp.RulePriority.normal`

---

### 2. 桌面端 FilePicker 导入问题

**问题描述**: `config_management.dart` (桌面端) 中 FilePicker 导入使用 `show` 子句导致类型识别错误。

**错误信息**:
```
Error: 'FilePickerResult' isn't a type.
Error: Member not found: 'FilePicker.platform'.
```

**修复方案**:
```dart
// 修复前
import 'package:file_picker/file_picker.dart' show FilePicker, FilePickerResult, FileType;

// 修复后
import 'package:file_picker/file_picker.dart';
```

**修改文件**:
- `lib/ui/desktop/setting/config_management.dart`

---

## 变更统计

| 文件 | 变更类型 | 说明 |
|------|---------|------|
| `lib/ui/mobile/setting/mcp_automation.dart` | 修改 | 添加 mcp 别名前缀 |
| `lib/ui/desktop/setting/mcp_automation.dart` | 修改 | 添加 mcp 别名前缀 |
| `lib/ui/desktop/setting/config_management.dart` | 修改 | 修复 FilePicker 导入 |
| `BUILD_FIX_v1.22.5.md` | 新增 | v1.22.5 失败分析报告 |

**总计**: 4 files changed, 136 insertions(+), 19 deletions(-)

---

## Git 历史

```
0ed8126 (HEAD -> main, tag: v1.22.6, origin/main)
  fix(v1.22.6): 修复 Action/Condition/Rule 命名冲突
  
79ba300 (tag: v1.22.5)
  fix(v1.22.5): 修复 3 个构建错误
  
b1ec755
  docs: 更新 v1.22.4 构建修复报告
```

---

## 预期构建结果

**GitHub Actions**: 应成功编译并生成 APK  
**Release**: https://github.com/hUh63/apk/releases/tag/v1.22.6

---

## 下一步

1. ⏳ 等待 GitHub Actions 构建完成
2. ⏳ 验证 APK 产物上传
3. ⏳ 测试 MCP 自动化功能 (定时任务/事件监听/规则引擎/工作流)

---

## 相关文档

- [v1.22.5 失败分析](omnibot://workspace/apk/BUILD_FIX_v1.22.5.md)
- [v1.22.4 修复报告](omnibot://workspace/apk/BUILD_FIX_v1.22.4.md)
- [Release v1.22.6](https://github.com/hUh63/apk/releases/tag/v1.22.6)
