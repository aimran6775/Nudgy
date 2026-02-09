"""
Nudgy SVG Generator for Rive Import
====================================
Generates a pixel-perfect SVG of Nudgy matching the app icon proportions exactly.
Each body part is in a named <g> group so Rive imports them as separate layers.

Artboard: 400 × 460 px (transparent background)
All proportions derived from generate_app_icon_v2.py (the canonical source of truth).

Usage:
    python3 generate_nudgy_svg.py
    → outputs nudgy_for_rive.svg
    → drag into Rive editor
"""

import math
import os

# ---- Artboard ----
ART_W = 400
ART_H = 460

# ---- Reference mapping ----
# In the icon generator:
#   canvas = 1024x1024 (after downsample)
#   cx, cy = 512, 527  (center)
#   psize = 680
#
# Our artboard is 400×460, we center the penguin.
# We'll use the same proportional system (fractions of psize).

CX = ART_W / 2       # 200
CY = ART_H / 2 + 10  # 240 (slightly below center, matching icon's +15 offset)
PSIZE = 340           # Scale psize to fit 400px artboard (680/2)

# ---- Colors ----
PLUMAGE_DARK = "#1A1A2E"
PLUMAGE_HIGHLIGHT = "#2A2A42"
PLUMAGE_EDGE = "#343450"
BELLY_TOP = "#F5F5F7"
BELLY_BOTTOM = "#E8E8EC"
ACCENT_BLUE = "#007AFF"
ACCENT_BLUE_DARK = "#0055CC"
ACCENT_BLUE_LIGHT = "#3399FF"
EYE_BLACK = "#0A0A0E"
EYE_WHITE = "#FFFFFF"
BLUSH_COLOR = "#FF6B8A"


def p(fraction):
    """Convert a fraction of psize to pixels."""
    return fraction * PSIZE


def fmt(val):
    """Format a float to 2 decimal places."""
    return f"{val:.2f}"


def ellipse_path(cx, cy, rx, ry):
    """Generate an SVG ellipse path using bezier curves (for precision)."""
    k = 0.5522848  # bezier approximation of quarter circle
    return (
        f"M {fmt(cx)} {fmt(cy - ry)} "
        f"C {fmt(cx + rx * k)} {fmt(cy - ry)}, {fmt(cx + rx)} {fmt(cy - ry * k)}, {fmt(cx + rx)} {fmt(cy)} "
        f"C {fmt(cx + rx)} {fmt(cy + ry * k)}, {fmt(cx + rx * k)} {fmt(cy + ry)}, {fmt(cx)} {fmt(cy + ry)} "
        f"C {fmt(cx - rx * k)} {fmt(cy + ry)}, {fmt(cx - rx)} {fmt(cy + ry * k)}, {fmt(cx - rx)} {fmt(cy)} "
        f"C {fmt(cx - rx)} {fmt(cy - ry * k)}, {fmt(cx - rx * k)} {fmt(cy - ry)}, {fmt(cx)} {fmt(cy - ry)} Z"
    )


def body_path():
    """
    Egg/pear-shaped body — wider at bottom, narrower at top.
    Directly from draw_body_shape() in the icon generator.
    """
    body_w = p(0.44)   # half-width
    body_h = p(0.48)   # half-height
    body_cy = CY + p(0.08)

    top_x = CX
    top_y = body_cy - body_h * 0.85

    return (
        f"M {fmt(top_x)} {fmt(top_y)} "
        # Right side
        f"C {fmt(CX + body_w * 0.6)} {fmt(top_y)}, "
        f"{fmt(CX + body_w * 1.1)} {fmt(body_cy - body_h * 0.15)}, "
        f"{fmt(CX + body_w * 0.95)} {fmt(body_cy + body_h * 0.5)} "
        # Right to bottom
        f"C {fmt(CX + body_w * 0.85)} {fmt(body_cy + body_h * 0.85)}, "
        f"{fmt(CX + body_w * 0.4)} {fmt(body_cy + body_h * 1.0)}, "
        f"{fmt(CX)} {fmt(body_cy + body_h * 0.95)} "
        # Bottom to left
        f"C {fmt(CX - body_w * 0.4)} {fmt(body_cy + body_h * 1.0)}, "
        f"{fmt(CX - body_w * 0.85)} {fmt(body_cy + body_h * 0.85)}, "
        f"{fmt(CX - body_w * 0.95)} {fmt(body_cy + body_h * 0.5)} "
        # Left to top
        f"C {fmt(CX - body_w * 1.1)} {fmt(body_cy - body_h * 0.15)}, "
        f"{fmt(CX - body_w * 0.6)} {fmt(top_y)}, "
        f"{fmt(top_x)} {fmt(top_y)} Z"
    )


