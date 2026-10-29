# Alcance funcional: checkout y cuentas por cobrar

## Checkout

El checkout crea pedidos y descuenta inventario de forma transaccional. Los medios `SINPE Móvil simulado`, `Tarjeta demo` y `Transferencia simulada` son exclusivamente académicos: no contactan pasarelas, no realizan cobros y no deben recibir números de tarjeta, CVV ni credenciales bancarias.

Se retiraron `FacturaElectronica`, `TipoCliente` y `Telefono2` de la interfaz y del contrato de entrada porque no tenían persistencia ni un efecto operativo verificable. Su reintroducción requiere definir el contrato fiscal o comercial, persistencia, validación y pruebas de extremo a extremo.

## Crédito y cuentas por cobrar

`AccountsReceivableAdmin` es la experiencia canónica para consultar cuentas, configurar el crédito y registrar movimientos. Las rutas de `Credits` se conservan temporalmente por compatibilidad, pero ya no se publican en la navegación. Una retirada futura debe confirmar primero que no existan enlaces externos ni marcadores activos.
