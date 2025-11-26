import Foundation
import AVFoundation

// MARK: - ElevenLabs Service
// Generates realistic AI voices using ElevenLabs API
class ElevenLabsService {
    private let apiKey: String
    private let endpoint = "https://api.elevenlabs.io/v1/text-to-speech"
    
    // Default voice ID - you can change this to any ElevenLabs voice ID
    // Popular voices: "21m00Tcm4TlvDq8ikWAM" (Rachel - warm, conversational), "AZnzlk1XvdvUeBnXmlld" (Domi - expressive), "EXAVITQu4vr4xnSDxMaL" (Bella - warm), "ErXwobaYiN019PkySvjV" (Antoni - friendly)
    private let defaultVoiceId = "UGTtbzgh3HObxRjWaSpr" // Custom voice ID
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    // Generate audio from text using ElevenLabs
    func generateSpeech(text: String, voiceId: String? = nil) async throws -> Data {
        let voice = voiceId ?? defaultVoiceId
        let urlString = "\(endpoint)/\(voice)"
        
        print("🎙️ ElevenLabs: Generating speech for text (length: \(text.count))")
        print("🎙️ ElevenLabs: Using voice ID: \(voice)")
        print("🎙️ ElevenLabs: API endpoint: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            print("❌ ElevenLabs: Invalid URL: \(urlString)")
            throw ElevenLabsError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.timeoutInterval = 30.0  // Increase timeout for audio generation
        
        // ElevenLabs request body
        // Using eleven_turbo_v2_5 for best quality and speed (available with starter subscription)
        let requestBody: [String: Any] = [
            "text": text,
            "model_id": "eleven_turbo_v2_5", // Fast, high-quality model available with starter subscription
            "voice_settings": [
                "stability": 0.3,  // Lower stability = more expressive, varied, and emotional (was 0.4)
                "similarity_boost": 0.75,  // Slightly lower for more natural variation (was 0.8)
                "style": 0.8,  // Higher style = much more expressive and dynamic (was 0.6)
                "use_speaker_boost": true
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ElevenLabsError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ ElevenLabs API Error:")
            print("   Status Code: \(httpResponse.statusCode)")
            print("   Error Message: \(errorMessage)")
            print("   Response Headers: \(httpResponse.allHeaderFields)")
            throw ElevenLabsError.apiError(httpResponse.statusCode, errorMessage)
        }
        
        return data
    }
}

enum ElevenLabsError: LocalizedError {
    case invalidURL
    case invalidResponse
    case apiError(Int, String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid ElevenLabs API URL"
        case .invalidResponse:
            return "Invalid response from ElevenLabs API"
        case .apiError(let code, let message):
            return "ElevenLabs API error \(code): \(message)"
        }
    }
}

