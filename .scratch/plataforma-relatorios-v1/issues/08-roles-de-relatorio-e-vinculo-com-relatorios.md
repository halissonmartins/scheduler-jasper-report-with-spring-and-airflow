# 08 — Roles de Relatório e vínculo com Relatórios

**What to build:** O GERENTE passa a administrar permissão em grupo: cria uma Role de Relatório e define quais Relatórios ela alcança, podendo desvincular sem destruir a role.

**Blocked by:** 03 — Cadastro de Relatório com Código validado.

**Status:** ready-for-agent

- [ ] GERENTE cria Role de Relatório com nome e descrição; a role correspondente passa a existir no Keycloak (ADR-0005)
- [ ] GERENTE vincula e desvincula Relatórios de uma Role de Relatório
- [ ] O mapeamento role → Relatórios é consultável, mostrando quais Relatórios uma role alcança
- [ ] Vínculos registram autoria e data de criação e alteração
- [ ] ADMINISTRADOR e RELATOR recebem 403 nas operações de Role de Relatório
- [ ] Cenários Cucumber cobrindo criação, vínculo, desvínculo e recusa por tipo de usuário
