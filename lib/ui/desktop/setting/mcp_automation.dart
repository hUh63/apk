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
import 'package:proxypin/ui/mobile/setting/mcp_automation.dart';

/// 桌面端 MCP 自动化配置页面
///
/// 复用移动端 [McpAutomationPage] 的完整实现，保证桌面/移动行为一致：
/// 6 个 Tab（定时任务 / 事件监听 / 规则引擎 / Prompts / Roots / 工作流），
/// 按 Tab 分派的添加按钮、任务执行选择器、规则增删改、
/// Prompts 参数对话框、Roots 目录浏览器、工作流可视化编辑器、
/// MCP 连接状态指示器。
///
/// 桌面通过子窗口打开时，规则与工作流经文件持久化共享，
/// MCP 运行状态通过 [DesktopMultiWindow.invokeMainWindowMethod] 的
/// `getMcpStatus` 获取主窗口真实状态。
class DesktopMcpAutomation extends StatelessWidget {
  const DesktopMcpAutomation({super.key});

  @override
  Widget build(BuildContext context) {
    return const McpAutomationPage();
  }
}
