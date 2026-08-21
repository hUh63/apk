# ProxyPin 事件系统使用指南

## 📖 概述

ProxyPin v1.20.2 引入了完整的事件系统，支持：
- **事件总线**：跨组件通信
- **脚本执行**：Python/Shell/JavaScript
- **定时调度**：Cron 表达式支持
- **规则引擎**：可视化规则配置

---

## 1️⃣ EventBus - 事件总线

### 基本用法

```dart
import 'package:proxypin/event/event.dart';

// 获取单例
final eventBus = EventBus();

// 订阅事件
eventBus.subscribe('http.request', (event) {
  print('收到 HTTP 请求：${event.data}');
});

// 发布事件
eventBus.publish(Event(
  type: 'http.request',
  data: {'url': 'https://example.com'},
));

// 取消订阅
eventBus.unsubscribe('http.request', callback);
```

### 内置事件类型

| 事件类型 | 说明 | 数据字段 |
|---------|------|---------|
| `http.request` | HTTP 请求 | `url`, `method`, `headers`, `body` |
| `http.response` | HTTP 响应 | `url`, `statusCode`, `headers`, `body`, `responseTime` |
| `network.status` | 网络状态变化 | `status`: connected/disconnected/wifi/mobile |
| `proxy.started` | 代理启动 | `port`, `timestamp` |
| `proxy.stopped` | 代理停止 | `timestamp` |
| `capture.started` | 抓包开始 | `timestamp` |
| `capture.stopped` | 抓包停止 | `timestamp` |
| `script.executed` | 脚本执行 | `scriptName`, `success`, `output` |

### 高级用法

```dart
// 带过滤的订阅
eventBus.subscribe('http.request', (event) {
  // 只处理 POST 请求
  if (event.data['method'] == 'POST') {
    // 处理逻辑
  }
}, filter: (event) => event.data['method'] == 'POST');

// 一次性事件
eventBus.subscribeOnce('proxy.started', (event) {
  print('代理已启动，端口：${event.data['port']}');
});

// 获取历史事件
final history = eventBus.getHistory(limit: 50);
```

---

## 2️⃣ ScriptExecutor - 脚本执行器

### 执行 Python 脚本

```dart
import 'package:proxypin/event/event.dart';

final executor = ScriptExecutor();

// 执行文件脚本
final result = await executor.executePython(
  '/path/to/script.py',
  args: ['--arg1', 'value1'],
  environment: {'API_KEY': 'secret'},
  timeoutSeconds: 30,
);

print('执行成功：${result.success}');
print('输出：${result.output}');
print('错误：${result.error}');
```

### 执行内联 Python 代码

```dart
final result = await executor.executePythonCode('''
import json
data = {"status": "ok", "timestamp": 1234567890}
print(json.dumps(data))
''');
```

### 执行 Shell 命令

```dart
// 执行文件
final result = await executor.executeShell('/path/to/script.sh');

// 执行内联命令
final result = await executor.executeShellCommand('''
  echo "当前目录：$(pwd)"
  ls -la
''');
```

### 执行 JavaScript

```dart
// 使用 Node.js 执行
final result = await executor.executeJavaScript('/path/to/script.js');

// 内联代码
final result = await executor.executeJavaScriptCode('''
  console.log("Hello from Node.js");
  console.log(JSON.stringify({status: "ok"}));
''');
```

### 检查解释器

```dart
final interpreters = await executor.checkAllInterpreters();
print('Python 可用：${interpreters['python']}');
print('Node.js 可用：${interpreters['node']}');
print('Shell 可用：${interpreters['shell']}');
```

---

## 3️⃣ EnhancedScheduler - 增强调度器

### 一次性任务

```dart
import 'package:proxypin/event/event.dart';

final scheduler = EnhancedScheduler();

// 10 分钟后执行一次
final taskId = scheduler.addOnce(
  name: '数据备份',
  executeAt: DateTime.now().add(Duration(minutes: 10)),
  callback: () async {
    print('执行数据备份...');
    // 备份逻辑
  },
);
```

### 周期性任务

```dart
// 每 5 分钟执行一次
final taskId = scheduler.addPeriodic(
  name: '状态检查',
  interval: Duration(minutes: 5),
  callback: () async {
    print('检查系统状态...');
  },
  repeat: true,
);
```

### Cron 任务

```dart
// 每天凌晨 2 点执行
scheduler.addCron(
  name: '每日清理',
  cronExpression: '0 2 * * *',
  callback: () async {
    print('执行每日清理任务...');
  },
);

// 每小时执行一次
scheduler.addCron(
  name: '每小时同步',
  cronExpression: '0 * * * *',
  callback: () async {
    print('执行数据同步...');
  },
);

// 每 15 分钟执行一次
scheduler.addCron(
  name: '频繁检查',
  cronExpression: '*/15 * * * *',
  callback: () async {
    print('执行检查...');
  },
);
```

