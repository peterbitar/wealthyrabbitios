import SwiftUI

struct ChatListView: View {
    @StateObject private var viewModel = ChatViewModel(apiKey: Config.openAIAPIKey)
    @State private var searchText = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.vertical, 8)

                // Chat list
                List(viewModel.conversations) { conversation in
                    NavigationLink(destination: ChatDetailView(conversation: conversation, viewModel: viewModel)) {
                        ChatRowView(conversation: conversation)
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("Chats")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {}) {
                        Image(systemName: "square.and.pencil")
                            .foregroundColor(.blue)
                    }
                }
            }
        }
    }
}

struct ChatRowView: View {
    let conversation: Conversation

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Text(conversation.contactAvatar)
                .font(.system(size: 40))
                .frame(width: 56, height: 56)
                .background(Color(.systemGray5))
                .clipShape(Circle())

            // Message preview
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.contactName)
                        .font(.system(size: 17, weight: .semibold))
                    Spacer()
                    if let lastMessage = conversation.lastMessage {
                        Text(formatTime(lastMessage.timestamp))
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                }

                if let lastMessage = conversation.lastMessage {
                    HStack {
                        Text(lastMessage.text)
                            .font(.system(size: 15))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                        Spacer()
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    func formatTime(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM/dd/yy"
            return formatter.string(from: date)
        }
    }
}

#Preview {
    ChatListView()
}
