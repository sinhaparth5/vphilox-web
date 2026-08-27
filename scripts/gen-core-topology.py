"""Regenerate the SVG body of src/components/CoreTopology.astro.

Geometry is laid out from the constants below, then checked: no two parallel
wires closer than MIN_PARALLEL, no label within MIN_TEXT of a wire it does not
belong to, no label overlapping another. Run it for each placement arm, since
only one is ever on screen:

    python3 scripts/gen-core-topology.py spread
    python3 scripts/gen-core-topology.py packed   # writes the SVG body

The body replaces everything between </desc> and </svg> in the component."""

import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "src" / "components" / "_core-topology.svg.part"

W, H = 1120, 648

CORE_X = [20, 300, 580, 860]
CORE_W, CORE_TOP, CORE_BOT = 250, 54, 364
INNER, IW = 12, 226                       # inner margin, inner width

Y_CORELAB = 76
Y_TH, HTH = 92, 58                        # thread boxes 92..150
Y_THLAB = 106
Y_WK, HWK, WWK = 118, 22, 74              # worker pill 118..140
Y_PORTS, HPORTS = 186, 46                 # 186..232
Y_PILL, HPILL, WPILL = 196, 26, 62        # 196..222
Y_L1, HL1 = 252, 44                       # 252..296
Y_L2, HL2 = 316, 40                       # 316..356
Y_L3, HL3 = 392, 50
Y_DR, HDR = 470, 44
Y_DIV = 538
Y_TITLE = 564
BAR_Y = [580, 610]; HBAR = 18
BASE = [593, 623]

TW, TWG = 106, 14                         # thread box width, gap
BARW = 240

def th_x(x0, k):  return x0 + INNER + k * (TW + TWG)
def th_cx(x0, k): return th_x(x0, k) + TW / 2

boxes, texts, wires = [], [], []

def box(st, x, y, w, h, label, cls="", i=0, size=13, rx=6, lab_cls="boxlabel"):
    b = dict(st=st, x=x, y=y, w=w, h=h, cls=cls, i=i, rx=rx,
             label=label, lab_cls=lab_cls, size=size)
    boxes.append(b)
    if label:
        texts.append(dict(st=st, x=x + w / 2, y=y + h / 2 + size * 0.34,
                          s=label, cls=lab_cls, size=size, anchor="middle", owner=b))

def txt(st, x, y, s, cls="cap", size=12, anchor="middle"):
    texts.append(dict(st=st, x=x, y=y, s=s, cls=cls, size=size, anchor=anchor))

def wire(st, d, cls="wire"):
    wires.append(dict(st=st, d=d, cls=cls))

# ---------------------------------------------------------------- stage 0
for n, x0 in enumerate(CORE_X):
    box(0, x0, CORE_TOP, CORE_W, CORE_BOT - CORE_TOP, "", cls="core", i=n, rx=10)
    txt(0, x0 + CORE_W / 2, Y_CORELAB, f"core {n}", cls="corelab", size=14)

    for k in range(2):
        box(0, th_x(x0, k), Y_TH, TW, HTH, "", cls=f"thread t{n}{k}", i=n)
        txt(0, th_cx(x0, k), Y_THLAB, f"thread {k}", cls="cap", size=13)
        wire(0, f"M{th_cx(x0, k):g} {Y_TH + HTH} V{Y_PORTS}", cls=f"wire iss i{n}{k}")

    # Sits in the 36px band between the thread boxes and the strip, centred
    # between the two issue wires that pass through it.
    txt(0, x0 + CORE_W / 2, Y_PORTS - 14, "issue ports", cls="cap", size=13)
    box(0, x0 + INNER, Y_PORTS, IW, HPORTS, "", cls="ports", i=n)
    for k, lab in enumerate(["mul", "mul", "ld/st"]):
        px = x0 + INNER + 10 + k * (WPILL + 10)
        box(0, px, Y_PILL, WPILL, HPILL, lab,
            cls=("port mulport p%d%d" % (n, k)) if k < 2 else "port p%d%d" % (n, k),
            i=n, size=13, rx=13, lab_cls="pilllabel")

    for k in range(2):
        wire(0, f"M{th_cx(x0, k):g} {Y_PORTS + HPORTS} V{Y_L1}")
    box(0, th_x(x0, 0), Y_L1, TW, HL1, "L1i 32 KiB", cls=f"cache l1i c{n}", i=n, size=13)
    box(0, th_x(x0, 1), Y_L1, TW, HL1, "L1d 48 KiB", cls="cache", i=n, size=13)

    for k in range(2):
        wire(0, f"M{th_cx(x0, k):g} {Y_L1 + HL1} V{Y_L2}")
    box(0, x0 + INNER, Y_L2, IW, HL2, "L2  1.25 MiB", cls="cache", i=n, size=13)

    wire(0, f"M{x0 + CORE_W / 2:g} {CORE_BOT} V{Y_L3}")

