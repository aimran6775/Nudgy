# Nudge Penguin — Character & Logo Specification

> **Version:** 1.0  
> **Date:** February 7, 2026  
> **Status:** Active — source of truth for all penguin rendering  
> **Applies to:** App icon, in-app `PenguinMascot.swift`, onboarding, empty states, notifications

---

## 1. Character Identity

**Name:** Nudge (the penguin)  
**Species:** Emperor penguin (stylized)  
**Personality:** Warm, slightly goofy, quietly encouraging. Like a supportive friend who taps your shoulder, not a drill sergeant. Nudge doesn't judge your procrastination — it just shows up again, patiently.

**Tagline energy:** "Doing your best, one waddle at a time."

---

## 2. Design Proportions (Chibi/Kawaii Ratio)

The penguin uses an oversized-head character ratio for maximum cuteness and recognizability at small sizes.

```
┌─────────────────────┐
│                     │
│    ┌───────────┐    │  ← Head: 45% of total height
│    │  ◉    ◉   │    │     Slightly tilted 5° right
│    │     ▾     │    │     Round, wider than body
│    └───────────┘    │
│     ╔═══════╗       │  ← Scarf: wraps head-body junction
│     ║ BODY  ║       │     One tail trails to the right
│    ╱║       ║╲      │  ← Wings: stubby, slightly raised
│     ║       ║       │     Body: 45% of total height
│     ╚═══════╝       │     Compact, egg-shaped
│      (  ) (  )      │  ← Feet: 10% of total height
│                     │     Small rounded ovals
└─────────────────────┘
```

| Part | % of Height | Ratio Detail |
|---|---|---|
| Head | 45% | Circular, 110% of body width. Slight right tilt (5°) |
| Body | 45% | Egg-shaped (wider at bottom). Smooth curve from head — NO neck |
| Feet | 10% | Two small rounded ovals, slightly splayed |
| Eyes | 30% of head width | Large, round, expressive. Right eye 5% larger (asymmetry = life) |
| Beak | 8% of head height | Small downward triangle, accent blue |
| Wings | 25% of body height | Stubby flippers, angled 15° outward from body |
| Scarf | 8% of total height | Wraps junction, one tail curves right |

---

## 3. Color Palette

### Penguin Body Colors
| Part | Hex | RGB | Notes |
|---|---|---|---|
| **Dark plumage** (head, back, wings) | `#1A1A2E` | (26, 26, 46) | Deep navy-black, NOT pure black (depth) |
| **Dark plumage highlight** | `#2A2A42` | (42, 42, 66) | Edge highlight, gradient top |
| **Belly** | `#F5F5F7` | (245, 245, 247) | Warm white, slight cream |
| **Belly gradient bottom** | `#E8E8EC` | (232, 232, 236) | Subtle shadow at belly base |
| **Beak** | `#007AFF` | (0, 122, 255) | Accent blue — the signature color |
| **Feet** | `#007AFF` at 70% | — | Same accent, slightly transparent |
| **Eye whites** | `#FFFFFF` | (255, 255, 255) | Pure white for contrast |
| **Iris/pupil** | `#0A0A0E` | (10, 10, 14) | Near-black |
| **Eye shine** | `#FFFFFF` at 90% | — | Two spots: large top-right, small bottom-left |
| **Scarf** | `#007AFF` → `#0055CC` | — | Linear gradient, left-to-right |
| **Scarf highlight** | `#3399FF` at 40% | — | Thin line along top edge |
| **Cheek blush** | `#FF6B8A` at 15% | — | Very subtle pink circles on cheeks |

### Background Colors (Icon Only)
| Variant | Background | Glow |
|---|---|---|
| **Light** (default) | `#111116` dark charcoal | Blue radial glow, 40% intensity |
| **Dark** | `#000000` pure black | Blue radial glow, 30% intensity |
| **Tinted** | Transparent | No glow — solid silhouette only |

---

## 4. Expression States (6 States)

Each expression changes **eyes + wings + accessories** only. Body and head shape stay constant for recognition consistency.

### 4.1 Idle (Default)
- **Eyes:** Fully open, relaxed. Slow blink every 3.5s (close → 0.08s hold → open)
- **Wings:** Resting at sides, angled 15° out
- **Body:** Gentle lateral sway ±2pt over 3s (sine wave)
- **Head tilt:** 5° right (resting position)
- **Accessories:** Scarf sways opposite to body (secondary motion)

### 4.2 Happy (Task Completed)
- **Eyes:** Crescent/squint "smile eyes" — two upward-curving arcs
- **Wings:** Raised 30° outward (mini celebration)
- **Body:** Quick bounce: 0→-12pt→0 over 0.6s (spring, overshoot)
- **Head tilt:** Straightens to 0° then back to 5°
- **Accessories:** Sparkle particles around head (3-4 small stars)

### 4.3 Thinking (Processing Brain Dump)
- **Eyes:** Wide open, slightly upward gaze (looking at thought bubble)
- **Wings:** One wing (right) raised to chin level
- **Body:** Still, slight lean left
- **Head tilt:** 12° left (curious head cock)
- **Accessories:** Three animated dots in thought bubble position (top-right). Cycle: dim→bright sequentially, 0.5s per dot

