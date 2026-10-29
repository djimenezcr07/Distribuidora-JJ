using Microsoft.AspNetCore.Mvc;
using Moq;
using Proyecto_Final.Controllers;
using Proyecto_Final.Filters;
using Proyecto_Final.Models.Admin;
using Proyecto_Final.Services;

namespace Proyecto_Final.Tests;

public sealed class PaySlipSecurityAndDeliveryTests
{
    [Fact]
    public void ManagementController_RequiresExactPermission()
    {
        var attribute=Assert.IsType<AdminAuthorizeAttribute>(Assert.Single(typeof(PaySlipsController).GetCustomAttributes(typeof(AdminAuthorizeAttribute),true)));
        Assert.Equal("PLANILLA_BOLETAS_GESTIONAR",attribute.Arguments![1]);
        var send=typeof(PaySlipsController).GetMethod("Send")!;
        Assert.NotEmpty(send.GetCustomAttributes(typeof(HttpPostAttribute),true));
        Assert.NotEmpty(send.GetCustomAttributes(typeof(ValidateAntiForgeryTokenAttribute),true));
    }

    [Fact]
    public void EmployeeController_RequiresAuthenticatedSession()
        =>Assert.IsType<SessionAuthorizeAttribute>(Assert.Single(typeof(MyPaySlipsController).GetCustomAttributes(typeof(SessionAuthorizeAttribute),true)));

    [Fact]
    public async Task Coordinator_UsesFakeSmtpAndCompletesDelivery()
    {
        var repository=new Mock<IPaySlipService>();
        repository.Setup(item=>item.PrepareDeliveryAsync(7,It.IsAny<Guid>(),3,"Gestor",It.IsAny<CancellationToken>()))
            .ReturnsAsync(new PaySlipDeliveryPreparation(11,"employee@example.invalid","Empleado",true));
        var sender=new FakePaySlipEmailSender();
        var coordinator=new PaySlipDeliveryCoordinator(repository.Object,sender);

        await coordinator.SendAsync(7,Guid.NewGuid(),3,"Gestor",new Uri("https://portal.example.invalid/MyPaySlips/Details/7"),CancellationToken.None);

        Assert.Equal("employee@example.invalid",sender.Recipient);
        Assert.Equal("https",sender.Link!.Scheme);
        repository.Verify(item=>item.CompleteDeliveryAsync(11,true,null,3,"Gestor",It.IsAny<CancellationToken>()),Times.Once);
    }

    [Fact]
    public async Task Coordinator_RecordsFailureWithoutChangingPayroll()
    {
        var repository=new Mock<IPaySlipService>();
        repository.Setup(item=>item.PrepareDeliveryAsync(It.IsAny<long>(),It.IsAny<Guid>(),It.IsAny<int>(),It.IsAny<string>(),It.IsAny<CancellationToken>()))
            .ReturnsAsync(new PaySlipDeliveryPreparation(12,"employee@example.invalid","Empleado",true));
        var coordinator=new PaySlipDeliveryCoordinator(repository.Object,new FakePaySlipEmailSender{Failure=new InvalidOperationException("SMTP synthetic failure")});

        await Assert.ThrowsAsync<InvalidOperationException>(()=>coordinator.SendAsync(8,Guid.NewGuid(),3,"Gestor",new Uri("https://portal.example.invalid/MyPaySlips/Details/8"),CancellationToken.None));

        repository.Verify(item=>item.CompleteDeliveryAsync(12,false,"SMTP_DELIVERY_FAILED",3,"Gestor",It.IsAny<CancellationToken>()),Times.Once);
    }

    [Fact]
    public void DownloadBuilder_EncodesUserControlledText()
    {
        var html=PaySlipHtmlBuilder.Build(new PaySlipViewModel{CalculoId=1,Empleado="<script>alert(1)</script>",Periodo="2026-08",Lineas=[new(){Codigo="X",Nombre="<b>unsafe</b>",Tipo="Ingreso",Monto=1}]});
        Assert.DoesNotContain("<script>",html);
        Assert.DoesNotContain("<b>unsafe</b>",html);
        Assert.Contains("&lt;script&gt;",html);
    }

    private sealed class FakePaySlipEmailSender:IPaySlipEmailSender
    {
        public string? Recipient{get;private set;}
        public Uri? Link{get;private set;}
        public Exception? Failure{get;init;}
        public Task SendLinkAsync(string recipient,string employee,Uri secureLink,CancellationToken cancellationToken)
        {
            if(Failure is not null)throw Failure;
            Recipient=recipient;Link=secureLink;return Task.CompletedTask;
        }
    }
}
