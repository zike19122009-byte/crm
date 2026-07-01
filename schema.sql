-- ============================================================
-- CRM Follow-up de Rematrícula — Schema Supabase
-- Rode este arquivo inteiro em: Supabase > SQL Editor > New query
-- ============================================================

create extension if not exists "pgcrypto";

-- ------------------------------------------------------------
-- 1) PERFIS (espelha auth.users com nome/role)
-- ------------------------------------------------------------
create table if not exists public.profiles (
  id         uuid primary key references auth.users(id) on delete cascade,
  nome       text not null,
  email      text,
  role       text not null default 'user' check (role in ('user','admin')),
  criado_em  timestamptz not null default now()
);

-- ------------------------------------------------------------
-- 2) CONTATOS (os leads/alunos em follow-up de rematrícula)
-- ------------------------------------------------------------
create table if not exists public.contacts (
  id              uuid primary key default gen_random_uuid(),
  nome            text not null,
  telefone        text,
  email           text,
  status          text not null default 'nao_contatado',
  colaborador_id  uuid references public.profiles(id) on delete set null,
  meta            jsonb not null default '{}'::jsonb,
  criado_em       timestamptz not null default now(),
  atualizado_em   timestamptz not null default now()
);

-- ------------------------------------------------------------
-- 3) ANOTAÇÕES (bloco de notas de cada contato, estilo Trello)
-- ------------------------------------------------------------
create table if not exists public.notes (
  id          uuid primary key default gen_random_uuid(),
  contact_id  uuid not null references public.contacts(id) on delete cascade,
  autor_id    uuid references public.profiles(id) on delete set null,
  autor_nome  text,
  texto       text not null,
  criado_em   timestamptz not null default now()
);

-- ------------------------------------------------------------
-- 4) Função auxiliar: "o usuário logado é admin?"
--    (security definer evita loop de permissão dentro da própria policy)
-- ------------------------------------------------------------
create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  );
$$;

-- ------------------------------------------------------------
-- 5) Trigger: cria automaticamente o perfil quando alguém se cadastra
-- ------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, nome, email)
  values (new.id, coalesce(new.raw_user_meta_data->>'nome', new.email), new.email);
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ------------------------------------------------------------
-- 6) RLS (Row Level Security) — regras de acesso por linha
-- ------------------------------------------------------------
alter table public.profiles enable row level security;
alter table public.contacts enable row level security;
alter table public.notes    enable row level security;

-- PROFILES: qualquer usuário logado pode ver a lista (nomes da equipe)
drop policy if exists "profiles_select_all" on public.profiles;
create policy "profiles_select_all" on public.profiles
  for select using (auth.role() = 'authenticated');

-- PROFILES: cada um edita só o próprio perfil; admin edita qualquer um
drop policy if exists "profiles_update_own_or_admin" on public.profiles;
create policy "profiles_update_own_or_admin" on public.profiles
  for update using (id = auth.uid() or public.is_admin());

-- CONTACTS: todo mundo logado VÊ todos os contatos
-- (isso alimenta a tabela "Todos os atendimentos", que é só leitura)
drop policy if exists "contacts_select_all" on public.contacts;
create policy "contacts_select_all" on public.contacts
  for select using (auth.role() = 'authenticated');

-- CONTACTS: um usuário só pode criar contato atribuído a si mesmo
-- (ou sem responsável); admin pode criar para qualquer colaborador
drop policy if exists "contacts_insert_self_or_admin" on public.contacts;
create policy "contacts_insert_self_or_admin" on public.contacts
  for insert with check (
    colaborador_id is null
    or colaborador_id = auth.uid()
    or public.is_admin()
  );

-- CONTACTS: só o dono (colaborador_id) ou admin pode editar
drop policy if exists "contacts_update_owner_or_admin" on public.contacts;
create policy "contacts_update_owner_or_admin" on public.contacts
  for update using (colaborador_id = auth.uid() or public.is_admin());

-- CONTACTS: só o dono ou admin pode excluir
drop policy if exists "contacts_delete_owner_or_admin" on public.contacts;
create policy "contacts_delete_owner_or_admin" on public.contacts
  for delete using (colaborador_id = auth.uid() or public.is_admin());

-- NOTES: todo mundo logado pode VER as anotações (inclusive o admin,
-- que precisa enxergar as anotações de todos os colaboradores)
drop policy if exists "notes_select_all" on public.notes;
create policy "notes_select_all" on public.notes
  for select using (auth.role() = 'authenticated');

-- NOTES: só quem é dono do contato (ou admin) pode adicionar anotação
drop policy if exists "notes_insert_owner_or_admin" on public.notes;
create policy "notes_insert_owner_or_admin" on public.notes
  for insert with check (
    exists (
      select 1 from public.contacts c
      where c.id = contact_id
        and (c.colaborador_id = auth.uid() or public.is_admin())
    )
  );

-- NOTES: só quem escreveu a nota (ou admin) pode apagar
drop policy if exists "notes_delete_own_or_admin" on public.notes;
create policy "notes_delete_own_or_admin" on public.notes
  for delete using (autor_id = auth.uid() or public.is_admin());

-- ============================================================
-- 7) DEPOIS de criar sua conta pelo próprio site (tela de cadastro),
--    rode o comando abaixo (trocando o e-mail) para virar administrador:
--
--    update public.profiles set role = 'admin' where email = 'seu-email@uniasselvi.com.br';
--
-- ============================================================
