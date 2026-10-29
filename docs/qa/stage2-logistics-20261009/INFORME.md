# Stage 2 — Bloque 7: operaciones logísticas

Fecha de trabajo: 9 de octubre de 2026. Alcance local de presentación; no certifica las mutaciones SQL/E2E de logística ni la integración de pedidos del Bloque 6.

| Punto | Resultado y evidencia |
| --- | --- |
| 1. SHA inicial | `f05ee9f137f3698c25dfd7e197d01bab2fad5c41`; rama `codex/stage2-design-system`; ahead 5 / behind 0 contra la referencia local de origin. |
| 2. Auditoría | Siete vistas, sus controllers, modelos, servicios, permisos, layouts, historia Git, JavaScript, contratos SQL de logística/evidencia privada y pruebas. Fleet solo tiene Alerts, Maintenance y Mileage; Mileage queda fuera. |
| 3. Contratos | Se conservan acciones, verbos, nombres de binding, hidden, antiforgery, selecciones y condiciones de estado. Controllers, servicios, modelos operativos y SQL no cambian. |
| 4. Fleet Alerts | Bandeja tabular con categoría, unidad, contexto, fecha y severidad literal; filtro GET por días y registro de documento intactos. El modelo de alerta no expone kilometraje ni un identificador para acciones por fila; no se inventan. |
| 5. Fleet Maintenance | Formulario e historial con taller, costo, programación, realización, próximo kilometraje, registro y actor. Costo tabular alineado a la derecha sin partirse. Completar conserva ordenId/costo y confirmación. El modelo usa Descripcion y Taller; no existe Observaciones independiente. |
| 6. RoutesAdmin Index | Tabla con identidad, zona, chofer, unidad, estado, pedidos, entregadas/fallidas/pendientes, creación, despacho y detalle. Búsqueda/estado GET intactos. |
| 7. RoutesAdmin Create | Datos de ruta y asignaciones separados; Zona/ChoferUsuarioId/VehiculoId/Observaciones, lista PedidosSeleccionados y sus selecciones preservados. Validación por campo y resumen. Sin recursos se advierte y deshabilita la creación. No existe fecha/horario editable en este contrato; no se agrega. |
| 8. RoutesAdmin Detail | Identidad, creador, fechas, observaciones, cliente/correo/dirección, importe, estado del pedido/entrega, motivo de fallo y evidencias. Se conservan Sequence, Dispatch, Liquidate, Cancel, Recalculate, RemoveOrder, AddOrder y SaveSequence y sus condiciones. |
| 9. RoutesAdmin Evidences | Resumen por pedido y archivos con tipo, fecha, autor, observaciones y consulta autorizada. Sin evidencia/archivos se muestra contexto explícito. |
| 10. DeliveryBoard | Cuatro métricas originales, tabla de rutas, asignación, despacho y progreso. Atención requerida usa EntregasFallidas real. Búsqueda/estado locales afectan solo tabla. Actualización GET cada 15 s con pausa, prevención de concurrencia, timeout y preservación del último snapshot si falla. |
| 11. Mapas | Leaflet 1.9.4 existente; pins y tooltips mediante DOM/textContent. Coordenadas finitas dentro de rangos geográficos. Enlace Maps filtra coordenadas inválidas. Tabla equivalente editable con teclado; fallback si Leaflet o tiles fallan. Ninguna ubicación se guarda durante QA. |
| 12. Evidencia privada | Solo DeliveryEvidence/View por id; sin storage keys, URLs físicas/públicas ni cambios de StorageStatus. Se mantiene GetAuthorizedEvidenceAsync y el filtro Ready existente. MIME de imágenes limitado a JPEG/PNG/WebP para preview; error muestra fallback. No se mueven archivos históricos ni se convierten Legacy/Pending. |
| 13. Navegación | Workspace agrega destinos de logística; partial de dominio usa FLOTA_MANTENIMIENTO, RUTAS_GESTIONAR y ENTREGAS_TABLERO_VER. Links de detalle del tablero exigen RUTAS_GESTIONAR. Breadcrumb vuelve al dominio permitido. Field y DriverDeliveries permanecen intactos. |
| 14. Estados | Planificada/Despachada/Completada/Cancelada; Pendiente/EnRuta/Entregado/Fallido; Programada/EnProceso/Completada; Vencido/PorVencer. Texto presente y semántica Stage 2; desconocidos literales y neutrales, incluidos nombres de propiedades de prototipo. |
| 15. Responsive | Las siete vistas a 1440, 1280, 768 y 390: 28 casos reales y 28 sintéticos sin overflow horizontal de página. Scroll local de tablas. Variantes vacías, sin recursos, ruta despachada y permisos restringidos comprobadas. Se corrigió el overflow de texto accesible absoluto del tablero con contención posicionada y la alerta de recursos vacíos. |
| 16. Accesibilidad | Un h1 por vista, headings, labels, captions, scope, texto de botones, alternativas al mapa, aria-expanded/pressed y estados anunciados. Apertura local lleva foco al control visible, no al hidden. Sidebar móvil: apertura, Escape, cierre y retorno de foco comprobados. Tokens, foco y reduced-motion del sistema existentes; no se declara conformidad WCAG completa. |
| 17. QA real | API/MVC contra configuración local existente de TrilogiaDev, login manual de Administrador. GET de las siete vistas, rutas existentes despachada/completada, evidencias sin archivo y tablero. Nueve rutas y las métricas mostradas provienen del servidor; no se fabrican valores. Filtro local sin coincidencias/limpiar/pausar/reanudar y snapshot GET 200 comprobados. No se envía ningún POST operativo. |
| 18. QA sintético | Host privado sin servicios SQL, modelos sintéticos y vistas Razor reales compiladas; solo GET. Registros, importes extensos, estados desconocidos, selección de pedido, mapa Planificada, preview de imagen y estados vacíos. Fixture y recursos quedan fuera de Git bajo .git/codex-checkpoints/stage2-logistics/20261009. |
| 19. Console | Captura CDP por navegación real y sintética final: cero excepciones/errores relevantes; por página sin truncamiento. La primera captura acumulada sintética se truncó y se descartó a favor de captura individual. |
| 20. Network | Captura real de 28 navegaciones: cero >=400 inesperados y cero loadingFailed. Captura individual de siete vistas sintéticas también limpia. Snapshot real observado en tres ciclos: HTTP 200. No se abre Google Maps externo. |
| 21. Build | dotnet build Proyecto_Final.Tests/Proyecto_Final.Tests.csproj -c Debug: cero errores y cero advertencias. Host sintético también compila limpio. Tras build solo se ajustaron CSS/JS y whitespace Razor sin cambio semántico. |
| 22. .NET productivo | 406 correctas, 0 fallidas, 0 omitidas; baseline 382 + 24 regresiones del bloque. TRX privado. |
| 23. Laboratorio | OrdersIntegrationContractTests.cs era untracked y se compilaba por glob. Antes de ejecutar suite se preservó copia idéntica y se movió el original al checkpoint privado como OrdersIntegrationContractTests.excluded.cs. SHA-256 FF036AEDF72D5D88DA02707B99602FE6CD6AA135EAF007F6382A17C65EB05C42; sin edición. Cero pruebas de laboratorio incluidas en las 406. Bloque 6B intacto. |
| 24. JS | Foundations 11 + Commerce 7 + Orders 13 + Logistics 25 = 56 correctas, 0 fallidas/omitidas. Se ejecuta JavaScript real aislado para snapshots, error, permisos, filtro, pausa, foco, estados desconocidos/XSS, mapas/coordenadas y evidencia. |
| 25. Diff check | git diff --check correcto. La comprobación cached se realiza antes del checkpoint; salida conservada privada. |
| 26. Diff stat | Se incluyen únicamente las siete vistas, layout/partial, helper de presentación, CSS/logistics JS, pruebas y este informe: 17 archivos. Estadística exacta del staging en la salida final del checkpoint. |
| 27. SHA del commit | El SHA completo se entrega tras crear el checkpoint local; este informe se incluye en ese commit y no se introduce un SHA circular. Mensaje: feat(stage2): modernize fleet and delivery operations. |
| 28. Git status | Las cuatro vistas previas siguen modificadas fuera del commit; personal/untracked ajeno intacto. Salida exacta final se conserva privada y se entrega al cerrar. |
| 29. Exclusiones | Fleet/Mileage; Vehicles/Create, Edit, Index; experimento de contratos; .agents/.cache; documentos personales, reportes Azure, capturas/logs; fixture; candidate.sql y todo Bloque 6B. Hashes de cuatro vistas iguales a los iniciales. |
| 30. Limitaciones | No se prueban mutaciones reales ni confirmaciones destructivas enviando formularios. No hay rutas Planificada ni archivos Ready disponibles en las rutas reales inspeccionadas: mapa/editor y preview se validan en fixture y JS real aislado. No se certifica autorización de descarga de un archivo real disponible. Dependencia CDN/tiles externa preexistente. El gate SQL/E2E de pedidos sigue pendiente. |
| 31. Restricciones | NO PUSH / NO PR / NO ESCRITURA REMOTA / NO MIGRACIONES / NO CAMBIOS DE DATOS OPERATIVOS. Sin SQL, connection strings ni User Secrets editados; sin merge/rebase. |

