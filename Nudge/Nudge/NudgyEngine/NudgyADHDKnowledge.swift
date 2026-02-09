//
//  NudgyADHDKnowledge.swift
//  Nudge
//
//  Research-backed ADHD strategy database.
//  This module encodes clinical knowledge as behavioral scaffolding.
//  Nudgy never uses clinical language with users — this data INFORMS
//  prompt generation, curated lines, and behavioral decisions.
//
//  Sources informing this module (never cited to users):
//  - Dr. Russell Barkley: Executive function model, time blindness
//  - Dr. Edward Hallowell: ADHD as a trait, not a flaw
//  - CHADD clinical guidelines: Evidence-based strategies
//  - Jessica McCabe (How to ADHD): Community-tested approaches
//  - Dr. William Dodson: RSD (Rejection Sensitive Dysphoria)
//  - ADDitude Magazine research summaries
//  - r/ADHD community pain points and lived experience
//

import Foundation

// MARK: - NudgyADHDKnowledge

/// Research-backed ADHD knowledge that informs Nudgy's behavior.
/// This is the invisible scaffolding — users never see clinical terms.
/// Instead, this data shapes HOW Nudgy responds, WHEN it intervenes,
/// and WHAT strategies it suggests (in penguin language).
enum NudgyADHDKnowledge {
    
    // MARK: - Executive Function Strategies
    
    /// Strategies for when the user can't initiate a task (executive dysfunction).
    /// Based on Barkley's hot/cold EF model and behavioral activation research.
    enum ExecutiveFunction {
        
        /// The smallest possible first steps for common task types.
        /// Research: "Implementation intentions" (Gollwitzer, 1999) dramatically
        /// increase follow-through for ADHD individuals.
        static let microSteps: [String: [String]] = [
            "call": [
                "Just open the phone app",
                "Find their contact",
                "Type their name in search",
            ],
            "email": [
                "Just open the email app",
                "Hit compose. Leave it blank",
                "Type the subject line only",
            ],
            "text": [
                "Open the chat",
                "Just type 'hey'",
            ],
            "clean": [
                "Pick up one thing. Just one",
                "Set a 5-minute timer. Stop when it rings",
                "Clear one surface. Just the table",
            ],
            "exercise": [
                "Put on the shoes. That's it",
                "Stand up. That counts as starting",
                "Walk to the door",
            ],
            "work": [
                "Open the file. Don't write yet",
                "Read the first paragraph only",
                "Write one sentence. Any sentence",
            ],
            "study": [
                "Open the textbook to any page",
                "Read one paragraph",
                "Write one note. One",
            ],
            "appointment": [
                "Look up the number",
                "Write down what you need to say",
                "Dial — you can always hang up",
            ],
            "default": [
                "What's the tiniest first piece?",
                "Just look at it. That's a start",
                "Open it. You don't have to do it yet",
            ],
        ]
        
        /// Get micro-steps for a task based on keyword matching.
        static func microStepsFor(taskContent: String) -> [String] {
            let lower = taskContent.lowercased()
            
            for (key, steps) in microSteps {
                if lower.contains(key) {
                    return steps
                }
            }
            return microSteps["default"]!
        }
        
        /// Detect if a task might cause initiation paralysis.
        /// Based on: vague language, large scope, emotional weight.
        static func paralysisRisk(taskContent: String) -> ParalysisRisk {
            let lower = taskContent.lowercased()
            
            // High-risk indicators (vague + large scope)
            let vagueWords = ["sort out", "deal with", "figure out", "handle", "organize",
                              "fix everything", "get my life", "catch up on", "all the"]
            let emotionalWords = ["tell them", "confront", "apologize", "break up",
                                  "quit", "confess", "ask for help"]
            
            let isVague = vagueWords.contains { lower.contains($0) }
            let isEmotional = emotionalWords.contains { lower.contains($0) }
            
            if isVague && isEmotional { return .high }
            if isVague || isEmotional { return .moderate }
            
            // Low-risk: specific, concrete tasks
            let concreteVerbs = ["call", "text", "email", "buy", "pick up",
                                 "send", "submit", "book", "schedule"]
            let isConcrete = concreteVerbs.contains { lower.contains($0) }
            
            return isConcrete ? .low : .moderate
        }
        
