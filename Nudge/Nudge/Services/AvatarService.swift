//
//  AvatarService.swift
//  Nudge
//
//  Fetches the user's avatar from their "me" contact card (Memoji/photo)
//  or loads a custom photo they've picked. Stores custom avatar in UserDefaults.
//

import SwiftUI
import Contacts

@MainActor @Observable
final class AvatarService {
    
    static let shared = AvatarService()
    private init() { loadCachedAvatar() }
    
    /// The resolved avatar image (either from Contacts "me" card or custom pick)
    var avatarImage: UIImage?
    
    /// Whether we've attempted to load from Contacts
    var hasAttemptedContactLoad = false
    
    /// The user's initials (fallback when no avatar)
    var initials: String = ""
    
    // MARK: - Load from "Me" Contact Card
    
    /// Attempts to fetch the user's own contact card thumbnail.
    /// This is where Apple stores the user's Memoji if they've set one.
    func loadFromMeCard() {
        guard !hasAttemptedContactLoad else { return }
        hasAttemptedContactLoad = true
        
        // Don't overwrite a custom avatar
        if avatarImage != nil { return }
        
        let store = CNContactStore()
        guard CNContactStore.authorizationStatus(for: .contacts) == .authorized else { return }
        
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactThumbnailImageDataKey as CNKeyDescriptor,
            CNContactImageDataKey as CNKeyDescriptor,
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
        ]
        
        // Try to find the "me" contact
        do {
            // Method 1: Check if there's a "me" identifier
            if let meIdentifier = try? store.unifiedMeContactIdentifier() {
                let meContact = try store.unifiedContact(withIdentifier: meIdentifier, keysToFetch: keysToFetch)
                if let imageData = meContact.thumbnailImageData ?? meContact.imageData,
                   let image = UIImage(data: imageData) {
                    self.avatarImage = image
                    return
                }
                // Extract initials from me card
                let first = meContact.givenName.prefix(1)
                let last = meContact.familyName.prefix(1)
                if !first.isEmpty || !last.isEmpty {
                    self.initials = "\(first)\(last)".uppercased()
                }
            }
        } catch {
            // "Me" card not set — that's fine
        }
    }
    
    // MARK: - Custom Avatar (User-Picked Photo)
    
    /// Save a custom avatar image (from PhotosPicker)
    func setCustomAvatar(_ image: UIImage) {
        avatarImage = image
        
        // Cache to UserDefaults as JPEG data
        if let data = image.jpegData(compressionQuality: 0.7) {
            UserDefaults.standard.set(data, forKey: "customAvatarData")
        }
    }
    
    /// Remove the custom avatar
    func removeAvatar() {
        avatarImage = nil
        UserDefaults.standard.removeObject(forKey: "customAvatarData")
        hasAttemptedContactLoad = false // Allow re-check from contacts
    }
    
    // MARK: - Cache
    
    private func loadCachedAvatar() {
        if let data = UserDefaults.standard.data(forKey: "customAvatarData"),
           let image = UIImage(data: data) {
            avatarImage = image
        }
    }
}

// MARK: - CNContactStore Extension

extension CNContactStore {
    /// Try to get the "me" contact identifier
    func unifiedMeContactIdentifier() throws -> String? {
        // Enumerate all containers to find "me" identifier
        let containers = try containers(matching: nil)
        for container in containers {
            if let meIdentifier = container.value(forKey: "meIdentifier") as? String,
               !meIdentifier.isEmpty {
                return meIdentifier
            }
        }
        return nil
    }
}
