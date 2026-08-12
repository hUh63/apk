# MCP 自动化场景增强方案

## 当前 MCP 实现状态

### 已实现功能
- ✅ MCP Server 基础框架 (端口 9010)
- ✅ 协议版本：2026-07-28 (无状态核心)
- ✅ 兼容旧版：2024-11-05 / 2025-11-25
- ✅ Streamable HTTP 支持
- ✅ SSE 连接池管理
- ✅ 心跳定时器

### 已集成的管理模块
```dart
import 'package:proxypin/network/components/manager/hosts_manager.dart';
import 'package:proxypin/network/components/manager/request_block_manager.dart';
import 'package:proxypin/network/components/manager/request_rewrite_manager.dart';
import 'package:proxypin/network/components/manager/script_manager.dart';
import 'package:proxypin/network/components/manager/request_breakpoint_manager.dart';
import 'package:proxypin/network/components/manager/network_condition_manager.dart';
import 'package:proxypin/network/components/manager/environment_manager.dart';
```

---

## 可扩展自动化场景

### 1. 定时任务调度 🔴 高优先级

**场景**: 定时启用/禁用代理、定时抓包、定时备份配置

**实现方案**:
```dart
class McpAutomationScheduler {
  // 定时任务列表
  final List<ScheduledTask> _tasks = [];
  
  // 添加定时任务
  void scheduleTask({
    required String name,
    required DateTime executeAt,
    required VoidCallback action,
    bool repeatDaily = false,
  }) {
    _tasks.add(ScheduledTask(
      name: name,
      executeAt: executeAt,
      action: action,
      repeatDaily: repeatDaily,
    ));
  }
  
  // 示例：每天 23:00 自动备份配置
  void setupDailyBackup() {
    scheduleTask(
      name: 'daily_config_backup',
      executeAt: DateTime.now().copyWith(hour: 23, minute: 0),
      action: () async {
        await ConfigImportExport.autoBackupConfig();
        logger.i('每日配置自动备份完成');
      },
      repeatDaily: true,
    );
  }
  
  // 示例：定时启用代理
  void scheduleProxyEnable(DateTime time) {
    scheduleTask(
      name: 'enable_proxy',
      executeAt: time,
      action: () async {
        await ProxyServer.instance.start();
        logger.i('定时启用代理成功');
      },
    );
  }
}
```

---

### 2. 事件触发自动化 🟡 中优先级

**场景**: 
- 检测到特定 URL 时自动抓包
- 网络状态变化时自动切换代理模式
- 应用启动时自动启用脚本

**实现方案**:
```dart
class McpEventAutomation {
  // 事件监听器
  final Map<String, List<EventCallback>> _listeners = {};
  
  // 监听网络请求事件
  void onHttpRequest(Pattern urlPattern, EventCallback callback) {
    _addListener('http_request:$urlPattern', callback);
  }
  
  // 监听网络状态变化
  void onNetworkStatusChange(NetworkStatus status, EventCallback callback) {
    _addListener('network_status:$status', callback);
  }
  
  // 触发事件
  void _triggerEvent(String eventName, dynamic data) {
    final callbacks = _listeners[eventName] ?? [];
    for (final cb in callbacks) {
      cb(data);
    }
  }
  
  // 示例：检测到 API 请求时自动记录
  void setupApiMonitoring() {
    onHttpRequest(RegExp(r'/api/.*'), (request) {
      logger.i('检测到 API 请求：${request.url}');
      // 自动保存到特定文件夹
      exportRequestToFile(request, '/api_logs/');
    });
  }
}
```

---

### 3. 条件规则引擎 🟡 中优先级

**场景**: 
- 如果网络延迟 > 500ms，自动启用网络延迟模拟
- 如果抓包数量 > 1000，自动清理旧数据
- 如果内存使用 > 80%，自动暂停抓包

