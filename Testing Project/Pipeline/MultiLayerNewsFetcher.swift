import Foundation

// MARK: - Multi-Layer News Fetcher
// Implements the 3-layer input system with proper prioritization
class MultiLayerNewsFetcher {
    static let shared = MultiLayerNewsFetcher()
    
    private let rssService = RSSFeedService.shared
    private let newsAPIService = NewsService.shared
    private let newsDataIOService = NewsDataIOService.shared
    
    private init() {}
    
    // Fetch from all layers with holdings-first priority
    // Step 1: Search for holdings news first
    // Step 2: Scrape top stories
    func fetchAllLayers(holdings: [Holding] = [], limit: Int = 100) async throws -> [RawArticle] {
        print("🌐 Starting multi-layer news fetch (holdings-first)...")
        var allArticles: [RawArticle] = []
        var seenURLs: Set<String> = []
        
        // STEP 1: Search for holdings news first
        if !holdings.isEmpty {
            print("📊 Step 1: Searching for holdings news...")
            let holdingsArticles = try await fetchHoldingsNews(holdings: holdings)
            for article in holdingsArticles {
                let normalizedURL = article.url.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                if !seenURLs.contains(normalizedURL) {
                    seenURLs.insert(normalizedURL)
                    allArticles.append(article)
                }
            }
            print("✅ Step 1: Fetched \(holdingsArticles.count) articles about holdings")
        }
        
        // STEP 2: Scrape top stories
        print("📰 Step 2: Fetching top stories...")
        
        // Layer 1: Wire Feeds (High-value mandatory)
        print("📡 Layer 1: Fetching wire feeds...")
        let wireFeeds = try await fetchWireFeeds(limit: limit)
        for article in wireFeeds {
            let normalizedURL = article.url.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if !seenURLs.contains(normalizedURL) {
                seenURLs.insert(normalizedURL)
                allArticles.append(article)
            }
        }
        print("✅ Layer 1: Fetched \(wireFeeds.count) articles from wire feeds")
        
        // Layer 2: Financial Aggregators
        print("📰 Layer 2: Fetching financial aggregators...")
        let financialFeeds = try await fetchFinancialAggregators(limit: limit)
        for article in financialFeeds {
            let normalizedURL = article.url.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if !seenURLs.contains(normalizedURL) {
                seenURLs.insert(normalizedURL)
                allArticles.append(article)
            }
        }
        print("✅ Layer 2: Fetched \(financialFeeds.count) articles from financial aggregators")
        
        // Layer 3: Supplemental (only if we need more)
        if allArticles.count < limit {
            print("📦 Layer 3: Fetching supplemental sources (fallback)...")
            let supplemental = try await fetchSupplementalSources(limit: limit - allArticles.count)
            for article in supplemental {
                let normalizedURL = article.url.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                if !seenURLs.contains(normalizedURL) {
                    seenURLs.insert(normalizedURL)
                    allArticles.append(article)
                }
            }
            print("✅ Layer 3: Fetched \(supplemental.count) articles from supplemental sources")
        }
        
        print("✅ Total fetched: \(allArticles.count) unique raw articles (holdings-first priority)")
        return allArticles
    }
    
