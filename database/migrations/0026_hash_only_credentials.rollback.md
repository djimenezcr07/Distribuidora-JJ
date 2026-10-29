# Rollback 0026

No existe rollback automático a contraseñas en texto plano. Los hashes PBKDF2 no son reversibles y nunca deben transformarse ni copiarse a `Contrasena`.

Si fuera imprescindible volver a una versión anterior, primero debe adaptarse esa versión para consumir hashes o forzar restablecimientos controlados. Mantener `Contrasena` vacía, conservar el trigger de revocación y registrar la compensación como migración nueva. Restaurar un BACPAC es el último recurso y requiere aprobación expresa.
