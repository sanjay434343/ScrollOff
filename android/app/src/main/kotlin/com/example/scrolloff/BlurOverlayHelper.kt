package com.app.scrolloff

import android.content.Context
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.view.View

object BlurOverlayHelper {
    
    fun createThemedBackground(context: Context): GradientDrawable {
        // Return transparent background since we're using full black screen
        return GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            setColor(Color.TRANSPARENT) // Transparent since parent has black background
        }
    }
    
    fun getThemedTextColor(context: Context, isTitle: Boolean = false): Int {
        val isDarkMode = isSystemDarkMode(context)
        
        return if (isDarkMode) {
            if (isTitle) Color.parseColor("#FFFFFFFF") else Color.parseColor("#FFE2E8F0")
        } else {
            if (isTitle) Color.parseColor("#FF1A202C") else Color.parseColor("#FF4A5568")
        }
    }
    
    fun getThemedAccentColor(context: Context): Int {
        return Color.parseColor("#FFE53E3E") // Red accent works in both themes
    }
    
    fun getThemedMutedColor(context: Context): Int {
        val isDarkMode = isSystemDarkMode(context)
        return if (isDarkMode) {
            Color.parseColor("#FFA0AEC0")
        } else {
            Color.parseColor("#FF718096")
        }
    }
    
    fun getThemedInfoBackground(context: Context): GradientDrawable {
        val isDarkMode = isSystemDarkMode(context)
        
        return GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = 20f
            
            if (isDarkMode) {
                setColor(Color.parseColor("#FF2D3748"))
                setStroke(1, Color.parseColor("#FF4A5568"))
            } else {
                setColor(Color.parseColor("#FFF7FAFC"))
                setStroke(1, Color.parseColor("#FFE2E8F0"))
            }
        }
    }
    
    fun applyBlurEffect(view: View) {
        // No blur effect needed for fullscreen black background
        view.alpha = 1.0f
        view.elevation = 0f
    }
    
    private fun isSystemDarkMode(context: Context): Boolean {
        val nightModeFlags = context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
        return nightModeFlags == Configuration.UI_MODE_NIGHT_YES
    }
}
