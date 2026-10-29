using Microsoft.AspNetCore.Mvc.ModelBinding;
using System.Globalization;

namespace Proyecto_Final.ModelBinders;

public sealed class FlexibleDecimalModelBinder : IModelBinder
{
    public Task BindModelAsync(ModelBindingContext bindingContext)
    {
        ArgumentNullException.ThrowIfNull(bindingContext);

        var valueResult = bindingContext.ValueProvider
            .GetValue(bindingContext.ModelName);

        if (valueResult == ValueProviderResult.None)
        {
            return Task.CompletedTask;
        }

        bindingContext.ModelState.SetModelValue(
            bindingContext.ModelName,
            valueResult
        );

        var rawValue = valueResult.FirstValue;

        if (string.IsNullOrWhiteSpace(rawValue))
        {
            if (Nullable.GetUnderlyingType(bindingContext.ModelType) is not null)
            {
                bindingContext.Result = ModelBindingResult.Success(null);
                return Task.CompletedTask;
            }

            bindingContext.ModelState.TryAddModelError(
                bindingContext.ModelName,
                "El valor es obligatorio."
            );

            return Task.CompletedTask;
        }

        // Acepta tanto 0.5 como 0,5.
        var normalizedValue = rawValue
            .Trim()
            .Replace(',', '.');

        var validStyles =
            NumberStyles.AllowLeadingSign |
            NumberStyles.AllowDecimalPoint;

        if (decimal.TryParse(
            normalizedValue,
            validStyles,
            CultureInfo.InvariantCulture,
            out var parsedValue))
        {
            bindingContext.Result =
                ModelBindingResult.Success(parsedValue);

            return Task.CompletedTask;
        }

        bindingContext.ModelState.TryAddModelError(
            bindingContext.ModelName,
            $"El valor '{rawValue}' no es un número decimal válido."
        );

        return Task.CompletedTask;
    }
}
