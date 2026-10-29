using System.ComponentModel.DataAnnotations;

namespace Proyecto_Final.Models.Admin;

public sealed class SelectOptionViewModel
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
}

public sealed class DocumentFilterViewModel
{
    public string? Search { get; set; }
    public int? TypeId { get; set; }
    public int? DepartmentId { get; set; }
    public string? Status { get; set; }
    public string? Expiration { get; set; }
    public int Page { get; set; } = 1;
    public int PageSize { get; set; } = 20;
}

public sealed class DocumentListItemViewModel
{
    public int DocumentId { get; set; }
    public string TypeName { get; set; } = string.Empty;
    public string? DepartmentName { get; set; }
    public string Title { get; set; } = string.Empty;
    public string? ReferenceNumber { get; set; }
    public DateTime? IssueDate { get; set; }
    public DateTime? ExpirationDate { get; set; }
    public bool DoesNotExpire { get; set; }
    public string Status { get; set; } = string.Empty;
    public bool Active { get; set; }
    public int Version { get; set; }
    public DateTime UpdatedUtc { get; set; }
    public string ExpirationStatus { get; set; } = string.Empty;
    public int? DaysToExpiration { get; set; }
}

public sealed class DocumentVersionViewModel
{
    public int VersionId { get; set; }
    public int Version { get; set; }
    public string OriginalName { get; set; } = string.Empty;
    public string MimeType { get; set; } = string.Empty;
    public long SizeBytes { get; set; }
    public string Sha256 { get; set; } = string.Empty;
    public string StorageStatus { get; set; } = string.Empty;
    public int CreatedByUserId { get; set; }
    public string CreatedByName { get; set; } = string.Empty;
    public DateTime CreatedUtc { get; set; }
}

public sealed class DocumentDetailsViewModel
{
    public DocumentListItemViewModel Document { get; set; } = new();
    public string? Description { get; set; }
    public string OriginalName { get; set; } = string.Empty;
    public string MimeType { get; set; } = string.Empty;
    public long SizeBytes { get; set; }
    public string Sha256 { get; set; } = string.Empty;
    public string CreatedByName { get; set; } = string.Empty;
    public DateTime CreatedUtc { get; set; }
    public IReadOnlyList<DocumentVersionViewModel> Versions { get; set; } = Array.Empty<DocumentVersionViewModel>();
}

public sealed class DocumentFormViewModel
{
    public int DocumentId { get; set; }

    [Range(1, int.MaxValue, ErrorMessage = "Seleccione un tipo de documento.")]
    public int TypeId { get; set; }

    public int? DepartmentId { get; set; }

    [Required(ErrorMessage = "El título es obligatorio.")]
    [StringLength(180)]
    public string Title { get; set; } = string.Empty;

    [StringLength(1000)]
    public string? Description { get; set; }

    [StringLength(100)]
    public string? ReferenceNumber { get; set; }

    [DataType(DataType.Date)]
    public DateTime? IssueDate { get; set; }

    [DataType(DataType.Date)]
    public DateTime? ExpirationDate { get; set; }

    public bool DoesNotExpire { get; set; }

    [Required]
    [StringLength(30)]
    public string Status { get; set; } = "Vigente";

    public IFormFile? File { get; set; }
}

public sealed class DocumentIndexViewModel
{
    public DocumentFilterViewModel Filter { get; set; } = new();
    public PagedResult<DocumentListItemViewModel> Documents { get; set; } = new();
    public IReadOnlyList<SelectOptionViewModel> Types { get; set; } = Array.Empty<SelectOptionViewModel>();
    public IReadOnlyList<SelectOptionViewModel> Departments { get; set; } = Array.Empty<SelectOptionViewModel>();
    public int CurrentCount { get; set; }
    public int WarningCount { get; set; }
    public int ExpiredCount { get; set; }
    public int NoExpirationCount { get; set; }
}

public sealed class DocumentAlertFilterViewModel
{
    public string? Status { get; set; }
    public int? DepartmentId { get; set; }
    public int? MaxDays { get; set; }
    public int Page { get; set; } = 1;
    public int PageSize { get; set; } = 20;
}

public sealed class DocumentAlertViewModel
{
    public int AlertId { get; set; }
    public int DocumentId { get; set; }
    public string DocumentTitle { get; set; } = string.Empty;
    public string TypeName { get; set; } = string.Empty;
    public string? DepartmentName { get; set; }
    public string ResponsibleName { get; set; } = string.Empty;
    public DateTime ExpirationDate { get; set; }
    public int DaysRemaining { get; set; }
    public string ExpirationStatus { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;
    public DateTime CreatedUtc { get; set; }
}

public sealed class DocumentAlertsIndexViewModel
{
    public DocumentAlertFilterViewModel Filter { get; set; } = new();
    public PagedResult<DocumentAlertViewModel> Alerts { get; set; } = new();
    public IReadOnlyList<SelectOptionViewModel> Departments { get; set; } = Array.Empty<SelectOptionViewModel>();
    public int ActiveCount { get; set; }
    public int ExpiredCount { get; set; }
}

public sealed class PrivateFileMetadata
{
    public int OwnerId { get; set; }
    public int? VersionId { get; set; }
    public string StorageArea { get; set; } = string.Empty;
    public string StorageKey { get; set; } = string.Empty;
    public string OriginalName { get; set; } = string.Empty;
    public string MimeType { get; set; } = string.Empty;
}

public sealed class DocumentAlertNotificationCandidate
{
    public int AlertId { get; set; }
    public int DocumentId { get; set; }
    public int ThresholdDays { get; set; }
    public string DocumentTitle { get; set; } = string.Empty;
    public DateTime ExpirationDate { get; set; }
    public string Recipient { get; set; } = string.Empty;
}
