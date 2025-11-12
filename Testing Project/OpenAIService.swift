import Foundation

struct OpenAIMessage: Codable {
    let role: String
    let content: String
}

struct OpenAIRequest: Codable {
    let model: String
    let messages: [OpenAIMessage]
    let temperature: Double
}

struct OpenAIResponse: Codable {
    let id: String
    let choices: [Choice]

    struct Choice: Codable {
        let message: OpenAIMessage
        let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case message
            case finishReason = "finish_reason"
        }
    }
}

class OpenAIService {
    private let apiKey: String
    private let endpoint = "https://api.openai.com/v1/chat/completions"

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func sendMessage(conversationHistory: [Message], systemPrompt: String? = nil) async throws -> String {
        // Build messages array with optional system prompt
        var openAIMessages: [OpenAIMessage] = []

        // Add system prompt if provided
        if let systemPrompt = systemPrompt {
            openAIMessages.append(OpenAIMessage(role: "system", content: systemPrompt))
        }

        // Convert our Message format to OpenAI format
        let conversationMessages = conversationHistory.map { message in
            OpenAIMessage(
                role: message.isFromCurrentUser ? "user" : "assistant",
                content: message.text
            )
        }
        openAIMessages.append(contentsOf: conversationMessages)

        let request = OpenAIRequest(
            model: "gpt-3.5-turbo",
            messages: openAIMessages,
            temperature: 0.7
        )

        guard let url = URL(string: endpoint) else {
            throw OpenAIError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if let errorString = String(data: data, encoding: .utf8) {
                print("OpenAI API Error: \(errorString)")
            }
            throw OpenAIError.apiError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        let openAIResponse = try decoder.decode(OpenAIResponse.self, from: data)

        guard let firstChoice = openAIResponse.choices.first else {
            throw OpenAIError.noResponse
        }

        return firstChoice.message.content
    }
}

enum OpenAIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case apiError(statusCode: Int)
    case noResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from OpenAI"
        case .apiError(let statusCode):
            return "API error with status code: \(statusCode)"
        case .noResponse:
            return "No response from OpenAI"
        }
    }
}
