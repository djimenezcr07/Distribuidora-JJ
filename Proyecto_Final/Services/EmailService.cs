using System.Net;
using System.Net.Mail;
using System.Text;
using Proyecto_Final.Models.Store;

using System.Globalization;
using Microsoft.Extensions.Options;

namespace Proyecto_Final.Services
{
    public class EmailService
    {
        private readonly IConfiguration _configuration;
        private readonly CompanyOptions _company;
        private readonly BusinessClock _clock;

        public EmailService(IConfiguration configuration, IOptions<CompanyOptions> company, BusinessClock clock)
        {
            _configuration = configuration;
            _company = company.Value;
            _clock = clock;
        }

        public void SendEmail(string destinatario, string asunto, string contenido)
        {
            var host = _configuration.GetValue<string>("ConfiguracionCorreo:Host") ?? string.Empty;
            var puerto = _configuration.GetValue<int>("ConfiguracionCorreo:Puerto");
            var remitente = _configuration.GetValue<string>("ConfiguracionCorreo:Remitente") ?? string.Empty;
            var contrasenna = _configuration.GetValue<string>("ConfiguracionCorreo:Contrasenna") ?? string.Empty;

            if (string.IsNullOrWhiteSpace(host))
                throw new InvalidOperationException("El host del correo no esta configurado.");

            if (puerto <= 0)
                throw new InvalidOperationException("El puerto del correo no es valido.");

            if (string.IsNullOrWhiteSpace(remitente))
                throw new InvalidOperationException("El remitente del correo no esta configurado.");

            if (string.IsNullOrWhiteSpace(contrasenna))
                throw new InvalidOperationException("La contrasenna del correo no esta configurada.");

            using var mensaje = new MailMessage(remitente, destinatario, asunto, contenido)
            {
                IsBodyHtml = true
            };

            using var smtp = new SmtpClient(host, puerto)
            {
                Credentials = new NetworkCredential(remitente, contrasenna),
                EnableSsl = true
            };

            smtp.Send(mensaje);
        }

        public void SendOrderReceipt(
            string destinatario,
            string cliente,
            int pedidoId,
            CheckoutViewModel checkout,
            IReadOnlyCollection<CartItemViewModel> items,
            decimal totalConfirmado,
            decimal descuentoTotal)
        {
            var rutaPlantilla = Path.Combine(
                Directory.GetCurrentDirectory(),
                "EmailTemplates",
                "OrderReceipt.html");

            if (!File.Exists(rutaPlantilla))
            {
                throw new FileNotFoundException(
                    "No se encontró la plantilla del correo.",
                    rutaPlantilla);
            }

            var html = OrderReceiptHtmlBuilder.Build(
                File.ReadAllText(rutaPlantilla),
                cliente,
                pedidoId,
                checkout,
                items,
                totalConfirmado,
                descuentoTotal,
                _clock.LocalNow,
                _company);

            SendEmail(
                destinatario,
                $"Confirmación del pedido #{pedidoId}",
                html);
        }
    }

    public static class OrderReceiptHtmlBuilder
    {
        private static readonly CultureInfo CostaRicaCulture = CultureInfo.GetCultureInfo("es-CR");

        public static string Build(
            string template,
            string cliente,
            int pedidoId,
            CheckoutViewModel checkout,
            IEnumerable<CartItemViewModel> items,
            decimal totalConfirmado,
            decimal descuentoTotal,
            DateTime fecha,
            CompanyOptions company)
        {
            ArgumentException.ThrowIfNullOrWhiteSpace(template);
            ArgumentNullException.ThrowIfNull(checkout);
            ArgumentNullException.ThrowIfNull(items);
            ArgumentNullException.ThrowIfNull(company);
            if (pedidoId <= 0 || totalConfirmado < 0 || descuentoTotal < 0)
            {
                throw new ArgumentOutOfRangeException(nameof(totalConfirmado), "Los importes confirmados del pedido no son válidos.");
            }

            var orderItems = items.ToList();
            var products = new StringBuilder();
            foreach (var item in orderItems)
            {
                var lineDiscount = item.EsRegalo ? 0m : item.MontoDescuento;
                var lineTotal = item.EsRegalo ? 0m : item.SubtotalConDescuento;
                var displayedUnitPrice = item.EsRegalo || item.Cantidad <= 0
                    ? 0m
                    : item.Subtotal / item.Cantidad;
                var giftPromotion = string.IsNullOrWhiteSpace(item.PromocionNombre)
                    ? string.Empty
                    : $" · {item.PromocionNombre}";
                var description = item.EsRegalo
                    ? $"Regalo{giftPromotion}"
                    : lineDiscount > 0 ? $"Descuento: -{FormatCurrency(lineDiscount)}" : string.Empty;
                var name = item.ItemType == CartItemTypes.Combo ? $"Combo: {item.Nombre}" : item.Nombre;

                products.Append($"""
<tr style="border-bottom:1px solid #eeeeee">
    <td class="product" style="padding:14px">{Encode(name)}{(string.IsNullOrEmpty(description) ? string.Empty : $"<br/><small>{Encode(description)}</small>")}</td>
    <td class="qty" align="center" style="padding:14px">{item.Cantidad}</td>
    <td class="price" align="right" style="padding:14px">{FormatCurrency(displayedUnitPrice)}</td>
    <td class="subtotal" align="right" style="padding:14px">{FormatCurrency(lineTotal)}</td>
</tr>
""");
            }

            var subtotal = orderItems.Where(item => !item.EsRegalo).Sum(item => item.Subtotal);
            var discountSummary = descuentoTotal > 0
                ? $"<tr><td>Descuentos</td><td align=\"right\">-{FormatCurrency(descuentoTotal)}</td></tr>"
                : string.Empty;

            return template
                .Replace("{{BRAND_NAME}}", Encode(company.BrandName))
                .Replace("{{BRAND_SUBTITLE}}", Encode(company.BrandSubtitle))
                .Replace("{{CLIENTE}}", Encode(cliente))
                .Replace("{{PEDIDO}}", Encode("#" + pedidoId))
                .Replace("{{FECHA}}", Encode(fecha.ToString("dd/MM/yyyy HH:mm", CostaRicaCulture)))
                .Replace("{{METODO_PAGO}}", Encode(checkout.MetodoPago))
                .Replace("{{TIPO_ENTREGA}}", Encode(checkout.TipoEntrega))
                .Replace("{{DIRECCION}}", Encode(checkout.DireccionEntrega))
                .Replace("{{PRODUCTOS}}", products.ToString())
                .Replace("{{SUBTOTAL}}", FormatCurrency(subtotal))
                .Replace("{{DESCUENTO}}", discountSummary)
                .Replace("{{ENVIO}}", FormatCurrency(0m))
                .Replace("{{TOTAL}}", FormatCurrency(totalConfirmado))
                .Replace("{{LINK_PEDIDO}}", "#");
        }

        public static string FormatCurrency(decimal value) => $"₡{value.ToString("N2", CostaRicaCulture)}";

        private static string Encode(string? value) => WebUtility.HtmlEncode(value ?? string.Empty);
    }
}
