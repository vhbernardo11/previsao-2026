# Prestador 360 — Plano de implantação segura no Supabase

**Estado em 07/11/2026:** a organização vinculada confirmou cotação de **US$ 0/mês** e o usuário autorizou expressamente a criação de projeto independente. A confirmação de custo foi emitida, mas a execução de \`create_project\` recebeu bloqueio de segurança do serviço. **Projeto dedicado não foi criado.** Não tentar instalar os objetos em outro projeto.

## Sequência após desbloqueio / criação manual
1. Criar projeto **prestador-360** na organização selecionada, região **South America (São Paulo) / sa-east-1**, evitando recursos pagos. Verificar ID de projeto, estado \`ACTIVE_HEALTHY\` e custo no painel.
2. Conferir configuração de Auth, avisos de segurança e Data API do novo projeto. Não compartilhar segredos em chats, commits ou browser.
3. Aplicar uma migration revisada a partir de \`001_schema_seguro.sql\` **apenas no novo projeto**. Este arquivo é um rascunho de esquema; não foi aplicado.
4. Executar \`security_catalog_audit.sql\` — todas as 7 tabelas devem existir, RLS ativo, \`anon\` sem privilégios, usuário autenticado com as operações esperadas e políticas presentes.
5. Executar \`rls_isolation_rollback.sql\` **no SQL Editor do projeto exclusivo**. Usa usuários/empresas fictícios dentro de transação que termina em ROLLBACK. Validar que A não vê nem altera B, que referências de OS não cruzam empresas, e que B não vê A.
6. Testar REST com duas contas de testes reais (sem informações pessoais): SELECT, INSERT, UPDATE, DELETE e PUT/POST com JWT; verificar erro esperado para acesso entre organizações; executar Security Advisor.
7. Configurar Frontend no Hatchable (ou Vercel quando autorizado), usando exclusivamente URL e chave **publishable** do Supabase e \`@supabase/supabase-js\` em cliente autenticado. Nunca \`service_role\` no navegador, nem postar chaves em arquivos GitHub.
8. Antes de armazenar dados de clientes reais: política LGPD, consentimento, backups, recuperação, auditoria de pacotes e testes de uso comercial da hospedagem.
9. Consultar as fontes legais/versões para motor fiscal; **o banco não é o mesmo que cálculo real tributário validado**.

## Tabelas
\`p360_organizations\`, \`p360_clients\`, \`p360_services\`, \`p360_work_orders\`, \`p360_quotes\`, \`p360_quote_lines\`, \`p360_tax_scenarios\`.

## Proteções principais
- **Dono único por organização** neste MVP; sem permissões de colaboradores antes de especificar um modelo de membros.
- RLS \`TO authenticated\`, \`USING\` + \`WITH CHECK\`, \`owner_user_id = auth.uid()\` na organização.
- Filhos usam checagem de organização controlada pelo dono, com FK composta \`(org_id,cliente)\` ou \`(org_id,serviço)\` para impedir referências interempresa.
- \`anon\` não deve conseguir operar nas tabelas. Sem \`SECURITY DEFINER\` na camada pública.
- Scripts de verificação preservam operações existentes; nunca rodar em projeto alheio.

## Documentação oficial
- https://supabase.com/docs/guides/database/postgres/row-level-security
- https://supabase.com/docs/guides/api/securing-your-api
- https://supabase.com/docs/guides/auth

## Limites e observações
- Não foi criada uma instância dedicada nesta execução em função de bloqueio do provedor.
- Verificação de catálogos e testes E2E **não foram executados**, pois dependem do banco novo.
- Os resultados da calculadora fiscal continuam sendo **simulações**, não impostos oficiais para emissão.
