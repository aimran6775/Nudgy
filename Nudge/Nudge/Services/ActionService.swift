//
//  ActionService.swift
//  Nudge
//
//  Opens phone calls, text messages, emails, and links.
//  SMS uses MFMessageComposeViewController for pre-filled body support.
//

import SwiftUI
import MessageUI

/// Central action launcher — routes tasks to Phone, Messages, Mail, Safari.
enum ActionService {
    
    /// Open Phone app with the given number.
    @MainActor
    static func openCall(number: String) {
        guard let url = URL(string: "tel:\(number.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? number)") else { return }
        HapticService.shared.actionButtonTap()
        UIApplication.shared.open(url)
    }
    
    /// Open a link in Safari.
    @MainActor
    static func openLink(urlString: String) {
        guard let url = URL(string: urlString) else { return }
        HapticService.shared.actionButtonTap()
        UIApplication.shared.open(url)
    }
    
    /// Open Mail compose with optional subject and body.
    @MainActor
    static func openEmail(to: String, subject: String? = nil, body: String? = nil) {
        var components = URLComponents(string: "mailto:\(to)")
        var queryItems: [URLQueryItem] = []
        if let subject { queryItems.append(.init(name: "subject", value: subject)) }
        if let body { queryItems.append(.init(name: "body", value: body)) }
        if !queryItems.isEmpty { components?.queryItems = queryItems }
        
        guard let url = components?.url else { return }
        HapticService.shared.actionButtonTap()
        UIApplication.shared.open(url)
    }
    
    /// Whether the device can send text messages.
    static var canSendText: Bool {
        MFMessageComposeViewController.canSendText()
    }
    
    /// Route an action for a NudgeItem.
    /// If actionTarget is missing, attempts on-device contact resolution first,
    /// then posts `.nudgeNeedsContactPicker` if resolution fails.
    @MainActor
    static func perform(action: ActionType, item: NudgeItem) {
        if let target = item.actionTarget, !target.isEmpty {
            executeAction(action, target: target, item: item)
        } else if let contactName = item.contactName, !contactName.isEmpty {
            // Try to resolve contact name → phone/email on-device
            Task {
                let (target, resolvedName) = await ContactResolver.shared.resolveActionTarget(
                    name: contactName,
                    for: action
                )
                if let target, !target.isEmpty {
                    // Cache the resolved target on the item for next time
                    item.actionTarget = target
                    if let resolvedName { item.contactName = resolvedName }
                    executeAction(action, target: target, item: item)
                } else {
                    // Resolution failed — ask user to pick a contact
                    HapticService.shared.error()
                    NotificationCenter.default.post(
                        name: .nudgeNeedsContactPicker,
                        object: nil,
                        userInfo: [
                            "itemID": item.id.uuidString,
                            "actionType": action.rawValue
                        ]
                    )
                }
            }
        } else {
            // No target and no contact name — nothing to resolve
            HapticService.shared.error()
        }
    }
    
    /// Execute an action with a known target.
    @MainActor
    private static func executeAction(_ action: ActionType, target: String, item: NudgeItem) {
        switch action {
        case .call:
            openCall(number: target)
        case .email:
            openEmail(
                to: target,
                subject: item.aiDraftSubject,
                body: item.aiDraft
            )
        case .openLink:
            openLink(urlString: target)
        case .text:
            // Text messages are handled via MessageComposeView (UIViewControllerRepresentable)
            // Post a notification so the view layer can present the compose sheet
            NotificationCenter.default.post(
                name: .nudgeComposeMessage,
                object: nil,
                userInfo: [
                    "recipient": target,
                    "body": item.aiDraft ?? "",
                    "itemID": item.id.uuidString
                ]
            )
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when ActionService needs to present MFMessageComposeViewController
    static let nudgeComposeMessage = Notification.Name("nudgeComposeMessage")
    
    /// Posted when a view wants to open the Brain Dump overlay
    static let nudgeOpenBrainDump = Notification.Name("nudgeOpenBrainDump")
    
    /// Posted when a view wants to open the Quick Add sheet
    static let nudgeOpenQuickAdd = Notification.Name("nudgeOpenQuickAdd")
    
    /// Posted when a view wants to open the Nudgy Chat sheet
    static let nudgeOpenChat = Notification.Name("nudgeOpenChat")
    
    /// Posted when data changes and badge/views should refresh
    static let nudgeDataChanged = Notification.Name("nudgeDataChanged")
    
    /// Posted when ActionService can't resolve a contact — view should show ContactPickerView
    static let nudgeNeedsContactPicker = Notification.Name("nudgeNeedsContactPicker")
    
    /// Posted when TTS was skipped (voice disabled) — voice conversation loop should auto-resume listening
    static let nudgyTTSSkipped = Notification.Name("nudgyTTSSkipped")
}

// MARK: - Message Compose View (UIViewControllerRepresentable)

/// SwiftUI wrapper for MFMessageComposeViewController.
/// Required because `sms:` URL scheme doesn't support pre-filled body.
struct MessageComposeView: UIViewControllerRepresentable {
    let recipients: [String]
    let body: String
    var onFinished: () -> Void = {}
    
    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let controller = MFMessageComposeViewController()
        controller.recipients = recipients
        controller.body = body
        controller.messageComposeDelegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onFinished: onFinished)
    }
    
    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let onFinished: () -> Void
        
        init(onFinished: @escaping () -> Void) {
            self.onFinished = onFinished
        }
        
        func messageComposeViewController(
            _ controller: MFMessageComposeViewController,
            didFinishWith result: MessageComposeResult
        ) {
            controller.dismiss(animated: true)
            onFinished()
        }
    }
}