    // Fetch news specifically about user's holdings
    // ZERO-WASTE: Hard filters to drop time-wasters and opinion pieces
    private func fetchHoldingsNews(holdings: [Holding]) async throws -> [RawArticle] {
        var allArticles: [RawArticle] = []
        let tickers = holdings.map { $0.symbol.uppercased() }
        
        print("🔍 Searching for news about \(tickers.count) holdings: \(tickers.joined(separator: ", "))")
        
        // Hard NO filters for time-wasters
        let timeWasterPatterns = [
            "3 stocks", "5 stocks", "top picks", "should you buy", "dividend kings",
            "options traders", "price target raised", "price target lowered",
            "upgrade", "downgrade", "zacks rank", "the motley fool recommends",
            "analyst says", "analyst recommends", "analyst upgrades", "analyst downgrades"
        ]
        
        // Event keywords that indicate real news
        let eventKeywords = [
            "earnings", "guidance", "launch", "announces", "acquires", "merger",
            "lawsuit", "regulation", "reports", "record high", "record low",
            "all-time high", "all-time low", "beats", "misses", "forecast"
        ]
        
        // Fetch news for each holding in parallel
        await withTaskGroup(of: [RawArticle].self) { group in
            for ticker in tickers {
                group.addTask {
                    do {
                        // Search NewsAPI for this ticker (reduced to 10 per ticker)
                        let newsArticles = try await self.newsAPIService.fetchNewsForTicker(ticker, limit: 10)
                        print("✅ Found \(newsArticles.count) articles for \(ticker)")
                        
                        // Apply hard filters
                        let filteredArticles = newsArticles.filter { article in
                            let titleLower = article.title.lowercased()
                            
                            // Drop time-wasters
                            if timeWasterPatterns.contains(where: { titleLower.contains($0) }) {
                                print("   🚫 DROPPED (time-waster): \(article.title.prefix(60))...")
                                return false
                            }
                            
                            // Drop opinion-only pieces with no clear event
                            let hasEventKeyword = eventKeywords.contains(where: { titleLower.contains($0) })
                            let hasTicker = titleLower.contains(ticker.lowercased())
                            
                            if !hasEventKeyword && !hasTicker {
                                print("   🚫 DROPPED (no clear event): \(article.title.prefix(60))...")
                                return false
                            }
                            
                            return true
                        }
                        
                        print("   ✅ Kept \(filteredArticles.count)/\(newsArticles.count) articles for \(ticker)")
                        
                        return filteredArticles.map { article in
                            RawArticle(
                                source: "NewsAPI (Holdings Search)",
                                sourceLayer: 1, // High priority for holdings
                                title: article.title,
                                description: article.description,
                                publishedAt: article.publishedAt,
                                url: article.url,
                                tickersExtractedRaw: [ticker],
                                isHoldingsNews: true,
                                sourceTag: "HoldingsSearch"
                            )
                        }
                    } catch {
                        print("⚠️ Failed to fetch news for \(ticker): \(error.localizedDescription)")
                        return []
                    }
                }
            }
            
            for await articles in group {
                allArticles.append(contentsOf: articles)
            }
        }
        
        print("✅ Holdings search: \(allArticles.count) articles passed hard filters")
        return allArticles
    }
    
    // MARK: - Hard Filters for Top Stories (Zero-Waste)
    nonisolated private func applyHardFiltersToTopStories(_ articles: [RawArticle]) -> [RawArticle] {
        let genericPatterns = [
            "what to know before the bell",
            "stocks to buy now",
            "why", " is a buy", " is a sell", " is a hold",
            "should you buy", "should you sell"
        ]
        
        let macroKeywords = ["fed", "inflation", "gdp", "unemployment", "interest rate", "policy"]
        let regulationKeywords = ["regulation", "sec", "fda", "approval", "ban", "fine"]
        
        return articles.filter { article in
            let titleLower = article.title.lowercased()
            let descriptionLower = (article.description ?? "").lowercased()
            let combinedText = titleLower + " " + descriptionLower
            
            // Drop generic patterns
            if genericPatterns.contains(where: { titleLower.contains($0) }) {
                print("   🚫 DROPPED (generic pattern): \(article.title.prefix(60))...")
                return false
            }
            
            // Check age (drop if older than 48 hours, unless macro/regulation)
            if let publishedDate = ISO8601DateFormatter().date(from: article.publishedAt) {
                let hoursAgo = Date().timeIntervalSince(publishedDate) / 3600
                let hasMacroKeyword = macroKeywords.contains(where: { combinedText.contains($0) })
                let hasRegulationKeyword = regulationKeywords.contains(where: { combinedText.contains($0) })
                
                if hoursAgo > 48 && !hasMacroKeyword && !hasRegulationKeyword {
                    print("   🚫 DROPPED (too old, \(Int(hoursAgo))h): \(article.title.prefix(60))...")
                    return false
                }
            }
            
            // Drop if no clear ticker and no macro/regulation keyword
            let hasTicker = !(article.tickersExtractedRaw?.isEmpty ?? true)
            let hasMacroKeyword = macroKeywords.contains(where: { combinedText.contains($0) })
            let hasRegulationKeyword = regulationKeywords.contains(where: { combinedText.contains($0) })
            
            if !hasTicker && !hasMacroKeyword && !hasRegulationKeyword {
                print("   🚫 DROPPED (no ticker, no macro/regulation): \(article.title.prefix(60))...")
                return false
            }
            
            return true
        }
    }
    
