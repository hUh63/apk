package com.network.proxy.plugin

import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Base64
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.Inet4Address
import java.net.NetworkInterface
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * MCP Plugin for Flutter
 *
 * Bridges MCP (Model Context Protocol) commands from the Dart side to Android native
 * accessibility and shell capabilities. Registers a MethodChannel "com.proxy/mcpScreen".
 *
 * Supported methods:
 * - getDeviceInfo: returns device model, brand, Android version, WiFi IP, root/accessibility status
 * - getCurrentActivity: returns the current foreground activity
 * - dumpUi: dumps the current UI hierarchy (via accessibility service or root uiautomator)
 * - tap: performs a tap at (x, y)
 * - click: performs a long press at (x, y) for a given duration
 * - swipe: performs a swipe from (x1,y1) to (x2,y2)
 * - keyEvent: performs a global action (HOME/BACK/RECENTS/POWER/MENU)
 * - inputText: sets text on the focused element
 * - screenshot: takes a screenshot (requires root)
 * - openAccessibilitySettings: opens Android accessibility settings
 * - shell: executes a shell command (with or without su)
 *
 * Falls back to root (su) commands when the accessibility service is not available.
 */
class McpPlugin : FlutterPlugin {

    companion object {
        private const val CHANNEL_NAME = "com.proxy/mcpScreen"
    }

    private var context: Context? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        MethodChannel(binding.binaryMessenger, CHANNEL_NAME).setMethodCallHandler { call, result ->
            Thread {
                try {
                    val method = call.method
                    val args = (call.arguments as? Map<*, *>)?.mapKeys { it.key.toString() } ?: emptyMap()
                    val response = handleMethod(method, args)
                    result.success(response)
                } catch (e: Exception) {
                    result.error("MCP_ERROR", e.message, null)
                }
            }.start()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = null
    }

    /**
     * Main dispatch method for handling MCP tool calls.
     */
    @Suppress("UNCHECKED_CAST")
    private fun handleMethod(method: String, args: Map<String, Any?>): Any? {
        return when (method) {
            "getDeviceInfo" -> getDeviceInfo()
            "getCurrentActivity" -> getCurrentActivity()
            "dumpUi" -> {
                val clickableOnly = args["clickableOnly"] as? Boolean ?: false
                val packageFilter = args["packageFilter"] as? String
                dumpUi(clickableOnly, packageFilter)
            }
            "tap" -> {
                val x = (args["x"] as? Number)?.toInt() ?: 0
                val y = (args["y"] as? Number)?.toInt() ?: 0
                tap(x, y)
            }
            "click" -> {
                val x = (args["x"] as? Number)?.toInt() ?: 0
                val y = (args["y"] as? Number)?.toInt() ?: 0
                val duration = (args["duration"] as? Number)?.toLong() ?: 50L
                click(x, y, duration)
            }
            "swipe" -> {
                val x1 = (args["x1"] as? Number)?.toInt() ?: 0
                val y1 = (args["y1"] as? Number)?.toInt() ?: 0
                val x2 = (args["x2"] as? Number)?.toInt() ?: 0
                val y2 = (args["y2"] as? Number)?.toInt() ?: 0
                val duration = (args["duration"] as? Number)?.toLong() ?: 300L
                swipe(x1, y1, x2, y2, duration)
            }
            "keyEvent" -> {
                val keycode = (args["keycode"] as? Number)?.toInt() ?: 0
                keyEvent(keycode)
            }
            "inputText" -> {
                val text = args["text"] as? String ?: ""
                inputText(text)
            }
            "screenshot" -> screenshot()
            "openAccessibilitySettings" -> openAccessibilitySettings()
            "openShizukuSettings" -> openShizukuSettings()
            "shell" -> {
                val command = args["command"] as? String ?: ""
                val useSu = args["useSu"] as? Boolean ?: false
                val mode = args["mode"] as? String
                val timeoutMs = (args["timeoutMs"] as? Number)?.toLong() ?: 10000L
                if (mode != null) shellWithMode(command, mode, timeoutMs) else shell(command, useSu, timeoutMs)
            }
            else -> throw UnsupportedOperationException("Unknown method: $method")
        }
    }

