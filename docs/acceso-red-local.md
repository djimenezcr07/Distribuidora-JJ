# Acceso local desde celular u otra computadora

## Objetivo

Permitir probar el proyecto DistribuidoraJJ desde otro dispositivo conectado a la misma red local, por ejemplo un teléfono o una laptop de un compañero.

## Regla importante

Esta configuración es solo para desarrollo y demostración local. No expone el sistema a internet y no debe usarse como despliegue productivo.

## Perfiles agregados

### MVC

Perfil: `RedLocal-MVC`

URL local de red:

```text
http://0.0.0.0:5013
```

Desde otro dispositivo se abre usando la IP local de la computadora:

```text
http://IP-DE-LA-LAPTOP:5013
```

Ejemplo:

```text
http://192.168.1.25:5013
```

### API

Perfil: `RedLocal-API`

URL local de red:

```text
http://0.0.0.0:5040
```

Normalmente no hace falta abrir la API desde el celular, porque el usuario usa el MVC. La API puede seguir ejecutándose localmente como siempre.

## Pasos de prueba recomendados

1. Conectar la laptop y el teléfono a la misma red Wi-Fi.
2. Obtener la IP local de la laptop con:

```powershell
ipconfig
```

3. Buscar la línea `Dirección IPv4` del adaptador Wi-Fi.
4. Ejecutar la API.
5. Ejecutar el MVC con el perfil `RedLocal-MVC`.
6. Abrir en el celular:

```text
http://IP-DE-LA-LAPTOP:5013
```

## Firewall de Windows

Si el celular no logra abrir la página, ejecutar PowerShell como administrador y agregar la regla:

```powershell
netsh advfirewall firewall add rule name="DistribuidoraJJ MVC 5013" dir=in action=allow protocol=TCP localport=5013
```

Si se necesita probar la API desde otro dispositivo:

```powershell
netsh advfirewall firewall add rule name="DistribuidoraJJ API 5040" dir=in action=allow protocol=TCP localport=5040
```

## No subir configuraciones locales sensibles

No subir cambios de:

```text
appsettings.json
appsettings.Development.json
Proyecto_FinalAPI/appsettings.json
Proyecto_FinalAPI/appsettings.Development.json
```

## Problemas comunes

### El celular no abre la página

Revisar:

- Que ambos dispositivos estén en la misma red Wi-Fi.
- Que no sea una red de invitados.
- Que Windows Firewall permita el puerto 5013.
- Que el proyecto MVC esté ejecutándose con el perfil `RedLocal-MVC`.
- Que se esté usando `http`, no `https`.

### El login no funciona

Revisar:

- Que la API esté levantada.
- Que la base de datos esté disponible.
- Que `ApiSettings:BaseUrl` apunte a la API correcta en la computadora local.

### El navegador redirige a HTTPS

En desarrollo se desactiva la redirección automática a HTTPS para permitir pruebas por HTTP desde la red local. En producción la redirección HTTPS se mantiene activa.
