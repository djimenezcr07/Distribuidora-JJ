# Identidad visual — Distribuidora JJ

**Versión:** 1.0 · Stage 2.1A.1  
**Dirección aprobada:** Concepto A — Monograma JJ  
**Estado:** identidad final definida; integración en UI pendiente de Stage 2.1B

## 1. Núcleo de marca

- **BrandName:** Distribuidora JJ
- **BrandSubtitle:** Licorera - Distribuidora
- **Personalidad:** moderna, directa, confiable, profesional y cercana al comercio.
- **Idea del símbolo:** dos letras J construidas con el mismo trazo y ritmo. La J blanca representa claridad y servicio; la J dorada aporta un acento premium. Ambas operan dentro de una forma roja compacta que funciona como sello digital.

El resultado evita emblemas, coronas, botellas y otros códigos literales. Esto permite que la marca represente tanto la tienda como la plataforma operativa sin parecer una plantilla de licorera.

## 2. Arquitectura del logo

| Nivel | Asset | Contenido | Uso principal |
|---|---|---|---|
| Principal | `logo_stage2-identity_horizontal_20260821_color.svg` | Isotipo + nombre + subtítulo | Navbar, comprobantes, documentos, email |
| Principal invertido | `logo_stage2-identity_horizontal_20260821_reversed.svg` | Isotipo + texto claro | Fondos carbón o rojo profundo |
| Secundario | `logo_stage2-identity_stacked_20260821_color.svg` | Composición centrada | Login, splash, portada y firmas |
| Compacto | `logo_stage2-identity_compact_20260821_color.svg` | Isotipo + nombre | Sidebar, encabezados estrechos y móvil |
| Isotipo | `logo_stage2-identity_mark_20260821_color.svg` | Monograma JJ | Sidebar colapsado, favicon, app icon |
| Monocromático | `logo_stage2-identity_horizontal_20260821_mono-*.svg` | Logo a una tinta | Impresión, sello o limitación técnica |

La versión principal es la opción predeterminada. El isotipo solo debe usarse sin nombre cuando el contexto ya identifica a Distribuidora JJ o cuando el espacio no admite un lockup legible.

## 3. Construcción y espacio de seguridad

La unidad **x** equivale al ancho del trazo vertical de una J.

- Espacio libre mínimo alrededor del lockup: **2x**.
- Espacio libre mínimo alrededor del isotipo: **2x**.
- Ningún texto, borde, fotografía o control interactivo debe entrar en esa zona.
- Mantener siempre la proporción original del SVG.

## 4. Tamaños mínimos

| Variante | Digital | Impresión | Condición |
|---|---:|---:|---|
| Horizontal con subtítulo | 180 px de ancho | 45 mm | El subtítulo debe seguir legible |
| Secundaria vertical | 120 px de ancho | 32 mm | Para composiciones centradas |
| Compacta sin subtítulo | 132 px de ancho | 28 mm | Sidebar o header estrecho |
| Isotipo color | 32 × 32 px | 10 mm | Uso estándar de interfaz |
| Isotipo, pequeño formato | 24 × 24 px | No recomendado | Solo favicon; sin añadir detalle |
| App icon | 48 × 48 px visible | No aplica | Usar fuente 512 px al exportar |

Por debajo de 180 px no debe utilizarse el lockup con subtítulo; se cambia a compacto o isotipo.

## 5. Paleta oficial

| Token | Valor | RGB | Función de marca |
|---|---|---|---|
| `brand.red.primary` | `#8B0E16` | 139, 14, 22 | Color principal, contenedor del isotipo y presencia institucional |
| `brand.red.bright` | `#C41E26` | 196, 30, 38 | Acento comercial secundario; nunca reemplaza al rojo principal en el logo |
| `brand.charcoal` | `#1F1F1F` | 31, 31, 31 | Nombre, texto principal y workspace |
| `brand.gold.accent` | `#D4AF37` | 212, 175, 55 | Segunda J y detalles premium; no usar como texto normal sobre blanco |
| `brand.gold.light` | `#F2D77A` | 242, 215, 122 | Acento accesible sobre rojo/carbón |
| `brand.surface` | `#FAFAFA` | 250, 250, 250 | Fondo general claro |
| `brand.white` | `#FFFFFF` | 255, 255, 255 | Superficie y versión invertida |

