SET NOCOUNT ON;

IF OBJECT_ID(N'dbo.ChatDepartamentos', N'U') IS NULL OR
   OBJECT_ID(N'dbo.ChatDepartamentoMiembros', N'U') IS NULL OR
   OBJECT_ID(N'dbo.ChatDepartamentoMensajes', N'U') IS NULL
    THROW 54530, N'Faltan tablas de chat departamental de 0003.', 1;

IF OBJECT_ID(N'dbo.sp_Chat_GetDepartments', N'P') IS NULL OR
   OBJECT_ID(N'dbo.sp_Chat_SendDepartmentMessage', N'P') IS NULL OR
   OBJECT_ID(N'dbo.sp_Chat_GetDepartmentMessages', N'P') IS NULL OR
   OBJECT_ID(N'dbo.sp_Chat_SearchMessages', N'P') IS NULL OR
   OBJECT_ID(N'dbo.sp_Chat_Admin_GetDepartments', N'P') IS NULL OR
   OBJECT_ID(N'dbo.sp_Chat_Admin_CreateDepartment', N'P') IS NULL OR
   OBJECT_ID(N'dbo.sp_Chat_Admin_UpdateDepartment', N'P') IS NULL OR
   OBJECT_ID(N'dbo.sp_Chat_Admin_AddMember', N'P') IS NULL OR
   OBJECT_ID(N'dbo.sp_Chat_Admin_RemoveMember', N'P') IS NULL
    THROW 54531, N'Faltan procedimientos de chat departamental de 0003.', 1;

IF OBJECT_ID(N'dbo.Permisos', N'U') IS NOT NULL AND
   NOT EXISTS (SELECT 1 FROM dbo.Permisos WHERE Codigo = N'CHAT_DEPARTAMENTOS_GESTIONAR')
    THROW 54532, N'Falta el permiso CHAT_DEPARTAMENTOS_GESTIONAR.', 1;

SELECT
    CAST((SELECT COUNT_BIG(*) FROM dbo.ChatDepartamentos) AS BIGINT) AS Departamentos,
    CAST((SELECT COUNT_BIG(*) FROM dbo.ChatDepartamentoMiembros) AS BIGINT) AS Miembros,
    CAST((SELECT COUNT_BIG(*) FROM dbo.ChatDepartamentoMensajes) AS BIGINT) AS Mensajes;
GO
