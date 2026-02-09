# Nudgy — Rive Design Guide

> **Version:** 1.0  
> **Date:** February 8, 2026  
> **Status:** Ready for Rive design  
> **Purpose:** Complete specification for designing and animating Nudgy in the [Rive Editor](https://rive.app)  
> **For:** Designer / yourself in Rive — everything needed to create `nudgy.riv`

---

## 1. Project Setup in Rive

### Artboard
- **Name:** `Nudgy`
- **Size:** 400 × 460 px (fits the 1:1.15 aspect ratio used in-app)
- **Background:** Transparent (the app provides its own OLED black canvas)

### State Machine
- **Name:** `NudgyStateMachine`
- **Inputs:**
  | Name | Type | Default | Description |
  |---|---|---|---|
  | `expression` | Number | `0` | Which expression state (0-11, see §4) |
  | `isBlinking` | Boolean | `false` | Toggles blink animation layer |
  | `isTalking` | Boolean | `false` | Toggles talking head-bob layer |
  | `accentHue` | Number | `0.58` | Hue value 0-1 for accent color (0.58 ≈ blue) |

- **Triggers:**
  | Name | Description |
  |---|---|
  | `tap` | Play a quick squish-bounce reaction |
  | `celebrate` | Play a confetti burst one-shot |
  | `wave` | Play a wave animation one-shot |

### Layer Structure (recommended)
```
Layer 0: feet
Layer 1: body (plumage + belly)
Layer 2: scarf
Layer 3: left_wing
Layer 4: right_wing
Layer 5: head
Layer 6: face_patch
Layer 7: left_eye
Layer 8: right_eye
Layer 9: beak
Layer 10: blush_left
Layer 11: blush_right
Layer 12: eyebrows (optional, expression-dependent)
Layer 13: accessories (zzz, dots, sparkles)
```

---

## 2. Character Anatomy — Exact Proportions

All measurements are **fractions of artboard width (400px)**. The penguin is centered horizontally.

### Reference: The icon (generate_app_icon_v2.py) as canonical proportions

```
ARTBOARD CENTER = (200, 200)   ← all offsets relative to this

┌─────────────────────────────────────────┐
│                                         │
│         ┌─────────────────┐             │
│         │     HEAD        │  ← 242×224 px, center Y = 112
│         │   ◉        ◉    │     (0.605 × 0.56 of artboard)
│         │       ▾         │
│         │   ○          ○  │  ← blush spots
│         └─────────────────┘
│           ═══════════════   ← scarf: 240×40 px at Y=174
│         ┌─────────────────┐
│        ╱│                 │╲ ← wings: 40×88 px each
│         │     BODY        │    body: 352×384 px
│         │                 │    center Y = 232
│         │   ┌─────────┐   │
│         │   │  BELLY  │   │  ← belly: 240×304 px
│         │   │         │   │    center Y = 256
│         │   └─────────┘   │
│         └─────────────────┘
│            (   )  (   )     ← feet: 26×10 px each
│                                 at Y = 400
└─────────────────────────────────────────┘
```

### Exact Dimensions (in a 400px artboard)

| Part | Width (px) | Height (px) | Center X | Center Y | Notes |
|---|---|---|---|---|---|
| **Body** | 352 | 384 | 200 | 232 | Egg-shaped ellipse, slightly taller than wide |
| **Belly** | 240 | 304 | 200 | 256 | Inner white patch, same egg shape |
| **Head** | 242 | 224 | 200 | 112 | Ellipse, wider than it is tall (rx > ry) |
| **Face patch** | 160 | 136 | 200 | 128 | Lighter oval on face for eye area |
| **Left eye** | 34 | 34 | 162 | 116 | Circle — left eye slightly smaller |
| **Right eye** | 35 | 35 | 238 | 116 | Circle — right eye 5% larger (life!) |
| **Beak** | 34 | 28 | 200 | 150 | Small downward triangle with rounded corners |
| **Left blush** | 28 | 28 | 142 | 128 | Radial gradient pink → transparent |
| **Right blush** | 28 | 28 | 258 | 128 | Same |
| **Scarf** | 240 | 40 | 200 | 174 | Curved band wrapping neck junction |
| **Left wing** | 40 | 88 | 52 | 208 | Flipper shape, angled 15° outward |
| **Right wing** | 40 | 88 | 348 | 208 | Mirror of left |
| **Left foot** | 26 | 10 | 168 | 400 | Small capsule, rotated -8° |
| **Right foot** | 26 | 10 | 232 | 400 | Small capsule, rotated +8° |

### Key Proportional Rules
- **Head is LARGE** — it overlaps the body significantly (head bottom at ~224, body top at ~40). This is the chibi/kawaii look.
- **Head is wider than body edge-to-edge** — the head ellipse (242px) extends beyond the body width at the top.
- **Belly fills most of the body** — 240/352 = 68% of body width.
- **Wings are small and stubby** — only 40px wide, positioned at the body edges.
- **Scarf is thin** — only 40px tall (10% of artboard), NOT a bib.
- **Feet are tiny** — 26×10px, just little capsules at the bottom.

---

## 3. Color Palette

### Penguin Body
| Part | Hex | Opacity | Notes |
|---|---|---|---|
| Dark plumage (head, body outer, wings) | `#1A1A2E` | 100% | Deep navy-black, NOT pure black |
| Plumage highlight | `#2A2A42` | 100% | Gradient top / edge highlight |
| Plumage edge | `#343450` | 100% | Subtle 3rd tone for depth |
| Belly top | `#F5F5F7` | 100% | Warm white |
| Belly bottom | `#E8E8EC` | 100% | Subtle gradient shadow |
| Beak top | `#3399FF` | 100% | Lighter blue |
| Beak bottom | `#007AFF` | 100% | Accent blue |
| Feet | `#007AFF` | 70% | Same accent, semi-transparent |
| Scarf gradient start | `#007AFF` | 100% | Accent blue |
| Scarf gradient end | `#0055CC` | 100% | Darker blue |
| Scarf highlight stroke | `#3399FF` | 50% | Thin line along top edge |

### Face
| Part | Hex | Opacity | Notes |
|---|---|---|---|
| Face patch | `#2A2A42` | 100% | Lighter oval behind eyes |
| Eye whites | `#FFFFFF` | 100% | |
| Pupil / iris | `#0A0A0E` | 100% | Near-black |
| Eye shine (large) | `#FFFFFF` | 92% | Top-right of each eye |
| Eye shine (small) | `#FFFFFF` | 55% | Bottom-left of each eye |
| Cheek blush | `#FF6B8A` | 15-25% | Radial gradient, center=opaque, edge=transparent |

### Dynamic Accent Color
The scarf, beak, and feet can be tinted by the `accentHue` input:
- **Blue** (default, hue 0.58): `#007AFF` — active task
- **Green** (hue 0.37): `#30D158` — task done
- **Amber** (hue 0.10): `#FF9F0A` — stale item
- **Red** (hue 0.0): `#FF453A` — overdue

Use Rive's color binding to shift hue of scarf/beak/feet based on the `accentHue` number input. If not possible, just use the default blue.

---

## 4. Expression States (12 States)

The `expression` number input drives which state is active. **Body and head shape never change** — only eyes, wing angle, beak, accessories, and minor offset animations vary per expression.

### State 0: Idle (Default)
- **Eyes:** Fully open circles with white ring + black pupil + two shine spots
- **Wings:** Resting at sides, 15° outward
- **Beak:** Closed (small triangle, pointing down)
- **Ambient:** Gentle body sway ±2px over 3s (sine). Scarf counter-sways (secondary motion, 0.5s phase offset)
- **Blink layer** (separate timeline): Squish eyes to thin lines every 3.5s (±1.5s random). Close 0.08s → hold 0.06s → open 0.12s. 20% chance of double-blink.

### State 1: Happy
- **Eyes:** Crescent "smile eyes" — upward-curving arcs (no pupils visible)
- **Wings:** Raised to 30° outward
- **Body:** Quick spring bounce (0→-12px→0 over 0.6s)
- **Blush:** Intensity increases to 35%

### State 2: Thinking
- **Eyes:** Wide open, pupils shifted slightly up-right (looking at thought dots)
- **Wings:** Right wing raised to chin level
- **Body:** Slight lean left, still
- **Head tilt:** 12° left
- **Accessories:** 3 animated dots above top-right. Cycle dim→bright sequentially, 0.5s per dot.

### State 3: Sleeping
- **Eyes:** Closed — two gentle downward arcs with tiny lash marks at outer corners
- **Wings:** Tucked close to body (5° outward only)
- **Body:** No sway. Very subtle breathing: scale 1.0→1.012→1.0 over 4s
- **Head tilt:** 8° right (leaning into sleep)
- **Accessories:** "zzz" text floating upward from top-right, 3 z's at staggered heights, gentle upward drift, fading out.

### State 4: Celebrating
- **Eyes:** Crescent smile eyes (same as Happy)
- **Wings:** Raised HIGH — 60° outward ("hands up!")
- **Body:** Double bounce — two quick spring hops
- **Accessories:** 4+ small sparkle shapes radiating outward. Colors: blue, green, amber.

### State 5: Thumbs Up
- **Eyes:** Normal open, warm. Right eye winks (thin line) optionally.
- **Wings:** Right wing raised high with a tiny circle at tip (thumb). Left wing resting.
- **Body:** Slight forward lean
- **Head tilt:** 3° left
- **Accessories:** Small heart floats up from right wing area.

### State 6: Listening
- **Eyes:** Normal open, attentive. Subtle raised eyebrows (two thin capsules above eyes, rotated ±5°)
- **Wings:** Slightly forward (cupping pose)
- **Body:** Slight lean forward
- **Accessories:** None (the speech-to-text UI handles the mic visualization)

### State 7: Talking
- **Eyes:** Crescent smile eyes
- **Beak:** Slightly open (translate beak down 4px, or animate mouth shape)
- **Body:** Rhythmic head bob — 3 small rapid nods with decreasing amplitude, loop every 1.2s
- **Wings:** Gentle gesticulating — slight alternating raises

### State 8: Waving
- **Eyes:** Normal open, bright
- **Wings:** Right wing raised 80°+, waving back and forth (pendulum swing ±20° over 0.4s, 3 cycles)
- **Body:** Double bounce (same as celebrating)

### State 9: Nudging
- **Eyes:** Determined — normal open with stern eyebrows (angled inward)
- **Wings:** Right wing extended, pointing forward/right
- **Body:** Slight lean forward, assertive
- **Head tilt:** 0° (looking straight at user)
- **Accessories:** Could animate a tiny clock or exclamation mark

### State 10: Confused
- **Eyes:** Wide open, pupils shifted up-right (same as thinking)
- **Eyebrows:** Asymmetric — left raised, right lowered (creates "huh?" look)
- **Wings:** One raised (shrug gesture)
- **Head tilt:** 12° right (opposite of thinking)
- **Accessories:** "?" or sweat drop

### State 11: Typing
- **Eyes:** Focused — normal open, looking slightly downward
- **Wings:** Both extended forward (typing on invisible keyboard)
- **Body:** Slight rhythmic forward/back (pecking motion)

---

## 5. Animation Timings

### Idle Ambients (always running)
| Animation | Duration | Easing | Loop |
|---|---|---|---|
| Body sway | 3.0s per half-cycle | Ease in-out | Ping-pong forever |
| Scarf counter-sway | 3.0s, 0.5s phase offset | Ease in-out | Ping-pong forever |
| Blink | 3.5s interval (±1.5s random) | Eyes close 0.08s, hold 0.06s, open 0.12s | Loop |

### Expression Transitions
| Animation | Duration | Easing | Notes |
|---|---|---|---|
| Expression change | 0.3s | Spring (response 0.3, damping 0.7) | Cross-fade between states |
| Happy bounce | 0.6s | Spring (response 0.3, damping 0.5) | One shot |
| Celebrate double-bounce | 0.8s | Spring (response 0.25, damping 0.45) | One shot |
| Thinking dots cycle | 0.5s per dot | Ease out | Loop while in state |
| Sleep breathing | 4.0s | Ease in-out | Ping-pong |
| Talking head bob | 1.2s cycle | Spring (response 0.15, damping 0.6) | Loop while talking |
| Wave swing | 0.4s per swing, 3 swings | Spring | One shot |

### Trigger Animations
| Trigger | Duration | What Happens |
|---|---|---|
| `tap` | 0.4s | Squish scale to 92% → spring back to 100% |
| `celebrate` | 1.2s | Sparkle particles burst outward, fade |
| `wave` | 1.2s | Right wing pendulum 3x, body bounce |

---

## 6. Bezier Shape References

### Body Shape (egg/capsule)
An egg shape — wider at bottom, narrower at top. In Rive, use an ellipse and adjust bezier handles to create the egg taper.

### Head Shape
A wide ellipse (rx > ry). In Rive, this is just an ellipse with the horizontal radius ~8% wider than vertical radius.

### Wing Shape
A tapered flipper: wide at the shoulder, narrowing to a rounded tip. Use a path with ~4 control points:
- Top: wide attachment to body
- Middle: gradual taper
- Bottom: rounded narrow tip

### Beak Shape
A small downward-pointing rounded triangle. Symmetric. Use a path with 3 points + rounding.

### Scarf Shape
A slightly curved horizontal band that wraps around the head-body junction. Wider in the middle, tapers at the sides. Optional: one small tail end trailing to the right.

---

## 7. Export & Integration

### Export from Rive
1. File → Export → `.riv` format
2. Name the file `nudgy.riv`
3. Place it in: `Nudge/Nudge/Resources/nudgy.riv` (or directly in the `Nudge/Nudge/` folder since the project uses file system synchronization)

### In-App Integration (already done)
The code is ready in `RiveNudgyView.swift`:
- `RiveNudgyView` checks for `nudgy.riv` in the bundle at startup
- If found → renders via Rive runtime
- If not found → falls back to old bezier `PenguinMascot`
- `PenguinSceneView` already uses `RiveNudgyView`

### Testing
After placing `nudgy.riv` in the project:
```sh
cd Nudge
xcodebuild -scheme Nudge -destination 'generic/platform=iOS' -allowProvisioningUpdates build
xcrun devicectl device install app --device <UDID> "<DerivedData>/Build/Products/Debug-iphoneos/Nudge.app"
```

### Sizes in the App
| Context | Size (pt) | `RiveNudgyView` renders at |
|---|---|---|
| Main screen (hero) | 240 | 240 × 276 px |
| Onboarding / paywall | 120 | 120 × 138 px |
| Settings header | 80 | 80 × 92 px |
| Small / inline | 40 | 40 × 46 px |

All sizes use the same `.riv` file — Rive's `fit: .contain` handles scaling.

---

## 8. State Machine Wiring Diagram

```
┌─────────────────────────────────────┐
│         NudgyStateMachine           │
│                                     │
│  Inputs:                            │
│    expression (Number) ──────┐      │
│    isBlinking (Bool)    ──┐  │      │
│    isTalking (Bool)     ──┤  │      │
│    accentHue (Number)   ──┤  │      │
│                           │  │      │
│  Triggers:                │  │      │
│    tap ───────────────────┤  │      │
│    celebrate ─────────────┤  │      │
│    wave ──────────────────┘  │      │
│                              │      │
│  State Machine Layers:       │      │
│                              │      │
│  Layer 1: Expression ◄───────┘      │
│    States: idle, happy, thinking,   │
│    sleeping, celebrating, thumbsUp, │
│    listening, talking, waving,      │
│    nudging, confused, typing        │
│    Transitions: expression == N     │
│                                     │
│  Layer 2: Blink ◄── isBlinking      │
│    States: eyes_open, eyes_closed   │
│    (runs independently of expr)     │
│                                     │
│  Layer 3: Reactions ◄── triggers    │
│    States: none, tap_bounce,        │
│    confetti_burst, wave_motion      │
│                                     │
└─────────────────────────────────────┘
```

---

## 9. Quick Start Checklist

- [ ] Create new Rive file, artboard 400×460, transparent BG
- [ ] Draw body shapes: body ellipse, belly ellipse, head ellipse, face patch
- [ ] Add eyes (circles with nested shine spots)
- [ ] Add beak (rounded triangle path)
- [ ] Add scarf (curved band, gradient fill)
- [ ] Add wings (flipper paths, mirrored)
- [ ] Add feet (small capsules)
- [ ] Add blush spots (radial gradient circles)
- [ ] Create state machine `NudgyStateMachine`
- [ ] Add `expression` number input
- [ ] Create expression states (start with idle, happy, thinking, sleeping)
- [ ] Add blink animation on separate layer
- [ ] Add idle sway ambient animation
- [ ] Add `tap` trigger with bounce reaction
- [ ] Test all states with input changes
- [ ] Export as `nudgy.riv`
- [ ] Drop into `Nudge/Nudge/` folder
- [ ] Build and run — character should appear!

---

## 10. Rive Editor Tips

1. **Use bones** for wing rotation — set origin at shoulder joint, then rotate
2. **Use constraints** for eye tracking — pupils can follow a control point
3. **State machine transitions** should use `expression == 0` (equals) conditions, not ranges
4. **Blink should be on a separate layer** so it works independently of expression state
5. **Use Rive's timeline blending** — idle sway can blend on top of expression changes
6. **Test at 40px** — if any detail disappears, simplify. The character needs to read at widget size.
7. **Keep the silhouette identical to the app icon** — this is the #1 rule

---

*This guide + `nudge-penguin-spec.md` together are the complete character bible. The icon generator (`generate_app_icon_v2.py`) remains the proportion source of truth.*
