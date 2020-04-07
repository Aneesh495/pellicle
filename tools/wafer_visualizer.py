#!/usr/bin/env python3
"""
Pellicle 300mm Silicon Wafer Die Map & Topography Visualizer
Renders ANSI terminal representations and exports vector SVG maps of the exposure layout.
"""

import math
import sys
import os

WAFER_RADIUS_MM = 150.0
EDGE_EXCLUSION_MM = 3.0
USABLE_RADIUS_MM = WAFER_RADIUS_MM - EDGE_EXCLUSION_MM

DIE_WIDTH_MM = 26.0
DIE_HEIGHT_MM = 33.0

def generate_wafer_layout():
    dies = []
    idx = 1
    for col in range(-5, 6):
        cx = col * DIE_WIDTH_MM
        # Alternate scan direction by column
        scan_dir = "+Y" if abs(col) % 2 == 0 else "-Y"
        for row in range(-4, 5):
            cy = row * DIE_HEIGHT_MM
            # Check 4 corners
            hw = DIE_WIDTH_MM / 2.0
            hh = DIE_HEIGHT_MM / 2.0
            r_lim = USABLE_RADIUS_MM
            c1 = (cx - hw)**2 + (cy - hh)**2 <= r_lim**2
            c2 = (cx + hw)**2 + (cy - hh)**2 <= r_lim**2
            c3 = (cx - hw)**2 + (cy + hh)**2 <= r_lim**2
            c4 = (cx + hw)**2 + (cy + hh)**2 <= r_lim**2
            if c1 and c2 and c3 and c4:
                # Simulated leveling residual height (nm)
                z_topo = 15.0 * math.sin(cx / 40.0) * math.cos(cy / 40.0) + (cx**2 + cy**2) * 0.0005
                dies.append({
                    'index': idx,
                    'col': col,
                    'row': row,
                    'x': cx,
                    'y': cy,
                    'dir': scan_dir,
                    'z_topo': z_topo
                })
                idx += 1
    return dies

def render_terminal_map(dies):
    grid_size = 25
    canvas = [[' ' for _ in range(grid_size)] for _ in range(grid_size)]
    
    # Draw circular wafer boundary
    for i in range(grid_size):
        for j in range(grid_size):
            x = (j - grid_size / 2.0) * (WAFER_RADIUS_MM / (grid_size / 2.0))
            y = (grid_size / 2.0 - i) * (WAFER_RADIUS_MM / (grid_size / 2.0))
            r = math.sqrt(x*x + y*y)
            if abs(r - WAFER_RADIUS_MM) < 8.0:
                canvas[i][j] = '.'
    
    # Mark dies
    for d in dies:
        j = int(grid_size / 2.0 + (d['x'] / WAFER_RADIUS_MM) * (grid_size / 2.0 - 1))
        i = int(grid_size / 2.0 - (d['y'] / WAFER_RADIUS_MM) * (grid_size / 2.0 - 1))
        if 0 <= i < grid_size and 0 <= j < grid_size:
            canvas[i][j] = '#'
            
    print("================================================================================")
    print("  PELLICLE 300mm Silicon Wafer Exposure Die Grid (57 Active Dies)")
    print("================================================================================")
    for row in canvas:
        print("  " + "".join(row))
    print("================================================================================")
    print("  Legend: [.] 300mm Wafer Edge (3mm Exclusion) | [#] Active 26x33mm Die Field")
    print("================================================================================")

def export_svg(dies, filepath):
    width = 600
    height = 600
    scale = 1.8 # pixels per mm
    cx = width / 2.0
    cy = height / 2.0
    
    svg = [
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}" width="{width}" height="{height}">',
        '<rect width="100%" height="100%" fill="#12151c"/>',
        f'<circle cx="{cx}" cy="{cy}" r="{WAFER_RADIUS_MM * scale}" fill="#1e2330" stroke="#4a5568" stroke-width="2"/>',
        f'<circle cx="{cx}" cy="{cy}" r="{USABLE_RADIUS_MM * scale}" fill="none" stroke="#2b6cb0" stroke-width="1" stroke-dasharray="4,4"/>',
    ]
    
    for d in dies:
        dx = cx + (d['x'] - DIE_WIDTH_MM / 2.0) * scale
        dy = cy - (d['y'] + DIE_HEIGHT_MM / 2.0) * scale
        dw = DIE_WIDTH_MM * scale
        dh = DIE_HEIGHT_MM * scale
        # Color based on topography height
        hue = 180 + int(d['z_topo'] * 3.0)
        svg.append(f'<rect x="{dx:.1f}" y="{dy:.1f}" width="{dw:.1f}" height="{dh:.1f}" fill="hsl({hue}, 70%, 45%)" stroke="#ffffff" stroke-width="0.8" opacity="0.85"/>')
        svg.append(f'<text x="{dx + dw/2.0:.1f}" y="{dy + dh/2.0 + 3.0:.1f}" font-family="monospace" font-size="8" fill="#ffffff" text-anchor="middle">{d["index"]}</text>')
        
    # Wafer notch at bottom
    svg.append(f'<polygon points="{cx-6},{cy + WAFER_RADIUS_MM*scale} {cx+6},{cy + WAFER_RADIUS_MM*scale} {cx},{cy + WAFER_RADIUS_MM*scale - 8}" fill="#e2e8f0"/>')
    svg.append('</svg>')
    
    with open(filepath, 'w') as f:
        f.write("\n".join(svg))
    print(f"Exported wafer map SVG to: {filepath}")

def main():
    dies = generate_wafer_layout()
    render_terminal_map(dies)
    out_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'docs'))
    os.makedirs(out_dir, exist_ok=True)
    export_svg(dies, os.path.join(out_dir, 'wafer_map.svg'))

if __name__ == '__main__':
    main()
