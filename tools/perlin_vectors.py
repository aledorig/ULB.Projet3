#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.11"
# dependencies = ["numpy", "matplotlib"]
# ///
"""
Perlin noise gradient-vector visualizer.

Draws a small grid with gradient vectors at every lattice corner and a
sample dot at the centre of every cell.  Two modes:

  --gradients random  (default)
      Each corner gets a unit vector at a truly random angle derived from
      the seed + position.  This matches the standard pedagogical diagram
      (like Wikipedia's Perlin-noise illustration) where arrows can point
      in any direction.

  --gradients godot
      Uses the exact 16-direction gradient table from perlin_noise.gd.
      Arrows are always at multiples of 45° – technically correct for the
      engine, but less useful for a general explanation.

Optionally highlights one or more cells with red arrows (showing the four
corner gradients that contribute to the interpolation at the cell centre).

Exports to PDF at a precise physical size (mm).

Usage
-----
    uv run tools/perlin_vectors.py
    uv run tools/perlin_vectors.py --grid 6 --seed 42 --size 200x200
    uv run tools/perlin_vectors.py --grid 10 --size 250x250 --out perlin.pdf
    uv run tools/perlin_vectors.py --highlight 2,1 5,3
    uv run tools/perlin_vectors.py --gradients godot   # exact Godot table
"""

import argparse
import math
import os
import struct
import hashlib
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.backends.backend_pdf import PdfPages

# ---------------------------------------------------------------------------
# Godot PCG32 RNG (used only for --gradients godot)
# ---------------------------------------------------------------------------
class GodotRNG:
    _MUL = 6364136223846793005
    _INC = 1442695040888963407
    _M64 = 0xFFFFFFFFFFFFFFFF
    _M32 = 0xFFFFFFFF

    def __init__(self, seed: int):
        self.state = int(seed) & self._M64

    def _rand(self) -> int:
        old = self.state
        self.state = (old * self._MUL + self._INC) & self._M64
        xsh = int(((old >> 18) ^ old) >> 27) & self._M32
        rot = int(old >> 59)
        return int(((xsh >> rot) | (xsh << ((-rot) & 31))) & self._M32)

    def randf(self) -> float:
        return self._rand() / 4294967295.0

    def randi_range(self, lo: int, hi: int) -> int:
        if lo == hi:
            return lo
        return lo + self._rand() % (hi - lo + 1)


# ---------------------------------------------------------------------------
# Godot gradient table (16 directions, all multiples of 45°)
# ---------------------------------------------------------------------------
_PGRAD_X = np.array([ 1.,-1., 1.,-1., 1.,-1., 1.,-1., 0., 0., 0., 0., 1., 0.,-1., 0.], dtype=np.float64)
_PGRAD_Z = np.array([ 0., 0., 0., 0., 1., 1.,-1.,-1., 1., 1.,-1.,-1., 0., 1., 0.,-1.], dtype=np.float64)


def build_godot_perm(seed: int):
    rng = GodotRNG(seed)
    x_off = rng.randf() * 256.0
    z_off = rng.randf() * 256.0
    p = list(range(256))
    for i in range(256):
        j = rng.randi_range(i, 255)
        p[i], p[j] = p[j], p[i]
    perm = np.array(p + p, dtype=np.int64)
    return perm, x_off, z_off


def godot_gradient(perm, lx: int, lz: int):
    gi = int(perm[(perm[lx & 255] + (lz & 255)) & 255]) & 15
    return float(_PGRAD_X[gi]), float(_PGRAD_Z[gi])


# ---------------------------------------------------------------------------
# Random-angle gradients (pedagogical – any direction)
# ---------------------------------------------------------------------------
def random_gradient(seed: int, ix: int, iz: int):
    """
    Deterministic random unit vector for lattice corner (ix, iz).
    Uses a SHA-256 hash of (seed, ix, iz) to get a reproducible angle.
    """
    raw = struct.pack(">iii", seed & 0xFFFFFFFF, ix & 0xFFFFFFFF, iz & 0xFFFFFFFF)
    digest = hashlib.sha256(raw).digest()
    # Take first 4 bytes as a uint32 → map to [0, 2π)
    u32 = int.from_bytes(digest[:4], "big")
    angle = u32 / 4294967296.0 * 2.0 * math.pi
    return math.cos(angle), math.sin(angle)


# ---------------------------------------------------------------------------
# Grid drawing
# ---------------------------------------------------------------------------
MM_PER_INCH = 25.4


def mm_to_inch(mm: float) -> float:
    return mm / MM_PER_INCH


