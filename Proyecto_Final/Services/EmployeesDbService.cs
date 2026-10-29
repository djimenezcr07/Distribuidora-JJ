using Microsoft.AspNetCore.Mvc.Rendering;
using Microsoft.Data.SqlClient;
using Proyecto_Final.Models.Admin;
using System.Data;

namespace Proyecto_Final.Services
{
    public interface IEmployeesService
    {
        Task<List<EmployeeRoleOptionViewModel>> GetEmployeeRolesAsync();
        Task<List<SelectListItem>> GetEmployeeRoleSelectListAsync(int? selectedPerfilId = null);
        Task<List<EmployeeListItemViewModel>> GetEmployeesAsync(string? buscar, string? estado);
        Task<EmployeeFormViewModel?> GetEmployeeFormByIdAsync(int empleadoId);
        Task<EmployeeDetailViewModel?> GetEmployeeDetailAsync(int empleadoId);
        Task<int> CreateEmployeeAsync(EmployeeFormViewModel model, int? usuarioCambioId, string? usuarioCambioNombre);
        Task UpdateEmployeeAsync(EmployeeFormViewModel model, int? usuarioCambioId, string? usuarioCambioNombre);
        Task<bool> ToggleEmployeeStatusAsync(int empleadoId);
        Task<int> CreateEmployeeTaskAsync(EmployeeTaskFormViewModel model, int? usuarioAsignacionId, string? usuarioAsignacionNombre);
        Task UpdateEmployeeTaskStatusAsync(int tareaId, string estado);
        Task<List<EmployeeLeaveRequestViewModel>> GetEmployeeLeaveRequestsAsync(string? estado, int? empleadoId = null);
        Task UpdateEmployeeLeaveRequestStatusAsync(EmployeeLeaveRequestDecisionViewModel model, int? usuarioRespuestaId, string? usuarioRespuestaNombre);
        Task<EmployeePortalViewModel> GetEmployeePortalAsync(int usuarioId);
        Task<int> CreateMyLeaveRequestAsync(int usuarioId, EmployeeLeaveRequestFormViewModel model);
        Task UpdateMyTaskStatusAsync(int usuarioId, int tareaId, string estado);
    }

    public class EmployeesDbService : IEmployeesService
    {
        private readonly string _connectionString;
        private readonly IPasswordHashService _passwordHashes;

        public EmployeesDbService(IConfiguration configuration, IPasswordHashService passwordHashes)
        {
            _connectionString = configuration.GetConnectionString("DefaultConnection")
                ?? throw new InvalidOperationException("No se encontró la cadena de conexión DefaultConnection.");
            _passwordHashes = passwordHashes;
        }

        public async Task<List<EmployeeRoleOptionViewModel>> GetEmployeeRolesAsync()
        {
            var roles = new List<EmployeeRoleOptionViewModel>();

            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Admin_GetEmployeeRoles", connection)
            {
                CommandType = CommandType.StoredProcedure
            };

            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();

            while (await reader.ReadAsync())
            {
                roles.Add(new EmployeeRoleOptionViewModel
                {
                    PerfilId = reader.GetInt32(0),
                    Nombre = reader.GetString(1)
                });
            }

            return roles;
        }

        public async Task<List<SelectListItem>> GetEmployeeRoleSelectListAsync(int? selectedPerfilId = null)
        {
            var roles = await GetEmployeeRolesAsync();

            return roles.Select(role => new SelectListItem
            {
                Value = role.PerfilId.ToString(),
                Text = role.Nombre,
                Selected = selectedPerfilId.HasValue && selectedPerfilId.Value == role.PerfilId
            }).ToList();
        }

        public async Task<List<EmployeeListItemViewModel>> GetEmployeesAsync(string? buscar, string? estado)
        {
            var employees = new List<EmployeeListItemViewModel>();

            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Admin_GetEmployees", connection)
            {
                CommandType = CommandType.StoredProcedure
            };

            command.Parameters.Add("@Buscar", SqlDbType.NVarChar, 150).Value = string.IsNullOrWhiteSpace(buscar) ? DBNull.Value : buscar.Trim();
            command.Parameters.Add("@Estado", SqlDbType.NVarChar, 20).Value = string.IsNullOrWhiteSpace(estado) ? DBNull.Value : estado.Trim();

            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();

            while (await reader.ReadAsync())
            {
                employees.Add(ReadEmployeeListItem(reader));
            }

            return employees;
        }

