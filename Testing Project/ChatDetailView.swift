import SwiftUI

struct ChatDetailView: View {
    let conversation: Conversation
    @ObservedObject var viewModel: ChatViewModel
    @State private var messageText = ""
    @State private var messages: [Message]
    @FocusState private var isInputFocused: Bool

    init(conversation: Conversation, viewModel: ChatViewModel) {
        self.conversation = conversation
        self.viewModel = viewModel
        _messages = State(initialValue: conversation.messages)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Messages list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(currentMessages) { message in
                            MessageBubbleView(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .onChange(of: currentMessages.count) { oldValue, newValue in
                    if let lastMessage = currentMessages.last {
                        withAnimation {
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
            MessageInputView(
                messageText: $messageText,
                isInputFocused: _isInputFocused,
                onSend: sendMessage
            )
        }
        .navigationTitle(conversation.contactName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(conversation.contactName)
                        .font(.system(size: 17, weight: .semibold))
                    Text("online")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
        }
    }

    var currentMessages: [Message] {
        viewModel.conversations.first(where: { $0.id == conversation.id })?.messages ?? messages
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

struct MessageBubbleView: View {
    let message: Message

    var body: some View {
        HStack {
            if message.isFromCurrentUser {
                Spacer()
            }

            VStack(alignment: message.isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(message.isFromCurrentUser ? Color.blue : Color(.systemGray5))
                    .foregroundColor(message.isFromCurrentUser ? .white : .primary)
                    .cornerRadius(18)

                Text(formatMessageTime(message.timestamp))
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 4)
            }

            if !message.isFromCurrentUser {
                Spacer()
            }
        }
    }

    func formatMessageTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct MessageInputView: View {
    @Binding var messageText: String
    @FocusState var isInputFocused: Bool
    let onSend: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Plus button
            Button(action: {}) {
                Image(systemName: "plus")
                    .font(.system(size: 22))
                    .foregroundColor(.gray)
            }
            .padding(.leading, 8)

            // Text input
            HStack {
                TextField("Message", text: $messageText, axis: .vertical)
                    .textFieldStyle(PlainTextFieldStyle())
                    .focused($isInputFocused)
                    .lineLimit(1...5)

                Button(action: {}) {
                    Image(systemName: "camera.fill")
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(20)

            // Send button or voice button
            if messageText.isEmpty {
                Button(action: {}) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.gray)
                }
                .padding(.trailing, 8)
            } else {
                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.blue)
                }
                .padding(.trailing, 4)
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
}

#Preview {
    NavigationView {
        ChatDetailView(
            conversation: Conversation(
                contactName: "Alice Johnson",
                contactAvatar: "👩‍💼",
                messages: [
                    Message(text: "Hey! How are you?", isFromCurrentUser: false),
                    Message(text: "I'm good! Thanks for asking", isFromCurrentUser: true)
                ]
            ),
            viewModel: ChatViewModel()
        )
    }
}
