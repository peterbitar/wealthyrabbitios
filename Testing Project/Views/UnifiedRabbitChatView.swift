import SwiftUI
import AVFoundation
import Speech
import Combine

// MARK: - Unified Rabbit Chat View
// Single unified chat interface (no rabbit type switching)
struct UnifiedRabbitChatView: View {
    @ObservedObject var viewModel: RabbitViewModel
    @State private var messageText = ""
    @FocusState private var isInputFocused: Bool
    @State private var showCallModeModal = false
    @State private var isRabbitTyping = false
    @StateObject private var voiceRecorder = VoiceRecorderManager()
    
    // Get the unified Rabbit conversation
    private var conversation: Conversation {
        viewModel.getUnifiedRabbitConversation()
    }
    
    // Get current messages from the conversation
    private var currentMessages: [Message] {
        viewModel.conversations.first(where: { $0.id == conversation.id })?.messages ?? conversation.messages
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                WealthyRabbitTheme.chatBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Messages list
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(currentMessages) { message in
                                    if message.type == .voiceNote {
                                        // Show voice note messages from Rabbit
                                        VoiceNoteMessage(
                                            message: message,
                                            accentColor: WealthyRabbitTheme.mossGreen
                                        )
                                        .id(message.id)
                                    } else if message.type == .ctaCallMode {
                                        // Skip rendering old CTA messages - call is now in header
                                        EmptyView()
                                            .id(message.id)
                                    } else {
                                        RabbitMessageBubble(
                                            message: message,
                                            accentColor: WealthyRabbitTheme.mossGreen
                                        )
                                        .id(message.id)
                                    }
                                }
                                
                                // Typing indicator
                                if isRabbitTyping {
                                    RabbitTypingIndicator(accentColor: WealthyRabbitTheme.mossGreen)
                                        .id("typing-indicator")
                                }
                            }
                            .padding(.horizontal, WealthyRabbitTheme.normalSpacing)
                            .padding(.vertical, WealthyRabbitTheme.normalSpacing)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // Dismiss keyboard when tapping outside
                            isInputFocused = false
                        }
                        .onChange(of: currentMessages.count) { oldValue, newValue in
                            if let lastMessage = currentMessages.last {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                            }
                        }
                        .onChange(of: isRabbitTyping) { oldValue, newValue in
                            if newValue {
                                // Scroll to typing indicator when it appears
                                withAnimation(.easeOut(duration: 0.3)) {
                                    proxy.scrollTo("typing-indicator", anchor: .bottom)
                                }
                            } else if let lastMessage = currentMessages.last {
                                // Scroll to last message when typing stops
                                withAnimation(.easeOut(duration: 0.3)) {
                                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                            }
                        }
                        .onAppear {
                            if let lastMessage = currentMessages.last {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                            
                            // Check for portfolio changes when RabbitChat becomes visible
                            viewModel.checkForPortfolioChanges()
                        }
                    }
                    
                    // Message input
                    CalmMessageInput(
                        messageText: $messageText,
                        isInputFocused: _isInputFocused,
                        accentColor: WealthyRabbitTheme.mossGreen,
                        onSend: sendMessage,
                        voiceRecorder: voiceRecorder,
                        onVoiceNoteTranscribed: { transcribedText in
                            // Send the transcribed text as a message
                            messageText = transcribedText
                            sendMessage()
                        }
                    )
                }
            }
            .navigationTitle("Rabbit")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showCallModeModal) {
                CallModeComingSoonModal()
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Text("🐇")
                            .font(.system(size: 16))
                        Text("Rabbit")
                            .font(WealthyRabbitTheme.bodyFont)
                            .fontWeight(.semibold)
                    }
                }
                
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    // Rabbit Brief button
                    Button(action: {
                        viewModel.generateRabbitBrief()
                    }) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 16))
                            .foregroundColor(WealthyRabbitTheme.mossGreen)
                    }
                    
                    // Call icon
                    Button(action: {
                        showCallModeModal = true
                    }) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 18))
                            .foregroundColor(WealthyRabbitTheme.mossGreen)
                    }
                }
            }
        }
    }
    
    func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let currentConversation = viewModel.getUnifiedRabbitConversation()
        viewModel.sendMessage(to: currentConversation, text: messageText)
        let _ = messageText
        messageText = ""
        
        // Show typing indicator BEFORE starting OpenAI call
        isRabbitTyping = true
        
        // Get AI response
        Task {
            await viewModel.getAIResponse(for: currentConversation) {
                // Hide typing indicator when response is received
                Task { @MainActor in
                    // Small delay to make it feel more natural
                    try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
                    isRabbitTyping = false
                }
            }
        }
    }
}