    // MARK: - Layer 1: Wire Feeds
    private func fetchWireFeeds(limit: Int) async throws -> [RawArticle] {
        var articles: [RawArticle] = []
        
        // Fetch all wire feeds in parallel
        // Note: Errors are caught per-feed so one failure doesn't stop others
        await withTaskGroup(of: [RawArticle].self) { group in
            for feedSource in WireFeedSource.allCases {
                group.addTask {
                    do {
                        let items = try await self.rssService.fetchRSSFeed(
                            url: feedSource.rssURL,
                            source: feedSource.rawValue
                        )
                        if !items.isEmpty {
                            print("✅ Successfully fetched \(items.count) items from \(feedSource.rawValue)")
                        }
                        let rawArticles = items.map { item in
                            RawArticle(
                                source: feedSource.rawValue,
                                sourceLayer: 1,
                                title: item.title,
                                description: item.description,
                                publishedAt: item.pubDate?.ISO8601Format() ?? Date().ISO8601Format(),
                                url: item.link,
                                tickersExtractedRaw: self.extractTickers(from: item.title + " " + (item.description ?? "")),
                                isHoldingsNews: false
                            )
                        }
                        return self.applyHardFiltersToTopStories(rawArticles)
                    } catch {
                        // Log error but don't fail entire fetch - other feeds may succeed
                        print("⚠️ Failed to fetch \(feedSource.rawValue): \(error.localizedDescription)")
                        print("   URL: \(feedSource.rssURL)")
                        return []
                    }
                }
            }
            
            for await feedArticles in group {
                articles.append(contentsOf: feedArticles)
            }
        }
        
        print("📡 Wire feeds: \(articles.count) articles passed hard filters")
        return Array(articles.prefix(limit))
    }
    
    // MARK: - Layer 2: Financial Aggregators
    private func fetchFinancialAggregators(limit: Int) async throws -> [RawArticle] {
        var articles: [RawArticle] = []
        
        await withTaskGroup(of: [RawArticle].self) { group in
            for aggregator in FinancialAggregatorSource.allCases {
                group.addTask {
                    do {
                        let items = try await self.rssService.fetchRSSFeed(
                            url: aggregator.rssURL,
                            source: aggregator.rawValue
                        )
                        let rawArticles = items.map { item in
                            RawArticle(
                                source: aggregator.rawValue,
                                sourceLayer: 2,
                                title: item.title,
                                description: item.description,
                                publishedAt: item.pubDate?.ISO8601Format() ?? Date().ISO8601Format(),
                                url: item.link,
                                tickersExtractedRaw: self.extractTickers(from: item.title + " " + (item.description ?? "")),
                                isHoldingsNews: false
                            )
                        }
                        return self.applyHardFiltersToTopStories(rawArticles)
                    } catch {
                        print("⚠️ Failed to fetch \(aggregator.rawValue): \(error.localizedDescription)")
                        return []
                    }
                }
            }
            
            for await feedArticles in group {
                articles.append(contentsOf: feedArticles)
            }
        }
        
        print("📰 Financial aggregators: \(articles.count) articles passed hard filters")
        return Array(articles.prefix(limit))
    }
    
