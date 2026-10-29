using Microsoft.Data.SqlClient;
using Proyecto_Final.Models.Admin;
using System.Data;
using System.Net;
using System.Text;

namespace Proyecto_Final.Services;

public interface IPaySlipService
{
    Task<List<PaySlipListItemViewModel>> ListAsync(int userId, bool includeAll, CancellationToken cancellationToken);
    Task<PaySlipViewModel?> GetAsync(long calculationId, int userId, bool canManage, CancellationToken cancellationToken);
    Task<PaySlipDeliveryPreparation> PrepareDeliveryAsync(long calculationId, Guid idempotencyKey, int actorId, string actorName, CancellationToken cancellationToken);
    Task CompleteDeliveryAsync(long deliveryId, bool successful, string? errorCode, int actorId, string actorName, CancellationToken cancellationToken);
}

public interface IPaySlipEmailSender
{
    Task SendLinkAsync(string recipient, string employee, Uri secureLink, CancellationToken cancellationToken);
}

public interface IPaySlipDeliveryCoordinator
{
    Task SendAsync(long calculationId, Guid idempotencyKey, int actorId, string actorName, Uri secureLink, CancellationToken cancellationToken);
}

public sealed class PaySlipDeliveryCoordinator : IPaySlipDeliveryCoordinator
{
    private readonly IPaySlipService _service;
    private readonly IPaySlipEmailSender _sender;

    public PaySlipDeliveryCoordinator(IPaySlipService service, IPaySlipEmailSender sender)
    {
        _service = service;
        _sender = sender;
    }

    public async Task SendAsync(long calculationId, Guid idempotencyKey, int actorId, string actorName, Uri secureLink, CancellationToken cancellationToken)
    {
        if (secureLink.Scheme != Uri.UriSchemeHttps) throw new InvalidOperationException("La boleta solo puede notificarse mediante un enlace HTTPS.");
        var delivery = await _service.PrepareDeliveryAsync(calculationId, idempotencyKey, actorId, actorName, cancellationToken);
        if (!delivery.DebeEnviar) return;
        try
        {
            await _sender.SendLinkAsync(delivery.Destinatario, delivery.Empleado, secureLink, cancellationToken);
            await _service.CompleteDeliveryAsync(delivery.EnvioId, true, null, actorId, actorName, cancellationToken);
        }
        catch
        {
            await _service.CompleteDeliveryAsync(delivery.EnvioId, false, "SMTP_DELIVERY_FAILED", actorId, actorName, cancellationToken);
            throw;
        }
    }
}

public sealed class SmtpPaySlipEmailSender : IPaySlipEmailSender
{
    private readonly EmailService _emailService;
    public SmtpPaySlipEmailSender(EmailService emailService) => _emailService = emailService;

    public Task SendLinkAsync(string recipient, string employee, Uri secureLink, CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        var safeEmployee = WebUtility.HtmlEncode(employee);
        var safeLink = WebUtility.HtmlEncode(secureLink.AbsoluteUri);
        _emailService.SendEmail(recipient, "Boleta de pago disponible",
            $"<p>Hola {safeEmployee},</p><p>Tu boleta de pago está disponible en el portal privado.</p><p><a href=\"{safeLink}\">Consultar boleta</a></p><p>El acceso requiere iniciar sesión. Este correo no contiene importes ni datos sensibles.</p>");
        return Task.CompletedTask;
    }
}

public static class PaySlipHtmlBuilder
{
    public static string Build(PaySlipViewModel model)
    {
        ArgumentNullException.ThrowIfNull(model);
        var rows = new StringBuilder();
        foreach (var line in model.Lineas)
            rows.Append($"<tr><td>{WebUtility.HtmlEncode(line.Codigo)}</td><td>{WebUtility.HtmlEncode(line.Nombre)}</td><td>{WebUtility.HtmlEncode(line.Tipo)}</td><td>{line.Monto:N2}</td></tr>");
        return $"""
<!doctype html><html lang="es"><head><meta charset="utf-8"><title>Boleta de pago</title></head><body>
<h1>Boleta de pago</h1><p><strong>Empleado:</strong> {WebUtility.HtmlEncode(model.Empleado)}</p><p><strong>Periodo:</strong> {WebUtility.HtmlEncode(model.Periodo)}</p>
<table><thead><tr><th>Código</th><th>Concepto</th><th>Tipo</th><th>Monto</th></tr></thead><tbody>{rows}</tbody></table>
<p><strong>Salario base:</strong> {model.SalarioBase:N2}</p><p><strong>Total bruto:</strong> {model.TotalBruto:N2}</p><p><strong>Deducciones:</strong> {model.TotalDeducciones:N2}</p><p><strong>Total neto:</strong> {model.TotalNeto:N2}</p>
</body></html>
""";
    }
}

public sealed class PaySlipDbService : IPaySlipService
{
    private readonly string _connectionString;
    public PaySlipDbService(IConfiguration configuration) => _connectionString = configuration.GetConnectionString("DefaultConnection") ?? throw new InvalidOperationException("No se encontró DefaultConnection.");

