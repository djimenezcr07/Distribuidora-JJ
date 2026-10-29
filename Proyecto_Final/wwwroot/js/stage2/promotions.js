(() => {
  "use strict";
  const type = document.getElementById("promoTipo");
  if (!type) return;
  const toggle = () => {
    const isDiscount = type.value === "DescuentoPorcentual";
    document.querySelectorAll(".promo-descuento").forEach(element => { element.hidden = !isDiscount; });
    document.querySelectorAll(".promo-regalia").forEach(element => { element.hidden = isDiscount; });
  };
  type.addEventListener("change", toggle);
  toggle();
})();
