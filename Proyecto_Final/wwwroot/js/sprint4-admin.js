(function () {
    "use strict";

    document.addEventListener("submit", function (event) {
        var form = event.target.closest("form");
        if (!form) return;
        var message = form.getAttribute("data-confirm");
        if (!message && /\/(Cancel|SetActive|ToggleStatus|Approve|Reject|Pay|Close|Submit)(?:\?|$)/i.test(form.action)) {
            message = "¿Confirma que desea ejecutar esta acción? El cambio quedará auditado.";
        }
        if (message && !window.confirm(message)) event.preventDefault();
    });

    document.addEventListener("change", function (event) {
        var input = event.target.closest("input[type='file'][data-file-label]");
        if (!input) return;
        var label = document.getElementById(input.getAttribute("data-file-label"));
        if (!label) return;
        var file = input.files && input.files.length ? input.files[0] : null;
        label.textContent = file
            ? file.name + " · " + Math.max(1, Math.round(file.size / 1024)) + " KB"
            : "Ningún archivo seleccionado";
    });

    function updateExpenseTotal(input) {
        var form = input.closest("form");
        if (!form) return;
        var fields = form.querySelectorAll("[data-expense-money]");
        var output = form.querySelector("[data-expense-total]");
        if (!output) return;
        var total = 0;
        fields.forEach(function (field) {
            var value = Number.parseFloat(field.value);
            if (Number.isFinite(value) && value > 0) total += value;
        });
        output.textContent = new Intl.NumberFormat("es-CR", { style: "currency", currency: "CRC" }).format(total);
    }

    document.addEventListener("input", function (event) {
        var input = event.target.closest("[data-expense-money]");
        if (input) updateExpenseTotal(input);
    });
})();
