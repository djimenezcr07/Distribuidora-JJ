# Decisión de arquitectura: MVC y API

## Decisión

MVC es la aplicación de primera parte y mantiene acceso directo a SQL mediante servicios de dominio y procedimientos almacenados. La API es un límite externo: autenticación para MVC y catálogo de productos para consumidores externos o integraciones futuras. El endpoint de productos no es la capa interna oficial del catálogo MVC.

## Motivo

Forzar a MVC a consumir su propio catálogo por HTTP agregaría latencia, otro punto de fallo y contratos duplicados sin mejorar ownership ni transacciones. Los flujos de carrito, promociones, inventario y checkout necesitan coherencia con la misma base y procedimientos transaccionales. La API de productos permanece de solo lectura y comparte el esquema canónico, pero no sustituye esos servicios internos.

## Reglas de coherencia

- MVC y API leen el mismo esquema versionado y no mantienen bases o modelos de producto independientes.
- Los cambios de columnas/procedimientos requieren migración, verificación sintáctica y pruebas de mapeo en ambos proyectos.
- La API no expone mutaciones de inventario hasta que exista un caso externo, autenticación de servicio, idempotencia y auditoría definidos.
- Un refactor hacia API interna solo se justifica si el sistema se separa en servicios desplegables con observabilidad, resiliencia y contratos versionados.
