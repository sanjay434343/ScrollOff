package com.example.scrolloff

import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.util.Log

class BlockingOverlayService : Service() {
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val appName = intent?.getStringExtra("blocked_app") ?: "Unknown App"
        val packageName = intent?.getStringExtra("blocked_package_name") ?: ""
        
        Log.d("ScrollOff", "BlockingOverlayService started for $appName")
        
        // Launch Flutter app and navigate to blocked screen
        showBlockedScreen(appName, packageName)
        
        // Stop the service immediately
        stopSelf()
        return START_NOT_STICKY
    }
    
    private fun showBlockedScreen(appName: String, packageName: String) {
        try {
            // Create intent to launch MainActivity with blocked screen data
            val intent = Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                putExtra("show_blocked_screen", true)
                putExtra("blocked_app_name", appName)
                putExtra("blocked_package_name", packageName)
            }
            
            Log.d("ScrollOff", "Launching MainActivity with blocked screen intent")
            startActivity(intent)
            
        } catch (e: Exception) {
            Log.e("ScrollOff", "Failed to show blocked screen", e)
        }
    }
}
