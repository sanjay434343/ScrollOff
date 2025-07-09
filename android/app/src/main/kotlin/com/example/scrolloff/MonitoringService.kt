package com.app.scrolloff

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import java.util.*
import kotlin.concurrent.timer

class MonitoringService : Service() {
    private var monitoringTimer: Timer? = null
    private val NOTIFICATION_ID = 1001
    private val CHANNEL_ID = "ScrollOffMonitoring"
    
    // Use same storage keys as MainActivity
    private val PREFS_NAME = "FlutterSharedPreferences"
    private val BLOCKED_APPS_KEY = "flutter.scrolloff_blocked_apps"
    
    private var lastCheckedApp: String? = null
    private var currentlyBlockedApp: String? = null
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        Log.d("ScrollOff", "MonitoringService onCreate")
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d("ScrollOff", "MonitoringService started")
        
        // Start foreground notification
        val notification = createNotification()
        startForeground(NOTIFICATION_ID, notification)
        
        // Start monitoring
        startMonitoring()
        
        return START_STICKY // Restart if killed
    }
    
    override fun onDestroy() {
        super.onDestroy()
        Log.d("ScrollOff", "MonitoringService destroyed")
        stopMonitoring()
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "ScrollOff Monitoring",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Monitoring blocked apps in background"
                setShowBadge(false)
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("ScrollOff Active")
            .setContentText("Monitoring blocked apps")
            .setSmallIcon(android.R.drawable.ic_menu_view)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }
    
    private fun startMonitoring() {
        if (monitoringTimer != null) return
        
        Log.d("ScrollOff", "Starting monitoring timer")
        val blockedApps = getBlockedApps()
        Log.d("ScrollOff", "Monitoring for blocked apps: $blockedApps")
        
        monitoringTimer = timer(period = 1000) { // Check every 1 second for faster response
            checkForBlockedApps()
        }
    }
    
    private fun stopMonitoring() {
        Log.d("ScrollOff", "Stopping monitoring timer")
        monitoringTimer?.cancel()
        monitoringTimer = null
    }
    
    private fun getBlockedApps(): Set<String> {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        
        // Try to get as StringSet first (newer format)
        val blockedSet = try {
            prefs.getStringSet(BLOCKED_APPS_KEY, emptySet()) ?: emptySet()
        } catch (e: Exception) {
            // Fallback: try to get as comma-separated string (older format)
            val blockedAppsString = prefs.getString(BLOCKED_APPS_KEY, "") ?: ""
            if (blockedAppsString.isNotEmpty()) {
                blockedAppsString.split(",").filter { it.isNotEmpty() }.toSet()
            } else {
                emptySet()
            }
        }
        
        Log.d("ScrollOff", "MonitoringService - Blocked apps: $blockedSet")
        return blockedSet
    }
    
    // Helper method to parse Flutter's string set format
    private fun parseFlutterStringSetValue(value: String): Set<String> {
        return try {
            // Flutter might store as JSON-like format: ["item1","item2"]
            if (value.startsWith("[") && value.endsWith("]")) {
                val content = value.substring(1, value.length - 1)
                if (content.isEmpty()) {
                    emptySet()
                } else {
                    content.split(",")
                        .map { it.trim().removeSurrounding("\"") }
                        .filter { it.isNotEmpty() }
                        .toSet()
                }
            } else {
                // Fallback: treat as comma-separated
                value.split(",").map { it.trim() }.filter { it.isNotEmpty() }.toSet()
            }
        } catch (e: Exception) {
            Log.e("ScrollOff", "Error parsing Flutter string set", e)
            emptySet()
        }
    }
    
    private fun checkForBlockedApps() {
        try {
            val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val currentTime = System.currentTimeMillis()
            val startTime = currentTime - 1000 // Look back 1 second for faster detection
            
            val events = usageStatsManager.queryEvents(startTime, currentTime)
            
            var lastPackageName: String? = null
            val event = UsageEvents.Event()
            
            while (events.hasNextEvent()) {
                events.getNextEvent(event)
                if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) {
                    lastPackageName = event.packageName
                }
            }
            
            val blockedApps = getBlockedApps()
            
            lastPackageName?.let { packageName ->
                // Log every app change for debugging
                if (packageName != lastCheckedApp) {
                    Log.d("ScrollOff", "📱 App changed: $lastCheckedApp → $packageName")
                    lastCheckedApp = packageName
                }
                
                if (blockedApps.contains(packageName) && packageName != "com.example.scrolloff") {
                    // BLOCKED APP DETECTED - IMMEDIATE BLOCK
                    Log.d("ScrollOff", "🚫 BLOCKING: $packageName (was: $currentlyBlockedApp)")
                    currentlyBlockedApp = packageName
                    blockApp(packageName)
                } else {
                    // Current app is NOT blocked - only clear if we were blocking something
                    if (currentlyBlockedApp != null && packageName == "com.example.scrolloff") {
                        // Only clear when specifically going to ScrollOff
                        Log.d("ScrollOff", "✅ ScrollOff opened - clearing overlay for $currentlyBlockedApp")
                        clearOverlay()
                        currentlyBlockedApp = null
                    } else if (currentlyBlockedApp != null && !blockedApps.contains(packageName)) {
                        // User switched to a completely different, non-blocked app
                        Log.d("ScrollOff", "✅ Switched to non-blocked app: $packageName - clearing overlay")
                        clearOverlay()
                        currentlyBlockedApp = null
                    }
                    // DO NOT clear overlay if user is just navigating within system or other activities
                }
            }
            
        } catch (e: Exception) {
            Log.e("ScrollOff", "❌ Error in checkForBlockedApps", e)
        }
    }

    private fun blockApp(packageName: String) {
        try {
            val appName = getAppName(packageName)
            Log.d("ScrollOff", "🛑 IMMEDIATE BLOCK: $appName ($packageName)")
            
            // DON'T clear existing overlay - just ensure one exists
            val intent = Intent(this@MonitoringService, BlockingOverlayService::class.java).apply {
                putExtra("blocked_app_name", appName)
                putExtra("blocked_package_name", packageName)
            }
            
            startService(intent)
            Log.d("ScrollOff", "🚨 BLOCKING SERVICE STARTED for $appName")
            
        } catch (e: Exception) {
            Log.e("ScrollOff", "❌ Failed to block app", e)
        }
    }
    
    private fun clearOverlay() {
        try {
            val stopIntent = Intent(this, BlockingOverlayService::class.java)
            stopService(stopIntent)
            Log.d("ScrollOff", "Overlay cleared")
        } catch (e: Exception) {
            Log.e("ScrollOff", "Error clearing overlay", e)
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
}
