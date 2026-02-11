//
//  TabBarNudgyChomp.swift
//  Nudge
//
//  Option A — Tab bar Nudgy chomp animation.
//  A tiny penguin head pops up above the Nudgy tab when a task is completed on the Nudges tab,
//  chomps a fish, then dips back down with a happy expression.
//

import SwiftUI

struct TabBarNudgyChomp: View {
    
    @Binding var isActive: Bool
    var species: FishSpecies?
    
    // Animation state
    @State private var peekOffset: CGFloat = 50
    @State private var mouthOpen = false
    @State private var fishVisible = true
    @State private var fishOffset: CGFloat = -40
    @State private var showHeart = false
    @State private var heartOffset: CGFloat = 0
    @State private var heartOpacity: Double = 0
    @State private var bounce: CGFloat = 0
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    private let headSize: CGFloat = 36
    
    var body: some View {
        if isActive {
            ZStack {
                // Mini Nudgy head
                ZStack {
                    // Head
                    Ellipse()
                        .fill(Color(hex: "2C2C3A"))
                        .frame(width: headSize, height: headSize * 0.85)
                    
                    // White belly patch
                    Ellipse()
                        .fill(.white.opacity(0.9))
                        .frame(width: headSize * 0.6, height: headSize * 0.5)
                        .offset(y: headSize * 0.08)
                    
                    // Eyes
                    HStack(spacing: headSize * 0.18) {
                        Circle().fill(.white)
                            .frame(width: 5, height: 5)
                            .overlay(
                                Circle().fill(.black)
                                    .frame(width: 3, height: 3)
                            )
                        Circle().fill(.white)
                            .frame(width: 5, height: 5)
                            .overlay(
                                Circle().fill(.black)
                                    .frame(width: 3, height: 3)
                            )
                    }
                    .offset(y: -headSize * 0.08)
                    
                    // Beak / mouth
                    if mouthOpen {
                        Ellipse()
                            .fill(Color.orange.opacity(0.9))
                            .frame(width: 8, height: 6)
                            .offset(y: headSize * 0.18)
                    } else {
                        SmallBeak()
                            .fill(Color.orange)
                            .frame(width: 7, height: 4)
                            .offset(y: headSize * 0.18)
                    }
                }
                .offset(y: peekOffset + bounce)
                
                // Flying fish
                if fishVisible, let species {
                    FishView(
                        size: 12,
                        color: species.fishColor,
                        accentColor: species.fishAccentColor
                    )
                    .offset(x: fishOffset, y: peekOffset - 5)
                    .transition(.opacity)
                }
                
                // Heart
                if showHeart {
                    Text("❤️")
                        .font(.system(size: 10))
                        .offset(x: 14, y: peekOffset - 18 + heartOffset)
                        .opacity(heartOpacity)
                }
            }
            .frame(width: 50, height: 60)
            .onAppear { runAnimation() }
        }
    }
    
    private func runAnimation() {
        guard !reduceMotion else {
            // Simplified: quick bounce and done
            withAnimation(.spring(response: 0.3)) { peekOffset = 5 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.spring(response: 0.3)) { peekOffset = 50 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { isActive = false }
            }
            return
        }
        
        // Step 1: Peek up (0.0s)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            peekOffset = 5
        }
        
        // Step 2: Open mouth (0.3s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.1)) { mouthOpen = true }
        }
        
        // Step 3: Fish flies in (0.4s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeIn(duration: 0.2)) { fishOffset = 0 }
        }
        
        // Step 4: Chomp — fish gone, mouth closes (0.6s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
            withAnimation(.easeOut(duration: 0.08)) {
                fishVisible = false
                mouthOpen = false
            }
            HapticService.shared.actionButtonTap()
        }
        
        // Step 5: Happy bounce (0.75s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.4)) {
                bounce = -6
            }
            // Heart float
            showHeart = true
            withAnimation(.easeOut(duration: 0.5)) {
                heartOpacity = 1
                heartOffset = -12
            }
        }
        
        // Step 6: Settle (1.0s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.spring(response: 0.25)) { bounce = 0 }
            withAnimation(.easeOut(duration: 0.3)) {
                heartOpacity = 0
            }
        }
        
        // Step 7: Dip back down (1.4s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                peekOffset = 50
            }
        }
        
        // Step 8: Cleanup (1.8s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            isActive = false
        }
    }
}

// MARK: - Small Beak Shape

private struct SmallBeak: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: 0, y: 0))
            p.addLine(to: CGPoint(x: rect.width, y: 0))
            p.addLine(to: CGPoint(x: rect.width / 2, y: rect.height))
            p.closeSubpath()
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack {
            Spacer()
            TabBarNudgyChomp(isActive: .constant(true), species: .tropical)
        }
    }
}
