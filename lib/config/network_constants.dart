/// ProxyPin 网络配置常量
/// 
/// 集中管理所有硬编码的网络配置值，便于维护和修改
library;

/// 本地回环地址 (localhost)
const String localhostIP = '127.0.0.1';

/// 任意地址绑定 (所有网络接口)
const String anyIP = '0.0.0.0';

/// HTTP 默认端口
const int httpPort = 80;

/// HTTPS 默认端口
const int httpsPort = 443;

/// 本地主机名
const String localhost = 'localhost';

/// 代理 bypass 列表 (本地和私有网络)
const String proxyBypassList = 'localhost;127.0.0.1;10.0.0.0/8;172.16.0.0/12;192.168.0.0/16';

/// 特殊代理域名 (用于证书安装等内部功能)
const String proxyPinDomain = 'proxy.pin';

/// 代理 URL 格式
String proxyUrl(String host, int port) => 'http://$host:$port';

/// SSL 安装 URL
String sslInstallUrl(int port) => 'http://$localhostIP:$port/ssl';
