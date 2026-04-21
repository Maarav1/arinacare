// ios/Runner/AppDelegate.swift
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    // Initialize Flutter
    GeneratedPluginRegistrant.register(with: self)
    
    // Register our custom MemoryManagerPlugin
    if let controller = window?.rootViewController as? FlutterViewController {
      MemoryManagerPlugin.register(with: controller.binaryMessenger)
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}