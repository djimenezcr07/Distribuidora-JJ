using Microsoft.Extensions.Caching.Memory;

namespace Proyecto_FinalAPI.Services
{
    public class PasswordRecoveryAttemptLimiter
    {
        private const int MaxIdentifierAttempts = 5;
        private const int MaxIpAttempts = 20;
        private static readonly TimeSpan AttemptWindow = TimeSpan.FromMinutes(15);
        private static readonly TimeSpan BlockDuration = TimeSpan.FromMinutes(15);
        private readonly IMemoryCache _cache;

        public PasswordRecoveryAttemptLimiter(IMemoryCache cache)
        {
            _cache = cache;
        }

        public bool IsForgotPasswordBlocked(string email, string ipAddress, out TimeSpan remainingTime)
        {
            return IsBlocked(BuildIdentifierKey("forgot-password", email, ipAddress), out remainingTime)
                || IsBlocked(BuildIpKey("forgot-password", ipAddress), out remainingTime);
        }

        public void RegisterForgotPasswordAttempt(string email, string ipAddress)
        {
            RegisterAttempt(BuildIdentifierKey("forgot-password", email, ipAddress), MaxIdentifierAttempts);
            RegisterAttempt(BuildIpKey("forgot-password", ipAddress), MaxIpAttempts);
        }

        public bool IsResetPasswordBlocked(string token, string ipAddress, out TimeSpan remainingTime)
        {
            return IsBlocked(BuildIdentifierKey("reset-password", token, ipAddress), out remainingTime)
                || IsBlocked(BuildIpKey("reset-password", ipAddress), out remainingTime);
        }

        public void RegisterResetPasswordAttempt(string token, string ipAddress)
        {
            RegisterAttempt(BuildIdentifierKey("reset-password", token, ipAddress), MaxIdentifierAttempts);
            RegisterAttempt(BuildIpKey("reset-password", ipAddress), MaxIpAttempts);
        }

        public void ResetResetPasswordAttempts(string token, string ipAddress)
        {
            _cache.Remove(BuildIdentifierKey("reset-password", token, ipAddress));
        }

        private bool IsBlocked(string key, out TimeSpan remainingTime)
        {
            remainingTime = TimeSpan.Zero;

            if (!_cache.TryGetValue(key, out RecoveryAttemptState? state) || state == null)
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

        private void RegisterAttempt(string key, int maxAttempts)
        {
            if (!_cache.TryGetValue(key, out RecoveryAttemptState? state) || state == null)
            {
                state = new RecoveryAttemptState
                {
                    Attempts = 0,
                    FirstAttemptAt = DateTimeOffset.UtcNow
                };
            }

            if (DateTimeOffset.UtcNow - state.FirstAttemptAt > AttemptWindow)
            {
                state.Attempts = 0;
                state.FirstAttemptAt = DateTimeOffset.UtcNow;
                state.BlockedUntil = null;
            }

            state.Attempts++;

            if (state.Attempts >= maxAttempts)
            {
                state.BlockedUntil = DateTimeOffset.UtcNow.Add(BlockDuration);
            }

            var expiration = state.BlockedUntil.HasValue
                ? state.BlockedUntil.Value.AddMinutes(1)
                : DateTimeOffset.UtcNow.Add(AttemptWindow);

            _cache.Set(key, state, expiration);
        }

        private static string BuildIdentifierKey(string scope, string identifier, string ipAddress)
        {
            var normalizedIdentifier = string.IsNullOrWhiteSpace(identifier)
                ? "unknown"
                : identifier.Trim().ToLowerInvariant();
            var normalizedIp = NormalizeIp(ipAddress);

            return $"password-recovery:{scope}:identifier:{normalizedIdentifier}:ip:{normalizedIp}";
        }

        private static string BuildIpKey(string scope, string ipAddress)
        {
            return $"password-recovery:{scope}:ip:{NormalizeIp(ipAddress)}";
        }

        private static string NormalizeIp(string ipAddress)
        {
            return string.IsNullOrWhiteSpace(ipAddress) ? "unknown" : ipAddress.Trim();
        }

        private sealed class RecoveryAttemptState
        {
            public int Attempts { get; set; }
            public DateTimeOffset FirstAttemptAt { get; set; }
            public DateTimeOffset? BlockedUntil { get; set; }
        }
    }
}
