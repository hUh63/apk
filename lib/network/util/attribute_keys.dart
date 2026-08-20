/// @author wanghongen
/// 2023/5/23
interface class AttributeKeys {
  static const String host = "HOST";
  static const String domain = "DOMAIN";
  static const String uri = "URI";
  static const String request = "REQUEST";
  static const String remote = "REMOTE";
  static const String proxyInfo = "PROXY_INFO";
  static const String socks5Proxy = "SOCKS5_PROXY";
  static const String processInfo = "PROCESS_INFO";
  static const String skipCapture = "SKIP_CAPTURE";
  
  // HTTP/2 相关属性
  static const String h2FallbackToHttp1 = "H2_FALLBACK_TO_HTTP1"; // HTTP/2 降级到 HTTP/1.1
  static const String h2ShouldRetry = "H2_SHOULD_RETRY"; // HTTP/2 连接需要重试
}
