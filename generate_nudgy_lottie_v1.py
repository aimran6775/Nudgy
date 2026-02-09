"""
Nudgy Lottie Animation Generator
=================================
Generates a comprehensive Lottie JSON animation file for the Nudgy penguin mascot.
All proportions match the app icon (generate_app_icon_v2.py) exactly.

Features:
  - Full character with 13+ layers (feet, body, belly, wings, scarf, head, face, eyes, beak, blush)
  - Idle sway animation (body rocks ±2px over 3s)
  - Eye blinking (every 3.5s — squish closed and open)
  - Smooth looping at 30fps

The JSON follows the Bodymovin/Lottie specification.
See: https://lottiefiles.github.io/lottie-docs/

Usage:
    python3 generate_nudgy_lottie.py
    → outputs Nudge/Nudge/Resources/nudgy_idle.json
"""

import json
import math
import os

# ---- Canvas & Timing ----
W = 400
H = 460
FPS = 30
DURATION_SECONDS = 7  # full loop cycle (LCM of sway 3s + blink ~3.5s)
TOTAL_FRAMES = FPS * DURATION_SECONDS  # 210 frames

# ---- Penguin geometry (matching icon generator exactly) ----
CX = W / 2       # 200
CY = H / 2 + 10  # 240
PSIZE = 340       # reference size

def p(fraction):
    return fraction * PSIZE

# ---- Colors (RGBA 0-1) ----
def hex_to_rgb01(h):
    h = h.lstrip('#')
    return [int(h[i:i+2], 16)/255.0 for i in (0, 2, 4)]

PLUMAGE_DARK = hex_to_rgb01("1A1A2E")
PLUMAGE_HIGHLIGHT = hex_to_rgb01("2A2A42")
PLUMAGE_EDGE = hex_to_rgb01("343450")
BELLY_TOP = hex_to_rgb01("F5F5F7")
BELLY_BOTTOM = hex_to_rgb01("E8E8EC")
ACCENT_BLUE = hex_to_rgb01("007AFF")
ACCENT_BLUE_DARK = hex_to_rgb01("0055CC")
ACCENT_BLUE_LIGHT = hex_to_rgb01("3399FF")
EYE_BLACK = hex_to_rgb01("0A0A0E")
EYE_WHITE = hex_to_rgb01("FFFFFF")
BLUSH_PINK = hex_to_rgb01("FF6B8A")
FACE_PATCH = hex_to_rgb01("FFFFFF")

# ---- Bezier helpers ----
KAPPA = 0.5522848  # bezier approximation of quarter circle

def ellipse_bezier_path(cx, cy, rx, ry):
    """Generate Lottie bezier vertices for an ellipse."""
    # 4 anchor points with in/out tangent handles
    # Top, Right, Bottom, Left
    vertices = [
        [cx, cy - ry],      # top
        [cx + rx, cy],      # right
        [cx, cy + ry],      # bottom
        [cx - rx, cy],      # left
    ]
    in_tangents = [
        [-rx * KAPPA, 0],   # top: in from right
        [0, -ry * KAPPA],   # right: in from top
        [rx * KAPPA, 0],    # bottom: in from left
        [0, ry * KAPPA],    # left: in from bottom
    ]
    out_tangents = [
        [rx * KAPPA, 0],    # top: out to right
        [0, ry * KAPPA],    # right: out to bottom
        [-rx * KAPPA, 0],   # bottom: out to left
        [0, -ry * KAPPA],   # left: out to top
    ]
    return {"c": True, "v": vertices, "i": in_tangents, "o": out_tangents}


