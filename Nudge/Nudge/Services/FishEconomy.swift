//
//  FishEconomy.swift
//  Nudge
//
//  The Nudgy fish reward system — completing tasks earns you fish.
//  Different fish for different task sizes. Fish unlock wardrobe items
//  and fill your aquarium over the week.
//
//  Fish Types:
//  🐟 Catfish     — quick tasks (< 10 min or low energy)
//  🐠 Tropical    — medium tasks (10-25 min or medium energy)
//  🗡️ Swordfish   — big tasks (25+ min or high energy)
//  🐋 Whale       — milestone achievements (not from tasks)
//

import Foundation
import SwiftUI

// MARK: - Fish Species

/// The type of fish earned for completing a task.
enum FishSpecies: String, CaseIterable, Codable, Sendable {
    case catfish   = "catfish"
    case tropical  = "tropical"
    case swordfish = "swordfish"
    case whale     = "whale"
    
    var emoji: String {
        switch self {
        case .catfish:   return "🐟"
        case .tropical:  return "🐠"
        case .swordfish: return "🗡️"
        case .whale:     return "🐋"
        }
    }
    
    var label: String {
        switch self {
        case .catfish:   return String(localized: "Catfish")
        case .tropical:  return String(localized: "Tropical Fish")
        case .swordfish: return String(localized: "Swordfish")
        case .whale:     return String(localized: "Whale")
        }
    }
    
    var description: String {
        switch self {
        case .catfish:   return String(localized: "Quick task catch!")
        case .tropical:  return String(localized: "Nice sized catch!")
        case .swordfish: return String(localized: "A big one! Well earned!")
        case .whale:     return String(localized: "Legendary achievement!")
        }
    }
    
    /// Snowflake value of this fish.
    var snowflakeValue: Int {
        switch self {
        case .catfish:   return 1
        case .tropical:  return 3
        case .swordfish: return 5
        case .whale:     return 15
        }
    }
    
    /// Animation duration for the reward celebration.
    var celebrationDuration: Double {
        switch self {
        case .catfish:   return 1.2
        case .tropical:  return 1.8
        case .swordfish: return 2.5
        case .whale:     return 3.5
        }
    }
    
    /// Color name for the fish glow.
    var glowColorHex: String {
        switch self {
        case .catfish:   return "#64B5F6"   // Light blue
        case .tropical:  return "#FFB74D"   // Orange
        case .swordfish: return "#E040FB"   // Purple
        case .whale:     return "#FFD700"   // Gold
        }
    }

    // MARK: - Visual Rendering Properties (for FishView)

    /// Base size of the fish in the aquarium tank.
    var displaySize: CGFloat {
        switch self {
        case .catfish:   return 22
        case .tropical:  return 26
        case .swordfish: return 32
        case .whale:     return 42
        }
    }

    /// Primary body color for the vector FishView.
    var fishColor: Color {
        switch self {
        case .catfish:   return Color(hex: "4FC3F7")  // Ocean blue
        case .tropical:  return Color(hex: "FF8A65")  // Coral orange
        case .swordfish: return Color(hex: "BA68C8")  // Royal purple
        case .whale:     return Color(hex: "FFD54F")  // Golden
        }
    }

    /// Accent / shading color for dorsal fin, gill, and gradient.
    var fishAccentColor: Color {
        switch self {
        case .catfish:   return Color(hex: "0288D1")
        case .tropical:  return Color(hex: "E64A19")
        case .swordfish: return Color(hex: "7B1FA2")
        case .whale:     return Color(hex: "F57F17")
        }
    }

    /// Swim speed multiplier — larger fish are slower.
    var swimSpeed: Double {
        switch self {
        case .catfish:   return 3.5
        case .tropical:  return 4.0
        case .swordfish: return 5.0
        case .whale:     return 7.0
        }
    }
}

// MARK: - Fish Catch (a single earned fish)

/// Record of a single fish caught (earned by completing a task).
struct FishCatch: Codable, Identifiable, Sendable {
    let id: UUID
    let species: FishSpecies
    let taskContent: String
    let taskEmoji: String
    let caughtAt: Date
    let weekNumber: Int  // For weekly aquarium grouping
    
    init(species: FishSpecies, taskContent: String, taskEmoji: String) {
        self.id = UUID()
        self.species = species
        self.taskContent = taskContent
        self.taskEmoji = taskEmoji
        self.caughtAt = Date()
        self.weekNumber = Calendar.current.component(.weekOfYear, from: Date())
    }
}

// MARK: - Fish Economy

enum FishEconomy {
    
    /// Determine the fish species earned for completing a task.
    static func speciesForTask(_ item: NudgeItem) -> FishSpecies {
        // Priority-based
        if item.priority == .high { return .swordfish }
        
        // Duration-based
        if let minutes = item.estimatedMinutes ?? item.actualMinutes {
            if minutes >= 25 { return .swordfish }
            if minutes >= 10 { return .tropical }
            return .catfish
        }
        
        // Energy-based
        if let energy = item.energyLevel {
            switch energy {
            case .high:   return .swordfish
            case .medium: return .tropical
            case .low:    return .catfish
            }
        }
        
        // Content-based heuristics
        let lower = item.content.lowercased()
        let bigTaskWords = ["project", "presentation", "report", "clean", "organize", "build", "write", "prepare", "study"]
        let mediumTaskWords = ["email", "call", "text", "schedule", "book", "buy", "order", "research"]
        
        if bigTaskWords.contains(where: { lower.contains($0) }) { return .swordfish }
        if mediumTaskWords.contains(where: { lower.contains($0) }) { return .tropical }
        
        // Age-based: older tasks are harder (they've been avoided)
        if item.ageInDays >= 5 { return .swordfish }
        if item.ageInDays >= 3 { return .tropical }
        
        return .catfish
    }
    
    /// Calculate snowflakes earned for a fish catch (with streak multiplier).
    static func snowflakesForCatch(species: FishSpecies, streak: Int, isAllClear: Bool) -> Int {
        var base = species.snowflakeValue
        
        // Streak multiplier: 2x after 3+ days
        if streak >= 3 { base *= 2 }
        
        // All-clear bonus: +5
        if isAllClear { base += 5 }
        
        return base
    }
    
    // MARK: - Weekly Stats
    
    /// Get fish caught this week from stored catches.
    static func thisWeekCatches(from catches: [FishCatch]) -> [FishCatch] {
        let currentWeek = Calendar.current.component(.weekOfYear, from: Date())
        return catches.filter { $0.weekNumber == currentWeek }
    }
    
    /// Count fish by species for the current week.
    static func weeklySpeciesCount(from catches: [FishCatch]) -> [FishSpecies: Int] {
        let weekly = thisWeekCatches(from: catches)
        var counts: [FishSpecies: Int] = [:]
        for fish in weekly {
            counts[fish.species, default: 0] += 1
        }
        return counts
    }
    
    /// Weekly goal: catch at least this many fish to fill the aquarium.
    static func weeklyGoal(level: Int) -> Int {
        min(10 + (level * 2), 50)
    }
    
    /// Weekly progress as 0.0 – 1.0.
    static func weeklyProgress(catches: [FishCatch], level: Int) -> Double {
        let count = thisWeekCatches(from: catches).count
        let goal = weeklyGoal(level: level)
        return min(Double(count) / Double(goal), 1.0)
    }
}
