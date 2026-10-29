using Microsoft.Data.SqlClient;
using Proyecto_Final.Models.Admin;
using System.Data;
using System.Text;

namespace Proyecto_Final.Services
{
    // CU-261 / CU-263 — Asistente virtual integral basado en reglas (sin IA externa).
    // Interpreta la intención por palabras clave, responde con métricas del negocio
    // (foto de sp_Asistente_Metricas) y aplica control de acceso por rol.
    public class AssistantService
    {
        private readonly string _connectionString;
        private readonly ILogger<AssistantService> _logger;
        private readonly IRolePermissionService _permissionService;

        public AssistantService(
            IConfiguration configuration,
            ILogger<AssistantService> logger,
            IRolePermissionService permissionService)
        {
            _connectionString = configuration.GetConnectionString("DefaultConnection")
                ?? throw new InvalidOperationException("No se encontró la cadena de conexión DefaultConnection.");
            _logger = logger;
            _permissionService = permissionService;
        }

        // ── Categorías y control de acceso por permisos efectivos ──
        private const string Fin = "financiero", Inv = "inventario", Ops = "operativo",
                             Log = "logistica", Cli = "clientes", Rh = "personal";

        private static readonly HashSet<string> Todas = new() { Fin, Inv, Ops, Log, Cli, Rh };

        private static readonly Dictionary<string, string> NombreCategoria = new()
        {
            [Fin] = "Finanzas", [Inv] = "Inventario", [Ops] = "Pedidos",
            [Log] = "Logística", [Cli] = "Clientes", [Rh] = "Personal"
        };

        private static readonly Dictionary<string, string[]> CategoryPermissions = new()
        {
            [Fin] = new[] { "REPORTES_VENTAS_VER", "PRESUPUESTOS_VER", "GASTOS_VER" },
            [Inv] = new[] { "INVENTARIO_INTELIGENCIA_VER", "INVENTARIO_VER" },
            [Ops] = new[] { "PEDIDOS_VER", "COMPRAS_ORDENES_VER", "VENTA_MOVIL_CREAR_PEDIDO" },
            [Log] = new[] { "ENTREGAS_TABLERO_VER", "FLOTA_KILOMETRAJE", "FLOTA_MANTENIMIENTO" },
            [Cli] = new[] { "CLIENTES_VER", "CONSULTAS_VER" },
            [Rh] = new[] { "EMPLEADOS_VER", "PLANILLA_VER", "RRHH_JORNADAS_APROBAR" }
        };

        public async Task<HashSet<string>> GetAllowedCategoriesAsync(string? role)
        {
            var normalizedRole = (role ?? string.Empty).Trim();
            if (string.Equals(normalizedRole, "Administrador", StringComparison.OrdinalIgnoreCase))
                return new HashSet<string>(Todas);

            var allowed = new HashSet<string>();
            foreach (var (category, permissionCodes) in CategoryPermissions)
            {
                foreach (var code in permissionCodes)
                {
                    if (await _permissionService.HasCodePermissionAsync(normalizedRole, code))
                    {
                        allowed.Add(category);
                        break;
                    }
                }
            }

            return allowed;
        }

        private static readonly string[] DetalleWords = { "detalle", "mas ", "más", "amplia", "amplía", "ampliar", "profundiza", "detallado" };
        private static readonly string[] ResumenWords = { "resumen", "como va", "como vamos", "estado general", "panorama", "dashboard", "indicadores", "kpi", "reporte general", "como esta el negocio", "situacion" };
        private static readonly string[] CapacidadWords = { "que puedes hacer", "que puedo preguntar", "que puedo consultar", "opciones", "que sabes", "menu", "ayuda general", "para que sirves" };

