"""Capturas de marketing de Savium Rewards para la App Store (1320×2868, iPhone 6,9"), como las de Savium Share.
Toma las capturas crudas de AppStore/capturas-crudas[-en]/ y genera AppStore/<idioma>/NN.png
con fondo verde Savium, titular y el iPhone recortado por abajo."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

RAIZ = Path(__file__).resolve().parent.parent / "AppStore"
ANCHO, ALTO = 1320, 2868
CLARO, OSCURO = (0x34, 0xA8, 0x15), (0x23, 0x90, 0x05)   # verde Savium (#239005)

TEXTOS = {
    "es": [
        ("1-cartera", "Todas tus tarjetas\nen un solo sitio", "Deja las de plástico en casa"),
        ("2-codigo", "El código listo\npara la caja", "Brillo al máximo, también sin conexión"),
        ("3-familia", "Compartidas\nen familia", "Tú decides cuáles ve tu familia"),
        ("4-catalogo", "Añádelas\nen segundos", "Escanea el código o elige el programa"),
    ],
}

def fuente(tam, peso="Bold"):
    f = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", tam)
    try:
        f.set_variation_by_name(peso)
    except Exception:
        pass
    return f

def fondo():
    img = Image.new("RGB", (ANCHO, ALTO))
    d = ImageDraw.Draw(img)
    for y in range(ALTO):
        t = y / (ALTO - 1)
        d.line([(0, y), (ANCHO, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(CLARO, OSCURO)))
    # Brillo suave arriba
    brillo = Image.new("L", (ANCHO, ALTO), 0)
    ImageDraw.Draw(brillo).ellipse((-400, -900, ANCHO + 400, 900), fill=70)
    img.paste((255, 255, 255), (0, 0), brillo.filter(ImageFilter.GaussianBlur(200)))
    return img

def componer(cruda, titular, subtitulo, destino):
    img = fondo()
    d = ImageDraw.Draw(img)
    y = 190
    for linea in titular.split("\n"):
        f = fuente(118)
        w = d.textlength(linea, font=f)
        d.text(((ANCHO - w) / 2, y), linea, font=f, fill="white")
        y += 136
    f2 = fuente(52, "Medium")
    w = d.textlength(subtitulo, font=f2)
    d.text(((ANCHO - w) / 2, y + 26), subtitulo, font=f2, fill=(232, 248, 226))

    # iPhone: captura reducida con esquinas redondeadas, marco negro fino y sombra; sale por abajo.
    escala = 0.80
    tel = Image.open(cruda).convert("RGB").resize((round(ANCHO * escala), round(ALTO * escala)), Image.LANCZOS)
    tw, th = tel.size
    borde = 26
    marco = Image.new("RGBA", (tw + 2 * borde, th + 2 * borde), (0, 0, 0, 0))
    ImageDraw.Draw(marco).rounded_rectangle((0, 0, marco.width, marco.height), radius=150, fill=(18, 18, 20, 255))
    mascara = Image.new("L", tel.size, 0)
    ImageDraw.Draw(mascara).rounded_rectangle((0, 0, tw, th), radius=126, fill=255)
    marco.paste(tel, (borde, borde), mascara)
    x0 = (ANCHO - marco.width) // 2
    y0 = y + 150
    sombra = Image.new("L", (ANCHO, ALTO), 0)
    ImageDraw.Draw(sombra).rounded_rectangle((x0 + 10, y0 + 40, x0 + marco.width - 10, y0 + marco.height + 40), radius=150, fill=120)
    img.paste((10, 60, 0), (0, 0), sombra.filter(ImageFilter.GaussianBlur(50)))
    img.paste(marco, (x0, y0), marco)
    destino.parent.mkdir(parents=True, exist_ok=True)
    img.save(destino)

for idioma, lista in TEXTOS.items():
    origen = RAIZ / "capturas-crudas"
    for i, (nombre, titular, sub) in enumerate(lista, 1):
        cruda = origen / f"{nombre}.png"
        if cruda.exists():
            componer(cruda, titular, sub, RAIZ / idioma / f"{i:02d}-{nombre}.png")
            print(idioma, i, nombre)