    // MARK: - Layer 3: Supplemental (Fallback only)
    private func fetchSupplementalSources(limit: Int) async throws -> [RawArticle] {
        var articles: [RawArticle] = []
        
        // NewsAPI (fallback)
        do {
            let newsAPIArticles = try await newsAPIService.fetchFinancialNews(limit: limit / 2)
            let rawArticles = newsAPIArticles.map { article in
                RawArticle(
                    source: SupplementalSource.newsAPI.rawValue,
                    sourceLayer: 3,
                    title: article.title,
                    description: article.description,
                    publishedAt: article.publishedAt,
                    url: article.url,
                    tickersExtractedRaw: self.extractTickers(from: article.title + " " + (article.description ?? "")),
                    isHoldingsNews: false
                )
            }
            articles.append(contentsOf: applyHardFiltersToTopStories(rawArticles))
        } catch {
            print("⚠️ NewsAPI fallback failed: \(error.localizedDescription)")
        }
        
        // NewsData.io (fallback, if API key available)
        if !Config.newsDataIOAPIKey.isEmpty {
            do {
                let newsDataArticles = try await newsDataIOService.fetchFinancialNews(limit: limit / 2)
                let rawArticles = newsDataArticles.map { article in
                    RawArticle(
                        source: SupplementalSource.newsDataIO.rawValue,
                        sourceLayer: 3,
                        title: article.title,
                        description: article.description,
                        publishedAt: article.publishedAt,
                        url: article.url,
                        tickersExtractedRaw: self.extractTickers(from: article.title + " " + (article.description ?? "")),
                        isHoldingsNews: false
                    )
                }
                articles.append(contentsOf: applyHardFiltersToTopStories(rawArticles))
            } catch {
                print("⚠️ NewsData.io fallback failed: \(error.localizedDescription)")
            }
        }
        
        print("📦 Supplemental sources: \(articles.count) articles passed hard filters")
        return Array(articles.prefix(limit))
    }
    
