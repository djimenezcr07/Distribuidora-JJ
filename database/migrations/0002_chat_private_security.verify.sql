SET NOCOUNT ON;

IF OBJECT_ID(N'dbo.ChatConversaciones', N'U') IS NULL OR OBJECT_ID(N'dbo.ChatMensajes', N'U') IS NULL
    THROW 54520, N'Faltan tablas de chat privado de 0002.', 1;

IF OBJECT_ID(N'dbo.sp_Chat_GetUsers', N'P') IS NULL OR
   OBJECT_ID(N'dbo.sp_Chat_GetOrCreateConversation', N'P') IS NULL OR
   OBJECT_ID(N'dbo.sp_Chat_SendMessage', N'P') IS NULL OR
   OBJECT_ID(N'dbo.sp_Chat_GetMessages', N'P') IS NULL
    THROW 54521, N'Faltan procedimientos de chat privado de 0002.', 1;

SELECT
    CAST((SELECT COUNT_BIG(*) FROM dbo.ChatConversaciones) AS BIGINT) AS Conversaciones,
    CAST((SELECT COUNT_BIG(*) FROM dbo.ChatMensajes) AS BIGINT) AS Mensajes;
GO