    public async Task<List<PaySlipListItemViewModel>> ListAsync(int userId, bool includeAll, CancellationToken cancellationToken)
    {
        var items = new List<PaySlipListItemViewModel>();
        await using var connection = new SqlConnection(_connectionString); await using var command = Command(connection, "dbo.sp_PaySlip_Listar");
        command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = userId; command.Parameters.Add("@IncluirTodas", SqlDbType.Bit).Value = includeAll;
        await connection.OpenAsync(cancellationToken); await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken)) items.Add(new PaySlipListItemViewModel { CalculoId=reader.GetInt64(0),Periodo=reader.GetString(1),Empleado=reader.GetString(2),TotalBruto=reader.GetDecimal(3),TotalDeducciones=reader.GetDecimal(4),TotalNeto=reader.GetDecimal(5),Estado=reader.GetString(6),UltimoEnvio=reader.IsDBNull(7)?null:reader.GetString(7) });
        return items;
    }

    public async Task<PaySlipViewModel?> GetAsync(long calculationId, int userId, bool canManage, CancellationToken cancellationToken)
    {
        await using var connection = new SqlConnection(_connectionString); await using var command = Command(connection, "dbo.sp_PaySlip_Obtener");
        command.Parameters.Add("@CalculoId", SqlDbType.BigInt).Value=calculationId; command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value=userId; command.Parameters.Add("@PuedeGestionar", SqlDbType.Bit).Value=canManage;
        await connection.OpenAsync(cancellationToken); await using var reader=await command.ExecuteReaderAsync(cancellationToken); if(!await reader.ReadAsync(cancellationToken)) return null;
        var model=new PaySlipViewModel{CalculoId=reader.GetInt64(0),PropietarioUsuarioId=reader.GetInt32(1),Empleado=reader.GetString(2),Periodo=reader.GetString(3),SalarioBase=reader.GetDecimal(4),HorasOrdinarias=reader.GetDecimal(5),HorasExtra=reader.GetDecimal(6),Comisiones=reader.GetDecimal(7),TotalBruto=reader.GetDecimal(8),TotalDeducciones=reader.GetDecimal(9),TotalNeto=reader.GetDecimal(10),Estado=reader.GetString(11),FechaPagoUtc=reader.IsDBNull(12)?null:reader.GetDateTime(12)};
        await reader.NextResultAsync(cancellationToken); while(await reader.ReadAsync(cancellationToken)) model.Lineas.Add(new PaySlipLineViewModel{Codigo=reader.GetString(0),Nombre=reader.GetString(1),Tipo=reader.GetString(2),Monto=reader.GetDecimal(3)});
        return model;
    }

    public async Task<PaySlipDeliveryPreparation> PrepareDeliveryAsync(long calculationId, Guid idempotencyKey, int actorId, string actorName, CancellationToken cancellationToken)
    {
        await using var connection=new SqlConnection(_connectionString); await using var command=Command(connection,"dbo.sp_PaySlip_PrepararEnvio");
        command.Parameters.Add("@CalculoId",SqlDbType.BigInt).Value=calculationId;command.Parameters.Add("@IdempotencyKey",SqlDbType.UniqueIdentifier).Value=idempotencyKey;Actor(command,actorId,actorName);
        await connection.OpenAsync(cancellationToken);await using var reader=await command.ExecuteReaderAsync(cancellationToken);if(!await reader.ReadAsync(cancellationToken))throw new InvalidOperationException("No fue posible preparar el envío.");
        return new PaySlipDeliveryPreparation(reader.GetInt64(0),reader.GetString(1),reader.GetString(2),reader.GetBoolean(3));
    }

    public async Task CompleteDeliveryAsync(long deliveryId, bool successful, string? errorCode, int actorId, string actorName, CancellationToken cancellationToken)
    {
        await using var connection=new SqlConnection(_connectionString);await using var command=Command(connection,"dbo.sp_PaySlip_CompletarEnvio");command.Parameters.Add("@EnvioId",SqlDbType.BigInt).Value=deliveryId;command.Parameters.Add("@Exitoso",SqlDbType.Bit).Value=successful;command.Parameters.Add("@CodigoError",SqlDbType.NVarChar,100).Value=string.IsNullOrWhiteSpace(errorCode)?DBNull.Value:errorCode;Actor(command,actorId,actorName);await connection.OpenAsync(cancellationToken);await command.ExecuteNonQueryAsync(cancellationToken);
    }

    private static SqlCommand Command(SqlConnection connection,string name)=>new(name,connection){CommandType=CommandType.StoredProcedure};
    private static void Actor(SqlCommand command,int id,string name){command.Parameters.Add("@ActorUsuarioId",SqlDbType.Int).Value=id;command.Parameters.Add("@ActorNombre",SqlDbType.NVarChar,150).Value=name;}
}
