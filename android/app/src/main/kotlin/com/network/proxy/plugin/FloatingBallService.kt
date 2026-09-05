package com.network.proxy.plugin

import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.util.Log
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

/**
 * MCP 悬浮球前台服务：
 * - 圆形悬浮球（字母 P 图案，可自定义颜色/透明度），显示 MCP 运行状态（绿色描边=运行中）
 * - 点击弹出快捷面板（MCP 状态/启动/停止/打开应用），再次点击收起
 * - 3 秒无操作自动贴边（可关）
 * - 前台服务提升应用保活能力
 */
class FloatingBallService : Service() {
    companion object {
        const val TAG = "FloatingBall"
        const val CHANNEL_ID = "floating-ball"
        const val NOTIFICATION_ID = 9528

        /** 主进程 MCP 状态广播（由 McpPlugin 写入） */
        @Volatile
        var mcpRunning: Boolean = false
    }

    private lateinit var windowManager: WindowManager
    private var ballView: LinearLayout? = null
    private var panelView: LinearLayout? = null
    private var ballParams: WindowManager.LayoutParams? = null
    private var panelParams: WindowManager.LayoutParams? = null

    private var ballColor = 0xFF6750A4.toInt()
    private var ballAlpha = 230
    private var autoDock = true

    private val handler = Handler(Looper.getMainLooper())
    private var dockRunnable: Runnable? = null
    private var panelOpen = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        startForeground()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "STOP") {
            stopSelf()
            return START_NOT_STICKY
        }
        autoDock = intent?.getBooleanExtra("autoDock", true) ?: true
        ballColor = intent?.getIntExtra("color", 0xFF6750A4.toInt()) ?: 0xFF6750A4.toInt()
        ballAlpha = intent?.getIntExtra("alpha", 230) ?: 230
        mcpRunning = intent?.getBooleanExtra("running", mcpRunning) ?: mcpRunning

        if (!Settings.canDrawOverlays(this)) {
            Log.w(TAG, "no overlay permission")
            stopSelf()
            return START_NOT_STICKY
        }

        if (ballView == null) {
            createBall()
        } else {
            refreshBallStyle()
        }
        return START_STICKY
    }

    private fun startForeground() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(CHANNEL_ID, "MCP 悬浮球", NotificationManager.IMPORTANCE_LOW)
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
        val notification = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION") Notification.Builder(this)
        }
            .setContentTitle("ProxyPin MCP 悬浮球")
            .setContentText("悬浮球运行中，MCP 保活增强")
            .setSmallIcon(android.R.drawable.ic_menu_manage)
            .build()
        // Android 14+ 要求前台服务带类型（manifest 已声明 specialUse）
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    @SuppressLint("ClickableViewAccessibility", "InflateParams")
    private fun createBall() {
        ballView = LinearLayout(this).apply { applyBallStyle(this) }

        ballParams = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.END
            x = 24
            y = 260
        }

        var downX = 0f; var downY = 0f
        var startX = 0; var startY = 0
        var moved = false

        ballView?.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    downX = event.rawX; downY = event.rawY
                    startX = ballParams?.x ?: 0; startY = ballParams?.y ?: 0
                    moved = false
                    cancelDock()
                    false
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = (event.rawX - downX).toInt()
                    val dy = (event.rawY - downY).toInt()
                    if (dx * dx + dy * dy > 100) {
                        moved = true
                        ballParams?.x = startX + dx
                        ballParams?.y = startY + dy
                        ballParams?.let { windowManager.updateViewLayout(ballView, it) }
                    }
                    moved
                }
                MotionEvent.ACTION_UP -> {
                    if (!moved) togglePanel()
                    scheduleDock()
                    true
                }
                else -> false
            }
        }

        try {
            windowManager.addView(ballView, ballParams)
        } catch (e: Exception) {
            // 悬浮窗被系统/厂商拦截时必须给出可见反馈，否则用户开启后什么都看不到
            Log.e(TAG, "悬浮球添加失败", e)
            ballView = null
            try {
                android.widget.Toast.makeText(
                    this,
                    "悬浮球启动失败：${e.message ?: "窗口被系统拒绝，请检查「显示悬浮窗」与厂商后台弹出权限"}",
                    android.widget.Toast.LENGTH_LONG
                ).show()
            } catch (_: Throwable) {}
            return
        }
        scheduleDock()
    }

    private fun applyBallStyle(view: LinearLayout) {
        val running = mcpRunning
        val ring = GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(ballColor)
            setStroke(if (running) 6 else 2, if (running) Color.rgb(76, 175, 80) else Color.argb(120, 255, 255, 255))
        }
        view.background = ring
        view.alpha = ballAlpha / 255f
        view.setPadding(30, 30, 30, 30)
        view.elevation = 12f
        // "P" 变形字母图案
        val label = TextView(this).apply {
            text = "P"
            setTextColor(Color.WHITE)
            textSize = 22f
            typeface = android.graphics.Typeface.create("sans-serif-black", android.graphics.Typeface.BOLD)
        }
        view.removeAllViews()
        view.addView(label)
        view.contentDescription = if (running) "MCP 运行中" else "MCP 已停止"
    }

    private fun refreshBallStyle() {
        ballView?.let { applyBallStyle(it) }
    }

    private fun togglePanel() {
        if (panelOpen) {
            closePanel()
            return
        }
        panelOpen = true
        panelView = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.argb(240, 30, 30, 34))
            setPadding(28, 20, 28, 20)
            elevation = 16f
        }

        val title = TextView(this).apply {
            text = if (mcpRunning) "● MCP 运行中" else "○ MCP 已停止"
            setTextColor(if (mcpRunning) Color.rgb(76, 175, 80) else Color.GRAY)
            textSize = 14f
        }
        panelView?.addView(title)

        fun addButton(text: String, action: () -> Unit) {
            val btn = Button(this).apply {
                this.text = text
                textSize = 13f
                isAllCaps = false
                setTextColor(Color.WHITE)
                background = GradientDrawable().apply {
                    cornerRadius = 20f
                    setColor(Color.argb(70, 255, 255, 255))
                }
                setOnClickListener { action(); closePanel() }
            }
            panelView?.addView(btn)
        }

        addButton("打开 ProxyPin") {
            val launch = packageManager.getLaunchIntentForPackage(packageName)
            launch?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(launch)
        }
        addButton("刷新状态") {
            refreshBallStyle()
            closePanel()
        }

        panelParams = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = (ballParams?.x ?: 0) - 30
            y = (ballParams?.y ?: 0) + 140
        }
        windowManager.addView(panelView, panelParams)
    }

    private fun closePanel() {
        try {
            panelView?.let { windowManager.removeView(it) }
        } catch (_: Exception) {}
        panelView = null
        panelOpen = false
    }

    /** 3 秒无操作贴边 */
    private fun scheduleDock() {
        cancelDock()
        if (!autoDock) return
        dockRunnable = Runnable {
            val params = ballParams ?: return@Runnable
            val screen = resources.displayMetrics.widthPixels
            // gravity 为 END：x 表示距屏幕右缘的偏移。球心屏幕坐标 ≈ screen - x - 55
            val center = screen - params.x - 55
            // 贴左：球左缘 ≈ 8 → x = screen - 118；贴右：球右缘 ≈ 8 → x = 8
            val targetX = if (center < screen / 2) screen - 118 else 8
            params.x = targetX
            try {
                windowManager.updateViewLayout(ballView, params)
            } catch (_: Exception) {}
        }
        handler.postDelayed(dockRunnable!!, 3000)
    }

    private fun cancelDock() {
        dockRunnable?.let { handler.removeCallbacks(it) }
    }

    override fun onDestroy() {
        cancelDock()
        try {
            panelView?.let { windowManager.removeView(it) }
        } catch (_: Exception) {}
        try {
            ballView?.let { windowManager.removeView(it) }
        } catch (_: Exception) {}
        panelView = null
        ballView = null
        super.onDestroy()
    }
}
