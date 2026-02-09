//
//  DynamicTypeModifiers.swift
//  Nudge
//
//  Created by Abdullah Imran on 2/7/26.
//

import SwiftUI

// MARK: - Scaled Padding

/// Adapts padding to Dynamic Type size — larger text gets more breathing room.
struct ScaledPadding: ViewModifier {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    let edges: Edge.Set
    let basePadding: CGFloat
    
    func body(content: Content) -> some View {
        content.padding(edges, scaledValue)
    }
    
    private var scaledValue: CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small:
            return basePadding * 0.85
        case .medium:
            return basePadding
        case .large:
            return basePadding * 1.05
        case .xLarge:
            return basePadding * 1.1
        case .xxLarge:
            return basePadding * 1.15
        case .xxxLarge:
            return basePadding * 1.2
        case .accessibility1, .accessibility2, .accessibility3,
                .accessibility4, .accessibility5:
            return basePadding * 1.3
        @unknown default:
            return basePadding
        }
    }
}

// MARK: - Scaled Size

/// Adapts a fixed size value to Dynamic Type — prevents clipping at large sizes.
struct ScaledSize: ViewModifier {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    let baseWidth: CGFloat?
    let baseHeight: CGFloat?
    
    func body(content: Content) -> some View {
        content.frame(
            width: baseWidth.map { $0 * scaleFactor },
            height: baseHeight.map { $0 * scaleFactor }
        )
    }
    
    private var scaleFactor: CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small:
            return 0.9
        case .medium:
            return 1.0
        case .large:
            return 1.05
        case .xLarge:
            return 1.15
        case .xxLarge:
            return 1.25
        case .xxxLarge:
            return 1.35
        case .accessibility1, .accessibility2, .accessibility3,
                .accessibility4, .accessibility5:
            return 1.5
        @unknown default:
            return 1.0
        }
    }
}

// MARK: - View Extensions

extension View {
    /// Padding that scales with Dynamic Type
    func scaledPadding(_ edges: Edge.Set = .all, _ base: CGFloat = DesignTokens.spacingLG) -> some View {
        modifier(ScaledPadding(edges: edges, basePadding: base))
    }
    
    /// Frame size that scales with Dynamic Type
    func scaledFrame(width: CGFloat? = nil, height: CGFloat? = nil) -> some View {
        modifier(ScaledSize(baseWidth: width, baseHeight: height))
    }
}