**实现方案**:
```dart
class McpConditionEngine {
  final List<ConditionRule> _rules = [];
  
  // 添加条件规则
  void addRule(ConditionRule rule) {
    _rules.add(rule);
    rule.startMonitoring();
  }
  
  // 示例：内存监控规则
  void setupMemoryMonitor() {
    addRule(ConditionRule(
      name: 'memory_threshold',
      condition: () => ProcessInfo.currentMemoryPercent > 80,
      action: () async {
        logger.w('内存使用超过 80%，自动暂停抓包');
        await ProxyServer.instance.pause();
      },
      cooldown: Duration(minutes: 5),
    ));
  }
  
  // 示例：网络延迟监控
  void setupLatencyMonitor() {
    addRule(ConditionRule(
      name: 'latency_threshold',
      condition: () => NetworkConditionManager.currentLatency > 500,
      action: () async {
        logger.i('网络延迟高，启用延迟模拟');
        await NetworkConditionManager.setLatency(1000);
      },
    ));
  }
}

class ConditionRule {
  final String name;
  final bool Function() condition;
  final Future<void> Function() action;
  final Duration? cooldown;
  DateTime? _lastTriggered;
  
  void startMonitoring() {
    Timer.periodic(Duration(seconds: 10), (_) => _check());
  }
  
  Future<void> _check() async {
    if (condition()) {
      if (_isCooldownExpired()) {
        await action();
        _lastTriggered = DateTime.now();
      }
    }
  }
  
  bool _isCooldownExpired() {
    if (cooldown == null) return true;
    if (_lastTriggered == null) return true;
    return DateTime.now().difference(_lastTriggered!) > cooldown!;
  }
}
```

---

### 4. 脚本联动增强 🟢 低优先级

**场景**:
- 脚本执行失败时自动重试
- 多个脚本按顺序执行
- 脚本与抓包联动

**实现方案**:
```dart
class McpScriptWorkflow {
  // 脚本执行链
  Future<void> executeChain(List<String> scriptIds) async {
    for (final scriptId in scriptIds) {
      final script = await ScriptManager.getById(scriptId);
      try {
        await script.execute();
        logger.i('脚本执行成功：$scriptId');
      } catch (e) {
        logger.e('脚本执行失败：$scriptId', error: e);
        // 可选：继续执行下一个或中断
      }
    }
  }
  
  // 脚本与抓包联动
  void setupScriptCaptureTrigger(String scriptId, Pattern urlPattern) {
    McpEventAutomation().onHttpRequest(urlPattern, (_) async {
      final script = await ScriptManager.getById(scriptId);
      await script.execute();
    });
  }
}
```

---

## 实施优先级

| 优先级 | 场景 | 预计工作量 | 用户价值 |
|--------|------|------------|----------|
| 🔴 高 | 定时任务调度 | 2-3 小时 | 自动备份、定时代理 |
| 🔴 高 | 配置变更自动保存 | 1 小时 | 防止配置丢失 |
| 🟡 中 | 事件触发自动化 | 4-5 小时 | 智能抓包、场景联动 |
| 🟡 中 | 条件规则引擎 | 3-4 小时 | 自动优化、资源管理 |
| 🟢 低 | 脚本联动增强 | 2-3 小时 | 高级自动化 |

---

## 快速实现示例

### 配置自动保存（推荐首先实现）

```dart
// 在 Configuration 类中添加
class Configuration {
  // 配置变更时自动保存
  void _autoSaveOnChange() {
    // 防抖：配置变更后 2 秒自动保存
    _saveTimer?.cancel();
    _saveTimer = Timer(Duration(seconds: 2), () async {
      await save();
      logger.d('配置自动保存成功');
    });
  }
  
  Timer? _saveTimer;
}
```

### 每日自动备份（推荐第二个实现）

```dart
// 在 MCP Server 启动时调用
void setupAutomation() {
  // 每日 23:00 自动备份
  Timer.periodic(Duration(days: 1), (_) async {
    final now = DateTime.now();
    final target = DateTime(now.year, now.month, now.day, 23, 0);
    final delay = target.difference(now);
    
    if (delay.isNegative) return;
    
    Timer(delay, () async {
      await ConfigImportExport.autoBackupConfig();
      logger.i('每日自动备份完成');
    });
  });
}
```

---

## 集成建议

1. **第一阶段** (v1.3.2):
   - ✅ 配置变更自动保存
   - ✅ 每日自动备份

2. **第二阶段** (v1.4.0):
   - 定时任务调度框架
   - 基础事件监听

3. **第三阶段** (v1.5.0):
   - 条件规则引擎
   - 完整的事件系统
   - 脚本工作流

---

## 相关文件

- `lib/network/mcp/mcp_server.dart` - MCP 服务器主逻辑
- `lib/network/bin/configuration.dart` - 配置管理
- `lib/network/components/manager/` - 各管理模块
- `lib/utils/` - 工具函数
