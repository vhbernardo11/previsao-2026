-- Prestador 360 / Supabase dedicado
-- Migration v0.2: PROPOSTA NÃO EXECUTADA — 07/11/2026
-- Aplicar SOMENTE em projeto Prestador 360 isolado, após consentimento/cotação.
-- Segurança: RLS por dono de organização, FKs compostas impedem referências interempresa.
-- Não colocar chave service_role no cliente nem aplicar estas tabelas em projeto de terceiro.
create extension if not exists pgcrypto;
create table public.p360_organizations (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users(id) on delete cascade default auth.uid(),
  name text not null check(length(name) between 1 and 150),
  city text,
  state char(2) not null default 'SP',
  tax_regime text,
  created_at timestamptz not null default now()
);
create unique index p360_org_owner_id_idx on public.p360_organizations(owner_user_id,id);
create table public.p360_clients (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.p360_organizations(id) on delete cascade,
  name text not null check(length(name) between 1 and 200),
  phone text,
  email text,
  city text,
  created_at timestamptz not null default now(),
  unique(org_id,id)
);
create table public.p360_services (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.p360_organizations(id) on delete cascade,
  name text not null check(length(name) between 1 and 200),
  category text,
  reference_price numeric(14,2) not null default 0 check(reference_price>=0),
  service_list_code text,
  nbs_code text,
  cclass_trib text,
  classification_status text not null default 'unverified'
    check(classification_status in ('unverified','reviewed','expired')),
  created_at timestamptz not null default now(),
  unique(org_id,id)
);
create table public.p360_work_orders (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.p360_organizations(id) on delete cascade,
  client_id uuid not null,
  service_id uuid not null,
  status text not null default 'scheduled'
    check(status in('scheduled','in_progress','completed','cancelled')),
  scheduled_on date,
  amount numeric(14,2) not null default 0 check(amount>=0),
  created_at timestamptz not null default now(),
  unique(org_id,id),
  foreign key(org_id,client_id) references public.p360_clients(org_id,id),
  foreign key(org_id,service_id) references public.p360_services(org_id,id)
);
create table public.p360_quotes (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.p360_organizations(id) on delete cascade,
  client_id uuid not null,
  status text not null default 'draft'
    check(status in ('draft','sent','approved','rejected','expired')),
  discount numeric(14,2) not null default 0 check(discount>=0),
  valid_until date,
  created_at timestamptz not null default now(),
  unique(org_id,id),
  foreign key(org_id,client_id) references public.p360_clients(org_id,id)
);
create table public.p360_quote_lines (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  quote_id uuid not null,
  service_id uuid not null,
  quantity numeric(14,3) not null default 1 check(quantity>0),
  unit_price numeric(14,2) not null check(unit_price>=0),
  unique(org_id,id),
  foreign key(org_id,quote_id) references public.p360_quotes(org_id,id) on delete cascade,
  foreign key(org_id,service_id) references public.p360_services(org_id,id)
);
create table public.p360_tax_scenarios (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.p360_organizations(id) on delete cascade,
  competence_date date not null,
  regime text not null,
  annex text,
  rbt12 numeric(18,2),
  monthly_revenue numeric(18,2),
  status text not null default 'simulation' check(status='simulation'),
  input jsonb not null,
  output jsonb not null,
  source_versions jsonb not null,
  reviewer_confirmed boolean not null default false,
  created_at timestamptz not null default now()
);
-- Índices de performance para RLS, FKs e filtro por organização.
create index p360_tax_scenarios_org_competence_idx on public.p360_tax_scenarios(org_id,competence_date);
create index p360_work_orders_org_client_idx on public.p360_work_orders(org_id,client_id);
create index p360_work_orders_org_service_idx on public.p360_work_orders(org_id,service_id);
create index p360_quotes_org_client_idx on public.p360_quotes(org_id,client_id);
create index p360_quote_lines_org_quote_idx on public.p360_quote_lines(org_id,quote_id);
create index p360_quote_lines_org_service_idx on public.p360_quote_lines(org_id,service_id);

