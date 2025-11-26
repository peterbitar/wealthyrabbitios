import SwiftUI

struct ReflectView: View {
    @ObservedObject var viewModel: RabbitViewModel
    @State private var showAddHolding = false
    @State private var editingHolding: Holding?
    @State private var refreshID = UUID()

    // Form fields
    @State private var symbolInput = ""
    @State private var nameInput = ""
    @State private var allocationInput = ""
    @State private var noteInput = ""

    var body: some View {
        let _ = print("🔍 ReflectView rendering - Holdings count: \(viewModel.userSettings.holdings.count)")

        return NavigationView {
            ZStack {
                WealthyRabbitTheme.burrowGradient
                    .ignoresSafeArea()

                List {
                    // Notifications Quick Access
                    Section {
                        NavigationLink(destination: NotificationSettingsView(viewModel: viewModel)) {
                            HStack(spacing: 12) {
                                Image(systemName: "bell.badge.fill")
                                    .foregroundColor(WealthyRabbitTheme.apricot)
                                    .font(.system(size: 18))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Notifications")
                                        .font(WealthyRabbitTheme.bodyFont)
                                        .foregroundColor(.primary)

                                    Text("\(viewModel.userSettings.notificationFrequency.rawValue) · \(viewModel.userSettings.notificationSensitivity.rawValue)")
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                }

                                Spacer()
                            }
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.7))

                    // Holdings Section
                    Section {
                        if viewModel.userSettings.holdings.isEmpty {
                            Button(action: {
                                showAddHolding = true
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(WealthyRabbitTheme.mistBlue)
                                    Text("Add your first holding")
                                        .font(WealthyRabbitTheme.bodyFont)
                                        .foregroundColor(.secondary)
                                }
                            }
                        } else {
                            ForEach(viewModel.userSettings.holdings, id: \.id) { holding in
                                Button(action: {
                                    editHolding(holding)
                                }) {
                                    HStack(spacing: 12) {
                                        // Symbol Badge
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(
                                                    LinearGradient(
                                                        colors: [WealthyRabbitTheme.mistBlue, WealthyRabbitTheme.mistBlue.opacity(0.7)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                                .frame(width: 56, height: 56)

                                            Text(holding.symbol)
                                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                                .foregroundColor(.white)
                                        }
                                        .shadow(color: WealthyRabbitTheme.mistBlue.opacity(0.3), radius: 4, x: 0, y: 2)

                                        // Info Column
                                        VStack(alignment: .leading, spacing: 6) {
                                            // Top Row - Name and Allocation
                                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                                Text(holding.name)
                                                    .font(.system(size: 16, weight: .semibold))
                                                    .foregroundColor(.primary)

                                                if let allocation = holding.allocation {
                                                    Text("\(Int(allocation))%")
                                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                                        .foregroundColor(.white)
                                                        .padding(.horizontal, 7)
                                                        .padding(.vertical, 2)
                                                        .background(
                                                            Capsule()
                                                                .fill(WealthyRabbitTheme.mistBlue.opacity(0.8))
                                                        )
                                                }
                                            }

                                            // Note if exists
                                            if let note = holding.note, !note.isEmpty {
                                                Text(note)
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.secondary)
                                                    .lineLimit(1)
                                            }

                                            // Indicators Row - Compact
                                            if let quote = viewModel.getQuote(for: holding.symbol) {
                                                HStack(spacing: 6) {
                                                    // Price Change - Real Data
                                                    HStack(spacing: 3) {
                                                        Image(systemName: getPriceIcon(quote.changePercent))
                                                            .font(.system(size: 9, weight: .bold))
                                                            .foregroundColor(getPriceColor(quote.changePercent))
                                                        Text(formatPercent(quote.changePercent))
                                                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                                                            .foregroundColor(getPriceColor(quote.changePercent))
                                                    }
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 3)
                                                    .background(getPriceColor(quote.changePercent).opacity(0.12))
                                                    .clipShape(Capsule())

                                                    // Market Feel - Based on real data
                                                    let marketFeel = StockDataService.shared.calculateSentiment(changePercent: quote.changePercent)
                                                    HStack(spacing: 3) {
                                                        Text(getMarketFeelEmoji(marketFeel.rawValue))
                                                            .font(.system(size: 10))
                                                        Text(marketFeel.rawValue)
                                                            .font(.system(size: 11, weight: .medium))
                                                            .foregroundColor(.secondary)
                                                    }
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 3)
                                                    .background(Color.black.opacity(0.04))
                                                    .clipShape(Capsule())

                                                    // Social Vibe - Real Reddit data
                                                    if let buzzData = viewModel.getSocialBuzz(for: holding.symbol) {
                                                        HStack(spacing: 3) {
                                                            Text(getSocialVibeEmoji(buzzData.buzzLevel.rawValue))
                                                                .font(.system(size: 10))
                                                            Text(buzzData.buzzLevel.rawValue)
                                                                .font(.system(size: 11, weight: .medium))
                                                                .foregroundColor(.secondary)
                                                        }
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 3)
                                                        .background(Color.black.opacity(0.04))
                                                        .clipShape(Capsule())
                                                    } else {
                                                        // Loading state
                                                        HStack(spacing: 3) {
                                                            Text("...")
                                                                .font(.system(size: 11, weight: .medium))
                                                                .foregroundColor(.secondary)
                                                        }
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 3)
                                                        .background(Color.black.opacity(0.04))
                                                        .clipShape(Capsule())
                                                    }
                                                }
                                            } else {
                                                // Loading or No Data
                                                HStack(spacing: 6) {
                                                    if viewModel.isLoadingStockData {
                                                        ProgressView()
                                                            .scaleEffect(0.7)
                                                        Text("Loading prices...")
                                                            .font(.system(size: 11))
                                                            .foregroundColor(.secondary)
                                                    } else {
                                                        Text("Tap refresh to load data")
                                                            .font(.system(size: 11))
                                                            .foregroundColor(.secondary)
                                                    }
                                                }
                                                .padding(.vertical, 3)
                                            }
                                        }

                                        Spacer()
                                    }
                                    .padding(.vertical, 8)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .onDelete(perform: deleteHoldings)
                        }
                    } header: {
                        HStack {
                            Text("Holdings")
                            Spacer()
                            if !viewModel.userSettings.holdings.isEmpty {
                                Button(action: {
                                    showAddHolding = true
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus.circle.fill")
                                        Text("Add")
                                    }
                                    .font(.system(size: 13))
                                    .foregroundColor(WealthyRabbitTheme.mistBlue)
                                }
                            }
                        }
                    } footer: {
                        if !viewModel.userSettings.holdings.isEmpty {
                            Text("\(viewModel.userSettings.holdings.count) total holdings · Swipe to delete")
                                .font(.system(size: 12))
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.7))
                }
                .listStyle(InsetGroupedListStyle())
                .scrollContentBackground(.hidden)
                .id(refreshID)
            }
            .navigationTitle("Portfolio")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await viewModel.refreshStockData()
                        }
                    }) {
                        if viewModel.isLoadingStockData {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(WealthyRabbitTheme.mistBlue)
                        }
                    }
                    .disabled(viewModel.isLoadingStockData)
                }
            }
            .onAppear {
                // Auto-refresh data when view appears
                if !viewModel.userSettings.holdings.isEmpty {
                    Task {
                        // Refresh stock data if not cached
                        if viewModel.stockQuotes.isEmpty {
                            await viewModel.refreshStockData()
                        }

                        // Refresh social data if not cached
                        if viewModel.socialBuzzData.isEmpty {
                            await viewModel.refreshSocialBuzz()
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddHolding, onDismiss: {
                // Force refresh when sheet is dismissed
                refreshID = UUID()
                // Refresh data for new holdings
                Task {
                    await viewModel.refreshStockData()
                    await viewModel.refreshSocialBuzz()
                }
            }) {
                AddHoldingSheet(
                    viewModel: viewModel,
                    isPresented: $showAddHolding,
                    editingHolding: $editingHolding,
                    symbolInput: $symbolInput,
                    nameInput: $nameInput,
                    allocationInput: $allocationInput,
                    noteInput: $noteInput
                )
            }
        }
    }

    func editHolding(_ holding: Holding) {
        editingHolding = holding
        symbolInput = holding.symbol
        nameInput = holding.name
        allocationInput = holding.allocation != nil ? String(Int(holding.allocation!)) : ""
        noteInput = holding.note ?? ""
        showAddHolding = true
    }

    func deleteHoldings(at offsets: IndexSet) {
        viewModel.userSettings.holdings.remove(atOffsets: offsets)
    }

    // Helper functions for real stock data
    func getPriceIcon(_ changePercent: Double) -> String {
        if changePercent > 0 {
            return "arrow.up.right"
        } else if changePercent < 0 {
            return "arrow.down.right"
        } else {
            return "minus"
        }
    }

    func getPriceColor(_ changePercent: Double) -> Color {
        if changePercent > 0 {
            return Color.green
        } else if changePercent < 0 {
            return Color.red
        } else {
            return Color.gray
        }
    }

    func formatPercent(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : ""
        return String(format: "\(sign)%.1f%%", value)
    }

    func getMarketFeelEmoji(_ feel: String) -> String {
        switch feel {
        case "Bullish": return "📈"
        case "Bearish": return "📉"
        case "Neutral": return "➡️"
        case "Steady": return "⚖️"
        default: return "📊"
        }
    }

    func getRandomSocialVibe() -> String {
        let vibes = ["Hot", "Quiet", "Rising", "Calm"]
        return vibes.randomElement() ?? "Quiet"
    }

    func getSocialVibeEmoji(_ vibe: String) -> String {
        switch vibe {
        case "Hot": return "🔥"
        case "Rising": return "📢"
        case "Quiet": return "😴"
        case "Calm": return "☮️"
        default: return "💬"
        }
    }
}

