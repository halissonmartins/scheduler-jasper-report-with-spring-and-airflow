# 26 — E2E Playwright das telas administrativas

**What to build:** O resíduo das telas de ADMINISTRADOR e GERENTE que nenhum outro seam enxerga: a fronteira de papel no navegador, os controles que a tela oferece e as mensagens que ela exibe. Mais um único caminho feliz encadeando os três papéis, que é a integração que cada seam isolado deixa passar.

Deliberadamente **não** reencena no navegador o CRUD de Cadastros nem as regras de permissão do servidor — isso é seam 1 (issues 02, 03, 08, 13), onde roda mais rápido e sem flakiness.

**Blocked by:** 16 — Telas administrativas; 23 — E2E Playwright incluindo o teto de blob (estabelece o seam 4 e a etapa de CI).

**Status:** ready-for-agent

- [ ] GERENTE autenticado não alcança as telas de ADMINISTRADOR — nem pelo menu, nem por URL direta; RELATOR não alcança nenhuma das duas (ADR-0010)
- [ ] Janela de Agendamento é seleção de lista fechada na tela de Relatório, não campo livre
- [ ] Código do Relatório inválido e Código com nome de Produto inexistente exibem mensagem legível na tela, não erro cru
- [ ] Um caminho feliz encadeado: ADMINISTRADOR cadastra Produto e Relatório → GERENTE cria Role de Relatório, vincula o Relatório e vincula um Relator → o Relator passa a ver o item no catálogo
- [ ] Cenários com a mesma etiqueta e etapa de CI do ticket 23, fora do fluxo de cada push
