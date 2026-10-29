(function () {
    "use strict";
    document.querySelectorAll(".sig-form").forEach(function (form) {
        var canvas = form.querySelector(".sig-canvas");
        var data = form.querySelector(".sig-data");
        if (!canvas || !data) return;
        var context = canvas.getContext("2d");
        if (!context) return;
        var drawing = false, dirty = false;
        context.lineWidth = 2;
        context.lineCap = "round";
        context.strokeStyle = getComputedStyle(document.documentElement).getPropertyValue("--djj-color-text").trim();
        function position(event) {
            var rect = canvas.getBoundingClientRect();
            return { x: (event.clientX - rect.left) * canvas.width / rect.width, y: (event.clientY - rect.top) * canvas.height / rect.height };
        }
        canvas.addEventListener("pointerdown", function (event) {
            if (event.button !== 0) return;
            drawing = true;
            dirty = true;
            var point = position(event);
            context.beginPath();
            context.moveTo(point.x, point.y);
            canvas.setPointerCapture?.(event.pointerId);
            event.preventDefault();
        });
        canvas.addEventListener("pointermove", function (event) {
            if (!drawing) return;
            var point = position(event);
            context.lineTo(point.x, point.y);
            context.stroke();
            event.preventDefault();
        });
        ["pointerup", "pointercancel", "lostpointercapture"].forEach(function (name) {
            canvas.addEventListener(name, function () { drawing = false; });
        });
        form.querySelector(".sig-clear")?.addEventListener("click", function () {
            context.clearRect(0, 0, canvas.width, canvas.height);
            dirty = false;
            data.value = "";
        });
        form.addEventListener("submit", function (event) {
            if (!dirty) {
                event.preventDefault();
                canvas.focus();
                var toast = document.getElementById("driverToast");
                if (toast) { toast.textContent = "Capture la firma antes de guardar."; toast.hidden = false; }
                return;
            }
            data.value = canvas.toDataURL("image/png");
        });
    });
})();
