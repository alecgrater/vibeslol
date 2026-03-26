"""
Vibeslol Seed Video Generator
Generates 5 unique, satisfying 6-second animations for the feed.
Uses raw frame pipe to ffmpeg for reliable H.264 encoding.
"""

import cv2
import numpy as np
import math
import os
import subprocess
import struct

WIDTH, HEIGHT = 720, 1280
FPS = 60
DURATION = 6
TOTAL_FRAMES = FPS * DURATION
OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "..", "ios", "Vibeslol", "Resources", "Videos")

BG = (5, 3, 8)  # Near-black in BGR


def make_ffmpeg_writer(name):
    """Create an ffmpeg process that accepts raw BGR frames via stdin."""
    path = os.path.join(OUTPUT_DIR, name)
    cmd = [
        "/opt/homebrew/bin/ffmpeg", "-y",
        "-f", "rawvideo",
        "-vcodec", "rawvideo",
        "-pix_fmt", "bgr24",
        "-s", f"{WIDTH}x{HEIGHT}",
        "-r", str(FPS),
        "-i", "-",
        "-c:v", "libx264",
        "-profile:v", "baseline",
        "-level", "3.1",
        "-pix_fmt", "yuv420p",
        "-crf", "18",
        "-preset", "fast",
        "-an",
        "-loglevel", "error",
        path,
    ]
    proc = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    return proc, path


def write_frame(proc, img):
    """Write a BGR numpy array frame to the ffmpeg process."""
    proc.stdin.write(img.tobytes())


def finish_writer(proc):
    """Close the ffmpeg process."""
    proc.stdin.close()
    proc.wait()


def hsv_to_bgr(h, s, v):
    """Convert HSV (0-179, 0-255, 0-255) to BGR tuple."""
    c = np.uint8([[[h, s, v]]])
    return tuple(int(x) for x in cv2.cvtColor(c, cv2.COLOR_HSV2BGR)[0][0])


