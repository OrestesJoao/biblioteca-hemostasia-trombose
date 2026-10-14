-- Execute uma única vez em Supabase Dashboard > SQL Editor > New query.
-- Cada conta autenticada enxerga apenas a própria biblioteca.

create extension if not exists pgcrypto;

create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.articles (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.article_history (
  id bigint generated always as identity primary key,
  article_id uuid not null,
  owner_id uuid not null,
  action text not null check (action in ('created', 'updated', 'deleted')),
  data jsonb not null,
  changed_at timestamptz not null default now()
);

alter table public.categories enable row level security;
alter table public.articles enable row level security;
alter table public.article_history enable row level security;

create policy "categories: owner manages own rows" on public.categories
  for all to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid());

create policy "articles: owner manages own rows" on public.articles
  for all to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid());

create policy "article history: owner reads own rows" on public.article_history
  for select to authenticated using (owner_id = auth.uid());

create or replace function public.record_article_history()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'DELETE' then
    insert into public.article_history(article_id, owner_id, action, data)
    values (old.id, old.owner_id, 'deleted', old.data);
    return old;
  end if;
  insert into public.article_history(article_id, owner_id, action, data)
  values (new.id, new.owner_id, case when tg_op = 'INSERT' then 'created' else 'updated' end, new.data);
  return new;
end;
$$;

drop trigger if exists articles_history on public.articles;
create trigger articles_history
after insert or update or delete on public.articles
for each row execute function public.record_article_history();
