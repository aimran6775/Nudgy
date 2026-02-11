//
//  PersonaSystem.swift
//  Nudge
//
//  Phase 18: Persona System Foundation.
//  Nudgy adapts personality, language complexity, UI density,
//  and task breakdown depth based on user persona.
//
//  Stored in AppSettings.selectedPersona.
//

import SwiftUI

// MARK: - User Persona

enum UserPersona: String, CaseIterable, Codable, Sendable {
    case adhd        = "adhd"
    case professional = "professional"
    case student     = "student"
    case parent      = "parent"
    case creative    = "creative"
    
    var label: String {
        switch self {
        case .adhd:         return String(localized: "ADHD Brain")
        case .professional: return String(localized: "Busy Professional")
        case .student:      return String(localized: "Student")
        case .parent:       return String(localized: "Parent")
        case .creative:     return String(localized: "Creative")
        }
    }
    
    var icon: String {
        switch self {
        case .adhd:         return "brain.head.profile.fill"
        case .professional: return "briefcase.fill"
        case .student:      return "graduationcap.fill"
        case .parent:       return "figure.2.and.child.holdinghands"
        case .creative:     return "paintpalette.fill"
        }
    }
    
    var description: String {
        switch self {
        case .adhd:
            return String(localized: "Gentle nudges, task breakdowns, overwhelm support, dopamine rewards. Nudgy is your ADHD companion.")
        case .professional:
            return String(localized: "Efficient briefings, draft-ready emails, calendar sync. Nudgy keeps you sharp.")
        case .student:
            return String(localized: "Study planning, deadline tracking, break reminders. Nudgy helps you study smart.")
        case .parent:
            return String(localized: "Family scheduling, meal planning, errands. Nudgy helps manage the chaos.")
        case .creative:
            return String(localized: "Inspiration capture, project milestones, flow protection. Nudgy supports your creative process.")
        }
    }
    
    var accentColorHex: String {
        switch self {
        case .adhd:         return "#4FC3F7"   // Calming blue
        case .professional: return "#90CAF9"   // Corporate blue
        case .student:      return "#AED581"   // Fresh green
        case .parent:       return "#FFB74D"   // Warm amber
        case .creative:     return "#CE93D8"   // Creative purple
        }
    }
}

// MARK: - Persona Adapter

/// Adapts Nudgy's behavior based on the active persona.
enum PersonaAdapter {
    
    /// Get the system prompt modifier for AI conversations.
    static func systemPromptContext(for persona: UserPersona) -> String {
        switch persona {
        case .adhd:
            return """
            The user has ADHD. Be extra patient, break tasks into tiny steps, \
            celebrate small wins, offer to handle overwhelming tasks, suggest breaks, \
            use warm encouraging language. Never guilt them. When they're stuck, offer \
            to do it for them (draft, search, call). Use short sentences. Add emojis.
            """
        case .professional:
            return """
            The user is a busy professional. Be efficient and concise. \
            Prioritize by urgency and impact. Offer to draft professional emails, \
            schedule meetings, prepare briefings. Use clear, direct language. \
            Minimize small talk. Focus on actionable next steps.
            """
        case .student:
            return """
            The user is a student. Help with study planning, deadline tracking, \
            and assignment breakdowns. Use the Pomodoro technique. Remind them \
            to take breaks. Celebrate completing study sessions. Be encouraging \
            but not patronizing. Help with time management.
            """
        case .parent:
            return """
            The user is a parent managing family life. Help with meal planning, \
            school schedules, errands, and family activities. Be understanding \
            about interruptions. Batch related errands together. Suggest efficient \
            routines. Be warm and supportive, never judgmental about what's undone.
            """
        case .creative:
            return """
            The user is a creative professional. Protect their flow state — \
            batch admin tasks away from creative blocks. Help capture inspiration \
            quickly. Break creative projects into milestones, not minute tasks. \
            Be enthusiastic about their ideas. Suggest creative breaks, not just rest.
            """
        }
    }
    