def egg_shape_path(cx, cy, body_w, body_h):
    """Egg/pear shape — wider at bottom, narrower at top. Matches icon generator."""
    body_cy = cy
    top_y = body_cy - body_h * 0.85
    
    # 7 points defining the egg shape (top → right-upper → right-lower → bottom → left-lower → left-upper → back to top)
    vertices = [
        [cx, top_y],                                    # 0: top center
        [cx + body_w * 0.95, body_cy - body_h * 0.1],  # 1: right upper
        [cx + body_w * 0.75, body_cy + body_h * 0.7],  # 2: right lower
        [cx, body_cy + body_h * 0.95],                  # 3: bottom center
        [cx - body_w * 0.75, body_cy + body_h * 0.7],  # 4: left lower
        [cx - body_w * 0.95, body_cy - body_h * 0.1],  # 5: left upper
    ]
    
    # Tangent handles for smooth curves
    in_tangents = [
        [-body_w * 0.45, 0],
        [0, -body_h * 0.45],
        [body_w * 0.25, body_h * 0.15],
        [body_w * 0.4, 0],
        [-body_w * 0.25, body_h * 0.15],
        [0, body_h * 0.45],
    ]
    out_tangents = [
        [body_w * 0.45, 0],
        [0, body_h * 0.45],
        [-body_w * 0.25, body_h * 0.15],
        [-body_w * 0.4, 0],
        [body_w * 0.25, body_h * 0.15],
        [0, -body_h * 0.45],
    ]
    
    return {"c": True, "v": vertices, "i": in_tangents, "o": out_tangents}


def rounded_triangle_path(cx, cy, w, h):
    """Small downward-pointing rounded triangle for beak."""
    vertices = [
        [cx, cy + h],                   # bottom point
        [cx - w * 0.8, cy - h * 0.5],   # top left
        [cx + w * 0.8, cy - h * 0.5],   # top right
    ]
    in_tangents = [
        [w * 0.3, -h * 0.3],
        [0, h * 0.3],
        [w * 0.3, 0],
    ]
    out_tangents = [
        [-w * 0.3, -h * 0.3],
        [-w * 0.3, 0],
        [0, h * 0.3],
    ]
    return {"c": True, "v": vertices, "i": in_tangents, "o": out_tangents}


def wing_path(cx, cy, side, wing_w, wing_h, angle_deg=15):
    """Flipper wing shape. side: -1=left, 1=right."""
    # Define flipper in local coords, then rotate
    wing_x = cx + side * p(0.37)
    wy = cy + p(0.02)
    oy = wy - wing_h * 0.4
    
    rad = math.radians(side * angle_deg)
    cos_a = math.cos(rad)
    sin_a = math.sin(rad)
    
    def rot(x, y):
        rx = x * cos_a - y * sin_a + wing_x
        ry = x * sin_a + y * cos_a + oy
        return [rx, ry]
    
    def rot_t(x, y):
        """Rotate tangent vector only."""
        rx = x * cos_a - y * sin_a
        ry = x * sin_a + y * cos_a
        return [rx, ry]
    
    # Simplified 4-point flipper
    p0 = rot(0, -wing_h * 0.5)                  # shoulder (top)
    p1 = rot(side * wing_w * 0.9, 0)             # widest point
    p2 = rot(side * wing_w * 0.4, wing_h * 0.5)  # tip
    p3 = rot(-side * wing_w * 0.1, 0)            # inner edge
    
    vertices = [p0, p1, p2, p3]
    
    # Smooth tangents
    in_tangents = [
        rot_t(-side * wing_w * 0.2, -wing_h * 0.1),
        rot_t(0, -wing_h * 0.25),
        rot_t(side * wing_w * 0.3, 0),
        rot_t(0, wing_h * 0.2),
    ]
    out_tangents = [
        rot_t(side * wing_w * 0.3, 0),
        rot_t(0, wing_h * 0.25),
        rot_t(-side * wing_w * 0.2, 0),
        rot_t(0, -wing_h * 0.2),
    ]
    
    return {"c": True, "v": vertices, "i": in_tangents, "o": out_tangents}


def scarf_path(cx, cy):
    """Scarf with trailing tail."""
    scarf_y = cy - p(0.065)
    sh = p(0.035)
    sw = p(0.30)
    
    vertices = [
        [cx - sw, scarf_y - sh],          # 0: left start
        [cx, scarf_y - sh * 1.8],         # 1: top center (arched)
        [cx + sw, scarf_y - sh],          # 2: right end
        [cx + sw * 0.5, scarf_y + sh * 2],# 3: right side drape
        [cx + sw * 0.65, scarf_y + sh * 5],# 4: tail end
        [cx + sw * 0.25, scarf_y + sh * 3],# 5: tail inner
        [cx - sw * 0.3, scarf_y + sh * 2],# 6: bottom left
    ]
    in_tangents = [
        [0, sh * 0.5],
        [-sw * 0.4, 0],
        [sw * 0.4, 0],
        [sw * 0.15, -sh * 1.5],
        [sw * 0.1, -sh * 1.0],
        [sw * 0.1, sh * 0.8],
        [-sw * 0.3, sh * 0.3],
    ]
    out_tangents = [
        [0, -sh * 0.5],
        [sw * 0.4, 0],
        [sw * 0.05, sh * 1.0],
        [sw * 0.1, sh * 1.2],
        [-sw * 0.15, sh * 0.8],
        [-sw * 0.15, -sh * 1.0],
        [-sw * 0.4, -sh * 0.3],
    ]
    return {"c": True, "v": vertices, "i": in_tangents, "o": out_tangents}


