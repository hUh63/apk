# HTTP/2 兼容性优化方案 (#871)

## 问题分析
HTTP/2 协议在处理某些边缘情况时可能存在兼容性问题，包括：
1. 大文件传输时的流控制
2. HPACK 头部压缩的边界情况
3. 多路复用时的流优先级处理
4. GOAWAY 帧的优雅处理

## 当前实现
- `lib/network/http/h2/h2_codec.dart` - HTTP/2 编解码器
- `lib/network/http/h2/frame.dart` - 帧处理
- `lib/network/http/h2/hpack/` - HPACK 头部压缩
- `lib/network/http/h2/setting.dart` - 设置管理

## 优化建议

### 1. 增强流控制 (#871)
```dart
// 添加流窗口大小监控
void updateWindowSize(int streamId, int size) {
  if (size <= 0) {
    // 触发 WINDOW_UPDATE 帧
    sendWindowUpdate(streamId, -size + initialWindowSize);
  }
}
```

### 2. HPACK 压缩优化
- 动态调整头部表大小
- 优化常用头部的缓存策略

### 3. GOAWAY 优雅处理
```dart
// 收到 GOAWAY 后停止创建新流，等待现有流完成
void handleGoaway(FrameHeader header, Uint8List payload) {
  lastStreamId = readInt32(payload, 0);
  errorCode = readInt32(payload, 4);
  isGracefulShutdown = true;
  // 停止接收新流，等待现有流完成
}
```

### 4. 错误恢复机制
- 添加帧解析错误的重试逻辑
- 连接重置时的自动重连

## 实施优先级
1. 🔴 GOAWAY 优雅处理 - 避免连接突然中断
2. 🟡 流控制优化 - 提高大文件传输稳定性
3. 🟢 HPACK 优化 - 提升性能
4. 🟢 错误恢复 - 增强鲁棒性

## 相关文件
- `lib/network/http/h2/h2_codec.dart`
- `lib/network/http/h2/frame.dart`
- `lib/network/channel/channel_dispatcher.dart`
