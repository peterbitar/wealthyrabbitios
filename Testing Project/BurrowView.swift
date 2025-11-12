import SwiftUI
import Combine

struct BurrowView: View {
    @ObservedObject var viewModel: RabbitViewModel
    @State private var currentTime = Date()

    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                WealthyRabbitTheme.burrowGradient
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: WealthyRabbitTheme.relaxedSpacing) {
                        // Header
                        VStack(spacing: 8) {
                            Text(getGreeting())
                                .font(WealthyRabbitTheme.titleFont)
                                .foregroundColor(.primary)

                            Text(getMarketStatus())
                                .font(WealthyRabbitTheme.captionFont)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, WealthyRabbitTheme.normalSpacing)

                        // Rabbit Tiles
                        VStack(spacing: WealthyRabbitTheme.normalSpacing) {
                            ForEach(RabbitType.allCases, id: \.self) { rabbitType in
                                if let conversation = viewModel.getConversation(for: rabbitType) {
                                    NavigationLink(destination: RabbitChatView(
                                        conversation: conversation,
                                        rabbitType: rabbitType,
                                        viewModel: viewModel
                                    )) {
                                        RabbitTile(
                                            rabbitType: rabbitType,
                                            conversation: conversation
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        .padding(.horizontal, WealthyRabbitTheme.normalSpacing)
                        .padding(.bottom, WealthyRabbitTheme.airySpacing)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .onReceive(timer) { _ in
            currentTime = Date()
        }
    }

    func getGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: currentTime)
        let timeOfDay: String

        switch hour {
        case 0..<12: timeOfDay = "morning"
        case 12..<17: timeOfDay = "afternoon"
        default: timeOfDay = "evening"
        }

        return "Good \(timeOfDay), \(viewModel.userSettings.userName) 🕊️"
    }

    func getMarketStatus() -> String {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: currentTime)
        let minute = calendar.component(.minute, from: currentTime)
        let weekday = calendar.component(.weekday, from: currentTime)

        // Weekend
        if weekday == 1 || weekday == 7 {
            return "Markets closed • Opens Monday 9:30 AM"
        }

        // Market hours: 9:30 AM to 4:00 PM ET (simplified)
        if hour < 9 || (hour == 9 && minute < 30) {
            let minutesUntilOpen = (9 - hour) * 60 + (30 - minute)
            if minutesUntilOpen < 60 {
                return "Markets open in \(minutesUntilOpen) minutes"
            }
            return "Markets open at 9:30 AM"
        } else if hour >= 16 {
            return "Markets closed • Opens tomorrow 9:30 AM"
        } else {
            let minutesUntilClose = (15 - hour) * 60 + (60 - minute)
            if minutesUntilClose < 60 {
                return "Markets close in \(minutesUntilClose) minutes"
            }
            return "Markets open"
        }
    }
}

struct RabbitTile: View {
    let rabbitType: RabbitType
    let conversation: Conversation
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: WealthyRabbitTheme.normalSpacing) {
            // Avatar
            Text(rabbitType.emoji)
                .font(.system(size: 44))
                .frame(width: 68, height: 68)
                .background(rabbitType.accentColor.opacity(0.3))
                .clipShape(Circle())
                .offset(y: isHovering ? -2 : 0)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isHovering)

            VStack(alignment: .leading, spacing: 6) {
                // Name
                Text(rabbitType.rawValue)
                    .font(WealthyRabbitTheme.headingFont)
                    .foregroundColor(.primary)

                // Last message preview
                if let lastMessage = conversation.lastMessage {
                    Text(lastMessage.text)
                        .font(WealthyRabbitTheme.bodyFont)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }

            Spacer()

            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .padding(WealthyRabbitTheme.normalSpacing)
        .background(Color.white.opacity(0.7))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
        .onAppear {
            // Subtle animation on appear
            DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 0...0.5)) {
                isHovering = true
            }
        }
    }
}

#Preview {
    BurrowView(viewModel: RabbitViewModel(apiKey: Config.openAIAPIKey))
}
