-- =====================================================================
-- SuperCheck - 0002: historial de listas
-- Ejecutar DESPUÉS de 0001_init.sql
--
-- Una lista pasa de 'active' a 'completed' cuando alguien la finaliza.
-- Las listas completadas quedan guardadas (solo lectura) y se pueden:
--   * reutilizar  -> duplicate_list(): crea una lista nueva con los mismos
--                    productos y cantidades, todos sin tachar
--   * reabrir     -> reopen_list()
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) Estado de la lista
-- ---------------------------------------------------------------------
alter table public.lists
  add column status       text not null default 'active'
    check (status in ('active', 'completed')),
  add column completed_at timestamptz,
  add column completed_by uuid references public.profiles (id) on delete set null;

alter table public.lists
  add constraint lists_completed_consistency
  check ((status = 'completed') = (completed_at is not null));

create index lists_status_idx on public.lists (status, completed_at desc);

-- ---------------------------------------------------------------------
-- 2) Corrección a 0001: generate_invite_code corría con los permisos de quien
--    inserta, y por RLS solo "veía" sus propias listas, así que no detectaba
--    códigos repetidos de otras personas. Con security definer ve todas.
-- ---------------------------------------------------------------------
create or replace function public.generate_invite_code()
returns text
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  code text;
  i int;
begin
  loop
    code := '';
    for i in 1..8 loop
      code := code || substr(
        alphabet,
        1 + (get_byte(extensions.gen_random_bytes(1), 0) % 32),
        1
      );
    end loop;
    exit when not exists (select 1 from public.lists where invite_code = code);
  end loop;
  return code;
end;
$$;

-- ---------------------------------------------------------------------
-- 3) Una lista finalizada es de solo lectura: no se pueden agregar,
--    tachar ni borrar ítems hasta reabrirla.
-- ---------------------------------------------------------------------
create or replace function public.is_list_active(p_list_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.lists
    where id = p_list_id and status = 'active'
  );
$$;

drop policy "items_insert_member" on public.list_items;
drop policy "items_update_member" on public.list_items;
drop policy "items_delete_member" on public.list_items;

create policy "items_insert_member_active"
  on public.list_items for insert
  to authenticated
  with check (
    public.is_list_member(list_id)
    and public.is_list_active(list_id)
    and added_by = auth.uid()
  );

create policy "items_update_member_active"
  on public.list_items for update
  to authenticated
  using (public.is_list_member(list_id) and public.is_list_active(list_id))
  with check (public.is_list_member(list_id) and public.is_list_active(list_id));

create policy "items_delete_member_active"
  on public.list_items for delete
  to authenticated
  using (public.is_list_member(list_id) and public.is_list_active(list_id));

-- ---------------------------------------------------------------------
-- 4) Finalizar / reabrir (cualquier miembro, no solo el dueño: suele terminarla
--    quien está en el súper)
-- ---------------------------------------------------------------------
create or replace function public.complete_list(p_list_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  if not public.is_list_member(p_list_id) then
    raise exception 'not_a_member' using errcode = '42501';
  end if;

  update public.lists
     set status = 'completed',
         completed_at = now(),
         completed_by = auth.uid()
   where id = p_list_id
     and status = 'active';
end;
$$;

create or replace function public.reopen_list(p_list_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  if not public.is_list_member(p_list_id) then
    raise exception 'not_a_member' using errcode = '42501';
  end if;

  update public.lists
     set status = 'active',
         completed_at = null,
         completed_by = null
   where id = p_list_id
     and status = 'completed';
end;
$$;

-- ---------------------------------------------------------------------
-- 5) Reutilizar: copia una lista (activa o del historial) en una nueva.
--    La nueva lista es de quien la pide, con su propio código de invitación.
--    Los ítems se copian sin tachar y en el mismo orden.
-- ---------------------------------------------------------------------
create or replace function public.duplicate_list(
  p_source_list_id uuid,
  p_name text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_new_id uuid;
  v_name   text;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  if not public.is_list_member(p_source_list_id) then
    raise exception 'not_a_member' using errcode = '42501';
  end if;

  select name into v_name from public.lists where id = p_source_list_id;

  -- El trigger on_list_created agrega a quien llama como miembro 'owner'.
  insert into public.lists (name, owner_id)
  values (left(coalesce(nullif(trim(p_name), ''), v_name), 80), auth.uid())
  returning id into v_new_id;

  -- now() es igual para toda la transacción, así que se suma el número de fila
  -- (en milisegundos) para conservar el orden original.
  insert into public.list_items (
    list_id, barcode, name, brand, quantity_label, net_quantity, net_unit,
    image_url, desired_qty, notes, added_by, created_at
  )
  select
    v_new_id, barcode, name, brand, quantity_label, net_quantity, net_unit,
    image_url, desired_qty, notes, auth.uid(),
    now() + (row_number() over (order by created_at, id)) * interval '1 millisecond'
  from public.list_items
  where list_id = p_source_list_id;

  return v_new_id;
end;
$$;

revoke all on function public.complete_list(uuid)            from public, anon;
revoke all on function public.reopen_list(uuid)              from public, anon;
revoke all on function public.duplicate_list(uuid, text)     from public, anon;
grant execute on function public.complete_list(uuid)         to authenticated;
grant execute on function public.reopen_list(uuid)           to authenticated;
grant execute on function public.duplicate_list(uuid, text)  to authenticated;

-- ---------------------------------------------------------------------
-- 6) Realtime también para las listas (se entera quien no la finalizó)
-- ---------------------------------------------------------------------
alter table public.lists replica identity full;
alter publication supabase_realtime add table public.lists;
