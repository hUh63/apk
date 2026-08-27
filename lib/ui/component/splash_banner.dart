/*
 * 启动横幅 - 美观的应用启动界面
 * 显示应用信息、版本、加载状态
 */

import 'dart:io';

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:proxypin/ui/configuration.dart';

/// 启动横幅页面
class SplashBanner extends StatefulWidget {
  final VoidCallback? onComplete;
  final Duration duration;
  final bool showVersion;
  final bool showFeatures;

  /// 背景模式：default 蓝色渐变 / custom 自定义图片 / transparent 跟随主题背景
  final String backgroundMode;

  /// 自定义背景图片文件（backgroundMode == custom 时使用）
  final File? backgroundImage;

  /// 自定义小字文本（为空时显示版本信息）
  final String? subtitle;

  const SplashBanner({
    super.key,
    this.onComplete,
    this.duration = const Duration(seconds: 2),
    this.showVersion = true,
    this.showFeatures = true,
    this.backgroundMode = 'default',
    this.backgroundImage,
    this.subtitle,
  });

  @override
  State<SplashBanner> createState() => _SplashBannerState();
}

class _SplashBannerState extends State<SplashBanner> with SingleTickerProviderStateMixin {
  double _logoScale = 0.5;
  double _opacity = 0.0;
  int _currentFeatureIndex = 0;
  Timer? _featureTimer;
  
  final List<String> _features = [
    'HTTP/HTTPS 抓包',
    '请求重放与分析',
    '代码生成 (9 种语言)',
    'API 端点识别',
    'HAR 导入导出',
    '性能监控',
  ];

  @override
  void initState() {
    super.initState();
    _startAnimation();
  }

  void _startAnimation() {
    // Logo 缩放动画
    Future.delayed(const Duration(milliseconds: 100), () {
      setState(() {
        _logoScale = 1.0;
        _opacity = 1.0;
      });
    });

    // 特性轮播
    if (widget.showFeatures) {
      _featureTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          _currentFeatureIndex = (_currentFeatureIndex + 1) % _features.length;
        });
      });
    }

    // 完成后回调
    Future.delayed(widget.duration, () {
      if (mounted && widget.onComplete != null) {
        widget.onComplete!();
      }
    });
  }

  @override
  void dispose() {
    _featureTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foregroundColor = backgroundMode == 'transparent' ? (isDark ? Colors.white : Colors.blue.shade700) : Colors.white;

    Widget? backgroundLayer;
    if (backgroundMode == 'custom' && backgroundImage != null) {
      // 自定义图片背景 + 深色遮罩，保证文字可读
      backgroundLayer = Container(
        decoration: BoxDecoration(
          image: DecorationImage(image: FileImage(backgroundImage!), fit: BoxFit.cover),
        ),
      );
    } else if (backgroundMode == 'default') {
      backgroundLayer = Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade900,
              Colors.blue.shade700,
              Colors.lightBlue.shade400,
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundMode == 'transparent' ? Theme.of(context).scaffoldBackgroundColor : null,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (backgroundLayer != null) backgroundLayer,
          // 自定义图片上加遮罩，保证文字可读
          if (backgroundMode == 'custom' && backgroundImage != null)
            Container(color: Colors.black.withValues(alpha: 0.45)),
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                AnimatedScale(
                  scale: _logoScale,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.elasticOut,
                  child: AnimatedOpacity(
                    opacity: _opacity,
                    duration: const Duration(milliseconds: 500),
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: backgroundMode == 'transparent'
                            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: backgroundMode == 'transparent'
                            ? null
                            : [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                      ),
                      child: Center(
                        child: Icon(
                          Icons.security,
                          size: 70,
                          color: backgroundMode == 'transparent'
                              ? Theme.of(context).colorScheme.primary
                              : Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ),
                ),
              
              const SizedBox(height: 40),
              
              // 应用名称
              AnimatedOpacity(
                opacity: _opacity,
                duration: const Duration(milliseconds: 500),
                child: Text(
                  'ProxyPin',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: foregroundColor,
                    letterSpacing: 2,
                  ),
                ),
              ),

              if (widget.showVersion) ...[
                const SizedBox(height: 10),
                AnimatedOpacity(
                  opacity: _opacity,
                  duration: const Duration(milliseconds: 500),
                  child: Text(
                    widget.subtitle?.isNotEmpty == true
                        ? widget.subtitle!
                        : 'v${AppConfiguration.version} · 开源免费抓包工具',
                    style: TextStyle(
                      fontSize: 14,
                      color: foregroundColor.withOpacity(0.8),
                    ),
                  ),
                ),
              ],
              
              const SizedBox(height: 60),
              
              // 特性轮播
              if (widget.showFeatures) ...[
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.3),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: Text(
                    _features[_currentFeatureIndex],
                    key: ValueKey(_currentFeatureIndex),
                    style: TextStyle(
                      fontSize: 18,
                      color: foregroundColor.withOpacity(0.9),
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // 指示器
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _features.length,
                    (index) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: index == _currentFeatureIndex
                            ? foregroundColor
                            : foregroundColor.withOpacity(0.3),
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 60),

              // 加载指示器
              AnimatedOpacity(
                opacity: _opacity,
                duration: const Duration(milliseconds: 500),
                child: Column(
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '正在启动...',
                      style: TextStyle(
                        fontSize: 14,
                        color: foregroundColor.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // 底部信息
              AnimatedOpacity(
                opacity: _opacity,
                duration: const Duration(milliseconds: 500),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: Text(
                    '© 2023 Hongen Wang. All rights reserved.',
                    style: TextStyle(
                      fontSize: 12,
                      color: foregroundColor.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ));
  }
}

/// 启动横幅管理器
class SplashBannerManager {
  static final SplashBannerManager _instance = SplashBannerManager._internal();
  factory SplashBannerManager() => _instance;
  SplashBannerManager._internal();

  bool _hasShown = false;
  DateTime? _lastShownAt;

  /// 是否需要显示启动横幅
  bool shouldShow() {
    // 首次启动或距离上次启动超过 24 小时
    if (!_hasShown) return true;
    if (_lastShownAt == null) return true;
    
    final hoursSinceLastShow = DateTime.now().difference(_lastShownAt!).inHours;
    return hoursSinceLastShow >= 24;
  }

  /// 标记已显示
  void markAsShown() {
    _hasShown = true;
    _lastShownAt = DateTime.now();
  }

  /// 重置状态 (用于重新显示)
  void reset() {
    _hasShown = false;
  }
}
