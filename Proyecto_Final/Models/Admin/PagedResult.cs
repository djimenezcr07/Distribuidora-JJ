namespace Proyecto_Final.Models.Admin;

public sealed class PagedResult<T>
{
    public IReadOnlyList<T> Items { get; init; } = Array.Empty<T>();
    public int Page { get; init; } = 1;
    public int PageSize { get; init; } = 20;
    public int Total { get; init; }
    public int TotalPages => Math.Max(1, (int)Math.Ceiling(Total / (double)Math.Max(PageSize, 1)));
}
