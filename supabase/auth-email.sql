-- thrive · entrar con correo o Google: el perfil solo guarda dirección si el usuario entró con wallet
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
declare a text; c text; prov text;
begin
  prov := coalesce(new.raw_app_meta_data->>'provider', '');
  if prov in ('email', 'google') then
    a := null; c := null;
  else
    a := coalesce(new.raw_user_meta_data->'custom_claims'->>'address', new.raw_user_meta_data->>'address', new.raw_user_meta_data->>'sub');
    c := coalesce(new.raw_user_meta_data->'custom_claims'->>'chain', new.raw_user_meta_data->>'chain');
    if a like '0x%' then a := lower(a); end if;
  end if;
  insert into public.profiles (id, address, chain) values (new.id, a, c) on conflict (id) do nothing;
  return new;
end $$;
