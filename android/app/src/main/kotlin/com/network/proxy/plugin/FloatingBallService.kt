package com.network.proxy.plugin

import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.RadialGradient
import android.graphics.RectF
import android.graphics.Shader
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
 * 悬浮球前台服务（液态玻璃风格）：
 * - 正圆玻璃球：径向渐变球体 + 顶部高光 + 白色波纹图案，无描边，颜色/透明度可自定义
 * - 点击弹出贴球配置面板：设置 / 换颜色 / 调透明度 / 贴边开关 / 隐藏悬浮球（配置实时写回偏好设置）
 * - 3 秒无操作自动贴边（可关）
 * - 前台服务提升应用保活能力
 */
class FloatingBallService : Service() {
    companion object {
        const val TAG = "FloatingBall"
        const val CHANNEL_ID = "floating-ball"
        const val NOTIFICATION_ID = 9528

        /** 球体直径（dp），正圆保证 */
        const val BALL_DP = 104

        /** 与 Flutter 侧预置色一致的循环列表 */
        val PRESET_COLORS = intArrayOf(
            0xFF6750A4.toInt(), 0xFF1565C0.toInt(), 0xFF2E7D32.toInt(),
            0xFFEF6C00.toInt(), 0xFFC2185B.toInt(), 0xFF37474F.toInt()
        )
        val ALPHA_CYCLE = intArrayOf(255, 215, 175, 135)

        /** 主进程 MCP 状态（由 McpPlugin 写入，保留字段兼容旧调用） */
        @Volatile
        var mcpRunning: Boolean = false
    }

