"""Логотип Netro: слои SVG -> честная прорезь в стойках -> иконки для всех платформ."""
import io, re, cairosvg
from PIL import Image, ImageChops

DEFS = open('netro-mark.svg').read()
defs = re.search(r'<defs>.*?</defs>', DEFS, re.S).group(0)
def svg(body, bg=False):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">{defs}{body}</svg>'
def render(s, size=1024):
    return Image.open(io.BytesIO(cairosvg.svg2png(bytestring=s.encode(), output_width=size, output_height=size))).convert('RGBA')

BG = '''<rect width="1024" height="1024" rx="232" fill="url(#bg)"/>
<rect width="1024" height="1024" rx="232" fill="url(#hl)"/>
<circle cx="512" cy="512" r="330" fill="url(#halo)"/>
<rect x="2" y="2" width="1020" height="1020" rx="230" fill="none" stroke="#FFFFFF" stroke-opacity="0.08" stroke-width="4"/>'''
BARS = '''<path d="M352 706 V318" stroke="url(#bar)" stroke-width="92" stroke-linecap="round"/>
<path d="M672 706 V318" stroke="url(#bar)" stroke-width="92" stroke-linecap="round"/>'''
GAP = '<path d="M352 318 L672 706" stroke="#000" stroke-width="140" stroke-linecap="round"/>'
BEAM = '<path d="M352 318 L672 706" stroke="url(#beam)" stroke-width="92" stroke-linecap="round"/>'

def glyph(size, scale=1.0):
    """Только знак N (прозрачный фон). scale<1 — для adaptive-icon с безопасной зоной."""
    def body(x):
        return f'<g transform="translate(512 512) scale({scale}) translate(-512 -512)">{x}</g>'
    bars = render(svg(body(BARS)), size)
    gap = render(svg(body(GAP)), size).getchannel('A')
    a = ImageChops.multiply(bars.getchannel('A'), ImageChops.invert(gap))
    bars.putalpha(a)
    beam = render(svg(body(BEAM)), size)
    return Image.alpha_composite(bars, beam)

def full(size):
    return Image.alpha_composite(render(svg(BG), size), glyph(size))

if __name__ == '__main__':
    master = full(1024)
    master.save('netro-1024.png')
    print('ok')

BG_SQ = BG.replace('rx="232"', 'rx="0"').replace(
    '<rect x="2" y="2" width="1020" height="1020" rx="230" fill="none" stroke="#FFFFFF" stroke-opacity="0.08" stroke-width="4"/>', '')

def square(size):
    return Image.alpha_composite(render(svg(BG_SQ), size), glyph(size))

def build_all(app):
    import os, json
    res = f'{app}/android/app/src/main/res'
    for d, n in {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}.items():
        full(n * 4).resize((n, n), Image.LANCZOS).save(f'{res}/mipmap-{d}/ic_launcher.png')
        m = int(n * 108 / 48)  # adaptive: 108dp слои
        render(svg(BG_SQ), m * 2).resize((m, m), Image.LANCZOS).save(f'{res}/mipmap-{d}/ic_launcher_background.png')
        glyph(m * 2, 0.62).resize((m, m), Image.LANCZOS).save(f'{res}/mipmap-{d}/ic_launcher_foreground.png')
        g = glyph(m * 2, 0.62)
        mono = Image.new('RGBA', g.size, (255, 255, 255, 0)); mono.putalpha(g.getchannel('A'))
        mono.resize((m, m), Image.LANCZOS).save(f'{res}/mipmap-{d}/ic_launcher_monochrome.png')
    os.makedirs(f'{res}/mipmap-anydpi-v26', exist_ok=True)
    open(f'{res}/mipmap-anydpi-v26/ic_launcher.xml', 'w').write('''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
    <monochrome android:drawable="@mipmap/ic_launcher_monochrome"/>
</adaptive-icon>
''')
    # Windows .ico
    big = full(1024)
    big.save(f'{app}/windows/runner/resources/app_icon.ico',
             sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    # iOS AppIcon (квадрат без прозрачности — углы скругляет система)
    ios = f'{app}/ios/Runner/Assets.xcassets/AppIcon.appiconset'
    meta = json.load(open(f'{ios}/Contents.json'))
    sq = square(1024).convert('RGB')
    for img in meta['images']:
        fn = img.get('filename')
        if not fn:
            continue
        pt = float(img['size'].split('x')[0]); sc = float(img['scale'].rstrip('x'))
        px = int(round(pt * sc))
        sq.resize((px, px), Image.LANCZOS).save(f'{ios}/{fn}')
    # Знак для интерфейса
    os.makedirs(f'{app}/assets', exist_ok=True)
    glyph(512).save(f'{app}/assets/netro_glyph.png')
    full(512).save(f'{app}/assets/netro_icon.png')
    print('icons ok')

if __name__ == '__main__' and True:
    build_all('/home/claude/netro/app')