# ---- Lottie layer constructors ----

def make_shape_layer(name, shapes, transform=None):
    """Create a Lottie shape layer."""
    layer = {
        "ty": 4,  # shape layer
        "nm": name,
        "mn": name,
        "sr": 1,
        "ks": transform or default_transform(),
        "ao": 0,
        "shapes": shapes,
        "ip": 0,
        "op": TOTAL_FRAMES,
        "st": 0,
        "bm": 0,
    }
    return layer


def default_transform():
    """Default identity transform."""
    return {
        "o": {"a": 0, "k": 100},   # opacity
        "r": {"a": 0, "k": 0},     # rotation
        "p": {"a": 0, "k": [W/2, H/2, 0]},  # position at center
        "a": {"a": 0, "k": [W/2, H/2, 0]},  # anchor at center
        "s": {"a": 0, "k": [100, 100, 100]}, # scale
    }


def make_group(name, items):
    """Wrap items in a shape group."""
    return {
        "ty": "gr",
        "nm": name,
        "it": items + [group_transform()],
    }


def group_transform():
    """Default group transform."""
    return {
        "ty": "tr",
        "p": {"a": 0, "k": [0, 0]},
        "a": {"a": 0, "k": [0, 0]},
        "s": {"a": 0, "k": [100, 100]},
        "r": {"a": 0, "k": 0},
        "o": {"a": 0, "k": 100},
    }


def make_path(shape_data, name="Path"):
    """Create a Lottie shape path."""
    return {
        "ty": "sh",
        "nm": name,
        "d": 1,
        "ks": {"a": 0, "k": shape_data},
    }


def make_fill(color, opacity=100):
    """Create a solid fill."""
    return {
        "ty": "fl",
        "nm": "Fill",
        "c": {"a": 0, "k": color + [1]},
        "o": {"a": 0, "k": opacity},
        "r": 1,
    }


def make_gradient_fill(start, end, colors, opacity=100):
    """Create a linear gradient fill.
    colors: list of (offset, [r, g, b]) tuples
    """
    num_stops = len(colors)
    
    return {
        "ty": "gf",
        "nm": "Gradient Fill",
        "o": {"a": 0, "k": opacity},
        "r": 1,
        "s": {"a": 0, "k": start},
        "e": {"a": 0, "k": end},
        "t": 1,  # linear
        "g": {
            "p": num_stops,
            "k": {"a": 0, "k": _build_gradient_stops(colors)},
        },
    }


def _build_gradient_stops(color_list):
    """Build gradient color stop array: [offset, r, g, b, offset, r, g, b, ...]
    color_list: list of (offset, [r, g, b]) tuples
    """
    result = []
    for offset, color in color_list:
        result.extend([offset] + color)
    return result


def make_stroke(color, width, opacity=100):
    """Create a stroke."""
    return {
        "ty": "st",
        "nm": "Stroke",
        "c": {"a": 0, "k": color + [1]},
        "o": {"a": 0, "k": opacity},
        "w": {"a": 0, "k": width},
        "lc": 2,  # round cap
        "lj": 2,  # round join
    }


def make_ellipse(cx, cy, rx, ry, name="Ellipse"):
    """Create an ellipse shape."""
    return {
        "ty": "el",
        "nm": name,
        "p": {"a": 0, "k": [cx, cy]},
        "s": {"a": 0, "k": [rx * 2, ry * 2]},
    }


# ---- Animation keyframe helpers ----

def keyframe_ease(t, val, ease_in=None, ease_out=None):
    """Single keyframe with optional easing."""
    kf = {"t": t, "s": val if isinstance(val, list) else [val]}
    if ease_in and ease_out:
        kf["i"] = ease_in
        kf["o"] = ease_out
    return kf