        enum ParalysisRisk: String {
            case low      // Concrete, doable — just present it
            case moderate // Might need a nudge or breakdown offer
            case high     // Likely to cause avoidance — proactively offer help
        }
    }
    
    // MARK: - Time Awareness
    
    /// Time-related ADHD support strategies.
    /// Based on Barkley's research on time blindness as a core ADHD deficit.
    enum TimeAwareness {
        
        /// Contextual time facts for gentle time anchoring.
        /// ADHD brains struggle with "time horizon" — making future consequences
        /// feel real. These provide gentle temporal context without pressure.
        static func gentleTimeContext(for date: Date) -> String? {
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: date)
            let weekday = calendar.component(.weekday, from: date)
            let isWeekend = weekday == 1 || weekday == 7
            
            switch hour {
            case 5..<8:
                return "Early morning. …The quiet hours are good for thinking"
            case 8..<10:
                return isWeekend
                    ? "Weekend morning. No rush at all"
                    : "Morning. If you take medication, your focus window might be opening"
            case 10..<12:
                return "Mid-morning. …Usually a good time to tackle something tricky"
            case 12..<14:
                return "Around lunch. Bodies need fuel. Have you eaten? 🐟"
            case 14..<16:
                return "The afternoon dip. It's normal to feel slower right now"
            case 16..<18:
                return "Late afternoon. …Wrapping up is its own kind of win"
            case 18..<20:
                return "Evening. Whatever you didn't finish today can wait"
            case 20..<22:
                return "Getting late. …Tomorrow exists for a reason"
            default:
                return "It's very late. Being awake is okay, but sleep is good too"
            }
        }
        
        /// How long a task has been waiting, framed gently.
        static func staleness(createdAt: Date, now: Date = .now) -> TaskStaleness {
            let days = Calendar.current.dateComponents([.day], from: createdAt, to: now).day ?? 0
            
            switch days {
            case 0: return .fresh
            case 1: return .yesterday
            case 2...4: return .fewDays
            case 5...14: return .overAWeek
            default: return .longTime
            }
        }
        
        enum TaskStaleness: String {
            case fresh      // Created today — no comment needed
            case yesterday  // "Since yesterday" — still fine
            case fewDays    // Gentle acknowledgment
            case overAWeek  // Maybe worth discussing
            case longTime   // Might not actually be needed anymore
        }
        
