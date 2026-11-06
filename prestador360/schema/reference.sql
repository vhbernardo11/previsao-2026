-- REFERÊNCIA DE MIGRATION: NÃO EXECUTADA. Validar com migrations do app real antes de aplicar.
create extension if not exists pgcrypto;
create table if not exists public.p360_organizations (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  municipality text,
  uf char(2) default 'SP',
  created_at timestamptz not null default now()
);
create table if not exists public.p360_clients (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.p360_organizations(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  phone text,
  city text,
  created_at timestamptz not null default now()
);
create table if not exists public.p360_services (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.p360_organizations(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  category text,
  base_price numeric(14,2) not null default 0 check(base_price>=0),
  created_at timestamptz not null default now()
);
create table if not exists public.p360_work_orders (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.p360_organizations(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  client_id uuid references public.p360_clients(id),
  service_id uuid references public.p360_services(id),
  status text not null default 'Agendada' check(status in('Agendada','Em andamento','Concluída','Cancelada')),
  service_date date,
  amount numeric(14,2) not null default 0 check(amount>=0),
  created_at timestamptz not null default now()
);
create table if not exists public.p360_quotes (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.p360_organizations(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  client_id uuid references public.p360_clients(id),
  service_id uuid references public.p360_services(id),
  status text not null default 'Pendente',
  amount numeric(14,2) not null default 0 check(amount>=0),
  created_at timestamptz not null default now()
);
create table if not exists public.p360_tax_scenarios (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.p360_organizations(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  competence_year smallint not null check(competence_year between 2026 and 2033),
  regime text not null,
  rbt12 numeric(16,2),
  month_revenue numeric(16,2),
  calculation jsonb not null default '{}'::jsonb,
  source_revision text not null,
  created_at timestamptz not null default now()
);
-- Data API: GRANT mínimo por tabela + RLS. Nenhum acesso anon.
grant select,insert,update,delete on public.p360_organizations,public.p360_clients,public.p360_services,public.p360_work_orders,public.p360_quotes,public.p360_tax_scenarios to authenticated;
alter table public.p360_organizations enable row level security;
alter table public.p360_clients enable row level security;
alter table public.p360_services enable row level security;
alter table public.p360_work_orders enable row level security;
alter table public.p360_quotes enable row level security;
alter table public.p360_tax_scenarios enable row level security;
create policy org_own_select on public.p360_organizations for select to authenticated using(owner_id=(select auth.uid()));
create policy org_own_insert on public.p360_organizations for insert to authenticated with check(owner_id=(select auth.uid()));
create policy org_own_update on public.p360_organizations for update to authenticated using(owner_id=(select auth.uid())) with check(owner_id=(select auth.uid()));
create policy org_own_delete on public.p360_organizations for delete to authenticated using(owner_id=(select auth.uid()));
-- Filhos são sempre da organização do usuário; RLS impede associação a organização de terceiros.
create policy clients_own_all on public.p360_clients for all to authenticated
 using(owner_id=(select auth.uid()) and exists(select 1 from public.p360_organizations o where o.id=org_id and o.owner_id=(select auth.uid())))
 with check(owner_id=(select auth.uid()) and exists(select 1 from public.p360_organizations o where o.id=org_id and o.owner_id=(select auth.uid())));
create policy services_own_all on public.p360_services for all to authenticated
 using(owner_id=(select auth.uid()) and exists(select 1 from public.p360_organizations o where o.id=org_id and o.owner_id=(select auth.uid())))
 with check(owner_id=(select auth.uid()) and exists(select 1 from public.p360_organizations o where o.id=org_id and o.owner_id=(select auth.uid())));
create policy orders_own_all on public.p360_work_orders for all to authenticated
 using(owner_id=(select auth.uid()) and exists(select 1 from public.p360_organizations o where o.id=org_id and o.owner_id=(select auth.uid())))
 with check(owner_id=(select auth.uid()) and exists(select 1 from public.p360_organizations o where o.id=org_id and o.owner_id=(select auth.uid())));
create policy quotes_own_all on public.p360_quotes for all to authenticated
 using(owner_id=(select auth.uid()) and exists(select 1 from public.p360_organizations o where o.id=org_id and o.owner_id=(select auth.uid())))
 with check(owner_id=(select auth.uid()) and exists(select 1 from public.p360_organizations o where o.id=org_id and o.owner_id=(select auth.uid())));
create policy tax_own_all on public.p360_tax_scenarios for all to authenticated
 using(owner_id=(select auth.uid()) and exists(select 1 from public.p360_organizations o where o.id=org_id and o.owner_id=(select auth.uid())))
 with check(owner_id=(select auth.uid()) and exists(select 1 from public.p360_organizations o where o.id=org_id and o.owner_id=(select auth.uid())));
-- TODO antes de produção: FK composta org_id+client_id/service_id para bloquear associação
-- cross-tenant apesar de owner_id correto em ordens/orçamentos; auditar RLS e GRANTs.
