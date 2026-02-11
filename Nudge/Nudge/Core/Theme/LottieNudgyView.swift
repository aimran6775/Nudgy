//
//  LottieNudgyView.swift
//  Nudge
//
//  Legacy compatibility wrapper — forwards to NudgySprite which renders
//  the custom PenguinMascot (bezier character) with accessory overlays.
//
//  All new call sites should use NudgySprite or PenguinSceneView directly.
//  This file exists only so stale references keep compiling.
//

import SwiftUI

// MARK: - Legacy Alias

/// Thin wrapper that forwards to NudgySprite.
/// New code should use `NudgySprite` or `PenguinSceneView` directly.
struct LottieNudgyView: View {
    let expression: PenguinExpression
    let size: CGFloat
    var accentColor: Color = DesignTokens.accentActive
    
    var body: some View {
        NudgySprite(
            expression: expression,
            size: size,
            accentColor: accentColor
        )
    }
}

// MARK: - Color Extension for Hue Extraction

extension Color {
    /// Extract the hue component (0.0-1.0) from a SwiftUI Color.
    var hueComponent: Float {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        UIColor(self).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return Float(hue)
    }
}
