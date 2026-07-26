# 16 — Telas administrativas

**What to build:** As telas de ADMINISTRADOR e GERENTE sobre as APIs já prontas: cadastro de Produtos e Relatórios, gestão de usuários privilegiados, criação de Roles de Relatório e seus vínculos com Relatórios e Relatores, e — porque Operação e Auditoria são funções do ADMINISTRADOR (ADR-0019) — as telas de consulta de Execuções de Coleta e da trilha de auditoria.

**Blocked by:** 15 — Frontend do Relator; 08 — Roles de Relatório e vínculo com Relatórios; 13 — Gestão de usuários privilegiados; 06 — Metadados, Status e alerta; 12 — Auditoria de geração e download.

**Status:** ready-for-agent

- [ ] ADMINISTRADOR cadastra, edita e remove Produto e Relatório pela interface, com as validações do Código exibidas de forma compreensível
- [ ] Janela de Agendamento apresentada como seleção de lista fechada, nunca campo livre
- [ ] ADMINISTRADOR cadastra e remove usuários ADMINISTRADOR e GERENTE
- [ ] GERENTE cria Role de Relatório e gerencia seus vínculos com Relatórios
- [ ] GERENTE lista Relatores, inclusive os que aguardam liberação, e gerencia seus vínculos de Role
- [ ] GERENTE exclui Relator
- [ ] ADMINISTRADOR consulta Execuções de Coleta por Relatório, Data de Referência e status, com início, fim, duração e contagem de linhas
- [ ] ADMINISTRADOR consulta a trilha de auditoria por usuário, Relatório e período, incluindo as tentativas recusadas
- [ ] Cada tipo de usuário vê apenas as telas que lhe cabem, com o servidor recusando o que a interface esconde
