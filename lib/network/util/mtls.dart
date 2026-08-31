/*
 * 双向认证 mTLS（上游 #366）
 * 与目标服务器建立 TLS 时提供客户端证书（PEM 格式：证书链 + 未加密私钥）。
 * Dart SecurityContext 不支持 PKCS12 与加密私钥，故要求 PEM。
 */

import 'dart:convert';
import 'dart:io';

import 'package:proxypin/network/util/logger.dart';
import 'package:proxypin/storage/path.dart';

class Mtls {
  Mtls._();

  static SecurityContext? _context;
  static String? _chainPath;
  static String? _keyPath;

  /// 当前是否已加载客户端证书
  static bool get isLoaded => _context != null;

  /// 获取可用的 SecurityContext（未配置或加载失败返回 null，走普通握手）
  static SecurityContext? get securityContext => _context;

  /// 从 PEM 文件加载客户端证书链与私钥
  static Future<bool> load(String chainPath, String keyPath) async {
    try {
      final chainBytes = await File(chainPath).readAsBytes();
      final keyBytes = await File(keyPath).readAsBytes();

      final context = SecurityContext(withTrustedRoots: true);
      context.useCertificateChainBytes(chainBytes);
      context.usePrivateKeyBytes(keyBytes);

      _context = context;
      _chainPath = chainPath;
      _keyPath = keyPath;
      logger.i('mTLS 客户端证书加载成功');
      return true;
    } catch (e) {
      logger.e('mTLS 客户端证书加载失败', error: e);
      _context = null;
      return false;
    }
  }

  /// 卸载
  static void unload() {
    _context = null;
    _chainPath = null;
    _keyPath = null;
  }

  /// 应用启动后按配置恢复
  static Future<void> restore(String? chainPath, String? keyPath) async {
    if (chainPath == null || keyPath == null || chainPath.isEmpty || keyPath.isEmpty) return;
    await load(chainPath, keyPath);
  }

  /// 把选择的证书文件复制到应用目录持久化，返回新路径
  static Future<String> persist(String sourcePath, String name) async {
    final source = File(sourcePath);
    final target = await Paths.getPath(name);
    await source.copy(target.path);
    return target.path;
  }

  /// 校验 PEM 文件大致格式
  static bool looksLikePem(String path, String beginMarker) {
    try {
      final content = File(path).readAsStringSync();
      return content.contains('-----BEGIN $beginMarker');
    } catch (_) {
      return false;
    }
  }

  static String? get chainPath => _chainPath;
  static String? get keyPath => _keyPath;

  /// 调试用：证书指纹摘要
  static String? get fingerprint {
    final ctx = _context;
    if (ctx == null) return null;
    return base64Encode(utf8.encode('$_chainPath|$_keyPath')).substring(0, 12);
  }
}
