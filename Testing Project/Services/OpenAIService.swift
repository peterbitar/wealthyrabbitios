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
        // Retry logic with exponential backoff for rate limits
        let maxRetries = 3
        var retryDelay: TimeInterval = 0.5 // Start with 500ms
        
        for attempt in 0..<maxRetries {
            do {
                return try await performRequest(conversationHistory: conversationHistory, systemPrompt: systemPrompt)
            } catch OpenAIError.apiError(let statusCode) where statusCode == 429 {
                // Rate limit error - retry with exponential backoff
                if attempt < maxRetries - 1 {
                    // Parse retry-after from error if available, otherwise use exponential backoff
                    let delay = retryDelay * pow(2.0, Double(attempt))
                    print("⚠️ Rate limit hit (429), retrying in \(String(format: "%.2f", delay))s (attempt \(attempt + 1)/\(maxRetries))")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    retryDelay = delay
                } else {
                    throw OpenAIError.rateLimitExceeded
                }
            } catch {
                // Other errors - don't retry
                throw error
            }
        }
        
        throw OpenAIError.rateLimitExceeded
    }
    
    private func performRequest(conversationHistory: [Message], systemPrompt: String? = nil) async throws -> String {
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
            model: "gpt-4.1-mini", // Using mini for higher rate limits: 200,000 TPM vs 30,000 TPM
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
    case rateLimitExceeded

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
        case .rateLimitExceeded:
            return "Rate limit exceeded after retries"
        }
    }
}
