-- Prestador 360 — TESTES DE ISOLAMENTO por duas identidades.
-- APENAS no projeto dedicado e DEPOIS de aplicar 001_schema_seguro.sql.
-- Usar conexão com privilégio suficiente (SQL Editor do projeto).
-- Toda inserção ocorre em TRANSAÇÃO e termina com ROLLBACK.
-- Não executar em projetos de ACS, Fio Cliente ou Integrai.
BEGIN;
INSERT INTO auth.users (id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
VALUES
('00000000-0000-4000-8000-000000000a01','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p360-rls-a@example.invalid','',now(),now(),now()),
('00000000-0000-4000-8000-000000000b01','00000000-0000-0000-0000-000000000000','authenticated','authenticated','p360-rls-b@example.invalid','',now(),now(),now());
INSERT INTO public.p360_organizations(id,owner_user_id,name)
VALUES
('00000000-0000-4000-8000-000000000a02','00000000-0000-4000-8000-000000000a01','Empresa A TESTE'),
('00000000-0000-4000-8000-000000000b02','00000000-0000-4000-8000-000000000b01','Empresa B TESTE');
INSERT INTO public.p360_clients(id,org_id,name)
VALUES
('00000000-0000-4000-8000-000000000a03','00000000-0000-4000-8000-000000000a02','Cliente A TESTE'),
('00000000-0000-4000-8000-000000000b03','00000000-0000-4000-8000-000000000b02','Cliente B TESTE');
INSERT INTO public.p360_services(id,org_id,name,reference_price)
VALUES
('00000000-0000-4000-8000-000000000a04','00000000-0000-4000-8000-000000000a02','Serviço A TESTE',100),
('00000000-0000-4000-8000-000000000b04','00000000-0000-4000-8000-000000000b02','Serviço B TESTE',100);
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000a01',true);
DO $test$
DECLARE found int; affected int;
BEGIN
 SELECT count(*) INTO found FROM public.p360_clients;
 IF found <> 1 THEN
  RAISE EXCEPTION 'RLS FALHOU: usuário A enxerga % clientes; esperado 1',found;
 END IF;
 UPDATE public.p360_clients SET name='ALTERAÇÃO INDEVIDA' WHERE id='00000000-0000-4000-8000-000000000b03';
 GET DIAGNOSTICS affected=ROW_COUNT;
 IF affected <> 0 THEN
  RAISE EXCEPTION 'RLS FALHOU: usuário A alterou cliente B';
 END IF;
 BEGIN
  INSERT INTO public.p360_clients(org_id,name)
  VALUES ('00000000-0000-4000-8000-000000000b02','INVASÃO INDEVIDA');
  RAISE EXCEPTION 'RLS FALHOU: usuário A inseriu na empresa B';
 EXCEPTION WHEN insufficient_privilege OR check_violation THEN
  NULL; -- esperado: tentativa negada
 END;
 BEGIN
  INSERT INTO public.p360_work_orders(org_id,client_id,service_id)
  VALUES ('00000000-0000-4000-8000-000000000a02',
          '00000000-0000-4000-8000-000000000b03',
          '00000000-0000-4000-8000-000000000a04');
  RAISE EXCEPTION 'FK FALHOU: ordem A aponta para cliente B';
 EXCEPTION WHEN foreign_key_violation THEN
  NULL; -- esperado: FK composta (org_id,client_id)
 END;
END $test$;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000b01',true);
DO $test$
DECLARE found int;
BEGIN
 SELECT count(*) INTO found FROM public.p360_clients;
 IF found <> 1 THEN
  RAISE EXCEPTION 'RLS FALHOU: usuário B enxerga % clientes; esperado 1',found;
 END IF;
END $test$;
RESET ROLE;
ROLLBACK;
-- Resultado esperado: nenhuma exceção; ROLLBACK final sem persistir dados fictícios.
-- Não substitui integração Auth verdadeira com sessões JWT e testes E2E de API.
