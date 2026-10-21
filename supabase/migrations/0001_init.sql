-- =====================================================================
-- SuperCheck - esquema inicial (Supabase / PostgreSQL)
-- Ejecutar en: Supabase Dashboard > SQL Editor (o con `supabase db push`)
-- =====================================================================

create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------------
-- Utilidades
-- ---------------------------------------------------------------------

-- Mantiene updated_at al día en cualquier tabla que lo tenga.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- Código de invitación de 8 caracteres, sin caracteres ambiguos (0/O, 1/I).
-- 256 % 32 = 0, así que usar el byte módulo 32 no introduce sesgo.
create or replace function public.generate_invite_code()
returns text
language plpgsql
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
-- profiles
-- ---------------------------------------------------------------------
create table public.profiles (
  id           uuid primary key references auth.users (id) on delete cascade,
  display_name text not null default '',
  avatar_url   text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- Crea el perfil automáticamente cuando alguien se registra.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(
      nullif(new.raw_user_meta_data ->> 'display_name', ''),
      split_part(coalesce(new.email, ''), '@', 1)
    )
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------
-- lists
-- ---------------------------------------------------------------------
create table public.lists (
  id          uuid primary key default gen_random_uuid(),
  name        text not null check (char_length(name) between 1 and 80),
  owner_id    uuid not null references public.profiles (id) on delete cascade,
  invite_code text not null unique default public.generate_invite_code(),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index lists_owner_id_idx on public.lists (owner_id);

create trigger lists_set_updated_at
  before update on public.lists
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------
-- list_members
-- ---------------------------------------------------------------------
create table public.list_members (
  list_id   uuid not null references public.lists (id) on delete cascade,
  user_id   uuid not null references public.profiles (id) on delete cascade,
  role      text not null default 'member' check (role in ('owner', 'member')),
  joined_at timestamptz not null default now(),
  primary key (list_id, user_id)
);

create index list_members_user_id_idx on public.list_members (user_id);

-- Al crear una lista, el dueño pasa a ser miembro con rol 'owner'.
create or replace function public.add_owner_as_member()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.list_members (list_id, user_id, role)
  values (new.id, new.owner_id, 'owner')
  on conflict do nothing;
  return new;
end;
$$;

create trigger on_list_created
  after insert on public.lists
  for each row execute function public.add_owner_as_member();

-- ---------------------------------------------------------------------
-- list_items
-- ---------------------------------------------------------------------
create table public.list_items (
  id            uuid primary key default gen_random_uuid(),
  list_id       uuid not null references public.lists (id) on delete cascade,

  -- Producto elegido (viene de Open Food Facts, o se carga a mano)
  barcode       text,                       -- EAN-13 / UPC-A / EAN-8 tal como lo devuelve OFF
  name          text not null,
  brand         text,
  quantity_label text,                      -- texto original, ej. "300 g"
  net_quantity  numeric check (net_quantity is null or net_quantity > 0),
  net_unit      text check (net_unit is null or net_unit in ('g', 'ml')),
  image_url     text,

  -- Cuántas unidades de ese paquete se necesitan
  desired_qty   integer not null default 1 check (desired_qty > 0),
  notes         text,

  -- Estado
  is_checked    boolean not null default false,
  checked_by    uuid references public.profiles (id) on delete set null,
  checked_at    timestamptz,

  added_by      uuid references public.profiles (id) on delete set null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index list_items_list_id_idx on public.list_items (list_id);
create index list_items_list_barcode_idx on public.list_items (list_id, barcode);

create trigger list_items_set_updated_at
  before update on public.list_items
  for each row execute function public.set_updated_at();

-- Necesario para que los eventos DELETE de Realtime incluyan la fila completa.
alter table public.list_items replica identity full;

-- ---------------------------------------------------------------------
-- Funciones auxiliares para RLS
-- (security definer evita la recursión infinita de políticas sobre list_members)
-- ---------------------------------------------------------------------
create or replace function public.is_list_member(p_list_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.list_members
    where list_id = p_list_id
      and user_id = auth.uid()
  );
$$;

create or replace function public.shares_list_with(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.list_members me
    join public.list_members other on other.list_id = me.list_id
    where me.user_id = auth.uid()
      and other.user_id = p_user_id
  );
$$;

-- ---------------------------------------------------------------------
-- Unirse a una lista con el código de invitación
-- ---------------------------------------------------------------------
create or replace function public.join_list_by_code(p_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_list_id uuid;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;

  select id into v_list_id
  from public.lists
  where invite_code = upper(trim(p_code));

  if v_list_id is null then
    raise exception 'invalid_invite_code' using errcode = 'P0002';
  end if;

  insert into public.list_members (list_id, user_id, role)
  values (v_list_id, auth.uid(), 'member')
  on conflict do nothing;

  return v_list_id;
end;
$$;

revoke all on function public.join_list_by_code(text) from public, anon;
grant execute on function public.join_list_by_code(text) to authenticated;

-- ---------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------
alter table public.profiles     enable row level security;
alter table public.lists        enable row level security;
alter table public.list_members enable row level security;
alter table public.list_items   enable row level security;

-- profiles: ver el propio y el de quienes comparten lista conmigo.
create policy "profiles_select_self_or_shared"
  on public.profiles for select
  to authenticated
  using (id = auth.uid() or public.shares_list_with(id));

create policy "profiles_update_self"
  on public.profiles for update
  to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- lists
-- (owner_id = auth.uid() en el SELECT permite el INSERT ... RETURNING antes de que
--  el trigger haya registrado la membresía.)
create policy "lists_select_member_or_owner"
  on public.lists for select
  to authenticated
  using (public.is_list_member(id) or owner_id = auth.uid());

create policy "lists_insert_as_owner"
  on public.lists for insert
  to authenticated
  with check (owner_id = auth.uid());

create policy "lists_update_owner"
  on public.lists for update
  to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

create policy "lists_delete_owner"
  on public.lists for delete
  to authenticated
  using (owner_id = auth.uid());

-- list_members: no hay INSERT directo; se entra con join_list_by_code() o como dueño al crear la lista.
create policy "members_select_same_list"
  on public.list_members for select
  to authenticated
  using (public.is_list_member(list_id));

-- Salir de una lista (borrar mi propia fila) o que el dueño expulse a alguien.
create policy "members_delete_self_or_owner"
  on public.list_members for delete
  to authenticated
  using (
    user_id = auth.uid()
    or exists (
      select 1 from public.lists l
      where l.id = list_members.list_id and l.owner_id = auth.uid()
    )
  );

-- list_items: cualquier miembro puede ver y editar.
create policy "items_select_member"
  on public.list_items for select
  to authenticated
  using (public.is_list_member(list_id));

create policy "items_insert_member"
  on public.list_items for insert
  to authenticated
  with check (public.is_list_member(list_id) and added_by = auth.uid());

create policy "items_update_member"
  on public.list_items for update
  to authenticated
  using (public.is_list_member(list_id))
  with check (public.is_list_member(list_id));

create policy "items_delete_member"
  on public.list_items for delete
  to authenticated
  using (public.is_list_member(list_id));

-- ---------------------------------------------------------------------
-- Realtime
-- ---------------------------------------------------------------------
alter publication supabase_realtime add table public.list_items;
alter publication supabase_realtime add table public.list_members;
