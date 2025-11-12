import Foundation
import Combine

struct Message: Identifiable, Codable {
    let id: UUID
    let text: String
    let timestamp: Date
    let isFromCurrentUser: Bool

    init(id: UUID = UUID(), text: String, timestamp: Date = Date(), isFromCurrentUser: Bool) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
        self.isFromCurrentUser = isFromCurrentUser
    }
}

struct Conversation: Identifiable, Codable {
    let id: UUID
    let contactName: String
    let contactAvatar: String
    var messages: [Message]
    var lastMessage: Message? {
        messages.last
    }

    init(id: UUID = UUID(), contactName: String, contactAvatar: String, messages: [Message] = []) {
        self.id = id
        self.contactName = contactName
        self.contactAvatar = contactAvatar
        self.messages = messages
    }
}

class ChatViewModel: ObservableObject {
    @Published var conversations: [Conversation] = []
    private var openAIService: OpenAIService?

    init(apiKey: String = "") {
        if !apiKey.isEmpty {
            self.openAIService = OpenAIService(apiKey: apiKey)
        }
        loadSampleData()
    }

    func loadSampleData() {
        conversations = [
            Conversation(
                contactName: "ChatGPT Assistant",
                contactAvatar: "🤖",
                messages: [
                    Message(text: "Hello! I'm your AI assistant. How can I help you today?", timestamp: Date().addingTimeInterval(-60), isFromCurrentUser: false)
                ]
            )
        ]
    }

    func sendMessage(to conversation: Conversation, text: String) {
        if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
            let newMessage = Message(text: text, isFromCurrentUser: true)
            conversations[index].messages.append(newMessage)
        }
    }

    func addIncomingMessage(to conversation: Conversation, text: String) {
        if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
            let newMessage = Message(text: text, isFromCurrentUser: false)
            conversations[index].messages.append(newMessage)
        }
    }

    func getAIResponse(for conversation: Conversation) async {
        guard let openAIService = openAIService else {
            // Fallback to random replies if no API key
            await MainActor.run {
                let replies = [
                    "That's interesting!",
                    "I see what you mean",
                    "Tell me more",
                    "Sounds good to me!",
                    "Let's do it!"
                ]
                if let randomReply = replies.randomElement() {
                    addIncomingMessage(to: conversation, text: randomReply)
                }
            }
            return
        }

        guard let conversationIndex = conversations.firstIndex(where: { $0.id == conversation.id }) else {
            return
        }

        let conversationHistory = conversations[conversationIndex].messages

        do {
            let response = try await openAIService.sendMessage(conversationHistory: conversationHistory)
            await MainActor.run {
                addIncomingMessage(to: conversation, text: response)
            }
        } catch {
            await MainActor.run {
                addIncomingMessage(to: conversation, text: "Sorry, I encountered an error: \(error.localizedDescription)")
            }
        }
    }
}
