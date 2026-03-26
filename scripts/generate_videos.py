"""
Vibeslol Seed Video Generator
Generates 5 unique, satisfying 6-second animations for the feed.
Each video is a different mesmerizing simulation.
"""

import cv2
import numpy as np
import math
import os

WIDTH, HEIGHT = 720, 1280
FPS = 60
DURATION = 6
TOTAL_FRAMES = FPS * DURATION
OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "..", "ios", "Vibeslol", "Resources", "Videos")

PURPLE = (0xFF, 0x49, 0x94)  # #9449FF in BGR
CYAN = (0xFF, 0xCC, 0x00)
MAGENTA = (0xFF, 0x00, 0xFF)
WHITE = (255, 255, 255)
BG = (10, 5, 15)


def make_writer(name):
    path = os.path.join(OUTPUT_DIR, name)
    fourcc = cv2.VideoWriter_fourcc(*"mp4v")
    return cv2.VideoWriter(path, fourcc, FPS, (WIDTH, HEIGHT)), path


def video1_bouncing_balls():
    """Balls bounce in a cylinder. Every wall hit = multiply."""
    print("Generating: Bouncing balls multiply on collision...")
    writer, path = make_writer("video1.mp4")

    balls = [{"x": WIDTH // 2, "y": HEIGHT // 2, "vx": 4.0, "vy": 3.0, "r": 12,
              "color": PURPLE}]
    center_x, center_y = WIDTH // 2, HEIGHT // 2
    cylinder_r = 280

    for frame in range(TOTAL_FRAMES):
        img = np.full((HEIGHT, WIDTH, 3), BG, dtype=np.uint8)

        # Draw cylinder
        cv2.circle(img, (center_x, center_y), cylinder_r, PURPLE, 2)

        new_balls = []
        for b in balls:
            b["x"] += b["vx"]
            b["y"] += b["vy"]

            # Check cylinder collision
            dx = b["x"] - center_x
            dy = b["y"] - center_y
            dist = math.sqrt(dx * dx + dy * dy)

            if dist + b["r"] >= cylinder_r:
                # Reflect velocity
                nx, ny = dx / dist, dy / dist
                dot = b["vx"] * nx + b["vy"] * ny
                b["vx"] -= 2 * dot * nx
                b["vy"] -= 2 * dot * ny
                b["x"] = center_x + nx * (cylinder_r - b["r"] - 1)
                b["y"] = center_y + ny * (cylinder_r - b["r"] - 1)

                # Spawn new ball if under limit
                if len(balls) + len(new_balls) < 80:
                    angle = math.atan2(ny, nx) + math.pi * 0.7
                    speed = math.sqrt(b["vx"] ** 2 + b["vy"] ** 2) * 0.9
                    hue = (frame * 3) % 180
                    color_hsv = np.uint8([[[hue, 255, 255]]])
                    color_bgr = cv2.cvtColor(color_hsv, cv2.COLOR_HSV2BGR)[0][0]
                    new_balls.append({
                        "x": b["x"], "y": b["y"],
                        "vx": math.cos(angle) * speed,
                        "vy": math.sin(angle) * speed,
                        "r": max(4, b["r"] - 1),
                        "color": tuple(int(c) for c in color_bgr)
                    })

            # Draw ball with glow
            cv2.circle(img, (int(b["x"]), int(b["y"])), b["r"] + 6,
                       (*b["color"][:3],), -1)
            overlay = img.copy()
            cv2.circle(overlay, (int(b["x"]), int(b["y"])), b["r"] + 6,
                       b["color"], -1)
            cv2.addWeighted(overlay, 0.3, img, 0.7, 0, img)
            cv2.circle(img, (int(b["x"]), int(b["y"])), b["r"],
                       b["color"], -1)

        balls.extend(new_balls)
        writer.write(img)

    writer.release()
    print(f"  -> {path}")


