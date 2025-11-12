//
//  ContentView.swift
//  Testing Project
//
//  Created by Peter on 2025-11-07.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = RabbitViewModel(apiKey: Config.openAIAPIKey)
    @State private var selectedTab = 1

    var body: some View {
        TabView(selection: $selectedTab) {
            // Portfolio Tab (Holdings & Notifications)
            ReflectView(viewModel: viewModel)
                .tabItem {
                    Image(systemName: "chart.pie.fill")
                    Text("Portfolio")
                }
                .tag(0)

            // Burrow (Home) Tab
            BurrowView(viewModel: viewModel)
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Burrow")
                }
                .tag(1)

            // Profile Tab
            SettingsView(viewModel: viewModel)
                .tabItem {
                    Image(systemName: "person.circle")
                    Text("Profile")
                }
                .tag(2)
        }
        .tint(WealthyRabbitTheme.mossGreen)
    }
}

#Preview {
    ContentView()
}
