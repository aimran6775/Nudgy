//
//  URLActionGenerator.swift
//  Nudge
//
//  Generates smart URLs for task actions — Amazon search, Google search,
//  Maps directions, OpenTable reservations, YouTube tutorials, etc.
//  Nudgy constructs the exact URL so the user just taps and goes.
//

import Foundation

// MARK: - URL Action Result

/// A generated URL action with metadata for display.
struct URLAction: Sendable {
    let url: URL
    let label: String
    let icon: String
    let domain: String
    let openInApp: Bool   // true = SFSafariViewController, false = system open
    
    /// Convenience for display: "amazon.com", "maps.apple.com", etc.
    var displayDomain: String {
        domain.replacingOccurrences(of: "www.", with: "")
    }
}

// MARK: - URLActionGenerator

enum URLActionGenerator {
    
    // MARK: - Smart URL from Task Content
    
    /// Analyze task content and generate the best URL action(s).
    /// Returns empty array if no URL action is applicable.
    static func generateActions(for content: String, actionType: ActionType? = nil, actionTarget: String? = nil) -> [URLAction] {
        let lower = content.lowercased()
        var actions: [URLAction] = []
        
        // If there's already a URL target, use it directly
        if let target = actionTarget, let url = URL(string: target), url.scheme != nil {
            actions.append(URLAction(
                url: url,
                label: String(localized: "Open Link"),
                icon: "safari",
                domain: url.host ?? "link",
                openInApp: true
            ))
            return actions
        }
        
        // Shopping keywords → Amazon + Google Shopping
        if matchesAny(lower, keywords: ["buy", "order", "purchase", "shop", "get from", "pick up", "groceries", "amazon", "towels", "supplies"]) {
            let query = extractSearchQuery(from: content, removing: ["buy", "order", "purchase", "shop for", "get", "pick up", "from amazon", "on amazon", "from store", "need to"])
            
            if let amazonURL = buildAmazonSearchURL(query: query) {
                actions.append(URLAction(
                    url: amazonURL,
                    label: String(localized: "Search Amazon"),
                    icon: "cart.fill",
                    domain: "amazon.com",
                    openInApp: true
                ))
            }
            
            if let googleShoppingURL = buildGoogleSearchURL(query: query + " buy") {
                actions.append(URLAction(
                    url: googleShoppingURL,
                    label: String(localized: "Search Google"),
                    icon: "magnifyingglass",
                    domain: "google.com",
                    openInApp: true
                ))
            }
        }
        
        // Restaurant/food keywords → Yelp + Google Maps
        if matchesAny(lower, keywords: ["restaurant", "reservation", "book a table", "dinner", "lunch spot", "brunch", "eat at", "dine"]) {
            let query = extractSearchQuery(from: content, removing: ["book", "make a", "reservation", "at", "for", "tonight", "tomorrow", "this weekend"])
            
            if let yelpURL = buildYelpSearchURL(query: query) {
                actions.append(URLAction(
                    url: yelpURL,
                    label: String(localized: "Find on Yelp"),
                    icon: "fork.knife",
                    domain: "yelp.com",
                    openInApp: true
                ))
            }
            
            if let mapsURL = buildMapsSearchURL(query: query + " restaurant") {
                actions.append(URLAction(
                    url: mapsURL,
                    label: String(localized: "Search Maps"),
                    icon: "map.fill",
                    domain: "maps.apple.com",
                    openInApp: false
                ))
            }
        }
        
        // Directions/location keywords → Apple Maps
        if matchesAny(lower, keywords: ["directions", "navigate", "drive to", "go to", "get to", "how to get", "address", "location"]) {
            let destination = extractSearchQuery(from: content, removing: ["get directions to", "navigate to", "drive to", "go to", "get to", "directions to", "find"])
            
            if let mapsURL = buildMapsDirectionsURL(destination: destination) {
                actions.append(URLAction(
                    url: mapsURL,
                    label: String(localized: "Get Directions"),
                    icon: "location.fill",
                    domain: "maps.apple.com",
                    openInApp: false
                ))
            }
        }
        
        // Appointment/booking keywords → Google search
        if matchesAny(lower, keywords: ["appointment", "book", "schedule", "dentist", "doctor", "clinic", "salon", "barber", "vet"]) {
            let query = extractSearchQuery(from: content, removing: ["make", "schedule", "book", "an", "a", "appointment", "with", "at", "the"])
            
            if let searchURL = buildGoogleSearchURL(query: query + " near me book appointment") {
                actions.append(URLAction(
                    url: searchURL,
                    label: String(localized: "Search & Book"),
                    icon: "magnifyingglass",
                    domain: "google.com",
                    openInApp: true
                ))
            }
        }
        
        // Research/learn keywords → Google + YouTube
        if matchesAny(lower, keywords: ["research", "look up", "learn", "how to", "tutorial", "find out", "study", "read about", "article"]) {
            let query = extractSearchQuery(from: content, removing: ["research", "look up", "learn about", "how to", "find out about", "study", "read about"])
            
            if let googleURL = buildGoogleSearchURL(query: query) {
                actions.append(URLAction(
                    url: googleURL,
                    label: String(localized: "Google It"),
                    icon: "magnifyingglass",
                    domain: "google.com",
                    openInApp: true
                ))
            }
            
            if let youtubeURL = buildYouTubeSearchURL(query: query) {
                actions.append(URLAction(
                    url: youtubeURL,
                    label: String(localized: "Watch on YouTube"),
                    icon: "play.rectangle.fill",
                    domain: "youtube.com",
                    openInApp: true
                ))
            }
        }
        
        // Recipe/cooking keywords → Google recipes
        if matchesAny(lower, keywords: ["cook", "recipe", "make dinner", "bake", "meal", "what to cook"]) {
            let query = extractSearchQuery(from: content, removing: ["cook", "make", "bake", "prepare", "figure out", "find a", "recipe for"])
            
            if let recipeURL = buildGoogleSearchURL(query: query + " recipe") {
                actions.append(URLAction(
                    url: recipeURL,
                    label: String(localized: "Find Recipes"),
                    icon: "fork.knife",
                    domain: "google.com",
                    openInApp: true
                ))
            }
        }
        
        // Payment/bill keywords
        if matchesAny(lower, keywords: ["pay", "bill", "payment", "invoice", "rent", "utilities"]) {
            let query = extractSearchQuery(from: content, removing: ["pay", "the", "my", "bill", "for", "make a", "payment"])
            
            if let searchURL = buildGoogleSearchURL(query: query + " pay online login") {
                actions.append(URLAction(
                    url: searchURL,
                    label: String(localized: "Find Payment Portal"),
                    icon: "creditcard.fill",
                    domain: "google.com",
                    openInApp: true
                ))
            }
        }
        
        // Generic search fallback for .search action type
        if actions.isEmpty && actionType == .search {
            let query = extractSearchQuery(from: content, removing: ["search for", "search", "look up", "find"])
            if let searchURL = buildGoogleSearchURL(query: query) {
                actions.append(URLAction(
                    url: searchURL,
                    label: String(localized: "Search"),
                    icon: "magnifyingglass",
                    domain: "google.com",
                    openInApp: true
                ))
            }
        }
        
        // Generic navigate fallback
        if actions.isEmpty && actionType == .navigate {
            let destination = extractSearchQuery(from: content, removing: ["go to", "drive to", "navigate to", "directions to"])
            if let mapsURL = buildMapsDirectionsURL(destination: destination) {
                actions.append(URLAction(
                    url: mapsURL,
                    label: String(localized: "Get Directions"),
                    icon: "location.fill",
                    domain: "maps.apple.com",
                    openInApp: false
                ))
            }
        }
        
        return actions
    }
    