        // ── Catálogo de intenciones (orden: específico → genérico) ──
        private static readonly List<(string Key, string Cat, string[] Kw)> Intents = new()
        {
            ("ventas_hoy",       Fin, new[]{ "ventas hoy", "venta hoy", "vendimos hoy", "vendido hoy", "ventas de hoy" }),
            ("ventas_anio",      Fin, new[]{ "ventas del ano", "venta anual", "ventas anuales", "ventas del year", "en el ano", "acumulado del ano" }),
            ("ventas",           Fin, new[]{ "venta", "vendimos", "vendido", "ingreso", "ingresos", "facturado del mes" }),
            ("facturas",         Fin, new[]{ "factura", "facturacion", "facturamos", "cuantas facturas" }),
            ("ticket",           Fin, new[]{ "ticket", "venta promedio", "promedio de venta", "valor promedio" }),
            ("cobros",           Fin, new[]{ "cobro", "cobrar", "por cobrar", "cuentas por cobrar", "saldo pendiente", "deuda", "adeud", "moroso" }),
            ("creditos",         Fin, new[]{ "credito", "limite de credito", "credito bloqueado", "bloqueado" }),
            ("valor_inventario", Fin, new[]{ "valor del inventario", "valor de inventario", "valor de la mercaderia", "cuanto vale el inventario", "valor en bodega" }),

            ("cuarentena",       Inv, new[]{ "cuarentena" }),
            ("devoluciones",     Inv, new[]{ "devolucion", "devuelto", "devueltos" }),
            ("productos",        Inv, new[]{ "cuantos productos", "total de productos", "productos activos", "cuantos articulos", "catalogo de productos" }),
            ("stock",            Inv, new[]{ "stock", "agotado", "existencia", "reabastec", "por agotar", "abastecer", "inventario", "mercaderia" }),

            ("pedidos_retenidos",Ops, new[]{ "retenido", "retenidos" }),
            ("pedidos_ruta",     Ops, new[]{ "en ruta", "reparto" }),
            ("pedidos",          Ops, new[]{ "pedido", "orden de compra", "ordenes", "cuantas ordenes" }),

            ("entregas",         Log, new[]{ "entrega", "entregas", "fallida", "fallidas", "fallido" }),
            ("rutas",            Log, new[]{ "ruta", "rutas" }),
            ("vehiculos",        Log, new[]{ "vehiculo", "vehiculos", "flota", "camion", "placa" }),
            ("kilometraje",      Log, new[]{ "kilometraje", "odometro", "kilometros" }),
            ("mantenimiento",    Log, new[]{ "mantenimiento", "taller", "reparacion" }),
            ("alertas_flota",    Log, new[]{ "alerta", "vencimiento", "vence", "marchamo", "rtv", "riteve", "seguro del vehiculo" }),
            ("activos",          Log, new[]{ "nevera", "exhibidor", "congelador", "codigo de activo", "activos de la empresa", "cuantos activos", "activos prestados", "equipos prestados" }),

            ("clientes",         Cli, new[]{ "cliente", "clientes" }),
            ("consultas",        Cli, new[]{ "consulta", "consultas", "mensaje de contacto", "buzon" }),

            ("empleados",        Rh,  new[]{ "empleado", "empleados", "colaborador", "planilla", "cuanto personal" }),
            ("solicitudes",      Rh,  new[]{ "solicitud", "licencia", "permiso de empleado", "vacacion", "incapacidad" }),
            ("tareas",           Rh,  new[]{ "tarea", "tareas" }),
        };

        private static readonly Dictionary<string, string> IntentCategoria =
            Intents.ToDictionary(i => i.Key, i => i.Cat);