### Proporción recomendada

- **Storefront:** 60% blancos/fondos, 30% carbón y rojo, 10% dorado como acento.
- **Workspace:** 70% neutros, 25% carbón/rojo, 5% dorado para selección o énfasis excepcional.

El dorado no es color semántico de advertencia ni color de texto sobre blanco. Los estados funcionales deben conservar su propio sistema accesible en Stage 2.1B.

## 6. Fondos aprobados

- Fondo blanco o `#FAFAFA`: logo horizontal color o monocromático oscuro.
- Fondo carbón `#1F1F1F`: logo horizontal invertido o monocromático claro.
- Fondo rojo principal `#8B0E16`: monocromático claro.
- Fotografía: únicamente sobre un área visualmente estable y con contraste suficiente; preferir un bloque de superficie detrás del logo.

No colocar el logo directamente sobre patrones, etiquetas de producto, reflejos intensos o fotografías con alto detalle.

## 7. Usos correctos

- Usar el SVG original y conservar su relación de aspecto.
- Elegir la variante según fondo y tamaño, no recolorear manualmente.
- Mantener el isotipo alineado ópticamente con el texto o contenedor.
- Reservar el lockup completo para contextos de identificación formal.
- Usar texto alternativo “Distribuidora JJ” cuando el logo funcione como imagen significativa.
- En un enlace a inicio, el nombre accesible debe describir el destino, por ejemplo: “Distribuidora JJ — Inicio”.

## 8. Usos incorrectos

- No estirar, comprimir, inclinar ni rotar.
- No cambiar el orden o la distancia entre isotipo, nombre y subtítulo.
- No aplicar degradados, sombras, biseles, brillos, transparencias ni efectos 3D.
- No añadir coronas, escudos, botellas, marcos o eslóganes dentro del lockup.
- No sustituir el dorado por amarillo brillante ni el rojo por tonos no aprobados.
- No encerrar el lockup completo en otra forma.
- No usar la versión con subtítulo a un tamaño donde el texto no sea legible.
- No combinar estos assets con referencias visibles a la identidad anterior.

## 9. Aplicaciones previstas

| Contexto | Variante recomendada | Regla |
|---|---|---|
| Navbar storefront | Horizontal color | 160–200 px; si baja de 180 px usar compacta |
| Sidebar workspace | Compacta / isotipo | Compacta expandida; isotipo a 32 px colapsada |
| Login | Secundaria vertical | Centrada, ancho recomendado 160–220 px |
| Footer | Horizontal invertida | Sobre carbón, ancho 140–180 px |
| Favicon | `icon_stage2-identity_favicon_20260821_32.svg` | 32 px; nunca usar el lockup |
| App icon | `icon_stage2-identity_app_20260821_512.svg` | Exportar a 512, 192 y 180 px cuando se integre |
| Comprobantes | Horizontal color o mono oscuro | Respetar 45 mm en impresión |
| Email header | Horizontal color | SVG no siempre compatible: exportar PNG @2x en Stage 2.1B |
| Mobile | Compacta o isotipo | No reducir la principal con subtítulo |
| Loading / splash | Secundaria o isotipo | Sin animación hasta definir motion system |

## 10. Handoff y límites de esta etapa

Los assets viven en `Proyecto_Final/wwwroot/brand/stage2/` y no están referenciados por ninguna vista, layout o CSS. Los PNG/ICO heredados siguen intactos para evitar iniciar implícitamente Stage 2.1B.

El app icon conserva el monograma dentro de una zona segura central para tolerar máscaras circulares o redondeadas del sistema operativo. No agregar texto al favicon ni al app icon.

La siguiente etapa podrá:

1. exportar PNG/ICO derivados de la fuente vectorial;
2. sustituir referencias heredadas de manera controlada;
3. conectar los tokens de marca con el Design System;
4. validar navbar, sidebar, login, email y comprobantes en sus contextos reales.

No se autoriza inferir de este documento un rediseño masivo de pantallas.
