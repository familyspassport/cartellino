-- Cartellino: archivio vestiti (codice unico + foto)

-- Elenco di chi può aggiungere/eliminare (gestito da staff.sh, non leggibile dalla pagina)
create table if not exists public.staff (
  email text primary key
);
alter table public.staff enable row level security;

create or replace function public.is_staff()
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (select 1 from public.staff where lower(email) = lower(auth.jwt() ->> 'email'));
$$;

-- Vestiti
create table if not exists public.vestiti (
  code       text primary key check (code ~ '^[A-Z0-9_.-]{1,40}$'),
  photo_path text not null,
  note       text default '',
  created_at timestamptz not null default now()
);
alter table public.vestiti enable row level security;

-- Chiunque abbia il link cerca; solo lo staff scrive
create policy "lettura libera" on public.vestiti
  for select to anon, authenticated using (true);
create policy "inserimento staff" on public.vestiti
  for insert to authenticated with check (public.is_staff());
create policy "modifica staff" on public.vestiti
  for update to authenticated using (public.is_staff()) with check (public.is_staff());
create policy "eliminazione staff" on public.vestiti
  for delete to authenticated using (public.is_staff());

-- Foto: bucket pubblico in lettura, scrittura solo staff
insert into storage.buckets (id, name, public)
values ('foto', 'foto', true)
on conflict (id) do update set public = true;

create policy "foto upload staff" on storage.objects
  for insert to authenticated with check (bucket_id = 'foto' and public.is_staff());
create policy "foto elimina staff" on storage.objects
  for delete to authenticated using (bucket_id = 'foto' and public.is_staff());
