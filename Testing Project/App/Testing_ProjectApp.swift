//
//  Testing_ProjectApp.swift
//  Testing Project
//
//  Created by Peter on 2025-11-07.
//

import SwiftUI

@main
struct Testing_ProjectApp: App {
    // Register AppDelegate for push notifications
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var pushManager = PushNotificationManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // Request push notification permissions on app launch
                    let granted = await pushManager.requestPermission()
                    if granted {
                        print("✅ Push notifications enabled")
                    } else {
                        print("⚠️ Push notifications denied")
                    }
                }
        }
    }
}
