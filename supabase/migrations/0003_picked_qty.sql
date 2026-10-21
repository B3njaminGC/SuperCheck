-- =====================================================================
-- SuperCheck - 0003: conteo de unidades
-- Ejecutar DESPUÉS de 0001_init.sql y 0002_history.sql
--
-- Hasta ahora un ítem estaba tachado o no. Con picked_qty se cuenta cuántas
-- unidades ya están en el carrito: pedir 3 y escanear una deja "1 de 3", y el
-- ítem se tacha recién al llegar a 3. is_checked sigue guardándose (es lo que
-- ordena y filtra la lista) y vale true cuando picked_qty >= desired_qty.
-- =====================================================================

alter table public.list_items
  add column picked_qty integer not null default 0
    check (picked_qty >= 0);

-- Lo que ya estaba tachado cuenta como completo.
update public.list_items
   set picked_qty = desired_qty
 where is_checked;
