package com.example.scrolloff

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Base64
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.*
import kotlin.concurrent.timer

class MainActivity : FlutterActivity() {
    private val APPS_CHANNEL = "com.example.scrolloff/apps"
    private val PERMISSIONS_CHANNEL = "com.example.scrolloff/permissions"
    private val MONITORING_CHANNEL = "com.example.scrolloff/monitoring"
    private val NAVIGATION_CHANNEL = "com.example.scrolloff/navigation"
    
    private var monitoringTimer: Timer? = null
    private var isMonitoring = false
    
    // Blocked apps list - sync with Flutter
    private val blockedApps = setOf(
        "com.instagram.android",
        "com.google.android.youtube",
        "app.revanced.android.youtube",
        "com.facebook.katana",
        "com.twitter.android",
        "com.snapchat.android",
        "com.zhiliaoapp.musically",
        "com.reddit.frontpage"
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Apps channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APPS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInstalledApps" -> {
                    try {
                        val installedApps = getInstalledApps()
                        result.success(installedApps)
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to get installed apps", e.message)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Permissions channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PERMISSIONS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openUsageAccessSettings" -> {
                    try {
                        openUsageAccessSettings()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to open usage access settings", e.message)
                    }
                }
                "openOverlaySettings" -> {
                    try {
                        openOverlaySettings()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to open overlay settings", e.message)
                    }
                }
                "checkUsageStatsPermission" -> {
                    try {
                        val hasPermission = checkUsageStatsPermission()
                        result.success(hasPermission)
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to check usage stats permission", e.message)
                    }
                }
                "checkOverlayPermission" -> {
                    try {
                        val hasPermission = checkOverlayPermission()
                        result.success(hasPermission)
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to check overlay permission", e.message)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Monitoring channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MONITORING_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startMonitoring" -> {
                    try {
                        startAppMonitoring()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to start monitoring", e.message)
                    }
                }
                "stopMonitoring" -> {
                    try {
                        stopAppMonitoring()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to stop monitoring", e.message)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Navigation channel for blocked screen
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NAVIGATION_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "showBlockedScreen" -> {
                    try {
                        val appName = call.argument<String>("appName") ?: "Unknown App"
                        val packageName = call.argument<String>("packageName") ?: ""
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to show blocked screen", e.message)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun openUsageAccessSettings() {
        try {
            // Try to open the app-specific usage access settings first
            val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
            intent.data = Uri.parse("package:$packageName")
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            startActivity(intent)
        } catch (e: Exception) {
            try {
                // Fallback to general usage access settings
                val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                startActivity(intent)
            } catch (e2: Exception) {
                // Final fallback to application details settings
                val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                intent.data = Uri.parse("package:$packageName")
                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                startActivity(intent)
            }
        }
    }

    private fun openOverlaySettings() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION)
                intent.data = Uri.parse("package:$packageName")
                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                startActivity(intent)
            } else {
                // For older versions, open app details
                val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                intent.data = Uri.parse("package:$packageName")
                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                startActivity(intent)
            }
        } catch (e: Exception) {
            // Fallback to app details settings
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            intent.data = Uri.parse("package:$packageName")
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            startActivity(intent)
        }
    }

    private fun checkUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            android.os.Process.myUid(),
            packageName
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun checkOverlayPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            // For versions below Marshmallow, permission is granted at install time
            true
        }
    }

    private fun getInstalledApps(): List<Map<String, String>> {
        val packageManager = packageManager
        val installedPackages = packageManager.getInstalledApplications(PackageManager.GET_META_DATA)
        val appsList = mutableListOf<Map<String, String>>()

        for (appInfo in installedPackages) {
            // Only include user-installed apps, exclude system apps
            val isUserApp = (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) == 0
            val isUpdatedSystemApp = (appInfo.flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) != 0
            
            if (isUserApp && !isSystemPackage(appInfo.packageName)) {
                try {
                    val appName = packageManager.getApplicationLabel(appInfo).toString()
                    val packageName = appInfo.packageName
                    
                    if (packageName != this.packageName) {
                        val iconBase64 = getAppIconAsBase64Optimized(packageManager, packageName)
                        
                        appsList.add(
                            mapOf(
                                "appName" to appName,
                                "packageName" to packageName,
                                "iconBase64" to iconBase64
                            )
                        )
                    }
                } catch (e: Exception) {
                    // Skip apps that can't be processed
                }
            }
        }

        return appsList.sortedBy { it["appName"] }
    }

    private fun isSystemPackage(packageName: String): Boolean {
        val systemPrefixes = listOf(
            "android.",
            "com.android.",
            "com.google.android.gms",
            "com.samsung.",
            "com.sec.android.",
            "com.miui.",
            "com.oneplus.",
            "com.huawei.",
            "com.oppo.",
            "com.vivo."
        )
        return systemPrefixes.any { packageName.startsWith(it) }
    }

    private fun getAppIconAsBase64Optimized(packageManager: PackageManager, packageName: String): String {
        return try {
            val icon = packageManager.getApplicationIcon(packageName)
            val bitmap = drawableToBitmapOptimized(icon)
            val outputStream = ByteArrayOutputStream()
            // Use lower quality for better performance
            bitmap.compress(Bitmap.CompressFormat.PNG, 70, outputStream)
            Base64.encodeToString(outputStream.toByteArray(), Base64.NO_WRAP)
        } catch (e: Exception) {
            ""
        }
    }

    private fun drawableToBitmapOptimized(drawable: Drawable): Bitmap {
        if (drawable is BitmapDrawable && drawable.bitmap != null) {
            return scaleBitmap(drawable.bitmap, 64, 64)
        }

        // Use smaller size for better performance
        val size = 64
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, size, size)
        drawable.draw(canvas)
        return bitmap
    }

