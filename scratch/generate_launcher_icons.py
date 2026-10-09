import os
import json
from PIL import Image, ImageDraw

def generate_logo(size=1024):
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    
    blue_color = (25, 113, 194, 255)
    draw.ellipse([0, 0, size, size], fill=blue_color)
    
    pad = int(size * 0.15)
    canvas_size = size - 2 * pad
    
    shield_img = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(shield_img)
    
    w = float(canvas_size)
    h = float(canvas_size)
    
    def get_bezier_point(p0, p1, p2, t):
        x = (1.0 - t)**2 * p0[0] + 2.0 * (1.0 - t) * t * p1[0] + t**2 * p2[0]
        y = (1.0 - t)**2 * p0[1] + 2.0 * (1.0 - t) * t * p1[1] + t**2 * p2[1]
        return (x, y)
        
    points = [
        (w * 0.5, 0.0),
        (w * 0.9, h * 0.15),
    ]
    
    for i in range(1, 31):
        t = i / 30.0
        points.append(get_bezier_point((w * 0.9, h * 0.15), (w * 0.9, h * 0.6), (w * 0.5, h * 0.95), t))
        
    for i in range(1, 31):
        t = i / 30.0
        points.append(get_bezier_point((w * 0.5, h * 0.95), (w * 0.1, h * 0.6), (w * 0.1, h * 0.15), t))
        
    points.append((w * 0.1, h * 0.15))
    points.append((w * 0.5, 0.0))
    
    sdraw.polygon(points, fill=(255, 255, 255, 255))
    
    body_rect = [w * 0.25, h * 0.38, w * 0.75, h * 0.50]
    sdraw.rounded_rectangle(body_rect, radius=int(w * 0.035), fill=blue_color)
    
    cabin_points = [
        (w * 0.32, h * 0.38),
        (w * 0.40, h * 0.26),
        (w * 0.60, h * 0.26),
        (w * 0.68, h * 0.38)
    ]
    sdraw.polygon(cabin_points, fill=blue_color)
    
    wheel_r = w * 0.075
    def draw_circle(draw_obj, cx, cy, r, color):
        draw_obj.ellipse([cx - r, cy - r, cx + r, cy + r], fill=color)
        
    draw_circle(sdraw, w * 0.36, h * 0.52, wheel_r, blue_color)
    draw_circle(sdraw, w * 0.64, h * 0.52, wheel_r, blue_color)
    
    draw_circle(sdraw, w * 0.36, h * 0.52, w * 0.03, (255, 255, 255, 255))
    draw_circle(sdraw, w * 0.64, h * 0.52, w * 0.03, (255, 255, 255, 255))
    
    image.paste(shield_img, (pad, pad), shield_img)
    return image

def main():
    print("Generating high-resolution logo...")
    logo = generate_logo(1024)
    
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
                
            size_val = float(size_str.split("x")[0])
            scale_val = float(scale_str.replace("x", ""))
            pixel_size = int(round(size_val * scale_val))
            
            path = os.path.join(ios_base, filename)
            resized = logo.resize((pixel_size, pixel_size), Image.Resampling.LANCZOS)
            resized.save(path, "PNG")
            print(f"Saved iOS launcher icon: {path} ({pixel_size}x{pixel_size})")
            
    print("Launcher icon generation completed successfully!")

if __name__ == "__main__":
    main()
