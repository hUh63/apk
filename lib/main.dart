/*
 * Copyright 2023 Hongen Wang All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:code_forge/code_forge.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:proxypin/network/bin/configuration.dart';
import 'package:proxypin/network/components/manager/environment_manager.dart';
import 'package:proxypin/ui/component/chinese_font.dart';
import 'package:proxypin/ui/component/multi_window_compat.dart';
import 'package:proxypin/ui/component/multi_window.dart';
import 'package:proxypin/ui/component/splash_banner.dart';
import 'package:proxypin/ui/configuration.dart';
import 'package:proxypin/ui/desktop/desktop.dart';
import 'package:proxypin/ui/mobile/mobile.dart';
import 'package:proxypin/utils/desktop_support.dart';
import 'package:proxypin/utils/navigator.dart';
import 'package:proxypin/utils/platform.dart';
import 'package:window_manager/window_manager.dart';

import 'l10n/app_localizations.dart';

///主入口
///@author wanghongen
void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();

  final windowController = Platforms.isDesktop() ? await DesktopMultiWindow.ensureInitialized() : null;

  var instance = AppConfiguration.instance;

  //多窗口
  if (args.firstOrNull == 'multi_window') {
    final windowId = windowController!.windowId;
    final argument =
        windowController.arguments.isEmpty ? const {} : jsonDecode(windowController.arguments) as Map<String, dynamic>;
    DesktopMultiWindow.initializeFromArguments(argument);
    var appConfiguration = await instance;

    if (Platform.isMacOS) {
      windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    }
    if (appConfiguration.themeMode != ThemeMode.system) {
      windowManager.setBrightness(appConfiguration.themeMode == ThemeMode.dark ? Brightness.dark : Brightness.light);
    }
    runApp(FluentApp(multiWindow(windowId, argument), appConfiguration));
    return;
  }

  var configuration = Configuration.instance;
  // 预热环境变量,避免第一个请求命中时才 IO
  unawaited(EnvironmentManager.preload());
  //移动端
  if (Platforms.isMobile()) {
    var appConfiguration = await instance;
    var config = await configuration;
    runApp(FluentApp(
        SplashGate(child: MobileHomePage(config, appConfiguration), appConfiguration: appConfiguration),
        appConfiguration));
    return;
  }

  var appConfiguration = await instance;
  if (Platforms.isDesktop()) {
    await DesktopSupport.initialize(appConfiguration);
  }

  runApp(FluentApp(DesktopHomePage(await configuration, appConfiguration), appConfiguration));
}

/// 启动页门控：先展示 SplashBanner（Logo 动画 + 版本信息），完成后切换到主页面。
/// 仅移动端启用（手机应用启动页符合用户预期；桌面端保持直接进入，不拖慢启动）。
/// 支持偏好设置自定义：开关、时长、背景（默认/自定义图片/透明）、自定义小字。
class SplashGate extends StatefulWidget {
  final Widget child;
  final AppConfiguration appConfiguration;

  const SplashGate({super.key, required this.child, required this.appConfiguration});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _showSplash = true;

  @override
  Widget build(BuildContext context) {
    if (!_showSplash) return widget.child;

    final config = widget.appConfiguration;
    // 开关关闭 或 背景选"原生启动页(off)"时不叠加自定义启动页
    if (!config.splashEnabled || config.splashBackground == 'off') {
      return widget.child;
    }

    final backgroundFile =
        config.splashBackground == 'custom' && config.splashBackgroundPath != null
            ? File(config.splashBackgroundPath!)
            : null;

    return SplashBanner(
      duration: Duration(milliseconds: config.splashDurationMs.clamp(500, 10000)),
      backgroundMode: config.splashBackground,
      backgroundImage: backgroundFile,
      subtitle: config.splashSubtitle,
      onComplete: () {
        if (mounted) setState(() => _showSplash = false);
      },
    );
  }
}

class FluentApp extends StatelessWidget {
  final Widget home;
  final AppConfiguration appConfiguration;

  const FluentApp(this.home, this.appConfiguration, {super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
        valueListenable: appConfiguration.globalChange,
        builder: (_, current, __) {
          // 莫奈取色：Android 12+ 从壁纸提取动态色板（monetEnabled 关闭或低版本回退到固定主题）
          return DynamicColorBuilder(
              builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
            final useMonet = appConfiguration.monetEnabled;
            final ThemeData lightTheme;
            final ThemeData darkTheme;
            if (useMonet && lightDynamic != null) {
              lightTheme = theme(Brightness.light)
                  .copyWith(colorScheme: lightDynamic.harmonized());
            } else {
              lightTheme = theme(Brightness.light);
            }
            if (useMonet && darkDynamic != null) {
              darkTheme = theme(Brightness.dark)
                  .copyWith(colorScheme: darkDynamic.harmonized());
            } else {
              darkTheme = theme(Brightness.dark);
            }
            return MaterialApp(
              title: 'ProxyPin',
              debugShowCheckedModeBanner: false,
              navigatorKey: navigatorHelper.navigatorKey,
              theme: lightTheme,
              darkTheme: darkTheme,
              themeMode: appConfiguration.themeMode,
              locale: appConfiguration.language,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: home,
            );
          });
        });
  }

  ThemeData theme(Brightness brightness) {
    bool useMaterial3 = appConfiguration.useMaterial3;
    bool isDark = brightness == Brightness.dark;

    Color? themeColor = isDark ? appConfiguration.themeColor : appConfiguration.themeColor;
    Color? cardColor = isDark ? Color(0XFF3C3C3C) : Colors.white;
    Color? surfaceContainer = isDark ? Colors.grey[800] : Colors.white;

    Color? secondary = useMaterial3 ? null : themeColor;
    if (themeColor is MaterialColor) {
      secondary = themeColor[500];
    }

    var colorScheme = ColorScheme.fromSeed(
      brightness: brightness,
      seedColor: themeColor,
      primary: themeColor,
      surface: cardColor,
      secondary: secondary,
      onPrimary: isDark ? Colors.white : null,
      surfaceContainer: surfaceContainer,
      surfaceContainerHigh: surfaceContainer,
    );

    var themeData =
        ThemeData(brightness: brightness, useMaterial3: appConfiguration.useMaterial3, colorScheme: colorScheme);

    if (!appConfiguration.useMaterial3) {
      themeData = themeData.copyWith(
        appBarTheme: themeData.appBarTheme.copyWith(
          iconTheme: themeData.iconTheme.copyWith(size: 20),
          backgroundColor: themeData.canvasColor,
          elevation: 0,
          titleTextStyle: themeData.textTheme.titleMedium,
        ),
        tabBarTheme: themeData.tabBarTheme.copyWith(
          labelColor: themeData.colorScheme.primary,
          indicatorColor: themeColor,
          unselectedLabelColor: themeData.textTheme.titleMedium?.color,
        ),
      );
    }

    if (Platform.isWindows) {
      themeData = themeData.useSystemChineseFont();
    }

    return themeData.copyWith(
        dialogTheme:
            themeData.dialogTheme.copyWith(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
  }
}
