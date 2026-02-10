//
//  NudgeWatchApp.swift
//  NudgeWatch Watch App
//
//  Companion watch app showing current task, quick actions,
//  and focus timer on the wrist.
//
//  Communicates with the iOS app via WatchConnectivity.
//

import SwiftUI
import WatchConnectivity

@main
struct NudgeWatchApp: App {
    
    @State private var connectivity = WatchConnectivityManager.shared
    
    var body: some Scene {
        WindowGroup {
            WatchHomeView()
                .environment(connectivity)
        }
    }
}

// MARK: - Watch Connectivity Manager

@Observable
final class WatchConnectivityManager: NSObject, WCSessionDelegate {
    
    static let shared = WatchConnectivityManager()
    
    var currentTask: WatchTask?
    var taskCount: Int = 0
    var streak: Int = 0
    var isConnected: Bool = false
    
    private var session: WCSession?
    
    override init() {
        super.init()
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }
    
    // MARK: - Send Actions to Phone
    
    func markDone() {
        guard let task = currentTask else { return }
        session?.sendMessage(["action": "done", "taskID": task.id], replyHandler: nil)
    }
    
    func snooze() {
        guard let task = currentTask else { return }
        session?.sendMessage(["action": "snooze", "taskID": task.id], replyHandler: nil)
    }
    
    func skip() {
        guard let task = currentTask else { return }
        session?.sendMessage(["action": "skip", "taskID": task.id], replyHandler: nil)
    }
    
    func requestRefresh() {
        session?.sendMessage(["action": "refresh"], replyHandler: nil)
    }
    
    // MARK: - WCSessionDelegate
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            isConnected = activationState == .activated
            if isConnected {
                requestRefresh()
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            updateFromContext(applicationContext)
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            updateFromContext(message)
        }
    }
    
    private func updateFromContext(_ context: [String: Any]) {
        if let taskData = context["currentTask"] as? [String: Any] {
            currentTask = WatchTask(
                id: taskData["id"] as? String ?? "",
                content: taskData["content"] as? String ?? "",
                emoji: taskData["emoji"] as? String ?? "📋",
                estimatedMinutes: taskData["estimatedMinutes"] as? Int
            )
        } else {
            currentTask = nil
        }
        
        taskCount = context["taskCount"] as? Int ?? 0
        streak = context["streak"] as? Int ?? 0
    }
}

// MARK: - Watch Task Model

struct WatchTask: Identifiable {
    let id: String
    let content: String
    let emoji: String
    let estimatedMinutes: Int?
}