def belly_path():
    """White belly — ellipse centered slightly below body center."""
    belly_w = p(0.30)
    belly_h = p(0.38)
    belly_cy = CY + p(0.14)
    return ellipse_path(CX, belly_cy, belly_w, belly_h)


def head_path():
    """Large round head — slightly wider than tall, with subtle 3° tilt."""
    head_r = p(0.28)
    head_cy = CY - p(0.22)
    rx = head_r * 1.08  # wider than tall
    ry = head_r
    return ellipse_path(CX, head_cy, rx, ry)


def face_patch_path():
    """Lighter oval on face where eyes sit."""
    head_cy = CY - p(0.22)
    face_w = p(0.20)
    face_h = p(0.17)
    face_cy = head_cy + p(0.04)
    return ellipse_path(CX, face_cy, face_w, face_h)


def eye_elements():
    """Generate SVG for both eyes with shine spots."""
    head_cy = CY - p(0.22)
    eye_y = head_cy + p(0.01)
    eye_spacing = p(0.095)
    elements = []

    for side, name in [(-1, "left_eye"), (1, "right_eye")]:
        ex = CX + side * eye_spacing
        base_r = p(0.042)
        er = base_r * (1.05 if side == 1 else 1.0)

        # Eye white (outer ring)
        outer_r = er * 1.15
        # Pupil/iris
        # Main shine
        shine_r = er * 0.38
        shine_x = ex + er * 0.28
        shine_y = eye_y - er * 0.30
        # Secondary shine
        shine2_r = er * 0.18
        shine2_x = ex - er * 0.22
        shine2_y = eye_y + er * 0.28

        elements.append(
            f'  <g id="{name}">\n'
            f'    <circle cx="{fmt(ex)}" cy="{fmt(eye_y)}" r="{fmt(outer_r)}" fill="{EYE_WHITE}"/>\n'
            f'    <circle cx="{fmt(ex)}" cy="{fmt(eye_y)}" r="{fmt(er)}" fill="{EYE_BLACK}"/>\n'
            f'    <circle cx="{fmt(shine_x)}" cy="{fmt(shine_y)}" r="{fmt(shine_r)}" fill="{EYE_WHITE}" opacity="0.92"/>\n'
            f'    <circle cx="{fmt(shine2_x)}" cy="{fmt(shine2_y)}" r="{fmt(shine2_r)}" fill="{EYE_WHITE}" opacity="0.55"/>\n'
            f'  </g>'
        )

    return "\n".join(elements)


