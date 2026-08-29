# 上报服务器指南

上报服务器可以把抓包请求按自定义格式转发到你的服务端，用于接口监控、自动化测试、数据采集等场景。

## 工作方式

配置一个接收端 URL 后，抓到的请求会按 HTTP 方式转发给你的服务：

- 请求体为 JSON 格式的请求信息（URL、方法、请求头、请求体、状态码、耗时等）；
- 你的服务返回 200 即视为上报成功。

## 配置步骤

1. 「设置 → 上报服务器」进入配置页；
2. 填写接收端 URL 与认证信息（如有）；
3. 打开开关后自动开始上报。

## 接收端示例（Node.js）

```javascript
const http = require('http');
http.createServer((req, res) => {
  let body = '';
  req.on('data', c => body += c);
  req.on('end', () => {
    const item = JSON.parse(body || '{}');
    console.log(item.url, item.status);
    res.end('ok');
  });
}).listen(9000);
```

## 使用建议

- 接收端要尽快返回，避免阻塞抓包主流程；
- 只在测试环境使用，避免把敏感抓包数据发往外部；
- 配合自建内网服务可实现团队的接口用例沉淀。
