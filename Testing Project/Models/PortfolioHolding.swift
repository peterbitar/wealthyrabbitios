import Foundation

// MARK: - Portfolio Holding Model
// Represents a holding with quantity and price data for P/L calculation
struct PortfolioHolding: Identifiable {
    let id: UUID
    let ticker: String
    let name: String
    let quantity: Double
    let avgPrice: Double  // Average purchase price
    let currentPrice: Double  // Current market price
    
    // Computed property for unrealized P/L
    var unrealizedPL: Double {
        (currentPrice - avgPrice) * quantity
    }
    
    // Computed property for P/L percentage
    var plPercent: Double {
        guard avgPrice > 0 else { return 0 }
        return ((currentPrice - avgPrice) / avgPrice) * 100
    }
    
    init(id: UUID = UUID(), ticker: String, name: String, quantity: Double, avgPrice: Double, currentPrice: Double) {
        self.id = id
        self.ticker = ticker
        self.name = name
        self.quantity = quantity
        self.avgPrice = avgPrice
        self.currentPrice = currentPrice
    }
}

// MARK: - Dummy Portfolio Data
// Hard-coded realistic holdings for Portfolio screen
struct DummyPortfolioData {
    static let holdings: [PortfolioHolding] = [
        PortfolioHolding(
            ticker: "AAPL",
            name: "Apple Inc.",
            quantity: 25,
            avgPrice: 175.50,
            currentPrice: 182.30
        ),
        PortfolioHolding(
            ticker: "NVDA",
            name: "NVIDIA Corp.",
            quantity: 10,
            avgPrice: 485.20,
            currentPrice: 512.75
        ),
        PortfolioHolding(
            ticker: "TSLA",
            name: "Tesla Inc.",
            quantity: 15,
            avgPrice: 245.80,
            currentPrice: 238.40
        ),
        PortfolioHolding(
            ticker: "VOO",
            name: "Vanguard S&P 500 ETF",
            quantity: 50,
            avgPrice: 420.15,
            currentPrice: 428.90
        ),
        PortfolioHolding(
            ticker: "JNJ",
            name: "Johnson & Johnson",
            quantity: 20,
            avgPrice: 162.30,
            currentPrice: 165.80
        )
    ]
}

