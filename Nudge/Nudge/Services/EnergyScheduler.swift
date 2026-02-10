//
//  EnergyScheduler.swift
//  Nudge
//
//  Reorders the task queue based on time-of-day energy patterns.
//  Morning = high energy tasks, afternoon = medium, evening = low.
//
//  Uses EnergyLevel from NudgeItem and SmartPickEngine scoring.
//

import Foundation

@MainActor
enum EnergyScheduler {
    
    /// Re-sort a list of tasks by optimal energy matching for current time.
    /// Does NOT mutate sortOrder — returns a new ordering for display.
    static func optimizedOrder(_ items: [NudgeItem]) -> [NudgeItem] {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())
        let currentBucket = energyBucket(for: hour)
        
        // Partition: items with energy tags vs without
        let tagged = items.filter { $0.energyLevel != nil }
        let untagged = items.filter { $0.energyLevel == nil }
        
        // Sort tagged items: matching energy first, then by score
        let sorted = tagged.sorted { a, b in
            let aMatch = a.energyLevel == currentBucket
            let bMatch = b.energyLevel == currentBucket
            
            if aMatch != bMatch { return aMatch }
            
            // Then prefer items with closer scheduled times
            if let aTime = a.scheduledTime, let bTime = b.scheduledTime {
                return aTime < bTime
            }
            
            return a.sortOrder < b.sortOrder
        }
        
        // Interleave: matching energy first, then untagged, then non-matching
        let matching = sorted.filter { $0.energyLevel == currentBucket }
        let nonMatching = sorted.filter { $0.energyLevel != currentBucket }
        
        return matching + untagged + nonMatching
    }
    
    /// Suggest an energy level for a given hour
    static func energyBucket(for hour: Int) -> EnergyLevel {
        switch hour {
        case 6...11:  return .high     // Morning peak
        case 12...14: return .medium   // Post-lunch dip
        case 15...17: return .high     // Afternoon recovery
        case 18...20: return .medium   // Evening wind-down
        default:      return .low      // Night/early morning
        }
    }
    
    /// Get a user-friendly label for the current energy window
    static var currentWindowLabel: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6...11:  return String(localized: "Morning Peak 🌅")
        case 12...14: return String(localized: "Post-Lunch 🍽️")
        case 15...17: return String(localized: "Afternoon Focus 💪")
        case 18...20: return String(localized: "Evening Wind-Down 🌙")
        default:      return String(localized: "Rest Time 💤")
        }
    }
}