def draw_perlin_grid(
    ax,
    seed: int,
    grid_w: int,
    grid_h: int,
    gradient_mode: str = "random",   # "random" | "godot"
    highlight_cells=None,
    arrow_scale: float = 0.40,
    cell_color: str = "#e8eaf6",
    grid_color: str = "#1a1a2e",
    arrow_color: str = "#1a1a2e",
    highlight_color: str = "#e53935",
    dot_color: str = "#1a1a2e",
):
    if highlight_cells is None:
        highlight_cells = []

    # Build Godot perm table only when needed
    godot_perm = godot_x_off = godot_z_off = None
    if gradient_mode == "godot":
        godot_perm, godot_x_off, godot_z_off = build_godot_perm(seed)

    # --- background ---
    for row in range(grid_h):
        for col in range(grid_w):
            rect = mpatches.FancyBboxPatch(
                (col, row), 1, 1,
                boxstyle="square,pad=0",
                linewidth=0,
                facecolor=cell_color,
            )
            ax.add_patch(rect)

    # --- grid lines ---
    for col in range(grid_w + 1):
        ax.plot([col, col], [0, grid_h], color=grid_color, linewidth=1.4, zorder=2)
    for row in range(grid_h + 1):
        ax.plot([0, grid_w], [row, row], color=grid_color, linewidth=1.4, zorder=2)

    # --- highlighted corners ---
    highlighted = set()
    for (hcol, hrow) in highlight_cells:
        for dc in (0, 1):
            for dr in (0, 1):
                highlighted.add((hcol + dc, hrow + dr))

    # --- gradient arrows ---
    for iz in range(grid_h + 1):
        for ix in range(grid_w + 1):
            if gradient_mode == "godot":
                lx = int(math.floor(ix + godot_x_off)) & 255
                lz = int(math.floor(iz + godot_z_off)) & 255
                gx, gz = godot_gradient(godot_perm, lx, lz)
            else:
                gx, gz = random_gradient(seed, ix, iz)

            is_hi = (ix, iz) in highlighted
            color = highlight_color if is_hi else arrow_color
            zorder = 5 if is_hi else 3
            lw = 2.0 if is_hi else 1.5

            if gx == 0.0 and gz == 0.0:
                ax.plot(ix, iz, "o", color=color, markersize=3, zorder=zorder)
                continue

            ax.annotate(
                "",
                xy=(ix + gx * arrow_scale, iz + gz * arrow_scale),
                xytext=(ix, iz),
                arrowprops=dict(
                    arrowstyle="->,head_width=0.22,head_length=0.16",
                    color=color,
                    linewidth=lw,
                ),
                zorder=zorder,
            )

    # --- centre dots ---
    for row in range(grid_h):
        for col in range(grid_w):
            ax.plot(col + 0.5, row + 0.5, "o",
                    color=dot_color, markersize=4, zorder=4)

    # --- axes ---
    ax.set_xlim(-0.6, grid_w + 0.6)
    ax.set_ylim(-0.6, grid_h + 0.6)
    ax.set_aspect("equal")
    ax.axis("off")


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def parse_args():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--seed", type=int, default=1337,
                   help="RNG seed (default: 1337)")
    p.add_argument("--grid", type=str, default="10x10",
                   help="Grid WxH in cells, e.g. 10x10 or just 8 (default: 10x10)")
    p.add_argument("--size", type=str, default="250x250",
                   help="Physical output size in mm WxH (default: 250x250)")
    p.add_argument("--gradients", choices=["random", "godot"], default="random",
                   help="'random' = continuous angles for pedagogy (default); "
                        "'godot' = exact 16-direction table from the engine")
    p.add_argument("--highlight", nargs="*", metavar="COL,ROW",
                   help="Cells to highlight with red arrows (e.g. 2,1 5,3)")
    p.add_argument("--out", type=str, default="",
                   help="Output PDF path (default: tools/terrain_viz/perlin_vectors.pdf)")
    p.add_argument("--dpi", type=int, default=150,
                   help="Raster DPI for screen preview (PDF is vector; default: 150)")
    p.add_argument("--no-preview", action="store_true",
                   help="Skip the interactive matplotlib window")
    return p.parse_args()


def parse_two_ints(s: str, sep: str = "x"):
    parts = s.split(sep)
    if len(parts) == 1:
        v = int(parts[0])
        return v, v
    return int(parts[0]), int(parts[1])


def main():
    args = parse_args()

    grid_w, grid_h = parse_two_ints(args.grid)
    size_w_mm, size_h_mm = parse_two_ints(args.size)
    fig_w_in = mm_to_inch(size_w_mm)
    fig_h_in = mm_to_inch(size_h_mm)

    highlight_cells = []
    if args.highlight:
        for token in args.highlight:
            col_s, row_s = token.split(",")
            highlight_cells.append((int(col_s), int(row_s)))

    fig, ax = plt.subplots(figsize=(fig_w_in, fig_h_in))
    fig.patch.set_facecolor("#f0f0f8")
    ax.set_facecolor("#f0f0f8")

    draw_perlin_grid(
        ax,
        seed=args.seed,
        grid_w=grid_w,
        grid_h=grid_h,
        gradient_mode=args.gradients,
        highlight_cells=highlight_cells,
    )

    mode_label = "random angles" if args.gradients == "random" else "Godot 16-dir table"
    title = (f"Perlin noise – gradient vectors  "
             f"(seed={args.seed}, grid={grid_w}×{grid_h}, {mode_label})")
    ax.set_title(title, fontsize=9, pad=6, color="#1a1a2e")

    fig.tight_layout(pad=0.4)

    out_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "terrain_viz")
    out_path = args.out if args.out else os.path.join(out_dir, "perlin_vectors.pdf")
    os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)

    with PdfPages(out_path) as pdf:
        fig.set_size_inches(fig_w_in, fig_h_in)
        pdf.savefig(fig, dpi=args.dpi, bbox_inches="tight",
                    facecolor=fig.get_facecolor())
        d = pdf.infodict()
        d["Title"] = title
        d["Subject"] = "Perlin noise gradient vectors"

    print(f"Saved → {os.path.abspath(out_path)}")
    print(f"  Physical size : {size_w_mm} mm × {size_h_mm} mm")
    print(f"  Grid          : {grid_w} × {grid_h} cells")
    print(f"  Gradients     : {args.gradients}")

    if not args.no_preview:
        plt.show()


if __name__ == "__main__":
    main()
