import SwiftUI

struct HoldingsView: View {
    @ObservedObject var viewModel: RabbitViewModel
    @State private var showingAddHolding = false

    var userSettings: UserSettings {
        viewModel.userSettings
    }

    var body: some View {
        ZStack {
            WealthyRabbitTheme.burrowGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if userSettings.holdings.isEmpty {
                    // Empty state
                    VStack(spacing: WealthyRabbitTheme.relaxedSpacing) {
                        Text("🌱")
                            .font(.system(size: 64))

                        VStack(spacing: 8) {
                            Text("No holdings yet")
                                .font(WealthyRabbitTheme.headingFont)

                            Text("Add your investments so the Holdings Rabbit can watch them for you")
                                .font(WealthyRabbitTheme.bodyFont)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, WealthyRabbitTheme.airySpacing)
                        }

                        Button(action: {
                            showingAddHolding = true
                        }) {
                            Text("Add Your First Holding")
                                .font(WealthyRabbitTheme.bodyFont)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, WealthyRabbitTheme.relaxedSpacing)
                                .padding(.vertical, 12)
                                .background(WealthyRabbitTheme.mossGreen)
                                .cornerRadius(12)
                        }
                    }
                } else {
                    // Holdings list
                    List {
                        ForEach(userSettings.holdings) { holding in
                            HoldingRow(holding: holding)
                        }
                        .onDelete(perform: deleteHoldings)
                        .listRowBackground(Color.white.opacity(0.6))
                        .listRowSeparator(.hidden)
                    }
                    .listStyle(PlainListStyle())
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationTitle("Holdings & Accounts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if viewModel.isSyncing {
                    ProgressView()
                } else if !viewModel.isBackendAvailable {
                    Image(systemName: "cloud.slash")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingAddHolding = true
                }) {
                    Image(systemName: "plus")
                        .foregroundColor(WealthyRabbitTheme.mossGreen)
                }
            }
        }
        .sheet(isPresented: $showingAddHolding) {
            AddHoldingView(userSettings: userSettings)
        }
    }

    func deleteHoldings(at offsets: IndexSet) {
        userSettings.holdings.remove(atOffsets: offsets)
    }
}

struct HoldingRow: View {
    let holding: Holding

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(holding.symbol)
                        .font(WealthyRabbitTheme.headingFont)

                    Text(holding.name)
                        .font(WealthyRabbitTheme.captionFont)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if let allocation = holding.allocation {
                    Text("\(Int(allocation))%")
                        .font(WealthyRabbitTheme.bodyFont)
                        .fontWeight(.medium)
                        .foregroundColor(WealthyRabbitTheme.mistBlue)
                }
            }

            if let note = holding.note, !note.isEmpty {
                Text(note)
                    .font(WealthyRabbitTheme.captionFont)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding(.vertical, 8)
    }
}

struct AddHoldingView: View {
    @ObservedObject var userSettings: UserSettings
    @Environment(\.dismiss) var dismiss

    @State private var symbol = ""
    @State private var name = ""
    @State private var allocation = ""
    @State private var note = ""

    var body: some View {
        NavigationView {
            ZStack {
                WealthyRabbitTheme.burrowGradient
                    .ignoresSafeArea()

                Form {
                    Section(header: Text("Stock Details")) {
                        TextField("Symbol (e.g., AAPL)", text: $symbol)
                            .textInputAutocapitalization(.characters)

                        TextField("Company Name", text: $name)
                    }

                    Section(header: Text("Optional Details")) {
                        HStack {
                            TextField("Allocation %", text: $allocation)
                                .keyboardType(.decimalPad)
                            Text("%")
                                .foregroundColor(.secondary)
                        }

                        TextField("Note (e.g., 'core tech')", text: $note)
                    }

                    Section {
                        Button(action: addHolding) {
                            Text("Add Holding")
                                .frame(maxWidth: .infinity)
                                .foregroundColor(canSave ? WealthyRabbitTheme.mossGreen : .gray)
                        }
                        .disabled(!canSave)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Add Holding")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    var canSave: Bool {
        !symbol.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func addHolding() {
        let allocationValue = Double(allocation)

        let newHolding = Holding(
            symbol: symbol.uppercased().trimmingCharacters(in: .whitespacesAndNewlines),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            allocation: allocationValue,
            note: note.isEmpty ? nil : note
        )

        userSettings.holdings.append(newHolding)
        dismiss()
    }
}

#Preview {
    NavigationView {
        HoldingsView(viewModel: RabbitViewModel())
    }
}
