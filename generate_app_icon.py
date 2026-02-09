"""
Nudge App Icon Generator
========================
Generates the penguin mascot icon in all 3 iOS variants:
  1. Light (default) — charcoal bg, white penguin, blue accents
  2. Dark — pure black bg, white penguin, blue accents  
  3. Tinted — solid white silhouette on transparent bg (iOS applies user tint)

Design: Close-up penguin bust matching PenguinMascot.swift geometry.
All drawn with Pillow ellipses, polygons, and anti-aliased shapes.

Output: 1024x1024 PNGs directly into the Xcode asset catalog.
"""

from PIL import Image, ImageDraw, ImageFilter
import math
import os

# ----- Config -----
SIZE = 1024
CENTER = SIZE // 2
# Scale factor: everything is relative to this so we can resize later
S = SIZE / 1024.0

# Colors from DesignTokens
ACCENT_BLUE = (0, 122, 255)          # #007AFF
ACCENT_BLUE_SOFT = (0, 122, 255, 60) # glow
PURE_BLACK = (0, 0, 0)
CARD_DARK = (28, 28, 30)             # #1C1C1E
CHARCOAL_BG = (18, 18, 20)           # slightly lighter than pure black for light variant
WING_DARK = (44, 44, 46)             # #2C2C2E
WHITE = (255, 255, 255)
BELLY_WHITE = (245, 245, 247)        # slightly warm
EYE_BLACK = (10, 10, 12)
SCARF_BLUE = (0, 100, 220, 140)      # semi-transparent scarf

OUTPUT_DIR = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "Nudge", "Nudge", "Assets.xcassets", "AppIcon.appiconset"
)


def s(val):
    """Scale a value relative to 1024."""
    return int(val * S)


def ellipse_bbox(cx, cy, rx, ry):
    """Return bounding box for an ellipse centered at (cx, cy) with radii rx, ry."""
    return [cx - rx, cy - ry, cx + rx, cy + ry]


def draw_rounded_ellipse(draw, cx, cy, rx, ry, fill, img=None):
    """Draw an anti-aliased ellipse. If img provided, uses supersampling."""
    draw.ellipse(ellipse_bbox(cx, cy, rx, ry), fill=fill)