        // ── Base de conocimiento de ayuda (CU-263) ──────────────
        private static readonly Dictionary<string, (string Titulo, string Texto)> Ayuda =
            new(StringComparer.OrdinalIgnoreCase)
            {
                ["inventario"] = ("Módulo de Inventario", "Operación → Inventario para ver productos y stock. 'Nuevo producto' para crear, el lápiz para editar, y 'Movimientos' para entradas, salidas o ajustes."),
                ["pedidos"] = ("Módulo de Pedidos", "Operación → Pedidos: revisa los pedidos por estado y, desde el detalle, cámbialo, retenlo o factúralo."),
                ["facturacion"] = ("Módulo de Facturación", "Operación → Facturación genera la factura de un pedido confirmado. El inventario se descontó en el checkout; no se vuelve a descontar al facturar."),
                ["clientes"] = ("Módulo de Clientes", "Clientes → Clientes administra los datos; desde Créditos gestionas su línea de crédito y movimientos."),
                ["creditos"] = ("Módulo de Créditos", "Clientes → Créditos define el límite, bloquea y registra cargos/abonos de cada cliente."),
                ["cobros"] = ("Cuentas por cobrar", "Operación → Cuentas por Cobrar muestra los saldos deudores y permite registrar abonos."),
                ["rutas"] = ("Rutas y Entregas", "Operación → Rutas: crea la ruta con chofer y vehículo, agrega pedidos, ubícalos en el mapa, secuénciala, despáchala y al final del día liquídala."),
                ["vehiculos"] = ("Vehículos", "Operación → Vehículos registra la flota (placa, marca, capacidad, odómetro)."),
                ["kilometraje"] = ("Kilometraje", "Operación → Kilometraje: el chofer registra el km inicial al salir y el final al volver; el sistema valida contra el odómetro del vehículo."),
                ["mantenimiento"] = ("Mantenimiento de flota", "Operación → Mantenimiento registra órdenes preventivas o correctivas con costo y taller."),
                ["alertas"] = ("Alertas de flota", "Operación → Alertas de flota muestra vencimientos legales (marchamo, RTV, seguro) y mantenimientos preventivos próximos o vencidos."),
                ["activos"] = ("Activos", "Operación → Activos registra neveras y exhibidores con su código de activo y controla su estado (disponible, prestado, etc.)."),
                ["devoluciones"] = ("Devoluciones", "Operación → Devoluciones registra la mercadería devuelta; pasa a cuarentena antes de reintegrarse."),
                ["cuarentena"] = ("Cuarentena", "Operación → Cuarentena libera (reintegra al stock) o descarta los productos devueltos."),
                ["empleados"] = ("Empleados", "Personal → Empleados administra el personal, asigna tareas y aprueba solicitudes de licencia."),
                ["roles"] = ("Roles y permisos", "Seguridad → Roles define perfiles; en Permisos asignas los permisos a cada rol."),
                ["consultas"] = ("Consultas", "Clientes → Consultas muestra los mensajes de contacto de los clientes para atenderlos."),
                ["asistente"] = ("Asistente", "Escríbeme una pregunta en lenguaje natural sobre métricas del negocio o sobre cómo usar un módulo. Prueba: “¿qué puedo preguntar?”."),
            };

        // ────────────────────────────────────────────────────────
        public async Task<AssistantAnswerViewModel> AskAsync(string pregunta, string? rol, string? contextoIntent, int usuarioId, string usuarioNombre)
        {
            var norm = Normalizar(pregunta);
            var permitidas = await GetAllowedCategoriesAsync(rol);
            AssistantAnswerViewModel r;

            // 1) Ampliar una métrica ya mostrada (E3): resumen de la categoría
            if (Contiene(norm, DetalleWords) && !string.IsNullOrWhiteSpace(contextoIntent)
                && IntentCategoria.TryGetValue(contextoIntent!, out var catCtx) && permitidas.Contains(catCtx))
            {
                var m = await LoadMetricsAsync();
                r = ResumenCategoria(catCtx, m);
            }
            // 2) Capacidades / "¿qué puedo preguntar?"
            else if (Contiene(norm, CapacidadWords))
            {
                r = Capacidades(permitidas);
            }
            // 3) Ayuda de uso de un módulo (CU-263 E1) — antes que métricas
            else if (DetectarAyuda(norm) is string modulo)
            {
                r = ResponderAyuda(modulo);
            }
            // 4) Resumen ejecutivo del negocio
            else if (Contiene(norm, ResumenWords))
            {
                var m = await LoadMetricsAsync();
                r = ResumenGeneral(permitidas, m);
            }
            // 5) Métrica puntual
            else if (DetectarIntent(norm) is (string key, string cat))
            {
                if (!permitidas.Contains(cat))
                {
                    r = NoAutorizado(NombreCategoria[cat], permitidas);
                }
                else
                {
                    var m = await LoadMetricsAsync();
                    r = ResponderMetrica(key, m);
                }
            }
            // 6) No interpretado (CU-261 E2 / CU-263 E2)
            else
            {
                r = NoInterpretado(permitidas);
            }

            await LogAsync(usuarioId, usuarioNombre, pregunta, r.Intent, r.Tipo, r.Interpretado);
            return r;
        }