struct AddHoldingSheet: View {
    var viewModel: RabbitViewModel
    @Binding var isPresented: Bool
    @Binding var editingHolding: Holding?
    @Binding var symbolInput: String
    @Binding var nameInput: String
    @Binding var allocationInput: String
    @Binding var noteInput: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                WealthyRabbitTheme.burrowGradient
                    .ignoresSafeArea()

                Form {
                    Section(header: Text("Stock Information")) {
                        TextField("Symbol (e.g., AAPL)", text: $symbolInput)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()

                        TextField("Company Name", text: $nameInput)
                    }
                    .listRowBackground(Color.white.opacity(0.7))

                    Section(header: Text("Optional Details")) {
                        TextField("Allocation %", text: $allocationInput)
                            .keyboardType(.numberPad)

                        TextField("Note (e.g., core holding)", text: $noteInput)
                    }
                    .listRowBackground(Color.white.opacity(0.7))
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(editingHolding == nil ? "Add Holding" : "Edit Holding")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        clearForm()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(editingHolding == nil ? "Add" : "Save") {
                        saveHolding()
                    }
                    .disabled(symbolInput.isEmpty || nameInput.isEmpty)
                }
            }
        }
    }

    func saveHolding() {
        let allocation = Double(allocationInput)
        let note = noteInput.isEmpty ? nil : noteInput

        if let editing = editingHolding {
            // Update existing holding
            if let index = viewModel.userSettings.holdings.firstIndex(where: { $0.id == editing.id }) {
                var updatedHoldings = viewModel.userSettings.holdings
                updatedHoldings[index] = Holding(
                    id: editing.id,
                    symbol: symbolInput.uppercased(),
                    name: nameInput,
                    allocation: allocation,
                    note: note
                )
                viewModel.userSettings.holdings = updatedHoldings
                print("✅ Updated holding: \(symbolInput.uppercased())")
            }
        } else {
            // Add new holding - create new array to trigger @Published
            let newHolding = Holding(
                symbol: symbolInput.uppercased(),
                name: nameInput,
                allocation: allocation,
                note: note
            )
            var updatedHoldings = viewModel.userSettings.holdings
            updatedHoldings.append(newHolding)
            viewModel.userSettings.holdings = updatedHoldings
            print("✅ Added holding: \(newHolding.symbol) - Total holdings: \(viewModel.userSettings.holdings.count)")
        }

        clearForm()
        dismiss()
    }

    func clearForm() {
        editingHolding = nil
        symbolInput = ""
        nameInput = ""
        allocationInput = ""
        noteInput = ""
    }
}

#Preview {
    ReflectView(viewModel: RabbitViewModel(apiKey: Config.openAIAPIKey))
}
