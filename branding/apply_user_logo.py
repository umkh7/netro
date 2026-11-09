"""Логотип владельца (user-logo-src.png) -> иконки Android, Windows, iOS и знак в интерфейсе."""
import json
from PIL import Image

APP = '/home/claude/netro/app'
rounded = Image.open('netro-rounded-1254.png').convert('RGBA')
square = Image.open('netro-square-1024.png').convert('RGB')
adbg = Image.open('netro-adaptive-bg.png').convert('RGB')

res = f'{APP}/android/app/src/main/res'
for d, n in {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}.items():
    rounded.resize((n, n), Image.LANCZOS).save(f'{res}/mipmap-{d}/ic_launcher.png')
    m = int(round(n * 108 / 48))
    adbg.resize((m, m), Image.LANCZOS).save(f'{res}/mipmap-{d}/ic_launcher_background.png')
    Image.new('RGBA', (m, m), (0, 0, 0, 0)).save(f'{res}/mipmap-{d}/ic_launcher_foreground.png')
    import os
    p = f'{res}/mipmap-{d}/ic_launcher_monochrome.png'
    if os.path.exists(p):
        os.remove(p)
open(f'{res}/mipmap-anydpi-v26/ic_launcher.xml', 'w').write('''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
''')

rounded.resize((256, 256), Image.LANCZOS).save(
    f'{APP}/windows/runner/resources/app_icon.ico',
    sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])

ios = f'{APP}/ios/Runner/Assets.xcassets/AppIcon.appiconset'
meta = json.load(open(f'{ios}/Contents.json'))
for img in meta['images']:
    fn = img.get('filename')
    if not fn:
        continue
    px = int(round(float(img['size'].split('x')[0]) * float(img['scale'].rstrip('x'))))
    square.resize((px, px), Image.LANCZOS).save(f'{ios}/{fn}')

rounded.resize((192, 192), Image.LANCZOS).save(f'{APP}/assets/netro_glyph.png')
rounded.resize((512, 512), Image.LANCZOS).save(f'{APP}/assets/netro_icon.png')
print('applied')
