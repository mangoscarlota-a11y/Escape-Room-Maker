-- Pega todo este archivo en Supabase: SQL Editor -> New query -> Run.
-- Crea la tabla de salas y las reglas: cualquiera puede LEER y PUBLICAR salas,
-- pero nadie puede editarlas ni borrarlas desde el juego.

create table if not exists public.rooms (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 40),
  author text not null check (char_length(author) between 1 and 30),
  data jsonb not null check (
    case
      when jsonb_typeof(data -> 'objects') = 'array'
        then jsonb_array_length(data -> 'objects') <= 301
      else false
    end
    and octet_length(data::text) < 60000
  ),
  created_at timestamptz not null default now()
);

create index if not exists rooms_created_at_idx on public.rooms (created_at desc);

alter table public.rooms enable row level security;

drop policy if exists "Cualquiera puede ver las salas" on public.rooms;
create policy "Cualquiera puede ver las salas"
  on public.rooms for select to anon, authenticated using (true);

drop policy if exists "Cualquiera puede publicar salas" on public.rooms;
create policy "Cualquiera puede publicar salas"
  on public.rooms for insert to anon, authenticated with check (true);

grant usage on schema public to anon, authenticated;
grant select, insert on public.rooms to anon, authenticated;
