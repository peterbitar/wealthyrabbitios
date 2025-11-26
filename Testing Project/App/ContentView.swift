//
//  ContentView.swift
//  Testing Project
//
//  Created by Peter on 2025-11-07.
//

import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var viewModel = RabbitViewModel(apiKey: Config.openAIAPIKey)
    @State private var selectedTab = 0  // Feed is now the default (tag 0)

    var body: some View {
        TabView(selection: $selectedTab) {
            // Rabbit Feed Tab (Default Home Page - Event Cards)
            RabbitFeedView(viewModel: viewModel)
                .tabItem {
                    Image(systemName: "newspaper.fill")
                    Text("Feed")
                }
                .tag(0)

            // Rabbit Chat Tab
            UnifiedRabbitChatView(viewModel: viewModel)
                .tabItem {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                    Text("Rabbit")
                }
                .tag(1)
            
            // Portfolio Tab (Holdings & Notifications)
            ReflectView(viewModel: viewModel)
                .tabItem {
                    Image(systemName: "chart.pie.fill")
                    Text("Portfolio")
                }
                .tag(2)

            // Profile Tab
            SettingsView(viewModel: viewModel)
                .tabItem {
                    Image(systemName: "person.circle")
                    Text("Profile")
                }
                .tag(3)
        }
        .tint(WealthyRabbitTheme.primaryColor)
        .onAppear {
            // Configure tab bar appearance to prevent transparency
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(WealthyRabbitTheme.neutralLight)
            
            // Set shadow for better visibility
            appearance.shadowColor = UIColor.black.withAlphaComponent(0.1)
            
            // Apply to all tab bar styles
            UITabBar.appearance().standardAppearance = appearance
            if #available(iOS 15.0, *) {
                UITabBar.appearance().scrollEdgeAppearance = appearance
            }
        }
    }
}

#Preview {
    ContentView()
}
