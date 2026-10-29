using System.Text.Json;
using Proyecto_Final.Models.Store;

namespace Proyecto_Final.Services;

public static class StoreCheckoutPayloadBuilder
{
    public static string CreateItemsJson(IEnumerable<CartItemViewModel> items)
    {
        ArgumentNullException.ThrowIfNull(items);

        var payload = items.Select(item => new
        {
            tipo = item.ItemType,
            productoId = item.ItemType == CartItemTypes.Product ? item.ProductoId : (int?)null,
            comboId = item.ItemType == CartItemTypes.Combo ? item.ComboId : null,
            cantidad = item.Cantidad
        });

        return JsonSerializer.Serialize(payload);
    }
}
