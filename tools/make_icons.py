"""Genera el logo de SuperCheck (carrito con tilde) en los tamaños que usa la app.

    python3 tools/make_icons.py

Salidas en assets/icon/:
  icon.png             cuadrado completo, para el ícono del teléfono
  icon_foreground.png  solo el dibujo sobre transparente, para el ícono adaptable de Android
  logo.png             ícono redondeado, para mostrar dentro de la app
"""
from PIL import Image, ImageDraw

SIZE = 1024
SS = 4  # se dibuja 4 veces más grande y se reduce: bordes suaves
BLUE_TOP = (66, 165, 245)
BLUE_BOTTOM = (21, 101, 192)
CHECK = (25, 118, 210)
WHITE = (255, 255, 255, 255)


def glyph(draw, scale, ox, oy, check_color):
    """Carrito con tilde. Coordenadas pensadas sobre un lienzo de 1024."""
    def p(x, y):
        return (ox + x * scale * SS, oy + y * scale * SS)

    def w(v):
        return max(1, int(v * scale * SS))

    def line(points, width):
        pts = [p(*q) for q in points]
        draw.line(pts, fill=check_color if False else WHITE, width=w(width), joint="curve")
        r = w(width) / 2
        for x, y in (pts[0], pts[-1]):
            draw.ellipse([x - r, y - r, x + r, y + r], fill=WHITE)

    # armazón: manija y base
    line([(140, 290), (250, 290), (350, 650), (770, 650)], 46)
    # canasto
    basket = [(285, 380), (830, 380), (770, 590), (345, 590)]
    draw.polygon([p(*q) for q in basket], fill=WHITE)
    line(basket + [basket[0]], 30)
    # ruedas
    for cx in (400, 730):
        x, y = p(cx, 760)
        r = 50 * scale * SS
        draw.ellipse([x - r, y - r, x + r, y + r], fill=WHITE)
    # tilde
    pts = [p(*q) for q in [(440, 485), (525, 560), (675, 420)]]
    draw.line(pts, fill=check_color, width=w(50), joint="curve")
    r = w(50) / 2
    for x, y in (pts[0], pts[-1]):
        draw.ellipse([x - r, y - r, x + r, y + r], fill=check_color)


def gradient(size):
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        t = y / (size - 1)
        c = tuple(round(BLUE_TOP[i] + (BLUE_BOTTOM[i] - BLUE_TOP[i]) * t) for i in range(3))
        for x in range(size):
            px[x, y] = c
    return img


def render(background, scale, rounded):
    big = SIZE * SS
    if background:
        canvas = gradient(big).convert("RGBA")
    else:
        canvas = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    layer = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    # centrar el dibujo (ocupa de x=117 a 853 y de y=267 a 810 aprox. sobre 1024)
    cx, cy = (117 + 853) / 2, (267 + 810) / 2
    ox = big / 2 - cx * scale * SS
    oy = big / 2 - cy * scale * SS
    glyph(d, scale, ox, oy, CHECK if background else (30, 136, 229, 255))
    canvas.alpha_composite(layer)
    if rounded:
        mask = Image.new("L", (big, big), 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, big, big], radius=int(big * 0.225), fill=255)
        canvas.putalpha(mask)
    return canvas.resize((SIZE, SIZE), Image.LANCZOS)


if __name__ == "__main__":
    render(True, 0.92, False).convert("RGB").save("assets/icon/icon.png")
    render(False, 0.70, False).save("assets/icon/icon_foreground.png")
    render(True, 0.92, True).save("assets/icon/logo.png")
    print("listo")