### 4.4 Sleeping (Empty State — All Done)
- **Eyes:** Closed — two gentle downward arcs with tiny lash marks
- **Wings:** Tucked close to body
- **Body:** No sway. Very slight breathing: scale 1.0→1.01→1.0 over 4s
- **Head tilt:** 8° right (leaning into sleep)
- **Accessories:** "zzz" floating upward from top-right, fading out. Three z's at staggered heights, gentle upward drift

### 4.5 Celebrating (All Clear — Zero Tasks)
- **Eyes:** Crescent smile eyes (same as happy)
- **Wings:** Raised high, 60° outward ("hands up!")
- **Body:** Double bounce: two spring hops in sequence
- **Head tilt:** Slight wobble left-right-center
- **Accessories:** Confetti particles — 8-12 small colored dots radiating outward from center. Colors: accent blue, green, amber

### 4.6 Thumbs Up (Share Saved)
- **Eyes:** Normal open, warm
- **Wings:** Right wing raised high with "thumb" extended (tiny circle at wing tip). Left wing resting
- **Body:** Slight forward lean (engaging)
- **Head tilt:** 3° left (nodding energy)
- **Accessories:** Small checkmark or heart floats up from right wing

---

## 5. Rendering Rules

### 5.1 App Icon (Static)
- Expression: **Idle** (neutral, inviting)
- Render at **4x** (4096×4096) then downsample to 1024×1024 for maximum anti-aliasing
- Penguin fills **70%** of icon area, centered, slightly above vertical center
- Subtle blue radial glow behind penguin (creates depth, separates from bg)
- Drop shadow: 4px blur, 2px Y offset, black at 30%
- **No rounded corners** — iOS applies the superellipse mask automatically

### 5.2 In-App Mascot (Animated)  
- Rendered via SwiftUI `Path` bezier curves (not `Shape` primitives)
- Three sizes: `large` (120pt), `medium` (60pt), `small` (40pt)  
- Accent color flows through beak, feet, scarf via `accentColor` parameter
- All animations respect `@Environment(\.accessibilityReduceMotion)`
- Reduce Motion fallback: cross-fade expressions, no positional animation

### 5.3 Consistency Contract
The icon and in-app mascot **must** be visually identical in silhouette. Same bezier curves define both. If one changes, both change.

---

## 6. Animation Specifications

### Timing (Maps to `AnimationConstants`)

| Animation | Duration | Easing | Spring Params |
|---|---|---|---|
| **Blink** (close) | 0.08s | `.easeOut` | — |
| **Blink** (hold) | 0.06s | — | — |
| **Blink** (open) | 0.12s | `.easeOut` | — |
| **Blink interval** | 3.5s | — | Random ±0.5s |
| **Body sway** | 3.0s per cycle | `.easeInOut` | Repeats forever |
| **Happy bounce** | 0.6s total | — | `response: 0.3, damping: 0.5` |
| **Thinking dots** | 0.5s per dot | `.easeOut` | Sequential cycle |
| **Sleep breathing** | 4.0s per cycle | `.easeInOut` | Repeats forever |
| **Celebrate bounce** | 0.8s total | — | `response: 0.25, damping: 0.45` |
| **Expression transition** | 0.3s | `.spring` | `response: 0.3, damping: 0.7` |
| **Scarf secondary sway** | 3.0s | `.easeInOut` | Phase offset from body: -0.5s |

### Particle Systems

| Effect | Count | Spread | Lifetime | Colors |
|---|---|---|---|---|
| **Happy sparkles** | 3-4 | 40pt radius from head | 0.8s | Accent blue |
| **Celebrate confetti** | 8-12 | 80pt radius from center | 1.2s | Blue, green, amber |
| **Thumbs up heart** | 1 | Floats 30pt upward | 0.6s | Accent blue |
| **Sleep zzz** | 3 | Staggered 20pt apart vertical | 2.0s cycle | `textTertiary` |

---

## 7. Size Reference

| Context | Size (pt) | Detail Level |
|---|---|---|
| App icon (home screen) | 60×60 @3x | Full detail |
| App icon (Spotlight) | 40×40 @3x | Full detail |
| App icon (Settings) | 29×29 @3x | Simplified — no blush, thicker outlines |
| In-app large | 120pt | Full detail + animations |
| In-app medium | 60pt | Full detail + animations |
| In-app small | 40pt | Simplified — no blush, no scarf tail |
| Notification | 40pt | Static idle only |
| Widget | 44pt | Static idle, accent-tinted |

---

## 8. What The Penguin is NOT

- ❌ **Not realistic** — no feather texture, no realistic shading
- ❌ **Not angular/sharp** — all curves, no pointed edges except beak tip
- ❌ **Not a copy** of Pesto, Tux, Pudgy Penguins, or any existing penguin character
- ❌ **Not gendered** — universal, no accessories that imply gender
- ❌ **Not scary** — always approachable, never angry or threatening
- ❌ **Not detailed** — clean vector shapes, visible at 29pt. If it needs zoom to appreciate, it's too complex
