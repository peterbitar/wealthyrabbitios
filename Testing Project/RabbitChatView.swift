import SwiftUI

struct RabbitChatView: View {
    let conversation: Conversation
    let rabbitType: RabbitType
    @ObservedObject var viewModel: RabbitViewModel
    @State private var messageText = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        ZStack {
            WealthyRabbitTheme.chatBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Messages list
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(currentMessages) { message in
                                RabbitMessageBubble(
                                    message: message,
                                    accentColor: rabbitType.accentColor
                                )
                                .id(message.id)
                            }
                        }
                        .padding(.horizontal, WealthyRabbitTheme.normalSpacing)
                        .padding(.vertical, WealthyRabbitTheme.normalSpacing)
                    }
                    .onChange(of: currentMessages.count) { oldValue, newValue in
                        if let lastMessage = currentMessages.last {
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                    .onAppear {
                        if let lastMessage = currentMessages.last {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }

                // Message input
                CalmMessageInput(
                    messageText: $messageText,
                    isInputFocused: _isInputFocused,
                    accentColor: rabbitType.accentColor,
                    onSend: sendMessage
                )
            }
        }
        .navigationTitle(rabbitType.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    HStack(spacing: 6) {
                        Text(rabbitType.emoji)
                            .font(.system(size: 16))
                        Text(rabbitType.rawValue)
                            .font(WealthyRabbitTheme.bodyFont)
                            .fontWeight(.semibold)
                    }
                    Text(rabbitType.focus)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    var currentMessages: [Message] {
        viewModel.conversations.first(where: { $0.id == conversation.id })?.messages ?? conversation.messages
    }

    func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        viewModel.sendMessage(to: conversation, text: messageText)
        messageText = ""

        // Get AI response
        Task {
            await viewModel.getAIResponse(for: conversation)
        }
    }
}

struct RabbitMessageBubble: View {
    let message: Message
    let accentColor: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.isFromCurrentUser {
                Spacer(minLength: 50)
            }

            VStack(alignment: message.isFromCurrentUser ? .trailing : .leading, spacing: 6) {
                Text(message.text)
                    .font(WealthyRabbitTheme.bodyFont)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(message.isFromCurrentUser ? accentColor.opacity(0.3) : Color.white.opacity(0.8))
                    .foregroundColor(.primary)
                    .cornerRadius(18)

                Text(formatMessageTime(message.timestamp))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.7))
                    .padding(.horizontal, 6)
            }

            if !message.isFromCurrentUser {
                Spacer(minLength: 50)
            }
        }
    }

    func formatMessageTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct CalmMessageInput: View {
    @Binding var messageText: String
    @FocusState var isInputFocused: Bool
    let accentColor: Color
    let onSend: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Text input
            HStack {
                TextField("Message", text: $messageText, axis: .vertical)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(WealthyRabbitTheme.bodyFont)
                    .focused($isInputFocused)
                    .lineLimit(1...5)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.8))
            .cornerRadius(22)

            // Send button
            if !messageText.isEmpty {
                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(accentColor)
                }
            }
        }
        .padding(.horizontal, WealthyRabbitTheme.normalSpacing)
        .padding(.vertical, 12)
        .background(WealthyRabbitTheme.chatBackground)
    }
}

#Preview {
    NavigationView {
        RabbitChatView(
            conversation: Conversation(
                contactName: "Holdings Rabbit",
                contactAvatar: "🐇",
                messages: [
                    Message(text: "Hello! Your portfolio looks steady today.", isFromCurrentUser: false),
                    Message(text: "What's the outlook for tech stocks?", isFromCurrentUser: true)
                ]
            ),
            rabbitType: .holdings,
            viewModel: RabbitViewModel(apiKey: Config.openAIAPIKey)
        )
    }
}