def beak_path():
    """Small downward-pointing rounded triangle beak."""
    head_cy = CY - p(0.22)
    beak_cy = head_cy + p(0.095)
    beak_w = p(0.042)
    beak_h = p(0.035)

    return (
        f"M {fmt(CX)} {fmt(beak_cy + beak_h)} "
        f"C {fmt(CX - beak_w * 0.3)} {fmt(beak_cy + beak_h * 0.3)}, "
        f"{fmt(CX - beak_w)} {fmt(beak_cy - beak_h * 0.2)}, "
        f"{fmt(CX - beak_w * 0.8)} {fmt(beak_cy - beak_h * 0.5)} "
        f"C {fmt(CX - beak_w * 0.4)} {fmt(beak_cy - beak_h * 0.9)}, "
        f"{fmt(CX + beak_w * 0.4)} {fmt(beak_cy - beak_h * 0.9)}, "
        f"{fmt(CX + beak_w * 0.8)} {fmt(beak_cy - beak_h * 0.5)} "
        f"C {fmt(CX + beak_w)} {fmt(beak_cy - beak_h * 0.2)}, "
        f"{fmt(CX + beak_w * 0.3)} {fmt(beak_cy + beak_h * 0.3)}, "
        f"{fmt(CX)} {fmt(beak_cy + beak_h)} Z"
    )


def wing_path(side):
    """
    Stubby flipper wing. side = -1 (left) or 1 (right).
    Matches draw_wings() from icon generator.
    """
    wing_h = p(0.22)
    wing_w = p(0.10)
    wing_y = CY + p(0.02)
    wing_x = CX + side * p(0.37)
    angle = side * 15  # degrees

    # We'll compute the rotated/translated points manually
    # Origin for rotation: (wing_x, wing_y - wing_h * 0.4)
    ox = wing_x
    oy = wing_y - wing_h * 0.4
    rad = math.radians(angle)
    cos_a = math.cos(rad)
    sin_a = math.sin(rad)

    def rot(x, y):
        """Rotate point (x,y) around origin, then translate."""
        rx = x * cos_a - y * sin_a + ox
        ry = x * sin_a + y * cos_a + oy
        return rx, ry

    # Control points in local coords (pre-rotation)
    # Start at top
    p0 = rot(0, -wing_h * 0.5)
    # Right curve
    c1 = rot(side * wing_w * 0.8, -wing_h * 0.3)
    c2 = rot(side * wing_w * 1.2, wing_h * 0.1)
    p1 = rot(side * wing_w * 0.6, wing_h * 0.5)
    # Back curve
    c3 = rot(side * wing_w * 0.2, wing_h * 0.65)
    c4 = rot(-side * wing_w * 0.2, wing_h * 0.2)
    p2 = rot(0, -wing_h * 0.5)

    return (
        f"M {fmt(p0[0])} {fmt(p0[1])} "
        f"C {fmt(c1[0])} {fmt(c1[1])}, {fmt(c2[0])} {fmt(c2[1])}, {fmt(p1[0])} {fmt(p1[1])} "
        f"C {fmt(c3[0])} {fmt(c3[1])}, {fmt(c4[0])} {fmt(c4[1])}, {fmt(p2[0])} {fmt(p2[1])} Z"
    )


def scarf_path():
    """
    Blue scarf with trailing tail.
    Matches draw_scarf() from icon generator.
    """
    scarf_y = CY - p(0.065)
    scarf_h = p(0.035)
    scarf_w = p(0.30)

    return (
        f"M {fmt(CX - scarf_w)} {fmt(scarf_y - scarf_h)} "
        # Top curve
        f"C {fmt(CX - scarf_w * 0.5)} {fmt(scarf_y - scarf_h * 1.8)}, "
        f"{fmt(CX + scarf_w * 0.5)} {fmt(scarf_y - scarf_h * 1.8)}, "
        f"{fmt(CX + scarf_w)} {fmt(scarf_y - scarf_h)} "
        # Right side down
        f"C {fmt(CX + scarf_w * 1.05)} {fmt(scarf_y + scarf_h * 0.5)}, "
        f"{fmt(CX + scarf_w * 0.5)} {fmt(scarf_y + scarf_h * 2.5)}, "
        f"{fmt(CX + scarf_w * 0.3)} {fmt(scarf_y + scarf_h * 2.0)} "
        # Tail curves down-right
        f"C {fmt(CX + scarf_w * 0.65)} {fmt(scarf_y + scarf_h * 4.0)}, "
        f"{fmt(CX + scarf_w * 0.85)} {fmt(scarf_y + scarf_h * 5.5)}, "
        f"{fmt(CX + scarf_w * 0.55)} {fmt(scarf_y + scarf_h * 6.5)} "
        # Tail end back up
        f"C {fmt(CX + scarf_w * 0.35)} {fmt(scarf_y + scarf_h * 5.0)}, "
        f"{fmt(CX + scarf_w * 0.45)} {fmt(scarf_y + scarf_h * 3.5)}, "
        f"{fmt(CX + scarf_w * 0.15)} {fmt(scarf_y + scarf_h * 2.0)} "
        # Close along bottom of main wrap
        f"C {fmt(CX - scarf_w * 0.3)} {fmt(scarf_y + scarf_h * 2.8)}, "
        f"{fmt(CX - scarf_w * 0.8)} {fmt(scarf_y + scarf_h * 1.5)}, "
        f"{fmt(CX - scarf_w)} {fmt(scarf_y - scarf_h)} Z"
    )


