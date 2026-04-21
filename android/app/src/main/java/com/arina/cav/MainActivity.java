package com.arina.cav;

import androidx.annotation.NonNull;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.Context;
import android.app.ActivityManager;
import android.os.Build;
import android.os.Debug;
import android.os.Process;
import android.os.Bundle;
import java.util.HashMap;
import java.util.Map;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "arina.memory";

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        createNotificationChannel();
    }

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
            .setMethodCallHandler((call, result) -> {
                switch (call.method) {
                    case "getMemoryPressure":
                        getMemoryPressure(result);
                        break;
                    case "getMemoryInfo":
                        getMemoryInfo(result);
                        break;
                    case "getMemoryStats":
                        getMemoryStats(result);
                        break;
                    default:
                        result.notImplemented();
                        break;
                }
            });
    }

    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                "audio_channel",
                "Audio Playback",
                NotificationManager.IMPORTANCE_LOW
            );
            channel.setDescription("Audio playback controls");
            channel.setShowBadge(false);
            channel.setLockscreenVisibility(android.app.Notification.VISIBILITY_PUBLIC);
            
            NotificationManager notificationManager = getSystemService(NotificationManager.class);
            notificationManager.createNotificationChannel(channel);
        }
    }

    private void getMemoryPressure(MethodChannel.Result result) {
        try {
            int pressure = getMemoryPressureLevel();
            result.success(pressure);
        } catch (Exception e) {
            result.error("MEMORY_ERROR", e.getMessage(), null);
        }
    }

    private void getMemoryInfo(MethodChannel.Result result) {
        try {
            Map<String, Object> info = getMemoryInfoMap();
            result.success(info);
        } catch (Exception e) {
            result.error("MEMORY_INFO_ERROR", e.getMessage(), null);
        }
    }

    private void getMemoryStats(MethodChannel.Result result) {
        try {
            Map<String, Object> stats = getMemoryStatsMap();
            result.success(stats);
        } catch (Exception e) {
            result.error("STATS_ERROR", e.getMessage(), null);
        }
    }

    private int getMemoryPressureLevel() {
        Context context = getApplicationContext();
        ActivityManager activityManager = (ActivityManager) context.getSystemService(Context.ACTIVITY_SERVICE);
        ActivityManager.MemoryInfo memoryInfo = new ActivityManager.MemoryInfo();
        activityManager.getMemoryInfo(memoryInfo);

        long availableMemMB = memoryInfo.availMem / (1024 * 1024);
        long totalMemMB = getTotalMemory(activityManager);
        float usedPercentage = ((float)(totalMemMB - availableMemMB) / totalMemMB) * 100;

        if (availableMemMB < 100 || usedPercentage > 90) {
            return 3; // Critical
        } else if (availableMemMB < 200 || usedPercentage > 75) {
            return 2; // High
        } else if (availableMemMB < 400 || usedPercentage > 50) {
            return 1; // Medium
        } else {
            return 0; // Low
        }
    }

    private long getTotalMemory(ActivityManager activityManager) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN) {
            ActivityManager.MemoryInfo memoryInfo = new ActivityManager.MemoryInfo();
            activityManager.getMemoryInfo(memoryInfo);
            return memoryInfo.totalMem / (1024 * 1024);
        } else {
            return Runtime.getRuntime().totalMemory() / (1024 * 1024);
        }
    }

    private Map<String, Object> getMemoryInfoMap() {
        Context context = getApplicationContext();
        ActivityManager activityManager = (ActivityManager) context.getSystemService(Context.ACTIVITY_SERVICE);
        ActivityManager.MemoryInfo memoryInfo = new ActivityManager.MemoryInfo();
        activityManager.getMemoryInfo(memoryInfo);

        // Get app memory usage
        int pid = Process.myPid();
        int[] pids = {pid};
        Debug.MemoryInfo[] memoryInfoArray = activityManager.getProcessMemoryInfo(pids);
        Debug.MemoryInfo myMemInfo = memoryInfoArray[0];

        Map<String, Object> info = new HashMap<>();
        
        // System memory
        info.put("availableMemMB", memoryInfo.availMem / (1024 * 1024));
        info.put("totalMemMB", getTotalMemory(activityManager));
        info.put("thresholdMB", memoryInfo.threshold / (1024 * 1024));
        info.put("lowMemory", memoryInfo.lowMemory);
        info.put("usedPercentage", calculateUsedPercentage(memoryInfo, activityManager));
        
        // App memory
        info.put("appMemoryMB", myMemInfo.getTotalPss() / 1024);
        info.put("nativeHeapMB", Debug.getNativeHeapAllocatedSize() / (1024 * 1024));
        
        long dalvikHeap = Runtime.getRuntime().totalMemory() - Runtime.getRuntime().freeMemory();
        info.put("dalvikHeapMB", dalvikHeap / (1024 * 1024));
        
        // Device info
        info.put("deviceModel", Build.MODEL);
        info.put("deviceBrand", Build.BRAND);
        info.put("sdkVersion", Build.VERSION.SDK_INT);
        info.put("platform", "Android");
        
        return info;
    }

    private Map<String, Object> getMemoryStatsMap() {
        Context context = getApplicationContext();
        ActivityManager activityManager = (ActivityManager) context.getSystemService(Context.ACTIVITY_SERVICE);
        ActivityManager.MemoryInfo memoryInfo = new ActivityManager.MemoryInfo();
        activityManager.getMemoryInfo(memoryInfo);

        long availableMemMB = memoryInfo.availMem / (1024 * 1024);
        long totalMemMB = getTotalMemory(activityManager);
        int pressure = getMemoryPressureLevel();

        Map<String, Object> stats = new HashMap<>();
        stats.put("current", totalMemMB - availableMemMB);
        stats.put("available", availableMemMB);
        stats.put("total", totalMemMB);
        stats.put("pressure", pressure);
        stats.put("isCritical", pressure == 3);
        stats.put("timestamp", System.currentTimeMillis());
        
        return stats;
    }

    private float calculateUsedPercentage(ActivityManager.MemoryInfo memoryInfo, ActivityManager activityManager) {
        long totalMem = getTotalMemory(activityManager);
        long availableMem = memoryInfo.availMem / (1024 * 1024);
        return ((float)(totalMem - availableMem) / totalMem) * 100;
    }
}