def video2_gravity_particles():
    """Particles fall like rain then swirl into a vortex."""
    print("Generating: Gravity particle vortex...")
    writer, path = make_writer("video2.mp4")

    num = 300
    px = np.random.uniform(0, WIDTH, num).astype(np.float64)
    py = np.random.uniform(-HEIGHT, 0, num).astype(np.float64)
    vx = np.random.uniform(-1, 1, num).astype(np.float64)
    vy = np.random.uniform(1, 4, num).astype(np.float64)
    hues = np.random.randint(120, 170, num)  # Cyan-purple range

    cx, cy = WIDTH // 2, HEIGHT // 2

    for frame in range(TOTAL_FRAMES):
        img = np.full((HEIGHT, WIDTH, 3), BG, dtype=np.uint8)
        t = frame / TOTAL_FRAMES

        # Gravity + vortex pull increases over time
        vortex_strength = t * 3.0
        for i in range(num):
            dx = cx - px[i]
            dy = cy - py[i]
            dist = max(math.sqrt(dx * dx + dy * dy), 1)

            # Radial pull + tangential swirl
            vx[i] += (dx / dist) * vortex_strength * 0.05
            vy[i] += (dy / dist) * vortex_strength * 0.05
            vx[i] += (-dy / dist) * vortex_strength * 0.03
            vy[i] += (dx / dist) * vortex_strength * 0.03

            vy[i] += 0.1  # gravity

            px[i] += vx[i]
            py[i] += vy[i]

            # Wrap around
            if py[i] > HEIGHT + 20:
                py[i] = -10
                px[i] = np.random.uniform(0, WIDTH)

            # Draw with trail
            size = max(2, int(4 - t * 2))
            hue = int(hues[i] + frame * 0.5) % 180
            color_hsv = np.uint8([[[hue, 220, 255]]])
            color_bgr = cv2.cvtColor(color_hsv, cv2.COLOR_HSV2BGR)[0][0]
            cv2.circle(img, (int(px[i]), int(py[i])), size,
                       tuple(int(c) for c in color_bgr), -1)

        writer.write(img)

    writer.release()
    print(f"  -> {path}")


def video3_pulse_rings():
    """Expanding rings pulse outward from center like a heartbeat."""
    print("Generating: Pulse rings...")
    writer, path = make_writer("video3.mp4")

    rings = []
    cx, cy = WIDTH // 2, HEIGHT // 2

    for frame in range(TOTAL_FRAMES):
        img = np.full((HEIGHT, WIDTH, 3), BG, dtype=np.uint8)
        t = frame / FPS

        # Spawn ring every ~0.4 seconds
        if frame % 24 == 0:
            hue = (frame * 2) % 180
            rings.append({"r": 0, "hue": hue, "alpha": 1.0})

        alive = []
        for ring in rings:
            ring["r"] += 4
            ring["alpha"] -= 0.008

            if ring["alpha"] > 0:
                thickness = max(1, int(3 * ring["alpha"]))
                color_hsv = np.uint8([[[ring["hue"], 200, int(255 * ring["alpha"])]]])
                color_bgr = cv2.cvtColor(color_hsv, cv2.COLOR_HSV2BGR)[0][0]
                cv2.circle(img, (cx, cy), int(ring["r"]),
                           tuple(int(c) for c in color_bgr), thickness,
                           cv2.LINE_AA)
                alive.append(ring)

        rings = alive

        # Center dot pulses
        pulse = abs(math.sin(t * math.pi * 2.5))
        dot_r = int(8 + pulse * 12)
        cv2.circle(img, (cx, cy), dot_r, PURPLE, -1, cv2.LINE_AA)

        writer.write(img)

    writer.release()
    print(f"  -> {path}")


