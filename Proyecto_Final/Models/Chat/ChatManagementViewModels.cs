using System.ComponentModel.DataAnnotations;

namespace Proyecto_Final.Models.Chat
{
    public sealed class ChatSearchRequest
    {
        [Required]
        [StringLength(100, MinimumLength = 2)]
        public string Query { get; set; } = string.Empty;

        public string Type { get; set; } = "all";
        public int? ConversationId { get; set; }
        public int? DepartmentId { get; set; }
        public int Page { get; set; } = 1;
        public int PageSize { get; set; } = 25;
    }

    public sealed class ChatSearchResultViewModel
    {
        public int MessageId { get; set; }
        public string OriginType { get; set; } = string.Empty;
        public int? ConversationId { get; set; }
        public int? DepartmentId { get; set; }
        public string OriginName { get; set; } = string.Empty;
        public int SenderId { get; set; }
        public string SenderName { get; set; } = string.Empty;
        public string Content { get; set; } = string.Empty;
        public DateTime SentAt { get; set; }
        public int TotalResults { get; set; }
    }

    public sealed class ChatDepartmentAdminViewModel
    {
        public int DepartmentId { get; set; }
        public string Name { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;
        public bool Active { get; set; }
        public int MemberCount { get; set; }
        public List<ChatDepartmentMemberViewModel> Members { get; set; } = new();
    }

    public sealed class ChatDepartmentMemberViewModel
    {
        public int UserId { get; set; }
        public string FullName { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public bool CanPost { get; set; }
    }

    public sealed class ChatDepartmentFormViewModel
    {
        public int DepartmentId { get; set; }

        [Required]
        [StringLength(120, MinimumLength = 2)]
        public string Name { get; set; } = string.Empty;

        [StringLength(300)]
        public string? Description { get; set; }

        public bool Active { get; set; } = true;
    }
}