    // ==================== Device Info ====================

    private fun getDeviceInfo(): Map<String, Any> {
        val model = Build.MODEL ?: "unknown"
        val brand = Build.BRAND ?: "unknown"
        val androidVersion = Build.VERSION.RELEASE ?: "unknown"
        val sdkVersion = Build.VERSION.SDK_INT
        val wifiIp = getWifiIpAddress()
        val hasRoot = hasRoot()
        val accessibilityEnabled = McpAccessibilityService.isRunning()
        val hasShizuku = hasShizuku()
        val hasDhizuku = hasDhizuku()

        val mode = when {
            hasRoot -> "root"
            hasShizuku -> "shizuku"
            hasDhizuku -> "dhizuku"
            accessibilityEnabled -> "accessibility"
            else -> "none"
        }

        return mapOf(
            "model" to model,
            "brand" to brand,
            "androidVersion" to androidVersion,
            "sdkVersion" to sdkVersion,
            "wifiIp" to wifiIp,
            "hasRoot" to hasRoot,
            "hasShizuku" to hasShizuku,
            "hasDhizuku" to hasDhizuku,
            "accessibilityEnabled" to accessibilityEnabled,
            "mode" to mode
        )
    }

    private fun getCurrentActivity(): String {
        if (McpAccessibilityService.isRunning() && McpAccessibilityService.currentPackage.isNotEmpty()) {
            return "${McpAccessibilityService.currentPackage}/${McpAccessibilityService.currentClassName}"
        }
        if (hasRoot()) {
            return shell("dumpsys activity activities | grep -E 'topResumedActivity|mResumedActivity'", true, 3000L)["stdout"].toString()
        }
        return "unknown (no root or accessibility)"
    }

    // ==================== UI Dump ====================

    private fun dumpUi(clickableOnly: Boolean, packageFilter: String?): String {
        val service = McpAccessibilityService.instance
        if (service != null) {
            return service.dumpUi(clickableOnly, packageFilter)
        }
        if (hasRoot()) {
            return dumpUiViaRoot(clickableOnly, packageFilter)
        }
        throw UnsupportedOperationException("No accessibility service or root available. Enable accessibility in settings.")
    }

    /**
     * Dump UI hierarchy via root uiautomator command.
     */
    private fun dumpUiViaRoot(clickableOnly: Boolean, packageFilter: String?): String {
        val process = Runtime.getRuntime().exec(arrayOf("su", "-c", "uiautomator dump /dev/fd/1"))
        val xml = BufferedReader(InputStreamReader(process.inputStream, Charsets.UTF_8)).readText()
        val stderr = BufferedReader(InputStreamReader(process.errorStream, Charsets.UTF_8)).readText()
        val exitCode = process.waitFor()
        
        if (exitCode != 0 || xml.isBlank()) {
            throw RuntimeException("uiautomator dump failed (exit=$exitCode): $stderr")
        }

        // Extract the XML hierarchy content
        val xmlContent = if (xml.startsWith("<?xml")) {
            val startIdx = xml.indexOf("<?xml")
            val endIdx = xml.indexOf("</hierarchy>")
            if (endIdx >= 0) {
                xml.substring(startIdx, endIdx + 12)
            } else {
                xml.substring(startIdx)
            }
        } else {
            xml
        }

        return parseUiautomatorXml(xmlContent, clickableOnly, packageFilter).toString()
    }