## Incidencias de validación resueltas

La API fue iniciada inicialmente con un perfil inexistente y escuchó en un puerto incorrecto; se reinició con el perfil Proyecto_FinalAPI existente, sin editar configuración. Se confirmó el login administrativo final y el QA se ejecutó con esa versión. También se corrigieron overflow móvil, el foco que encontraba primero un hidden y la compresión de texto de botones/badges dentro de tablas. Las correcciones de CSS/JS están limitadas a .djj-logistics.

## Archivos propios del checkpoint

- Proyecto_Final/Views/Fleet/Alerts.cshtml
- Proyecto_Final/Views/Fleet/Maintenance.cshtml
- Proyecto_Final/Views/RoutesAdmin/Index.cshtml
- Proyecto_Final/Views/RoutesAdmin/Create.cshtml
- Proyecto_Final/Views/RoutesAdmin/Detail.cshtml
- Proyecto_Final/Views/RoutesAdmin/Evidences.cshtml
- Proyecto_Final/Views/DeliveryBoard/Index.cshtml
- Proyecto_Final/Views/Shared/_WorkspaceLayout.cshtml
- Proyecto_Final/Views/Shared/_LogisticsNavigation.cshtml
- Proyecto_Final/Models/Presentation/LogisticsStatusPresentation.cs
- Proyecto_Final/wwwroot/css/stage2/workspace.css
- Proyecto_Final/wwwroot/js/stage2/logistics-ui.js
- Proyecto_Final/wwwroot/js/stage2/route-admin-map.js
- Proyecto_Final/wwwroot/js/stage2/delivery-board.js
- Proyecto_Final.Tests/LogisticsPresentationTests.cs
- scripts/ui/stage2-logistics.test.cjs
- docs/qa/stage2-logistics-20261009/INFORME.md
