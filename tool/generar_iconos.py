#!/usr/bin/env python3
"""Íconos y pantalla de arranque de la app eduXaction (Android e iOS).

Dibuja la marca —la X blanca de dos barras redondeadas giradas ±24°, con su
halo, sobre el cuadrado #0B0B0D— con la MISMA geometría de
`assets/media/eduxaction-x.svg`, y escribe cada tamaño que piden las dos
plataformas.

Se dibuja con Pillow en vez de depender de `flutter_launcher_icons`: la marca
son dos rectángulos, y agregar un paquete cambiaría `pubspec.lock` para algo
que se genera una vez. Para cambiar el ícono, se cambia este archivo y se
vuelve a correr:

    python3 tool/generar_iconos.py

No toca nada de la web: `web/` tiene sus propios íconos.
"""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

RAIZ = Path(__file__).resolve().parent.parent
FONDO = (0x0B, 0x0B, 0x0D)
FONDO_HEX = '#0B0B0D'

# Geometría del SVG (viewBox de 128): barra de 15 × 84 con radio 4, centrada
# en (64, 64), girada ±24°; halo con desenfoque gaussiano de 5 y opacidad 0.8.
LADO_SVG = 128
BARRA = (56.5, 22, 56.5 + 15, 22 + 84)
RADIO_BARRA = 4
GIRO = 24
DESENFOQUE = 5
OPACIDAD_HALO = 0.8

# Se dibuja a 4× y se reduce: así los bordes salen suavizados.
SOBREMUESTREO = 4


def _mascara_x(lado: int, escala: float) -> Image.Image:
    """La X como máscara (L) de `lado` px; `escala` la achica dentro del cuadro."""
    grande = lado * SOBREMUESTREO
    factor = grande / LADO_SVG
    mascara = Image.new('L', (grande, grande), 0)
    for angulo in (GIRO, -GIRO):
        capa = Image.new('L', (grande, grande), 0)
        x0, y0, x1, y1 = (v * factor for v in BARRA)
        ImageDraw.Draw(capa).rounded_rectangle(
            (x0, y0, x1, y1), radius=RADIO_BARRA * factor, fill=255)
        # PIL gira en sentido antihorario; el SVG, horario.
        capa = capa.rotate(-angulo, resample=Image.BICUBIC,
                           center=(grande / 2, grande / 2))
        mascara = ImageChops.lighter(mascara, capa)
    if escala != 1:
        chica = mascara.resize((round(grande * escala),) * 2, Image.LANCZOS)
        mascara = Image.new('L', (grande, grande), 0)
        desplazamiento = (grande - chica.width) // 2
        mascara.paste(chica, (desplazamiento, desplazamiento))
    return mascara.resize((lado, lado), Image.LANCZOS)


def _x_con_halo(lado: int, escala: float = 1.0) -> Image.Image:
    """La X blanca con su halo, sobre transparente (RGBA)."""
    mascara = _mascara_x(lado, escala)
    halo = mascara.filter(
        ImageFilter.GaussianBlur(DESENFOQUE * lado / LADO_SVG * escala))
    halo = halo.point(lambda v: round(v * OPACIDAD_HALO))
    alfa = ImageChops.lighter(halo, mascara)
    imagen = Image.new('RGBA', (lado, lado), (255, 255, 255, 0))
    imagen.putalpha(alfa)
    return imagen


def icono_completo(lado: int, redondeado: bool = False) -> Image.Image:
    """Cuadrado de fondo con la X. iOS redondea solo: va a sangre y sin alfa."""
    fondo = Image.new('RGBA', (lado, lado), FONDO + (255,))
    fondo.alpha_composite(_x_con_halo(lado))
    if not redondeado:
        return fondo.convert('RGB')
    # El radio de la marca: 25 % del lado (`.exa-mark`).
    grande = lado * SOBREMUESTREO
    forma = Image.new('L', (grande, grande), 0)
    ImageDraw.Draw(forma).rounded_rectangle(
        (0, 0, grande - 1, grande - 1), radius=grande * 0.25, fill=255)
    fondo.putalpha(forma.resize((lado, lado), Image.LANCZOS))
    return fondo


def escribir(imagen: Image.Image, ruta: Path) -> None:
    ruta.parent.mkdir(parents=True, exist_ok=True)
    imagen.save(ruta, optimize=True)
    print('  ', ruta.relative_to(RAIZ))


def ios() -> None:
    print('iOS')
    carpeta = RAIZ / 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
    contenido = json.loads((carpeta / 'Contents.json').read_text())
    for entrada in contenido['images']:
        nombre = entrada.get('filename')
        if not nombre:
            continue
        puntos = float(entrada['size'].split('x')[0])
        escala = int(entrada['scale'].rstrip('x'))
        escribir(icono_completo(round(puntos * escala)), carpeta / nombre)

    # Pantalla de arranque: la X sola, 120 pt, sobre el fondo de la marca
    # (el color lo pone `LaunchScreen.storyboard`).
    lanzamiento = RAIZ / 'ios/Runner/Assets.xcassets/LaunchImage.imageset'
    for sufijo, escala in (('', 1), ('@2x', 2), ('@3x', 3)):
        escribir(_x_con_halo(120 * escala), lanzamiento / f'LaunchImage{sufijo}.png')


# Densidades de Android: factor sobre 1 dp.
DENSIDADES = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}


def android() -> None:
    print('Android')
    res = RAIZ / 'android/app/src/main/res'
    for densidad, factor in DENSIDADES.items():
        # Ícono clásico (Android 7 y anteriores): 48 dp, redondeado.
        escribir(icono_completo(round(48 * factor), redondeado=True),
                 res / f'mipmap-{densidad}/ic_launcher.png')
        # Ícono adaptable (Android 8+): 108 dp, de los que el sistema muestra
        # el círculo central de 66. La X va al 72 % para quedar dentro.
        lado = round(108 * factor)
        escribir(_x_con_halo(lado, escala=0.72),
                 res / f'drawable-{densidad}/ic_launcher_foreground.png')
        # Ícono temático (Android 13+): solo la forma, sin halo.
        monocromo = Image.new('RGBA', (lado, lado), (255, 255, 255, 0))
        monocromo.putalpha(_mascara_x(lado, 0.72))
        escribir(monocromo, res / f'drawable-{densidad}/ic_launcher_monochrome.png')
        # Pantalla de arranque de Android 11 y anteriores: la X de 96 dp.
        escribir(_x_con_halo(round(96 * factor)),
                 res / f'drawable-{densidad}/splash_x.png')


def tienda() -> None:
    print('Fichas de las tiendas')
    destino = RAIZ / 'docs/movil/tienda'
    # Google Play pide 512 × 512; App Store toma el de 1024 del catálogo.
    escribir(icono_completo(512), destino / 'icono-google-play-512.png')
    escribir(icono_completo(1024), destino / 'icono-1024.png')


if __name__ == '__main__':
    ios()
    android()
    tienda()
    print(f'Listo. Fondo de la marca: {FONDO_HEX}')
