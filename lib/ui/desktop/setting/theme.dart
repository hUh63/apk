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
import 'package:flutter/material.dart';
import 'package:proxypin/l10n/app_localizations.dart';
import 'package:proxypin/ui/configuration.dart';

/// 桌面端主题设置菜单
class DesktopThemeSetting extends StatelessWidget {
  final AppConfiguration appConfiguration;

  const DesktopThemeSetting({super.key, required this.appConfiguration});

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    return MenuAnchor(
      builder: (context, controller, child) {
        return IconButton(
          icon: getIcon(),
          tooltip: localizations.theme,
          iconSize: 21,
          onPressed: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
        );
      },
      menuChildren: [
        // Material 3 开关
        CheckboxMenuButton(
          value: appConfiguration.useMaterial3,
          onChanged: (bool? value) {
            appConfiguration.useMaterial3 = value ?? true;
          },
          child: const Text('Material 3'),
        ),
        const Divider(),
        // 跟随系统
        MenuItemButton(
          leadingIcon: const Icon(Icons.cached),
          onPressed: () {
            appConfiguration.themeMode = ThemeMode.system;
          },
          child: Text(localizations.followSystem),
        ),
        // 浅色主题
        MenuItemButton(
          leadingIcon: const Icon(Icons.sunny),
          onPressed: () {
            appConfiguration.themeMode = ThemeMode.light;
          },
          child: Text(localizations.themeLight),
        ),
        // 深色主题
        MenuItemButton(
          leadingIcon: const Icon(Icons.nightlight_outlined),
          onPressed: () {
            appConfiguration.themeMode = ThemeMode.dark;
          },
          child: Text(localizations.themeDark),
        ),
      ],
    );
  }

  Icon getIcon() {
    switch (appConfiguration.themeMode) {
      case ThemeMode.system:
        return const Icon(Icons.cached);
      case ThemeMode.dark:
        return const Icon(Icons.nightlight_outlined);
      case ThemeMode.light:
        return const Icon(Icons.sunny);
    }
  }
}