def smooth_ease():
    """Standard smooth ease in/out handles."""
    return (
        {"x": [0.42], "y": [1]},   # ease in
        {"x": [0.58], "y": [0]},   # ease out
    )


def sway_keyframes(axis, amplitude, frames_per_half_cycle):
    """Generate ping-pong sway keyframes for the full animation."""
    keyframes = []
    ei, eo = smooth_ease()
    t = 0
    direction = 1
    while t <= TOTAL_FRAMES:
        val = [0, 0] if axis == 'x' else [0, 0]
        if axis == 'x':
            val = [amplitude * direction, 0]
        else:
            val = [0, amplitude * direction]
        
        kf = {"t": t, "s": val, "i": ei, "o": eo}
        keyframes.append(kf)
        t += frames_per_half_cycle
        direction *= -1
    
    # Final keyframe (hold)
    keyframes.append({"t": TOTAL_FRAMES, "s": [0, 0]})
    return keyframes


# ---- Build the character layers ----

def build_feet_layer():
    """Two small blue ellipse feet."""
    body_bottom = CY + p(0.50)
    foot_w = p(0.065)
    foot_h = p(0.025)
    foot_spacing = p(0.08)
    
    left_foot = make_group("Left Foot", [
        make_ellipse(CX - foot_spacing, body_bottom, foot_w, foot_h),
        make_fill(ACCENT_BLUE, opacity=70),
    ])
    right_foot = make_group("Right Foot", [
        make_ellipse(CX + foot_spacing, body_bottom, foot_w, foot_h),
        make_fill(ACCENT_BLUE, opacity=70),
    ])
    
    return make_shape_layer("Feet", [left_foot, right_foot])


def build_body_layer():
    """Dark plumage egg-shaped body."""
    body_w = p(0.44)
    body_h = p(0.48)
    body_cy = CY + p(0.08)
    
    path = egg_shape_path(CX, body_cy, body_w, body_h)
    
    body_group = make_group("Body", [
        make_path(path, "Body Shape"),
        make_gradient_fill(
            [CX - body_w, body_cy], [CX + body_w, body_cy],
            [(0.0, PLUMAGE_EDGE), (0.15, PLUMAGE_DARK), (0.85, PLUMAGE_DARK), (1.0, PLUMAGE_EDGE)]
        ),
    ])
    
    return make_shape_layer("Body", [body_group])


def build_belly_layer():
    """White belly ellipse."""
    belly_w = p(0.30)
    belly_h = p(0.38)
    belly_cy = CY + p(0.14)
    
    belly_group = make_group("Belly", [
        make_ellipse(CX, belly_cy, belly_w, belly_h),
        make_gradient_fill(
            [CX, belly_cy - belly_h], [CX, belly_cy + belly_h],
            [(0.0, BELLY_TOP), (0.7, BELLY_TOP), (1.0, BELLY_BOTTOM)]
        ),
    ])
    
    return make_shape_layer("Belly", [belly_group])


def build_wing_layer(side, name):
    """Single wing flipper."""
    wing_h = p(0.22)
    wing_w = p(0.10)
    
    path = wing_path(CX, CY, side, wing_w, wing_h)
    
    wing_group = make_group(name, [
        make_path(path, f"{name} Shape"),
        make_fill(PLUMAGE_DARK),
    ])
    
    transform = default_transform()
    
    return make_shape_layer(name, [wing_group], transform)


def build_scarf_layer():
    """Blue accent scarf with tail."""
    path = scarf_path(CX, CY)
    
    scarf_group = make_group("Scarf", [
        make_path(path, "Scarf Shape"),
        make_gradient_fill(
            [CX - p(0.30), CY - p(0.065)], [CX + p(0.30), CY - p(0.065)],
            [(0.0, ACCENT_BLUE), (0.5, ACCENT_BLUE), (1.0, ACCENT_BLUE_DARK)]
        ),
        make_stroke(ACCENT_BLUE_LIGHT, 0.8, opacity=50),
    ])
    
    return make_shape_layer("Scarf", [scarf_group])