// MARK: - Typing Indicator Component
struct RabbitTypingIndicator: View {
    let accentColor: Color
    @State private var animatedDot: Int = 0
    @State private var timer: Timer?
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Spacer(minLength: 50)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Text("Rabbit is thinking")
                        .font(WealthyRabbitTheme.bodyFont)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 3) {
                        ForEach(0..<3) { index in
                            Circle()
                                .fill(accentColor.opacity(animatedDot == index ? 0.8 : 0.4))
                                .frame(width: 6, height: 6)
                                .offset(y: animatedDot == index ? -4 : 0)
                                .animation(
                                    .easeInOut(duration: 0.4),
                                    value: animatedDot
                                )
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.8))
                .cornerRadius(18)
            }
            
            Spacer(minLength: 50)
        }
        .onAppear {
            // Cycle through dots with a timer
            timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
                withAnimation {
                    animatedDot = (animatedDot + 1) % 3
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
}

// MARK: - Voice Note Message Component
struct VoiceNoteMessage: View {
    let message: Message
    let accentColor: Color
    @State private var showComingSoonAlert = false
    
    // Static waveform pattern for audio bar
    private let barHeights: [CGFloat] = [12, 18, 14, 20, 10, 16, 12, 18, 14, 20, 10, 16, 12, 18, 14, 20, 10, 16, 12, 18]
    
    var durationString: String {
        let duration = message.durationSeconds ?? 0
        let minutes = duration / 60
        let seconds = duration % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Spacer(minLength: 50)
            
            VStack(alignment: .leading, spacing: 8) {
                // Voice note bubble
                Button(action: {
                    showComingSoonAlert = true
                }) {
                    HStack(spacing: 12) {
                        // Play icon
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(accentColor)
                        
                        // Audio bar visual (static waveform pattern)
                        HStack(spacing: 3) {
                            ForEach(0..<20) { index in
                                RoundedRectangle(cornerRadius: 1.5)
                                    .fill(accentColor.opacity(0.6))
                                    .frame(width: 2, height: barHeights[index])
                            }
                        }
                        .frame(width: 120, height: 20)
                        
                        // Duration label
                        Text(durationString)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(18)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Optional caption text
                if !message.text.isEmpty {
                    Text(message.text)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                }
                
                Text(formatMessageTime(message.timestamp))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.7))
                    .padding(.horizontal, 6)
            }
            
            Spacer(minLength: 50)
        }
        .alert("Voice Notes (Coming Soon)", isPresented: $showComingSoonAlert) {
            Button("Got it", role: .cancel) { }
        } message: {
            Text("Voice notes are coming soon.")
        }
    }
    
    func formatMessageTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Message Bubble Component
// Reused from RabbitChatView
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

// MARK: - Message Input Component
// Reused from RabbitChatView
struct CalmMessageInput: View {
    @Binding var messageText: String
    @FocusState var isInputFocused: Bool
    let accentColor: Color
    let onSend: () -> Void
    @ObservedObject var voiceRecorder: VoiceRecorderManager
    let onVoiceNoteTranscribed: (String) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Text input with voice note button inside
            HStack(spacing: 8) {
                TextField("Message", text: $messageText, axis: .vertical)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(WealthyRabbitTheme.bodyFont)
                    .focused($isInputFocused)
                    .lineLimit(1...5)
                
                // Voice note button inside the text box (always visible)
                Button(action: {
                    if voiceRecorder.isRecording {
                        voiceRecorder.stopRecording { transcribedText in
                            if !transcribedText.isEmpty {
                                onVoiceNoteTranscribed(transcribedText)
                            }
                        }
                    } else {
                        voiceRecorder.startRecording()
                    }
                }) {
                    Image(systemName: voiceRecorder.isRecording ? "stop.circle.fill" : "mic.fill")
                        .font(.system(size: 18))
                        .foregroundColor(voiceRecorder.isRecording ? .red : accentColor)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(PlainButtonStyle())
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            if !voiceRecorder.isRecording {
                                voiceRecorder.startRecording()
                            }
                        }
                        .onEnded { _ in
                            if voiceRecorder.isRecording {
                                voiceRecorder.stopRecording { transcribedText in
                                    if !transcribedText.isEmpty {
                                        onVoiceNoteTranscribed(transcribedText)
                                    }
                                }
                            }
                        }
                )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.8))
            .cornerRadius(22)
            
            // Send button (when text is not empty)
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
        .onChange(of: voiceRecorder.isRecording) { oldValue, newValue in
            if newValue {
                // Dismiss keyboard when recording starts
                isInputFocused = false
            }
        }
    }
}