        /// Gentle staleness framing (never guilt-inducing).
        static func stalenessMessage(_ staleness: TaskStaleness) -> String? {
            switch staleness {
            case .fresh, .yesterday:
                return nil
            case .fewDays:
                return "This one's been here a few days. …That's okay"
            case .overAWeek:
                return "This has been sitting for a while. …Still important, or can it go?"
            case .longTime:
                return "This one's been here a long time. …Maybe it's not actually needed anymore?"
            }
        }
    }
    
    // MARK: - Emotional Regulation
    
    /// Emotional support strategies informed by RSD and emotional dysregulation research.
    /// Based on Dr. William Dodson's work on Rejection Sensitive Dysphoria
    /// and general ADHD emotional flooding patterns.
    enum EmotionalRegulation {
        
        /// Detect emotional state from user's text.
        /// Simple keyword-based — supplements the AI's deeper understanding.
        static func detectMood(from text: String) -> DetectedMood {
            let lower = text.lowercased()
            
            let overwhelmedWords = ["overwhelmed", "too much", "can't handle", "drowning",
                                     "everything", "impossible", "so much", "falling behind",
                                     "never enough", "behind on"]
            let frustratedWords = ["frustrated", "angry", "annoyed", "stupid", "hate",
                                    "can't do anything", "useless", "what's wrong with me",
                                    "why can't i", "ugh", "failing", "terrible"]
            let anxiousWords = ["anxious", "worried", "scared", "nervous", "panic",
                                "what if", "afraid", "stress", "deadline"]
            let sadWords = ["sad", "depressed", "hopeless", "tired", "exhausted",
                            "don't care", "give up", "what's the point", "numb"]
            let positiveWords = ["good", "great", "happy", "excited", "proud",
                                 "did it", "finished", "yes", "finally", "amazing"]
            
            // Check from most urgent to least
            if overwhelmedWords.contains(where: { lower.contains($0) }) { return .overwhelmed }
            if frustratedWords.contains(where: { lower.contains($0) }) { return .frustrated }
            if anxiousWords.contains(where: { lower.contains($0) }) { return .anxious }
            if sadWords.contains(where: { lower.contains($0) }) { return .sad }
            if positiveWords.contains(where: { lower.contains($0) }) { return .positive }
            return .neutral
        }
        
        enum DetectedMood: String, Codable {
            case overwhelmed   // Too much happening — need to narrow focus
            case frustrated    // Self-directed anger — possible RSD episode
            case anxious       // Future-focused worry — need grounding
            case sad           // Low energy — need warmth, not tasks
            case positive      // Good energy — ride the wave gently
            case neutral       // No strong signal — proceed normally
        }
        
        /// Get the appropriate response strategy for a detected mood.
        /// This determines HOW Nudgy should respond, not what it says.
        static func strategy(for mood: DetectedMood) -> ResponseStrategy {
            switch mood {
            case .overwhelmed:
                return ResponseStrategy(
                    approach: .groundFirst,
                    suggestTasks: false,
                    offerBreakdown: true,
                    toneGuidance: "Be a calm anchor. Narrow their focus to ONE thing. Don't list or add.",
                    curatedResponse: NudgyPersonality.CuratedLines.overwhelmSupport.randomElement()!
                )
            case .frustrated:
                return ResponseStrategy(
                    approach: .validateFirst,
                    suggestTasks: false,
                    offerBreakdown: false,
                    toneGuidance: "Validate without fixing. 'That sounds really frustrating.' No advice unless asked.",
                    curatedResponse: "That sounds frustrating. …It's okay to feel that way 💙"
                )
            case .anxious:
                return ResponseStrategy(
                    approach: .groundFirst,
                    suggestTasks: false,
                    offerBreakdown: true,
                    toneGuidance: "Gentle grounding. Bring them to the present. 'Right now, you're here. That's enough.'",
                    curatedResponse: "Hey. …You're here right now. That's what matters 💙"
                )
            case .sad:
                return ResponseStrategy(
                    approach: .bePresentOnly,
                    suggestTasks: false,
                    offerBreakdown: false,
                    toneGuidance: "Just be present. Don't try to fix or motivate. Warmth only.",
                    curatedResponse: "I'm here. …We don't have to do anything right now 💙"
                )
            case .positive:
                return ResponseStrategy(
                    approach: .gentlyCelebrate,
                    suggestTasks: true,
                    offerBreakdown: false,
                    toneGuidance: "Match their warmth but don't spike energy. 'That's really nice' over 'AMAZING!'",
                    curatedResponse: "Oh. …That's really nice. I'm glad 🐧"
                )
            case .neutral:
                return ResponseStrategy(
                    approach: .normalCompanion,
                    suggestTasks: true,
                    offerBreakdown: false,
                    toneGuidance: "Normal gentle companion mode.",
                    curatedResponse: nil
                )
            }
        }
        
        struct ResponseStrategy {
            let approach: ResponseApproach
            let suggestTasks: Bool
            let offerBreakdown: Bool
            let toneGuidance: String
            let curatedResponse: String?
        }
        
        enum ResponseApproach: String {
            case groundFirst      // Help them return to present moment
            case validateFirst    // Acknowledge feelings before anything else
            case bePresentOnly    // Just be there. No action. No advice.
            case gentlyCelebrate  // Warm acknowledgment, not hype
            case normalCompanion  // Standard gentle companion mode
        }
    }
    
    // MARK: - Pattern Recognition
    
    /// Behavioral pattern analysis for long-term ADHD support.
    /// These patterns help Nudgy become a better companion over time.
    enum PatternRecognition {
        
        /// Analyze task completion patterns to identify productive times.
        static func analyzeProductiveHours(completionHours: [Int]) -> ProductiveTimeInsight? {
            guard completionHours.count >= 5 else { return nil }
            
            var hourCounts: [Int: Int] = [:]
            for hour in completionHours {
                hourCounts[hour, default: 0] += 1
            }
            
            guard let peakHour = hourCounts.max(by: { $0.value < $1.value }) else { return nil }
            
            let period: String
            switch peakHour.key {
            case 5..<12: period = "morning"
            case 12..<17: period = "afternoon"
            case 17..<21: period = "evening"
            default: period = "late night"
            }
            
            return ProductiveTimeInsight(
                peakHour: peakHour.key,
                period: period,
                confidence: Double(peakHour.value) / Double(completionHours.count)
            )
        }
        
        struct ProductiveTimeInsight {
            let peakHour: Int
            let period: String
            let confidence: Double  // 0-1, how strong the pattern is
        }
        
        /// Analyze snooze patterns to detect avoidance.
        static func analyzeSnoozePattern(
            snoozeCount: Int,
            totalTasks: Int,
            sameTaskSnoozes: Int
        ) -> SnoozeInsight {
            let snoozeRate = totalTasks > 0 ? Double(snoozeCount) / Double(totalTasks) : 0
            
            if sameTaskSnoozes >= 3 {
                return .avoidance  // Same task snoozed 3+ times → probably stuck
            }
            if snoozeRate > 0.5 {
                return .overwhelmed  // Snoozing everything → too much on plate
            }
            if snoozeRate > 0.3 {
                return .timingIssue  // Moderate snoozing → tasks at wrong times
            }
            return .healthy  // Normal amount of snoozing
        }
        
        enum SnoozeInsight: String {
            case healthy      // Normal — no intervention needed
            case timingIssue  // Suggest different scheduling
            case overwhelmed  // Too many tasks — suggest pruning
            case avoidance    // Stuck on specific task — offer breakdown
        }
        
        /// Gentle suggestions based on snooze patterns.
        static func snoozeSuggestion(_ insight: SnoozeInsight) -> String? {
            switch insight {
            case .healthy:
                return nil
            case .timingIssue:
                return "I've noticed you snooze things a lot. …Maybe we're scheduling at the wrong times? 🐧"
            case .overwhelmed:
                return "There might be too many things on the iceberg. …Want to pick the 3 that actually matter? 🧊"
            case .avoidance:
                return "This one keeps getting pushed back. …Want to talk about what's making it hard? 💙"
            }
        }
        
        /// Analyze streak data for gentle encouragement.
        static func streakMessage(consecutiveDaysActive: Int) -> String? {
            switch consecutiveDaysActive {
            case 0...1: return nil
            case 2: return "Two days in a row. …That's something 🐧"
            case 3...4: return "You've been showing up. I noticed 💙"
            case 5...6: return "Almost a week of showing up. …That takes something 🧊"
            case 7: return "A whole week. …I'm quietly proud of you 🐧"
            case 8...13: return "You keep coming back. That matters more than any task 💙"
            case 14...29: return "Two weeks of this. …You're building something real 🧊"
            default: return "You've been here \(consecutiveDaysActive) days. …That's not nothing. That's everything 💙"
            }
        }
    }
    
    // MARK: - Body Doubling
    
    /// Body doubling support — the practice of having someone present
    /// while you work, which dramatically helps ADHD task initiation.
    /// Research: Nikolas & Nigg (2013) on external accountability.
    enum BodyDoubling {
        
        /// Messages for starting a body doubling session.
        static func startMessage(taskContent: String) -> String {
            let messages = [
                "I'll sit here while you work on that. …Just a penguin, keeping you company 🧊",
                "I'm not going anywhere. You do your thing — I'll watch the ice 🐧",
                "Let's do this together. …Well, you do it. I'll be here 💙",
                "I'll stay right here. …Penguins are excellent at just being present 🧊",
            ]
            return messages.randomElement()!
        }
        
        /// Gentle check-in messages during body doubling.
        static func checkInMessage(minutesElapsed: Int) -> String? {
            switch minutesElapsed {
            case 5: return "Still here. …You're doing great 🐧"
            case 15: return "Fifteen minutes. …That's real progress 💙"
            case 25: return "Almost half an hour. …Water break? 💧"
            case 30: return "Thirty minutes of focus. …That's a lot. Take a breath 🧊"
            case 45: return "You've been going a while. …Stretch? Your body will thank you 🐧"
            case 60: return "An hour. …That's impressive. But maybe a real break? 💙"
            default: return nil
            }
        }
        
        /// Message when body doubling session ends.
        static func endMessage(minutesWorked: Int) -> String {
            if minutesWorked < 5 {
                return "Even a few minutes counts. …Really 🐧"
            } else if minutesWorked < 15 {
                return "\(minutesWorked) minutes. …That's \(minutesWorked) more than zero 💙"
            } else if minutesWorked < 30 {
                return "Nice session. …You showed up and that matters 🧊"
            } else {
                return "\(minutesWorked) minutes of focus. …I'm proud of you 🐧"
            }
        }
    }
    
    // MARK: - Transition Support
    
    /// Support for task transitions — one of the hardest things for ADHD brains.
    /// Research: Shifting/cognitive flexibility deficits (Willcutt et al., 2005).
    enum TransitionSupport {
        
        /// Help with the difficult moment between tasks.
        static func transitionMessage(from previousTask: String?, to nextTask: String) -> String {
            let messages: [String]
            if previousTask != nil {
                messages = [
                    "Take a breath. …One thing done, new thing starting 💙",
                    "Switching gears. That's actually really hard. …Take a moment 🧊",
                    "Okay. …Let the last thing go. We're here now 🐧",
                    "Deep breath. …New task, fresh start. No rush 💙",
                ]
            } else {
                messages = [
                    "Starting something new. …Just look at it first. That counts 🐧",
                    "Here we go. …One small step at a time 💙",
                    "Let's see this one. …No pressure. Just have a look 🧊",
                ]
            }
            return messages.randomElement()!
        }
        
        /// Suggest a micro-break between tasks.
        static let microBreakSuggestions = [
            "Quick breath. …In for 4, out for 4 💙",
            "Wiggle your fingers. …Stretch. …Okay, ready 🐧",
            "Look at something far away for 20 seconds. …Good for your eyes and your brain 🧊",
            "Sip of water. …Hydrated penguins are happy penguins 💧",
        ]
    }
    
    // MARK: - Medication Awareness (Opt-In Only)
    
    /// Medication-aware support. ONLY activated if user explicitly shares
    /// their medication routine. Never assumes. Never asks. Never suggests.
    enum MedicationAwareness {
        
        /// If the user has shared their medication timing, provide
        /// gentle focus-window awareness.
        static func focusWindowMessage(medicationTime: Date, now: Date = .now) -> String? {
            let hoursSince = Calendar.current.dateComponents([.hour], from: medicationTime, to: now).hour ?? 0
            
            switch hoursSince {
            case 0..<1:
                return "Your focus might be ramping up. …Good time for the tricky stuff 🐧"
            case 1..<4:
                return nil  // Peak focus window — don't interrupt
            case 4..<6:
                return "If you have something important, now might be a good time before the afternoon 💙"
            case 6..<8:
                return "Energy might be shifting. …Lighter tasks work well right now 🧊"
            default:
                return nil  // Don't comment outside the medication cycle
            }
        }
    }
    
    // MARK: - Communication Helpers
    
    /// Translate clinical concepts into Nudgy's language.
    /// These mappings ensure Nudgy never sounds like a textbook.
    static let clinicalToNudgy: [String: String] = [
        "executive dysfunction": "that stuck feeling",
        "time blindness": "time being weird",
        "rejection sensitive dysphoria": "that sharp sting when something doesn't go right",
        "emotional dysregulation": "big feelings",
        "hyperfocus": "being in the zone",
        "working memory deficit": "forgetting the thing you were just thinking about",
        "task initiation difficulty": "trouble starting",
        "cognitive flexibility": "switching between things",
        "sustained attention": "staying with one thing",
        "impulsivity": "acting before thinking",
        "hyperactivity": "the buzzy energy",
        "inattentive": "drifty brain",
        "comorbidity": "other stuff going on too",
        "neurodivergent": "brain works differently",
        "dopamine": "the motivation thing",
        "stimulant medication": "your meds",
    ]
}