    // MARK: - URL Builders
    
    static func buildAmazonSearchURL(query: String) -> URL? {
        guard !query.isEmpty else { return nil }
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return URL(string: "https://www.amazon.com/s?k=\(encoded)")
    }
    
    static func buildGoogleSearchURL(query: String) -> URL? {
        guard !query.isEmpty else { return nil }
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return URL(string: "https://www.google.com/search?q=\(encoded)")
    }
    
    static func buildYouTubeSearchURL(query: String) -> URL? {
        guard !query.isEmpty else { return nil }
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return URL(string: "https://www.youtube.com/results?search_query=\(encoded)")
    }
    
    static func buildYelpSearchURL(query: String) -> URL? {
        guard !query.isEmpty else { return nil }
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return URL(string: "https://www.yelp.com/search?find_desc=\(encoded)")
    }
    
    static func buildMapsSearchURL(query: String) -> URL? {
        guard !query.isEmpty else { return nil }
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return URL(string: "https://maps.apple.com/?q=\(encoded)")
    }
    
    static func buildMapsDirectionsURL(destination: String) -> URL? {
        guard !destination.isEmpty else { return nil }
        let encoded = destination.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? destination
        return URL(string: "https://maps.apple.com/?daddr=\(encoded)&dirflg=d")
    }
    
    // MARK: - Helpers
    
    /// Check if text contains any of the keywords.
    private static func matchesAny(_ text: String, keywords: [String]) -> Bool {
        keywords.contains { text.contains($0) }
    }
    
    /// Extract a search query by removing action words from the content.
    private static func extractSearchQuery(from content: String, removing stopWords: [String]) -> String {
        var query = content.lowercased()
        
        for word in stopWords {
            query = query.replacingOccurrences(of: word, with: "")
        }
        
        // Clean up whitespace and trim
        query = query.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return query
    }
}
