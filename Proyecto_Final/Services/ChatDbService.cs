using System.Data;
using Microsoft.Data.SqlClient;
using Proyecto_Final.Models.Chat;

namespace Proyecto_Final.Services
{
    public interface IChatDbService
    {
        Task<List<ChatUserViewModel>> GetUsersAsync(int currentUserId);
        Task<int?> GetOrCreateConversationAsync(int currentUserId, int otherUserId);
        Task<bool> IsConversationMemberAsync(int conversationId, int userId);
        Task<ChatMessageViewModel?> SendMessageAsync(int conversationId, int senderId, string content);
        Task<List<ChatMessageViewModel>> GetMessagesAsync(int conversationId, int userId, int page, int pageSize);
        Task<List<ChatDepartmentViewModel>> GetDepartmentsAsync(int userId, bool canManageAll);
        Task<bool> IsDepartmentMemberAsync(int departmentId, int userId, bool canManageAll);
        Task<bool> CanPostToDepartmentAsync(int departmentId, int userId, bool canManageAll);
        Task<ChatDepartmentMessageViewModel?> SendDepartmentMessageAsync(int departmentId, int senderId, string content, bool canManageAll);
        Task<List<ChatDepartmentMessageViewModel>> GetDepartmentMessagesAsync(int departmentId, int userId, bool canManageAll, int page, int pageSize);
        Task<List<ChatSearchResultViewModel>> SearchMessagesAsync(int userId, bool canManageAll, ChatSearchRequest request);
        Task<List<ChatDepartmentAdminViewModel>> GetDepartmentsForAdministrationAsync();
        Task<int> CreateDepartmentAsync(ChatDepartmentFormViewModel model, int actorUserId);
        Task UpdateDepartmentAsync(ChatDepartmentFormViewModel model, int actorUserId);
        Task AddDepartmentMemberAsync(int departmentId, int userId, bool canPost, int actorUserId);
        Task RemoveDepartmentMemberAsync(int departmentId, int userId, int actorUserId);
    }

    public sealed class ChatDbService : IChatDbService
    {
        private readonly string _connectionString;

        public ChatDbService(IConfiguration configuration)
        {
            _connectionString = configuration.GetConnectionString("DefaultConnection") ?? string.Empty;
            if (string.IsNullOrWhiteSpace(_connectionString))
            {
                throw new InvalidOperationException(
                    "La configuración ConnectionStrings:DefaultConnection es obligatoria para el servicio de chat.");
            }
        }

        public async Task<List<ChatUserViewModel>> GetUsersAsync(int currentUserId)
        {
            var result = new List<ChatUserViewModel>();
            await using var connection = new SqlConnection(_connectionString);
            await using var command = CreateProcedure(connection, "dbo.sp_Chat_GetUsers");
            command.Parameters.Add("@UsuarioIdActual", SqlDbType.Int).Value = currentUserId;
            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                result.Add(new ChatUserViewModel
                {
                    UsuarioId = reader.GetInt32(reader.GetOrdinal("UsuarioId")),
                    NombreCompleto = reader.GetString(reader.GetOrdinal("NombreCompleto")),
                    Correo = reader.GetString(reader.GetOrdinal("Correo"))
                });
            }

            return result;
        }

