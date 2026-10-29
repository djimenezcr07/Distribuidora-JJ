# Incidente de seguridad: credencial SMTP expuesta

## Estado

- Fecha de detección confirmada: 2026-07-22.
- Clasificación: credencial reutilizable expuesta en archivos rastreados por Git.
- Archivos actuales afectados al iniciar el saneamiento:
  - `Proyecto_Final/appsettings.json`.
  - `Proyecto_Final/appsettings.Development.json`.
  - `Proyecto_FinalAPI/appsettings.json`.
  - `Proyecto_FinalAPI/appsettings.Development.json`.
- Estado del árbol actual: valores sensibles eliminados y sustituidos por campos vacíos.

## Alcance histórico aproximado

El historial de esos archivos comienza, como mínimo, en `e91758e` y tuvo múltiples modificaciones hasta `12a5c91`. La reintroducción reciente aparece dentro del intervalo aproximado `5e93f16..12a5c91`. Este rango sirve para orientar la investigación; no demuestra por sí solo en qué revisiones cada valor fue utilizable.

No se reproduce ninguna credencial en este documento. Todo valor histórico debe tratarse como comprometido.

## Riesgo

Una contraseña de aplicación SMTP o una cadena SQL conservada en Git puede recuperarse desde clones, forks, caches y revisiones antiguas aunque se elimine del último commit. El retiro del valor actual no lo revoca en el proveedor.

## Contención aplicada

1. Se vaciaron cadenas de conexión, remitentes y contraseñas en los cuatro `appsettings` compartidos.
2. Se retiraron bloques comentados que preservaban configuraciones anteriores.
3. Se reforzó el escáner para revisar archivos rastreados, JSON comentado, cadenas con password, tokens conocidos y candidatos de alta entropía asociados a nombres sensibles.
4. Se reforzó `.gitignore` para configuración local, secretos, respaldos y datos privados.
5. La configuración real debe llegar por variables de entorno, User Secrets o App Service Configuration.

## Acción externa obligatoria

El propietario de la cuenta debe revocar o rotar manualmente la contraseña de aplicación SMTP expuesta y revisar accesos recientes en el proveedor. Esta operación no se automatiza porque afecta una cuenta externa y puede interrumpir a otros colaboradores.

Después de rotarla, configurar los valores nuevos únicamente por canal privado:

```text
ConnectionStrings__DefaultConnection
ConfiguracionCorreo__Remitente
ConfiguracionCorreo__Contrasenna
```

## Limpieza coordinada del historial

La reescritura cambia identificadores de commit y exige coordinación. No ejecutar mientras existan ramas o trabajos sin publicar.

Procedimiento conservador con `git-filter-repo`:

```bash
git clone --mirror https://github.com/d0j0fre/Desarrollo_Trilogia.git Desarrollo_Trilogia-clean.git
cd Desarrollo_Trilogia-clean.git
git filter-repo --sensitive-data-removal --invert-paths \
  --path Trilogia-Cursos/Proyecto_Final/appsettings.json \
  --path Trilogia-Cursos/Proyecto_Final/appsettings.Development.json \
  --path Trilogia-Cursos/Proyecto_FinalAPI/appsettings.json \
  --path Trilogia-Cursos/Proyecto_FinalAPI/appsettings.Development.json
git fsck --full
```

Antes de publicar, revisar refs y coordinar una ventana de mantenimiento. La publicación, solo con autorización explícita del equipo, sería:

```bash
git push --force --mirror origin
```

Después de la reescritura se deben volver a agregar los cuatro archivos como plantillas sanitizadas en un commit nuevo.

## Instrucciones para colaboradores

1. Publicar o respaldar parches locales antes de la ventana acordada.
2. Eliminar el clon antiguo después de verificar que no contiene trabajo único.
3. Clonar nuevamente desde GitHub.
4. No mezclar ramas creadas sobre los identificadores antiguos.
5. Recrear User Secrets o variables de entorno desde el canal privado.
6. Ejecutar el escáner y el build antes de continuar.

## Criterio de cierre

El incidente solo puede cerrarse cuando se confirme la rotación externa, se revise el entorno desplegado y el equipo decida si ejecutará la limpieza histórica. El saneamiento del árbol actual, por sí solo, no cierra el incidente.