        // ── Formateo de una métrica puntual ─────────────────────
        private static AssistantAnswerViewModel ResponderMetrica(string key, Metrics m)
        {
            var r = new AssistantAnswerViewModel { Tipo = "metrica", Intent = key, Interpretado = true };
            switch (key)
            {
                case "ventas_hoy":
                    r.Titulo = "Ventas de hoy";
                    r.Respuesta = $"Hoy se han vendido <strong>{Money(m.VentasHoy)}</strong>."; break;
                case "ventas":
                    r.Titulo = "Ventas del mes";
                    r.Respuesta = $"Las ventas del mes suman <strong>{Money(m.VentasMes)}</strong> en {m.FacturasMes} factura(s)."; break;
                case "ventas_anio":
                    r.Titulo = "Ventas del año";
                    r.Respuesta = $"En lo que va del año se han vendido <strong>{Money(m.VentasAnio)}</strong>."; break;
                case "facturas":
                    r.Titulo = "Facturación del mes";
                    r.Respuesta = $"Se han emitido <strong>{m.FacturasMes}</strong> factura(s) por {Money(m.VentasMes)} este mes."; break;
                case "ticket":
                    r.Titulo = "Ticket promedio";
                    r.Respuesta = $"El ticket promedio del mes es <strong>{Money(m.TicketPromedioMes)}</strong>."; break;
                case "cobros":
                    r.Titulo = "Cuentas por cobrar";
                    r.Respuesta = $"El saldo por cobrar asciende a <strong>{Money(m.CobrosPendientes)}</strong> · {m.CreditosBloqueados} crédito(s) bloqueado(s)."; break;
                case "creditos":
                    r.Titulo = "Créditos de clientes";
                    r.Respuesta = $"Hay <strong>{m.ClientesConCredito}</strong> cliente(s) con crédito activo y {m.CreditosBloqueados} bloqueado(s)."; break;
                case "valor_inventario":
                    r.Titulo = "Valor del inventario";
                    r.Respuesta = $"El inventario vendible vale <strong>{Money(m.ValorInventario)}</strong> a precio de venta."; break;

                case "stock":
                    r.Titulo = "Estado del inventario";
                    r.Respuesta = $"<strong>{m.StockBajo}</strong> producto(s) con stock bajo y <strong>{m.ProductosAgotados}</strong> agotado(s), de {m.TotalProductos} activos."; break;
                case "productos":
                    r.Titulo = "Productos";
                    r.Respuesta = $"Hay <strong>{m.TotalProductos}</strong> producto(s) activo(s) en el catálogo."; break;
                case "devoluciones":
                case "cuarentena":
                    r.Titulo = "Cuarentena";
                    r.Respuesta = $"Hay <strong>{m.DevolucionesCuarentena}</strong> devolución(es) en cuarentena esperando liberarse o descartarse."; break;

                case "pedidos":
                    r.Titulo = "Pedidos";
                    r.Respuesta = $"Hoy: <strong>{m.PedidosHoy}</strong> · Pendientes: <strong>{m.PedidosPendientes}</strong> · En ruta: {m.PedidosEnRuta} · Retenidos: {m.PedidosRetenidos}."; break;
                case "pedidos_retenidos":
                    r.Titulo = "Pedidos retenidos";
                    r.Respuesta = $"Hay <strong>{m.PedidosRetenidos}</strong> pedido(s) retenido(s) a la espera de autorización."; break;
                case "pedidos_ruta":
                    r.Titulo = "Pedidos en ruta";
                    r.Respuesta = $"Hay <strong>{m.PedidosEnRuta}</strong> pedido(s) actualmente en ruta."; break;

                case "entregas":
                    r.Titulo = "Entregas";
                    r.Respuesta = $"En ruta: <strong>{m.PedidosEnRuta}</strong> · Pendientes: {m.EntregasPendientes} · Fallidas: <strong>{m.EntregasFallidas}</strong>."; break;
                case "rutas":
                    r.Titulo = "Rutas";
                    r.Respuesta = $"Planificadas: <strong>{m.RutasPlanificadas}</strong> · Despachadas: <strong>{m.RutasDespachadas}</strong>."; break;
                case "vehiculos":
                    r.Titulo = "Flota de vehículos";
                    r.Respuesta = $"Hay <strong>{m.VehiculosActivos}</strong> vehículo(s) activo(s) de {m.TotalVehiculos} registrados."; break;
                case "kilometraje":
                    r.Titulo = "Kilometraje";
                    r.Respuesta = $"El control de kilometraje está activo para los {m.VehiculosActivos} vehículo(s) de la flota. Consulta el odómetro de cada uno en Operación → Vehículos."; break;
                case "mantenimiento":
                    r.Titulo = "Mantenimiento";
                    r.Respuesta = $"Hay <strong>{m.MantenimientosProgramados}</strong> orden(es) de mantenimiento programada(s)."; break;
                case "alertas_flota":
                    r.Titulo = "Alertas de flota";
                    r.Respuesta = $"Hay <strong>{m.AlertasFlota}</strong> alerta(s) de flota (vencimientos legales o mantenimientos preventivos próximos/vencidos)."; break;
                case "activos":
                    r.Titulo = "Activos";
                    r.Respuesta = $"Hay <strong>{m.TotalActivos}</strong> activo(s) registrados, de los cuales {m.ActivosPrestados} está(n) prestado(s)."; break;

                case "clientes":
                    r.Titulo = "Clientes";
                    r.Respuesta = $"Hay <strong>{m.ClientesActivos}</strong> cliente(s) activo(s) de {m.TotalClientes} registrados."; break;
                case "consultas":
                    r.Titulo = "Consultas de clientes";
                    r.Respuesta = $"Hay <strong>{m.ConsultasPendientes}</strong> consulta(s) de clientes pendiente(s) de atender."; break;

                case "empleados":
                    r.Titulo = "Personal";
                    r.Respuesta = $"Hay <strong>{m.TotalEmpleados}</strong> empleado(s) activo(s)."; break;
                case "solicitudes":
                    r.Titulo = "Solicitudes de licencia";
                    r.Respuesta = $"Hay <strong>{m.SolicitudesPendientes}</strong> solicitud(es) de licencia pendiente(s) de aprobar."; break;
                case "tareas":
                    r.Titulo = "Tareas del personal";
                    r.Respuesta = $"Hay <strong>{m.TareasPendientes}</strong> tarea(s) pendiente(s) o en proceso."; break;
                default:
                    r.Interpretado = false; r.Tipo = "no_interpretado"; r.Titulo = "Sin datos"; r.Respuesta = "No tengo esa métrica."; break;
            }
            r.Sugerencias.Add("¿Quieres más detalle?");
            r.Sugerencias.Add("Dame un resumen");
            r.Sugerencias.Add("¿Qué puedo preguntar?");
            return r;
        }