-- Bloqueio por padrão até políticas explícitas.
alter table public.p360_organizations enable row level security;
alter table public.p360_clients enable row level security;
alter table public.p360_services enable row level security;
alter table public.p360_work_orders enable row level security;
alter table public.p360_quotes enable row level security;
alter table public.p360_quote_lines enable row level security;
alter table public.p360_tax_scenarios enable row level security;
-- 2026: GRANT explícito para novos objetos expostos ao PostgREST.
grant select,insert,update,delete on public.p360_organizations,public.p360_clients,
  public.p360_services,public.p360_work_orders,public.p360_quotes,
  public.p360_quote_lines,public.p360_tax_scenarios to authenticated;
revoke all on public.p360_organizations,public.p360_clients,public.p360_services,
  public.p360_work_orders,public.p360_quotes,public.p360_quote_lines,
  public.p360_tax_scenarios from anon;
revoke all on public.p360_organizations,public.p360_clients,public.p360_services,
  public.p360_work_orders,public.p360_quotes,public.p360_quote_lines,
  public.p360_tax_scenarios from public;
grant select,insert,update,delete on public.p360_organizations,public.p360_clients,
  public.p360_services,public.p360_work_orders,public.p360_quotes,
  public.p360_quote_lines,public.p360_tax_scenarios to service_role;
create policy p360_org_own_all on public.p360_organizations
  for all to authenticated
  using(owner_user_id=(select auth.uid()))
  with check(owner_user_id=(select auth.uid()));
-- Todos os filhos exigem ownership por org; sem função SECURITY DEFINER.
create policy p360_clients_owner on public.p360_clients for all to authenticated
  using(exists(select 1 from public.p360_organizations o where o.id=org_id and o.owner_user_id=(select auth.uid())))
  with check(exists(select 1 from public.p360_organizations o where o.id=org_id and o.owner_user_id=(select auth.uid())));
create policy p360_services_owner on public.p360_services for all to authenticated
  using(exists(select 1 from public.p360_organizations o where o.id=org_id and o.owner_user_id=(select auth.uid())))
  with check(exists(select 1 from public.p360_organizations o where o.id=org_id and o.owner_user_id=(select auth.uid())));
create policy p360_orders_owner on public.p360_work_orders for all to authenticated
  using(exists(select 1 from public.p360_organizations o where o.id=org_id and o.owner_user_id=(select auth.uid())))
  with check(exists(select 1 from public.p360_organizations o where o.id=org_id and o.owner_user_id=(select auth.uid())));
create policy p360_quotes_owner on public.p360_quotes for all to authenticated
  using(exists(select 1 from public.p360_organizations o where o.id=org_id and o.owner_user_id=(select auth.uid())))
  with check(exists(select 1 from public.p360_organizations o where o.id=org_id and o.owner_user_id=(select auth.uid())));
create policy p360_quote_lines_owner on public.p360_quote_lines for all to authenticated
  using(exists(select 1 from public.p360_organizations o where o.id=org_id and o.owner_user_id=(select auth.uid())))
  with check(exists(select 1 from public.p360_organizations o where o.id=org_id and o.owner_user_id=(select auth.uid())));
create policy p360_tax_owner on public.p360_tax_scenarios for all to authenticated
  using(exists(select 1 from public.p360_organizations o where o.id=org_id and o.owner_user_id=(select auth.uid())))
  with check(exists(select 1 from public.p360_organizations o where o.id=org_id and o.owner_user_id=(select auth.uid())));
-- TODO antes de produção:
-- 1) Testar users A/B com orgs diferentes, SELECT e INSERT interempresa.
-- 2) Testar FK composta cliente/serviço da org B em ordem/orçamento da org A.
-- 3) Configurar Auth redirect e cookies; nunca service_role no cliente.
-- 4) Revisar advisories e índices de RLS, retenção LGPD, backups.
-- 5) Dados fiscais versionados e classificações validadas pelo contador.