box(0, 20, Y_L3, 1090, HL3, "shared L3  ·  8 MiB", cls="cache shared", i=4, size=14)
wire(0, f"M565 {Y_L3 + HL3} V{Y_DR}")
box(0, 20, Y_DR, 1090, HDR, "DRAM", cls="cache dram", i=5, size=14)

# ---------------------------------------------------------------- readout
PANEL = [
    dict(x0=20, lx=196, bx=206, title="cycles per byte",
         rows=[("one per core", 0.5160), ("packed onto siblings", 0.8204)],
         top=0.8204, delta="+59.0%"),
    dict(x0=600, lx=776, bx=786, title="L1i misses / 1000 instructions",
         rows=[("one per core", 0.2108), ("packed onto siblings", 0.1356)],
         top=0.2108, delta="−35.7%"),
]

wires.append(dict(st=1, d=f"M20 {Y_DIV} H1110", cls="divider"))
for p in PANEL:
    txt(1, p["x0"], Y_TITLE, p["title"], cls="panelcap", size=13, anchor="start")
    for r, (lab, val) in enumerate(p["rows"]):
        st = r + 1                                   # stage 1 then stage 2
        w = BARW * val / p["top"]
        txt(st, p["lx"], BASE[r], lab, cls="rowlab", size=13, anchor="end")
        boxes.append(dict(st=st, x=p["bx"], y=BAR_Y[r], w=w, h=HBAR, label="",
                          cls="bar" + (" bar-hi" if r == 1 else ""), i=r, rx=3))
        txt(st, p["bx"] + w + 10, BASE[r], f"{val:.4f}",
            cls="val", size=13, anchor="start")
    # The delta trails the packed row's own value, so neither panel overruns.
    wp = BARW * p["rows"][1][1] / p["top"]
    dx = p["bx"] + wp + 10 + len(f'{p["rows"][1][1]:.4f}') * 13 * 0.62 + 12
    txt(4, dx, BASE[1], p["delta"], cls="delta", size=13, anchor="start")

# ---------------------------------------------------------------- workers
WORKERS = {
    "spread": [(0, 0), (1, 0), (2, 0), (3, 0)],
    "packed": [(0, 0), (0, 1), (1, 0), (1, 1)],
}
worker_g = {}
for arm, slots in WORKERS.items():
    items = []
    for w, (core, k) in enumerate(slots):
        cx = th_cx(CORE_X[core], k)
        items.append((cx - WWK / 2, Y_WK, WWK, HWK, f"w{w}", cx, Y_WK + HWK / 2 + 13 * 0.34))
    worker_g[arm] = items

ARM = sys.argv[1] if len(sys.argv) > 1 else "spread"
for x, y, w_, h_, lab, cx, ty in worker_g[ARM]:
    b = dict(st=None, x=x, y=y, w=w_, h=h_, cls="worker", i=0, rx=11,
             label=lab, lab_cls="wklabel", size=13)
    boxes.append(b)
    texts.append(dict(st=None, x=cx, y=ty, s=lab, cls="wklabel", size=13,
                      anchor="middle", owner=b))