        public async Task<EmployeeFormViewModel?> GetEmployeeFormByIdAsync(int empleadoId)
        {
            var detail = await GetEmployeeHeaderAsync(empleadoId);
            if (detail == null) return null;

            return new EmployeeFormViewModel
            {
                EmpleadoId = detail.EmpleadoId,
                UsuarioId = detail.UsuarioId,
                PerfilId = detail.PerfilId,
                Rol = detail.Rol,
                NombreCompleto = detail.NombreCompleto,
                Correo = detail.Correo,
                Telefono = detail.Telefono,
                Direccion = detail.Direccion,
                Puesto = detail.Puesto,
                Departamento = detail.Departamento,
                Salario = detail.Salario,
                FechaContratacion = detail.FechaContratacion,
                Responsabilidades = detail.Responsabilidades,
                ObservacionesInternas = detail.ObservacionesInternas,
                Activo = detail.Activo && detail.UsuarioActivo,
                FechaRegistro = detail.FechaRegistro,
                FechaActualizacion = detail.FechaActualizacion,
                RowVersionBase64 = detail.RowVersionBase64,
                RolesDisponibles = await GetEmployeeRoleSelectListAsync(detail.PerfilId)
            };
        }

        public async Task<EmployeeDetailViewModel?> GetEmployeeDetailAsync(int empleadoId)
        {
            var detail = await GetEmployeeHeaderAsync(empleadoId);
            if (detail == null) return null;

            detail.Tareas = await GetEmployeeTasksAsync(empleadoId);
            detail.Solicitudes = await GetEmployeeLeaveRequestsAsync(null, empleadoId);
            detail.HistorialSalarios = await GetEmployeeSalaryHistoryAsync(empleadoId);
            detail.NuevaTarea = new EmployeeTaskFormViewModel { EmpleadoId = empleadoId };

            return detail;
        }

        public async Task<int> CreateEmployeeAsync(EmployeeFormViewModel model, int? usuarioCambioId, string? usuarioCambioNombre)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Admin_CreateEmployee", connection)
            {
                CommandType = CommandType.StoredProcedure
            };

            AddEmployeeFormParameters(command, model, includePassword: true);
            command.Parameters.Add("@UsuarioCambioId", SqlDbType.Int).Value = usuarioCambioId.HasValue && usuarioCambioId.Value > 0 ? usuarioCambioId.Value : DBNull.Value;
            command.Parameters.Add("@UsuarioCambioNombre", SqlDbType.NVarChar, 150).Value = string.IsNullOrWhiteSpace(usuarioCambioNombre) ? DBNull.Value : usuarioCambioNombre.Trim();

            await connection.OpenAsync();
            var result = await command.ExecuteScalarAsync();
            return Convert.ToInt32(result ?? 0);
        }

        public async Task UpdateEmployeeAsync(EmployeeFormViewModel model, int? usuarioCambioId, string? usuarioCambioNombre)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_RRHH_UpdateEmployee", connection)
            {
                CommandType = CommandType.StoredProcedure
            };

            command.Parameters.Add("@EmpleadoId", SqlDbType.Int).Value = model.EmpleadoId;
            AddEmployeeFormParameters(command, model, includePassword: false);
            command.Parameters.Add("@MotivoCambioSalario", SqlDbType.NVarChar, 255).Value = string.IsNullOrWhiteSpace(model.MotivoCambioSalario) ? DBNull.Value : model.MotivoCambioSalario.Trim();
            command.Parameters.Add("@UsuarioCambioId", SqlDbType.Int).Value = usuarioCambioId.HasValue && usuarioCambioId.Value > 0 ? usuarioCambioId.Value : DBNull.Value;
            command.Parameters.Add("@UsuarioCambioNombre", SqlDbType.NVarChar, 150).Value = string.IsNullOrWhiteSpace(usuarioCambioNombre) ? DBNull.Value : usuarioCambioNombre.Trim();
            command.Parameters.Add("@VersionFila", SqlDbType.Binary, 8).Value = Convert.FromBase64String(model.RowVersionBase64);

