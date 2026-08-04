package com.network.proxy.plugin

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.content.pm.PackageManager
import android.content.res.Resources
import android.graphics.Path
import android.graphics.Rect
import android.os.Bundle
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import org.json.JSONArray
import org.json.JSONObject

/**
 * MCP Accessibility Service
 *
 * Provides UI automation capabilities for MCP (Model Context Protocol) integration:
 * - Dump UI hierarchy (accessibility tree)
 * - Perform tap, swipe, and gesture actions
 * - Set text on focused elements
 * - Execute global actions (home, back, recents, power, menu)
 * - Take screenshots (via root)
 *
 * This service can work with either:
 * 1. Android Accessibility Service (no root required)
 * 2. Root (su) commands as fallback
 */
class McpAccessibilityService : AccessibilityService() {

    companion object {
        @Volatile
        var instance: McpAccessibilityService? = null
            private set

        @Volatile
        var currentPackage: String = ""

        @Volatile
        var currentClassName: String = ""

        fun isRunning(): Boolean = instance != null
    }

    private val resourceCache = mutableMapOf<String, Resources?>()

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
    }

    override fun onDestroy() {
        instance = null
        super.onDestroy()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event != null && event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            event.packageName?.let { currentPackage = it.toString() }
            event.className?.let { currentClassName = it.toString() }
        }
    }

    override fun onInterrupt() {}

    /**
     * Dump the current UI hierarchy as a JSONArray.
     * @param clickableOnly if true, only include clickable elements
     * @param packageFilter if non-null, only include elements from this package
     * @return JSONArray of UI element JSONObjects
     */
    fun dumpUi(clickableOnly: Boolean, packageFilter: String?): String {
        val root = rootInActiveWindow ?: return JSONArray().toString()
        val jsonArray = JSONArray()
        traverseNode(root, jsonArray, clickableOnly, packageFilter)
        root.recycle()
        return jsonArray.toString()
    }

    /**
     * Set text on the currently focused element.
     * @param text the text to set
     * @return true if successful
     */
    fun setText(text: String): Boolean {
        val root = rootInActiveWindow ?: return false
        val focused = root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
        if (focused != null) {
            val args = Bundle()
            args.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text)
            val result = focused.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
            focused.recycle()
            root.recycle()
            return result
        }
        root.recycle()
        return false
    }

    /**
     * Perform a global action (home, back, recents, etc.).
     * @param action keycode: 3=HOME, 4=BACK, 26=POWER, 82=MENU, 187=RECENTS
     * @return true if successful
     */
    fun performGlobalActionByKeycode(keycode: Int): Boolean {
        val globalAction = when (keycode) {
            3 -> GLOBAL_ACTION_HOME
            4 -> GLOBAL_ACTION_BACK
            26 -> GLOBAL_ACTION_POWER_DIALOG
            187 -> GLOBAL_ACTION_RECENTS
            // MENU(82) 无对应 AccessibilityService 全局动作，返回 false 由调用方走 root 降级
            else -> return false
        }
        return performGlobalAction(globalAction)
    }

    /**
     * Perform a tap gesture at the given coordinates.
     * @param x x coordinate
     * @param y y coordinate
     * @param callback called with true/false on completion
     */
    fun tap(x: Int, y: Int, callback: (Boolean) -> Unit) {
        val path = Path().apply { moveTo(x.toFloat(), y.toFloat()) }
        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0, 50))
            .build()
        dispatchGesture(gesture, object : GestureResultCallback() {
            override fun onCompleted(gesture: GestureDescription?) { callback(true) }
            override fun onCancelled(gesture: GestureDescription?) { callback(false) }
        }, null)
    }

    /**
     * Perform a click (tap with duration) at the given coordinates.
     * @param x x coordinate
     * @param y y coordinate
     * @param duration press duration in ms
     * @param callback called with true/false on completion
     */
    fun click(x: Int, y: Int, duration: Long, callback: (Boolean) -> Unit) {
        val path = Path().apply { moveTo(x.toFloat(), y.toFloat()) }
        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0, duration))
            .build()
        dispatchGesture(gesture, object : GestureResultCallback() {
            override fun onCompleted(gesture: GestureDescription?) { callback(true) }
            override fun onCancelled(gesture: GestureDescription?) { callback(false) }
        }, null)
    }

    /**
     * Perform a swipe gesture from (x1,y1) to (x2,y2).
     * @param x1 start x
     * @param y1 start y
     * @param x2 end x
     * @param y2 end y
     * @param duration swipe duration in ms
     * @param callback called with true/false on completion
     */
    fun swipe(x1: Int, y1: Int, x2: Int, y2: Int, duration: Long, callback: (Boolean) -> Unit) {
        val path = Path().apply {
            moveTo(x1.toFloat(), y1.toFloat())
            lineTo(x2.toFloat(), y2.toFloat())
        }
        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0, duration))
            .build()
        dispatchGesture(gesture, object : GestureResultCallback() {
            override fun onCompleted(gesture: GestureDescription?) { callback(true) }
            override fun onCancelled(gesture: GestureDescription?) { callback(false) }
        }, null)
    }

    /**
     * Convert an AccessibilityNodeInfo to a JSONObject.
     */
    private fun nodeToJson(node: AccessibilityNodeInfo): JSONObject? {
        val rect = Rect()
        node.getBoundsInScreen(rect)
        if (rect.width() <= 0 || rect.height() <= 0) return null

        val json = JSONObject()
        val viewIdResourceName = node.viewIdResourceName ?: ""

        json.put("text", node.text?.toString() ?: "")
        json.put("contentDesc", node.contentDescription?.toString() ?: "")
        json.put("resourceId", viewIdResourceName)
        json.put("resId", resolveResourceId(viewIdResourceName))
        json.put("className", node.className?.toString() ?: "")
        json.put("packageName", node.packageName?.toString() ?: "")
        json.put("clickable", node.isClickable)
        json.put("enabled", node.isEnabled)
        json.put("focusable", node.isFocusable)
        json.put("scrollable", node.isScrollable)
        json.put("bounds", "[${rect.left},${rect.top}][${rect.right},${rect.bottom}]")
        json.put("centerX", rect.centerX())
        json.put("centerY", rect.centerY())
        return json
    }

    /**
     * Recursively traverse the accessibility tree and collect nodes.
     */
    private fun traverseNode(
        node: AccessibilityNodeInfo,
        jsonArray: JSONArray,
        clickableOnly: Boolean,
        packageFilter: String?
    ) {
        val shouldInclude = if (packageFilter != null) {
            node.packageName?.toString() == packageFilter
        } else {
            true
        }

        if (shouldInclude) {
            if (!clickableOnly || node.isClickable) {
                nodeToJson(node)?.let { jsonArray.put(it) }
            }
        }

        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            traverseNode(child, jsonArray, clickableOnly, packageFilter)
            child.recycle()
        }
    }

    /**
     * Resolve a resource ID string to a hex resource identifier.
     * e.g. "com.example.app:id/button1" -> "0x7f080123"
     */
    private fun resolveResourceId(resourceId: String): String {
        if (resourceId.isEmpty()) return ""

        val colonIndex = resourceId.indexOf(':')
        if (colonIndex <= 0) return ""

        val packageName = resourceId.substring(0, colonIndex)
        val rest = resourceId.substring(colonIndex + 1)

        val slashIndex = rest.indexOf('/')
        if (slashIndex <= 0) return ""

        val type = rest.substring(0, slashIndex)
        val name = rest.substring(slashIndex + 1)

        val resources = getResourceForPackage(packageName) ?: return ""
        val identifier = resources.getIdentifier(name, type, packageName)
        return if (identifier != 0) "0x${Integer.toHexString(identifier)}" else ""
    }

    private fun getResourceForPackage(packageName: String): Resources? {
        return resourceCache.getOrPut(packageName) {
            try {
                packageManager.getResourcesForApplication(packageName)
            } catch (e: PackageManager.NameNotFoundException) {
                null
            }
        }
    }
}