def draw_glow_circle(img, center, radius, color, intensity=0.6):
    """Draw a circle with a soft glow around it."""
    if radius < 1:
        return
    # Outer glow (large, dim)
    overlay = img.copy()
    cv2.circle(overlay, center, int(radius * 2.5), color, -1, cv2.LINE_AA)
    cv2.addWeighted(overlay, intensity * 0.15, img, 1 - intensity * 0.15, 0, img)
    # Mid glow
    overlay2 = img.copy()
    cv2.circle(overlay2, center, int(radius * 1.6), color, -1, cv2.LINE_AA)
    cv2.addWeighted(overlay2, intensity * 0.3, img, 1 - intensity * 0.3, 0, img)
    # Core
    cv2.circle(img, center, radius, color, -1, cv2.LINE_AA)
    # Bright center
    bright = tuple(min(255, int(c * 1.3)) for c in color)
    cv2.circle(img, center, max(2, radius // 2), bright, -1, cv2.LINE_AA)


def video1_bouncing_balls():
    """Balls bounce in a cylinder. Every wall hit = multiply. Big glowing balls."""
    print("Generating: Bouncing balls multiply on collision...")
    proc, path = make_ffmpeg_writer("video1.mp4")

    balls = [{"x": float(WIDTH // 2), "y": float(HEIGHT // 2),
              "vx": 6.0, "vy": 5.0, "r": 28,
              "color": hsv_to_bgr(135, 255, 255)}]
    center_x, center_y = WIDTH // 2, HEIGHT // 2
    cylinder_r = min(WIDTH, HEIGHT) // 2 - 40

    for frame in range(TOTAL_FRAMES):
        img = np.full((HEIGHT, WIDTH, 3), BG, dtype=np.uint8)

        # Draw cylinder ring with glow
        cv2.circle(img, (center_x, center_y), cylinder_r + 8,
                   hsv_to_bgr(135, 150, 60), 16, cv2.LINE_AA)
        cv2.circle(img, (center_x, center_y), cylinder_r,
                   hsv_to_bgr(135, 200, 180), 3, cv2.LINE_AA)

        new_balls = []
        for b in balls:
            b["x"] += b["vx"]
            b["y"] += b["vy"]

            dx = b["x"] - center_x
            dy = b["y"] - center_y
            dist = math.sqrt(dx * dx + dy * dy)

            if dist + b["r"] >= cylinder_r:
                nx, ny = dx / max(dist, 0.1), dy / max(dist, 0.1)
                dot = b["vx"] * nx + b["vy"] * ny
                b["vx"] -= 2 * dot * nx
                b["vy"] -= 2 * dot * ny
                b["x"] = center_x + nx * (cylinder_r - b["r"] - 2)
                b["y"] = center_y + ny * (cylinder_r - b["r"] - 2)

                if len(balls) + len(new_balls) < 50:
                    angle = math.atan2(ny, nx) + math.pi * 0.7
                    speed = math.sqrt(b["vx"] ** 2 + b["vy"] ** 2) * 0.85
                    hue = (frame * 2 + len(balls) * 20) % 180
                    new_balls.append({
                        "x": b["x"], "y": b["y"],
                        "vx": math.cos(angle) * speed,
                        "vy": math.sin(angle) * speed,
                        "r": max(10, b["r"] - 3),
                        "color": hsv_to_bgr(hue, 255, 255)
                    })

            draw_glow_circle(img, (int(b["x"]), int(b["y"])),
                             b["r"], b["color"], intensity=0.7)

        balls.extend(new_balls)
        write_frame(proc, img)

    finish_writer(proc)
    size = os.path.getsize(path) / (1024 * 1024)
    print(f"  -> {path} ({size:.1f}MB)")


def video2_gravity_particles():
    """Particles fall like rain then swirl into a vortex. Large glowing dots."""
    print("Generating: Gravity particle vortex...")
    proc, path = make_ffmpeg_writer("video2.mp4")

    num = 500
    px = np.random.uniform(0, WIDTH, num).astype(np.float64)
    py = np.random.uniform(-HEIGHT, 0, num).astype(np.float64)
    vx = np.random.uniform(-2, 2, num).astype(np.float64)
    vy = np.random.uniform(2, 8, num).astype(np.float64)
    hues = np.random.randint(100, 160, num)
    sizes = np.random.randint(4, 12, num)

    cx, cy = WIDTH // 2, HEIGHT // 2

    for frame in range(TOTAL_FRAMES):
        img = np.full((HEIGHT, WIDTH, 3), BG, dtype=np.uint8)
        t = frame / TOTAL_FRAMES

        vortex_strength = t * 5.0
        for i in range(num):
            dx_val = cx - px[i]
            dy_val = cy - py[i]
            dist = max(math.sqrt(dx_val * dx_val + dy_val * dy_val), 1)

            vx[i] += (dx_val / dist) * vortex_strength * 0.08
            vy[i] += (dy_val / dist) * vortex_strength * 0.08
            vx[i] += (-dy_val / dist) * vortex_strength * 0.05
            vy[i] += (dx_val / dist) * vortex_strength * 0.05

            vy[i] += 0.15

            speed = math.sqrt(vx[i] ** 2 + vy[i] ** 2)
            if speed > 15:
                vx[i] *= 15 / speed
                vy[i] *= 15 / speed

            px[i] += vx[i]
            py[i] += vy[i]

            if py[i] > HEIGHT + 30:
                py[i] = -20
                px[i] = np.random.uniform(0, WIDTH)
                vy[i] = np.random.uniform(2, 6)
                vx[i] = np.random.uniform(-1, 1)
            if px[i] < -30:
                px[i] = WIDTH + 20
            elif px[i] > WIDTH + 30:
                px[i] = -20

            size = int(sizes[i] * (1 + t * 0.5))
            hue = int(hues[i] + frame * 0.3) % 180
            color = hsv_to_bgr(hue, 230, 255)

            # Draw particle with glow
            glow_size = size * 3
            overlay = img.copy()
            cv2.circle(overlay, (int(px[i]), int(py[i])), glow_size,
                       color, -1, cv2.LINE_AA)
            cv2.addWeighted(overlay, 0.08, img, 0.92, 0, img)
            cv2.circle(img, (int(px[i]), int(py[i])), size,
                       color, -1, cv2.LINE_AA)

        # Center glow intensifies with vortex
        if t > 0.3:
            center_alpha = min(0.4, (t - 0.3) * 0.6)
            overlay = img.copy()
            center_r = int(80 + t * 120)
            cv2.circle(overlay, (cx, cy), center_r,
                       hsv_to_bgr(135, 200, 255), -1, cv2.LINE_AA)
            cv2.addWeighted(overlay, center_alpha, img, 1 - center_alpha, 0, img)

        write_frame(proc, img)

    finish_writer(proc)
    size = os.path.getsize(path) / (1024 * 1024)
    print(f"  -> {path} ({size:.1f}MB)")


def video3_pulse_rings():
    """Expanding rings pulse outward from center. Thick, bright rings."""
    print("Generating: Pulse rings...")
    proc, path = make_ffmpeg_writer("video3.mp4")

    rings = []
    cx, cy = WIDTH // 2, HEIGHT // 2
    max_radius = int(math.sqrt(WIDTH ** 2 + HEIGHT ** 2) / 2) + 50

    for frame in range(TOTAL_FRAMES):
        img = np.full((HEIGHT, WIDTH, 3), BG, dtype=np.uint8)
        t = frame / FPS

        # Spawn ring every ~0.3 seconds
        if frame % 18 == 0:
            hue = (frame * 3) % 180
            rings.append({"r": 0.0, "hue": hue, "alpha": 1.0, "speed": 6 + (frame % 5)})

        alive = []
        for ring in rings:
            ring["r"] += ring["speed"]
            ring["alpha"] -= 0.006

            if ring["alpha"] > 0.05 and ring["r"] < max_radius:
                alpha = ring["alpha"]
                brightness = int(255 * min(1.0, alpha * 1.5))
                color = hsv_to_bgr(ring["hue"], 220, brightness)

                thickness = max(3, int(12 * alpha))

                glow_color = hsv_to_bgr(ring["hue"], 180, int(brightness * 0.5))
                cv2.circle(img, (cx, cy), int(ring["r"]),
                           glow_color, thickness + 12, cv2.LINE_AA)
                cv2.circle(img, (cx, cy), int(ring["r"]),
                           color, thickness, cv2.LINE_AA)

                alive.append(ring)

        rings = alive

        # Pulsing center orb
        pulse = abs(math.sin(t * math.pi * 2.5))
        orb_r = int(20 + pulse * 30)
        draw_glow_circle(img, (cx, cy), orb_r,
                         hsv_to_bgr(135, 255, 255), intensity=0.8)

        write_frame(proc, img)

    finish_writer(proc)
    size = os.path.getsize(path) / (1024 * 1024)
    print(f"  -> {path} ({size:.1f}MB)")


def video4_dna_helix():
    """Rotating double helix DNA strand with large glowing nodes."""
    print("Generating: DNA helix...")
    proc, path = make_ffmpeg_writer("video4.mp4")

    for frame in range(TOTAL_FRAMES):
        img = np.full((HEIGHT, WIDTH, 3), BG, dtype=np.uint8)
        t = frame / FPS

        num_nodes = 30
        for i in range(num_nodes):
            y = int((i / num_nodes) * HEIGHT * 1.3 - HEIGHT * 0.15)
            phase = t * 3.5 + i * 0.35

            amplitude = 220
            x1 = int(WIDTH // 2 + math.sin(phase) * amplitude)
            x2 = int(WIDTH // 2 + math.sin(phase + math.pi) * amplitude)

            z1 = math.cos(phase)
            z2 = math.cos(phase + math.pi)
            r1 = int(14 + z1 * 8)
            r2 = int(14 + z2 * 8)

            hue1 = int(130 + i * 1.5) % 180
            hue2 = int(85 + i * 1.5) % 180
            bright1 = int(200 + z1 * 55)
            bright2 = int(200 + z2 * 55)

            c1 = hsv_to_bgr(hue1, 240, bright1)
            c2 = hsv_to_bgr(hue2, 240, bright2)

            if i % 3 == 0:
                bar_color = hsv_to_bgr(int((hue1 + hue2) / 2), 120, 100)
                cv2.line(img, (x1, y), (x2, y), bar_color, 3, cv2.LINE_AA)

            if z1 < z2:
                draw_glow_circle(img, (x1, y), r1, c1, intensity=0.5)
                draw_glow_circle(img, (x2, y), r2, c2, intensity=0.5)
            else:
                draw_glow_circle(img, (x2, y), r2, c2, intensity=0.5)
                draw_glow_circle(img, (x1, y), r1, c1, intensity=0.5)

        write_frame(proc, img)

    finish_writer(proc)
    size = os.path.getsize(path) / (1024 * 1024)
    print(f"  -> {path} ({size:.1f}MB)")


def video5_fractal_tree():
    """Growing fractal tree that branches and sways with glowing tips."""
    print("Generating: Fractal tree...")
    proc, path = make_ffmpeg_writer("video5.mp4")

    def draw_branch(img, x, y, angle, length, depth, t, max_depth):
        if depth > max_depth or length < 5:
            return

        progress = min(1.0, t / (0.2 + depth * 0.35))
        if progress <= 0:
            return

        current_len = length * progress
        sway = math.sin(t * 2.5 + depth * 0.6) * (depth * 1.5)
        branch_angle = angle + math.radians(sway)

        x2 = x + math.cos(branch_angle) * current_len
        y2 = y + math.sin(branch_angle) * current_len

        blend = min(1.0, depth / max_depth)
        hue = int(135 * blend + 20 * (1 - blend))
        brightness = int(160 + 95 * (1 - blend * 0.2))
        color = hsv_to_bgr(hue, 220, brightness)

        thickness = max(2, int((max_depth - depth + 1) * 2.5))
        cv2.line(img, (int(x), int(y)), (int(x2), int(y2)),
                 color, thickness, cv2.LINE_AA)

        if thickness > 4:
            glow_color = hsv_to_bgr(hue, 160, int(brightness * 0.4))
            cv2.line(img, (int(x), int(y)), (int(x2), int(y2)),
                     glow_color, thickness + 8, cv2.LINE_AA)

        if depth >= max_depth - 2 and progress >= 0.8:
            tip_hue = (hue + 30) % 180
            tip_color = hsv_to_bgr(tip_hue, 255, 255)
            tip_r = max(3, 8 - depth)
            draw_glow_circle(img, (int(x2), int(y2)), tip_r,
                             tip_color, intensity=0.6)

        if progress >= 0.7:
            spread = 28 + t * 3
            draw_branch(img, x2, y2, angle - math.radians(spread),
                        length * 0.68, depth + 1, t - 0.25, max_depth)
            draw_branch(img, x2, y2, angle + math.radians(spread),
                        length * 0.68, depth + 1, t - 0.25, max_depth)

    for frame in range(TOTAL_FRAMES):
        img = np.full((HEIGHT, WIDTH, 3), BG, dtype=np.uint8)
        t = frame / FPS

        # Ground glow
        overlay = img.copy()
        cv2.ellipse(overlay, (WIDTH // 2, HEIGHT - 180), (200, 40), 0, 0, 360,
                    hsv_to_bgr(135, 180, 120), -1)
        cv2.addWeighted(overlay, 0.15, img, 0.85, 0, img)

        draw_branch(img, WIDTH // 2, HEIGHT - 200,
                    -math.pi / 2, 280, 0, t, 9)

        write_frame(proc, img)

    finish_writer(proc)
    size = os.path.getsize(path) / (1024 * 1024)
    print(f"  -> {path} ({size:.1f}MB)")


if __name__ == "__main__":
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    print(f"Generating 5 seed videos at {WIDTH}x{HEIGHT} @ {FPS}fps, {DURATION}s each")
    print(f"Output: {OUTPUT_DIR}\n")

    video1_bouncing_balls()
    video2_gravity_particles()
    video3_pulse_rings()
    video4_dna_helix()
    video5_fractal_tree()

    print("\nDone!")
