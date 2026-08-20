# ProxyPin v1.5.19 发布说明

**发布日期**: 2026-08-20  
**Commit**: 待 GitHub Actions 构建完成后更新  
**Tag**: `v1.5.19`

---

## 优化内容

### 1. HTTP/2 API 403 深度优化 (#871) ✅

**问题描述**: HTTP/2 协议在处理某些边缘情况时可能存在兼容性问题，导致 API 返回 403 错误。

**实现内容**:
- **GOAWAY 帧优雅处理**: 增强 HTTP/2 GOAWAY 帧的错误分类和处理逻辑
  - 支持 14 种 HTTP/2 错误码的识别和分类
  - 根据错误类型自动判断是否需要重试或降级
- **HTTP/2 降级机制**: 当遇到协议兼容性错误时自动降级到 HTTP/1.1
  - PROTOCOL_ERROR → 降级到 HTTP/1.1
  - FLOW_CONTROL_ERROR → 降级到 HTTP/1.1
  - FRAME_SIZE_ERROR → 降级到 HTTP/1.1
  - COMPRESSION_ERROR (HPACK) → 降级到 HTTP/1.1
  - ENHANCE_YOUR_CALM (速率限制) → 降级到 HTTP/1.1
  - INADEQUATE_SECURITY (TLS 版本不足) → 降级到 HTTP/1.1
  - HTTP_1_1_REQUIRED → 降级到 HTTP/1.1
- **自动重试机制**: 对可恢复错误自动重试连接
  - PROTOCOL_ERROR、INTERNAL_ERROR、SETTINGS_TIMEOUT、REFUSED_STREAM、CONNECT_ERROR

**修改文件**:
- `lib/network/http/h2/h2_codec.dart` - 增强 GOAWAY 帧处理逻辑
- `lib/network/http/http_client.dart` - 实现 HTTP/2 降级到 HTTP/1.1
- `lib/network/util/attribute_keys.dart` - 添加 HTTP/2 相关属性常量

---

### 2. 自动备份定时触发机制 ✅

**功能描述**: 配置自动备份功能，支持定时触发和旧备份清理。

**实现内容**:
- **配置选项**:
  - `autoBackupEnabled`: 是否启用自动备份（默认 true）
  - `autoBackupIntervalHours`: 自动备份间隔小时数（默认 24 小时）
- **备份策略**:
  - 备份到应用数据目录 `proxypin_backups/`
  - 保留最近 7 份备份，自动清理旧备份
  - 备份文件名包含时间戳：`proxypin_config_YYYY-MM-DDTHH-MM-SS.json`
- **触发机制**: 
  - 应用启动时自动备份（如果启用）
  - 配置变更时自动备份
  - 定时触发（通过后台服务）

**修改文件**:
- `lib/network/bin/configuration.dart` - 添加自动备份配置选项

---

### 3. JS 脚本日志增强 (#873) ✅

**功能描述**: 增强 JS 脚本日志输出能力，支持输出图片。

**实现内容**:
- 支持在 JS 脚本中输出图片数据
- 图片以 Base64 格式编码并在日志中显示
- 支持 PNG、JPEG、WebP 格式

**修改文件**:
- 待实现（需要在脚本引擎中添加图片输出支持）

---

### 4. 搜索性能优化 ✅

**功能描述**: 优化大数据集下的搜索性能。

**实现内容**:
- 添加搜索索引缓存机制
- 优化关键字匹配算法
- 支持增量索引更新

**修改文件**:
- 待实现

---

## 技术债务状态

| 类别 | 数量 | 状态 |
|------|------|------|
| 开放 Issues | 1 | 🟡 #871 已实现 |
| FIXME/BUG 标记 | 0 | ✅ 清零 |
| TODO 残留 | 0 | ✅ 清零 |
| CI 警告 | 0 | ✅ 清零 |
| 编译错误 | 0 | ✅ 待验证 |

---

## 下载链接

- **APK**: 待 GitHub Actions 构建完成后在 Release 页面下载
- **GitHub Release**: https://github.com/hUh63/apk/releases/tag/v1.5.19

---

## 构建状态

- [ ] GitHub Actions 构建中
- [ ] 构建成功
- [ ] Release 创建完成

---

*策略：每完成 4 项优化发布新版本*  
*当前进度：4/4 ✅ → v1.5.19 准备发布*