def video4_dna_helix():
    """Rotating double helix DNA strand with glowing nodes."""
    print("Generating: DNA helix...")
    writer, path = make_writer("video4.mp4")

    for frame in range(TOTAL_FRAMES):
        img = np.full((HEIGHT, WIDTH, 3), BG, dtype=np.uint8)
        t = frame / FPS

        num_nodes = 40
        for i in range(num_nodes):
            y = int((i / num_nodes) * HEIGHT * 1.2 - HEIGHT * 0.1)
            phase = t * 3 + i * 0.3

            x1 = int(WIDTH // 2 + math.sin(phase) * 150)
            x2 = int(WIDTH // 2 + math.sin(phase + math.pi) * 150)

            # Depth-based sizing
            z1 = math.cos(phase)
            z2 = math.cos(phase + math.pi)
            r1 = int(6 + z1 * 4)
            r2 = int(6 + z2 * 4)

            # Colors shift along strand
            hue1 = int(130 + i * 1.2) % 180  # Purple range
            hue2 = int(90 + i * 1.2) % 180   # Cyan range

            c1_hsv = np.uint8([[[hue1, 230, int(180 + z1 * 75)]]])
            c2_hsv = np.uint8([[[hue2, 230, int(180 + z2 * 75)]]])
            c1 = tuple(int(c) for c in cv2.cvtColor(c1_hsv, cv2.COLOR_HSV2BGR)[0][0])
            c2 = tuple(int(c) for c in cv2.cvtColor(c2_hsv, cv2.COLOR_HSV2BGR)[0][0])

            # Connect strands periodically
            if i % 4 == 0:
                cv2.line(img, (x1, y), (x2, y), (40, 30, 50), 1, cv2.LINE_AA)

            # Draw nodes (back first, then front)
            if z1 < z2:
                cv2.circle(img, (x1, y), r1, c1, -1, cv2.LINE_AA)
                cv2.circle(img, (x2, y), r2, c2, -1, cv2.LINE_AA)
            else:
                cv2.circle(img, (x2, y), r2, c2, -1, cv2.LINE_AA)
                cv2.circle(img, (x1, y), r1, c1, -1, cv2.LINE_AA)

        writer.write(img)

    writer.release()
    print(f"  -> {path}")


def video5_fractal_tree():
    """Growing fractal tree that branches and sways."""
    print("Generating: Fractal tree...")
    writer, path = make_writer("video5.mp4")

    def draw_branch(img, x, y, angle, length, depth, t, max_depth):
        if depth > max_depth or length < 3:
            return

        # Progress controls growth
        progress = min(1.0, t / (0.3 + depth * 0.4))
        if progress <= 0:
            return

        current_len = length * progress
        sway = math.sin(t * 2 + depth * 0.5) * (depth * 2)
        branch_angle = angle + math.radians(sway)

        x2 = x + math.cos(branch_angle) * current_len
        y2 = y + math.sin(branch_angle) * current_len

        # Color: trunk=brown, tips=purple/cyan
        blend = min(1.0, depth / max_depth)
        hue = int(130 * blend + 15 * (1 - blend))
        brightness = int(100 + 155 * (1 - blend * 0.3))
        color_hsv = np.uint8([[[hue, 180, brightness]]])
        color = tuple(int(c) for c in cv2.cvtColor(color_hsv, cv2.COLOR_HSV2BGR)[0][0])

        thickness = max(1, int((max_depth - depth + 1) * 1.5))
        cv2.line(img, (int(x), int(y)), (int(x2), int(y2)), color, thickness, cv2.LINE_AA)

        if progress >= 0.8:
            spread = 25 + t * 2
            draw_branch(img, x2, y2, angle - math.radians(spread),
                       length * 0.7, depth + 1, t - 0.3, max_depth)
            draw_branch(img, x2, y2, angle + math.radians(spread),
                       length * 0.7, depth + 1, t - 0.3, max_depth)

    for frame in range(TOTAL_FRAMES):
        img = np.full((HEIGHT, WIDTH, 3), BG, dtype=np.uint8)
        t = frame / FPS

        draw_branch(img, WIDTH // 2, HEIGHT - 200,
                   -math.pi / 2, 200, 0, t, 10)

        writer.write(img)

    writer.release()
    print(f"  -> {path}")


if __name__ == "__main__":
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    print(f"Generating 5 seed videos at {WIDTH}x{HEIGHT} @ {FPS}fps, {DURATION}s each\n")

    video1_bouncing_balls()
    video2_gravity_particles()
    video3_pulse_rings()
    video4_dna_helix()
    video5_fractal_tree()

    # Re-encode with ffmpeg for iOS compatibility (H.264 baseline)
    print("\nRe-encoding for iOS compatibility...")
    for i in range(1, 6):
        src = os.path.join(OUTPUT_DIR, f"video{i}.mp4")
        tmp = os.path.join(OUTPUT_DIR, f"video{i}_tmp.mp4")
        os.rename(src, tmp)
        os.system(
            f'/opt/homebrew/bin/ffmpeg -y -i "{tmp}" -c:v libx264 -profile:v baseline '
            f'-level 3.1 -pix_fmt yuv420p -crf 23 -preset fast -an "{src}" '
            f'-loglevel error'
        )
        os.remove(tmp)
        size = os.path.getsize(src) / (1024 * 1024)
        print(f"  video{i}.mp4: {size:.1f}MB")

    print("\nDone! 🎬")