        // ── Resumen por categoría (E3 "más detalle") ────────────
        private static AssistantAnswerViewModel ResumenCategoria(string cat, Metrics m)
        {
            var r = new AssistantAnswerViewModel { Tipo = "metrica", Intent = cat, Interpretado = true, Titulo = $"Detalle de {NombreCategoria[cat]}" };
            r.Respuesta = cat switch
            {
                Fin => $"Ventas hoy: <strong>{Money(m.VentasHoy)}</strong><br/>Ventas del mes: <strong>{Money(m.VentasMes)}</strong> ({m.FacturasMes} facturas)<br/>Ventas del año: {Money(m.VentasAnio)}<br/>Ticket promedio: {Money(m.TicketPromedioMes)}<br/>Cuentas por cobrar: <strong>{Money(m.CobrosPendientes)}</strong><br/>Valor del inventario: {Money(m.ValorInventario)}",
                Inv => $"Productos activos: <strong>{m.TotalProductos}</strong><br/>Stock bajo: <strong>{m.StockBajo}</strong><br/>Agotados: <strong>{m.ProductosAgotados}</strong><br/>En cuarentena: {m.DevolucionesCuarentena}<br/>Valor del inventario: {Money(m.ValorInventario)}",
                Ops => $"Pedidos hoy: <strong>{m.PedidosHoy}</strong><br/>Pendientes: <strong>{m.PedidosPendientes}</strong><br/>Retenidos: {m.PedidosRetenidos}<br/>En ruta: {m.PedidosEnRuta}<br/>Entregados hoy: {m.PedidosEntregadosHoy}",
                Log => $"Rutas planificadas: <strong>{m.RutasPlanificadas}</strong><br/>Rutas despachadas: <strong>{m.RutasDespachadas}</strong><br/>Entregas pendientes: {m.EntregasPendientes} · fallidas: {m.EntregasFallidas}<br/>Vehículos activos: {m.VehiculosActivos}/{m.TotalVehiculos}<br/>Mantenimientos programados: {m.MantenimientosProgramados}<br/>Alertas de flota: <strong>{m.AlertasFlota}</strong><br/>Activos: {m.TotalActivos} ({m.ActivosPrestados} prestados)",
                Cli => $"Clientes activos: <strong>{m.ClientesActivos}</strong> de {m.TotalClientes}<br/>Consultas pendientes: <strong>{m.ConsultasPendientes}</strong><br/>Clientes con crédito: {m.ClientesConCredito}",
                Rh => $"Empleados activos: <strong>{m.TotalEmpleados}</strong><br/>Solicitudes de licencia pendientes: <strong>{m.SolicitudesPendientes}</strong><br/>Tareas pendientes/en proceso: {m.TareasPendientes}",
                _ => "Sin datos."
            };
            r.Sugerencias.Add("Dame un resumen general");
            r.Sugerencias.Add("¿Qué puedo preguntar?");
            return r;
        }

