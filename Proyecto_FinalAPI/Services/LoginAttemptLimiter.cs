using Microsoft.Extensions.Caching.Memory;

namespace Proyecto_FinalAPI.Services
{
    public class LoginAttemptLimiter
    {
        private const int MaxFailedAttempts = 5;
        private static readonly TimeSpan AttemptWindow = TimeSpan.FromMinutes(10);
        private static readonly TimeSpan BlockDuration = TimeSpan.FromMinutes(15);
        private readonly IMemoryCache _cache;

        public LoginAttemptLimiter(IMemoryCache cache)
        {
            _cache = cache;
        }

        public bool IsBlocked(string email, string ipAddress, out TimeSpan remainingTime)
        {
            remainingTime = TimeSpan.Zero;
            var key = BuildKey(email, ipAddress);

            if (!_cache.TryGetValue(key, out LoginAttemptState? state) || state == null)
            {
                return false;
            }

            if (state.BlockedUntil.HasValue && state.BlockedUntil.Value > DateTimeOffset.UtcNow)
            {
                remainingTime = state.BlockedUntil.Value - DateTimeOffset.UtcNow;
                return true;
            }

            if (state.BlockedUntil.HasValue && state.BlockedUntil.Value <= DateTimeOffset.UtcNow)
            {
                _cache.Remove(key);
            }

            return false;
        }

        public void RegisterFailedAttempt(string email, string ipAddress)
        {
            var key = BuildKey(email, ipAddress);

            if (!_cache.TryGetValue(key, out LoginAttemptState? state) || state == null)
            {
                state = new LoginAttemptState
                {
                    FailedAttempts = 0,
                    FirstAttemptAt = DateTimeOffset.UtcNow
                };
            }

            if (DateTimeOffset.UtcNow - state.FirstAttemptAt > AttemptWindow)
            {
                state.FailedAttempts = 0;
                state.FirstAttemptAt = DateTimeOffset.UtcNow;
                state.BlockedUntil = null;
            }

            state.FailedAttempts++;

            if (state.FailedAttempts >= MaxFailedAttempts)
            {
                state.BlockedUntil = DateTimeOffset.UtcNow.Add(BlockDuration);
            }

            var expiration = state.BlockedUntil.HasValue
                ? state.BlockedUntil.Value.AddMinutes(1)
                : DateTimeOffset.UtcNow.Add(AttemptWindow);

            _cache.Set(key, state, expiration);
        }

        public void Reset(string email, string ipAddress)
        {
            _cache.Remove(BuildKey(email, ipAddress));
        }

        private static string BuildKey(string email, string ipAddress)
        {
            var normalizedEmail = (email ?? string.Empty).Trim().ToLowerInvariant();
            var normalizedIp = string.IsNullOrWhiteSpace(ipAddress) ? "unknown" : ipAddress.Trim();
            return $"login-attempts:{normalizedEmail}:{normalizedIp}";
        }

        private sealed class LoginAttemptState
        {
            public int FailedAttempts { get; set; }
            public DateTimeOffset FirstAttemptAt { get; set; }
            public DateTimeOffset? BlockedUntil { get; set; }
        }
    }
}