// MARK: - Call Mode CTA Message Component
struct CallModeCTAMessage: View {
    let message: Message
    let accentColor: Color
    let onCallButtonTapped: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Spacer(minLength: 50)
            
            VStack(alignment: .leading, spacing: 12) {
                // Rabbit's CTA text
                Text(message.text)
                    .font(WealthyRabbitTheme.bodyFont)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.8))
                    .foregroundColor(.primary)
                    .cornerRadius(18)
                
                // Call the Rabbit button
                Button(action: onCallButtonTapped) {
                    HStack(spacing: 8) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Call the Rabbit")
                            .font(WealthyRabbitTheme.bodyFont)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(accentColor)
                    .cornerRadius(20)
                }
                
                Text(formatMessageTime(message.timestamp))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.7))
                    .padding(.horizontal, 6)
            }
            
            Spacer(minLength: 50)
        }
    }
    
    func formatMessageTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Call Mode Coming Soon Modal
struct CallModeComingSoonModal: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                WealthyRabbitTheme.burrowGradient
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Icon
                    Image(systemName: "phone.fill")
                        .font(.system(size: 48))
                        .foregroundColor(WealthyRabbitTheme.mossGreen)
                        .padding(.top, 40)
                    
                    // Title
                    Text("Call Mode (Coming Soon)")
                        .font(WealthyRabbitTheme.headingFont)
                        .foregroundColor(.primary)
                    
                    // Body text
                    Text("Soon, this will play a short 30–45 second voice explanation from the Rabbit. For now, this is just a preview of the feature.")
                        .font(WealthyRabbitTheme.bodyFont)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    
                    Spacer()
                    
                    // Close button
                    Button(action: { dismiss() }) {
                        Text("Got it")
                            .font(WealthyRabbitTheme.bodyFont)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(WealthyRabbitTheme.mossGreen)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Voice Recorder Manager
class VoiceRecorderManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var capturedTranscription: String = ""
    private var recordingTimer: Timer?
    
    override init() {
        super.init()
        requestSpeechAuthorization()
    }
    
    func requestSpeechAuthorization() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    print("✅ Speech recognition authorized")
                case .denied, .restricted, .notDetermined:
                    print("⚠️ Speech recognition not authorized: \(authStatus)")
                @unknown default:
                    break
                }
            }
        }
    }
    
    func startRecording() {
        guard !isRecording else { return }
        
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                guard granted else {
                    print("❌ Microphone permission denied")
                    return
                }
                
                DispatchQueue.main.async {
                    self?.startSpeechRecognitionWithCapture()
                }
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                guard granted else {
                    print("❌ Microphone permission denied")
                    return
                }
                
                DispatchQueue.main.async {
                    self?.startSpeechRecognitionWithCapture()
                }
            }
        }
    }
    
    private func startSpeechRecognitionWithCapture() {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            print("❌ Speech recognizer not available")
            return
        }
        
        recognitionTask?.cancel()
        recognitionTask = nil
        capturedTranscription = ""
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("❌ Failed to configure audio session: \(error)")
            return
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            print("❌ Unable to create recognition request")
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            print("❌ Unable to create audio engine")
            return
        }
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
            isRecording = true
            recordingDuration = 0
            
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.recordingDuration += 0.1
            }
            
            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                guard let self = self else { return }
                
                if let error = error {
                    if !error.localizedDescription.contains("cancelled") {
                        print("❌ Speech recognition error: \(error)")
                    }
                    return
                }
                
                if let result = result {
                    let transcription = result.bestTranscription.formattedString
                    self.capturedTranscription = transcription
                    
                    if result.isFinal {
                        print("✅ Final transcription: \(transcription)")
                    }
                }
            }
            
            print("🎤 Started recording")
        } catch {
            print("❌ Failed to start audio engine: \(error)")
            stopRecording { _ in }
        }
    }
    
    func stopRecording(completion: @escaping (String) -> Void) {
        guard isRecording else {
            completion("")
            return
        }
        
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        recognitionRequest?.endAudio()
        
        // Wait for final transcription
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else {
                completion("")
                return
            }
            
            self.isRecording = false
            let finalText = self.capturedTranscription
            self.capturedTranscription = ""
            self.recordingDuration = 0
            
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            
            completion(finalText)
        }
    }
}

#Preview {
    UnifiedRabbitChatView(viewModel: RabbitViewModel(apiKey: Config.openAIAPIKey))
}

