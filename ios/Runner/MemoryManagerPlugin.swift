// ios/Runner/MemoryManagerPlugin.swift
import Flutter
import UIKit

public class MemoryManagerPlugin: NSObject, FlutterPlugin {
    
    // MARK: - Registration
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "arina.memory",
            binaryMessenger: registrar.messenger()
        )
        let instance = MemoryManagerPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    // MARK: - Method Handling
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getMemoryPressure":
            getMemoryPressure(result: result)
        case "getMemoryInfo":
            getMemoryInfo(result: result)
        case "getMemoryStats":
            getMemoryStats(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - Memory Pressure Detection
    private func getMemoryPressure(result: @escaping FlutterResult) {
        do {
            let memoryUsage = try getMemoryUsage()
            let pressureLevel = calculatePressureLevel(memoryUsage: memoryUsage)
            result(pressureLevel)
        } catch {
            result(FlutterError(
                code: "MEMORY_ERROR",
                message: "Failed to get memory pressure: \(error)",
                details: nil
            ))
        }
    }
    
    // MARK: - Detailed Memory Information
    private func getMemoryInfo(result: @escaping FlutterResult) {
        do {
            let memoryUsage = try getMemoryUsage()
            let deviceMemory = getDeviceMemoryInfo()
            let appMemory = getAppMemoryUsage()
            
            let memoryInfo: [String: Any] = [
                // Memory usage statistics
                "usedMemMB": memoryUsage.used,
                "availableMemMB": memoryUsage.available,
                "totalMemMB": memoryUsage.total,
                "usedPercentage": Double(memoryUsage.used) * 100.0 / Double(memoryUsage.total),
                
                // App-specific memory
                "appUsedMemoryMB": appMemory.appUsed,
                "appFreeMemoryMB": appMemory.appFree,
                "appTotalMemoryMB": appMemory.appTotal,
                
                // Device info
                "deviceModel": UIDevice.current.model,
                "deviceName": UIDevice.current.name,
                "systemVersion": UIDevice.current.systemVersion,
                "systemName": UIDevice.current.systemName,
                
                // Platform info
                "platform": "iOS",
                "isLowPowerMode": ProcessInfo.processInfo.isLowPowerModeEnabled,
                "physicalMemoryMB": deviceMemory.physicalMemory,
                "userMemoryMB": deviceMemory.userMemory,
                "timestamp": Date().timeIntervalSince1970,
            ]
            
            result(memoryInfo)
        } catch {
            result(FlutterError(
                code: "MEMORY_INFO_ERROR",
                message: "Failed to get memory info: \(error)",
                details: nil
            ))
        }
    }
    
    // MARK: - Memory Statistics
    private func getMemoryStats(result: @escaping FlutterResult) {
        do {
            let memoryUsage = try getMemoryUsage()
            let stats: [String: Any] = [
                "current": memoryUsage.used,
                "available": memoryUsage.available,
                "total": memoryUsage.total,
                "pressure": calculatePressureLevel(memoryUsage: memoryUsage),
                "isCritical": isMemoryCritical(memoryUsage: memoryUsage),
                "timestamp": Date().timeIntervalSince1970,
            ]
            result(stats)
        } catch {
            result(FlutterError(
                code: "STATS_ERROR",
                message: "Failed to get memory stats: \(error)",
                details: nil
            ))
        }
    }
    
    // MARK: - Memory Usage Calculation
    private func getMemoryUsage() throws -> (used: Int64, available: Int64, total: Int64) {
        var taskInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }
        
        guard kerr == KERN_SUCCESS else {
            throw NSError(
                domain: "MemoryManager",
                code: Int(kerr),
                userInfo: [NSLocalizedDescriptionKey: "Failed to get task info"]
            )
        }
        
        let usedBytes = Int64(taskInfo.resident_size)
        let totalBytes = Int64(ProcessInfo.processInfo.physicalMemory)
        let availableBytes = totalBytes - usedBytes
        
        return (
            used: usedBytes / (1024 * 1024),
            available: availableBytes / (1024 * 1024),
            total: totalBytes / (1024 * 1024)
        )
    }
    
    // MARK: - Device Memory Info
    private func getDeviceMemoryInfo() -> (physicalMemory: Int64, userMemory: Int64) {
        let physicalMemory = Int64(ProcessInfo.processInfo.physicalMemory) / (1024 * 1024)
        
        // Get user memory (memory available to apps)
        var userMemory = physicalMemory
        
        // On iOS, user memory is typically about 80% of physical memory
        // This is an approximation - actual value depends on device
        #if os(iOS)
        userMemory = Int64(Double(physicalMemory) * 0.8)
        #endif
        
        return (physicalMemory: physicalMemory, userMemory: userMemory)
    }
    
    // MARK: - App Memory Usage
    private func getAppMemoryUsage() -> (appUsed: Int64, appFree: Int64, appTotal: Int64) {
        let memoryUsage = try? getMemoryUsage()
        let appUsed = memoryUsage?.used ?? 0
        
        // Get memory footprint (includes more than just resident size)
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info>.size) / 4
        
        let kerr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(TASK_VM_INFO),
                    $0,
                    &count
                )
            }
        }
        
        var footprint: Int64 = 0
        if kerr == KERN_SUCCESS {
            footprint = Int64(info.phys_footprint) / (1024 * 1024)
        }
        
        let deviceMemory = getDeviceMemoryInfo()
        let appTotal = deviceMemory.userMemory
        let appFree = max(0, appTotal - footprint)
        
        return (
            appUsed: max(footprint, appUsed),
            appFree: appFree,
            appTotal: appTotal
        )
    }
    
    // MARK: - Pressure Level Calculation
    private func calculatePressureLevel(memoryUsage: (used: Int64, available: Int64, total: Int64)) -> Int {
        let usedPercentage = Double(memoryUsage.used) * 100.0 / Double(memoryUsage.total)
        
        // iOS memory pressure thresholds
        if memoryUsage.available < 100 || usedPercentage > 90 {
            return 3 // Critical
        } else if memoryUsage.available < 200 || usedPercentage > 75 {
            return 2 // High
        } else if memoryUsage.available < 400 || usedPercentage > 50 {
            return 1 // Medium
        } else {
            return 0 // Low
        }
    }
    
    // MARK: - Critical Memory Check
    private func isMemoryCritical(memoryUsage: (used: Int64, available: Int64, total: Int64)) -> Bool {
        let usedPercentage = Double(memoryUsage.used) * 100.0 / Double(memoryUsage.total)
        return memoryUsage.available < 100 || usedPercentage > 90
    }
}