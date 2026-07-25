# 09 — Vínculo de Role a Relator, catálogo filtrado e exclusão de Relator

**What to build:** O acesso do Relator passa a existir de verdade: o GERENTE vincula Roles de Relatório a Relatores, e o Relator vê exatamente os Relatórios que suas roles alcançam — nem um a mais. Revogar vale na hora.

**Blocked by:** 07 — Retenção de 7 dias e Datas de Referência disponíveis; 08 — Roles de Relatório e vínculo com Relatórios.

**Status:** ready-for-agent

- [ ] GERENTE lista Relatores cadastrados, inclusive os que ainda não têm nenhuma Role de Relatório
- [ ] GERENTE vincula e desvincula Roles de Relatório de um Relator
- [ ] GERENTE vê quais Roles um Relator tem e quais Relatores têm uma Role
- [ ] GERENTE exclui usuário Relator
- [ ] Catálogo devolve ao Relator apenas os Relatórios alcançados pelas suas Roles, agrupados por Produto
- [ ] Revogação de Role passa a valer imediatamente na próxima requisição
- [ ] Relator sem nenhuma Role recebe catálogo vazio, e não erro
- [ ] Cenários Cucumber cobrindo catálogo filtrado, revogação imediata e recusa por tipo de usuário
