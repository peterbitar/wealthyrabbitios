import Foundation
import Combine

enum MessageType: String, Codable {
    case text = "text"
    case dailyBrief = "daily_brief"
    case notification = "notification"
    case ctaCallMode = "cta_call_mode"
    case explanation = "explanation"  // Longer, more complex Rabbit responses
    case voiceNote = "voice_note"  // Voice note style message
}

struct Message: Identifiable, Codable {
    let id: UUID
    let text: String
    let timestamp: Date
    let isFromCurrentUser: Bool
    let type: MessageType  // Message type (text, cta_call_mode, etc.)
    let durationSeconds: Int?  // Optional duration for voice notes
    let audioUrl: String?  // Optional audio URL for voice notes (for later)
    
    init(id: UUID = UUID(), text: String, timestamp: Date = Date(), isFromCurrentUser: Bool, type: MessageType = .text, durationSeconds: Int? = nil, audioUrl: String? = nil) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
        self.isFromCurrentUser = isFromCurrentUser
        self.type = type
        self.durationSeconds = durationSeconds
        self.audioUrl = audioUrl
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