    /// Get the greeting style for a persona.
    static func morningGreeting(for persona: UserPersona, name: String, taskCount: Int) -> String {
        let displayName = name.isEmpty ? "" : " \(name)"
        
        switch persona {
        case .adhd:
            if taskCount == 0 {
                return String(localized: "Good morning\(displayName)! Clean slate today — what feels doable? 🐧")
            }
            return String(localized: "Hey\(displayName)! You've got \(taskCount) things — let's just pick ONE to start. 🐧")
            
        case .professional:
            return String(localized: "Good morning\(displayName). \(taskCount) items on the agenda. Shall I brief you?")
            
        case .student:
            if taskCount > 5 {
                return String(localized: "Morning\(displayName)! Busy day — \(taskCount) things. Let's plan your study blocks! 📚")
            }
            return String(localized: "Hey\(displayName)! \(taskCount) tasks today. You've got this! 💪")
            
        case .parent:
            return String(localized: "Morning\(displayName)! Let's get the family organized — \(taskCount) things to juggle today. 🐧")
            
        case .creative:
            return String(localized: "Good morning\(displayName)! \(taskCount) things on the list — let's protect your creative time. ✨")
        }
    }
    
    /// Get task breakdown depth for a persona.
    static func breakdownDepth(for persona: UserPersona) -> Int {
        switch persona {
        case .adhd:     return 5   // Many tiny steps
        case .professional: return 3  // Key milestones
        case .student:  return 4   // Study blocks
        case .parent:   return 3   // Practical steps
        case .creative: return 2   // High-level phases
        }
    }
    
    /// Whether to show time estimates prominently.
    static func showTimeEstimates(for persona: UserPersona) -> Bool {
        switch persona {
        case .adhd, .student: return true
        case .professional, .parent, .creative: return false
        }
    }
    
    /// Celebration message style for persona.
    static func celebrationMessage(for persona: UserPersona, species: FishSpecies) -> String {
        switch persona {
        case .adhd:
            switch species {
            case .catfish:   return String(localized: "Quick win! You did it! 🐟")
            case .tropical:  return String(localized: "Nice catch! That wasn't easy and you did it anyway! 🐠")
            case .swordfish: return String(localized: "WHOA! That was a BIG one! You're incredible! 🗡️")
            case .whale:     return String(localized: "LEGENDARY! You just caught a whale! I'm so proud of you! 🐋")
            }
        case .professional:
            switch species {
            case .catfish:   return String(localized: "Done. ✓")
            case .tropical:  return String(localized: "Good progress. Moving forward.")
            case .swordfish: return String(localized: "Major deliverable completed. Well done.")
            case .whale:     return String(localized: "Outstanding achievement. Milestone reached.")
            }
        case .student:
            switch species {
            case .catfish:   return String(localized: "One more done! 🐟")
            case .tropical:  return String(localized: "Great study session! 📚🐠")
            case .swordfish: return String(localized: "Assignment crushed! 🗡️💪")
            case .whale:     return String(localized: "EXAM READY! You're killing it! 🐋🎓")
            }
        case .parent:
            switch species {
            case .catfish:   return String(localized: "One less thing to worry about! 🐟")
            case .tropical:  return String(localized: "Family win! 🐠👨‍👩‍👧‍👦")
            case .swordfish: return String(localized: "That was a big one — you're an amazing parent! 🗡️")
            case .whale:     return String(localized: "Super parent achievement unlocked! 🐋🏆")
            }
        case .creative:
            switch species {
            case .catfish:   return String(localized: "Cleared the way for creativity! 🐟✨")
            case .tropical:  return String(localized: "Creative momentum building! 🐠🎨")
            case .swordfish: return String(localized: "Major creative milestone! Your work matters! 🗡️")
            case .whale:     return String(localized: "MASTERPIECE in the making! 🐋🌟")
            }
        }
    }
}
