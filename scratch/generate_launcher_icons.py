import os
import json
from PIL import Image, ImageDraw

def generate_logo(size=1024):
    # 1. Create a transparent canvas
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    
    # 2. Draw the blue circle background: #1971C2 -> (25, 113, 194, 255)
    blue_color = (25, 113, 194, 255)
    draw.ellipse([0, 0, size, size], fill=blue_color)
    
    # 3. Shield sizing with padding (size * 0.15)
    pad = int(size * 0.15)
    canvas_size = size - 2 * pad
    
    # Draw shield on a separate transparent layer
    shield_img = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(shield_img)
    
    w = float(canvas_size)
    h = float(canvas_size)
    
    # White shield coordinates relative to canvas_size
    # Shield top center (w * 0.5, 0)
    # Shield top right (w * 0.9, h * 0.15)
    # Right curve to bottom center (w * 0.5, h * 0.95), control (w * 0.9, h * 0.6)
    # Left curve from bottom center to (w * 0.1, h * 0.15), control (w * 0.1, h * 0.6)
    # Left line to top center (w * 0.5, 0)
    def get_bezier_point(p0, p1, p2, t):
        x = (1.0 - t)**2 * p0[0] + 2.0 * (1.0 - t) * t * p1[0] + t**2 * p2[0]
        y = (1.0 - t)**2 * p0[1] + 2.0 * (1.0 - t) * t * p1[1] + t**2 * p2[1]
        return (x, y)
        
    points = []
    points.append((w * 0.5, 0.0))
    points.append((w * 0.9, h * 0.15))
    
    # Right side curve
    for i in range(1, 31):
        t = i / 30.0
        points.append(get_bezier_point((w * 0.9, h * 0.15), (w * 0.9, h * 0.6), (w * 0.5, h * 0.95), t))
        
    # Left side curve
    for i in range(1, 31):
        t = i / 30.0
        points.append(get_bezier_point((w * 0.5, h * 0.95), (w * 0.1, h * 0.6), (w * 0.1, h * 0.15), t))
        
    points.append((w * 0.1, h * 0.15))
    points.append((w * 0.5, 0.0))
    
    # Draw white shield
    sdraw.polygon(points, fill=(255, 255, 255, 255))
    
    # Draw corporate blue car inside the shield
    # Body: Rect from (w * 0.25, h * 0.38) to (w * 0.75, h * 0.50)
    body_rect = [w * 0.25, h * 0.38, w * 0.75, h * 0.50]
    sdraw.rounded_rectangle(body_rect, radius=int(w * 0.035), fill=blue_color)
    
    # Cabin/roof: polygon
    cabin_points = [
        (w * 0.32, h * 0.38),
        (w * 0.40, h * 0.26),
        (w * 0.60, h * 0.26),
        (w * 0.68, h * 0.38)
    ]
    sdraw.polygon(cabin_points, fill=blue_color)
    
    # Wheels: circles at (w * 0.36, h * 0.52) and (w * 0.64, h * 0.52) with radius w * 0.075
    wheel_r = w * 0.075
    def draw_circle(draw_obj, cx, cy, r, color):
        draw_obj.ellipse([cx - r, cy - r, cx + r, cy + r], fill=color)
        
    # Blue wheels
    draw_circle(sdraw, w * 0.36, h * 0.52, wheel_r, blue_color)
    draw_circle(sdraw, w * 0.64, h * 0.52, wheel_r, blue_color)
    
    # White hubs: radius w * 0.03
    draw_circle(sdraw, w * 0.36, h * 0.52, w * 0.03, (255, 255, 255, 255))
    draw_circle(sdraw, w * 0.64, h * 0.52, w * 0.03, (255, 255, 255, 255))
    
    # Paste shield onto background image
    image.paste(shield_img, (pad, pad), shield_img)
    return image

def main():
    print("Generating high-resolution logo...")
    logo = generate_logo(1024)
    
    # Define Android mipmap paths
    android_base = "android/app/src/main/res"
    android_configs = [
        ("mipmap-mdpi", 48),
        ("mipmap-hdpi", 72),
        ("mipmap-xhdpi", 96),
        ("mipmap-xxhdpi", 144),
        ("mipmap-xxxhdpi", 192)
    ]
    
    for folder, size in android_configs:
        path = os.path.join(android_base, folder, "ic_launcher.png")
        os.makedirs(os.path.dirname(path), exist_ok=True)
        resized = logo.resize((size, size), Image.Resampling.LANCZOS)
        resized.save(path, "PNG")
        print(f"Saved Android launcher icon: {path} ({size}x{size})")
        
    # Define iOS assets path
    ios_base = "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    contents_path = os.path.join(ios_base, "Contents.json")
    
    if os.path.exists(contents_path):
        print("Reading iOS Contents.json...")
        with open(contents_path, "r") as f:
            contents = json.load(f)
            
        for img in contents.get("images", []):
            filename = img.get("filename")
            size_str = img.get("size")
            scale_str = img.get("scale")
            
            if not filename or not size_str or not scale_str:
                continue
                
            # Parse size (e.g. "83.5x83.5" or "20x20")
            size_val = float(size_str.split("x")[0])
            # Parse scale (e.g. "2x" or "1x")
            scale_val = float(scale_str.replace("x", ""))
            
            pixel_size = int(round(size_val * scale_val))
            
            path = os.path.join(ios_base, filename)
            resized = logo.resize((pixel_size, pixel_size), Image.Resampling.LANCZOS)
            resized.save(path, "PNG")
            print(f"Saved iOS launcher icon: {path} ({pixel_size}x{pixel_size})")
            
    print("Launcher icon generation completed successfully!")

if __name__ == "__main__":
    main()
