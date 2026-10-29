using System.Net;

namespace Proyecto_FinalAPI.Services
{
    public static class EmailTemplateBuilder
    {
        public static string BuildPasswordResetEmail(string nombreCompleto, string resetUrl, CompanyOptions company)
        {
            var nombreSeguro = Encode(nombreCompleto, "Cliente");
            var resetUrlSeguro = WebUtility.HtmlEncode(resetUrl ?? string.Empty);

            var contenido = $@"
                <p style='margin:0 0 16px;color:#374151;font-size:15px;line-height:1.7;'>
                    Hola <strong>{nombreSeguro}</strong>, recibimos una solicitud para restablecer la contraseña de tu cuenta.
                </p>
                <p style='margin:0 0 20px;color:#374151;font-size:15px;line-height:1.7;'>
                    Para continuar, presioná el siguiente botón. Por seguridad, este enlace vence en <strong>30 minutos</strong>.
                </p>
                <div style='margin:26px 0;text-align:center;'>
                    <a href='{resetUrlSeguro}' style='display:inline-block;background:#d4af37;color:#111827;text-decoration:none;font-weight:800;padding:14px 24px;border-radius:14px;font-size:15px;'>
                        Restablecer contraseña
                    </a>
                </div>
                <p style='margin:18px 0 0;color:#6b7280;font-size:13px;line-height:1.6;'>
                    Si no solicitaste este cambio, podés ignorar este correo. Tu contraseña actual seguirá funcionando.
                </p>";

            return BuildBaseTemplate(
                titulo: "Recuperación de contraseña",
                subtitulo: "Solicitud de seguridad de cuenta",
                badge: "Seguridad",
                contenido: contenido,
                notaInferior: $"Este mensaje fue generado automáticamente por el sistema de {company.BrandName}.",
                company: company);
        }

        public static string BuildContactNotificationEmail(string nombre, string correo, string asunto, string mensaje, CompanyOptions company)
        {
            var nombreSeguro = Encode(nombre, "No indicado");
            var correoSeguro = Encode(correo, "No indicado");
            var asuntoSeguro = Encode(asunto, "Consulta web");
            var mensajeSeguro = WebUtility.HtmlEncode(mensaje ?? string.Empty).Replace("\n", "<br />");

            var contenido = $@"
                <p style='margin:0 0 18px;color:#374151;font-size:15px;line-height:1.7;'>
                    Se recibió una nueva consulta desde el formulario de contacto del sitio web.
                </p>

                <table role='presentation' width='100%' cellspacing='0' cellpadding='0' style='border-collapse:collapse;margin:0 0 20px;'>
                    <tr>
                        <td style='padding:12px 14px;background:#fbfaf7;border:1px solid #ebe6dc;border-radius:14px;'>
                            <p style='margin:0 0 6px;color:#6b7280;font-size:12px;font-weight:800;text-transform:uppercase;letter-spacing:.04em;'>Nombre</p>
                            <p style='margin:0;color:#111827;font-size:15px;font-weight:700;'>{nombreSeguro}</p>
                        </td>
                    </tr>
                </table>

                <table role='presentation' width='100%' cellspacing='0' cellpadding='0' style='border-collapse:collapse;margin:0 0 20px;'>
                    <tr>
                        <td style='padding:12px 14px;background:#fbfaf7;border:1px solid #ebe6dc;border-radius:14px;'>
                            <p style='margin:0 0 6px;color:#6b7280;font-size:12px;font-weight:800;text-transform:uppercase;letter-spacing:.04em;'>Correo</p>
                            <p style='margin:0;color:#111827;font-size:15px;font-weight:700;'>{correoSeguro}</p>
                        </td>
                    </tr>
                </table>

                <table role='presentation' width='100%' cellspacing='0' cellpadding='0' style='border-collapse:collapse;margin:0 0 20px;'>
                    <tr>
                        <td style='padding:12px 14px;background:#fbfaf7;border:1px solid #ebe6dc;border-radius:14px;'>
                            <p style='margin:0 0 6px;color:#6b7280;font-size:12px;font-weight:800;text-transform:uppercase;letter-spacing:.04em;'>Asunto</p>
                            <p style='margin:0;color:#111827;font-size:15px;font-weight:700;'>{asuntoSeguro}</p>
                        </td>
                    </tr>
                </table>

                <div style='padding:16px 18px;background:#ffffff;border:1px solid #ebe6dc;border-radius:16px;'>
                    <p style='margin:0 0 8px;color:#6b7280;font-size:12px;font-weight:800;text-transform:uppercase;letter-spacing:.04em;'>Mensaje</p>
                    <p style='margin:0;color:#374151;font-size:15px;line-height:1.7;'>{mensajeSeguro}</p>
                </div>";

            return BuildBaseTemplate(
                titulo: "Nueva consulta web",
                subtitulo: asuntoSeguro,
                badge: "Contacto",
                contenido: contenido,
                notaInferior: "Recordá revisar el módulo de Consultas para darle seguimiento administrativo.",
                company: company);
        }

