using System.Data;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Configuration;
using Moq;
using Proyecto_FinalAPI.Controllers;
using Proyecto_FinalAPI.Models;
using Proyecto_FinalAPI.Services;

namespace Proyecto_Final.Tests;

public sealed class AuthenticationContractTests
{
    [Fact]
    public void ValidateCommand_UsesHashOnlyCredentialLookupContract()
    {
        using var connection = new SqlConnection();
        using var command = AccountApiDbService.CreateValidateUserCommand(
            connection,
            "  admin@example.com  ");

        Assert.Equal("dbo.sp_Auth_GetLoginCredential", command.CommandText);
        Assert.Equal(CommandType.StoredProcedure, command.CommandType);

        var email = Assert.IsType<SqlParameter>(command.Parameters["@Correo"]);
        Assert.Equal(SqlDbType.NVarChar, email.SqlDbType);
        Assert.Equal(150, email.Size);
        Assert.Equal("admin@example.com", email.Value);

        Assert.False(command.Parameters.Contains("@Contrasena"));
    }

    [Fact]
    public void PasswordHash_UsesSaltAndRejectsWrongOrMalformedValues()
    {
        var service = new PasswordHashService();
        var first = service.Hash("correct horse battery staple");
        var second = service.Hash("correct horse battery staple");

        Assert.NotEqual(first, second);
        Assert.True(service.Verify("correct horse battery staple", first));
        Assert.False(service.Verify("wrong password", first));
        Assert.False(service.Verify("correct horse battery staple", "not-a-valid-hash"));
    }

    [Fact]
    public void AuthenticatedUserMapping_UsesColumnNamesInsteadOfPositions()
    {
        var table = new DataTable();
        table.Columns.Add("PerfilNombre", typeof(string));
        table.Columns.Add("Activo", typeof(bool));
        table.Columns.Add("Correo", typeof(string));
        table.Columns.Add("UsuarioId", typeof(int));
        table.Columns.Add("NombreCompleto", typeof(string));
        table.Columns.Add("SecurityStamp", typeof(Guid));
        var securityStamp = Guid.NewGuid();
        table.Rows.Add("Administrador", true, "admin@example.com", 42, "Admin de prueba", securityStamp);

        using var reader = table.CreateDataReader();
        Assert.True(reader.Read());
        var user = AccountApiDbService.MapAuthenticatedUser(reader);

        Assert.Equal(42, user.UsuarioId);
        Assert.Equal("Admin de prueba", user.NombreCompleto);
        Assert.Equal("admin@example.com", user.Correo);
        Assert.Equal("Administrador", user.PerfilNombre);
        Assert.True(user.Activo);
        Assert.Equal(securityStamp.ToString("D"), user.SecurityStamp);
    }

    [Fact]
    public async Task Login_ForwardsPasswordUnchangedAndReturnsAdministrator()
    {
        const string credentialInput = " value with spaces ";
        string? forwardedPassword = null;
        var database = new Mock<IAccountApiDbService>();
        database
            .Setup(service => service.ValidateUserAsync(
                "admin@example.com",
                It.IsAny<string>(),
                It.IsAny<CancellationToken>()))
            .Callback<string, string, CancellationToken>((_, value, _) => forwardedPassword = value)
            .ReturnsAsync(new ApiUser
            {
                UsuarioId = 42,
                PerfilId = 3,
                PerfilActivo = true,
                NombreCompleto = "Admin de prueba",
                Correo = "admin@example.com",
                PerfilNombre = "Administrador",
                Activo = true,
                SecurityStamp = Guid.NewGuid().ToString("D")
            });
        var controller = CreateController(database.Object);

        var result = await controller.Login(new LoginApiRequest
        {
            Email = "admin@example.com",
            Password = credentialInput
        });

        var ok = Assert.IsType<OkObjectResult>(result);
        var response = Assert.IsType<Proyecto_FinalAPI.Controllers.AuthResult>(ok.Value);
        Assert.True(response.Success);
        Assert.Equal("Administrador", response.Role);
        Assert.False(string.IsNullOrWhiteSpace(response.SecurityStamp));
        Assert.Equal(credentialInput, forwardedPassword);
    }

