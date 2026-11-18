-- thrive · esquema de Supabase
-- Usuarios entran con su wallet (Supabase Auth → Web3: Ethereum y Solana). Cada usuario tiene un perfil,
-- puede publicar tesis por mercado, dar like, y sincronizar su estado (seguidos, favoritos, práctica, diseño).
-- Todo con Row Level Security: lo público se lee sin sesión; solo tú escribes lo tuyo.

-- ---------- perfiles ----------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  address text unique,
  chain text,
  handle text unique check (handle ~ '^[a-z0-9_.]{3,20}$'),
  bio text check (char_length(bio) <= 160),
  created_at timestamptz not null default now()
);
alter table public.profiles enable row level security;
drop policy if exists "perfiles visibles" on public.profiles;
create policy "perfiles visibles" on public.profiles for select using (true);
drop policy if exists "editar mi perfil" on public.profiles;
create policy "editar mi perfil" on public.profiles for update using (id = auth.uid()) with check (id = auth.uid());
revoke update on public.profiles from anon, authenticated;
grant update (handle, bio) on public.profiles to authenticated;
grant select on public.profiles to anon, authenticated;

-- el perfil se crea solo al primer inicio de sesión, con la dirección verificada por la firma
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
declare a text; c text;
begin
  a := coalesce(new.raw_user_meta_data->'custom_claims'->>'address', new.raw_user_meta_data->>'address', new.raw_user_meta_data->>'sub');
  c := coalesce(new.raw_user_meta_data->'custom_claims'->>'chain', new.raw_user_meta_data->>'chain');
  if a like '0x%' then a := lower(a); end if;           -- direcciones EVM en minúsculas; Solana distingue mayúsculas
  insert into public.profiles (id, address, chain) values (new.id, a, c) on conflict (id) do nothing;
  return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

-- ---------- tesis por mercado ----------
create table if not exists public.theses (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  market text not null check (char_length(market) between 2 and 90),   -- 'perp:BTC', 'perp:xyz:XYZ100', 'tok:<pool>'
  body text not null check (char_length(body) between 1 and 500),
  side text check (side in ('long', 'short', 'neutral')),
  created_at timestamptz not null default now()
);
create index if not exists theses_market_idx on public.theses (market, created_at desc);
alter table public.theses enable row level security;
drop policy if exists "tesis visibles" on public.theses;
create policy "tesis visibles" on public.theses for select using (true);
drop policy if exists "publicar mi tesis" on public.theses;
create policy "publicar mi tesis" on public.theses for insert to authenticated with check (
  user_id = auth.uid()
  and (select count(*) from public.theses t where t.user_id = auth.uid() and t.created_at > now() - interval '1 minute') < 5
);
drop policy if exists "borrar mi tesis" on public.theses;
create policy "borrar mi tesis" on public.theses for delete to authenticated using (user_id = auth.uid());
grant select on public.theses to anon, authenticated;
grant insert (market, body, side), delete on public.theses to authenticated;

-- ---------- likes ----------
create table if not exists public.likes (
  user_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  thesis_id bigint not null references public.theses(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, thesis_id)
);
alter table public.likes enable row level security;
drop policy if exists "likes visibles" on public.likes;
create policy "likes visibles" on public.likes for select using (true);
drop policy if exists "dar like" on public.likes;
create policy "dar like" on public.likes for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "quitar like" on public.likes;
create policy "quitar like" on public.likes for delete to authenticated using (user_id = auth.uid());
grant select on public.likes to anon, authenticated;
grant insert (thesis_id), delete on public.likes to authenticated;

-- ---------- vista del feed de tesis (respeta RLS) ----------
create or replace view public.thesis_feed with (security_invoker = on) as
  select t.id, t.market, t.body, t.side, t.created_at, t.user_id, p.handle, p.address, p.chain,
         (select count(*) from public.likes l where l.thesis_id = t.id) as likes
  from public.theses t join public.profiles p on p.id = t.user_id;
grant select on public.thesis_feed to anon, authenticated;

-- ---------- estado privado sincronizado (seguidos, favoritos, práctica, diseño) ----------
create table if not exists public.user_state (
  user_id uuid primary key default auth.uid() references public.profiles(id) on delete cascade,
  data jsonb not null default '{}'::jsonb check (pg_column_size(data) < 200000),
  updated_at timestamptz not null default now()
);
alter table public.user_state enable row level security;
drop policy if exists "mi estado" on public.user_state;
create policy "mi estado" on public.user_state for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
grant select, insert, update on public.user_state to authenticated;

-- ---------- traders de thrive (para la clasificación propia) ----------
create or replace view public.thrive_traders with (security_invoker = on) as
  select p.id, p.handle, p.address, p.chain, p.created_at,
         (select count(*) from public.theses t where t.user_id = p.id) as theses
  from public.profiles p where p.address is not null;
grant select on public.thrive_traders to anon, authenticated;