        // ── Resumen ejecutivo (filtrado por rol) ────────────────
        private static AssistantAnswerViewModel ResumenGeneral(HashSet<string> permitidas, Metrics m)
        {
            var sb = new StringBuilder();
            if (permitidas.Contains(Fin))
                sb.Append($"💰 <strong>Ventas del mes:</strong> {Money(m.VentasMes)} ({m.FacturasMes} facturas) · Por cobrar: {Money(m.CobrosPendientes)}<br/>");
            if (permitidas.Contains(Ops))
                sb.Append($"🧾 <strong>Pedidos:</strong> {m.PedidosPendientes} pendientes · {m.PedidosEnRuta} en ruta · {m.PedidosRetenidos} retenidos<br/>");
            if (permitidas.Contains(Inv))
                sb.Append($"📦 <strong>Inventario:</strong> {m.StockBajo} en stock bajo · {m.ProductosAgotados} agotados · {m.DevolucionesCuarentena} en cuarentena<br/>");
            if (permitidas.Contains(Log))
                sb.Append($"🚚 <strong>Logística:</strong> {m.RutasDespachadas} rutas despachadas · {m.EntregasPendientes} entregas pendientes · {m.AlertasFlota} alertas de flota<br/>");
            if (permitidas.Contains(Cli))
                sb.Append($"👥 <strong>Clientes:</strong> {m.ClientesActivos} activos · {m.ConsultasPendientes} consultas pendientes<br/>");
            if (permitidas.Contains(Rh))
                sb.Append($"🧑‍💼 <strong>Personal:</strong> {m.TotalEmpleados} empleados · {m.SolicitudesPendientes} solicitudes por aprobar<br/>");

            if (sb.Length == 0) sb.Append("No hay indicadores disponibles para tu rol, pero puedo ayudarte con el uso de los módulos.");

            return new AssistantAnswerViewModel
            {
                Tipo = "metrica", Intent = "resumen", Interpretado = true,
                Titulo = "Resumen del negocio", Respuesta = sb.ToString(),
                Sugerencias = { "¿Cuánto vendimos hoy?", "¿Cómo está el inventario?", "¿Qué puedo preguntar?" }
            };
        }

        // ── Capacidades por rol ─────────────────────────────────
        private static AssistantAnswerViewModel Capacidades(HashSet<string> permitidas)
        {
            var sb = new StringBuilder("Puedes preguntarme, por ejemplo:<ul style='margin:.3rem 0 0 1rem;padding:0'>");
            if (permitidas.Contains(Fin)) sb.Append("<li>💰 Finanzas: ventas de hoy/mes/año, facturación, ticket promedio, cuentas por cobrar, créditos, valor del inventario.</li>");
            if (permitidas.Contains(Ops)) sb.Append("<li>🧾 Pedidos: pedidos pendientes, retenidos, en ruta, de hoy.</li>");
            if (permitidas.Contains(Inv)) sb.Append("<li>📦 Inventario: stock bajo, agotados, total de productos, cuarentena.</li>");
            if (permitidas.Contains(Log)) sb.Append("<li>🚚 Logística: rutas, entregas, vehículos, mantenimiento, alertas de flota, activos.</li>");
            if (permitidas.Contains(Cli)) sb.Append("<li>👥 Clientes: total de clientes, consultas pendientes.</li>");
            if (permitidas.Contains(Rh)) sb.Append("<li>🧑‍💼 Personal: empleados, solicitudes de licencia, tareas.</li>");
            sb.Append("<li>❓ Ayuda: “¿cómo uso el módulo de rutas?”, “¿cómo facturo un pedido?”.</li>");
            sb.Append("</ul>");

            var sug = new List<string> { "Dame un resumen" };
            if (permitidas.Contains(Fin)) sug.Add("¿Cuánto vendimos este mes?");
            if (permitidas.Contains(Inv)) sug.Add("¿Cuántos productos agotados hay?");
            if (permitidas.Contains(Log)) sug.Add("¿Cuántas alertas de flota hay?");
            sug.Add("¿Cómo uso el inventario?");

            return new AssistantAnswerViewModel
            {
                Tipo = "ayuda", Intent = "capacidades", Interpretado = true,
                Titulo = "Esto es lo que puedo responderte", Respuesta = sb.ToString(), Sugerencias = sug
            };
        }