def build_head_layer():
    """Large round head — slightly wider than tall."""
    head_r = p(0.28)
    head_cy = CY - p(0.22)
    rx = head_r * 1.08
    ry = head_r
    
    head_group = make_group("Head", [
        make_ellipse(CX, head_cy, rx, ry),
        make_fill(PLUMAGE_DARK),
    ])
    
    # Subtle 3° tilt
    transform = default_transform()
    transform["r"] = {"a": 0, "k": 3}
    
    return make_shape_layer("Head", [head_group], transform)


def build_face_patch_layer():
    """Light oval face patch where eyes sit."""
    head_cy = CY - p(0.22)
    face_w = p(0.20)
    face_h = p(0.17)
    face_cy = head_cy + p(0.04)
    
    face_group = make_group("Face Patch", [
        make_ellipse(CX, face_cy, face_w, face_h),
        make_fill(FACE_PATCH),
    ])
    
    transform = default_transform()
    transform["r"] = {"a": 0, "k": 3}
    
    return make_shape_layer("Face Patch", [face_group], transform)


def build_eye_layer(side, name):
    """Single eye with pupil and two shine spots."""
    head_cy = CY - p(0.22)
    eye_y = head_cy + p(0.01)
    eye_spacing = p(0.095)
    
    ex = CX + side * eye_spacing
    base_r = p(0.042)
    er = base_r * (1.05 if side == 1 else 1.0)
    
    # Shine positions
    shine_r = er * 0.38
    shine_x = ex + er * 0.28
    shine_y = eye_y - er * 0.30
    
    shine2_r = er * 0.18
    shine2_x = ex - er * 0.22
    shine2_y = eye_y + er * 0.28
    
    items = [
        # Eye white (outer)
        make_group("Eye White", [
            make_ellipse(ex, eye_y, er * 1.15, er * 1.15),
            make_fill(EYE_WHITE),
        ]),
        # Pupil/iris
        make_group("Pupil", [
            make_ellipse(ex, eye_y, er, er),
            make_fill(EYE_BLACK),
        ]),
        # Main shine (top-right)
        make_group("Shine 1", [
            make_ellipse(shine_x, shine_y, shine_r, shine_r),
            make_fill(EYE_WHITE, opacity=92),
        ]),
        # Secondary shine (bottom-left)
        make_group("Shine 2", [
            make_ellipse(shine2_x, shine2_y, shine2_r, shine2_r),
            make_fill(EYE_WHITE, opacity=55),
        ]),
    ]
    
    # Blink animation: squish scale Y at specific frames
    transform = default_transform()
    transform["r"] = {"a": 0, "k": 3}  # Match head tilt
    
    # Blink every ~3.5 seconds (105 frames) — squish Y scale
    # Blink at frame 105 and frame 210 (end wraps)
    blink_frame_1 = 100  # ~3.3s
    blink_frame_2 = 195  # ~6.5s
    
    ei_fast = {"x": [0.33], "y": [1]}
    eo_fast = {"x": [0.67], "y": [0]}
    
    transform["s"] = {
        "a": 1,
        "k": [
            # Open
            {"t": 0, "s": [100, 100, 100], "i": ei_fast, "o": eo_fast},
            # Start closing (blink 1)
            {"t": blink_frame_1 - 2, "s": [100, 100, 100], "i": ei_fast, "o": eo_fast},
            {"t": blink_frame_1, "s": [100, 15, 100], "i": ei_fast, "o": eo_fast},
            {"t": blink_frame_1 + 1, "s": [100, 15, 100], "i": ei_fast, "o": eo_fast},
            {"t": blink_frame_1 + 4, "s": [100, 100, 100], "i": ei_fast, "o": eo_fast},
            # Open hold
            {"t": blink_frame_2 - 2, "s": [100, 100, 100], "i": ei_fast, "o": eo_fast},
            # Blink 2
            {"t": blink_frame_2, "s": [100, 15, 100], "i": ei_fast, "o": eo_fast},
            {"t": blink_frame_2 + 1, "s": [100, 15, 100], "i": ei_fast, "o": eo_fast},
            {"t": blink_frame_2 + 4, "s": [100, 100, 100], "i": ei_fast, "o": eo_fast},
            # End
            {"t": TOTAL_FRAMES, "s": [100, 100, 100]},
        ]
    }
    
    return make_shape_layer(name, items, transform)