def draw_triangle(draw, cx, cy, width, height, fill):
    """Draw a downward-pointing triangle (beak)."""
    points = [
        (cx, cy + height),           # bottom point
        (cx - width // 2, cy),       # top left
        (cx + width // 2, cy),       # top right
    ]
    draw.polygon(points, fill=fill)


def draw_subtle_glow(img, cx, cy, radius, color, intensity=0.5):
    """Draw a soft radial glow behind the penguin."""
    glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    
    # Multiple concentric circles with decreasing opacity
    steps = 30
    for i in range(steps, 0, -1):
        r = int(radius * (i / steps))
        alpha = int(intensity * 255 * ((steps - i) / steps) ** 2)
        alpha = min(alpha, 80)
        glow_draw.ellipse(
            ellipse_bbox(cx, cy, r, r),
            fill=(color[0], color[1], color[2], alpha)
        )
    
    # Blur for softness
    glow = glow.filter(ImageFilter.GaussianBlur(radius=s(40)))
    img.paste(Image.alpha_composite(
        Image.new("RGBA", img.size, (0, 0, 0, 0)),
        glow
    ), (0, 0), glow)


def draw_penguin(draw, variant="dark"):
    """
    Draw the penguin bust — matching PenguinMascot.swift proportions.
    
    The penguin is centered and fills roughly 70% of the icon,
    positioned slightly above center for visual weight.
    """
    # Penguin center — slightly above icon center for better visual balance
    pcx = CENTER
    pcy = s(480)
    
    # Scale factor for penguin relative to icon
    psize = s(680)  # penguin "size" reference
    
    # ---- BODY (main dark outer shape) ----
    body_rx = int(psize * 0.42)
    body_ry = int(psize * 0.50)
    body_cy = pcy + s(60)
    draw.ellipse(
        ellipse_bbox(pcx, body_cy, body_rx, body_ry),
        fill=WING_DARK if variant != "tinted" else WHITE
    )
    
    # ---- BELLY (white inner) ----
    if variant != "tinted":
        belly_rx = int(psize * 0.32)
        belly_ry = int(psize * 0.42)
        belly_cy = pcy + s(80)
        draw.ellipse(
            ellipse_bbox(pcx, belly_cy, belly_rx, belly_ry),
            fill=BELLY_WHITE
        )
    
    # ---- HEAD (round, overlaps body top) ----
    head_rx = int(psize * 0.30)
    head_ry = int(psize * 0.28)
    head_cy = pcy - s(80)
    draw.ellipse(
        ellipse_bbox(pcx, head_cy, head_rx, head_ry),
        fill=WING_DARK if variant != "tinted" else WHITE
    )
    
    # ---- FACE PATCH (white area on face) ----
    if variant != "tinted":
        face_rx = int(psize * 0.23)
        face_ry = int(psize * 0.20)
        face_cy = head_cy + s(15)
        draw.ellipse(
            ellipse_bbox(pcx, face_cy, face_rx, face_ry),
            fill=WHITE
        )
    
    # ---- WINGS (left and right, tucked) ----
    if variant != "tinted":
        wing_rx = int(psize * 0.12)
        wing_ry = int(psize * 0.30)
        wing_y = pcy + s(40)
        
        # Left wing — slight rotation simulated with offset
        draw.ellipse(
            ellipse_bbox(pcx - int(psize * 0.36), wing_y, wing_rx, wing_ry),
            fill=CARD_DARK
        )
        # Right wing
        draw.ellipse(
            ellipse_bbox(pcx + int(psize * 0.36), wing_y, wing_rx, wing_ry),
            fill=CARD_DARK
        )
    
    # ---- EYES ----
    if variant != "tinted":
        eye_r = int(psize * 0.045)
        eye_y = head_cy + s(5)
        eye_spacing = int(psize * 0.10)
        
        # Left eye
        draw.ellipse(
            ellipse_bbox(pcx - eye_spacing, eye_y, eye_r, eye_r),
            fill=EYE_BLACK
        )
        # Right eye
        draw.ellipse(
            ellipse_bbox(pcx + eye_spacing, eye_y, eye_r, eye_r),
            fill=EYE_BLACK
        )
        
        # Eye shine (top-right sparkle)
        shine_r = int(eye_r * 0.35)
        shine_offset_x = int(eye_r * 0.25)
        shine_offset_y = -int(eye_r * 0.30)
        for ex in [pcx - eye_spacing, pcx + eye_spacing]:
            draw.ellipse(
                ellipse_bbox(
                    ex + shine_offset_x,
                    eye_y + shine_offset_y,
                    shine_r, shine_r
                ),
                fill=WHITE
            )
    
    # ---- BEAK ----
    beak_cx = pcx
    beak_cy = head_cy + s(40)
    beak_w = int(psize * 0.08)
    beak_h = int(psize * 0.045)
    
    if variant == "tinted":
        # For tinted, cut out the beak area (we'll skip it — keep silhouette clean)
        pass
    else:
        draw_triangle(draw, beak_cx, beak_cy, beak_w, beak_h, fill=ACCENT_BLUE)
    
    # ---- SCARF (accent stripe across neck) ----
    if variant != "tinted":
        scarf_y = head_cy + s(68)
        scarf_h = s(16)
        scarf_rx = int(psize * 0.28)
        # Draw as a wide thin ellipse
        draw.ellipse(
            ellipse_bbox(pcx, scarf_y, scarf_rx, scarf_h),
            fill=(*ACCENT_BLUE, 150)
        )


def generate_dark_icon():
    """Dark variant — pure black bg, white penguin, blue accents. Matches in-app feel."""
    img = Image.new("RGBA", (SIZE, SIZE), (*PURE_BLACK, 255))
    draw = ImageDraw.Draw(img)
    
    # Subtle blue glow behind penguin
    draw_subtle_glow(img, CENTER, s(420), s(380), ACCENT_BLUE, intensity=0.35)
    
    # Redraw on the composited image
    draw = ImageDraw.Draw(img)
    draw_penguin(draw, variant="dark")
    
    # Convert to RGB (no alpha for iOS icon)
    final = Image.new("RGB", (SIZE, SIZE), PURE_BLACK)
    final.paste(img, (0, 0), img)
    return final


def generate_light_icon():
    """Light variant — charcoal/dark navy bg, white penguin, blue accents."""
    # Slightly lighter background to distinguish from dark variant
    bg_color = (24, 24, 28)
    img = Image.new("RGBA", (SIZE, SIZE), (*bg_color, 255))
    draw = ImageDraw.Draw(img)
    
    # Slightly stronger glow for the lighter background
    draw_subtle_glow(img, CENTER, s(420), s(400), ACCENT_BLUE, intensity=0.45)
    
    draw = ImageDraw.Draw(img)
    draw_penguin(draw, variant="dark")
    
    final = Image.new("RGB", (SIZE, SIZE), bg_color)
    final.paste(img, (0, 0), img)
    return final


def generate_tinted_icon():
    """
    Tinted variant — solid white silhouette on transparent background.
    iOS applies the user's chosen tint color as a multiply/overlay.
    Apple recommends: white shape on transparent, no internal detail.
    """
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw_penguin(draw, variant="tinted")
    return img


def save_icon(img, filename):
    """Save to the asset catalog directory."""
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    path = os.path.join(OUTPUT_DIR, filename)
    img.save(path, "PNG", quality=100)
    print(f"  ✅ {filename} ({img.size[0]}×{img.size[1]})")
    return path


def generate_contents_json():
    """Generate the Xcode asset catalog Contents.json for the app icon."""
    return '''{
  "images" : [
    {
      "filename" : "icon-light.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "filename" : "icon-dark.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "tinted"
        }
      ],
      "filename" : "icon-tinted.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
'''


def main():
    print("🐧 Nudge App Icon Generator")
    print(f"   Output: {OUTPUT_DIR}")
    print()
    
    print("Generating variants...")
    
    light = generate_light_icon()
    save_icon(light, "icon-light.png")
    
    dark = generate_dark_icon()
    save_icon(dark, "icon-dark.png")
    
    tinted = generate_tinted_icon()
    save_icon(tinted, "icon-tinted.png")
    
    # Write Contents.json
    contents_path = os.path.join(OUTPUT_DIR, "Contents.json")
    with open(contents_path, "w") as f:
        f.write(generate_contents_json())
    print(f"  ✅ Contents.json")
    
    print()
    print("🎉 Done! Icons are in the Xcode asset catalog.")
    print("   Build the project in Xcode to verify.")


if __name__ == "__main__":
    main()
