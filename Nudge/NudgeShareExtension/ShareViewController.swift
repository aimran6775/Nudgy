//
//  ShareViewController.swift
//  NudgeShareExtension
//
//  Share Extension target — accepts URLs, text, and images from any app.
//  Writes JSON payload to App Group UserDefaults for main app ingestion.
//  Memory budget: <80MB. Uses loadFileRepresentation for images.
//

import UIKit
import SwiftUI
import UniformTypeIdentifiers
import LinkPresentation

/// Share Extension entry point.
/// Extracts shared content → shows snooze picker → saves via App Group.
class ShareViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Extract shared content from extension context
        Task {
            let content = await extractContent()
            showShareUI(content: content)
        }
    }
    
    // MARK: - Content Extraction
    
    private func extractContent() async -> SharedContent {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            return SharedContent(text: "", url: nil, preview: nil)
        }
        
        var text = ""
        var urlString: String?
        var preview: String?
        
        for item in extensionItems {
            guard let attachments = item.attachments else { continue }
            
            for attachment in attachments {
                // URL
                if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    if let url = try? await attachment.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL {
                        urlString = url.absoluteString
                        text = url.absoluteString
                        
                        // Try to get metadata (title)
                        if let metadata = try? await fetchMetadata(for: url) {
                            preview = metadata
                            if !metadata.isEmpty { text = metadata }
                        }
                    }
                }
                // Plain text
                else if attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    if let sharedText = try? await attachment.loadItem(forTypeIdentifier: UTType.plainText.identifier) as? String {
                        text = sharedText
                    }
                }
            }
        }
        
        return SharedContent(text: text, url: urlString, preview: preview)
    }
    
    private func fetchMetadata(for url: URL) async throws -> String? {
        let provider = LPMetadataProvider()
        provider.timeout = 3
        let metadata = try await provider.startFetchingMetadata(for: url)
        return metadata.title
    }
    
    // MARK: - UI
    
    private func showShareUI(content: SharedContent) {
        let shareView = ShareExtensionView(
            content: content,
            onSave: { [weak self] snoozedUntil in
                self?.saveAndDismiss(content: content, snoozedUntil: snoozedUntil)
            },
            onCancel: { [weak self] in
                self?.cancel()
            }
        )
        
        let hostingController = UIHostingController(rootView: shareView)
        hostingController.view.backgroundColor = .clear
        
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        hostingController.didMove(toParent: self)
    }
    
    // MARK: - Save
    
    private func saveAndDismiss(content: SharedContent, snoozedUntil: Date) {
        guard let defaults = UserDefaults(suiteName: "group.com.nudge.app") else {
            cancel()
            return
        }
        
        // Read existing pending items
        var pendingItems: [[String: Any]] = []
        if let existingData = defaults.data(forKey: "pendingShareItems"),
           let existing = try? JSONSerialization.jsonObject(with: existingData) as? [[String: Any]] {
            pendingItems = existing
        }
        
        // Add new item
        let payload: [String: Any] = [
            "content": content.text,
            "url": content.url as Any,
            "preview": content.preview as Any,
            "snoozedUntil": snoozedUntil.timeIntervalSince1970,
            "savedAt": Date().timeIntervalSince1970
        ]
        pendingItems.append(payload)
        
        // Save back using Codable-compatible format
        let sharePayloads = pendingItems.compactMap { dict -> ShareExtensionPayload? in
            guard let contentStr = dict["content"] as? String else { return nil }
            return ShareExtensionPayload(
                content: contentStr,
                url: dict["url"] as? String,
                preview: dict["preview"] as? String,
                snoozedUntil: Date(timeIntervalSince1970: dict["snoozedUntil"] as? TimeInterval ?? Date().timeIntervalSince1970),
                savedAt: Date(timeIntervalSince1970: dict["savedAt"] as? TimeInterval ?? Date().timeIntervalSince1970)
            )
        }
        
        if let encodedData = try? JSONEncoder().encode(sharePayloads) {
            defaults.set(encodedData, forKey: "pendingShareItems")
        }
        
        // Haptic
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        // Dismiss after brief delay for animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil)
        }
    }
    
    private func cancel() {
        extensionContext?.cancelRequest(withError: NSError(domain: "com.nudge.share", code: 0))
    }
}

// MARK: - Shared Content

struct SharedContent {
    let text: String
    let url: String?
    let preview: String?
}

// MARK: - Share Extension Payload (Codable — must match main app)

struct ShareExtensionPayload: Codable {
    let content: String
    let url: String?
    let preview: String?
    let snoozedUntil: Date
    let savedAt: Date
}