    /**
     * Parse uiautomator XML dump into a JSONArray.
     */
    private fun parseUiautomatorXml(xml: String, clickableOnly: Boolean, packageFilter: String?): JSONArray {
        val jsonArray = JSONArray()
        val nodeRegex = Regex("<node\\s+([^>]+?)(?:/>|>)")
        val attrRegex = Regex("(\\w+)=\"([^\"]*)\"")
        val boundsRegex = Regex("\\[(\\d+),(\\d+)]\\[(\\d+),(\\d+)]")

        for (match in nodeRegex.findAll(xml)) {
            val attrs = attrRegex.findAll(match.groupValues[1]).associate { it.groupValues[1] to it.groupValues[2] }

            val clickable = attrs["clickable"] == "true"
            val packageName = attrs["package"] ?: ""

            if (clickableOnly && !clickable) continue
            if (packageFilter != null && packageName != packageFilter) continue

            val boundsStr = attrs["bounds"] ?: ""
            val boundsMatch = boundsRegex.find(boundsStr)
            val centerX: Int
            val centerY: Int
            if (boundsMatch != null) {
                val (x1, y1, x2, y2) = boundsMatch.destructured
                centerX = (x1.toInt() + x2.toInt()) / 2
                centerY = (y1.toInt() + y2.toInt()) / 2
            } else {
                centerX = 0
                centerY = 0
            }

            val resourceId = attrs["resource-id"] ?: ""
            val json = JSONObject()
            json.put("text", attrs["text"] ?: "")
            json.put("contentDesc", attrs["content-desc"] ?: "")
            json.put("resourceId", resourceId)
            json.put("resId", resolveResourceId(resourceId))
            json.put("className", attrs["class"] ?: "")
            json.put("packageName", packageName)
            json.put("clickable", clickable)
            json.put("enabled", attrs["enabled"] == "true")
            json.put("focusable", attrs["focusable"] == "true")
            json.put("scrollable", attrs["scrollable"] == "true")
            json.put("bounds", boundsStr)
            json.put("centerX", centerX)
            json.put("centerY", centerY)
            jsonArray.put(json)
        }

        return jsonArray
    }

    // ==================== Actions ====================

    private fun tap(x: Int, y: Int): Boolean {
        val service = McpAccessibilityService.instance
        if (service != null) {
            val latch = CountDownLatch(1)
            var result = false
            service.tap(x, y) { success ->
                result = success
                latch.countDown()
            }
            latch.await(10, TimeUnit.SECONDS)
            return result
        }
        if (hasRoot()) {
            shell("input tap $x $y", true, 10000L)
            return true
        }
        throw UnsupportedOperationException("No accessibility service or root available")
    }

    private fun click(x: Int, y: Int, duration: Long): Boolean {
        val service = McpAccessibilityService.instance
        if (service != null) {
            val latch = CountDownLatch(1)
            var result = false
            service.click(x, y, duration) { success ->
                result = success
                latch.countDown()
            }
            latch.await(10, TimeUnit.SECONDS)
            return result
        }
        if (hasRoot()) {
            shell("input swipe $x $y $x $y $duration", true, 10000L)
            return true
        }
        throw UnsupportedOperationException("No accessibility service or root available")
    }

    private fun swipe(x1: Int, y1: Int, x2: Int, y2: Int, duration: Long): Boolean {
        val service = McpAccessibilityService.instance
        if (service != null) {
            val latch = CountDownLatch(1)
            var result = false
            service.swipe(x1, y1, x2, y2, duration) { success ->
                result = success
                latch.countDown()
            }
            latch.await(10, TimeUnit.SECONDS)
            return result
        }
        if (hasRoot()) {
            shell("input swipe $x1 $y1 $x2 $y2 $duration", true, 10000L)
            return true
        }
        throw UnsupportedOperationException("No accessibility service or root available")
    }

    private fun keyEvent(keycode: Int): Boolean {
        val service = McpAccessibilityService.instance
        // 仅 HOME(3)/BACK(4)/POWER(26)/RECENTS(187) 可通过无障碍服务处理
        val accessibilitySupported = listOf(3, 4, 26, 187).contains(keycode)
        if (service != null && accessibilitySupported) {
            return service.performGlobalActionByKeycode(keycode)
        }
        if (hasRoot()) {
            shell("input keyevent $keycode", true, 10000L)
            return true
        }
        if (service != null && !accessibilitySupported) {
            throw UnsupportedOperationException("Keycode $keycode is not supported by accessibility service. Supported: 3=HOME, 4=BACK, 26=POWER, 187=RECENTS. Use root for other keys.")
        }
        throw UnsupportedOperationException("No accessibility service or root available")
    }

