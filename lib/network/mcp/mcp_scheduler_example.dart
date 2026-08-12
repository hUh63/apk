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

import 'package:proxypin/network/mcp/mcp_scheduler.dart';
import 'package:proxypin/network/util/logger.dart';

/// MCP 定时任务调度器使用示例
class McpSchedulerExample {
  /// 示例：设置每天凌晨 2 点自动清理缓存
  static void scheduleDailyCacheCleanup() {
    final now = DateTime.now();
    final executeAt = DateTime(now.year, now.month, now.day, 2, 0, 0);
    
    // 如果今天 2 点已过，设置为明天 2 点
    final targetTime = now.isAfter(executeAt) 
        ? executeAt.add(Duration(days: 1)) 
        : executeAt;
    
    McpScheduler().scheduleTask(
      name: '每日缓存清理',
      executeAt: targetTime,
      repeatDaily: true,
      action: () {
        logger.i('执行每日缓存清理任务...');
        // 这里调用实际的缓存清理逻辑
        // CacheManager.clear();
      },
    );
  }

  /// 示例：设置 10 分钟后执行一次性任务
  static void scheduleOneTimeTask() {
    final executeAt = DateTime.now().add(Duration(minutes: 10));
    
    McpScheduler().scheduleTask(
      name: '一次性数据同步',
      executeAt: executeAt,
      repeatDaily: false,
      action: () {
        logger.i('执行一次性数据同步任务...');
        // 这里调用实际的数据同步逻辑
        // DataSync.sync();
      },
    );
  }

  /// 示例：设置每天固定时间导出配置备份
  static void scheduleDailyConfigBackup() {
    final now = DateTime.now();
    final executeAt = DateTime(now.year, now.month, now.day, 23, 0, 0);
    
    final targetTime = now.isAfter(executeAt) 
        ? executeAt.add(Duration(days: 1)) 
        : executeAt;
    
    McpScheduler().scheduleTask(
      name: '每日配置备份',
      executeAt: targetTime,
      repeatDaily: true,
      action: () {
        logger.i('执行每日配置备份任务...');
        // 这里调用实际的配置备份逻辑
        // ConfigManager.backup();
      },
    );
  }

  /// 示例：设置每小时检查一次更新
  static void scheduleHourlyUpdateCheck() {
    final now = DateTime.now();
    final executeAt = DateTime(now.year, now.month, now.day, now.hour + 1, 0, 0);
    
    McpScheduler().scheduleTask(
      name: '每小时更新检查',
      executeAt: executeAt,
      repeatDaily: true, // 这里 repeatDaily 实际上是每天重复，但通过动态设置 executeAt 实现每小时
      action: () {
        logger.i('执行每小时更新检查任务...');
        // 这里调用实际的更新检查逻辑
        // UpdateManager.check();
        
        // 重新调度下一个小时的任务
        scheduleHourlyUpdateCheck();
      },
    );
  }
}
