//
//  NudgyEmotionMapper.swift
//  Nudge
//
//  Phase 14: Maps response content to penguin expressions.
//  Analyzes text sentiment/content to determine what face Nudgy should make.
//  Pure function — no side effects.
//

import Foundation

// MARK: - NudgyEmotionMapper

/// Maps text content to PenguinExpression values.
enum NudgyEmotionMapper {
    
    /// Detect the emotional tone of a response and return the matching expression.
    static func expressionForResponse(_ text: String) -> PenguinExpression {
        let lower = text.lowercased()
        
        // Celebration / excitement
        if lower.contains("🎉") || lower.contains("🎊") || lower.contains("all done") ||
           lower.contains("legend") || lower.contains("amazing") || lower.contains("wooo") ||
           lower.contains("proud of") || lower.contains("you did it") || lower.contains("crushed") {
            return .celebrating
        }
        
        // Happy / positive
        if lower.contains("nice") || lower.contains("great") || lower.contains("awesome") ||
           lower.contains("yesss") || lower.contains("beautiful") || lower.contains("happy waddle") ||
           lower.contains("love") || lower.contains("😊") || lower.contains("💙") ||
           lower.contains("well done") || lower.contains("nailed") {
            return .happy
        }
        
        // Nudging / encouraging action
        if lower.contains("overdue") || lower.contains("waiting") || lower.contains("been a while") ||
           lower.contains("let's do") || lower.contains("tackle") || lower.contains("how about") ||
           lower.contains("you should") || lower.contains("try") {
            return .nudging
        }
        
        // Confused / unsure
        if lower.contains("hmm") || lower.contains("not sure") || lower.contains("confused") ||
           lower.contains("buffering") || lower.contains("🤔") || lower.contains("weird") {
            return .confused
        }
        
        // Sleeping / rest
        if lower.contains("sleep") || lower.contains("rest") || lower.contains("late") ||
           lower.contains("💤") || lower.contains("😴") || lower.contains("night") {
            return .sleeping
        }
        
        // Thumbs up / supportive / reassuring
        if lower.contains("got this") || lower.contains("no pressure") || lower.contains("it's okay") ||
           lower.contains("that's fine") || lower.contains("no rush") || lower.contains("whenever") ||
           lower.contains("valid") || lower.contains("it's cool") {
            return .thumbsUp
        }
        
        // Listening / empathy
        if lower.contains("tell me") || lower.contains("listening") || lower.contains("I hear") ||
           lower.contains("go on") || lower.contains("what's up") {
            return .listening
        }
        
        // Waving / greeting
        if lower.contains("hey") || lower.contains("hello") || lower.contains("morning") ||
           lower.contains("evening") || lower.contains("👋") {
            return .waving
        }
        
        // Default: talking
        return .talking
    }
    
    /// Map a specific action to an expression.
    static func expressionForAction(_ action: NudgyAction) -> PenguinExpression {
        switch action {
        case .greeting: return .waving
        case .listening: return .listening
        case .thinking: return .thinking
        case .celebrating: return .celebrating
        case .snoozing: return .thumbsUp
        case .nudging: return .nudging
        case .resting: return .sleeping
        case .talking: return .talking
        case .idle: return .idle
        case .confused: return .confused
        case .happy: return .happy
        }
    }
}

// MARK: - Nudgy Actions

/// High-level actions Nudgy can be performing.
enum NudgyAction {
    case greeting
    case listening
    case thinking
    case celebrating
    case snoozing
    case nudging
    case resting
    case talking
    case idle
    case confused
    case happy
}
