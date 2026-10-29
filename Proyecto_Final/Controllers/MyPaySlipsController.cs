using Microsoft.AspNetCore.Mvc;
using Proyecto_Final.Filters;
using Proyecto_Final.Services;
using System.Text;

namespace Proyecto_Final.Controllers;

[SessionAuthorize]
[EmployeeRelationshipAuthorize]
public sealed class MyPaySlipsController : Controller
{
    private readonly IPaySlipService _service;
    public MyPaySlipsController(IPaySlipService service)=>_service=service;

    [HttpGet]
    public async Task<IActionResult> Index(CancellationToken cancellationToken)=>View(await _service.ListAsync(UserId(),false,cancellationToken));

    [HttpGet]
    public async Task<IActionResult> Details(long id,CancellationToken cancellationToken)
    {
        var model=await _service.GetAsync(id,UserId(),false,cancellationToken);
        return model is null?NotFound():View(model);
    }

    [HttpGet]
    public async Task<IActionResult> Download(long id,CancellationToken cancellationToken)
    {
        var model=await _service.GetAsync(id,UserId(),false,cancellationToken);
        if(model is null)return NotFound();
        return File(Encoding.UTF8.GetBytes(PaySlipHtmlBuilder.Build(model)),"text/html",$"mi-boleta-{id}.html");
    }

    private int UserId()=>HttpContext.Session.GetInt32("UserId")??0;
}