    [Fact]
    public async Task Login_InvalidCredentials_ReturnsGenericUnauthorizedResponse()
    {
        var database = new Mock<IAccountApiDbService>();
        database
            .Setup(service => service.ValidateUserAsync(
                It.IsAny<string>(),
                It.IsAny<string>(),
                It.IsAny<CancellationToken>()))
            .ReturnsAsync((ApiUser?)null);
        var controller = CreateController(database.Object);
        const string invalidCredential = "invalid";

        var result = await controller.Login(new LoginApiRequest
        {
            Email = "unknown@example.com",
            Password = invalidCredential
        });

        var unauthorized = Assert.IsType<UnauthorizedObjectResult>(result);
        var response = Assert.IsType<Proyecto_FinalAPI.Controllers.AuthResult>(unauthorized.Value);
        Assert.False(response.Success);
        Assert.Equal("Correo o contraseña incorrectos.", response.Message);
    }

    [Fact]
    public async Task ForgotPassword_WithoutPublicHttpsUrl_DoesNotCreateTokenAndReturnsGenericResponse()
    {
        var database = new Mock<IAccountApiDbService>();
        database.Setup(service => service.GetUserByEmailAsync("qa@example.com"))
            .ReturnsAsync(new ApiUser { UsuarioId = 7, Correo = "qa@example.com", NombreCompleto = "QA" });
        var controller = CreateController(database.Object, publicBaseUrl: null);

        var result = await controller.ForgotPassword(new ForgotPasswordApiRequest { Email = "qa@example.com" });

        var ok = Assert.IsType<OkObjectResult>(result);
        var response = Assert.IsType<Proyecto_FinalAPI.Controllers.AuthResult>(ok.Value);
        Assert.True(response.Success);
        database.Verify(service => service.CreatePasswordResetTokenAsync(It.IsAny<int>()), Times.Never);
    }

    [Fact]
    public void LoginAttemptLimiter_BlocksAfterFiveFailuresAndCanReset()
    {
        using var cache = new MemoryCache(new MemoryCacheOptions());
        var limiter = new LoginAttemptLimiter(cache);

        for (var attempt = 0; attempt < 5; attempt++)
            limiter.RegisterFailedAttempt("admin@example.com", "127.0.0.1");

        Assert.True(limiter.IsBlocked("admin@example.com", "127.0.0.1", out var remaining));
        Assert.True(remaining > TimeSpan.Zero);

        limiter.Reset("admin@example.com", "127.0.0.1");
        Assert.False(limiter.IsBlocked("admin@example.com", "127.0.0.1", out _));
    }

    private static AuthController CreateController(IAccountApiDbService database, string? publicBaseUrl = "https://qa.example.test")
    {
        var values = new Dictionary<string, string?>();
        if (publicBaseUrl is not null)
            values["PasswordRecovery:PublicBaseUrl"] = publicBaseUrl;
        var configuration = new ConfigurationBuilder().AddInMemoryCollection(values).Build();
        var cache = new MemoryCache(new MemoryCacheOptions());
        return new AuthController(
            database,
            new EmailService(configuration),
            new LoginAttemptLimiter(cache),
            new PasswordRecoveryAttemptLimiter(cache),
            configuration,
            Microsoft.Extensions.Logging.Abstractions.NullLogger<AuthController>.Instance,
            Microsoft.Extensions.Options.Options.Create(new CompanyOptions
            {
                BrandName = "Distribuidora JJ",
                BrandSubtitle = "Licorera - Distribuidora"
            }))
        {
            ControllerContext = new ControllerContext
            {
                HttpContext = new DefaultHttpContext()
            }
        };
    }
}
