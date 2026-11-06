# Prestador 360 — preview técnica 2026/2027

Projeto de gestão para prestadores técnicos, com UI responsiva e simulador fiscal limitado. O código desta pasta é uma **prévia independente e não comercial**, preservada na branch `prestador-360-demo`, sem afetar a versão principal do repositório.

## Telas incluídas
Painel com KPIs, clientes fictícios, serviços fictícios, ordens, orçamentos não fiscais e simulador do DAS para 2026/2027. Armazenamento da versão HTML no localStorage do navegador, não em nuvem. Não use dados reais nessa versão. O projeto Lovable separado foi criado para backend PostgreSQL/Supabase e avaliação online.

## Simulador fiscal: escopo real e limites

- **MEI serviços 2026**: DAS fixo de R$ 86,05 (INSS R$ 81,05 + ISS R$ 5,00). Nada proporcional a um orçamento.
- **Simples Nacional Anexos III e IV**: calcula alíquota efetiva `(RBT12 × alíquota nominal − parcela a deduzir) / RBT12`, depois multiplica a receita mensal atribuída ao anexo. Usar RBT12 correta de empresa em atividade plena e segregação correta. Faixas até R$ 3,6 milhões; para evitar particularidades do sublimite, bloqueia cálculo superior. Na 5ª faixa não exibe repartição dos tributos por causa do teto de ISS.
- **2026**: a parcela federal inclui IRPJ, CSLL, Cofins/PIS e CPP somente quando cabível no DAS. **Não soma** IBS 0,1%/CBS 0,9% ao Simples.
- **2027**: de acordo com anexos do texto alterado da LC 123 pela LC 227/2026, CBS e IBS aparecem como parcelas **dentro** do DAS; **não são impostos adicionais** do DAS. Em Anexo IV, CPP patronal é recolhida fora do DAS e não está calculada.
- **Município e estado de São Paulo**: ISS é municipal e varia conforme serviço/município; o simulador mostra a parcela ISS do DAS, nunca pressupõe alíquota municipal. Serviço sujeito a ISS não implica ICMS estadual automaticamente.
- **Não cobertos**: MEI 2027, início de atividade, Lucro Presumido/Real, atividades híbridas, retenções, anexos I/II/V, fator R, receitas fora da incidência, ISS retido, créditos, regimes específicos, CBS/IBS fora do Simples, NFS-e. Sem integração com Receita Federal, sem emissão fiscal.

## Casos manuais de regressão
- 2026, Simples III, RBT12 R$ 240.000, receita do mês R$ 18.000 → alíquota efetiva 7,30%; DAS R$ 1.314,00; parcela ISS (32%) R$ 420,48.
- 2027, Simples III, mesma base → DAS R$ 1.314,00; CBS (16,91% do DAS) R$ 222,2274 antes do arredondamento; IBS (0,19% do DAS) R$ 2,4966 antes do arredondamento.
- 2026, Simples IV, mesma base → efetiva 5,625%; DAS R$ 1.012,50; ISS (40% do DAS) R$ 405,00. CPP patronal fora.
- 2026 MEI serviços → R$ 86,05 fixos, independente da nota.

## Fontes
- Tabelas até 2026: https://legis.senado.gov.br/norma/572878/publicacao/34621013
- Anexo III, 2027–28: https://legis.senado.gov.br/norma/40180341/publicacao/40181117
- Anexo IV, 2027–28: https://legis.senado.gov.br/norma/40180341/publicacao/40181123
- DAS-MEI 2026: https://www8.receita.fazenda.gov.br/simplesnacional/Noticias/NoticiaCompleta.aspx?id=c3b2044c-ff97-432a-b33c-ecf2a3df6dc3
- NFS-e ME/EPP novembro de 2026: https://www.gov.br/receitafederal/pt-br/assuntos/noticias/2026/agosto/simples-nacional-nfs-e-nacional-sera-obrigatoria-para-me-e-epp-a-partir-de-1o-de-novembro-de-2026
- APIs e leiautes: https://www.gov.br/nfse/pt-br/biblioteca/documentacao-tecnica/documentacao-atual

## Infraestrutura
Há um projeto separado em Lovable Cloud com Supabase PostgreSQL provisionado. Criação de projeto Supabase diretamente na organização conectada exige confirmação de custo adicional, embora a cotação obtida tenha sido US$ 0/mês. A Vercel conectada retornou 403 na tentativa de criar um projeto e a equipe está no plano Hobby (uso pessoal não comercial). A publicação comercial exige plano compatível e validação jurídica, fiscal e segurança.

A pasta `schema/` descreve o modelo desejado, **não aplicado** em projetos conectados sem auditoria de permissões.
