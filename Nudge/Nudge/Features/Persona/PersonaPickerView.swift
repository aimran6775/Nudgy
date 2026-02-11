//
//  PersonaPickerView.swift
//  Nudge
//
//  Phase 19: Persona selection — shown during onboarding and
//  accessible from YouView. Choose how Nudgy adapts to your style.
//

import SwiftUI

struct PersonaPickerView: View {
    
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedPersona: UserPersona = .adhd
    @State private var animateIn = false
    
    var isOnboarding: Bool = false
    var onComplete: (() -> Void)?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: DesignTokens.spacingLG) {
                        // Header
                        VStack(spacing: DesignTokens.spacingSM) {
                            Text("🐧")
                                .font(.system(size: 56))
                                .scaleEffect(animateIn ? 1 : 0.5)
                                .opacity(animateIn ? 1 : 0)
                                .animation(.spring(response: 0.6, dampingFraction: 0.6), value: animateIn)
                            
                            Text(String(localized: "How should Nudgy help you?"))
                                .font(AppTheme.title2)
                                .foregroundStyle(DesignTokens.textPrimary)
                                .multilineTextAlignment(.center)
                            
                            Text(String(localized: "Nudgy adapts personality, language, and suggestions to match your style."))
                                .font(AppTheme.body)
                                .foregroundStyle(DesignTokens.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, DesignTokens.spacingLG)
                        }
                        .padding(.top, DesignTokens.spacingLG)
                        
                        // Persona cards
                        VStack(spacing: DesignTokens.spacingSM) {
                            ForEach(UserPersona.allCases, id: \.self) { persona in
                                personaCard(persona)
                            }
                        }
                        
                        // Confirm button
                        Button {
                            HapticService.shared.actionButtonTap()
                            settings.selectedPersona = selectedPersona
                            if isOnboarding {
                                onComplete?()
                            } else {
                                dismiss()
                            }
                        } label: {
                            Text(isOnboarding ? String(localized: "Let's Go!") : String(localized: "Save"))
                                .font(AppTheme.body.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, DesignTokens.spacingSM)
                                .background(Capsule().fill(DesignTokens.accentActive))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, DesignTokens.spacingXL)
                        .padding(.top, DesignTokens.spacingSM)
                        
                        // Note
                        Text(String(localized: "You can change this anytime in the You tab."))
                            .font(AppTheme.caption)
                            .foregroundStyle(DesignTokens.textTertiary)
                        
                        Spacer(minLength: DesignTokens.spacingXXL)
                    }
                    .padding(.horizontal, DesignTokens.spacingLG)
                }
            }
            .navigationTitle(isOnboarding ? "" : String(localized: "Your Style"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isOnboarding {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "Cancel")) { dismiss() }
                            .foregroundStyle(DesignTokens.textSecondary)
                    }
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            selectedPersona = settings.selectedPersona
            withAnimation(.spring(response: 0.6)) {
                animateIn = true
            }
        }
    }
    
    // MARK: - Persona Card
    
    private func personaCard(_ persona: UserPersona) -> some View {
        let isSelected = selectedPersona == persona
        
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedPersona = persona
            }
            HapticService.shared.actionButtonTap()
        } label: {
            HStack(spacing: DesignTokens.spacingMD) {
                Image(systemName: persona.icon)
                    .font(.system(size: 24))
                    .foregroundStyle(isSelected ? Color(hex: persona.accentColorHex) : DesignTokens.textTertiary)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(persona.label)
                        .font(AppTheme.body.weight(.semibold))
                        .foregroundStyle(isSelected ? DesignTokens.textPrimary : DesignTokens.textSecondary)
                    
                    Text(persona.description)
                        .font(AppTheme.caption)
                        .foregroundStyle(DesignTokens.textTertiary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? Color(hex: persona.accentColorHex) : DesignTokens.textTertiary)
            }
            .padding(DesignTokens.spacingMD)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                        .fill(Color(hex: persona.accentColorHex).opacity(0.10))
                }
            }
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusCard))
        }
        .buttonStyle(.plain)
        .nudgeAccessibility(
            label: "\(persona.label) persona",
            hint: persona.description,
            traits: isSelected ? [.isButton, .isSelected] : .isButton
        )
    }
}