    private fun inputText(text: String): Boolean {
        val service = McpAccessibilityService.instance
        if (service != null) {
            return service.setText(text)
        }
        if (hasRoot()) {
            // 使用 Android input text 命令的安全转义
            // input text 命令中空格需用 %s 表示，其他特殊字符需要转义
            val escaped = text
                .replace("\\", "\\\\")
                .replace("\"", "\\\"")
                .replace("'", "\\'")
                .replace("`", "\\`")
                .replace("$", "\\$")
                .replace("(", "\\(")
                .replace(")", "\\)")
                .replace(";", "\\;")
                .replace("|", "\\|")
                .replace("&", "\\&")
                .replace("<", "\\<")
                .replace(">", "\\>")
                .replace("\n", "%n")
                .replace(" ", "%s")
            shell("input text \"$escaped\"", true, 10000L)
            return true
        }
        throw UnsupportedOperationException("No accessibility service or root available")
    }

    // ==================== Screenshot ====================

    private fun screenshot(): String {
        if (hasRoot()) {
            return screenshotViaRoot()
        }
        throw UnsupportedOperationException("Screenshot requires root. Non-root MediaProjection not yet implemented.")
    }

    private fun screenshotViaRoot(): String {
        val process = Runtime.getRuntime().exec(arrayOf("su", "-c", "screencap -p"))
        val bytes = process.inputStream.readBytes()
        val stderr = BufferedReader(InputStreamReader(process.errorStream, Charsets.UTF_8)).readText()
        val exitCode = process.waitFor()
        if (exitCode != 0 || bytes.isEmpty()) {
            throw RuntimeException("screencap failed (exit=$exitCode): $stderr")
        }
        return Base64.encodeToString(bytes, Base64.NO_WRAP)
    }

    // ==================== Shell ====================

    private fun shell(command: String, useSu: Boolean, timeoutMs: Long): Map<String, Any> {
        val fullCommand = if (useSu) arrayOf("su", "-c", command) else arrayOf("sh", "-c", command)
        val process = Runtime.getRuntime().exec(fullCommand)
        val stdout = BufferedReader(InputStreamReader(process.inputStream, Charsets.UTF_8)).readText()
        val stderr = BufferedReader(InputStreamReader(process.errorStream, Charsets.UTF_8)).readText()
        val completed = process.waitFor(timeoutMs, java.util.concurrent.TimeUnit.MILLISECONDS)
        val exitCode = if (completed) process.exitValue() else -1

        // 超时后必须销毁进程，避免资源泄漏
        if (!completed) {
            process.destroyForcibly()
        }

        return mapOf(
            "success" to (completed && exitCode == 0),
            "command" to command,
            "useSu" to useSu,
            "timeoutMs" to timeoutMs,
            "timedOut" to !completed,
            "exitCode" to exitCode,
            "stdout" to stdout,
            "stderr" to stderr
        )
    }

    // ==================== Accessibility Settings ====================

    private fun openAccessibilitySettings(): Boolean {
        val intent = Intent("android.settings.ACCESSIBILITY_SETTINGS").apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        context?.startActivity(intent)
        return true
    }

    /**
     * 打开 Shizuku 授权页面
     * Shizuku 官方提供了专用授权 Intent（moe.shizuku.privileged.api 的 ACTIVITY_PERMISSION）
     */
    private fun openShizukuSettings(): Boolean {
        return try {
            val activity = Class.forName("moe.shizuku.privileged.api.constant.Intent")
            val action = activity.getField("ACTIVITY_PERMISSION").getString(null)
            val intent = Intent(action).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            context?.startActivity(intent)
            true
        } catch (e: Exception) {
            // 反射失败时退回 Shizuku 应用主页
            try {
                val pm = context?.packageManager ?: return false
                val launch = pm.getLaunchIntentForPackage("moe.shizuku.privileged.api")
                if (launch != null) {
                    launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context?.startActivity(launch)
                    true
                } else false
            } catch (e2: Exception) {
                false
            }
        }
    }

    // ==================== Shizuku / Dhizuku ====================

    private val shizukuBinder: android.os.IBinder? by lazy {
        try {
            // Shizuku 通过系统服务 user 的 binder 提供
            val clazz = Class.forName("moe.shizuku.api.Shizuku")
            val binderMethod = clazz.getMethod("binderReceived")
            binderMethod.invoke(null) as? android.os.IBinder
        } catch (e: Exception) {
            null
        }
    }