### 任务管理

```dart
// 获取所有任务
final tasks = scheduler.getTasks();
for (final task in tasks) {
  print('任务：${task.name}');
  print('状态：${task.status}');
  print('下次执行：${task.nextExecution}');
  print('已执行次数：${task.runCount}');
}

// 取消任务
scheduler.cancelTask(taskId);

// 清空所有任务
scheduler.clear();
```

---

## 4️⃣ RuleVisualConfig - 可视化规则配置

### 创建规则

```dart
import 'package:proxypin/event/event.dart';

// 创建条件
final condition = RuleCondition(
  id: 'c1',
  type: ConditionType.httpRequest,
  field: 'responseTime',
  operator: OperatorType.greaterThan,
  value: 2000, // 2 秒
);

// 创建动作
final action = RuleAction(
  id: 'a1',
  type: ActionType.log,
  config: {
    'level': 'warning',
    'message': '检测到慢请求',
  },
);

// 创建规则
final rule = VisualRule(
  id: 'slow_request_alert',
  name: '慢请求告警',
  description: '当响应时间超过 2 秒时记录日志',
  conditions: [condition],
  actions: [action],
  priority: RulePriority.high,
);
```

### 规则验证

```dart
final error = RuleValidator.validate(rule);
if (error != null) {
  print('规则验证失败：$error');
} else {
  print('规则验证通过');
}
```

### 生成预览

```dart
final preview = RulePreviewGenerator.generatePreview(rule);
print(preview);
// 输出:
// **规则**: 慢请求告警
// **描述**: 当响应时间超过 2 秒时记录日志
//
// **当满足以下条件时** (AND):
//   - 响应时间 大于 2000
//
// **执行以下动作**:
//   - 记录日志
```

### 使用内置模板

```dart
final templates = RuleTemplates.getTemplates();

// 模板 1: 慢请求告警
// 模板 2: 错误请求监控
// 模板 3: API 数据导出

for (final template in templates) {
  print('模板：${template.name}');
  print(RulePreviewGenerator.generatePreview(template));
}
```

### 条件操作符

| 操作符 | 说明 | 示例 |
|-------|------|------|
| `equals` | 等于 | `statusCode equals 200` |
| `notEquals` | 不等于 | `method notEquals GET` |
| `contains` | 包含 | `url contains /api/` |
| `startsWith` | 以...开始 | `path startsWith /v1` |
| `endsWith` | 以...结束 | `url endsWith .json` |
| `matches` | 正则匹配 | `url matches ^https://.*` |
| `greaterThan` | 大于 | `responseTime greaterThan 1000` |
| `lessThan` | 小于 | `responseTime lessThan 500` |
| `inList` | 在列表中 | `statusCode inList [200, 201, 204]` |
| `exists` | 存在 | `header exists Content-Type` |

### 动作类型

| 动作类型 | 说明 | 配置参数 |
|---------|------|---------|
| `log` | 记录日志 | `level`, `message` |
| `notify` | 发送通知 | `title`, `body` |
| `stopCapture` | 停止抓包 | - |
| `startCapture` | 开始抓包 | - |
| `exportData` | 导出数据 | `format`, `autoSave` |
| `executeScript` | 执行脚本 | `scriptPath`, `args` |
| `sendWebhook` | 发送 Webhook | `url`, `headers`, `payload` |
| `custom` | 自定义动作 | `handler` |

---

## 🔗 集成示例

### 示例 1: 慢请求自动导出

```dart
// 1. 创建规则
final rule = VisualRule(
  id: 'slow_request_export',
  name: '慢请求自动导出',
  conditions: [
    RuleCondition(
      id: 'c1',
      type: ConditionType.httpRequest,
      field: 'responseTime',
      operator: OperatorType.greaterThan,
      value: 3000,
    ),
  ],
  actions: [
    RuleAction(
      id: 'a1',
      type: ActionType.log,
      config: {'level': 'warning', 'message': '慢请求 detected'},
    ),
    RuleAction(
      id: 'a2',
      type: ActionType.exportData,
      config: {'format': 'har', 'autoSave': true},
    ),
  ],
);

// 2. 注册到规则引擎
// (通过 McpRuleEngine 集成)
```

### 示例 2: 定时备份抓包数据

```dart
// 每天凌晨 3 点备份
scheduler.addCron(
  name: '每日抓包备份',
  cronExpression: '0 3 * * *',
  callback: () async {
    // 导出当前抓包数据
    await executor.executePythonCode('''
import json
from datetime import datetime

# 导出数据逻辑
data = {"timestamp": datetime.now().isoformat(), "count": 100}
print(json.dumps(data))
''');
    
    // 发送通知
    eventBus.publish(Event(
      type: 'system.notification',
      data: {
        'title': '抓包备份完成',
        'body': '已成功备份今日抓包数据',
      },
    ));
  },
);
```