# ---------------------------------------------- stage 3 and 4 highlight overlays
# Outlines only, laid over the originals, so the labels underneath show through.
for n in (0, 1):
    x0 = CORE_X[n]
    for k in range(2):
        px = x0 + INNER + 10 + k * (WPILL + 10)
        boxes.append(dict(st=3, x=px, y=Y_PILL, w=WPILL, h=HPILL, label="",
                          cls="overlay hot", i=k, rx=13))
        wire(3, f"M{th_cx(x0, k):g} {Y_TH + HTH} V{Y_PORTS}", cls="wire hot trace")
    boxes.append(dict(st=4, x=th_x(x0, 0), y=Y_L1, w=TW, h=HL1, label="",
                      cls="overlay cool", i=n, rx=6))

# ================================================================ verify
def segs(d):
    hs, vs = [], []
    parts = d.replace("M", " M").replace("V", " V").replace("H", " H").split()
    x = y = 0.0
    i = 0
    while i < len(parts):
        t = parts[i]
        if t.startswith("M"):
            x, y = float(t[1:]), float(parts[i + 1]); i += 2
        elif t.startswith("V"):
            y2 = float(t[1:]); vs.append((x, min(y, y2), max(y, y2))); y = y2; i += 1
        elif t.startswith("H"):
            x2 = float(t[1:]); hs.append((y, min(x, x2), max(x, x2))); x = x2; i += 1
        else:
            i += 1
    return hs, vs

H_RUNS, V_RUNS = [], []
for w in wires:
    # Highlight overlays are drawn exactly on top of the wire they emphasise,
    # so they are not a second run competing for the same space.
    if "hot" in w["cls"]:
        continue
    a, b = segs(w["d"]); H_RUNS += a; V_RUNS += b

MIN_PARALLEL, MIN_TEXT, MIN_BOX = 16, 8, 6
problems = []

def check_parallel(runs, name):
    for i in range(len(runs)):
        for j in range(i + 1, len(runs)):
            p1, a1, b1 = runs[i]; p2, a2, b2 = runs[j]
            gap = abs(p1 - p2)
            if gap < MIN_PARALLEL and min(b1, b2) - max(a1, a2) > 2:
                problems.append(f"{name} runs {gap:.0f}px apart at {p1:.0f}/{p2:.0f}")

check_parallel(H_RUNS, "horizontal"); check_parallel(V_RUNS, "vertical")

def tbox(t):
    w = len(t["s"]) * t["size"] * 0.62
    if t["anchor"] == "middle": x0 = t["x"] - w / 2
    elif t["anchor"] == "end":  x0 = t["x"] - w
    else:                       x0 = t["x"]
    return x0, x0 + w, t["y"] - t["size"] * 0.78, t["y"] + t["size"] * 0.24

def inside_box(t):
    """A label centred on its own node is not a collision."""
    x0, x1, y0, y1 = tbox(t)
    for b in boxes:
        if b["x"] <= x0 and x1 <= b["x"] + b["w"] and b["y"] <= y0 and y1 <= b["y"] + b["h"]:
            return True
    return False