    private lateinit var windowManager: WindowManager
    private var ballView: GlassBallView? = null
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
            val channel = NotificationChannel(CHANNEL_ID, "悬浮球", NotificationManager.IMPORTANCE_LOW)
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
        val notification = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION") Notification.Builder(this)
        }
            .setContentTitle("ProxyPin 悬浮球")
            .setContentText("悬浮球运行中，点击可快速配置")
            .setSmallIcon(android.R.drawable.ic_menu_manage)
            .build()
        // Android 14+ 要求前台服务带类型（manifest 已声明 specialUse）
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    @SuppressLint("ClickableViewAccessibility")
    private fun createBall() {
        val sizePx = (BALL_DP * resources.displayMetrics.density).toInt()
        ballView = GlassBallView(this).apply {
            setStyle(ballColor, ballAlpha)
        }

        ballParams = WindowManager.LayoutParams(
            sizePx, sizePx,
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

    private fun refreshBallStyle() {
        ballView?.setStyle(ballColor, ballAlpha)
    }

    /** 将配置写回 Flutter shared_preferences，保证设置页与悬浮球面板状态一致 */
    private fun savePref(key: String, value: Any) {
        try {
            val sp = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            sp.edit().apply {
                when (value) {
                    is Boolean -> putBoolean("flutter.$key", value)
                    is Int -> putLong("flutter.$key", value.toLong())
                    is String -> putString("flutter.$key", value)
                }
            }.commit()
        } catch (e: Exception) {
            Log.w(TAG, "savePref failed: $key", e)
        }
    }

    private fun togglePanel() {
        if (panelOpen) {
            closePanel()
            return
        }
        panelOpen = true
        val dm = resources.displayMetrics
        val sizePx = (BALL_DP * resources.displayMetrics.density).toInt()

        panelView = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            // 玻璃面板：深色半透明圆角 + 高光描顶
            background = GradientDrawable().apply {
                cornerRadius = 30f
                setColor(Color.argb(228, 24, 24, 30))
                setStroke(1, Color.argb(46, 255, 255, 255))
            }
            setPadding(34, 28, 34, 30)
            elevation = 18f
        }

        val title = TextView(this).apply {
            text = "悬浮球"
            setTextColor(Color.argb(200, 255, 255, 255))
            textSize = 12f
            letterSpacing = 0.1f
        }
        panelView?.addView(title)

        fun addButton(text: String, action: (Button) -> Unit): Button {
            val btn = Button(this).apply {
                this.text = text
                textSize = 13f
                isAllCaps = false
                setTextColor(Color.WHITE)
                background = GradientDrawable().apply {
                    cornerRadius = 22f
                    setColor(Color.argb(42, 255, 255, 255))
                    setStroke(1, Color.argb(36, 255, 255, 255))
                }
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply { topMargin = (8 * resources.displayMetrics.density).toInt() }
                setOnClickListener { action(this) }
            }
            panelView?.addView(btn)
            return btn
        }

        addButton("设置") {
            val launch = packageManager.getLaunchIntentForPackage(packageName)
            launch?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(launch)
            closePanel()
        }
        addButton("换颜色") {
            var idx = PRESET_COLORS.indexOf(ballColor)
            idx = (idx + 1) % PRESET_COLORS.size
            ballColor = PRESET_COLORS[idx]
            refreshBallStyle()
            savePref("floatingBallColor", ballColor)
        }
        addButton("调透明度") {
            var idx = 0
            var best = Int.MAX_VALUE
            ALPHA_CYCLE.forEachIndexed { i, a -> if (kotlin.math.abs(a - ballAlpha) < best) { best = kotlin.math.abs(a - ballAlpha); idx = i } }
            idx = (idx + 1) % ALPHA_CYCLE.size
            ballAlpha = ALPHA_CYCLE[idx]
            refreshBallStyle()
            savePref("floatingBallAlpha", ballAlpha)
        }
        val dockBtn = addButton(if (autoDock) "贴边：开" else "贴边：关") { btn ->
            autoDock = !autoDock
            btn.text = if (autoDock) "贴边：开" else "贴边：关"
            savePref("floatingBallAutoDock", autoDock)
            if (autoDock) scheduleDock() else cancelDock()
        }
        dockBtn.text = if (autoDock) "贴边：开" else "贴边：关"
        addButton("隐藏悬浮球") {
            savePref("floatingBallEnabled", false)
            closePanel()
            stopSelf()
        }

        // 面板贴球：球在右半屏 → 面板出现在球左侧；球在左半屏 → 面板出现在球右侧
        val screenW = dm.widthPixels
        val ballLeft = screenW - (ballParams?.x ?: 24) - sizePx
        val ballTop = (ballParams?.y ?: 260)
        val onLeft = ballLeft + sizePx / 2 < screenW / 2

        panelParams = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        ).apply {
            if (onLeft) {
                gravity = Gravity.TOP or Gravity.START
                x = (ballLeft + sizePx + 12).coerceAtLeast(8)
            } else {
                gravity = Gravity.TOP or Gravity.END
                x = (screenW - ballLeft + 12).coerceAtLeast(8)
            }
            y = (ballTop - 20).coerceIn(8, (dm.heightPixels - 360).coerceAtLeast(8))
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
            val sizePx = (BALL_DP * resources.displayMetrics.density).toInt()
            // gravity 为 END：x 表示距屏幕右缘的偏移。球心屏幕坐标 ≈ screen - x - sizePx/2
            val center = screen - params.x - sizePx / 2
            // 贴左：球左缘 ≈ 8 → x = screen - sizePx - 8；贴右：球右缘 ≈ 8 → x = 8
            val targetX = if (center < screen / 2) screen - sizePx - 8 else 8
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

/**
 * 液态玻璃球视图：
 * - 正圆（View 尺寸固定且宽高相等）
 * - 径向渐变球体（左上高光过渡到主色再到暗部），无描边
 * - 顶部椭圆玻璃高光 + 白色同心波纹图案（圆头描边，渐弱）
 */
private class GlassBallView(context: Context) : View(context) {
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private var baseColor = 0xFF6750A4.toInt()

    fun setStyle(color: Int, alpha: Int) {
        baseColor = color
        this.alpha = (alpha.coerceIn(30, 255)) / 255f
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        val size = width.coerceAtMost(height).toFloat()
        if (size <= 0) return
        val cx = width / 2f
        val cy = height / 2f
        val r = size / 2f

        // 球体：径向渐变（左上亮 → 主色 → 右下暗）
        paint.shader = RadialGradient(
            cx - r * 0.32f, cy - r * 0.38f, r * 1.32f,
            intArrayOf(shift(baseColor, 1.5f), baseColor, shift(baseColor, 0.62f)),
            floatArrayOf(0f, 0.52f, 1f),
            Shader.TileMode.CLAMP
        )
        canvas.drawCircle(cx, cy, r, paint)

        // 顶部玻璃高光（椭圆白斑）
        paint.shader = null
        paint.style = Paint.Style.FILL
        paint.color = Color.argb(84, 255, 255, 255)
        canvas.drawOval(
            RectF(cx - r * 0.56f, cy - r * 0.82f, cx + r * 0.08f, cy - r * 0.36f),
            paint
        )
        // 底部微弱反光
        paint.color = Color.argb(36, 255, 255, 255)
        canvas.drawOval(
            RectF(cx - r * 0.34f, cy + r * 0.44f, cx + r * 0.30f, cy + r * 0.66f),
            paint
        )

        // 白色同心波纹图案（圆头描边，向外渐弱），朝上展开像冒泡信号
        paint.style = Paint.Style.STROKE
        paint.strokeCap = Paint.Cap.ROUND
        val waveAlphas = intArrayOf(255, 178, 108)
        for (i in 0 until 3) {
            paint.strokeWidth = r * (0.085f - i * 0.016f)
            paint.color = Color.argb(waveAlphas[i], 255, 255, 255)
            val rr = r * (0.20f + i * 0.21f)
            val rect = RectF(cx - rr, cy - rr + r * 0.10f, cx + rr, cy + rr + r * 0.10f)
            canvas.drawArc(rect, 248f, 124f, false, paint)
        }
        paint.style = Paint.Style.FILL
    }

    private fun shift(color: Int, factor: Float): Int {
        fun ch(c: Int) = ((c * factor).toInt()).coerceIn(0, 255)
        return Color.argb(255, ch(Color.red(color)), ch(Color.green(color)), ch(Color.blue(color)))
    }
}