    /**
     * 检测 Shizuku 是否可用：
     * 1. Shizuku 应用已安装
     * 2. binder 已连接（用户已在 Shizuku 中授权）
     */
    @Volatile
    private var shizukuStatus: Boolean? = null
    @Volatile
    private var shizukuCheckTime: Long = 0L

    private fun hasShizuku(): Boolean {
        // 5 秒缓存，授权返回后能重新检测
        val now = System.currentTimeMillis()
        if (shizukuStatus != null && now - shizukuCheckTime < 5000) return shizukuStatus!!
        val result = try {
            // 方式1：反射检查 binder
            val clazz = Class.forName("moe.shizuku.api.Shizuku")
            val ping = clazz.getMethod("pingBinder")
            if (ping.invoke(null) == true) {
                true
            } else {
                // 方式2：检查 Shizuku 应用是否安装且授权（ping 可能因进程隔离失败）
                val pm = context?.packageManager ?: return false
                pm.getPackageInfo("moe.shizuku.privileged.api", 0)
                val binder = shizukuBinder
                binder != null
            }
        } catch (e: Exception) {
            false
        }
        shizukuStatus = result
        shizukuCheckTime = now
        return result
    }

    /**
     * 检测 Dhizuku（Device Owner 扩展）是否可用：
     * 检查 me.bmax.dhizuku 是否被授予 Device Owner 权限
     */
    @Volatile
    private var dhizukuStatus: Boolean? = null

    private fun hasDhizuku(): Boolean {
        dhizukuStatus?.let { return it }
        val result = try {
            val pm = context?.packageManager ?: return false
            val dpm = context?.getSystemService(android.content.Context.DEVICE_POLICY_SERVICE)
                    as? android.app.admin.DevicePolicyManager
            val isOwner = dpm?.isDeviceOwnerApp("me.bmax.dhizuku") == true
            // Dhizuku 未作为 device owner 时，检查其是否已安装（部分系统用其它方式激活）
            val installed = try {
                pm.getPackageInfo("me.bmax.dhizuku", 0)
                true
            } catch (e: Exception) {
                false
            }
            isOwner || installed
        } catch (e: Exception) {
            false
        }
        dhizukuStatus = result
        return result
    }

    /**
     * 通过 Shizuku 执行 shell 命令（无需 root）
     */
    private fun shellViaShizuku(command: String, timeoutMs: Long): Map<String, Any> {
        try {
            val binder = shizukuBinder ?: throw IllegalStateException("Shizuku binder not connected")
            val clazz = Class.forName("moe.shizuku.api.Shizuku")
            val newProcess = clazz.getMethod("newProcess", Array<String>::class.java, String::class.java, Array<String>::class.java)
            val process = newProcess.invoke(null, arrayOf("sh", "-c", command), null, arrayOf<String>()) as android.os.Process
            val stdout = process.inputStream.bufferedReader().readText()
            val stderr = process.errorStream.bufferedReader().readText()
            val completed = process.waitFor(timeoutMs, java.util.concurrent.TimeUnit.MILLISECONDS)
            val exitCode = if (completed) process.exitValue() else -1
            if (!completed) process.destroyForcibly()
            return mapOf(
                "success" to (completed && exitCode == 0),
                "command" to command,
                "useSu" to false,
                "useShizuku" to true,
                "timeoutMs" to timeoutMs,
                "timedOut" to !completed,
                "exitCode" to exitCode,
                "stdout" to stdout,
                "stderr" to stderr
            )
        } catch (e: Exception) {
            return mapOf(
                "success" to false,
                "command" to command,
                "useSu" to false,
                "useShizuku" to true,
                "timedOut" to false,
                "exitCode" to -1,
                "stdout" to "",
                "stderr" to "Shizuku failed: ${e.message}"
            )
        }
    }

