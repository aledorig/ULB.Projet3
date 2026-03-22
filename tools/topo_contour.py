#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["numpy", "pillow", "matplotlib", "scipy"]
# ///
"""
Topographic contour map generator for cardboard layer cutting.

Generates contour polylines from the terrain height data at configurable
elevation steps, starting from sea level. Outputs a print-ready PDF.

Usage:
    python tools/topo_contour.py
    python tools/topo_contour.py --layers 10 --page-size 256
    python tools/topo_contour.py --seed 4 --layers 15 --page-size 300 --label-every 2

Requirements: numpy, Pillow, matplotlib  (pip install numpy Pillow matplotlib)
"""

import argparse
import os
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.backends.backend_pdf import PdfPages
import matplotlib.patheffects as pe

from scipy.ndimage import gaussian_filter

from terrain_viz import TerrainGenerator, TC


def generate_contour_pdf(args):
    size = args.size
    span = args.world_span
    spacing = span / size

    print(f"seed={args.seed}  grid={size}x{size}  world_span={span}  octaves={args.octaves}")
    print(f"Generating terrain...")

    gen = TerrainGenerator(args.seed, args.octaves)
    grids = gen.generate_all(0.0, 0.0, size, spacing)
    height = grids["final_height"]

    # Determine contour levels: from sea level upward
    h_min = height.min()
    h_max = height.max()

    # Land layers: sea level → max elevation
    land_step = (h_max - TC.SEA_LEVEL) / args.layers if h_max > TC.SEA_LEVEL else 0
    land_levels = [TC.SEA_LEVEL + i * land_step for i in range(args.layers + 1)]
    land_levels = [l for l in land_levels if l <= h_max]

    # Ocean layers: below sea level, same step size (or fewer if ocean is shallow)
    if h_min < TC.SEA_LEVEL:
        ocean_step = land_step if land_step > 0 else (TC.SEA_LEVEL - h_min) / args.layers
        ocean_levels = []
        elev = TC.SEA_LEVEL - ocean_step
        while elev >= h_min:
            ocean_levels.append(elev)
            elev -= ocean_step
        ocean_levels.reverse()  # deepest first → shallowest
    else:
        ocean_levels = []
        ocean_step = 0

    all_levels = ocean_levels + land_levels
    sea_level_index = len(ocean_levels)  # index of sea level in all_levels

    print(f"Elevation range: {h_min:.1f} → {h_max:.1f}")
    print(f"Ocean layers: {len(ocean_levels)} (step: {ocean_step:.1f})")
    print(f"Land layers:  {len(land_levels)} (step: {land_step:.1f})")
    print(f"Total layers: {len(all_levels)}")

    # Smooth the heightmap to remove tiny noise blobs
    # sigma in pixels — controls how aggressively small features are removed
    sigma = args.smooth
    if sigma > 0:
        height = gaussian_filter(height, sigma=sigma)
        print(f"Smoothing: sigma={sigma} px")

    # Page size in mm → inches for matplotlib
    page_mm = args.page_size
    page_in = page_mm / 25.4

    # World coordinate axes
    x = np.linspace(0, span, size)
    z = np.linspace(0, span, size)

    # Color map for layers (brown-ish topo style)
    cmap = matplotlib.colormaps["terrain"]
    norm = plt.Normalize(vmin=h_min, vmax=h_max)

    # ── Create the PDF ──────────────────────────────────────────────────────
    out_dir = args.out_dir
    if out_dir is None:
        out_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "terrain_viz")
    os.makedirs(out_dir, exist_ok=True)

    pdf_path = os.path.join(out_dir, "topo_contour.pdf")

    with PdfPages(pdf_path) as pdf:
        # ── Page 1: Full topographic overview ───────────────────────────────
        fig, ax = plt.subplots(figsize=(page_in, page_in))
        fig.subplots_adjust(left=0.08, right=0.92, top=0.92, bottom=0.08)

        # Shaded relief background (light)
        ax.imshow(
            height, extent=[0, span, span, 0],
            cmap="Greys_r", alpha=0.15, interpolation="bilinear",
        )

        # Sea level fill
        ax.contourf(
            x, z, height, levels=[-9999, TC.SEA_LEVEL],
            colors=["#b0d4f1"], alpha=0.5,
        )

        # Ocean contour lines (blue)
        if ocean_levels:
            cs_ocean = ax.contour(
                x, z, height, levels=ocean_levels,
                colors="steelblue", linewidths=0.6,
            )
            bold_ocean = ocean_levels[::args.label_every]
            if bold_ocean:
                cs_ocean_bold = ax.contour(
                    x, z, height, levels=bold_ocean,
                    colors="steelblue", linewidths=1.4,
                )
                labels_o = ax.clabel(
                    cs_ocean_bold, inline=True, fontsize=5,
                    fmt=lambda v: f"{v:.0f}", colors="steelblue",
                )
                for lbl in labels_o:
                    lbl.set_path_effects([pe.withStroke(linewidth=2, foreground="white")])

        # Land contour lines (brown)
        if land_levels:
            cs_land = ax.contour(
                x, z, height, levels=land_levels,
                colors="saddlebrown", linewidths=0.6,
            )
            bold_land = land_levels[::args.label_every]
            if bold_land:
                cs_land_bold = ax.contour(
                    x, z, height, levels=bold_land,
                    colors="saddlebrown", linewidths=1.4,
                )
                labels_l = ax.clabel(
                    cs_land_bold, inline=True, fontsize=5,
                    fmt=lambda v: f"{v:.0f}", colors="saddlebrown",
                )
                for lbl in labels_l:
                    lbl.set_path_effects([pe.withStroke(linewidth=2, foreground="white")])

        # Sea-level contour highlighted
        cs_sea = ax.contour(
            x, z, height, levels=[TC.SEA_LEVEL],
            colors="navy", linewidths=2.0,
        )
        ax.clabel(cs_sea, inline=True, fontsize=6, fmt="SEA 0", colors="navy")

        ax.set_aspect("equal")
        ax.set_xlabel("X (world units)")
        ax.set_ylabel("Z (world units)")
        ax.set_title(
            f"Topographic Contour Map  —  seed {args.seed}\n"
            f"{len(all_levels)} layers ({len(ocean_levels)} ocean + {len(land_levels)} land), "
            f"page {page_mm}×{page_mm} mm",
            fontsize=9,
        )

        # Legend / scale info
        ax.annotate(
            f"Sea level = {TC.SEA_LEVEL:.0f}\n"
            f"Min depth = {h_min:.1f}\n"
            f"Max elevation = {h_max:.1f}\n"
            f"Ocean step = {ocean_step:.1f} units\n"
            f"Land step = {land_step:.1f} units\n"
            f"Total layers = {len(all_levels)}",
            xy=(0.01, 0.01), xycoords="axes fraction",
            fontsize=6, family="monospace",
            bbox=dict(boxstyle="round,pad=0.3", fc="white", ec="gray", alpha=0.8),
        )

        pdf.savefig(fig, dpi=args.dpi)
        plt.close(fig)
        print(f"  Page 1: overview contour map")

        # ── Per-layer pages: individual contour polylines for cutting ───────
        for i, level in enumerate(all_levels):
            is_ocean = level < TC.SEA_LEVEL
            is_sea = level == TC.SEA_LEVEL
            zone = "OCEAN" if is_ocean else ("SEA LEVEL" if is_sea else "LAND")
            line_color = "steelblue" if is_ocean else "black"
            step = ocean_step if is_ocean else land_step

            fig, ax = plt.subplots(figsize=(page_in, page_in))
            fig.subplots_adjust(left=0.05, right=0.95, top=0.92, bottom=0.05)

            # Draw the single contour for this layer
            cs_layer = ax.contour(
                x, z, height, levels=[level],
                colors=line_color, linewidths=1.0,
            )

            # Also draw the outline of the layer below for alignment reference
            if i > 0:
                cs_ref = ax.contour(
                    x, z, height, levels=[all_levels[i - 1]],
                    colors="lightgray", linewidths=0.5, linestyles="dashed",
                )

            ax.set_aspect("equal")
            ax.set_xlim(0, span)
            ax.set_ylim(span, 0)

            layer_label = f"Layer {i} ({zone})"
            elev_label = f"Elevation: {level:.1f}"

            ax.set_title(
                f"{layer_label}  —  {elev_label}\n"
                f"Cut this contour from {'blue' if is_ocean else 'brown'} cardboard sheet #{i}",
                fontsize=8,
            )

            # Corner annotations for assembly
            ax.annotate(
                f"Layer {i}/{len(all_levels)-1}\n"
                f"Zone: {zone}\n"
                f"Elev: {level:.1f}\n"
                f"Step: {step:.1f}",
                xy=(0.01, 0.01), xycoords="axes fraction",
                fontsize=6, family="monospace",
                bbox=dict(boxstyle="round,pad=0.3", fc="white", ec="gray", alpha=0.8),
            )

            # Registration marks (corners) for alignment when stacking
            mark_size = span * 0.015
            for cx, cz in [(mark_size, mark_size), (span - mark_size, mark_size),
                           (mark_size, span - mark_size), (span - mark_size, span - mark_size)]:
                ax.plot(cx, cz, "+", color="black", markersize=6, markeredgewidth=0.5)

            pdf.savefig(fig, dpi=args.dpi)
            plt.close(fig)

        print(f"  Pages 2-{len(all_levels)+1}: individual layer cut sheets")

    print(f"\nPDF saved: {pdf_path}")
    print(f"  {len(all_levels)} layers ({len(ocean_levels)} ocean + {len(land_levels)} land)")
    print(f"  Elevation: {all_levels[0]:.1f} → {all_levels[-1]:.1f}")
    print(f"  Page size: {page_mm} x {page_mm} mm")


def main():
    p = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    p.add_argument("--seed",        type=int,   default=1010,     help="World seed (default: 4)")
    p.add_argument("--size",        type=int,   default=512,   help="Grid resolution in pixels (default: 512)")
    p.add_argument("--world-span",  type=float, default=2000,  help="World units covered (default: 3000)")
    p.add_argument("--octaves",     type=int,   default=6,     help="Noise octaves (default: 6)")
    p.add_argument("--layers",      type=int,   default=10,    help="Number of elevation layers/steps (default: 10)")
    p.add_argument("--page-size",   type=float, default=256,   help="Output page size in mm (default: 256)")
    p.add_argument("--label-every", type=int,   default=2,     help="Bold+label every N-th contour on overview (default: 2)")
    p.add_argument("--smooth",       type=float, default=7.0,  help="Gaussian smoothing sigma in pixels to remove noise blobs (default: 3.0, 0=off)")
    p.add_argument("--dpi",         type=int,   default=300,   help="PDF resolution (default: 300)")
    p.add_argument("--out-dir",     type=str,   default=None,  help="Output directory (default: tools/terrain_viz/)")
    args = p.parse_args()

    generate_contour_pdf(args)


if __name__ == "__main__":
    main()