def build_beak_layer():
    """Small blue downward-pointing beak."""
    head_cy = CY - p(0.22)
    beak_cy = head_cy + p(0.095)
    beak_w = p(0.042)
    beak_h = p(0.035)
    
    path = rounded_triangle_path(CX, beak_cy, beak_w, beak_h)
    
    beak_group = make_group("Beak", [
        make_path(path, "Beak Shape"),
        make_gradient_fill(
            [CX, beak_cy - beak_h], [CX, beak_cy + beak_h],
            [(0.0, ACCENT_BLUE_LIGHT), (1.0, ACCENT_BLUE)]
        ),
    ])
    
    transform = default_transform()
    transform["r"] = {"a": 0, "k": 3}
    
    return make_shape_layer("Beak", [beak_group], transform)


def build_blush_layer():
    """Soft pink blush on both cheeks."""
    head_cy = CY - p(0.22)
    blush_y = head_cy + p(0.04)
    blush_spacing = p(0.145)
    blush_r = p(0.035)
    
    left_blush = make_group("Left Blush", [
        make_ellipse(CX - blush_spacing, blush_y, blush_r, blush_r),
        make_fill(BLUSH_PINK, opacity=18),
    ])
    right_blush = make_group("Right Blush", [
        make_ellipse(CX + blush_spacing, blush_y, blush_r, blush_r),
        make_fill(BLUSH_PINK, opacity=18),
    ])
    
    transform = default_transform()
    transform["r"] = {"a": 0, "k": 3}
    
    return make_shape_layer("Blush", [left_blush, right_blush], transform)


def build_body_sway_layer():
    """
    A null/empty layer that parents all character layers for idle sway.
    The entire character gently rocks left-right.
    """
    # Sway: position oscillates ±2px on X axis over 3 seconds (90 frames)
    ei, eo = smooth_ease()
    
    # Generate smooth ping-pong sway
    sway_amp = 2.0
    half_cycle = 45  # 1.5s = 45 frames
    
    pos_keyframes = []
    t = 0
    direction = 1
    while t <= TOTAL_FRAMES:
        kf = {
            "t": t,
            "s": [W/2 + sway_amp * direction, H/2, 0],
            "i": {"x": [0.42, 0.42, 0.42], "y": [1, 1, 1]},
            "o": {"x": [0.58, 0.58, 0.58], "y": [0, 0, 0]},
        }
        pos_keyframes.append(kf)
        t += half_cycle
        direction *= -1
    
    pos_keyframes.append({"t": TOTAL_FRAMES, "s": [W/2 + sway_amp, H/2, 0]})
    
    transform = default_transform()
    transform["p"] = {"a": 1, "k": pos_keyframes}
    
    # Also add very subtle rotation sway (±1°)
    rot_keyframes = []
    t = 0
    direction = 1
    while t <= TOTAL_FRAMES:
        kf = {
            "t": t,
            "s": [0.8 * direction],
            "i": {"x": [0.42], "y": [1]},
            "o": {"x": [0.58], "y": [0]},
        }
        rot_keyframes.append(kf)
        t += half_cycle
        direction *= -1
    rot_keyframes.append({"t": TOTAL_FRAMES, "s": [0.8]})
    
    transform["r"] = {"a": 1, "k": rot_keyframes}
    
    return transform


def build_scarf_counter_sway():
    """Scarf sways opposite to body (secondary motion)."""
    half_cycle = 45
    phase_offset = 8  # ~0.25s behind body
    sway_amp = 1.5
    
    ei, eo = smooth_ease()
    
    pos_keyframes = []
    t = phase_offset
    direction = -1  # opposite to body
    while t <= TOTAL_FRAMES:
        kf = {
            "t": t,
            "s": [W/2 + sway_amp * direction, H/2, 0],
            "i": {"x": [0.42, 0.42, 0.42], "y": [1, 1, 1]},
            "o": {"x": [0.58, 0.58, 0.58], "y": [0, 0, 0]},
        }
        pos_keyframes.append(kf)
        t += half_cycle
        direction *= -1
    
    pos_keyframes.append({"t": TOTAL_FRAMES, "s": [W/2, H/2, 0]})
    
    transform = default_transform()
    transform["p"] = {"a": 1, "k": pos_keyframes}
    return transform