    /**
     * 通过 Dhizuku 执行 shell 命令（Device Owner 权限，无需 root）
     */
    private fun shellViaDhizuku(command: String, timeoutMs: Long): Map<String, Any> {
        try {
            val clazz = Class.forName("me.bmax.dhizuku.api.Dhizuku")
            val execMethod = clazz.getMethod("execCommand", String::class.java)
            val result = execMethod.invoke(null, command) as? String ?: ""
            // execCommand 返回 {status: 0, stdout: "...", stderr: "..."} JSON
            val json = org.json.JSONObject(result)
            val code = json.optInt("status", -1)
            return mapOf(
                "success" to (code == 0),
                "command" to command,
                "useSu" to false,
                "useDhizuku" to true,
                "timeoutMs" to timeoutMs,
                "timedOut" to false,
                "exitCode" to code,
                "stdout" to json.optString("stdout", ""),
                "stderr" to json.optString("stderr", "")
            )
        } catch (e: Exception) {
            return mapOf(
                "success" to false,
                "command" to command,
                "useSu" to false,
                "useDhizuku" to true,
                "timedOut" to false,
                "exitCode" to -1,
                "stdout" to "",
                "stderr" to "Dhizuku failed: ${e.message}"
            )
        }
    }

    /**
     * 统一 shell 执行：root > shizuku > dhizuku > 普通 shell
     * [mode] 指定模式: root / shizuku / dhizuku / auto
     */
    private fun shellWithMode(command: String, mode: String, timeoutMs: Long): Map<String, Any> {
        return when (mode) {
            "root" -> shell(command, true, timeoutMs)
            "shizuku" -> shellViaShizuku(command, timeoutMs)
            "dhizuku" -> shellViaDhizuku(command, timeoutMs)
            else -> { // auto
                when {
                    hasRoot() -> shell(command, true, timeoutMs)
                    hasShizuku() -> shellViaShizuku(command, timeoutMs)
                    hasDhizuku() -> shellViaDhizuku(command, timeoutMs)
                    else -> shell(command, false, timeoutMs)
                }
            }
        }
    }

    // ==================== Utilities ====================

    // Root 状态缓存，避免每次调用都 fork su 进程
    @Volatile
    private var rootStatus: Boolean? = null

    private fun hasRoot(): Boolean {
        rootStatus?.let { return it }
        val result = try {
            val process = Runtime.getRuntime().exec(arrayOf("su", "-c", "id"))
            val output = BufferedReader(InputStreamReader(process.inputStream)).readText()
            process.waitFor()
            output.contains("uid=0")
        } catch (e: Exception) {
            false
        }
        rootStatus = result
        return result
    }

    private fun getWifiIpAddress(): String {
        try {
            val interfaces = NetworkInterface.getNetworkInterfaces()
            while (interfaces.hasMoreElements()) {
                val iface = interfaces.nextElement()
                val name = iface.name
                if (!name.contains("wlan") && !name.contains("eth")) continue

                val addresses = iface.inetAddresses
                while (addresses.hasMoreElements()) {
                    val addr = addresses.nextElement()
                    if (!addr.isLoopbackAddress && addr is Inet4Address) {
                        return addr.hostAddress ?: ""
                    }
                }
            }
        } catch (e: Exception) {
        }
        return ""
    }

    private val resourceCache = mutableMapOf<String, android.content.res.Resources?>()

    private fun resolveResourceId(resourceId: String): String {
        if (resourceId.isEmpty()) return ""
        val ctx = context ?: return ""

        try {
            val colonIndex = resourceId.indexOf(':')
            if (colonIndex <= 0) return ""

            val packageName = resourceId.substring(0, colonIndex)
            val rest = resourceId.substring(colonIndex + 1)

            val slashIndex = rest.indexOf('/')
            if (slashIndex <= 0) return ""

            val type = rest.substring(0, slashIndex)
            val name = rest.substring(slashIndex + 1)

            val resources = resourceCache.getOrPut(packageName) {
                try {
                    ctx.packageManager.getResourcesForApplication(packageName)
                } catch (e: Exception) {
                    null
                }
            } ?: return ""

            val identifier = resources.getIdentifier(name, type, packageName)
            return if (identifier != 0) "0x${Integer.toHexString(identifier)}" else ""
        } catch (e: Exception) {
            return ""
        }
    }
}
