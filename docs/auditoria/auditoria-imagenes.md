# Auditoría del ciclo de imágenes de productos

## Controles existentes

`ProductImageStorageService` impone 2 MiB, extensiones JPG/JPEG/PNG/WEBP, MIME exacto, firmas binarias, nombres GUID y comprobación de traversal. `InventoryController` usa antiforgery y el rate limit `private-file-upload` al crear o editar.

| Flujo | Ubicación actual | Estado |
|---|---|---|
| Crear con imagen | `InventoryController.Create`, POST, líneas 49-84 | Compensa el archivo nuevo si falla DB |
| Editar/reemplazar | `InventoryController.Edit`, POST, líneas 96-137 | Conserva anterior si falla DB; borra anterior después del update |
| Retirar imagen | no especificado | No existe endpoint explícito |
| Eliminar producto | `DeletePermanent`, líneas 182-202 | No elimina la imagen; posible huérfano |
| Inventario | `Views/Inventory/Index.cshtml` | Imagen o fallback |
| Tienda/listado | `Views/Home/Index.cshtml`, `Shop.cshtml` | Imagen o fallback |
| Detalle | `Views/Home/Detail.cshtml` | Imagen o fallback |
| Carrito | `Views/Cart/Index.cshtml` | Imagen o fallback |

## Brechas

- Raíz fija: `wwwroot/uploads/productos`; puede ser efímera en App Service.
- No hay configuración de almacenamiento persistente.
- No hay retiro explícito ni limpieza auditada de huérfanos.
- `DeletePermanent` puede dejar el archivo anterior.
- Un fallo al borrar la imagen vieja ocurre después del commit DB y puede producir respuesta fallida con DB ya actualizada.
- Autorización por módulo `Inventario`, no por permisos exactos de lectura/escritura/retiro.
- Comparación de rutas usa `OrdinalIgnoreCase` también en Linux; requiere prueba o estrategia sensible a plataforma.
- Falta prueba controlador-servicio, compensación DB, orden de reemplazo, retiro, GET/fallback y autorización positiva/negativa.
- Existe un upload de evidencia versionado bajo `wwwroot/uploads/evidencias`; su contenido no se inspeccionó ni eliminó durante AUDIT_ONLY.

## Plan posterior a Puerta A

1. Inventariar URLs y archivos existentes sin borrarlos.
2. Introducir opciones de almacenamiento y una raíz persistente fuera del árbol de publicación cuando corresponda.
3. Añadir endpoint de lectura/fallback y claves opacas, sin paths físicos en URLs.
4. Añadir permisos exactos y endpoint de retiro auditado.
5. Compensar reemplazo/eliminación y registrar huérfanos sin romper el commit DB.
6. Añadir solo las pruebas faltantes; no duplicar extensión, MIME, firma o traversal.
7. Probar Windows y una ejecución Linux en CI cuando sea viable.

No se eliminó ni movió ninguna imagen.
