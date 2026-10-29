# Diagnóstico de login Azure y Sprint 4

## Problema observado

El MVC y el API iniciaban correctamente, pero el acceso con la cuenta administrativa informada terminaba en `401` y el mensaje genérico `Correo o contraseña incorrectos.`.

## Causa raíz confirmada

- Tanto el proceso local como la configuración de usuario apuntan a `sql-trilogia-cursos-dev-cr01.database.windows.net` y `DistribuidoraJJ_DB_DEV`.
- El MVC consume el API local configurado en `https://localhost:57540/`.
- La cuenta administrativa existe, está activa y pertenece al perfil `Administrador`.
- `dbo.sp_Auth_ValidateUser` tiene la firma correcta y devuelve las seis columnas compatibles con el API.
- El procedimiento devuelve una fila cuando recibe la credencial que está almacenada actualmente. El valor almacenado no es nulo, tiene 47 caracteres y no presenta espacios ASCII iniciales/finales.
- La respuesta `401` implica que la contraseña presentada no coincide con el valor que permanece almacenado. No hay evidencia de que el restablecimiento mencionado se haya aplicado a esta cuenta en esta base.

Se detectaron además defectos de robustez que no explicaban por sí solos esta cuenta: `Trim()` sobre la contraseña, `AddWithValue`, lectura por posiciones y una excepción de MVC sin logging.

No se cambió ninguna contraseña. Para completar el login real se requiere que el propietario defina una contraseña de prueba por un canal seguro y aplique el procedimiento de restablecimiento autorizado sin incluir el valor en Git ni en evidencias.

## Contrato real de Azure

```text
dbo.sp_Auth_ValidateUser
  @Correo NVARCHAR(150)
  @Contrasena NVARCHAR(255)

Resultado:
  0 UsuarioId INT
  1 NombreCompleto NVARCHAR(150)
  2 Correo NVARCHAR(150)
  3 PerfilId INT
  4 PerfilNombre NVARCHAR(50)
  5 Activo BIT
```

La verificación directa del contrato se realizó sin seleccionar ni imprimir contraseñas.

## Cambios de aplicación

- Parámetros `SqlParameter` con tipo y longitud explícitos.
- El correo se normaliza; la contraseña se transmite sin recortarla ni transformarla.
- Mapeo por nombre de columna para evitar dependencia del orden físico.
- Interfaz `IAccountApiDbService` para pruebas aisladas.
- Logging seguro de procedimiento, servidor y base; nunca credenciales ni connection string.
- El MVC registra fallos del API y mantiene un mensaje genérico.
- `GetUserByEmailAsync` dejó de cargar la contraseña retornada por el procedimiento histórico.
- El almacenamiento privado se valida y crea al iniciar el MVC.

## Azure Sprint 4

El ledger registra 0007–0011 como `Applied` en `DistribuidoraJJ_DB_DEV`. La verificación independiente encontró todas las tablas, vista y procedimientos esperados, 55 columnas obligatorias, índices, foreign keys y checks activos. Los 16 permisos obligatorios están asignados al perfil Administrador.

Esto no implica que 0002–0006 estén aplicadas ni que el historial completo sea consecutivo.

## Pruebas

- Conectividad API y MVC: HTTP 200.
- Credencial inválida: `401` y mensaje genérico.
- Rutas `/Documents`, `/Documents/Alerts`, `/Budgets`, `/Expenses` y `/BudgetComparison`: redirección a login sin sesión.
- Contrato SQL: procedimiento ejecutable con la credencial almacenada, seis columnas compatibles.
- Pruebas automatizadas: contrato tipado, contraseña con espacios, mapeo por nombre, rol Administrador, rechazo genérico y rate limit.
- Almacenamiento local: cuatro directorios privados creados fuera de `wwwroot` y escribibles al propagar las variables al proceso.

## Riesgo de contraseñas en texto directo

Azure contiene 38 cuentas con credencial directa, cero valores con formato hash reconocible y no existe una columna `ContrasenaHash`. La comparación actual ocurre dentro de SQL.

No es seguro crear una migración de hash aislada sin modificar simultáneamente registro, login, recuperación, administración de usuarios y despliegue. Tampoco se deben inventar hashes para usuarios existentes.

Plan recomendado:

1. Añadir de forma aditiva `ContrasenaHash`, `PasswordVersion`, `DebeCambiarContrasena` y timestamps mediante una migración revisada.
2. Mover la verificación al API con `PasswordHasher<TUser>` y comparación de tiempo constante.
3. Guardar únicamente hashes para registros y restablecimientos nuevos.
4. Obligar a los usuarios existentes a restablecer su contraseña mediante token de un solo uso; no copiar texto directo a logs ni scripts.
5. Mantener compatibilidad temporal controlada y medible; realizar rehash al login cuando corresponda.
6. Después de migrar todas las cuentas y verificar recuperación, retirar el acceso a la columna antigua mediante otra migración aprobada.

## Pasos reproducibles pendientes

1. Definir fuera del repositorio una contraseña temporal conocida para el administrador autorizado.
2. Aplicarla mediante el procedimiento administrativo acordado, registrando únicamente usuario afectado, fecha y ejecutor.
3. Reiniciar API/MVC para limpiar limitadores en memoria y heredar variables actualizadas.
4. Probar primero `POST /api/auth/login` y luego el formulario MVC.
5. Ejecutar el bloque autenticado de CU-201 a CU-223 y adjuntar evidencia sin datos sensibles.