        private static string BuildBaseTemplate(string titulo, string subtitulo, string badge, string contenido, string notaInferior, CompanyOptions company)
        {
            ArgumentNullException.ThrowIfNull(company);
            var marcaSegura = Encode(company.BrandName, string.Empty);
            var subtituloMarcaSeguro = Encode(company.BrandSubtitle, string.Empty);
            var tituloSeguro = Encode(titulo, company.BrandName);
            var subtituloSeguro = Encode(subtitulo, "Notificación del sistema");
            var badgeSeguro = Encode(badge, "Sistema");
            var notaSeguro = Encode(notaInferior, string.Empty);

            return $@"<!DOCTYPE html>
<html lang='es'>
<head>
    <meta charset='utf-8' />
    <meta name='viewport' content='width=device-width, initial-scale=1.0' />
    <title>{tituloSeguro}</title>
</head>
<body style='margin:0;padding:0;background:#f4f1ea;font-family:Arial,Helvetica,sans-serif;color:#111827;'>
    <table role='presentation' width='100%' cellspacing='0' cellpadding='0' style='border-collapse:collapse;background:#f4f1ea;padding:0;margin:0;'>
        <tr>
            <td align='center' style='padding:32px 14px;'>
                <table role='presentation' width='100%' cellspacing='0' cellpadding='0' style='border-collapse:collapse;max-width:640px;background:#ffffff;border-radius:24px;overflow:hidden;box-shadow:0 18px 44px rgba(17,24,39,.12);'>
                    <tr>
                        <td style='background:#111114;background-image:linear-gradient(135deg,#111114 0%,#222227 70%,#111114 100%);padding:30px 32px;color:#ffffff;'>
                            <div style='display:inline-block;background:rgba(212,175,55,.16);color:#f0cf66;border:1px solid rgba(212,175,55,.32);border-radius:999px;padding:7px 12px;font-size:12px;font-weight:800;text-transform:uppercase;letter-spacing:.06em;margin-bottom:16px;'>
                                {badgeSeguro}
                            </div>
                            <h1 style='margin:0 0 8px;color:#ffffff;font-size:28px;line-height:1.15;font-weight:900;'>
                                {tituloSeguro}
                            </h1>
                            <p style='margin:0;color:rgba(255,255,255,.72);font-size:15px;line-height:1.6;'>
                                {subtituloSeguro}
                            </p>
                        </td>
                    </tr>
                    <tr>
                        <td style='padding:30px 32px;'>
                            {contenido}
                        </td>
                    </tr>
                    <tr>
                        <td style='padding:0 32px 30px;'>
                            <div style='background:#fbfaf7;border:1px solid #ebe6dc;border-radius:16px;padding:14px 16px;color:#6b7280;font-size:13px;line-height:1.6;'>
                                {notaSeguro}
                            </div>
                        </td>
                    </tr>
                    <tr>
                        <td style='background:#111114;padding:20px 32px;text-align:center;'>
                            <p style='margin:0 0 6px;color:#ffffff;font-size:14px;font-weight:800;'>{marcaSegura}</p>
                            <p style='margin:0;color:rgba(255,255,255,.62);font-size:12px;line-height:1.6;'>
                                {subtituloMarcaSeguro} · Sistema de gestión comercial · Costa Rica
                            </p>
                        </td>
                    </tr>
                </table>
            </td>
        </tr>
    </table>
</body>
</html>";
        }

        private static string Encode(string? value, string fallback)
        {
            return WebUtility.HtmlEncode(string.IsNullOrWhiteSpace(value) ? fallback : value.Trim());
        }
    }
}
