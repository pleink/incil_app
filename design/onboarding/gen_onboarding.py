"""Generate Incil CampApp onboarding illustrations (SVG + PNG).

Brand: beige #FAE9D8 card on #FAF5F0, orange #FF7C00, black #2D2926,
accents pink #D82C5F / yellow #FEBB13. Signature: striped sun logo.
"""
import re
import cairosvg
from pathlib import Path

BEIGE = "#FAE9D8"
CREAM = "#FAF5F0"
ORANGE = "#FF7C00"
BLACK = "#2D2926"
PINK = "#D82C5F"
YELLOW = "#FEBB13"

# Official striped-sun mark from logo_ball.svg (viewBox 0 0 119 119)
SUN_PATH = re.search(
    r'<path d="([^"]+)"',
    Path("/Users/tiz/Desktop/Incil/logo_ball.svg").read_text(),
).group(1)


def sun(x, y, size, fill=ORANGE):
    """Sun mark with top-left at (x,y), scaled to `size` px."""
    s = size / 119.0
    return (
        f'<g transform="translate({x},{y}) scale({s})">'
        f'<path d="{SUN_PATH}" fill="{fill}"/></g>'
    )


def svg(body, w=1200, h=1200):
    return (
        f'<svg width="{w}" height="{h}" viewBox="0 0 {w} {h}" '
        f'fill="none" xmlns="http://www.w3.org/2000/svg">\n'
        f'<rect width="{w}" height="{h}" rx="96" fill="{BEIGE}"/>\n'
        f"{body}\n</svg>\n"
    )


def tent(cx, base_y, width, height, fill=BLACK, door=BEIGE):
    """Simple flat A-tent silhouette."""
    x1, x2, ax = cx - width / 2, cx + width / 2, cx
    ay = base_y - height
    dw, dh = width * 0.22, height * 0.42
    return (
        f'<polygon points="{x1},{base_y} {ax},{ay} {x2},{base_y}" fill="{fill}"/>'
        f'<polygon points="{cx - dw / 2},{base_y} {cx},{base_y - dh} '
        f'{cx + dw / 2},{base_y}" fill="{door}"/>'
    )


# ---------------------------------------------------------------- slide 1
# Willkommen — festival: big sun over camp, tents, confetti
slide1 = svg(
    sun(410, 320, 380)
    + f'<circle cx="240" cy="420" r="22" fill="{YELLOW}"/>'
    + f'<circle cx="950" cy="380" r="16" fill="{PINK}"/>'
    + f'<circle cx="890" cy="560" r="14" fill="{YELLOW}"/>'
    + f'<circle cx="270" cy="600" r="12" fill="{PINK}"/>'
    # ground line
    + f'<rect x="140" y="960" width="920" height="14" rx="7" fill="{BLACK}"/>'
    + tent(430, 960, 380, 300)
    + tent(790, 960, 260, 200)
    # bunting flags
    + f'<path d="M150 120 Q 600 260 1050 120" stroke="{BLACK}" stroke-width="10" fill="none"/>'
    + f'<polygon points="330,168 300,238 372,222" fill="{PINK}"/>'
    + f'<polygon points="590,208 566,282 640,270" fill="{YELLOW}"/>'
    + f'<polygon points="850,172 832,246 904,224" fill="{ORANGE}"/>'
)

# ---------------------------------------------------------------- slide 2
# Programm — phone with schedule inside the app
rows = ""
row_data = [(ORANGE, 300), (PINK, 240), (YELLOW, 300), (ORANGE, 200)]
for i, (c, w) in enumerate(row_data):
    y = 460 + i * 130
    rows += (
        f'<rect x="380" y="{y}" width="440" height="96" rx="20" fill="{CREAM}"/>'
        f'<rect x="380" y="{y}" width="26" height="96" rx="13" fill="{c}"/>'
        f'<rect x="440" y="{y + 26}" width="{w}" height="20" rx="10" fill="{BLACK}" opacity="0.85"/>'
        f'<rect x="440" y="{y + 58}" width="{w * 0.6}" height="14" rx="7" fill="{BLACK}" opacity="0.35"/>'
    )
slide2 = svg(
    # phone body
    f'<rect x="330" y="220" width="540" height="860" rx="72" fill="none" '
    f'stroke="{BLACK}" stroke-width="26"/>'
    # notch
    + f'<rect x="530" y="268" width="140" height="18" rx="9" fill="{BLACK}"/>'
    # header sun + title bars
    + sun(380, 330, 90)
    + f'<rect x="500" y="348" width="220" height="24" rx="12" fill="{BLACK}"/>'
    + f'<rect x="500" y="386" width="140" height="16" rx="8" fill="{BLACK}" opacity="0.35"/>'
    + rows
    # floating accents
    + f'<circle cx="210" cy="380" r="18" fill="{YELLOW}"/>'
    + f'<circle cx="990" cy="320" r="14" fill="{PINK}"/>'
    + f'<circle cx="1000" cy="880" r="20" fill="{ORANGE}"/>'
    + f'<circle cx="200" cy="860" r="12" fill="{PINK}"/>'
)

