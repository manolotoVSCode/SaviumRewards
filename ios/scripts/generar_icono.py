"""Icono de Savium Rewards: el cubo de Savium Finanzas (mismos trazos) con un moño de regalo encima,
en blanco sobre verde Savium, a 1024 px. También guarda el logo para la pantalla de entrada."""
import math
from pathlib import Path
from PIL import Image, ImageDraw

VERDE = (0x23, 0x90, 0x05)
BLANCO = (255, 255, 255)
LADO = 1024
SS = 4                                 # sobremuestreo para bordes suaves
L = LADO * SS

# Mismos trazos que el cubo de Finanzas (viewBox 184×184). El moño sube hasta y≈-50.
CUBO = [
    [(91.5, 10), (172.5, 48), (91.5, 86), (10.5, 48), (91.5, 10)],
    [(10.5, 48), (10.5, 136), (91.5, 175), (172.5, 136), (172.5, 48)],
    [(91.5, 106), (91.5, 175)],
]
ARRIBA, ABAJO = -8, 185                # alto total del dibujo, en unidades del viewBox
ESCALA = L * 0.64 / (ABAJO - ARRIBA)
DX = (L - 184 * ESCALA) / 2
DY = (L - (ABAJO - ARRIBA) * ESCALA) / 2 - ARRIBA * ESCALA
TRAZO = round(10 * ESCALA)


def punto(p):
    return (DX + p[0] * ESCALA, DY + p[1] * ESCALA)


def lazo(nudo, lado):
    """Una lazada del moño: un óvalo inclinado que sale del nudo hacia un lado y hacia arriba."""
    cx, cy = nudo[0] + lado * 25, nudo[1] - 19
    rx, ry, giro = 27, 14, math.radians(-35 * lado)
    pts = []
    for i in range(73):
        t = 2 * math.pi * i / 72
        x, y = rx * math.cos(t), ry * math.sin(t)
        pts.append((cx + x * math.cos(giro) - y * math.sin(giro), cy + x * math.sin(giro) + y * math.cos(giro)))
    return pts


def tapar(d, trazo_pts):
    """Rellena de verde el interior de una lazada: tapa las aristas del cubo que quedan detrás."""
    d.polygon([punto(p) for p in trazo_pts], fill=VERDE + (255,))


def dibujar(d, trazo_pts, cerrar=False):
    pts = [punto(p) for p in trazo_pts]
    d.line(pts, fill=BLANCO, width=TRAZO, joint="curve")
    r = TRAZO / 2
    for x, y in ([pts[0], pts[-1]] if cerrar else pts):
        d.ellipse((x - r, y - r, x + r, y + r), fill=BLANCO)


def icono(fondo):
    img = Image.new("RGBA", (L, L), fondo)
    d = ImageDraw.Draw(img)
    for t in CUBO:
        dibujar(d, t)
    # El moño sale del centro de la cara de arriba del cubo y tapa las aristas que quedan detrás.
    nudo = (91.5, 48)
    for lado in (-1, 1):
        tapar(d, lazo(nudo, lado))
        dibujar(d, lazo(nudo, lado), cerrar=True)
    # Nudo: un círculo lleno en el centro de la cara de arriba.
    x, y = punto(nudo)
    r = TRAZO * 1.15
    d.ellipse((x - r, y - r, x + r, y + r), fill=BLANCO)
    return img.resize((LADO, LADO), Image.LANCZOS)


raiz = Path(__file__).resolve().parent.parent / "SaviumRewards/Assets.xcassets"
destino = raiz / "AppIcon.appiconset/icono-1024.png"
icono(VERDE + (255,)).convert("RGB").save(destino)
logo = raiz / "Logo.imageset/logo.png"
logo.parent.mkdir(parents=True, exist_ok=True)
icono(VERDE + (255,)).convert("RGB").resize((512, 512), Image.LANCZOS).save(logo)
print(destino)
