using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Proyecto_Final.Services;

namespace Proyecto_Final.Controllers;

[AllowAnonymous]
[Route("product-images")]
public sealed class ProductImagesController : Controller
{
    private readonly IProductImageStorageService _storage;
    public ProductImagesController(IProductImageStorageService storage)=>_storage=storage;

    [HttpGet("{fileName}")]
    [ResponseCache(Duration=86400,Location=ResponseCacheLocation.Client)]
    public async Task<IActionResult> Get(string fileName,CancellationToken cancellationToken)
    {
        var image=await _storage.OpenReadAsync(fileName,cancellationToken);
        return image is null?NotFound():File(image.Content,image.ContentType,enableRangeProcessing:true);
    }
}
