# Stage 2 — Design System y layouts piloto

## Alcance

Esta base visual convive con la interfaz heredada. Solo `Home/Index` y `Admin/Index` migran durante Stage 2.1B; las demás vistas continúan usando `_Layout.cshtml` y sus hojas históricas. No se cambian controladores, servicios, rutas, permisos ni lógica de negocio.

## Arquitectura

- Tokens en tres niveles: primitivas, semántica y componentes. Todos usan el prefijo `--djj-*`.
- CSS aislado bajo `wwwroot/css/stage2`; no depende de Bootstrap ni Font Awesome.
- Iconografía Phosphor Regular 2.1.1 servida como sprite SVG local desde `_DjjIconSprite.cshtml`.
- Tipografía DM Sans en pesos 400, 500 y 700, con fallback de sistema.
- `_StorefrontLayout`: navegación comercial, búsqueda, cuenta, carrito y footer.
- `_WorkspaceLayout`: navegación operativa filtrada por permisos, topbar y contenido de densidad media.
- `_FieldLayout`: shell mobile-first para futuras vistas de chofer; su creación no migra todavía `DriverDeliveries`.

## Componentes fundacionales

Botones, icon buttons, campos, selects, textarea, checks, badges, estados, alerts, toast, cards, KPI cards, product cards, tablas, breadcrumb, paginación, búsqueda, filtros, estados vacíos/carga/error, modal y drawer.

## Accesibilidad y responsive

- Enlaces para saltar al contenido, foco visible y orden de teclado predecible.
- Drawers con `aria-expanded`, `aria-hidden`, cierre con Escape, restauración de foco y contención básica del foco.
- Controles táctiles de 44 px y navegación de campo compatible con safe areas.
- Escala progresiva desde 320 px y puntos de ajuste en 360, 576, 768 y 1024 px; los contenedores siguen funcionando en 1280 y 1440 px.
- Movimiento reducido respetado desde la base y sin animaciones decorativas continuas.

## Deuda heredada documentada

Las hojas `custom-theme.css`, `style.css`, `admin.css` y los paquetes Bootstrap/Font Awesome continúan activas únicamente a través de `_Layout.cshtml`. No se cargan en los layouts Stage 2, por lo que no afectan los pilotos. Su retirada debe realizarse por módulo en migraciones posteriores, nunca como reemplazo global.
