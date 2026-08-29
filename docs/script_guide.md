# 脚本开发指南

脚本可以拦截并修改代理经过的请求与响应，适合 mock 数据、改写参数、自动加签、注入测试数据等场景。

## 工作方式

每个脚本是一个 JavaScript 文件，引擎提供两个钩子，按需实现：

```javascript
// 请求发出前调用，返回修改后的请求；返回 null 表示不拦截
function onRequest(request) {
  return request;
}

// 响应返回前调用，返回修改后的响应
function onResponse(request, response) {
  return response;
}
```

## 常用对象字段

### 请求对象 request

| 字段 / 方法 | 说明 |
|---|---|
| `request.url` | 完整请求地址 |
| `request.method` | GET / POST 等 |
| `request.headers` | 请求头，可直接赋值修改 |
| `request.body` | 请求体文本 |
| `request.queryParameter` | 查询参数 |

### 响应对象 response

| 字段 / 方法 | 说明 |
|---|---|
| `response.status.code` | 状态码，可直接赋值 |
| `response.headers` | 响应头 |
| `response.body` | 响应体文本 |

## 示例

### 修改响应状态码

```javascript
function onResponse(request, response) {
  response.status.code = 200;
  return response;
}
```

### Mock 一段 JSON 数据

```javascript
function onResponse(request, response) {
  if (request.url.indexOf("/api/user") > -1) {
    response.body = JSON.stringify({
      id: 1,
      name: "ProxyPin"
    });
    response.headers["content-type"] = "application/json";
  }
  return response;
}
```

### 给请求统一加签名头

```javascript
function onRequest(request) {
  request.headers["x-sign"] = "demo";
  return request;
}
```

## 使用建议

- 脚本按启用状态依次执行，多个脚本同时启用时会链式生效。
- 修改 JSON 时建议先解析再改字段，避免直接拼接字符串。
- 脚本异常会跳过该脚本并记录日志，可在「工具箱 → 性能/日志」中排查。
