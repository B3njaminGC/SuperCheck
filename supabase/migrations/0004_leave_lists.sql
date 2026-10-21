-- =====================================================================
-- SuperCheck - 0004: salir de una lista / quitar a un miembro
-- Ejecutar DESPUÉS de 0001, 0002 y 0003.
--
-- Reemplaza la política de 0001 para que nunca se pueda borrar la fila del
-- dueño (la lista quedaría huérfana): el dueño finaliza o borra la lista.
--   * cualquier miembro puede salir (borrar su propia fila)
--   * el dueño puede quitar a otros miembros
-- =====================================================================

drop policy "members_delete_self_or_owner" on public.list_members;

create policy "members_delete_self_or_owner"
  on public.list_members for delete
  to authenticated
  using (
    role <> 'owner'
    and (
      user_id = auth.uid()
      or exists (
        select 1 from public.lists l
        where l.id = list_members.list_id and l.owner_id = auth.uid()
      )
    )
  );
