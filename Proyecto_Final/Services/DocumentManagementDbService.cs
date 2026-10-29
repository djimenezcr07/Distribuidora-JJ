using Microsoft.Data.SqlClient;
using Proyecto_Final.Models.Admin;
using System.Data;

namespace Proyecto_Final.Services;

public interface IDocumentManagementDbService
{
    Task<(IReadOnlyList<SelectOptionViewModel> Types, IReadOnlyList<SelectOptionViewModel> Departments)> GetOptionsAsync();
    Task<PagedResult<DocumentListItemViewModel>> ListAsync(DocumentFilterViewModel filter, DateTime businessDate, int warningDays);
    Task<(int Current, int Warning, int Expired, int NoExpiration)> GetSummaryAsync(DateTime businessDate, int warningDays);
    Task<DocumentDetailsViewModel?> GetDetailsAsync(int documentId, DateTime businessDate, int warningDays);
    Task<DocumentFormViewModel?> GetFormAsync(int documentId);
    Task<int> CreatePendingAsync(DocumentFormViewModel model, StagedPrivateFile file, int userId, string userName);
    Task MarkDocumentReadyAsync(int documentId, int userId, string userName);
    Task DeletePendingDocumentAsync(int documentId, int userId);
    Task UpdateMetadataAsync(DocumentFormViewModel model, int userId, string userName);
    Task<int> ReplaceFilePendingAsync(int documentId, StagedPrivateFile file, int userId, string userName);
    Task MarkVersionReadyAsync(int documentId, int versionId, int userId, string userName);
    Task DeletePendingVersionAsync(int documentId, int versionId, int userId);
    Task SetActiveAsync(int documentId, bool active, int userId, string userName);
    Task<PrivateFileMetadata?> GetAuthorizedFileAsync(int documentId, int? versionId, int userId, bool canManage);
    Task<IReadOnlyList<DocumentAlertNotificationCandidate>> GenerateAlertsAsync(DateTime businessDate, IReadOnlyCollection<int> thresholds, int userId);
    Task<PagedResult<DocumentAlertViewModel>> ListAlertsAsync(DocumentAlertFilterViewModel filter, DateTime businessDate);
    Task<(int Active, int Expired)> GetAlertSummaryAsync(DateTime businessDate);
    Task MarkAlertHandledAsync(int alertId, int userId);
    Task RegisterNotificationAsync(DocumentAlertNotificationCandidate candidate, string state, string? technicalError);
}

public sealed class DocumentManagementDbService : IDocumentManagementDbService
{
    private readonly string _connectionString;
    private readonly IHttpContextAccessor? _contextAccessor;

    public DocumentManagementDbService(IConfiguration configuration, IHttpContextAccessor? contextAccessor = null)
    {
        _contextAccessor = contextAccessor;
        _connectionString = configuration.GetConnectionString("DefaultConnection")
            ?? throw new InvalidOperationException("No se encontró la cadena de conexión DefaultConnection.");
    }