            await connection.OpenAsync();
            await command.ExecuteNonQueryAsync();
        }

        public async Task<bool> ToggleEmployeeStatusAsync(int empleadoId)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Admin_ToggleEmployeeStatus", connection)
            {
                CommandType = CommandType.StoredProcedure
            };

            command.Parameters.Add("@EmpleadoId", SqlDbType.Int).Value = empleadoId;

            await connection.OpenAsync();
            var result = await command.ExecuteScalarAsync();
            return Convert.ToBoolean(result ?? false);
        }

        public async Task<int> CreateEmployeeTaskAsync(EmployeeTaskFormViewModel model, int? usuarioAsignacionId, string? usuarioAsignacionNombre)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Admin_CreateEmployeeTask", connection)
            {
                CommandType = CommandType.StoredProcedure
            };

            command.Parameters.Add("@EmpleadoId", SqlDbType.Int).Value = model.EmpleadoId;
            command.Parameters.Add("@Titulo", SqlDbType.NVarChar, 150).Value = model.Titulo.Trim();
            command.Parameters.Add("@Descripcion", SqlDbType.NVarChar, 700).Value = string.IsNullOrWhiteSpace(model.Descripcion) ? DBNull.Value : model.Descripcion.Trim();
            command.Parameters.Add("@Prioridad", SqlDbType.NVarChar, 20).Value = model.Prioridad.Trim();
            command.Parameters.Add("@FechaLimite", SqlDbType.Date).Value = model.FechaLimite.HasValue ? model.FechaLimite.Value.Date : DBNull.Value;
            command.Parameters.Add("@UsuarioAsignacionId", SqlDbType.Int).Value = usuarioAsignacionId.HasValue && usuarioAsignacionId.Value > 0 ? usuarioAsignacionId.Value : DBNull.Value;
            command.Parameters.Add("@UsuarioAsignacionNombre", SqlDbType.NVarChar, 150).Value = string.IsNullOrWhiteSpace(usuarioAsignacionNombre) ? DBNull.Value : usuarioAsignacionNombre.Trim();

            await connection.OpenAsync();
            var result = await command.ExecuteScalarAsync();
            return Convert.ToInt32(result ?? 0);
        }

        public async Task UpdateEmployeeTaskStatusAsync(int tareaId, string estado)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Admin_UpdateEmployeeTaskStatus", connection)
            {
                CommandType = CommandType.StoredProcedure
            };

            command.Parameters.Add("@TareaId", SqlDbType.Int).Value = tareaId;
            command.Parameters.Add("@Estado", SqlDbType.NVarChar, 30).Value = estado.Trim();

            await connection.OpenAsync();
            await command.ExecuteNonQueryAsync();
        }

        public async Task<List<EmployeeLeaveRequestViewModel>> GetEmployeeLeaveRequestsAsync(string? estado, int? empleadoId = null)
        {
            var requests = new List<EmployeeLeaveRequestViewModel>();

            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Admin_GetEmployeeLeaveRequests", connection)
            {
                CommandType = CommandType.StoredProcedure
            };

            command.Parameters.Add("@Estado", SqlDbType.NVarChar, 30).Value = string.IsNullOrWhiteSpace(estado) ? DBNull.Value : estado.Trim();
            command.Parameters.Add("@EmpleadoId", SqlDbType.Int).Value = empleadoId.HasValue && empleadoId.Value > 0 ? empleadoId.Value : DBNull.Value;

            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();

            while (await reader.ReadAsync())
            {
                requests.Add(ReadLeaveRequest(reader));
            }

            return requests;
        }

        public async Task UpdateEmployeeLeaveRequestStatusAsync(EmployeeLeaveRequestDecisionViewModel model, int? usuarioRespuestaId, string? usuarioRespuestaNombre)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Admin_UpdateEmployeeLeaveRequestStatus", connection)
            {
                CommandType = CommandType.StoredProcedure
            };

            command.Parameters.Add("@SolicitudId", SqlDbType.Int).Value = model.SolicitudId;
            command.Parameters.Add("@Estado", SqlDbType.NVarChar, 30).Value = model.Estado.Trim();
            command.Parameters.Add("@RespuestaAdmin", SqlDbType.NVarChar, 500).Value = string.IsNullOrWhiteSpace(model.RespuestaAdmin) ? DBNull.Value : model.RespuestaAdmin.Trim();
            command.Parameters.Add("@UsuarioRespuestaId", SqlDbType.Int).Value = usuarioRespuestaId.HasValue && usuarioRespuestaId.Value > 0 ? usuarioRespuestaId.Value : DBNull.Value;
            command.Parameters.Add("@UsuarioRespuestaNombre", SqlDbType.NVarChar, 150).Value = string.IsNullOrWhiteSpace(usuarioRespuestaNombre) ? DBNull.Value : usuarioRespuestaNombre.Trim();

            await connection.OpenAsync();
            await command.ExecuteNonQueryAsync();
        }

        public async Task<EmployeePortalViewModel> GetEmployeePortalAsync(int usuarioId)
        {
            var model = new EmployeePortalViewModel();
            var profile = await GetEmployeeProfileByUserIdAsync(usuarioId);

            if (profile == null)
            {
                return model;
            }

            model.Perfil = profile;
            model.Tareas = await GetEmployeeTasksAsync(profile.EmpleadoId);
            model.Solicitudes = await GetEmployeeLeaveRequestsAsync(null, profile.EmpleadoId);
            model.NuevaSolicitud = new EmployeeLeaveRequestFormViewModel();

            return model;
        }

        public async Task<int> CreateMyLeaveRequestAsync(int usuarioId, EmployeeLeaveRequestFormViewModel model)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Employee_CreateLeaveRequest", connection)
            {
                CommandType = CommandType.StoredProcedure
            };

            command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = usuarioId;
            command.Parameters.Add("@FechaInicio", SqlDbType.Date).Value = model.FechaInicio.Date;
            command.Parameters.Add("@FechaFin", SqlDbType.Date).Value = model.FechaFin.Date;
            command.Parameters.Add("@TipoSolicitud", SqlDbType.NVarChar, 30).Value = model.TipoSolicitud.Trim();
            command.Parameters.Add("@Motivo", SqlDbType.NVarChar, 500).Value = model.Motivo.Trim();

            await connection.OpenAsync();
            var result = await command.ExecuteScalarAsync();
            return Convert.ToInt32(result ?? 0);
        }

        public async Task UpdateMyTaskStatusAsync(int usuarioId, int tareaId, string estado)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Employee_UpdateMyTaskStatus", connection)
            {
                CommandType = CommandType.StoredProcedure
            };

            command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = usuarioId;
            command.Parameters.Add("@TareaId", SqlDbType.Int).Value = tareaId;
            command.Parameters.Add("@Estado", SqlDbType.NVarChar, 30).Value = estado.Trim();

            await connection.OpenAsync();
            await command.ExecuteNonQueryAsync();
        }

        private async Task<EmployeeDetailViewModel?> GetEmployeeProfileByUserIdAsync(int usuarioId)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Employee_GetMyProfile", connection)
            {
                CommandType = CommandType.StoredProcedure
            };

            command.Parameters.Add("@UsuarioId", SqlDbType.Int).Value = usuarioId;

            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();

            if (!await reader.ReadAsync()) return null;

            return new EmployeeDetailViewModel
            {
                EmpleadoId = reader.GetInt32(0),
                UsuarioId = reader.GetInt32(1),
                NombreCompleto = reader.GetString(2),
                Correo = reader.GetString(3),
                Telefono = GetNullableString(reader, 4),
                Direccion = GetNullableString(reader, 5),
                Rol = reader.GetString(6),
                Puesto = reader.GetString(7),
                Departamento = GetNullableString(reader, 8),
                Salario = reader.GetDecimal(9),
                FechaContratacion = GetNullableDateTime(reader, 10),
                Responsabilidades = GetNullableString(reader, 11),
                Activo = reader.GetBoolean(12),
                UsuarioActivo = reader.GetBoolean(13)
            };
        }

        private async Task<EmployeeDetailViewModel?> GetEmployeeHeaderAsync(int empleadoId)
        {
            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Admin_GetEmployeeById", connection)
            {
                CommandType = CommandType.StoredProcedure
            };

            command.Parameters.Add("@EmpleadoId", SqlDbType.Int).Value = empleadoId;

            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();

            if (!await reader.ReadAsync()) return null;

            return new EmployeeDetailViewModel
            {
                EmpleadoId = reader.GetInt32(0),
                UsuarioId = reader.GetInt32(1),
                PerfilId = reader.GetInt32(2),
                Rol = reader.GetString(3),
                NombreCompleto = reader.GetString(4),
                Correo = reader.GetString(5),
                Telefono = GetNullableString(reader, 6),
                Direccion = GetNullableString(reader, 7),
                Puesto = reader.GetString(8),
                Departamento = GetNullableString(reader, 9),
                Salario = reader.GetDecimal(10),
                FechaContratacion = GetNullableDateTime(reader, 11),
                Responsabilidades = GetNullableString(reader, 12),
                ObservacionesInternas = GetNullableString(reader, 13),
                Activo = reader.GetBoolean(14),
                UsuarioActivo = reader.GetBoolean(15),
                FechaRegistro = reader.GetDateTime(16),
                FechaActualizacion = GetNullableDateTime(reader, 17),
                RowVersionBase64 = reader.FieldCount > 18 && !reader.IsDBNull(18)
                    ? Convert.ToBase64String((byte[])reader.GetValue(18))
                    : string.Empty
            };
        }

        private async Task<List<EmployeeTaskViewModel>> GetEmployeeTasksAsync(int empleadoId)
        {
            var tasks = new List<EmployeeTaskViewModel>();

            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Admin_GetEmployeeTasks", connection)
            {
                CommandType = CommandType.StoredProcedure
            };

            command.Parameters.Add("@EmpleadoId", SqlDbType.Int).Value = empleadoId;

            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();

            while (await reader.ReadAsync())
            {
                tasks.Add(new EmployeeTaskViewModel
                {
                    TareaId = reader.GetInt32(0),
                    EmpleadoId = reader.GetInt32(1),
                    Titulo = reader.GetString(2),
                    Descripcion = GetNullableString(reader, 3),
                    Prioridad = reader.GetString(4),
                    Estado = reader.GetString(5),
                    FechaAsignacion = reader.GetDateTime(6),
                    FechaLimite = GetNullableDateTime(reader, 7),
                    UsuarioAsignacionNombre = GetNullableString(reader, 8),
                    FechaActualizacion = GetNullableDateTime(reader, 9)
                });
            }

            return tasks;
        }

        private async Task<List<EmployeeSalaryHistoryViewModel>> GetEmployeeSalaryHistoryAsync(int empleadoId)
        {
            var history = new List<EmployeeSalaryHistoryViewModel>();

            await using var connection = new SqlConnection(_connectionString);
            await using var command = new SqlCommand("dbo.sp_Admin_GetEmployeeSalaryHistory", connection)
            {
                CommandType = CommandType.StoredProcedure
            };

            command.Parameters.Add("@EmpleadoId", SqlDbType.Int).Value = empleadoId;

            await connection.OpenAsync();
            await using var reader = await command.ExecuteReaderAsync();

            while (await reader.ReadAsync())
            {
                history.Add(new EmployeeSalaryHistoryViewModel
                {
                    HistorialSalarioId = reader.GetInt32(0),
                    EmpleadoId = reader.GetInt32(1),
                    SalarioAnterior = reader.IsDBNull(2) ? null : reader.GetDecimal(2),
                    SalarioNuevo = reader.GetDecimal(3),
                    Motivo = GetNullableString(reader, 4),
                    UsuarioCambioNombre = GetNullableString(reader, 5),
                    FechaCambio = reader.GetDateTime(6)
                });
            }

            return history;
        }

        private void AddEmployeeFormParameters(SqlCommand command, EmployeeFormViewModel model, bool includePassword)
        {
            command.Parameters.Add("@PerfilId", SqlDbType.Int).Value = model.PerfilId;
            command.Parameters.Add("@NombreCompleto", SqlDbType.NVarChar, 150).Value = model.NombreCompleto.Trim();
            command.Parameters.Add("@Correo", SqlDbType.NVarChar, 150).Value = model.Correo.Trim();

            if (includePassword && string.IsNullOrWhiteSpace(model.Contrasena))
                throw new InvalidOperationException("La contraseña inicial es obligatoria.");

            command.Parameters.Add("@ContrasenaHash", SqlDbType.NVarChar, 512).Value = string.IsNullOrWhiteSpace(model.Contrasena)
                ? DBNull.Value
                : _passwordHashes.Hash(model.Contrasena);

            command.Parameters.Add("@Telefono", SqlDbType.NVarChar, 30).Value = string.IsNullOrWhiteSpace(model.Telefono) ? DBNull.Value : model.Telefono.Trim();
            command.Parameters.Add("@Direccion", SqlDbType.NVarChar, 255).Value = string.IsNullOrWhiteSpace(model.Direccion) ? DBNull.Value : model.Direccion.Trim();
            command.Parameters.Add("@Puesto", SqlDbType.NVarChar, 100).Value = model.Puesto.Trim();
            command.Parameters.Add("@Departamento", SqlDbType.NVarChar, 100).Value = string.IsNullOrWhiteSpace(model.Departamento) ? DBNull.Value : model.Departamento.Trim();
            command.Parameters.Add("@Salario", SqlDbType.Decimal).Value = model.Salario;
            command.Parameters["@Salario"].Precision = 18;
            command.Parameters["@Salario"].Scale = 2;
            command.Parameters.Add("@FechaContratacion", SqlDbType.Date).Value = model.FechaContratacion.HasValue ? model.FechaContratacion.Value.Date : DBNull.Value;
            command.Parameters.Add("@Responsabilidades", SqlDbType.NVarChar, -1).Value = string.IsNullOrWhiteSpace(model.Responsabilidades) ? DBNull.Value : model.Responsabilidades.Trim();
            command.Parameters.Add("@ObservacionesInternas", SqlDbType.NVarChar, -1).Value = string.IsNullOrWhiteSpace(model.ObservacionesInternas) ? DBNull.Value : model.ObservacionesInternas.Trim();
            command.Parameters.Add("@Activo", SqlDbType.Bit).Value = model.Activo;
        }

        private static EmployeeListItemViewModel ReadEmployeeListItem(SqlDataReader reader)
        {
            return new EmployeeListItemViewModel
            {
                EmpleadoId = reader.GetInt32(0),
                UsuarioId = reader.GetInt32(1),
                NombreCompleto = reader.GetString(2),
                Correo = reader.GetString(3),
                Telefono = GetNullableString(reader, 4),
                Direccion = GetNullableString(reader, 5),
                Rol = reader.GetString(6),
                Puesto = reader.GetString(7),
                Departamento = GetNullableString(reader, 8),
                Salario = reader.GetDecimal(9),
                FechaContratacion = GetNullableDateTime(reader, 10),
                Activo = reader.GetBoolean(11),
                UsuarioActivo = reader.GetBoolean(12),
                TareasPendientes = reader.GetInt32(13),
                SolicitudesPendientes = reader.GetInt32(14)
            };
        }

        private static EmployeeLeaveRequestViewModel ReadLeaveRequest(SqlDataReader reader)
        {
            return new EmployeeLeaveRequestViewModel
            {
                SolicitudId = reader.GetInt32(0),
                EmpleadoId = reader.GetInt32(1),
                NombreCompleto = reader.GetString(2),
                Correo = reader.GetString(3),
                Puesto = reader.GetString(4),
                FechaInicio = reader.GetDateTime(5),
                FechaFin = reader.GetDateTime(6),
                CantidadDias = reader.GetInt32(7),
                TipoSolicitud = reader.GetString(8),
                Motivo = reader.GetString(9),
                Estado = reader.GetString(10),
                RespuestaAdmin = GetNullableString(reader, 11),
                UsuarioRespuestaNombre = GetNullableString(reader, 12),
                FechaSolicitud = reader.GetDateTime(13),
                FechaRespuesta = GetNullableDateTime(reader, 14)
            };
        }

        private static string? GetNullableString(SqlDataReader reader, int ordinal)
        {
            return reader.IsDBNull(ordinal) ? null : reader.GetString(ordinal);
        }

        private static DateTime? GetNullableDateTime(SqlDataReader reader, int ordinal)
        {
            return reader.IsDBNull(ordinal) ? null : reader.GetDateTime(ordinal);
        }
    }
}
