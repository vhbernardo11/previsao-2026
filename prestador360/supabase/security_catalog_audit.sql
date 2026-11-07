-- Prestador 360 — auditoria de segurança, leitura somente.
-- Execute APENAS no futuro projeto Supabase exclusivo Prestador 360.
-- Não cria dados e não modifica nenhuma tabela.
WITH expected(tab) AS (
  VALUES
  ('p360_organizations'), ('p360_clients'), ('p360_services'),
  ('p360_work_orders'), ('p360_quotes'), ('p360_quote_lines'),
  ('p360_tax_scenarios')
),
audit AS (
 SELECT e.tab, c.oid, c.relrowsecurity AS rls,
   coalesce(has_table_privilege('anon',c.oid,'select'),false) as anon_select,
   coalesce(has_table_privilege('anon',c.oid,'insert'),false) as anon_insert,
   coalesce(has_table_privilege('anon',c.oid,'update'),false) as anon_update,
   coalesce(has_table_privilege('anon',c.oid,'delete'),false) as anon_delete,
   coalesce(has_table_privilege('authenticated',c.oid,'select'),false) as auth_select,
   coalesce(has_table_privilege('authenticated',c.oid,'insert'),false) as auth_insert,
   coalesce(has_table_privilege('authenticated',c.oid,'update'),false) as auth_update,
   coalesce(has_table_privilege('authenticated',c.oid,'delete'),false) as auth_delete,
   (SELECT COUNT(*) FROM pg_policies p WHERE p.schemaname='public' AND p.tablename=e.tab) AS policies
 FROM expected e
 LEFT JOIN pg_class c ON c.oid=to_regclass('public.'||e.tab)
)
SELECT tab AS tabela, oid IS NOT NULL AS existe, rls AS rls_ativo,
       anon_select OR anon_insert OR anon_update OR anon_delete AS permissao_anon_indevida,
       auth_select AND auth_insert AND auth_update AND auth_delete AS autenticado_grants,
       policies AS numero_policies,
       coalesce(rls,false) AND oid IS NOT NULL
         AND NOT(anon_select OR anon_insert OR anon_update OR anon_delete)
         AND auth_select AND auth_insert AND auth_update AND auth_delete
         AND policies>0 AS verificacao_catalogo
FROM audit ORDER BY tab;
-- Rode também:
-- SELECT conrelid::regclass AS tabela, conname,
--        pg_get_constraintdef(oid) AS fk
-- FROM pg_constraint
-- WHERE connamespace='public'::regnamespace AND contype='f'
--   AND conrelid::regclass::text LIKE 'p360_%';
-- Se qualquer verificacao_catalogo = false, NÃO LIBERE o backend.
-- Esse diagnóstico estrutural NÃO substitui testes com duas identidades.
