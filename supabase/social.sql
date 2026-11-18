-- thrive · seguidores públicos y clanes (se agrega al esquema base)

-- ---------- seguidores públicos (para contar seguidores de cualquier wallet) ----------
create table if not exists public.follows (
  user_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  target text not null check (char_length(target) between 32 and 64),   -- dirección seguida (0x… o Solana)
  created_at timestamptz not null default now(),
  primary key (user_id, target)
);
create index if not exists follows_target_idx on public.follows (target);
alter table public.follows enable row level security;
drop policy if exists "seguidores visibles" on public.follows;
create policy "seguidores visibles" on public.follows for select using (true);
drop policy if exists "seguir" on public.follows;
create policy "seguir" on public.follows for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "dejar de seguir" on public.follows;
create policy "dejar de seguir" on public.follows for delete to authenticated using (user_id = auth.uid());
grant select on public.follows to anon, authenticated;
grant insert (target), delete on public.follows to authenticated;

create or replace view public.follower_counts with (security_invoker = on) as
  select target, count(*)::int as followers from public.follows group by target;
grant select on public.follower_counts to anon, authenticated;

-- ---------- clanes ----------
create table if not exists public.clans (
  id bigint generated always as identity primary key,
  name text not null unique check (char_length(name) between 3 and 30),
  tag text not null unique check (tag ~ '^[A-Z0-9]{2,5}$'),
  bio text check (char_length(bio) <= 160),
  owner uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.clans enable row level security;
drop policy if exists "clanes visibles" on public.clans;
create policy "clanes visibles" on public.clans for select using (true);
drop policy if exists "crear clan" on public.clans;
create policy "crear clan" on public.clans for insert to authenticated with check (
  owner = auth.uid() and (select count(*) from public.clans c where c.owner = auth.uid()) < 2
);
drop policy if exists "editar mi clan" on public.clans;
create policy "editar mi clan" on public.clans for update to authenticated using (owner = auth.uid()) with check (owner = auth.uid());
drop policy if exists "borrar mi clan" on public.clans;
create policy "borrar mi clan" on public.clans for delete to authenticated using (owner = auth.uid());
grant select on public.clans to anon, authenticated;
grant insert (name, tag, bio), update (bio), delete on public.clans to authenticated;

-- un usuario pertenece a un solo clan a la vez
create table if not exists public.clan_members (
  clan_id bigint not null references public.clans(id) on delete cascade,
  user_id uuid not null default auth.uid() references public.profiles(id) on delete cascade unique,
  joined_at timestamptz not null default now(),
  primary key (clan_id, user_id)
);
alter table public.clan_members enable row level security;
drop policy if exists "miembros visibles" on public.clan_members;
create policy "miembros visibles" on public.clan_members for select using (true);
drop policy if exists "unirme" on public.clan_members;
create policy "unirme" on public.clan_members for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "salirme" on public.clan_members;
create policy "salirme" on public.clan_members for delete to authenticated using (user_id = auth.uid());
grant select on public.clan_members to anon, authenticated;
grant insert (clan_id), delete on public.clan_members to authenticated;

-- al crear un clan, el dueño entra como miembro
create or replace function public.clan_owner_joins() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  delete from public.clan_members where user_id = new.owner;
  insert into public.clan_members (clan_id, user_id) values (new.id, new.owner);
  return new;
end $$;
drop trigger if exists on_clan_created on public.clans;
create trigger on_clan_created after insert on public.clans for each row execute function public.clan_owner_joins();

create or replace view public.clan_list with (security_invoker = on) as
  select c.id, c.name, c.tag, c.bio, c.created_at, c.owner,
         count(m.user_id)::int as members,
         coalesce(array_agg(p.address) filter (where p.address is not null), '{}') as addresses
  from public.clans c
  left join public.clan_members m on m.clan_id = c.id
  left join public.profiles p on p.id = m.user_id
  group by c.id;
grant select on public.clan_list to anon, authenticated;
