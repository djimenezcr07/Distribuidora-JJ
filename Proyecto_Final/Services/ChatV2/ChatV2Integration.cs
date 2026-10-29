using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.Extensions.DependencyInjection.Extensions;

namespace Proyecto_Final.Services.ChatV2;

/// <summary>Explicit opt-in building blocks only. No endpoints, issuer credentials or keys are registered.</summary>
public static class ChatV2Integration
{
    public static IServiceCollection AddChatV2Components(this IServiceCollection services)
    {
        services.TryAddSingleton(TimeProvider.System);
        services.AddScoped<ChatV2Authorization>();services.AddScoped<IChatV2Authorization>(provider=>provider.GetRequiredService<ChatV2Authorization>());
        services.AddScoped<IChatV2CapabilityQuery>(provider=>provider.GetRequiredService<ChatV2Authorization>());
        services.AddScoped<IChatV2Repository,SqlChatV2Repository>();services.AddScoped<IChatV2CursorProtector,HmacChatV2CursorProtector>();
        services.AddSingleton<ChatV2SendCoordinator>();services.AddScoped<ChatV2MessagingService>();services.AddScoped<ChatV2JsonExceptionFilter>();
        return services;
    }
}

public sealed class ChatV2JsonExceptionFilter(ILogger<ChatV2JsonExceptionFilter> logger) : IExceptionFilter
{
    public void OnException(ExceptionContext context)
    {
        if(context.Exception is OperationCanceledException&&context.HttpContext.RequestAborted.IsCancellationRequested)return;
        var failure=context.Exception is ChatV2Exception chat?chat.Failure:context.Exception is UnauthorizedAccessException?ChatV2Failure.Session:ChatV2Failure.Dependency;
        // No exception object, SQL text, body, cursor, proof or actor PII enters this log.
        logger.LogWarning("Chat V2 request failed. Category {Category}; Correlation {Correlation}",failure,context.HttpContext.TraceIdentifier);
        context.Result=new ObjectResult(new ChatV2Error(failure.ToString().ToLowerInvariant(),context.HttpContext.TraceIdentifier)){StatusCode=ChatV2Errors.Status(failure)};
        context.ExceptionHandled=true;
    }
}
