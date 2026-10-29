# Capacidad de garantías — autorización explícita

Autorización humana de 2026-10-14: GARANTIAS_GESTIONAR únicamente al perfil existente
Administrador, PerfilId 1. El nombre informal «administración» fue aclarado antes de
escribir. No concede nada a Supervisor, Empleado, Soporte ni otros perfiles.

Requiere 0034 por hash, catálogo acreditado y respaldo restaurable anterior al conjunto
0034/0035. Usar `sqlcmd -I -b -f 65001` y hash real. Crea la definición de permiso que
MVC ya requiere y la asignación explícita; rechaza definiciones incompatibles y grants
ajenos al alcance. No activa un permiso previamente deshabilitado ni elimina grants
encontrados. El evento de auditoría usa ORIGINAL_LOGIN() como identidad real del
operador SQL; no inventa una correspondencia con un usuario de aplicación.

Los triggers existentes invalidan stamps/sesiones anteriores de Administrador al
insertar la asignación. Después se requiere autenticarse nuevamente. Se conservan
los permisos ajenos y stamps de otros perfiles. No crea relaciones comerciales ni
excepciones administrativas: las comprobaciones de capacidad permanecen en MVC/SQL.

Probar en copia la asignación única, denegación a otro perfil y resolución autenticada
SQL/HTTP de una garantía sintética. No usar el fixture histórico como acreditación de
entrega física para crear garantías nuevas.

Para compensar se requiere autorización explícita de revocación; esa operación debe
invalidar stamps y conservar auditoría/ledger. No eliminar el permiso ni reescribir la
migración aplicada, y no restaurar automáticamente sobre datos posteriores.