    // MARK: - Helper: Extract Tickers (Initial Pass)
    nonisolated private func extractTickers(from text: String) -> [String] {
        // Basic regex-based ticker extraction (will be improved with ML later)
        let tickerPattern = "\\b([A-Z]{1,5})\\b"
        let regex = try? NSRegularExpression(pattern: tickerPattern, options: [])
        let nsString = text as NSString
        let results = regex?.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
        
        var tickers: Set<String> = []
        if let results = results {
            for match in results {
                if match.range.length > 0 {
                    let ticker = nsString.substring(with: match.range)
                    // Filter out common words that match ticker pattern
                    let commonWords = ["THE", "AND", "FOR", "ARE", "BUT", "NOT", "YOU", "ALL", "CAN", "HER", "WAS", "ONE", "OUR", "OUT", "DAY", "GET", "HAS", "HIM", "HIS", "HOW", "ITS", "MAY", "NEW", "NOW", "OLD", "SEE", "TWO", "WHO", "WAY", "USE", "MAN", "YEAR", "SAY", "SHE", "HER", "PUT", "END", "WHY", "ASK", "MEN", "TURN", "WANT", "AIR", "ALSO", "PLAY", "SMALL", "END", "PUT", "HOME", "READ", "HAND", "PORT", "LARGE", "SPELL", "ADD", "EVEN", "LAND", "HERE", "MUST", "BIG", "HIGH", "SUCH", "FOLLOW", "ACT", "WHY", "ASK", "MEN", "CHANGE", "WENT", "LIGHT", "KIND", "OFF", "NEED", "HOUSE", "PICTURE", "TRY", "US", "AGAIN", "ANIMAL", "POINT", "MOTHER", "WORLD", "NEAR", "BUILD", "SELF", "EARTH", "FATHER", "HEAD", "STAND", "OWN", "PAGE", "SHOULD", "COUNTRY", "FOUND", "ANSWER", "SCHOOL", "GROW", "STUDY", "STILL", "LEARN", "PLANT", "COVER", "FOOD", "SUN", "FOUR", "BETWEEN", "STATE", "KEEP", "EYE", "NEVER", "LAST", "LET", "THOUGHT", "CITY", "TREE", "CROSS", "FARM", "HARD", "START", "MIGHT", "STORY", "SAW", "FAR", "SEA", "DRAW", "LEFT", "LATE", "RUN", "DON'T", "WHILE", "PRESS", "CLOSE", "NIGHT", "REAL", "LIFE", "FEW", "NORTH", "OPEN", "SEEM", "TOGETHER", "NEXT", "WHITE", "CHILDREN", "BEGIN", "GOT", "WALK", "EXAMPLE", "EASE", "PAPER", "GROUP", "ALWAYS", "MUSIC", "THOSE", "BOTH", "MARK", "OFTEN", "LETTER", "UNTIL", "MILE", "RIVER", "CAR", "FEET", "CARE", "SECOND", "BOOK", "CARRY", "TOOK", "SCIENCE", "EAT", "ROOM", "FRIEND", "BEGAN", "IDEA", "FISH", "MOUNTAIN", "STOP", "ONCE", "BASE", "HEAR", "HORSE", "CUT", "SURE", "WATCH", "COLOR", "FACE", "WOOD", "MAIN", "ENOUGH", "PLAIN", "GIRL", "USUAL", "YOUNG", "READY", "ABOVE", "EVER", "RED", "LIST", "THOUGH", "FEEL", "TALK", "BIRD", "SOON", "BODY", "DOG", "FAMILY", "DIRECT", "LEAVE", "SONG", "MEASURE", "DOOR", "PRODUCT", "BLACK", "SHORT", "NUMERAL", "CLASS", "WIND", "QUESTION", "HAPPEN", "COMPLETE", "SHIP", "AREA", "HALF", "ROCK", "ORDER", "FIRE", "SOUTH", "PROBLEM", "PIECE", "TOLD", "KNEW", "PASS", "SINCE", "TOP", "WHOLE", "KING", "SPACE", "HEARD", "BEST", "HOUR", "BETTER", "TRUE", "DURING", "HUNDRED", "FIVE", "REMEMBER", "STEP", "EARLY", "HOLD", "WEST", "GROUND", "INTEREST", "REACH", "FAST", "VERB", "SING", "LISTEN", "SIX", "TABLE", "TRAVEL", "LESS", "MORNING", "TEN", "SIMPLE", "SEVERAL", "VOWEL", "TOWARD", "WAR", "LAY", "AGAINST", "PATTERN", "SLOW", "CENTER", "LOVE", "PERSON", "MONEY", "SERVE", "APPEAR", "ROAD", "MAP", "RAIN", "RULE", "GOVERN", "PULL", "COLD", "NOTICE", "VOICE", "UNIT", "POWER", "TOWN", "FINE", "CERTAIN", "FLY", "FALL", "LEAD", "CRY", "DARK", "MACHINE", "NOTE", "WAIT", "PLAN", "FIGURE", "STAR", "BOX", "NOUN", "FIELD", "REST", "CORRECT", "ABLE", "POUND", "DONE", "BEAUTY", "DRIVE", "STOOD", "CONTAIN", "FRONT", "TEACH", "WEEK", "FINAL", "GAVE", "GREEN", "OH", "QUICK", "DEVELOP", "OCEAN", "WARM", "FREE", "MINUTE", "STRONG", "SPECIAL", "MIND", "BEHIND", "CLEAR", "TAIL", "PRODUCE", "FACT", "STREET", "INCH", "MULTIPLY", "NOTHING", "COURSE", "STAY", "WHEEL", "FULL", "FORCE", "BLUE", "OBJECT", "DECIDE", "SURFACE", "DEEP", "MOON", "ISLAND", "FOOT", "SYSTEM", "BUSY", "TEST", "RECORD", "BOAT", "COMMON", "GOLD", "POSSIBLE", "PLANE", "STEAD", "DRY", "WONDER", "LAUGH", "THOUSAND", "AGO", "RAN", "CHECK", "GAME", "SHAPE", "EQUATE", "MISS", "BROUGHT", "HEAT", "SNOW", "TIRE", "BRING", "YES", "DISTANT", "FILL", "EAST", "PAINT", "LANGUAGE", "AMONG", "GRAND", "BALL", "YET", "WAVE", "DROP", "HEART", "PRESENT", "HEAVY", "DANCE", "ENGINE", "POSITION", "ARM", "WIDE", "SAIL", "MATERIAL", "SIZE", "VARY", "SETTLE", "SPEAK", "WEIGHT", "GENERAL", "ICE", "MATTER", "CIRCLE", "PAIR", "INCLUDE", "DIVIDE", "SYLLABLE", "FELT", "PERHAPS", "PICK", "SUDDEN", "COUNT", "SQUARE", "REASON", "LENGTH", "REPRESENT", "ART", "SUBJECT", "REGION", "ENERGY", "HUNT", "PROBABLE", "BED", "BROTHER", "EGG", "RIDE", "CELL", "BELIEVE", "FRACTION", "FOREST", "SIT", "RACE", "WINDOW", "STORE", "SUMMER", "TRAIN", "SLEEP", "PROVE", "LONE", "LEG", "EXERCISE", "WALL", "CATCH", "MOUNT", "WISH", "SKY", "BOARD", "JOY", "WINTER", "SAT", "WRITTEN", "WILD", "INSTRUMENT", "KEPT", "GLASS", "GRASS", "COW", "JOB", "EDGE", "SIGN", "VISIT", "PAST", "SOFT", "FUN", "BRIGHT", "GAS", "WEATHER", "MONTH", "MILLION", "BEAR", "FINISH", "HAPPY", "HOPE", "FLOWER", "CLOTHE", "STRANGE", "GONE", "JUMP", "BABY", "EIGHT", "VILLAGE", "MEET", "ROOT", "BUY", "RAISE", "SOLVE", "METAL", "WHETHER", "PUSH", "SEVEN", "PARAGRAPH", "THIRD", "SHALL", "HELD", "HAIR", "DESCRIBE", "COOK", "FLOOR", "EITHER", "RESULT", "BURN", "HILL", "SAFE", "CAT", "CENTURY", "CONSIDER", "TYPE", "LAW", "BIT", "COAST", "COPY", "PHRASE", "SILENT", "TALL", "SAND", "SOIL", "ROLL", "TEMPERATURE", "FINGER", "INDUSTRY", "VALUE", "FIGHT", "LIE", "BEAT", "EXCITE", "NATURAL", "VIEW", "SENSE", "EAR", "ELSE", "QUITE", "BROKE", "CASE", "MIDDLE", "KILL", "SON", "LAKE", "MOMENT", "SCALE", "LOUD", "SPRING", "OBSERVE", "CHILD", "STRAIGHT", "CONSONANT", "NATION", "DICTIONARY", "MILK", "SPEED", "METHOD", "ORGAN", "PAY", "AGE", "SECTION", "DRESS", "CLOUD", "SURPRISE", "QUIET", "STONE", "TINY", "CLIMB", "COOL", "DESIGN", "POOR", "LOT", "EXPERIMENT", "BOTTOM", "KEY", "IRON", "SINGLE", "STICK", "FLAT", "TWENTY", "SKIN", "SMILE", "CREASE", "HOLE", "TRADE", "MELODY", "TRIP", "OFFICE", "RECEIVE", "ROW", "MOUTH", "EXACT", "SYMBOL", "DIE", "LEAST", "TROUBLE", "SHOUT", "EXCEPT", "WROTE", "SEED", "TONE", "JOIN", "SUGGEST", "CLEAN", "BREAK", "LADY", "YARD", "RISE", "BAD", "BLOW", "OIL", "BLOOD", "TOUCH", "GREW", "CENT", "MIX", "TEAM", "WIRE", "COST", "LOST", "BROWN", "WEAR", "GARDEN", "EQUAL", "SENT", "CHOOSE", "FELL", "FIT", "FLOW", "FAIR", "BANK", "COLLECT", "SAVE", "CONTROL", "DECIMAL", "GENTLE", "WOMAN", "CAPTAIN", "PRACTICE", "SEPARATE", "DIFFICULT", "DOCTOR", "PLEASE", "PROTECT", "NOON", "CROP", "MODERN", "ELEMENT", "HIT", "STUDENT", "CORNER", "PARTY", "SUPPLY", "WHOSE", "LOCATE", "RING", "CHARACTER", "INSECT", "CAUGHT", "PERIOD", "INDICATE", "RADIO", "SPOKE", "ATOM", "HUMAN", "HISTORY", "EFFECT", "ELECTRIC", "EXPECT", "BONE", "RAIL", "IMAGINE", "PROVIDE", "AGREE", "THUS", "CAPITAL", "WON'T", "CHAIR", "DANGER", "FRUIT", "RICH", "THICK", "SOLDIER", "PROCESS", "OPERATE", "GUESS", "NECESSARY", "SHARP", "WING", "CREATE", "NEIGHBOR", "WASH", "BAT", "RATHER", "CROWD", "CORN", "COMPARE", "POEM", "STRING", "BELL", "DEPEND", "MEAT", "RUB", "TUBE", "FAMOUS", "DOLLAR", "STREAM", "FEAR", "SIGHT", "THIN", "TRIANGLE", "PLANET", "HURRY", "CHIEF", "COLONY", "CLOCK", "MINE", "TIE", "ENTER", "MAJOR", "FRESH", "SEARCH", "SEND", "YELLOW", "GUN", "ALLOW", "PRINT", "DEAD", "SPOT", "DESERT", "SUIT", "CURRENT", "LIFT", "ROSE", "CONTINUE", "BLOCK", "CHART", "HAT", "SELL", "SUCCESS", "COMPANY", "SUBTRACT", "EVENT", "PARTICULAR", "DEAL", "SWIM", "TERM", "OPPOSITE", "WIFE", "SHOE", "SHOULDER", "SPREAD", "ARRANGE", "CAMP", "INVENT", "COTTON", "BORN", "DETERMINE", "QUART", "NINE", "TRUCK", "NOISE", "LEVEL", "CHANCE", "GATHER", "SHOP", "STRETCH", "THROW", "SHINE", "PROPERTY", "COLUMN", "MOLECULE", "SELECT", "WRONG", "GRAY", "REPEAT", "REQUIRE", "BROAD", "PREPARE", "SALT", "NOSE", "PLURAL", "ANGER", "CLAIM", "CONTINENT", "OXYGEN", "SUGAR", "DEATH", "PRETTY", "SKILL", "WOMEN", "SEASON", "SOLUTION", "MAGNET", "SILVER", "THANK", "BRANCH", "MATCH", "SUFFIX", "ESPECIALLY", "FIG", "AFRAID", "HUGE", "SISTER", "STEEL", "DISCUSS", "FORWARD", "SIMILAR", "GUIDE", "EXPERIENCE", "SCORE", "APPLE", "BOUGHT", "LED", "PITCH", "COAT", "MASS", "CARD", "BAND", "ROPE", "SLIP", "WIN", "DREAM", "EVENING", "CONDITION", "FEED", "TOOL", "TOTAL", "BASIC", "SMELL", "VALLEY", "NOR", "DOUBLE", "SEAT", "ARRIVE", "MASTER", "TRACK", "PARENT", "SHORE", "DIVISION", "SHEET", "SUBSTANCE", "FAVOR", "CONNECT", "POST", "SPEND", "CHORD", "FAT", "GLAD", "ORIGINAL", "SHARE", "STATION", "DAD", "BREAD", "CHARGE", "PROPER", "BAR", "OFFER", "SEGMENT", "SLAVE", "DUCK", "INSTANT", "MARKET", "DEGREE", "POPULATE", "CHICK", "DEAR", "ENEMY", "REPLY", "DRINK", "OCCUR", "SUPPORT", "SPEECH", "NATURE", "RANGE", "STEAM", "MOTION", "PATH", "LIQUID", "LOG", "MEANT", "QUOTIENT", "TEETH", "SHELL", "NECK"]
                    if !commonWords.contains(ticker) && ticker.count >= 1 && ticker.count <= 5 {
                        tickers.insert(ticker)
                    }
                }
            }
        }
        
        return Array(tickers)
    }
}


