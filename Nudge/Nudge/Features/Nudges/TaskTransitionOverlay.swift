//
//  TaskTransitionOverlay.swift
//  Nudge
//
//  A brief animated transition when moving from one task to the next.
//  Nudgy celebrates the completed task and gently introduces the next one.
//
//  ADHD-optimized: Provides a clear "context switch" moment
//  so the brain registers the shift between tasks.
//

import SwiftUI

struct TaskTransitionOverlay: View {
    
    let completedTask: String
    let completedEmoji: String
    let nextTask: String?
    let nextEmoji: String?
    @Binding var isPresented: Bool
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: TransitionPhase = .celebrating
    
    private enum TransitionPhase {
        case celebrating, nextUp, dismissed
    }
    
    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }
            
            VStack(spacing: DesignTokens.spacingXXL) {
                Spacer()
                
                switch phase {
                case .celebrating:
                    celebrateView
                case .nextUp:
                    nextUpView
                case .dismissed:
                    EmptyView()
                }
                
                Spacer()
                Spacer()
            }
        }
        .onAppear {
            HapticService.shared.swipeDone()
            
            // Auto-advance after celebration
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                if nextTask != nil {
                    withAnimation(AnimationConstants.springSmooth) {
                        phase = .nextUp
                    }
                    
                    // Auto-dismiss after showing next task
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        dismiss()
                    }
                } else {
                    dismiss()
                }
            }
        }
    }
    
    // MARK: - Celebrate
    
    private var celebrateView: some View {
        VStack(spacing: DesignTokens.spacingLG) {
            Image(systemName: TaskIconResolver.resolveSymbol(for: completedEmoji))
                .font(.system(size: 64))
                .foregroundStyle(DesignTokens.accentComplete)
                .scaleEffect(reduceMotion ? 1.0 : 1.2)
                .animation(
                    reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.5),
                    value: phase
                )
            
            Text(String(localized: "Done! ✨"))
                .font(AppTheme.title2)
                .foregroundStyle(DesignTokens.accentComplete)
            
            Text(completedTask)
                .font(AppTheme.body)
                .foregroundStyle(DesignTokens.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .transition(.scale(scale: 0.8).combined(with: .opacity))
    }
    
    // MARK: - Next Up
    
    private var nextUpView: some View {
        VStack(spacing: DesignTokens.spacingLG) {
            Text(String(localized: "Next up"))
                .font(AppTheme.caption)
                .foregroundStyle(DesignTokens.textTertiary)
                .textCase(.uppercase)
            
            Image(systemName: TaskIconResolver.resolveSymbol(for: nextEmoji ?? "checklist"))
                .font(.system(size: 48))
                .foregroundStyle(DesignTokens.accentActive)
            
            Text(nextTask ?? "")
                .font(AppTheme.title3)
                .foregroundStyle(DesignTokens.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            
            Text(String(localized: "You got this 💙"))
                .font(AppTheme.body)
                .foregroundStyle(DesignTokens.accentActive)
        }
        .transition(.move(edge: .trailing).combined(with: .opacity))
    }
    
    // MARK: - Dismiss
    
    private func dismiss() {
        withAnimation(.easeOut(duration: 0.25)) {
            isPresented = false
        }
    }
}