        private static AssistantAnswerViewModel ResponderAyuda(string modulo)
        {
            var info = Ayuda[modulo];
            return new AssistantAnswerViewModel
            {
                Tipo = "ayuda", Intent = $"ayuda:{modulo}", Interpretado = true,
                Titulo = info.Titulo, Respuesta = info.Texto,
                Sugerencias = { "¿Cómo creo una ruta?", "¿Cómo facturo un pedido?", "¿Qué puedo preguntar?" }
            };
        }

        private static AssistantAnswerViewModel NoAutorizado(string categoria, HashSet<string> permitidas)
        {
            var r = new AssistantAnswerViewModel
            {
                Tipo = "ayuda", Intent = "no_autorizado", Interpretado = true,
                Titulo = "Información restringida",
                Respuesta = $"La información de <strong>{categoria}</strong> no está disponible para tu rol. Puedo ayudarte con lo que sí tienes permitido."
            };
            if (permitidas.Contains(Inv)) r.Sugerencias.Add("¿Cómo está el inventario?");
            if (permitidas.Contains(Ops)) r.Sugerencias.Add("¿Cuántos pedidos pendientes hay?");
            if (permitidas.Contains(Log)) r.Sugerencias.Add("¿Cuántas entregas pendientes hay?");
            r.Sugerencias.Add("¿Qué puedo preguntar?");
            return r;
        }

        private static AssistantAnswerViewModel NoInterpretado(HashSet<string> permitidas)
        {
            var r = new AssistantAnswerViewModel
            {
                Tipo = "no_interpretado", Intent = "desconocido", Interpretado = false,
                Titulo = "No entendí la solicitud",
                Respuesta = "No pude interpretar tu pregunta. Prueba con “dame un resumen” o “¿qué puedo preguntar?”. Si es un problema técnico, contacta a soporte."
            };
            r.Sugerencias.Add("¿Qué puedo preguntar?");
            r.Sugerencias.Add("Dame un resumen");
            if (permitidas.Contains(Inv)) r.Sugerencias.Add("¿Cómo está el inventario?");
            return r;
        }

        // ── Detección ───────────────────────────────────────────
        private static (string Key, string Cat)? DetectarIntent(string norm)
        {
            foreach (var it in Intents)
                if (Contiene(norm, it.Kw))
                    return (it.Key, it.Cat);
            return null;
        }

        private static string? DetectarAyuda(string norm)
        {
            var pideAyuda = Contiene(norm, "como uso", "como se usa", "como funciona", "como hago", "como creo", "como registro", "como genero", "como puedo usar", "ayuda con", "no se usar", "instrucciones");
            if (!pideAyuda) return null;
            foreach (var clave in Ayuda.Keys)
                if (norm.Contains(clave)) return clave;
            if (norm.Contains("factura")) return "facturacion";
            if (norm.Contains("vehiculo")) return "vehiculos";
            if (norm.Contains("cobr")) return "cobros";
            return null;
        }

        private static bool Contiene(string norm, params string[] terminos) => terminos.Any(t => norm.Contains(t));

        // ── Carga de la foto de métricas ────────────────────────
        private async Task<Metrics> LoadMetricsAsync()
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Asistente_Metricas", connection) { CommandType = CommandType.StoredProcedure };
            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();
            var m = new Metrics();
            if (await reader.ReadAsync())
            {
                m.VentasHoy = GD(reader, "VentasHoy"); m.VentasMes = GD(reader, "VentasMes"); m.VentasAnio = GD(reader, "VentasAnio");
                m.FacturasMes = GI(reader, "FacturasMes"); m.TicketPromedioMes = GD(reader, "TicketPromedioMes");
                m.CobrosPendientes = GD(reader, "CobrosPendientes"); m.ClientesConCredito = GI(reader, "ClientesConCredito");
                m.CreditosBloqueados = GI(reader, "CreditosBloqueados"); m.ValorInventario = GD(reader, "ValorInventario");
                m.TotalProductos = GI(reader, "TotalProductos"); m.StockBajo = GI(reader, "StockBajo"); m.ProductosAgotados = GI(reader, "ProductosAgotados");
                m.DevolucionesCuarentena = GI(reader, "DevolucionesCuarentena");
                m.PedidosHoy = GI(reader, "PedidosHoy"); m.PedidosPendientes = GI(reader, "PedidosPendientes");
                m.PedidosRetenidos = GI(reader, "PedidosRetenidos"); m.PedidosEnRuta = GI(reader, "PedidosEnRuta");
                m.PedidosEntregadosHoy = GI(reader, "PedidosEntregadosHoy");
                m.TotalClientes = GI(reader, "TotalClientes"); m.ClientesActivos = GI(reader, "ClientesActivos"); m.ConsultasPendientes = GI(reader, "ConsultasPendientes");
                m.TotalEmpleados = GI(reader, "TotalEmpleados"); m.SolicitudesPendientes = GI(reader, "SolicitudesPendientes"); m.TareasPendientes = GI(reader, "TareasPendientes");
                m.RutasPlanificadas = GI(reader, "RutasPlanificadas"); m.RutasDespachadas = GI(reader, "RutasDespachadas");
                m.EntregasPendientes = GI(reader, "EntregasPendientes"); m.EntregasFallidas = GI(reader, "EntregasFallidas");
                m.TotalVehiculos = GI(reader, "TotalVehiculos"); m.VehiculosActivos = GI(reader, "VehiculosActivos");
                m.MantenimientosProgramados = GI(reader, "MantenimientosProgramados"); m.AlertasFlota = GI(reader, "AlertasFlota");
                m.TotalActivos = GI(reader, "TotalActivos"); m.ActivosPrestados = GI(reader, "ActivosPrestados");
            }
            return m;
        }

