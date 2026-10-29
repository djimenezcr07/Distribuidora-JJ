using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;

namespace Proyecto_Final.Services.ChatV2;

[Authorize]
public sealed class ChatV2Hub(ChatV2ConnectionRegistry registry, IChatV2IdentityContext identities) : Hub
{
    public override async Task OnConnectedAsync()
    {
        try
        {
            var session = await identities.ResolveCurrentAsync(Context.ConnectionAborted);
            await registry.RegisterAsync(Context.ConnectionId, session.Identity.SessionId, Context.Abort, Context.ConnectionAborted);
            await base.OnConnectedAsync();
        }
        catch { Context.Abort(); throw new HubException("connection_denied"); }
    }
    public override async Task OnDisconnectedAsync(Exception? exception)
    { registry.Disconnect(Context.ConnectionId); await base.OnDisconnectedAsync(exception); }
    // Selectors only: the actor, session, capabilities and epochs always come from the server.
    public Task Subscribe(string domain, int resource) => Sensitive(async () =>
    {
        var selected = domain switch { "P" => ChatV2Domain.Private, "D" => ChatV2Domain.Department,
            "C" => ChatV2Domain.Customer, _ => throw new ChatV2Exception(ChatV2Failure.Validation) };
        await registry.SubscribeAsync(Context.ConnectionId, new(selected, resource), Context.ConnectionAborted);
    });
    public Task Unsubscribe() => Sensitive(async () => await registry.UnsubscribeAsync(Context.ConnectionId, Context.ConnectionAborted));
    public Task Revalidate() => Sensitive(async () => await registry.RevalidateConnectionAsync(Context.ConnectionId, Context.ConnectionAborted));
    private static async Task Sensitive(Func<Task> action)
    {
        try { await action(); }
        catch (ChatV2Exception error) { throw new HubException(error.Failure.ToString().ToLowerInvariant()); }
        catch { throw new HubException("dependency"); }
    }
}

public sealed class ChatV2GenericNotifications(IHubContext<ChatV2Hub> hub) : IChatV2GenericNotifications
{
    public ValueTask InvalidateAsync(string serverConnectionId, CancellationToken ct)
        => new(hub.Clients.Client(serverConnectionId).SendCoreAsync("Invalidate", [], ct));
}

/// <summary>Explicit composition only. No route mapping or productive startup registration.</summary>
public static class ChatV2TransportIntegration
{
    public static IServiceCollection AddChatV2Transport(this IServiceCollection services)
    {
        services.AddSignalR(options => { options.EnableDetailedErrors = false; options.MaximumReceiveMessageSize = 4096;
            options.MaximumParallelInvocationsPerClient = 1; });
        services.AddSingleton<IChatV2ConnectionValidator, ChatV2ConnectionValidator>();
        services.AddSingleton<IChatV2GenericNotifications, ChatV2GenericNotifications>();
        services.AddSingleton<ChatV2ConnectionRegistry>();
        services.AddSingleton<IChatV2ConnectionRegistry>(provider => provider.GetRequiredService<ChatV2ConnectionRegistry>());
        services.AddSingleton<IChatV2RevocationBridge>(provider => provider.GetRequiredService<ChatV2ConnectionRegistry>());
        return services;
    }
}