for t in texts:
    x0, x1, y0, y1 = tbox(t)
    if x1 > W - 4 or x0 < 4:
        problems.append(f"text {t['s']!r} runs off canvas ({x0:.0f}..{x1:.0f})")
    if inside_box(t):
        continue
    for yy, a, b in H_RUNS:
        if y0 - MIN_TEXT < yy < y1 + MIN_TEXT and min(b, x1) - max(a, x0) > 0:
            problems.append(f"text {t['s']!r} within {MIN_TEXT}px of H wire y={yy:.0f}")
    for xx, c, d2 in V_RUNS:
        if x0 - MIN_TEXT < xx < x1 + MIN_TEXT and min(d2, y1) - max(c, y0) > 0:
            problems.append(f"text {t['s']!r} within {MIN_TEXT}px of V wire x={xx:.0f}")
    for b in boxes:
        bx0, by0, bx1, by1 = b["x"], b["y"], b["x"] + b["w"], b["y"] + b["h"]
        if b["cls"].startswith("core"):
            continue
        for edge in (bx0, bx1):
            if x0 - MIN_BOX < edge < x1 + MIN_BOX and y0 < by1 - 2 and y1 > by0 + 2:
                problems.append(f"text {t['s']!r} within {MIN_BOX}px of box edge x={edge:.0f}")
                break

for i in range(len(texts)):
    for j in range(i + 1, len(texts)):
        a, b = texts[i], texts[j]
        ax0, ax1, ay0, ay1 = tbox(a); bx0, bx1, by0, by1 = tbox(b)
        if min(ax1, bx1) - max(ax0, bx0) > 0 and min(ay1, by1) - max(ay0, by0) > 0:
            problems.append(f"labels {a['s']!r} and {b['s']!r} overlap")

# ================================================================ emit
def n2(v):
    return f"{v:g}"

def esc(t):
    return t.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")

def emit(st):
    out = []
    for w in wires:
        if w["st"] != st: continue
        out.append(f'      <path class="{w["cls"]}" d="{w["d"]}"/>')
    for b in boxes:
        if b["st"] != st: continue
        cls = b["cls"]
        grp = "box" if "overlay" not in cls else "plain"
        rect = (f'<rect x="{n2(b["x"])}" y="{n2(b["y"])}" width="{n2(b["w"])}" '
                f'height="{n2(b["h"])}" rx="{n2(b["rx"])}"/>')
        if b.get("label"):
            ty = b["y"] + b["h"] / 2 + b["size"] * 0.34
            lab = (f'<text x="{n2(b["x"] + b["w"] / 2)}" y="{n2(ty)}" '
                   f'font-size="{n2(b["size"])}" class="{b["lab_cls"]}">{esc(b["label"])}</text>')
            out.append(f'      <g class="{grp} {cls}" style="--i:{b["i"]}">{rect}{lab}</g>')
        else:
            out.append(f'      <g class="{grp} {cls}" style="--i:{b["i"]}">{rect}</g>')
    for t in texts:
        if t["st"] != st or t.get("owner"): continue
        out.append(f'      <text class="{t["cls"]}" x="{n2(t["x"])}" y="{n2(t["y"])}" '
                   f'font-size="{n2(t["size"])}">{esc(t["s"])}</text>')
    return "\n".join(out)

svg = []
for st in range(5):
    body = emit(st)
    persist = " persist" if st <= 2 else ""
    svg.append(f'    <g class="stage{persist}" data-step="{st}">\n{body}\n    </g>')
for arm in ("spread", "packed"):
    rows = []
    for x, y, w_, h_, lab, cx, ty in worker_g[arm]:
        rect = (f'<rect x="{n2(x)}" y="{n2(y)}" width="{n2(w_)}" '
                f'height="{n2(h_)}" rx="11"/>')
        text = f'<text x="{n2(cx)}" y="{n2(ty)}" font-size="13" class="wklabel">{lab}</text>'
        rows.append(f'      <g class="worker">{rect}{text}</g>')
    svg.append(f'    <g class="workers {arm}">\n' + "\n".join(rows) + "\n    </g>")

OUT.write_text("\n".join(svg) + "\n")

print(f"{len(boxes)} boxes, {len(texts)} labels, {len(wires)} wires")
if problems:
    for p in sorted(set(problems)):
        print("  !", p)
else:
    print("clean: no run under %dpx, no label within %dpx of a wire, no label overlaps"
          % (MIN_PARALLEL, MIN_TEXT))