        private static int GI(SqlDataReader r, string c) { var i = r.GetOrdinal(c); return r.IsDBNull(i) ? 0 : Convert.ToInt32(r.GetValue(i)); }
        private static decimal GD(SqlDataReader r, string c) { var i = r.GetOrdinal(c); return r.IsDBNull(i) ? 0m : Convert.ToDecimal(r.GetValue(i)); }

        private static string Money(decimal v) => "₡" + v.ToString("N2");

        private async Task LogAsync(int usuarioId, string usuarioNombre, string pregunta, string intent, string tipo, bool interpretado)
        {
            try
            {
                await using var connection = new SqlConnection(_connectionString);
                await using var command = new SqlCommand("dbo.sp_Asistente_Log", connection) { CommandType = CommandType.StoredProcedure };
                command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = usuarioId > 0 ? usuarioId : DBNull.Value;
                command.Parameters.Add("@UsuarioNombre", SqlDbType.NVarChar, 150).Value = string.IsNullOrWhiteSpace(usuarioNombre) ? DBNull.Value : usuarioNombre;
                command.Parameters.Add("@Pregunta", SqlDbType.NVarChar, 500).Value = pregunta.Length > 500 ? pregunta[..500] : pregunta;
                command.Parameters.Add("@IntentDetectado", SqlDbType.NVarChar, 60).Value = string.IsNullOrWhiteSpace(intent) ? DBNull.Value : intent;
                command.Parameters.Add("@Modulo", SqlDbType.NVarChar, 60).Value = tipo == "ayuda" ? intent.Replace("ayuda:", "") : DBNull.Value;
                command.Parameters.Add("@Interpretado", SqlDbType.Bit).Value = interpretado;
                await connection.OpenAsync();
                await command.ExecuteNonQueryAsync();
            }
            catch (Exception exception)
            {
                _logger.LogWarning(
                    exception,
                    "No fue posible registrar la consulta del asistente para el usuario {UserId}.",
                    usuarioId);
            }
        }

        private static string Normalizar(string texto)
        {
            if (string.IsNullOrWhiteSpace(texto)) return string.Empty;
            var sb = new StringBuilder(texto.Trim().ToLowerInvariant());
            sb.Replace("á", "a").Replace("é", "e").Replace("í", "i").Replace("ó", "o").Replace("ú", "u").Replace("ñ", "n");
            return sb.ToString();
        }

        // Foto de métricas del negocio.
        private sealed class Metrics
        {
            public decimal VentasHoy, VentasMes, VentasAnio, TicketPromedioMes, CobrosPendientes, ValorInventario;
            public int FacturasMes, ClientesConCredito, CreditosBloqueados;
            public int TotalProductos, StockBajo, ProductosAgotados, DevolucionesCuarentena;
            public int PedidosHoy, PedidosPendientes, PedidosRetenidos, PedidosEnRuta, PedidosEntregadosHoy;
            public int TotalClientes, ClientesActivos, ConsultasPendientes;
            public int TotalEmpleados, SolicitudesPendientes, TareasPendientes;
            public int RutasPlanificadas, RutasDespachadas, EntregasPendientes, EntregasFallidas;
            public int TotalVehiculos, VehiculosActivos, MantenimientosProgramados, AlertasFlota, TotalActivos, ActivosPrestados;
        }
    }
}