def foot_path(side):
    """Small rounded foot. side = -1 (left) or 1 (right)."""
    body_bottom = CY + p(0.50)
    foot_w = p(0.065)
    foot_h = p(0.025)
    foot_spacing = p(0.08)
    fx = CX + side * foot_spacing
    fy = body_bottom
    return ellipse_path(fx, fy, foot_w, foot_h)


def blush_elements():
    """Cheek blush circles."""
    head_cy = CY - p(0.22)
    blush_y = head_cy + p(0.04)
    blush_spacing = p(0.145)
    blush_r = p(0.035)

    elements = []
    for side, name in [(-1, "blush_left"), (1, "blush_right")]:
        bx = CX + side * blush_spacing
        elements.append(
            f'  <g id="{name}">\n'
            f'    <circle cx="{fmt(bx)}" cy="{fmt(blush_y)}" r="{fmt(blush_r)}" '
            f'fill="{BLUSH_COLOR}" opacity="0.15"/>\n'
            f'  </g>'
        )
    return "\n".join(elements)


def generate_svg():
    """Generate the complete Nudgy SVG."""
    # Head tilt transform
    head_cy = CY - p(0.22)
    head_tilt = f'transform="rotate(3, {fmt(CX)}, {fmt(head_cy)})"'

    # Gradient definitions
    defs = f"""  <defs>
    <!-- Body gradient: dark with edge highlights -->
    <linearGradient id="bodyGrad" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0%" stop-color="{PLUMAGE_EDGE}"/>
      <stop offset="15%" stop-color="{PLUMAGE_DARK}"/>
      <stop offset="85%" stop-color="{PLUMAGE_DARK}"/>
      <stop offset="100%" stop-color="{PLUMAGE_EDGE}"/>
    </linearGradient>

    <!-- Belly gradient: white top, slightly shadowed bottom -->
    <linearGradient id="bellyGrad" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="{BELLY_TOP}"/>
      <stop offset="70%" stop-color="{BELLY_TOP}"/>
      <stop offset="100%" stop-color="{BELLY_BOTTOM}"/>
    </linearGradient>

    <!-- Head gradient: radial highlight -->
    <radialGradient id="headGrad" cx="0.35" cy="0.3" r="0.7">
      <stop offset="0%" stop-color="{PLUMAGE_HIGHLIGHT}"/>
      <stop offset="50%" stop-color="{PLUMAGE_DARK}"/>
      <stop offset="100%" stop-color="{PLUMAGE_DARK}"/>
    </radialGradient>

    <!-- Wing gradient -->
    <linearGradient id="wingGradL" x1="1" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="{PLUMAGE_DARK}"/>
      <stop offset="50%" stop-color="{PLUMAGE_DARK}"/>
      <stop offset="100%" stop-color="{PLUMAGE_HIGHLIGHT}"/>
    </linearGradient>
    <linearGradient id="wingGradR" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="{PLUMAGE_DARK}"/>
      <stop offset="50%" stop-color="{PLUMAGE_DARK}"/>
      <stop offset="100%" stop-color="{PLUMAGE_HIGHLIGHT}"/>
    </linearGradient>

    <!-- Scarf gradient -->
    <linearGradient id="scarfGrad" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0%" stop-color="{ACCENT_BLUE}"/>
      <stop offset="50%" stop-color="{ACCENT_BLUE}"/>
      <stop offset="100%" stop-color="{ACCENT_BLUE_DARK}"/>
    </linearGradient>

    <!-- Beak gradient -->
    <linearGradient id="beakGrad" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="{ACCENT_BLUE_LIGHT}"/>
      <stop offset="100%" stop-color="{ACCENT_BLUE}"/>
    </linearGradient>
  </defs>"""

    # Build SVG layer by layer (back to front, matching icon draw order)
    svg = f"""<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg"
     viewBox="0 0 {ART_W} {ART_H}"
     width="{ART_W}" height="{ART_H}"
     style="background: transparent">

{defs}

  <!-- Layer 0: Feet -->
  <g id="feet">
    <g id="left_foot">
      <path d="{foot_path(-1)}" fill="{ACCENT_BLUE}" opacity="0.7"/>
    </g>
    <g id="right_foot">
      <path d="{foot_path(1)}" fill="{ACCENT_BLUE}" opacity="0.7"/>
    </g>
  </g>

  <!-- Layer 1: Body -->
  <g id="body">
    <path d="{body_path()}" fill="url(#bodyGrad)"/>
  </g>

  <!-- Layer 2: Belly -->
  <g id="belly">
    <path d="{belly_path()}" fill="url(#bellyGrad)"/>
  </g>

  <!-- Layer 3: Wings -->
  <g id="left_wing">
    <path d="{wing_path(-1)}" fill="url(#wingGradL)"/>
  </g>
  <g id="right_wing">
    <path d="{wing_path(1)}" fill="url(#wingGradR)"/>
  </g>

  <!-- Layer 4: Scarf -->
  <g id="scarf">
    <path d="{scarf_path()}" fill="url(#scarfGrad)" stroke="{ACCENT_BLUE_LIGHT}" stroke-width="0.8" stroke-opacity="0.5"/>
  </g>

  <!-- Layer 5: Head -->
  <g id="head" {head_tilt}>
    <path d="{head_path()}" fill="url(#headGrad)"/>
  </g>

  <!-- Layer 6: Face Patch -->
  <g id="face_patch" {head_tilt}>
    <path d="{face_patch_path()}" fill="{EYE_WHITE}"/>
  </g>

  <!-- Layer 7-8: Eyes -->
  <g id="eyes" {head_tilt}>
{eye_elements()}
  </g>

  <!-- Layer 9: Beak -->
  <g id="beak" {head_tilt}>
    <path d="{beak_path()}" fill="url(#beakGrad)"/>
  </g>

  <!-- Layer 10-11: Blush -->
  <g id="blush" {head_tilt}>
{blush_elements()}
  </g>

</svg>"""

    return svg


def main():
    svg_content = generate_svg()
    
    output_path = os.path.join(
        os.path.dirname(os.path.abspath(__file__)),
        "nudgy_for_rive.svg"
    )
    
    with open(output_path, "w") as f:
        f.write(svg_content)
    
    print("🐧 Nudgy SVG Generated!")
    print(f"   Output: {output_path}")
    print(f"   Size: {ART_W} × {ART_H} px")
    print()
    print("Next steps:")
    print("  1. Open the Rive editor (editor.rive.app)")
    print("  2. Drag 'nudgy_for_rive.svg' onto the editor")
    print("  3. Each body part is a named group → becomes a Rive layer")
    print("  4. Add state machine + animations")
    print("  5. Export as nudgy.riv")


if __name__ == "__main__":
    main()