    public async Task<(IReadOnlyList<SelectOptionViewModel> Types, IReadOnlyList<SelectOptionViewModel> Departments)> GetOptionsAsync()
    {
        var types = new List<SelectOptionViewModel>();
        var departments = new List<SelectOptionViewModel>();
        await using var connection = new SqlConnection(_connectionString);
        await using var command = Procedure(connection, "dbo.sp_Document_GetOptions");
        return await ExecuteOwnedAsync<(IReadOnlyList<SelectOptionViewModel> Types, IReadOnlyList<SelectOptionViewModel> Departments)>(connection, command, async () =>
        {
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync()) types.Add(new() { Id = reader.GetInt32(0), Name = reader.GetString(1) });
        await reader.NextResultAsync();
        while (await reader.ReadAsync()) departments.Add(new() { Id = reader.GetInt32(0), Name = reader.GetString(1) });
        return (types, departments);
        });
    }

    public async Task<PagedResult<DocumentListItemViewModel>> ListAsync(DocumentFilterViewModel filter, DateTime businessDate, int warningDays)
    {
        var items = new List<DocumentListItemViewModel>();
        var page = Math.Max(filter.Page, 1);
        var pageSize = Math.Clamp(filter.PageSize, 1, 100);
        var total = 0;
        await using var connection = new SqlConnection(_connectionString);
        await using var command = Procedure(connection, "dbo.sp_Document_List");
        command.Parameters.Add("@Busqueda", SqlDbType.NVarChar, 180).Value = Db(filter.Search);
        command.Parameters.Add("@TipoDocumentoId", SqlDbType.Int).Value = Db(filter.TypeId);
        command.Parameters.Add("@DepartamentoId", SqlDbType.Int).Value = Db(filter.DepartmentId);
        command.Parameters.Add("@Estado", SqlDbType.NVarChar, 30).Value = Db(filter.Status);
        command.Parameters.Add("@Vencimiento", SqlDbType.NVarChar, 30).Value = Db(filter.Expiration);
        command.Parameters.Add("@FechaNegocio", SqlDbType.Date).Value = businessDate.Date;
        command.Parameters.Add("@DiasAviso", SqlDbType.Int).Value = warningDays;
        command.Parameters.Add("@Pagina", SqlDbType.Int).Value = page;
        command.Parameters.Add("@TamanoPagina", SqlDbType.Int).Value = pageSize;
        return await ExecuteOwnedAsync<PagedResult<DocumentListItemViewModel>>(connection, command, async () =>
        {
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            var item = ReadDocument(reader);
            total = reader.GetInt32(reader.GetOrdinal("TotalResultados"));
            items.Add(item);
        }
        return new() { Items = items, Page = page, PageSize = pageSize, Total = total };
        });
    }

    public async Task<(int Current, int Warning, int Expired, int NoExpiration)> GetSummaryAsync(DateTime businessDate, int warningDays)
    {
        await using var connection = new SqlConnection(_connectionString);
        await using var command = Procedure(connection, "dbo.sp_Document_Summary");
        command.Parameters.Add("@FechaNegocio", SqlDbType.Date).Value = businessDate.Date;
        command.Parameters.Add("@DiasAviso", SqlDbType.Int).Value = warningDays;
        return await ExecuteOwnedAsync<(int Current, int Warning, int Expired, int NoExpiration)>(connection, command, async () =>
        {
        await using var reader = await command.ExecuteReaderAsync(CommandBehavior.SingleRow);
        return await reader.ReadAsync()
            ? (reader.GetInt32(0), reader.GetInt32(1), reader.GetInt32(2), reader.GetInt32(3))
            : (0, 0, 0, 0);
        });
    }

    public async Task<DocumentDetailsViewModel?> GetDetailsAsync(int documentId, DateTime businessDate, int warningDays)
    {
        await using var connection = new SqlConnection(_connectionString);
        await using var command = Procedure(connection, "dbo.sp_Document_GetById");
        command.Parameters.Add("@DocumentoId", SqlDbType.Int).Value = documentId;
        command.Parameters.Add("@FechaNegocio", SqlDbType.Date).Value = businessDate.Date;
        command.Parameters.Add("@DiasAviso", SqlDbType.Int).Value = warningDays;
        return await ExecuteOwnedAsync<DocumentDetailsViewModel?>(connection, command, async () =>
        {
        await using var reader = await command.ExecuteReaderAsync();
        if (!await reader.ReadAsync()) return null;
        var model = new DocumentDetailsViewModel
        {
            Document = ReadDocument(reader),
            Description = NullableString(reader, "Descripcion"),
            OriginalName = reader.GetString(reader.GetOrdinal("NombreOriginal")),
            MimeType = reader.GetString(reader.GetOrdinal("MimeType")),
            SizeBytes = reader.GetInt64(reader.GetOrdinal("TamanoBytes")),
            Sha256 = reader.GetString(reader.GetOrdinal("HashSha256")),
            CreatedByName = reader.GetString(reader.GetOrdinal("CreadoPorNombre")),
            CreatedUtc = reader.GetDateTime(reader.GetOrdinal("FechaCreacionUtc"))
        };
        var versions = new List<DocumentVersionViewModel>();
        await reader.NextResultAsync();
        while (await reader.ReadAsync())
        {
            versions.Add(new()
            {
                VersionId = reader.GetInt32(0), Version = reader.GetInt32(1), OriginalName = reader.GetString(2),
                MimeType = reader.GetString(3), SizeBytes = reader.GetInt64(4), Sha256 = reader.GetString(5),
                StorageStatus = reader.GetString(6), CreatedByUserId = reader.GetInt32(7),
                CreatedByName = reader.GetString(8), CreatedUtc = reader.GetDateTime(9)
            });
        }
        model.Versions = versions;
        return model;
        });
    }

    public async Task<DocumentFormViewModel?> GetFormAsync(int documentId)
    {
        await using var connection = new SqlConnection(_connectionString);
        await using var command = Procedure(connection, "dbo.sp_Document_GetForEdit");
        command.Parameters.Add("@DocumentoId", SqlDbType.Int).Value = documentId;
        return await ExecuteOwnedAsync<DocumentFormViewModel?>(connection, command, async () =>
        {
        await using var reader = await command.ExecuteReaderAsync(CommandBehavior.SingleRow);
        if (!await reader.ReadAsync()) return null;
        return new()
        {
            DocumentId = reader.GetInt32(0), TypeId = reader.GetInt32(1), DepartmentId = NullableInt(reader, 2),
            Title = reader.GetString(3), Description = NullableString(reader, 4), ReferenceNumber = NullableString(reader, 5),
            IssueDate = NullableDate(reader, 6), ExpirationDate = NullableDate(reader, 7), DoesNotExpire = reader.GetBoolean(8),
            Status = reader.GetString(9)
        };
        });
    }

    public async Task<int> CreatePendingAsync(DocumentFormViewModel model, StagedPrivateFile file, int userId, string userName)
    {
        await using var connection = new SqlConnection(_connectionString);
        await using var command = Procedure(connection, "dbo.sp_Document_Create");
        AddDocumentParameters(command, model);
        AddFileParameters(command, file);
        AddActor(command, userId, userName);
        return await ExecuteOwnedAsync<int>(connection, command, async () =>
        {
        return Convert.ToInt32(await command.ExecuteScalarAsync());
        });
    }

    public Task MarkDocumentReadyAsync(int documentId, int userId, string userName) =>
        ExecuteActorAsync("dbo.sp_Document_MarkReady", documentId, "@DocumentoId", userId, userName);

    public Task DeletePendingDocumentAsync(int documentId, int userId) =>
        ExecuteAsync("dbo.sp_Document_DeletePending", ("@DocumentoId", SqlDbType.Int, documentId), ("@UsuarioId", SqlDbType.Int, userId));

    public async Task UpdateMetadataAsync(DocumentFormViewModel model, int userId, string userName)
    {
        await using var connection = new SqlConnection(_connectionString);
        await using var command = Procedure(connection, "dbo.sp_Document_Update");
        command.Parameters.Add("@DocumentoId", SqlDbType.Int).Value = model.DocumentId;
        AddDocumentParameters(command, model);
        AddActor(command, userId, userName);
        await ExecuteOwnedAsync(connection, command, async () =>
        {
        await command.ExecuteNonQueryAsync();
        });
    }

    public async Task<int> ReplaceFilePendingAsync(int documentId, StagedPrivateFile file, int userId, string userName)
    {
        await using var connection = new SqlConnection(_connectionString);
        await using var command = Procedure(connection, "dbo.sp_Document_ReplaceFile");
        command.Parameters.Add("@DocumentoId", SqlDbType.Int).Value = documentId;
        AddFileParameters(command, file);
        AddActor(command, userId, userName);
        return await ExecuteOwnedAsync<int>(connection, command, async () =>
        {
        return Convert.ToInt32(await command.ExecuteScalarAsync());
        });
    }

    public async Task MarkVersionReadyAsync(int documentId, int versionId, int userId, string userName)
    {
        await using var connection = new SqlConnection(_connectionString);
        await using var command = Procedure(connection, "dbo.sp_Document_MarkVersionReady");
        command.Parameters.Add("@DocumentoId", SqlDbType.Int).Value = documentId;
        command.Parameters.Add("@DocumentoVersionId", SqlDbType.Int).Value = versionId;
        AddActor(command, userId, userName);
        await ExecuteOwnedAsync(connection, command, async () =>
        {
        await command.ExecuteNonQueryAsync();
        });
    }

    public Task DeletePendingVersionAsync(int documentId, int versionId, int userId) =>
        ExecuteAsync("dbo.sp_Document_DeletePendingVersion", ("@DocumentoId", SqlDbType.Int, documentId),
            ("@DocumentoVersionId", SqlDbType.Int, versionId), ("@UsuarioId", SqlDbType.Int, userId));

    public async Task SetActiveAsync(int documentId, bool active, int userId, string userName)
    {
        await using var connection = new SqlConnection(_connectionString);
        await using var command = Procedure(connection, "dbo.sp_Document_SetStatus");
        command.Parameters.Add("@DocumentoId", SqlDbType.Int).Value = documentId;
        command.Parameters.Add("@Activo", SqlDbType.Bit).Value = active;
        AddActor(command, userId, userName);
        await ExecuteOwnedAsync(connection, command, async () =>
        {
        await command.ExecuteNonQueryAsync();
        });
    }

    public async Task<PrivateFileMetadata?> GetAuthorizedFileAsync(int documentId, int? versionId, int userId, bool canManage)
    {
        await using var connection = new SqlConnection(_connectionString);
        await using var command = Procedure(connection, "dbo.sp_Stage2_AuthorizeDocumentDownload");
        command.Parameters.Add("@DocumentoId", SqlDbType.Int).Value = documentId;
        command.Parameters.Add("@DocumentoVersionId", SqlDbType.Int).Value = Db(versionId);
        command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = userId;
        command.Parameters.Add("@PuedeAdministrar", SqlDbType.Bit).Value = canManage;
        return await ExecuteOwnedAsync<PrivateFileMetadata?>(connection, command, async () =>
        {
        await using var reader = await command.ExecuteReaderAsync(CommandBehavior.SingleRow);
        return await reader.ReadAsync() ? new()
        {
            OwnerId = documentId, VersionId = NullableInt(reader, 0), StorageArea = "Documents",
            StorageKey = reader.GetString(1), OriginalName = reader.GetString(2), MimeType = reader.GetString(3)
        } : null;
        });
    }

    public async Task<IReadOnlyList<DocumentAlertNotificationCandidate>> GenerateAlertsAsync(DateTime businessDate, IReadOnlyCollection<int> thresholds, int userId)
    {
        var list = new List<DocumentAlertNotificationCandidate>();
        await using var connection = new SqlConnection(_connectionString);
        await using var command = Procedure(connection, "dbo.sp_DocumentAlert_Generate");
        command.Parameters.Add("@FechaNegocio", SqlDbType.Date).Value = businessDate.Date;
        command.Parameters.Add("@Umbrales", SqlDbType.NVarChar, 100).Value = string.Join(',', thresholds.Where(x => x >= 0).Distinct().OrderBy(x => x));
        command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = userId;
        return await ExecuteOwnedAsync<IReadOnlyList<DocumentAlertNotificationCandidate>>(connection, command, async () =>
        {
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync()) list.Add(new()
        {
            AlertId = reader.GetInt32(0), DocumentId = reader.GetInt32(1), ThresholdDays = reader.GetInt32(2),
            DocumentTitle = reader.GetString(3), ExpirationDate = reader.GetDateTime(4), Recipient = reader.GetString(5)
        });
        return list;
        });
    }

    public async Task<PagedResult<DocumentAlertViewModel>> ListAlertsAsync(DocumentAlertFilterViewModel filter, DateTime businessDate)
    {
        var items = new List<DocumentAlertViewModel>();
        var page = Math.Max(filter.Page, 1);
        var size = Math.Clamp(filter.PageSize, 1, 100);
        var total = 0;
        await using var connection = new SqlConnection(_connectionString);
        await using var command = Procedure(connection, "dbo.sp_DocumentAlert_List");
        command.Parameters.Add("@Estado", SqlDbType.NVarChar, 30).Value = Db(filter.Status);
        command.Parameters.Add("@DepartamentoId", SqlDbType.Int).Value = Db(filter.DepartmentId);
        command.Parameters.Add("@MaxDias", SqlDbType.Int).Value = Db(filter.MaxDays);
        command.Parameters.Add("@FechaNegocio", SqlDbType.Date).Value = businessDate.Date;
        command.Parameters.Add("@Pagina", SqlDbType.Int).Value = page;
        command.Parameters.Add("@TamanoPagina", SqlDbType.Int).Value = size;
        return await ExecuteOwnedAsync<PagedResult<DocumentAlertViewModel>>(connection, command, async () =>
        {
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            total = reader.GetInt32(reader.GetOrdinal("TotalResultados"));
            items.Add(new()
            {
                AlertId = reader.GetInt32(0), DocumentId = reader.GetInt32(1), DocumentTitle = reader.GetString(2),
                TypeName = reader.GetString(3), DepartmentName = NullableString(reader, 4), ResponsibleName = reader.GetString(5),
                ExpirationDate = reader.GetDateTime(6), DaysRemaining = reader.GetInt32(7), ExpirationStatus = reader.GetString(8),
                Status = reader.GetString(9), CreatedUtc = reader.GetDateTime(10)
            });
        }
        return new() { Items = items, Page = page, PageSize = size, Total = total };
        });
    }

    public async Task<(int Active, int Expired)> GetAlertSummaryAsync(DateTime businessDate)
    {
        await using var connection = new SqlConnection(_connectionString);
        await using var command = Procedure(connection, "dbo.sp_DocumentAlert_Summary");
        command.Parameters.Add("@FechaNegocio", SqlDbType.Date).Value = businessDate.Date;
        return await ExecuteOwnedAsync<(int Active, int Expired)>(connection, command, async () =>
        {
        await using var reader = await command.ExecuteReaderAsync(CommandBehavior.SingleRow);
        return await reader.ReadAsync() ? (reader.GetInt32(0), reader.GetInt32(1)) : (0, 0);
        });
    }

    public Task MarkAlertHandledAsync(int alertId, int userId) =>
        ExecuteAsync("dbo.sp_DocumentAlert_MarkHandled", ("@AlertaId", SqlDbType.Int, alertId), ("@UsuarioId", SqlDbType.Int, userId));

    public Task RegisterNotificationAsync(DocumentAlertNotificationCandidate candidate, string state, string? technicalError) =>
        ExecuteAsync("dbo.sp_DocumentAlert_RegisterNotification",
            ("@AlertaId", SqlDbType.Int, candidate.AlertId), ("@Canal", SqlDbType.NVarChar, "Email"),
            ("@Destinatario", SqlDbType.NVarChar, candidate.Recipient), ("@EstadoEnvio", SqlDbType.NVarChar, state),
            ("@ErrorTecnicoResumido", SqlDbType.NVarChar, technicalError ?? (object)DBNull.Value));

    private async Task ExecuteActorAsync(string procedure, int id, string idName, int userId, string userName)
    {
        await using var connection = new SqlConnection(_connectionString);
        await using var command = Procedure(connection, procedure);
        command.Parameters.Add(idName, SqlDbType.Int).Value = id;
        AddActor(command, userId, userName);
        await ExecuteOwnedAsync(connection, command, async () =>
        {
        await command.ExecuteNonQueryAsync();
        });
    }

    private async Task ExecuteAsync(string procedure, params (string Name, SqlDbType Type, object Value)[] values)
    {
        await using var connection = new SqlConnection(_connectionString);
        await using var command = Procedure(connection, procedure);
        foreach (var value in values) command.Parameters.Add(value.Name, value.Type).Value = value.Value;
        await ExecuteOwnedAsync(connection, command, async () =>
        {
        await command.ExecuteNonQueryAsync();
        });
    }

    private static void AddDocumentParameters(SqlCommand command, DocumentFormViewModel model)
    {
        command.Parameters.Add("@TipoDocumentoId", SqlDbType.Int).Value = model.TypeId;
        command.Parameters.Add("@DepartamentoId", SqlDbType.Int).Value = Db(model.DepartmentId);
        command.Parameters.Add("@Titulo", SqlDbType.NVarChar, 180).Value = model.Title.Trim();
        command.Parameters.Add("@Descripcion", SqlDbType.NVarChar, 1000).Value = Db(model.Description);
        command.Parameters.Add("@NumeroReferencia", SqlDbType.NVarChar, 100).Value = Db(model.ReferenceNumber);
        command.Parameters.Add("@FechaEmision", SqlDbType.Date).Value = Db(model.IssueDate?.Date);
        command.Parameters.Add("@FechaVencimiento", SqlDbType.Date).Value = model.DoesNotExpire ? DBNull.Value : Db(model.ExpirationDate?.Date);
        command.Parameters.Add("@NoVence", SqlDbType.Bit).Value = model.DoesNotExpire;
        command.Parameters.Add("@Estado", SqlDbType.NVarChar, 30).Value = model.Status.Trim();
    }

    private static void AddFileParameters(SqlCommand command, StagedPrivateFile file)
    {
        command.Parameters.Add("@NombreOriginal", SqlDbType.NVarChar, 255).Value = file.OriginalName;
        command.Parameters.Add("@StorageKey", SqlDbType.NVarChar, 80).Value = file.StorageKey;
        command.Parameters.Add("@MimeType", SqlDbType.NVarChar, 100).Value = file.ContentType;
        command.Parameters.Add("@Extension", SqlDbType.NVarChar, 10).Value = file.Extension;
        command.Parameters.Add("@TamanoBytes", SqlDbType.BigInt).Value = file.Length;
        command.Parameters.Add("@HashSha256", SqlDbType.Char, 64).Value = file.Sha256;
    }

    private static void AddActor(SqlCommand command, int userId, string userName)
    {
        command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = userId;
        command.Parameters.Add("@UsuarioNombre", SqlDbType.NVarChar, 150).Value = userName;
    }

    private static DocumentListItemViewModel ReadDocument(SqlDataReader reader) => new()
    {
        DocumentId = reader.GetInt32(reader.GetOrdinal("DocumentoId")), TypeName = reader.GetString(reader.GetOrdinal("TipoDocumento")),
        DepartmentName = NullableString(reader, "Departamento"), Title = reader.GetString(reader.GetOrdinal("Titulo")),
        ReferenceNumber = NullableString(reader, "NumeroReferencia"), IssueDate = NullableDate(reader, "FechaEmision"),
        ExpirationDate = NullableDate(reader, "FechaVencimiento"), DoesNotExpire = reader.GetBoolean(reader.GetOrdinal("NoVence")),
        Status = reader.GetString(reader.GetOrdinal("Estado")), Active = reader.GetBoolean(reader.GetOrdinal("Activo")),
        Version = reader.GetInt32(reader.GetOrdinal("Version")), UpdatedUtc = reader.GetDateTime(reader.GetOrdinal("FechaActualizacionUtc")),
        ExpirationStatus = reader.GetString(reader.GetOrdinal("EstadoVencimiento")), DaysToExpiration = NullableInt(reader, reader.GetOrdinal("DiasRestantes"))
    };

    private SqlCommand Procedure(SqlConnection connection, string name)
    {
        var login = CurrentLogin();
        var command = new SqlCommand(name.Replace("dbo.sp_Document", "dbo.sp_Stage2_Document", StringComparison.Ordinal), connection) { CommandType = CommandType.StoredProcedure };
        command.Parameters.Add("@Actor", SqlDbType.Int).Value = login.UserId;
        return command;
    }

    private OriginalLoginContext CurrentLogin() => OriginalLoginSession.ValidatedRequest(
        _contextAccessor?.HttpContext ?? throw new UnauthorizedAccessException("Falta el contexto original de la solicitud."));

    private Task<T> ExecuteOwnedAsync<T>(SqlConnection connection, SqlCommand command, Func<Task<T>> operation)
    {
        var login = CurrentLogin();
        return OriginalLoginTransaction.ExecuteAsync(connection, command, login, login.UserId, null, operation);
    }

    private Task ExecuteOwnedAsync(SqlConnection connection, SqlCommand command, Func<Task> operation) =>
        ExecuteOwnedAsync(connection, command, async () => { await operation(); return 0; });
    private static object Db(string? value) => string.IsNullOrWhiteSpace(value) ? DBNull.Value : value.Trim();
    private static object Db(int? value) => value is > 0 ? value.Value : DBNull.Value;
    private static object Db(DateTime? value) => value.HasValue ? value.Value : DBNull.Value;
    private static string? NullableString(SqlDataReader reader, string name) => NullableString(reader, reader.GetOrdinal(name));
    private static string? NullableString(SqlDataReader reader, int ordinal) => reader.IsDBNull(ordinal) ? null : reader.GetString(ordinal);
    private static int? NullableInt(SqlDataReader reader, int ordinal) => reader.IsDBNull(ordinal) ? null : reader.GetInt32(ordinal);
    private static DateTime? NullableDate(SqlDataReader reader, string name) => NullableDate(reader, reader.GetOrdinal(name));
    private static DateTime? NullableDate(SqlDataReader reader, int ordinal) => reader.IsDBNull(ordinal) ? null : reader.GetDateTime(ordinal);
}