### 示例 3: API 错误监控

```dart
// 订阅 HTTP 响应事件
eventBus.subscribe('http.response', (event) async {
  final statusCode = event.data['statusCode'] as int?;
  
  if (statusCode != null && statusCode >= 500) {
    // 服务器错误，执行告警脚本
    await executor.executePythonCode('''
import requests
import json

webhook_url = "https://hooks.slack.com/xxx"
payload = {
  "text": f"⚠️ 服务器错误：{statusCode}",
  "channel": "#alerts"
}
requests.post(webhook_url, json=payload)
''');
  }
}, filter: (event) {
  final statusCode = event.data['statusCode'] as int?;
  return statusCode != null && statusCode >= 500;
});
```

---

## 📊 最佳实践

### 1. 事件命名规范

```dart
// 推荐：使用点分隔的层次命名
'system.startup'
'http.request.start'
'http.request.complete'
'network.status.changed'

// 避免：扁平命名或过于复杂
'startup'  // 太模糊
'http_request_start_complete_status'  // 太长
```

### 2. 脚本超时设置

```dart
// 根据脚本类型设置合理超时
// 快速脚本：5-10 秒
await executor.executePythonCode('print("quick")', timeoutSeconds: 5);

// 数据处理：30-60 秒
await executor.executePython('/path/to/process.py', timeoutSeconds: 60);

// 网络请求：10-30 秒
await executor.executeShell('/path/to/fetch.sh', timeoutSeconds: 30);
```

### 3. Cron 表达式参考

```
# 每分钟
* * * * *

# 每小时
0 * * * *

# 每天凌晨
0 0 * * *

# 每周一 9 点
0 9 * * 1

# 每月 1 号
0 0 1 * *

# 每 15 分钟
*/15 * * * *

# 工作日 9-18 点每小时
0 9-18 * * 1-5
```

### 4. 规则性能优化

```dart
// 使用高优先级处理关键规则
final criticalRule = VisualRule(
  // ...
  priority: RulePriority.critical,  // 关键规则优先执行
);

// 使用条件逻辑减少误触发
rule.conditionLogic = 'AND';  // 所有条件都满足才触发

// 设置规则过期时间避免累积
rule.expiresAt = DateTime.now().add(Duration(days: 30));
```

---

## 🐛 故障排查

### 事件未触发

1. 检查事件类型是否正确
2. 确认订阅在发布之前
3. 验证过滤器条件

### 脚本执行失败

1. 检查解释器是否安装
2. 验证脚本路径是否正确
3. 查看错误输出 `result.error`
4. 增加超时时间

### 定时任务未执行

1. 确认调度器正在运行
2. 检查任务状态 `task.status`
3. 验证 Cron 表达式格式
4. 查看失败重试次数

---

## 📚 API 参考

### EventBus

| 方法 | 说明 |
|-----|------|
| `subscribe(type, callback, {filter})` | 订阅事件 |
| `subscribeOnce(type, callback)` | 一次性订阅 |
| `unsubscribe(type, callback)` | 取消订阅 |
| `publish(event)` | 发布事件 |
| `getHistory({limit})` | 获取历史事件 |
| `clearHistory()` | 清空历史 |

### ScriptExecutor

| 方法 | 说明 |
|-----|------|
| `executePython(path, {args, env, timeout})` | 执行 Python 文件 |
| `executePythonCode(code, {env, timeout})` | 执行 Python 代码 |
| `executeShell(path, {args, env, timeout})` | 执行 Shell 文件 |
| `executeShellCommand(command, {env, timeout})` | 执行 Shell 命令 |
| `executeJavaScript(path, {args, env, timeout})` | 执行 JS 文件 |
| `executeJavaScriptCode(code, {env, timeout})` | 执行 JS 代码 |
| `checkAllInterpreters()` | 检查解释器可用性 |

### EnhancedScheduler

| 方法 | 说明 |
|-----|------|
| `addOnce({name, executeAt, callback})` | 添加一次性任务 |
| `addPeriodic({name, interval, callback, repeat})` | 添加周期任务 |
| `addCron({name, cronExpression, callback})` | 添加 Cron 任务 |
| `cancelTask(taskId)` | 取消任务 |
| `getTask(taskId)` | 获取任务详情 |
| `getTasks()` | 获取所有任务 |
| `clear()` | 清空所有任务 |

### RuleValidator

| 方法 | 说明 |
|-----|------|
| `validate(rule)` | 验证规则完整性 |
| `validateCondition(condition)` | 验证条件有效性 |

### RulePreviewGenerator

| 方法 | 说明 |
|-----|------|
| `generatePreview(rule)` | 生成规则预览文本 |

### RuleTemplates

| 方法 | 说明 |
|-----|------|
| `getTemplates()` | 获取内置规则模板列表 |

---

## 📄 许可证

Apache License 2.0