# ---------------------------------------------------------------- slide 3
# Aktuell bleiben — bell with sun badge and sound arcs
slide3 = svg(
    # bell dome + lip + clapper
    f'<path d="M600 300 C 430 300 350 440 350 610 L 350 760 '
    f'L 310 830 L 890 830 L 850 760 L 850 610 C 850 440 770 300 600 300 Z" '
    f'fill="{BLACK}"/>'
    + f'<rect x="560" y="240" width="80" height="90" rx="40" fill="{BLACK}"/>'
    + f'<path d="M520 870 a 80 80 0 0 0 160 0 Z" fill="{BLACK}"/>'
    # sound arcs left/right
    + f'<path d="M250 420 A 320 320 0 0 0 250 800" stroke="{PINK}" stroke-width="22" stroke-linecap="round" fill="none"/>'
    + f'<path d="M160 360 A 430 430 0 0 0 160 860" stroke="{YELLOW}" stroke-width="22" stroke-linecap="round" fill="none"/>'
    + f'<path d="M950 420 A 320 320 0 0 1 950 800" stroke="{PINK}" stroke-width="22" stroke-linecap="round" fill="none"/>'
    + f'<path d="M1040 360 A 430 430 0 0 1 1040 860" stroke="{YELLOW}" stroke-width="22" stroke-linecap="round" fill="none"/>'
    # sun badge on cream disc
    + f'<circle cx="830" cy="330" r="150" fill="{CREAM}"/>'
    + sun(725, 225, 210)
)

# ---------------------------------------------------------------- slide 4
# Alles an einem Ort — map with route, pin, tent & stage
slide4 = svg(
    # map sheet
    f'<rect x="150" y="260" width="900" height="700" rx="48" fill="{CREAM}"/>'
    # fold lines
    + f'<line x1="450" y1="260" x2="450" y2="960" stroke="{BEIGE}" stroke-width="10"/>'
    + f'<line x1="750" y1="260" x2="750" y2="960" stroke="{BEIGE}" stroke-width="10"/>'
    # dashed route
    + f'<path d="M240 880 C 420 760 380 560 560 520 C 720 490 700 400 820 380" '
    f'stroke="{ORANGE}" stroke-width="16" stroke-dasharray="4 40" '
    f'stroke-linecap="round" fill="none"/>'
    # start dot
    + f'<circle cx="240" cy="880" r="26" fill="{PINK}"/>'
    # small tent + stage flag on the map
    + tent(360, 700, 170, 130, fill=BLACK, door=CREAM)
    + f'<rect x="850" y="700" width="14" height="180" rx="7" fill="{BLACK}"/>'
    + f'<polygon points="864,700 864,780 980,740" fill="{YELLOW}"/>'
    # music note near stage
    + f'<circle cx="620" cy="840" r="34" fill="{BLACK}"/>'
    + f'<rect x="642" y="720" width="14" height="122" fill="{BLACK}"/>'
    + f'<path d="M642 720 q 60 10 70 56 q -30 -26 -70 -20 Z" fill="{BLACK}"/>'
    # destination pin with sun face
    + f'<path d="M820 130 C 700 130 610 220 610 340 C 610 470 820 640 820 640 '
    f'C 820 640 1030 470 1030 340 C 1030 220 940 130 820 130 Z" fill="{ORANGE}"/>'
    + f'<circle cx="820" cy="335" r="120" fill="{CREAM}"/>'
    + sun(736, 251, 168)
)

OUT_SVG = Path("/Users/tiz/Git/private/incil/incil_app/design/onboarding")
OUT_PNG = Path("/Users/tiz/Git/private/incil/incil_app/assets/onboarding")
OUT_SVG.mkdir(parents=True, exist_ok=True)
OUT_PNG.mkdir(parents=True, exist_ok=True)

slides = {
    "onboarding_festival": slide1,
    "onboarding_programm": slide2,
    "onboarding_updates": slide3,
    "onboarding_gelaende": slide4,
}
for name, content in slides.items():
    (OUT_SVG / f"{name}.svg").write_text(content)
    cairosvg.svg2png(
        bytestring=content.encode(),
        write_to=str(OUT_PNG / f"{name}.png"),
        output_width=1200,
        output_height=1200,
    )
    print("built", name)
