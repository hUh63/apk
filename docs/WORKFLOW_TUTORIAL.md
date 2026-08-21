# ProxyPin 工作流编排教程

> 通过可视化编排实现复杂自动化任务

---

## 📖 目录

1. [入门示例](#入门示例)
2. [进阶技巧](#进阶技巧)
3. [实战案例](#实战案例)
4. [故障排查](#故障排查)

---

## 入门示例

### 示例 1：简单的顺序工作流

**目标**: 依次执行 3 个脚本

```
开始 → 节点 1 → 节点 2 → 节点 3 → 结束
```

**配置**:

```json
{
  "id": "simple_sequence",
  "name": "简单顺序工作流",
  "nodes": [
    {
      "id": "step1",
      "name": "步骤 1",
      "scriptType": "javascript",
      "script": "logger.i('执行步骤 1'); return 'step1_result';"
    },
    {
      "id": "step2",
      "name": "步骤 2",
      "scriptType": "javascript",
      "script": "logger.i('执行步骤 2'); return 'step2_result';",
      "dependencies": ["step1"]
    },
    {
      "id": "step3",
      "name": "步骤 3",
      "scriptType": "javascript",
      "script": "logger.i('执行步骤 3'); return 'step3_result';",
      "dependencies": ["step2"]
    }
  ]
}
```

---

### 示例 2：并行执行工作流

**目标**: 同时执行 3 个独立任务

```
        → 节点 A →
开始    → 节点 B →  汇聚 → 结束
        → 节点 C →
```

**配置**:

```json
{
  "id": "parallel_workflow",
  "name": "并行执行工作流",
  "nodes": [
    {
      "id": "task_a",
      "name": "任务 A",
      "scriptType": "javascript",
      "script": "await api.get('/endpoint-a');"
    },
    {
      "id": "task_b",
      "name": "任务 B",
      "scriptType": "javascript",
      "script": "await api.get('/endpoint-b');"
    },
    {
      "id": "task_c",
      "name": "任务 C",
      "scriptType": "javascript",
      "script": "await api.get('/endpoint-c');"
    },
    {
      "id": "aggregate",
      "name": "结果汇聚",
      "scriptType": "javascript",
      "script": "logger.i('所有任务完成');",
      "dependencies": ["task_a", "task_b", "task_c"]
    }
  ],
  "executionMode": "parallel"
}
```

---

## 进阶技巧

### 1. 变量传递

节点之间可以通过返回值传递数据：

```javascript
// 节点 1：获取 Token
const token = await api.login('user', 'pass');
return { token: token };

// 节点 2：使用 Token（自动接收上一节点的返回值）
const token = inputData.token;
const data = await api.get('/protected', {
  headers: { Authorization: `Bearer ${token}` }
});
return data;
```

### 2. 条件分支

虽然工作流本身不支持条件分支，但可以在脚本中实现：

```javascript
// 条件执行节点
const data = await api.get('/check-status');

if (data.status === 'active') {
  await api.post('/send-notification', { message: '状态正常' });
} else {
  await api.post('/send-alert', { message: '状态异常' });
}

return data;
```

### 3. 循环处理

```javascript
// 遍历列表并处理
const items = await api.get('/items');

for (const item of items) {
  try {
    await api.post('/process', { id: item.id });
    logger.i(`处理完成：${item.id}`);
  } catch (error) {
    logger.e(`处理失败：${item.id} - ${error.message}`);
  }
}

return { total: items.length, processed: items.length };
```

### 4. 错误恢复

```javascript
// 带重试的请求
async function requestWithRetry(url, maxRetries = 3) {
  let lastError;
  
  for (let i = 0; i < maxRetries; i++) {
    try {
      return await api.get(url);
    } catch (error) {
      lastError = error;
      logger.w(`第${i + 1}次重试失败`);
      await sleep(1000 * (i + 1)); // 递增延迟
    }
  }
  
  throw lastError;
}

const result = await requestWithRetry('/flaky-endpoint');
return result;
```

---

## 实战案例

### 案例 1：API 自动化测试

**场景**: 测试用户登录→获取数据→验证结果完整流程

```json
{
  "id": "api_test_suite",
  "name": "API 自动化测试套件",
  "description": "完整的 API 测试流程",
  "nodes": [
    {
      "id": "setup",
      "name": "测试准备",
      "scriptType": "javascript",
      "script": "logger.i('开始测试套件'); return { startTime: Date.now() };"
    },
    {
      "id": "login",
      "name": "用户登录",
      "scriptType": "javascript",
      "script": "const token = await api.login('{{username}}', '{{password}}'); assert(token); return { token };",
      "dependencies": ["setup"]
    },
    {
      "id": "fetch_user_info",
      "name": "获取用户信息",
      "scriptType": "javascript",
      "script": "const info = await api.get('/user', {headers: {Authorization: 'Bearer {{login.token}}'}}); return info;",
      "dependencies": ["login"]
    },
    {
      "id": "fetch_orders",
      "name": "获取订单列表",
      "scriptType": "javascript",
      "script": "const orders = await api.get('/orders', {headers: {Authorization: 'Bearer {{login.token}}'}}); return orders;",
      "dependencies": ["login"]
    },
    {
      "id": "validate",
      "name": "数据验证",
      "scriptType": "javascript",
      "script": "assert(fetch_user_info.id); assert(orders.length >= 0); logger.i('验证通过');",
      "dependencies": ["fetch_user_info", "fetch_orders"]
    },
    {
      "id": "cleanup",
      "name": "清理资源",
      "scriptType": "javascript",
      "script": "await api.logout(); logger.i('测试完成，耗时：' + (Date.now() - setup.startTime) + 'ms');",
      "dependencies": ["validate"]
    }
  ],
  "variables": {
    "username": "test_user",
    "password": "test_password"
  },
  "retryConfig": {
    "maxRetries": 2,
    "retryInterval": 2000
  }
}
```

---

### 案例 2：数据导出工作流

**场景**: 定时导出数据并上传到云存储

```json
{
  "id": "data_export_workflow",
  "name": "数据导出工作流",
  "description": "导出 HAR 数据并上传到云存储",
  "nodes": [
    {
      "id": "export_har",
      "name": "导出 HAR 数据",
      "scriptType": "javascript",
      "script": "const harPath = '/sdcard/ProxyPin/export_' + Date.now() + '.har'; await mcp.exportHar(harPath); return { path: harPath };"
    },
    {
      "id": "compress_file",
      "name": "压缩文件",
      "scriptType": "shell",
      "script": "gzip {{export_har.path}} && echo '{{export_har.path}}.gz'",
      "dependencies": ["export_har"]
    },
    {
      "id": "upload_cloud",
      "name": "上传云存储",
      "scriptType": "javascript",
      "script": "const result = await api.upload('{{cloud_bucket}}', compress_file); return result;",
      "dependencies": ["compress_file"]
    },
    {
      "id": "send_notification",
      "name": "发送通知",
      "scriptType": "javascript",
      "script": "await mcp.notify('数据导出完成', '文件已上传：' + upload_cloud.url);",
      "dependencies": ["upload_cloud"]
    },
    {
      "id": "cleanup_local",
      "name": "清理本地文件",
      "scriptType": "shell",
      "script": "rm -f {{export_har.path}} {{compress_file}}",
      "dependencies": ["upload_cloud"]
    }
  ],
  "variables": {
    "cloud_bucket": "my-backup-bucket"
  }
}
```

---

### 案例 3：请求拦截工作流

**场景**: 拦截特定请求并修改响应

```json
{
  "id": "request_intercept_workflow",
  "name": "请求拦截工作流",
  "description": "拦截 API 请求并返回模拟数据",
  "trigger": {
    "type": "requestRule",
    "ruleId": "intercept_api_calls"
  },
  "nodes": [
    {
      "id": "log_request",
      "name": "记录请求",
      "scriptType": "javascript",
      "script": "logger.i('拦截请求：' + request.url); return request;"
    },
    {
      "id": "check_cache",
      "name": "检查缓存",
      "scriptType": "javascript",
      "script": "const cached = await mcp.getCache(request.url); return { hit: cached != null, data: cached };",
      "dependencies": ["log_request"]
    },
    {
      "id": "return_cached",
      "name": "返回缓存数据",
      "scriptType": "javascript",
      "script": "if (check_cache.hit) { response.body = check_cache.data; response.fromCache = true; } return response;",
      "dependencies": ["check_cache"]
    },
    {
      "id": "forward_request",
      "name": "转发请求",
      "scriptType": "javascript",
      "script": "if (!check_cache.hit) { const resp = await api.forward(request); await mcp.setCache(request.url, resp.body); return resp; }",
      "dependencies": ["check_cache"]
    }
  ]
}
```

---

### 案例 4：安全扫描工作流

**场景**: 定期扫描请求中的敏感信息泄露

```json
{
  "id": "security_scan_workflow",
  "name": "安全扫描工作流",
  "description": "检测请求中的敏感信息",
  "nodes": [
    {
      "id": "scan_headers",
      "name": "扫描请求头",
      "scriptType": "javascript",
      "script": "const sensitive = ['authorization', 'cookie', 'x-api-key']; const found = request.headers.keys().filter(k => sensitive.includes(k.toLowerCase())); return found;"
    },
    {
      "id": "scan_body",
      "name": "扫描请求体",
      "scriptType": "javascript",
      "script": "const patterns = [/password/i, /token/i, /secret/i]; const found = patterns.filter(p => p.test(request.body)); return found;",
      "dependencies": ["scan_headers"]
    },
    {
      "id": "generate_report",
      "name": "生成报告",
      "scriptType": "javascript",
      "script": "const report = { url: request.url, headerIssues: scan_headers, bodyIssues: scan_body, timestamp: Date.now() }; return report;",
      "dependencies": ["scan_body"]
    },
    {
      "id": "alert_if_risky",
      "name": "风险告警",
      "scriptType": "javascript",
      "script": "if (generate_report.headerIssues.length > 0 || generate_report.bodyIssues.length > 0) { await mcp.notify('安全风险', JSON.stringify(generate_report)); }",
      "dependencies": ["generate_report"]
    }
  ]
}
```

---

## 故障排查

### 问题 1：工作流无法启动

**症状**: 点击执行按钮无反应

**排查步骤**:
1. 检查工作流是否启用
2. 查看节点脚本是否有语法错误
3. 检查循环依赖（使用拓扑排序验证）

```javascript
// 调试：在第一个节点添加
logger.d('工作流启动');
logger.d('输入数据：' + JSON.stringify(inputData));
```

---

### 问题 2：节点执行失败

**症状**: 某个节点执行报错

**排查步骤**:
1. 查看执行历史中的错误堆栈
2. 检查依赖节点是否正常完成
3. 验证变量替换是否正确

```javascript
// 调试：添加详细错误处理
try {
  // 业务逻辑
} catch (error) {
  logger.e('节点执行失败：' + error.message);
  logger.e('堆栈：' + error.stack);
  throw error;
}
```

---

### 问题 3：变量替换不生效

**症状**: `{{variable}}` 保持原样未替换

**排查步骤**:
1. 检查变量名是否匹配（区分大小写）
2. 确认变量在工作流级别定义
3. 验证节点依赖顺序

```json
{
  "variables": {
    "baseUrl": "https://api.example.com",  // ✅ 正确
    "BaseURL": "https://api.example.com"   // ❌ 大小写不一致
  }
}
```

---

### 问题 4：并行执行结果不一致

**症状**: 多次执行结果不同

**原因**: 并行节点执行顺序不确定

**解决方案**:
1. 确保并行节点之间无数据依赖
2. 在汇聚节点处理数据合并
3. 必要时改为顺序执行

```javascript
// 汇聚节点：安全合并并行结果
const allResults = [task_a, task_b, task_c].filter(r => r != null);
return { results: allResults, total: allResults.length };
```

---

## 性能优化建议

### 1. 减少不必要的节点

```
❌ 避免：每个简单操作都创建节点
✅ 推荐：相关操作合并到同一节点
```

### 2. 合理使用并行

```
❌ 避免：有依赖关系的节点并行
✅ 推荐：独立任务并行执行
```

### 3. 控制重试次数

```json
{
  "retryConfig": {
    "maxRetries": 3,        // 不宜过大
    "retryInterval": 2000   // 避免过短
  }
}
```

### 4. 及时清理资源

```javascript
// 在最后节点清理临时文件/连接
await cleanup();
logger.i('工作流完成，资源已清理');
```

---

## 附录

### 内置 API 参考

| API | 描述 | 示例 |
|-----|------|------|
| `api.get(url, options)` | GET 请求 | `await api.get('/users')` |
| `api.post(url, data)` | POST 请求 | `await api.post('/login', {user, pass})` |
| `mcp.notify(title, content)` | 发送通知 | `mcp.notify('完成', '任务成功')` |
| `mcp.exportHar(path)` | 导出 HAR | `await mcp.exportHar('/sdcard/data.har')` |
| `mcp.getCache(key)` | 获取缓存 | `const data = await mcp.getCache('key')` |
| `mcp.setCache(key, value)` | 设置缓存 | `await mcp.setCache('key', data)` |
| `logger.i/w/e/d()` | 日志记录 | `logger.i('信息')` |

### 脚本执行上下文

```javascript
// 可用变量
inputData      // 上一节点的返回值
variables      // 工作流变量
request        // 当前请求（拦截场景）
response       // 当前响应（拦截场景）

// 可用函数
assert()       // 断言
sleep(ms)      // 延迟
Date.now()     // 时间戳
JSON.parse/stringify()  // JSON 处理
```