        public async Task<int?> GetOrCreateConversationAsync(int currentUserId, int otherUserId)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = CreateProcedure(connection, "dbo.sp_Chat_GetOrCreateConversation");
            command.Parameters.Add("@UsuarioActualId", SqlDbType.Int).Value = currentUserId;
            command.Parameters.Add("@OtroUsuarioId", SqlDbType.Int).Value = otherUserId;
            await connection.OpenAsync();
            var result = await command.ExecuteScalarAsync();
            return result is null or DBNull ? null : Convert.ToInt32(result);
        }

        public async Task<bool> IsConversationMemberAsync(int conversationId, int userId)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = CreateProcedure(connection, "dbo.sp_Chat_IsConversationMember");
            command.Parameters.Add("@ConversacionId", SqlDbType.Int).Value = conversationId;
            command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = userId;
            await connection.OpenAsync();
            return Convert.ToBoolean(await command.ExecuteScalarAsync());
        }

        public async Task<ChatMessageViewModel?> SendMessageAsync(int conversationId, int senderId, string content)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = CreateProcedure(connection, "dbo.sp_Chat_SendMessage");
            command.Parameters.Add("@ConversacionId", SqlDbType.Int).Value = conversationId;
            command.Parameters.Add("@RemitenteId", SqlDbType.Int).Value = senderId;
            command.Parameters.Add("@Contenido", SqlDbType.NVarChar, 1000).Value = content;
            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync(CommandBehavior.SingleRow);
            return await reader.ReadAsync() ? ReadPrivateMessage(reader) : null;
        }

        public async Task<List<ChatMessageViewModel>> GetMessagesAsync(
            int conversationId,
            int userId,
            int page,
            int pageSize)
        {
            var result = new List<ChatMessageViewModel>();
            await using var connection = new SqlConnection(_connectionString);
            await using var command = CreateProcedure(connection, "dbo.sp_Chat_GetMessages");
            command.Parameters.Add("@ConversacionId", SqlDbType.Int).Value = conversationId;
            command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = userId;
            command.Parameters.Add("@Pagina", SqlDbType.Int).Value = NormalizePage(page);
            command.Parameters.Add("@TamanoPagina", SqlDbType.Int).Value = NormalizePageSize(pageSize, 50);
            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                result.Add(ReadPrivateMessage(reader));
            }

            return result;
        }

        public async Task<List<ChatDepartmentViewModel>> GetDepartmentsAsync(int userId, bool canManageAll)
        {
            var result = new List<ChatDepartmentViewModel>();
            await using var connection = new SqlConnection(_connectionString);
            await using var command = CreateProcedure(connection, "dbo.sp_Chat_GetDepartments");
            command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = userId;
            command.Parameters.Add("@PuedeAdministrarTodo", SqlDbType.Bit).Value = canManageAll;
            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                result.Add(new ChatDepartmentViewModel
                {
                    DepartamentoId = reader.GetInt32(reader.GetOrdinal("DepartamentoId")),
                    Nombre = reader.GetString(reader.GetOrdinal("Nombre")),
                    Descripcion = GetNullableString(reader, "Descripcion"),
                    TotalUsuarios = reader.GetInt32(reader.GetOrdinal("TotalUsuarios")),
                    PuedePublicar = reader.GetBoolean(reader.GetOrdinal("PuedePublicar"))
                });
            }

            return result;
        }

        public Task<bool> IsDepartmentMemberAsync(int departmentId, int userId, bool canManageAll) =>
            ExecuteDepartmentPermissionAsync("dbo.sp_Chat_IsDepartmentMember", departmentId, userId, canManageAll);

        public Task<bool> CanPostToDepartmentAsync(int departmentId, int userId, bool canManageAll) =>
            ExecuteDepartmentPermissionAsync("dbo.sp_Chat_CanPostToDepartment", departmentId, userId, canManageAll);

        public async Task<ChatDepartmentMessageViewModel?> SendDepartmentMessageAsync(
            int departmentId,
            int senderId,
            string content,
            bool canManageAll)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = CreateProcedure(connection, "dbo.sp_Chat_SendDepartmentMessage");
            command.Parameters.Add("@DepartamentoId", SqlDbType.Int).Value = departmentId;
            command.Parameters.Add("@RemitenteId", SqlDbType.Int).Value = senderId;
            command.Parameters.Add("@Contenido", SqlDbType.NVarChar, 1000).Value = content;
            command.Parameters.Add("@PuedeAdministrarTodo", SqlDbType.Bit).Value = canManageAll;
            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync(CommandBehavior.SingleRow);
            return await reader.ReadAsync() ? ReadDepartmentMessage(reader) : null;
        }

        public async Task<List<ChatDepartmentMessageViewModel>> GetDepartmentMessagesAsync(
            int departmentId,
            int userId,
            bool canManageAll,
            int page,
            int pageSize)
        {
            var result = new List<ChatDepartmentMessageViewModel>();
            await using var connection = new SqlConnection(_connectionString);
            await using var command = CreateProcedure(connection, "dbo.sp_Chat_GetDepartmentMessages");
            command.Parameters.Add("@DepartamentoId", SqlDbType.Int).Value = departmentId;
            command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = userId;
            command.Parameters.Add("@PuedeAdministrarTodo", SqlDbType.Bit).Value = canManageAll;
            command.Parameters.Add("@Pagina", SqlDbType.Int).Value = NormalizePage(page);
            command.Parameters.Add("@TamanoPagina", SqlDbType.Int).Value = NormalizePageSize(pageSize, 50);
            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                result.Add(ReadDepartmentMessage(reader));
            }

            return result;
        }

        public async Task<List<ChatSearchResultViewModel>> SearchMessagesAsync(
            int userId,
            bool canManageAll,
            ChatSearchRequest request)
        {
            var result = new List<ChatSearchResultViewModel>();
            await using var connection = new SqlConnection(_connectionString);
            await using var command = CreateProcedure(connection, "dbo.sp_Chat_SearchMessages");
            command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = userId;
            command.Parameters.Add("@Texto", SqlDbType.NVarChar, 100).Value = request.Query.Trim();
            command.Parameters.Add("@Tipo", SqlDbType.NVarChar, 20).Value = NormalizeSearchType(request.Type);
            command.Parameters.Add("@ConversacionId", SqlDbType.Int).Value = request.ConversationId is > 0
                ? request.ConversationId.Value
                : DBNull.Value;
            command.Parameters.Add("@DepartamentoId", SqlDbType.Int).Value = request.DepartmentId is > 0
                ? request.DepartmentId.Value
                : DBNull.Value;
            command.Parameters.Add("@PuedeAdministrarTodo", SqlDbType.Bit).Value = canManageAll;
            command.Parameters.Add("@Pagina", SqlDbType.Int).Value = NormalizePage(request.Page);
            command.Parameters.Add("@TamanoPagina", SqlDbType.Int).Value = NormalizePageSize(request.PageSize, 25);
            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                result.Add(new ChatSearchResultViewModel
                {
                    MessageId = reader.GetInt32(reader.GetOrdinal("MensajeId")),
                    OriginType = reader.GetString(reader.GetOrdinal("TipoOrigen")),
                    ConversationId = GetNullableInt(reader, "ConversacionId"),
                    DepartmentId = GetNullableInt(reader, "DepartamentoId"),
                    OriginName = reader.GetString(reader.GetOrdinal("Origen")),
                    SenderId = reader.GetInt32(reader.GetOrdinal("RemitenteId")),
                    SenderName = reader.GetString(reader.GetOrdinal("RemitenteNombre")),
                    Content = reader.GetString(reader.GetOrdinal("Contenido")),
                    SentAt = reader.GetDateTime(reader.GetOrdinal("FechaEnvio")),
                    TotalResults = reader.GetInt32(reader.GetOrdinal("TotalResultados"))
                });
            }

            return result;
        }

        public async Task<List<ChatDepartmentAdminViewModel>> GetDepartmentsForAdministrationAsync()
        {
            var departments = new List<ChatDepartmentAdminViewModel>();
            await using var connection = new SqlConnection(_connectionString);
            await using var command = CreateProcedure(connection, "dbo.sp_Chat_Admin_GetDepartments");
            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                departments.Add(new ChatDepartmentAdminViewModel
                {
                    DepartmentId = reader.GetInt32(reader.GetOrdinal("DepartamentoId")),
                    Name = reader.GetString(reader.GetOrdinal("Nombre")),
                    Description = GetNullableString(reader, "Descripcion") ?? string.Empty,
                    Active = reader.GetBoolean(reader.GetOrdinal("Activo")),
                    MemberCount = reader.GetInt32(reader.GetOrdinal("TotalMiembros"))
                });
            }

            if (await reader.NextResultAsync())
            {
                while (await reader.ReadAsync())
                {
                    var departmentId = reader.GetInt32(reader.GetOrdinal("DepartamentoId"));
                    var department = departments.FirstOrDefault(item => item.DepartmentId == departmentId);
                    department?.Members.Add(new ChatDepartmentMemberViewModel
                    {
                        UserId = reader.GetInt32(reader.GetOrdinal("UsuarioId")),
                        FullName = reader.GetString(reader.GetOrdinal("NombreCompleto")),
                        Email = reader.GetString(reader.GetOrdinal("Correo")),
                        CanPost = reader.GetBoolean(reader.GetOrdinal("PuedePublicar"))
                    });
                }
            }

            return departments;
        }

        public async Task<int> CreateDepartmentAsync(ChatDepartmentFormViewModel model, int actorUserId)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = CreateProcedure(connection, "dbo.sp_Chat_Admin_CreateDepartment");
            AddDepartmentFormParameters(command, model, actorUserId, includeId: false);
            await connection.OpenAsync();
            return Convert.ToInt32(await command.ExecuteScalarAsync());
        }

        public async Task UpdateDepartmentAsync(ChatDepartmentFormViewModel model, int actorUserId)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = CreateProcedure(connection, "dbo.sp_Chat_Admin_UpdateDepartment");
            AddDepartmentFormParameters(command, model, actorUserId, includeId: true);
            await connection.OpenAsync();
            await command.ExecuteNonQueryAsync();
        }

        public async Task AddDepartmentMemberAsync(int departmentId, int userId, bool canPost, int actorUserId)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = CreateProcedure(connection, "dbo.sp_Chat_Admin_AddMember");
            command.Parameters.Add("@DepartamentoId", SqlDbType.Int).Value = departmentId;
            command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = userId;
            command.Parameters.Add("@PuedePublicar", SqlDbType.Bit).Value = canPost;
            command.Parameters.Add("@ActorUsuarioId", SqlDbType.Int).Value = actorUserId;
            await connection.OpenAsync();
            await command.ExecuteNonQueryAsync();
        }

        public async Task RemoveDepartmentMemberAsync(int departmentId, int userId, int actorUserId)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = CreateProcedure(connection, "dbo.sp_Chat_Admin_RemoveMember");
            command.Parameters.Add("@DepartamentoId", SqlDbType.Int).Value = departmentId;
            command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = userId;
            command.Parameters.Add("@ActorUsuarioId", SqlDbType.Int).Value = actorUserId;
            await connection.OpenAsync();
            await command.ExecuteNonQueryAsync();
        }

        private async Task<bool> ExecuteDepartmentPermissionAsync(
            string procedure,
            int departmentId,
            int userId,
            bool canManageAll)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = CreateProcedure(connection, procedure);
            command.Parameters.Add("@DepartamentoId", SqlDbType.Int).Value = departmentId;
            command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = userId;
            command.Parameters.Add("@PuedeAdministrarTodo", SqlDbType.Bit).Value = canManageAll;
            await connection.OpenAsync();
            return Convert.ToBoolean(await command.ExecuteScalarAsync());
        }

        private static SqlCommand CreateProcedure(SqlConnection connection, string name) =>
            new(name, connection) { CommandType = CommandType.StoredProcedure };

        private static ChatMessageViewModel ReadPrivateMessage(SqlDataReader reader) => new()
        {
            MensajeId = reader.GetInt32(reader.GetOrdinal("MensajeId")),
            ConversacionId = reader.GetInt32(reader.GetOrdinal("ConversacionId")),
            RemitenteId = reader.GetInt32(reader.GetOrdinal("RemitenteId")),
            Contenido = reader.GetString(reader.GetOrdinal("Contenido")),
            FechaEnvio = reader.GetDateTime(reader.GetOrdinal("FechaEnvio")),
            Leido = reader.GetBoolean(reader.GetOrdinal("Leido"))
        };

        private static ChatDepartmentMessageViewModel ReadDepartmentMessage(SqlDataReader reader) => new()
        {
            MensajeId = reader.GetInt32(reader.GetOrdinal("MensajeId")),
            DepartamentoId = reader.GetInt32(reader.GetOrdinal("DepartamentoId")),
            RemitenteId = reader.GetInt32(reader.GetOrdinal("RemitenteId")),
            Contenido = reader.GetString(reader.GetOrdinal("Contenido")),
            FechaEnvio = reader.GetDateTime(reader.GetOrdinal("FechaEnvio")),
            RemitenteNombre = reader.GetString(reader.GetOrdinal("RemitenteNombre"))
        };

        private static void AddDepartmentFormParameters(
            SqlCommand command,
            ChatDepartmentFormViewModel model,
            int actorUserId,
            bool includeId)
        {
            if (includeId)
            {
                command.Parameters.Add("@DepartamentoId", SqlDbType.Int).Value = model.DepartmentId;
            }

            command.Parameters.Add("@Nombre", SqlDbType.NVarChar, 120).Value = model.Name.Trim();
            command.Parameters.Add("@Descripcion", SqlDbType.NVarChar, 300).Value = string.IsNullOrWhiteSpace(model.Description)
                ? DBNull.Value
                : model.Description.Trim();
            command.Parameters.Add("@Activo", SqlDbType.Bit).Value = model.Active;
            command.Parameters.Add("@ActorUsuarioId", SqlDbType.Int).Value = actorUserId;
        }

        private static int NormalizePage(int page) => Math.Max(page, 1);
        private static int NormalizePageSize(int pageSize, int fallback) => Math.Clamp(pageSize <= 0 ? fallback : pageSize, 1, 100);

        private static string NormalizeSearchType(string? type) => type?.Trim().ToLowerInvariant() switch
        {
            "private" or "privado" => "privado",
            "department" or "departamento" => "departamento",
            _ => "todos"
        };

        private static string? GetNullableString(SqlDataReader reader, string name)
        {
            var ordinal = reader.GetOrdinal(name);
            return reader.IsDBNull(ordinal) ? null : reader.GetString(ordinal);
        }

        private static int? GetNullableInt(SqlDataReader reader, string name)
        {
            var ordinal = reader.GetOrdinal(name);
            return reader.IsDBNull(ordinal) ? null : reader.GetInt32(ordinal);
        }
    }
}