def generate_lottie():
    """Generate the complete Lottie JSON."""
    # Build sway transform for the main character group
    sway_transform = build_body_sway_layer()
    
    # Build all layers (bottom to top = first to last in array, but Lottie renders last on top)
    # In Lottie, layers are rendered in order: index 0 = back, higher = front
    # BUT in the layers array, first item renders on TOP. So we reverse.
    
    feet = build_feet_layer()
    body = build_body_layer()
    belly = build_belly_layer()
    left_wing = build_wing_layer(-1, "Left Wing")
    right_wing = build_wing_layer(1, "Right Wing")
    scarf = build_scarf_layer()
    head = build_head_layer()
    face_patch = build_face_patch_layer()
    left_eye = build_eye_layer(-1, "Left Eye")
    right_eye = build_eye_layer(1, "Right Eye")
    beak = build_beak_layer()
    blush = build_blush_layer()
    
    # Apply scarf counter-sway
    scarf["ks"] = build_scarf_counter_sway()
    
    # Layer order: last in list = rendered at back (Lottie convention)
    # We want: blush, beak, eyes, face_patch, head, scarf, wings, belly, body, feet
    # So front-most first:
    layers = [blush, beak, right_eye, left_eye, face_patch, head, scarf, right_wing, left_wing, belly, body, feet]
    
    # Assign indices
    for i, layer in enumerate(layers):
        layer["ind"] = i
    
    # Apply sway to ALL layers by putting them in a precomp
    # Actually, simpler: we'll apply the sway to each layer's transform position
    # by adding position animation. The sway_transform modifies position.
    for layer in layers:
        # Add sway to existing position
        base_pos = layer["ks"]["p"]
        if base_pos.get("a") == 0:
            # Static position — add sway animation
            static_val = base_pos["k"]
            half_cycle = 45
            sway_amp = 2.0
            
            pos_kfs = []
            t = 0
            direction = 1
            while t <= TOTAL_FRAMES:
                kf = {
                    "t": t,
                    "s": [static_val[0] + sway_amp * direction, static_val[1], static_val[2]],
                    "i": {"x": [0.42, 0.42, 0.42], "y": [1, 1, 1]},
                    "o": {"x": [0.58, 0.58, 0.58], "y": [0, 0, 0]},
                }
                pos_kfs.append(kf)
                t += half_cycle
                direction *= -1
            pos_kfs.append({"t": TOTAL_FRAMES, "s": [static_val[0] + sway_amp, static_val[1], static_val[2]]})
            
            layer["ks"]["p"] = {"a": 1, "k": pos_kfs}
    
    # Scarf gets opposite sway (already set via build_scarf_counter_sway)
    
    lottie = {
        "v": "5.12.1",          # bodymovin version
        "fr": FPS,              # frame rate
        "ip": 0,                # in point
        "op": TOTAL_FRAMES,     # out point
        "w": W,                 # width
        "h": H,                 # height
        "nm": "Nudgy Idle",     # composition name
        "ddd": 0,               # no 3D
        "assets": [],
        "layers": layers,
        "markers": [],
    }
    
    return lottie


def main():
    lottie = generate_lottie()
    
    # Output to Nudge bundle resources
    output_dir = os.path.join(
        os.path.dirname(os.path.abspath(__file__)),
        "Nudge", "Nudge", "Resources"
    )
    os.makedirs(output_dir, exist_ok=True)
    
    output_path = os.path.join(output_dir, "nudgy_idle.json")
    
    with open(output_path, "w") as f:
        json.dump(lottie, f, indent=2)
    
    # Also generate expression variants
    # For now, the idle animation is the base — expressions will be layered on via code
    
    file_size = os.path.getsize(output_path)
    
    print("🐧 Nudgy Lottie Animation Generated!")
    print(f"   Output: {output_path}")
    print(f"   Size: {file_size / 1024:.1f} KB")
    print(f"   Duration: {DURATION_SECONDS}s at {FPS}fps ({TOTAL_FRAMES} frames)")
    print(f"   Canvas: {W}×{H}")
    print(f"   Layers: 12 (feet, body, belly, 2×wing, scarf, head, face, 2×eye, beak, blush)")
    print()
    print("   ✅ Idle sway animation (±2px, 3s cycle)")
    print("   ✅ Eye blink (every ~3.5s)")
    print("   ✅ Scarf counter-sway (secondary motion)")
    print("   ✅ All proportions match app icon exactly")


if __name__ == "__main__":
    main()