    private fun scaleBitmap(bitmap: Bitmap, width: Int, height: Int): Bitmap {
        return Bitmap.createScaledBitmap(bitmap, width, height, true)
    }

    private fun startAppMonitoring() {
        if (isMonitoring) return
        
        Log.d("ScrollOff", "Starting app monitoring")
        isMonitoring = true
        
        // Check usage stats permission
        if (!checkUsageStatsPermission()) {
            Log.e("ScrollOff", "Usage stats permission not granted")
            return
        }
        
        monitoringTimer = timer(period = 3000) { // Increased from 2000 to 3000ms to reduce overhead
            checkForBlockedApps()
        }
    }
    
    private fun stopAppMonitoring() {
        Log.d("ScrollOff", "Stopping app monitoring")
        isMonitoring = false
        monitoringTimer?.cancel()
        monitoringTimer = null
        
        // Stop any running overlay service
        try {
            val stopIntent = Intent(this, BlockingOverlayService::class.java)
            stopService(stopIntent)
        } catch (e: Exception) {
            Log.e("ScrollOff", "Error stopping overlay service", e)
        }
    }
    
    private fun checkForBlockedApps() {
        try {
            val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val currentTime = System.currentTimeMillis()
            val events = usageStatsManager.queryEvents(currentTime - 5000, currentTime) // Back to 5000ms window
            
            var lastPackageName: String? = null
            val event = UsageEvents.Event()
            
            while (events.hasNextEvent()) {
                events.getNextEvent(event)
                if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) {
                    lastPackageName = event.packageName
                }
            }
            
            lastPackageName?.let { packageName ->
                if (blockedApps.contains(packageName) && packageName != this.packageName) {
                    Log.d("ScrollOff", "Blocked app detected: $packageName")
                    blockApp(packageName)
                }
            }
        } catch (e: Exception) {
            Log.e("ScrollOff", "Error checking for blocked apps", e)
        }
    }
    
    private fun blockApp(packageName: String) {
        runOnUiThread {
            if (checkOverlayPermission()) {
                showBlockingOverlay(packageName)
            } else {
                // If no overlay permission, just bring ScrollOff to foreground
                bringAppToForeground()
                Log.w("ScrollOff", "No overlay permission, bringing app to foreground instead")
            }
        }
    }
    
    private fun showBlockingOverlay(packageName: String) {
        try {
            // For better reliability, just bring ScrollOff to foreground instead of overlay
            bringAppToForeground()
            Log.d("ScrollOff", "Brought ScrollOff to foreground for ${getAppName(packageName)}")
            
            // Optionally show a brief overlay if overlay permission is available
            if (checkOverlayPermission()) {
                try {
                    val intent = Intent(this, BlockingOverlayService::class.java)
                    intent.putExtra("blocked_app", getAppName(packageName))
                    intent.putExtra("package_name", packageName)
                    
                    // Use regular service instead of foreground service to avoid permission issues
                    startService(intent)
                    Log.d("ScrollOff", "Started overlay service for ${getAppName(packageName)}")
                } catch (e: Exception) {
                    Log.e("ScrollOff", "Failed to start overlay service", e)
                }
            }
            
        } catch (e: Exception) {
            Log.e("ScrollOff", "Failed to show blocking overlay", e)
            bringAppToForeground()
        }
    }
    
    private fun bringAppToForeground() {
        try {
            val intent = packageManager.getLaunchIntentForPackage(packageName)
            intent?.let {
                it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                startActivity(it)
            }
        } catch (e: Exception) {
            Log.e("ScrollOff", "Failed to bring app to foreground", e)
        }
    }
    
    private fun getAppName(packageName: String): String {
        return try {
            val appInfo = packageManager.getApplicationInfo(packageName, 0)
            packageManager.getApplicationLabel(appInfo).toString()
        } catch (e: Exception) {
            packageName
        }
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        handleBlockedScreenIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleBlockedScreenIntent(intent)
    }

    private fun handleBlockedScreenIntent(intent: Intent?) {
        intent?.let { i ->
            if (i.getBooleanExtra("show_blocked_screen", false)) {
                val appName = i.getStringExtra("blocked_app_name") ?: "Unknown App"
                val packageName = i.getStringExtra("blocked_package_name") ?: ""
                
                Log.d("ScrollOff", "Handling blocked screen intent for $appName")
                
                // Send to Flutter immediately if engine is ready, otherwise wait
                if (flutterEngine != null) {
                    sendToFlutter(appName, packageName)
                } else {
                    // Wait for Flutter engine to be ready
                    android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                        sendToFlutter(appName, packageName)
                    }, 1000)
                }
            }
        }
    }

    private fun sendToFlutter(appName: String, packageName: String) {
        try {
            val channel = MethodChannel(flutterEngine?.dartExecutor?.binaryMessenger, NAVIGATION_CHANNEL)
            channel.invokeMethod("navigateToBlockedScreen", mapOf(
                "appName" to appName,
                "packageName" to packageName
            ))
            Log.d("ScrollOff", "Sent blocked screen navigation to Flutter for $appName")
        } catch (e: Exception) {
            Log.e("ScrollOff", "Failed to send to Flutter", e)
        }
    }
}
