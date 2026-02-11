//
//  IntentModelAccess.swift
//  Nudge
//
//  Provides ModelContainer access for App Intents.
//  App Intents may run out-of-process, so they need their own
//  ModelContainer built from the shared App Group store.
//
//  Uses the same per-user store pattern as NudgeApp.swift.
//

import SwiftData
import Foundation

/// Shared data access for App Intents — resolves the active user's store
/// from the App Group and builds a ModelContainer.
enum IntentModelAccess {
    
    /// The key used to persist the active user ID in the shared App Group defaults.
    private static let activeUserKey = "activeUserID"
    
    /// Build a ModelContainer for the currently signed-in user.
    /// Returns nil if no user is signed in or the store can't be opened.
    @MainActor
    static func makeContainer() -> ModelContainer? {
        guard let userID = resolveActiveUserID() else {
            return nil
        }
        
        let schema = Schema([
            NudgeItem.self,
            BrainDump.self,
            NudgyWardrobe.self,
            Routine.self,
            MoodEntry.self,
        ])
        
        let baseURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppGroupID.suiteName
        ) ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        let storeURL = baseURL.appendingPathComponent("nudge_\(userID).store")
        
        let configuration = ModelConfiguration(
            "nudge_intent_\(userID)",
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        
        return try? ModelContainer(for: schema, configurations: [configuration])
    }
    
    /// Resolve the active user ID from shared defaults.
    /// Falls back to "debug-test-user" for debug builds.
    private static func resolveActiveUserID() -> String? {
        let defaults = UserDefaults(suiteName: AppGroupID.suiteName)
        
        // Check for stored active user ID
        if let userID = defaults?.string(forKey: activeUserKey), !userID.isEmpty {
            return userID
        }
        
        // Check standard UserDefaults (AppSettings stores with user prefix)
        if let userID = UserDefaults.standard.string(forKey: activeUserKey), !userID.isEmpty {
            return userID
        }
        
        #if DEBUG
        // Debug fallback
        return "debug-test-user"
        #else
        return nil
        #endif
    }
    
    /// Save the active user ID to shared defaults (called from NudgeApp on sign-in).
    static func setActiveUserID(_ userID: String) {
        UserDefaults(suiteName: AppGroupID.suiteName)?.set(userID, forKey: activeUserKey)
        UserDefaults.standard.set(userID, forKey: activeUserKey)
    }
}
